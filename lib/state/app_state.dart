import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';
import '../i18n/tr.dart';
import '../logic/statements.dart';
import '../models/app_data.dart';
import '../services/requirement_store.dart';

/// Holds the applicant's answers and saves them on the phone after every change.
///
/// NOTE before real use: shared_preferences is not encrypted. Move to encrypted
/// storage (e.g. flutter_secure_storage for the key + an encrypted database).
class AppState extends ChangeNotifier {
  static const _key = 'negosyoplan.v2';

  AppData data = AppData();

  /// Keeps the on-screen language in step with the owner's choice.
  @override
  void notifyListeners() {
    Lang.code = data.lang;
    super.notifyListeners();
  }
  bool loaded = false;
  bool loggedIn = false;
  Timer? _saveTimer;

  /// Lets tests and previews use a clock other than today.
  DateTime Function() now = DateTime.now;

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw != null) data = AppData.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      data = AppData();
    }
    loaded = true;
    notifyListeners();
  }

  void _changed() {
    notifyListeners();
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 400), save);
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(data.toJson()));
  }

  /// Make a change and save it.
  void change(void Function(AppData d) f) {
    f(data);
    _changed();
  }

  // ---------------- account ----------------

  bool get hasAccount => data.pinHash.isNotEmpty;
  String get firstName {
    final fn = val('fn');
    if (fn.isNotEmpty) return fn;
    final n = data.accountName.trim();
    return n.isEmpty ? '' : n.split(' ').first;
  }

  static String normalizeMobile(String m) {
    var d = m.replaceAll(RegExp(r'[^0-9]'), '');
    if (d.startsWith('63')) d = '0${d.substring(2)}';
    if (d.length == 10 && d.startsWith('9')) d = '0$d';
    return d;
  }

  /// Simple on-device hash so log-in works offline.
  /// Before real use: salted, slow hash (PBKDF2/Argon2) and attempt limits.
  static String hashPin(String mobile, String pin) => sha256.convert(utf8.encode('${normalizeMobile(mobile)}:$pin')).toString();

  /// Makes the account on this phone. [uid] is the Firebase account id (empty
  /// for a phone-only account). Answers from another account are cleared first.
  void createAccount({required String name, required String mobile, required String pin, String uid = ''}) {
    if (data.uid != uid || (hasAccount && normalizeMobile(mobile) != data.mobile)) _resetFor(uid);
    change((d) {
      d.uid = uid;
      d.accountName = name.trim();
      d.mobile = normalizeMobile(mobile);
      d.pinHash = hashPin(mobile, pin);
      // Fill Step 1 from the account so the user does not type it twice.
      final parts = name.trim().split(RegExp(r'\s+'));
      if (parts.isNotEmpty && (d.v['fn'] ?? '').isEmpty) d.v['fn'] = parts.first;
      if (parts.length > 1 && (d.v['ln'] ?? '').isEmpty) d.v['ln'] = parts.last;
      // TESTING ONLY: start with every question answered (see config.dart).
      if (kTestAnswers) _copyAnswers(AppData.testFill(), d, keepName: true);
    });
    loggedIn = true;
  }

  bool login(String mobile, String pin) {
    final ok = hasAccount && normalizeMobile(mobile) == data.mobile && hashPin(mobile, pin) == data.pinHash;
    if (ok) {
      loggedIn = true;
      notifyListeners();
    }
    return ok;
  }

  /// Called after logging in online. If the phone holds another account's
  /// answers, they are replaced (by the answers saved online, if any).
  void startSession({required String uid, required String name, required String mobile, required String pin, AppData? restored}) {
    final sameAccount = data.uid == uid || (data.uid.isEmpty && data.mobile == normalizeMobile(mobile));
    if (!sameAccount) {
      _resetFor(uid, restored: restored);
    } else if (data.v.isEmpty && restored != null) {
      _resetFor(uid, restored: restored);
    }
    change((d) {
      d.uid = uid;
      if (name.trim().isNotEmpty) d.accountName = name.trim();
      d.mobile = normalizeMobile(mobile);
      d.pinHash = hashPin(mobile, pin);
      d.verified = true;
    });
    loggedIn = true;
  }

  void _resetFor(String uid, {AppData? restored}) {
    final keepLang = data.lang, keepChosen = data.langChosen;
    data = (restored ?? AppData())
      ..uid = uid
      ..pinHash = ''
      ..lang = keepLang
      ..langChosen = keepChosen;
    reqFiles = [];
    reqStore.clear();
  }

  /// Runs when the owner logs out (signs out of Firebase; set in main.dart).
  Future<void> Function()? onSignOut;

  void logout() {
    loggedIn = false;
    onSignOut?.call();
    notifyListeners();
  }

  // ---------------- status from OLEDIPO ----------------

  /// Status staff set on the submitted application (see AuthService.watchStatus).
  void setRemoteStatus(String status, String note) {
    if (status == data.appStatus && note == data.staffNote) return;
    change((d) => d
      ..appStatus = status
      ..staffNote = note);
  }

  /// OLEDIPO changed the status and the owner has not been told yet (see StatusWatcher).
  bool get hasStatusNews =>
      submitted && (returnedForCompletion || accepted) && (data.appStatus != data.statusSeen || data.staffNote != data.noteSeen);

  void markStatusSeen() => change((d) => d
    ..statusSeen = d.appStatus
    ..noteSeen = d.staffNote);

  bool get returnedForCompletion => data.appStatus == 'Returned for completion';
  bool get accepted => data.appStatus == 'Accepted';

  /// Requirements can be changed before submitting, or when OLEDIPO returned the application.
  bool get canEditRequirements => !submitted || returnedForCompletion;

  /// Fill the app with the sample business (keeps the account).
  void loadSample() {
    final keep = data;
    final s = AppData.sample()
      ..accountName = keep.accountName.isEmpty ? 'Maria L. Santos' : keep.accountName
      ..mobile = keep.mobile.isEmpty ? '09171234567' : keep.mobile
      ..pinHash = keep.pinHash
      ..lang = keep.lang
      ..langChosen = keep.langChosen;
    data = s;
    _changed();
  }

  /// TESTING ONLY: fills every question with test answers (see config.dart).
  void loadTestAnswers() => change((d) => _copyAnswers(AppData.testFill(), d, keepName: true));

  static void _copyAnswers(AppData from, AppData to, {bool keepName = false}) {
    final fn = to.v['fn'], ln = to.v['ln'];
    to
      ..v = Map.of(from.v)
      ..g = {for (final e in from.g.entries) e.key: List.of(e.value)}
      ..lists = {for (final e in from.lists.entries) e.key: [for (final r in e.value) Map.of(r)]}
      ..years = Map.of(from.years)
      ..extraYears = Set.of(from.extraYears)
      ..req = Map.of(from.req)
      ..trainings = [for (final t in from.trainings) Map.of(t)];
    if (keepName) {
      if ((fn ?? '').isNotEmpty) to.v['fn'] = fn!;
      if ((ln ?? '').isNotEmpty) to.v['ln'] = ln!;
    }
  }

  Future<void> deleteAll() async {
    await reqStore.clear();
    reqFiles = [];
    data = AppData();
    loggedIn = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
    notifyListeners();
  }

  // ---------------- simple answers ----------------

  String val(String k) => data.v[k] ?? '';
  void setVal(String k, String value) => change((d) => d.v[k] = value);

  List<String> sel(String k) => data.g[k] ?? const [];
  String one(String k) => sel(k).isEmpty ? '' : sel(k).first;
  void pick(String k, String option, {bool multi = false}) => change((d) {
        final cur = List<String>.from(d.g[k] ?? const []);
        if (multi) {
          cur.contains(option) ? cur.remove(option) : cur.add(option);
        } else {
          cur
            ..clear()
            ..add(option);
        }
        d.g[k] = cur;
      });

  // ---------------- list answers ----------------

  List<Map<String, String>> rows(String k) => data.lists[k] ?? const [];
  void addRow(String k, Map<String, String> row) => change((d) => (d.lists[k] ??= []).add(row));
  void setRow(String k, int i, Map<String, String> row) => change((d) => d.lists[k]![i] = row);
  void removeRow(String k, int i) => change((d) => d.lists[k]!.removeAt(i));

  // ---------------- business kind ----------------

  /// prod | resell | service, from Step 3.
  String get kind => switch (one('bt')) {
        'I buy and resell' => 'resell',
        'I offer a service' => 'service',
        _ => 'prod',
      };

  String get costRoute => '/costs/$kind';

  // ---------------- statements by year ----------------

  /// Business start (Step 2), as (year, month). Null when not answered.
  (int, int)? get start {
    final p = val('os').split('-');
    final y = int.tryParse(p.first);
    if (y == null) return null;
    return (y, p.length > 1 ? int.tryParse(p[1]) ?? 1 : 1);
  }

  /// Every year from the business start to last year, plus years the owner added.
  List<int> get statementYears {
    final set = <int>{...data.years.keys, ...data.extraYears};
    final s = start;
    final last = now().year - 1;
    if (s != null) {
      for (var y = s.$1; y <= (s.$1 > last ? s.$1 : last); y++) {
        set.add(y);
      }
    }
    return set.toList()..sort();
  }

  int get nextYear => statementYears.isEmpty ? now().year - 1 : statementYears.last + 1;

  void addYear() => change((d) => d.extraYears.add(nextYear));

  bool canRemoveYear(int y) {
    final s = start;
    final fromStart = s != null && y >= s.$1 && y <= now().year - 1;
    return data.extraYears.contains(y) && !fromStart;
  }

  void removeYear(int y) => change((d) {
        d.extraYears.remove(y);
        d.years.remove(y);
      });

  YearStatements year(int y) => data.years[y] ?? YearStatements();

  /// One year's three statements with every total worked out, carrying Cash
  /// beginning and Capital, beginning from the year before (see [computeYear]).
  YearFigures figures(int y) {
    YearFigures? prev;
    for (final x in statementYears) {
      if (x > y) break;
      final s = year(x);
      final f = computeYear(s.inc, s.cf, s.bs, prev);
      if (x == y) return f;
      prev = f;
    }
    final s = year(y);
    return computeYear(s.inc, s.cf, s.bs, null);
  }

  /// The lines the owner typed for that year, plus the lines the app works out.
  Map<String, String> statementValues(int y, StatementType t) => figures(y).of(t);

  /// True when the year before is also in the statements, so Cash beginning
  /// and Capital, beginning are carried over instead of typed.
  bool hasPreviousYear(int y) {
    final ys = statementYears;
    return ys.isNotEmpty && y > ys.first && ys.contains(y - 1);
  }

  /// A line the app works out for that year (not typed).
  bool isCalculated(int y, String key) => calculatedKeys.contains(key) || (carriedKeys.containsKey(key) && hasPreviousYear(y));

  /// The lines the owner types for that year.
  List<StatementLine> inputLines(int y, StatementType t) =>
      t.lines.where((l) => l.kind != LineKind.heading && !isCalculated(y, l.key)).toList();

  void setLine(int y, StatementType t, String key, String value) => change((d) {
        final s = d.years.putIfAbsent(y, YearStatements.new);
        final m = switch (t) {
          StatementType.income => s.inc,
          StatementType.cashFlow => s.cf,
          StatementType.balance => s.bs,
        };
        if (value.trim().isEmpty) {
          m.remove(key);
        } else {
          m[key] = value;
        }
      });

  Progress progress(int y, StatementType t) {
    final vals = statementValues(y, t);
    final keys = inputLines(y, t).map((l) => l.key).toList();
    final typed = keys.where((k) => (vals[k] ?? '').trim().isNotEmpty).length;
    if (typed == 0) return Progress.empty;
    return typed == keys.length ? Progress.complete : Progress.partial;
  }

  int blankLines(int y, StatementType t) {
    final vals = statementValues(y, t);
    return inputLines(y, t).where((l) => (vals[l.key] ?? '').trim().isEmpty).length;
  }

  bool yearComplete(int y) => StatementType.values.every((t) => progress(y, t) == Progress.complete);

  /// "June to December · first year", "January to December" …
  String yearSpan(int y) {
    final s = start;
    const months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
    if (s != null && y == s.$1) return '${months[(s.$2 - 1).clamp(0, 11).toInt()]} to December · first year';
    if (y >= now().year) return 'January to now · this year';
    return 'January to December';
  }

  // ---------------- requirements (PDFs kept on this phone) ----------------

  /// Where the requirement PDFs are kept: SQLite + files on this phone.
  /// Tests use [MemoryRequirementStore].
  RequirementStore reqStore = SqliteRequirementStore();

  /// Business permit, signed Annex C and training certificates, as uploaded.
  List<ReqFile> reqFiles = [];

  Future<void> loadRequirements() async {
    reqFiles = await reqStore.all();
    notifyListeners();
  }

  ReqFile? reqFile(String kind) {
    for (final f in reqFiles) {
      if (f.kind == kind) return f;
    }
    return null;
  }

  List<ReqFile> get trainingFiles => reqFiles.where((f) => f.kind == 'training').toList();

  /// 'none' · 'saved' (on this phone) · 'sent' — for the permit and Annex C.
  String reqStatus(String kind) => reqFile(kind)?.status ?? 'none';

  /// All three requirements are there: business permit, signed Annex C, and at least one training certificate.
  bool get requirementsComplete => reqFile('permit') != null && reqFile('annexC') != null && trainingFiles.isNotEmpty;

  Future<void> addRequirement({required String kind, required String title, String provider = '', String date = '', required Uint8List bytes, required String fileName}) async {
    await reqStore.add(kind: kind, title: title, provider: provider, date: date, bytes: bytes, fileName: fileName);
    await loadRequirements();
  }

  Future<void> removeRequirement(int id) async {
    await reqStore.remove(id);
    await loadRequirements();
  }

  /// Where a submitted application is sent. Set in main.dart (Firestore +
  /// Google Drive, see lib/cloud/). Null means "on this phone only" (tests,
  /// or when the online backend is off or Firebase could not start).
  SubmitBackend? backend;

  /// Submits the application: sends the answers and PDFs online (when a
  /// [backend] is set), then marks everything as sent on this phone.
  /// If sending fails, nothing is marked and the error is passed on.
  Future<void> submitApplication() async {
    if (backend != null) await backend!.submit(this);
    await reqStore.markAllSent();
    change((d) => d
      ..submittedAt = now().toIso8601String()
      ..appStatus = 'Pending'
      ..staffNote = ''
      ..statusSeen = 'Pending'
      ..noteSeen = ''
      ..trackerAt = 4); // printed, signed, uploaded, submitted; now with the committee
    await loadRequirements();
  }

  bool get submitted => data.submittedAt.isNotEmpty;
}

/// Sends a submitted application somewhere (see lib/cloud/cloud_backend.dart).
abstract class SubmitBackend {
  Future<void> submit(AppState app);
}