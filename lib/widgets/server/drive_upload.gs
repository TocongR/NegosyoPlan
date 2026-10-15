/**
 * NegosyoPlan · Google Drive upload (Google Apps Script web app).
 *
 * The phone app sends each requirement PDF here; this script saves it in
 * your Google Drive, inside one folder per application, and answers with
 * the file id and link. Free, no Firebase Storage needed.
 *
 * Setup:
 *  1. In Google Drive make a folder, e.g. "NegosyoPlan uploads". Open it and copy
 *     the id from the address bar (the part after /folders/). Paste it below.
 *  2. Change SECRET to a long random text. Put the same text in
 *     lib/cloud/cloud_config.dart (driveSecret).
 *  3. Deploy → New deployment → type "Web app" →
 *       Execute as: Me
 *       Who has access: Anyone
 *     Copy the Web app URL into cloud_config.dart (driveUploadUrl).
 *  4. After any change here: Deploy → Manage deployments → Edit → Version: New version.
 */

const ROOT_FOLDER_ID = 'PASTE_YOUR_DRIVE_FOLDER_ID_HERE';
const SECRET = 'CHANGE_ME_TO_A_LONG_RANDOM_TEXT';
const MAX_BYTES = 10 * 1024 * 1024; // 10 MB, same as the app

function doPost(e) {
  try {
    const body = JSON.parse(e.postData.contents);
    if (body.secret !== SECRET) return reply_({ ok: false, error: 'not allowed' });
    if (body.mimeType !== 'application/pdf') return reply_({ ok: false, error: 'only PDF' });

    const bytes = Utilities.base64Decode(body.data);
    if (bytes.length > MAX_BYTES) return reply_({ ok: false, error: 'file too big' });

    const folder = applicationFolder_(String(body.folder || 'Unnamed application'));
    const blob = Utilities.newBlob(bytes, 'application/pdf', String(body.fileName || 'file.pdf'));
    const file = folder.createFile(blob);
    return reply_({ ok: true, id: file.getId(), url: file.getUrl() });
  } catch (err) {
    return reply_({ ok: false, error: String(err) });
  }
}

/** Quick check in a browser: opening the Web app URL shows this. */
function doGet() {
  return reply_({ ok: true, service: 'NegosyoPlan Drive upload' });
}

/** One folder per application, made the first time a file arrives. */
function applicationFolder_(name) {
  const lock = LockService.getScriptLock();
  lock.waitLock(20000);
  try {
    const root = DriveApp.getFolderById(ROOT_FOLDER_ID);
    const found = root.getFoldersByName(name);
    return found.hasNext() ? found.next() : root.createFolder(name);
  } finally {
    lock.releaseLock();
  }
}

function reply_(obj) {
  return ContentService.createTextOutput(JSON.stringify(obj)).setMimeType(ContentService.MimeType.JSON);
}
