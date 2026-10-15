/// Online settings for the demo backend.
///
/// * Text (the application answers) → Cloud Firestore (Firebase free Spark plan).
/// * Files (the requirement PDFs) → a Google Drive folder, through a small
///   Google Apps Script web app (free; see server/drive_upload.gs).
///
/// Fill in the two values below after you deploy the Apps Script.
class CloudConfig {
  CloudConfig._();

  /// Turn the online backend on or off. When off, Submit works on the phone only.
  static const enabled = true;

  /// The Web app URL from Apps Script → Deploy → New deployment → Web app.
  /// Looks like https://script.google.com/macros/s/AKfy.../exec
  static const driveUploadUrl = 'https://script.google.com/macros/s/AKfycbww5ZY5wI9mQ8NHSvEHM-X8hnCsJwnT-qZrAZgx72uI8oxtcm181MH22wKccjabfyIb/exec';

  /// Must be the same text as SECRET in server/drive_upload.gs.
  /// Demo-level protection only: anyone who has the app could read it.
  static const driveSecret = 'np-cyj1FPTSrtwXw9ZQky86hEYcZAJYpoZNzELhSZSm';

  static bool get driveReady => enabled && driveUploadUrl.startsWith('https://');
}
