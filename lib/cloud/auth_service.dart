import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../models/app_data.dart';
import '../state/app_state.dart';

/// Accounts with Firebase Authentication: full name, mobile number and a
/// 6-digit PIN. No SMS code for now.
///
/// Firebase needs an email, so the mobile number becomes one that only this
/// app uses: 09171234567 → 09171234567@negosyoplan.app. The PIN is the
/// password (Firebase requires at least 6 characters, hence 6 digits).
///
/// Firestore:
///   users/{uid}         name, mobile, createdAt
///   applications/{uid} the submitted application; staff set "status"
///                       (Pending · Returned for completion · Accepted) and
///                       "staffNote". The app shows it to the owner.
class AuthService {
  AuthService._();

  static const pinLength = 6;

  /// False when Firebase could not start (then the app uses the phone-only account).
  static bool get available => Firebase.apps.isNotEmpty;

  static FirebaseAuth get _auth => FirebaseAuth.instance;
  static FirebaseFirestore get _db => FirebaseFirestore.instance;

  static User? get currentUser => available ? _auth.currentUser : null;

  static String emailFor(String mobile) => '${AppState.normalizeMobile(mobile)}@negosyoplan.app';

  /// Creates the account and returns its id.
  static Future<String> signUp({required String name, required String mobile, required String pin}) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(email: emailFor(mobile), password: pin);
      final user = cred.user!;
      await user.updateDisplayName(name.trim());
      await _db.collection('users').doc(user.uid).set({
        'name': name.trim(),
        'mobile': AppState.normalizeMobile(mobile),
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)); // merge: keeps the notification token if it was saved first
      return user.uid;
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(_message(e));
    } on FirebaseException catch (e) {
      throw AuthFailure('Could not save your account (${e.code}). Please try again.');
    }
  }

  /// Logs in and returns the account id, name and (if any) the answers saved online.
  static Future<(String uid, String name, Map<String, dynamic>? answers)> logIn({required String mobile, required String pin}) async {
    try {
      final cred = await _auth.signInWithEmailAndPassword(email: emailFor(mobile), password: pin);
      final user = cred.user!;
      var name = user.displayName ?? '';
      Map<String, dynamic>? answers;
      try {
        final prof = await _db.collection('users').doc(user.uid).get().timeout(const Duration(seconds: 15));
        name = (prof.data()?['name'] as String?) ?? name;
        final app = await _db.collection('applications').doc(user.uid).get().timeout(const Duration(seconds: 15));
        answers = app.data()?['answers'] as Map<String, dynamic>?;
      } catch (_) {
        // Profile or answers could not be read; logging in still works.
      }
      return (user.uid, name, answers);
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(_message(e));
    }
  }

  static Future<void> logOut() async {
    if (available) await _auth.signOut();
  }

  // ---------------- application status from OLEDIPO ----------------

  static StreamSubscription<User?>? _authSub;
  static StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _docSub;

  /// Keeps [app] up to date with the status OLEDIPO staff set on the
  /// application (works while the app is open; also after restarting).
  static void watchStatus(AppState app) {
    if (!available) return;
    _authSub?.cancel();
    _authSub = _auth.authStateChanges().listen((user) {
      _docSub?.cancel();
      _docSub = null;
      if (user == null) return;
      _docSub = _db.collection('applications').doc(user.uid).snapshots().listen((snap) {
        final d = snap.data();
        if (d == null) return;
        app.setRemoteStatus('${d['status'] ?? ''}', '${d['staffNote'] ?? ''}');
      }, onError: (_) {});
    });
  }

  /// Turns saved answers from Firestore back into the app's data (for logging in on a new phone).
  static AppData? restore(Map<String, dynamic>? answers) {
    if (answers == null) return null;
    try {
      return AppData.fromJson(answers);
    } catch (_) {
      return null;
    }
  }

  static String _message(FirebaseAuthException e) => switch (e.code) {
        'email-already-in-use' => 'This mobile number already has an account. Please log in.',
        'invalid-credential' || 'wrong-password' || 'user-not-found' || 'invalid-email' => 'Wrong mobile number or PIN. Please try again.',
        'weak-password' => 'Your PIN must be 6 numbers.',
        'network-request-failed' => 'No internet. Please connect and try again.',
        'too-many-requests' => 'Too many tries. Please wait a few minutes and try again.',
        'operation-not-allowed' || 'admin-restricted-operation' =>
          'Sign-in is not turned on yet. (Firebase console → Authentication → Sign-in method → Email/Password.)',
        _ => 'Something went wrong (${e.code}). Please try again.',
      };
}

/// A sign-up or log-in problem, with a message the owner can read.
class AuthFailure implements Exception {
  final String message;
  const AuthFailure(this.message);
  @override
  String toString() => message;
}