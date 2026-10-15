import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

/// One uploaded requirement (a PDF kept on this phone).
class ReqFile {
  final int id;

  /// 'permit' (one only) · 'annexC' (one only) · 'training' (one or more).
  final String kind;

  /// Training name (for trainings) or the requirement name.
  final String title;
  final String provider;
  final String date;

  /// Where the PDF is stored inside the app's own folder.
  final String path;

  /// The file name the owner picked.
  final String fileName;
  final int size;
  final DateTime addedAt;

  /// 'saved' on this phone · 'sent' to OLEDIPO.
  final String status;

  const ReqFile({
    required this.id,
    required this.kind,
    required this.title,
    this.provider = '',
    this.date = '',
    required this.path,
    required this.fileName,
    required this.size,
    required this.addedAt,
    this.status = 'saved',
  });

  Map<String, Object?> toMap() => {
        'id': id,
        'kind': kind,
        'title': title,
        'provider': provider,
        'date': date,
        'path': path,
        'file_name': fileName,
        'size': size,
        'added_at': addedAt.toIso8601String(),
        'status': status,
      };

  factory ReqFile.fromMap(Map<String, Object?> m) => ReqFile(
        id: m['id'] as int,
        kind: m['kind'] as String,
        title: m['title'] as String? ?? '',
        provider: m['provider'] as String? ?? '',
        date: m['date'] as String? ?? '',
        path: m['path'] as String,
        fileName: m['file_name'] as String? ?? '',
        size: m['size'] as int? ?? 0,
        addedAt: DateTime.tryParse(m['added_at'] as String? ?? '') ?? DateTime.now(),
        status: m['status'] as String? ?? 'saved',
      );

  /// "1.2 MB", "350 KB".
  String get sizeText => size >= 1024 * 1024 ? '${(size / (1024 * 1024)).toStringAsFixed(1)} MB' : '${(size / 1024).ceil()} KB';
}

/// Why a picked file was not accepted.
class NotAPdf implements Exception {
  final String message;
  const NotAPdf(this.message);
  @override
  String toString() => message;
}

/// The requirement files: kept on this phone only (no server yet).
/// The list is in a SQLite database; the PDFs are copied into the app's own
/// documents folder, so they stay even if the original file is deleted.
abstract class RequirementStore {
  static const maxBytes = 10 * 1024 * 1024; // 10 MB per file

  Future<List<ReqFile>> all();

  /// Adds a PDF. For 'permit' and 'annexC' it replaces the one already there.
  Future<ReqFile> add({required String kind, required String title, String provider = '', String date = '', required Uint8List bytes, required String fileName});

  Future<void> remove(int id);

  /// Marks every file as sent (after the owner submits).
  Future<void> markAllSent();

  /// Deletes every file (used by "Delete my data").
  Future<void> clear();

  /// Throws [NotAPdf] unless [bytes] is a PDF of an allowed size.
  static void check(Uint8List bytes, String fileName) {
    final isPdf = bytes.length > 4 && bytes[0] == 0x25 && bytes[1] == 0x50 && bytes[2] == 0x44 && bytes[3] == 0x46; // %PDF
    if (!isPdf) throw const NotAPdf('Please choose a PDF file.');
    if (bytes.length > maxBytes) throw const NotAPdf('This file is too big. Please choose a PDF under 10 MB.');
  }
}

/// SQLite + files in the app's documents folder.
class SqliteRequirementStore implements RequirementStore {
  Database? _db;
  Directory? _dir;

  Future<Database> _open() async {
    if (_db != null) return _db!;
    final base = await getApplicationDocumentsDirectory();
    _dir = Directory(p.join(base.path, 'requirements'));
    await _dir!.create(recursive: true);
    _db = await openDatabase(
      p.join(base.path, 'negosyoplan.db'),
      version: 1,
      onCreate: (db, _) => db.execute('''
        CREATE TABLE requirement_files (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          kind TEXT NOT NULL,
          title TEXT NOT NULL,
          provider TEXT,
          date TEXT,
          path TEXT NOT NULL,
          file_name TEXT,
          size INTEGER,
          added_at TEXT,
          status TEXT
        )'''),
    );
    return _db!;
  }

  @override
  Future<List<ReqFile>> all() async {
    final db = await _open();
    final rows = await db.query('requirement_files', orderBy: 'id');
    return rows.map(ReqFile.fromMap).toList();
  }

  @override
  Future<ReqFile> add({required String kind, required String title, String provider = '', String date = '', required Uint8List bytes, required String fileName}) async {
    RequirementStore.check(bytes, fileName);
    final db = await _open();
    if (kind != 'training') {
      for (final old in (await all()).where((f) => f.kind == kind)) {
        await remove(old.id);
      }
    }
    final stamp = DateTime.now();
    final path = p.join(_dir!.path, '${kind}_${stamp.microsecondsSinceEpoch}.pdf');
    await File(path).writeAsBytes(bytes, flush: true);
    final id = await db.insert('requirement_files', {
      'kind': kind,
      'title': title,
      'provider': provider,
      'date': date,
      'path': path,
      'file_name': fileName,
      'size': bytes.length,
      'added_at': stamp.toIso8601String(),
      'status': 'saved',
    });
    return ReqFile(id: id, kind: kind, title: title, provider: provider, date: date, path: path, fileName: fileName, size: bytes.length, addedAt: stamp);
  }

  @override
  Future<void> remove(int id) async {
    final db = await _open();
    final rows = await db.query('requirement_files', where: 'id = ?', whereArgs: [id]);
    for (final r in rows) {
      final f = File(r['path'] as String);
      if (await f.exists()) await f.delete();
    }
    await db.delete('requirement_files', where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<void> markAllSent() async {
    final db = await _open();
    await db.update('requirement_files', {'status': 'sent'});
  }

  @override
  Future<void> clear() async {
    for (final f in await all()) {
      await remove(f.id);
    }
  }
}

/// In-memory store for tests.
class MemoryRequirementStore implements RequirementStore {
  final _files = <ReqFile>[];
  var _next = 1;

  @override
  Future<List<ReqFile>> all() async => List.of(_files);

  @override
  Future<ReqFile> add({required String kind, required String title, String provider = '', String date = '', required Uint8List bytes, required String fileName}) async {
    RequirementStore.check(bytes, fileName);
    if (kind != 'training') _files.removeWhere((f) => f.kind == kind);
    final f = ReqFile(id: _next++, kind: kind, title: title, provider: provider, date: date, path: 'memory/$fileName', fileName: fileName, size: bytes.length, addedAt: DateTime(2026));
    _files.add(f);
    return f;
  }

  @override
  Future<void> remove(int id) async => _files.removeWhere((f) => f.id == id);

  @override
  Future<void> markAllSent() async {
    for (var i = 0; i < _files.length; i++) {
      final f = _files[i];
      _files[i] = ReqFile(
          id: f.id, kind: f.kind, title: f.title, provider: f.provider, date: f.date, path: f.path, fileName: f.fileName, size: f.size, addedAt: f.addedAt, status: 'sent');
    }
  }

  @override
  Future<void> clear() async => _files.clear();
}
