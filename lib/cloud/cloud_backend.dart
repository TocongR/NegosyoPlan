import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../services/generated_docs.dart';
import '../services/requirement_store.dart';
import '../state/app_state.dart';
import 'drive_uploader.dart';

/// Sends a submitted application online:
/// 1. uses the owner's account (logged in with mobile number and PIN),
/// 2. uploads each requirement PDF to Google Drive (folder per application),
/// 3. makes Annex A, Annex D and the financial statements as PDFs from the
///    answers and uploads them too, so staff can read and print them,
/// 4. saves the answers and the file links in Firestore:
///    applications/{uid}            answers, names, status "Pending"
///    applications/{uid}/files/{id} one document per PDF (kind, title, Drive link)
///
/// Only text goes to Firestore; files go to Drive. The owner's PIN is never sent.
class CloudBackend implements SubmitBackend {
  CloudBackend({DriveUploader? drive}) : _drive = drive ?? DriveUploader();
  final DriveUploader _drive;

  /// Requirement files already in Drive from an earlier try (requirement id → Drive file),
  /// so pressing Submit again after an error does not upload them twice.
  final Map<int, DriveFile> _alreadyUploaded = {};

  FirebaseFirestore get _db => FirebaseFirestore.instance;

  /// The logged-in account.
  Future<String> _uid() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw const CloudStepError('Step 1 · Account', 'You are not logged in. Please log out and log in again, then submit.');
    }
    return user.uid;
  }

  @override
  Future<void> submit(AppState app) async {
    final uid = await _uid();
    final business = app.val('bn').trim().isEmpty ? 'No business name' : app.val('bn').trim();
    final owner = [app.val('fn'), app.val('mn'), app.val('ln')].where((x) => x.trim().isNotEmpty).join(' ');
    final folder = '$business — $owner ($uid)';

    // 1) Requirement files to Google Drive.
    final uploaded = <(ReqFile, DriveFile)>[];
    for (final f in app.reqFiles) {
      try {
        final bytes = await File(f.path).readAsBytes();
        final name = '${f.kind}_${f.title}_${f.fileName}'.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
        final d = _alreadyUploaded[f.id] ?? await _drive.upload(folderName: folder, fileName: name, bytes: bytes);
        _alreadyUploaded[f.id] = d;
        uploaded.add((f, d));
      } catch (e) {
        throw CloudStepError('Step 2 · Google Drive upload (${f.fileName})', '$e');
      }
    }

    // 2) Forms made from the answers, always fresh (the answers may have changed).
    //    Same file name each time, so Drive replaces the old copy.
    final generated = <(GeneratedDoc, int, DriveFile)>[];
    for (final g in GeneratedDoc.all) {
      try {
        final bytes = await g.build(app);
        final d = await _drive.upload(folderName: folder, fileName: 'GENERATED_${g.fileName}', bytes: bytes);
        generated.add((g, bytes.length, d));
      } catch (e) {
        throw CloudStepError('Step 3 · Making and uploading ${g.title}', '$e');
      }
    }

    // 3) Text to Firestore.
    final answers = app.data.toJson()
      ..remove('pinHash')
      ..remove('lastRoute')
      ..remove('textSize')
      ..remove('readAloud')
      ..remove('statusSeen')
      ..remove('noteSeen');
    final doc = _db.collection('applications').doc(uid);
    final batch = _db.batch()
      ..set(doc, {
        'status': 'Pending', // staff change this on the staff website
        'staffNote': '',
        'userId': uid,
        'ownerName': owner,
        'businessName': business,
        'mobile': app.data.mobile,
        'barangay': app.val('a2'),
        'town': app.val('a3'),
        'loanAmount': app.val('la'),
        'language': app.data.lang,
        'answers': answers,
        'submittedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        // Shown to staff on the review website.
        'history': FieldValue.arrayUnion([
          {'action': app.returnedForCompletion ? 'Resubmitted' : 'Submitted', 'note': '', 'by': owner, 'at': Timestamp.now()},
        ]),
      }, SetOptions(merge: true));

    final keep = <String>{};
    for (final (f, d) in uploaded) {
      final id = '${f.kind}_${f.id}';
      keep.add(id);
      batch.set(doc.collection('files').doc(id), {
        'kind': f.kind,
        'title': f.title,
        'provider': f.provider,
        'date': f.date,
        'fileName': f.fileName,
        'size': f.size,
        'generated': false,
        'driveFileId': d.id,
        'driveUrl': d.url,
        'uploadedAt': FieldValue.serverTimestamp(),
      });
    }
    for (final (g, size, d) in generated) {
      keep.add(g.id);
      batch.set(doc.collection('files').doc(g.id), {
        'kind': g.id, // gen_annexA · gen_annexD · gen_statements
        'title': g.title,
        'provider': '',
        'date': '',
        'fileName': g.fileName,
        'size': size,
        'generated': true,
        'driveFileId': d.id,
        'driveUrl': d.url,
        'uploadedAt': FieldValue.serverTimestamp(),
      });
    }

    // Files the owner removed since the last time (e.g. after "Returned for completion")
    // are taken off the list staff see.
    try {
      final old = await doc.collection('files').get().timeout(const Duration(seconds: 20));
      for (final d in old.docs) {
        if (!keep.contains(d.id)) batch.delete(d.reference);
      }
    } catch (_) {
      // Not able to read the old list; the new files are still saved.
    }

    try {
      await batch.commit().timeout(const Duration(seconds: 40));
    } on FirebaseException catch (e) {
      throw CloudStepError('Step 4 · Firestore save', '${e.code}: ${e.message}'
          '${e.code == 'permission-denied' ? '\n→ Check the Firestore rules (server/firestore.rules) are published.' : ''}'
          '${e.code == 'not-found' ? '\n→ Create the Firestore database in the Firebase console.' : ''}');
    } on TimeoutException {
      throw const CloudStepError('Step 4 · Firestore save', 'No answer from Firestore in 40 s.\n→ Is the Firestore database created? Is there internet?');
    }
  }
}

/// Says which step of sending failed, and why.
class CloudStepError implements Exception {
  final String step;
  final String detail;
  const CloudStepError(this.step, this.detail);
  @override
  String toString() => '$step failed.\n$detail';
}