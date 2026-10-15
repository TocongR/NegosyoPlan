import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// Phone notifications (Firebase Cloud Messaging), so the owner hears that
/// OLEDIPO accepted or returned the application even when the app is closed.
///
/// The app only registers this phone: it saves the phone's FCM token in
/// users/{uid}.fcmToken. The notification itself is sent by
/// server/notify.gs (Apps Script) when staff decide on the staff website.
///
/// While the app is open, the in-app pop-up (StatusWatcher) shows the news
/// instead, so nothing is drawn here for messages in the foreground.
/// Tapping a notification opens the app; the pop-up then shows the note.
class PushService {
  PushService._();

  static StreamSubscription<User?>? _authSub;
  static StreamSubscription<String>? _refreshSub;

  static FirebaseMessaging get _fcm => FirebaseMessaging.instance;

  /// Call once after Firebase starts (main.dart).
  static Future<void> start() async {
    try {
      // Android 13+ and iOS ask the owner once. Saying no only turns off notifications.
      await _fcm.requestPermission(alert: true, badge: true, sound: true);
    } catch (e) {
      debugPrint('Notification permission: $e');
    }
    _authSub?.cancel();
    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) _save(user.uid);
    });
    _refreshSub?.cancel();
    _refreshSub = _fcm.onTokenRefresh.listen((token) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) _save(user.uid, token);
    });
  }

  static Future<void> _save(String uid, [String? token]) async {
    try {
      token ??= await _fcm.getToken();
      if (token == null) return;
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'fcmToken': token,
        'fcmUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Could not save the notification token: $e');
    }
  }

  /// On log out: this phone should stop getting this account's notifications.
  static Future<void> forget() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'fcmToken': FieldValue.delete(),
      }, SetOptions(merge: true)).timeout(const Duration(seconds: 8));
    } catch (_) {
      // Offline: the server skips tokens that no longer work.
    }
  }
}