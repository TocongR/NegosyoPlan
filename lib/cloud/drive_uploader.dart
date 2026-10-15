import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'cloud_config.dart';

/// A file saved in the team's Google Drive folder.
class DriveFile {
  final String id;
  final String url;
  const DriveFile(this.id, this.url);
}

class DriveUploadError implements Exception {
  final String message;
  const DriveUploadError(this.message);
  @override
  String toString() => 'DriveUploadError: $message';
}

/// Sends one PDF to the Apps Script web app, which saves it in Google Drive
/// (in a folder for this application) and answers with the file id and link.
class DriveUploader {
  DriveUploader({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;

  Future<DriveFile> upload({
    required String folderName,
    required String fileName,
    required Uint8List bytes,
    String mimeType = 'application/pdf',
  }) async {
    if (!CloudConfig.driveReady) throw const DriveUploadError('Drive upload URL is not set in lib/cloud/cloud_config.dart (driveUploadUrl).');
    final body = jsonEncode({
      'secret': CloudConfig.driveSecret,
      'folder': folderName,
      'fileName': fileName,
      'mimeType': mimeType,
      'data': base64Encode(bytes),
    });

    // Apps Script answers a POST with a redirect (302) to the real response,
    // which must be fetched with GET. Dart does not follow POST redirects,
    // so do it by hand.
    final req = http.Request('POST', Uri.parse(CloudConfig.driveUploadUrl))
      ..headers['Content-Type'] = 'application/json'
      ..followRedirects = false
      ..body = body;
    // Big PDFs on slow mobile data can take a while, so the limits are generous.
    var res = await http.Response.fromStream(await _client.send(req).timeout(const Duration(minutes: 5)));
    if (res.statusCode == 302 || res.statusCode == 303) {
      final next = res.headers['location'];
      if (next == null) throw const DriveUploadError('No redirect location');
      // The file is already saved at this point; this only fetches the answer. Try up to 3 times.
      http.Response? answer;
      Object? lastError;
      for (var i = 0; i < 3 && answer == null; i++) {
        try {
          answer = await _client.get(Uri.parse(next)).timeout(const Duration(minutes: 2));
        } catch (e) {
          lastError = e;
        }
      }
      if (answer == null) throw DriveUploadError('No answer from Google after upload ($lastError). Check the internet and try again.');
      res = answer;
    }
    if (res.statusCode != 200) {
      throw DriveUploadError('HTTP ${res.statusCode}${res.statusCode == 401 || res.statusCode == 403 ? ' → Deploy the Apps Script with "Who has access: Anyone".' : ''}');
    }

    final Map<String, dynamic> j;
    try {
      j = jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      final start = res.body.length > 120 ? res.body.substring(0, 120) : res.body;
      throw DriveUploadError('Apps Script did not answer with JSON. Is it deployed as a Web app for "Anyone", and is the URL the /exec one?\nAnswer started with: $start');
    }
    if (j['ok'] != true) {
      final err = '${j['error'] ?? 'upload failed'}';
      throw DriveUploadError(err == 'not allowed'
          ? 'Secret does not match. driveSecret in cloud_config.dart must be exactly SECRET in the Apps Script (then deploy a New version).'
          : 'Apps Script: $err');
    }
    return DriveFile(j['id'] as String, j['url'] as String);
  }
}
