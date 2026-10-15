import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:share_plus/share_plus.dart';

import '../logic/checks.dart';
import '../logic/format.dart';
import '../logic/statements.dart';
import '../state/app_state.dart';

/// The official EMBRACE forms, filled in from the owner's answers.
///
/// The templates in `assets/templates/` are the forms OLEDIPO gave us
/// (Annex A, C and D) with fill-in marks added. The layout, wording and boxes
/// are the originals; the app only writes the answers into the blanks.
/// Everything happens on the phone, with no internet and no AI.
enum WordForm { annexA, annexC, annexD }

extension WordFormInfo on WordForm {
  String get title => switch (this) {
        WordForm.annexA => 'Application form (Annex A)',
        WordForm.annexC => 'Certificate of Residency and Business Operation (Annex C)',
        WordForm.annexD => 'Business plan (Annex D)',
      };

  String get asset => 'assets/templates/$name.docx';

  String get fileName => switch (this) {
        WordForm.annexA => 'Annex-A-Application-Form.docx',
        WordForm.annexC => 'Annex-C-Certificate-of-Residency-and-Operation.docx',
        WordForm.annexD => 'Annex-D-Business-Plan.docx',
      };
}

/// Fills a .docx template.
///
/// Marks the template may contain (inside `word/document.xml`):
/// * `{{key}}` or `{{key|default}}` — replaced by the value; the default is
///   used when the value is blank (for example a line of underscores).
/// * `<w:r><w:t>{{#flag}}</w:t></w:r> … <w:r><w:t>{{/flag}}</w:t></w:r>` —
///   kept only when [flags] contains `flag` (used for check marks).
class DocxFiller {
  DocxFiller._();

  static final _section = RegExp(r'<w:r><w:t>\{\{#(\w+)\}\}</w:t></w:r>(.*?)<w:r><w:t>\{\{/\1\}\}</w:t></w:r>', dotAll: true);
  static final _field = RegExp(r'\{\{(\w+)(?:\|([^}]*))?\}\}');

  static String escape(String s) =>
      s.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;').replaceAll('"', '&quot;');

  /// Fills the XML of one document part.
  static String fillXml(String xml, Map<String, String> values, Set<String> flags) {
    var out = xml.replaceAllMapped(_section, (m) => flags.contains(m.group(1)) ? m.group(2)! : '');
    out = out.replaceAllMapped(_field, (m) {
      final v = (values[m.group(1)] ?? '').trim();
      if (v.isEmpty) return escape(m.group(2) ?? '');
      return escape(v).replaceAll('\n', '</w:t><w:br/><w:t xml:space="preserve">');
    });
    return out;
  }

  /// Fills a whole .docx file and returns the new file.
  static Uint8List fill(Uint8List template, Map<String, String> values, Set<String> flags) {
    final input = ZipDecoder().decodeBytes(template);
    final output = Archive();
    for (final f in input.files) {
      if (!f.isFile) continue;
      List<int> data = f.content as List<int>;
      if (f.name == 'word/document.xml') {
        data = utf8.encode(fillXml(utf8.decode(data), values, flags));
      }
      output.addFile(ArchiveFile(f.name, data.length, data));
    }
    return Uint8List.fromList(ZipEncoder().encode(output)!);
  }
}

/// Values for each form, taken from the answers exactly as typed.
class WordForms {
  WordForms._();

  static const docxMime = 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';

  static Future<Uint8List> build(AppState s, WordForm f) async {
    final template = (await rootBundle.load(f.asset)).buffer.asUint8List();
    final (values, flags) = data(s, f);
    return DocxFiller.fill(template, values, flags);
  }

  /// Saves or sends the filled Word file with the phone's share sheet
  /// (Save to Files, Gmail, Messenger, Drive…).
  static Future<void> share(AppState s, WordForm f) async {
    final bytes = await build(s, f);
    await Share.shareXFiles(
      [XFile.fromData(bytes, name: f.fileName, mimeType: docxMime)],
      subject: f.title,
    );
  }

  static (Map<String, String>, Set<String>) data(AppState s, WordForm f) => switch (f) {
        WordForm.annexA => annexA(s),
        WordForm.annexC => annexC(s),
        WordForm.annexD => annexD(s),
      };

  // ---------------- helpers ----------------

  /// `100000` -> `100,000.00`. Blank stays blank.
  static String money(String? raw) {
    final v = amt(raw);
    if (v == null) return '';
    final cents = (v.abs() * 100).round();
    final s = '${groupDigits(cents ~/ 100)}.${(cents % 100).toString().padLeft(2, '0')}';
    return v < 0 ? '($s)' : s;
  }

  static String moneyOf(double? v) => v == null ? '' : money(v.toString());

  /// `09171234567` -> `0917 123 4567`.
  static String mobile(String m) {
    final d = AppState.normalizeMobile(m);
    if (d.length != 11) return m;
    return '${d.substring(0, 4)} ${d.substring(4, 7)} ${d.substring(7)}';
  }

  static String fullName(AppState s) => [s.val('fn'), s.val('mn'), s.val('ln')].where((x) => x.trim().isNotEmpty).join(' ');

  static List<String> _home(AppState s) => [s.val('a1'), s.val('a2'), s.val('a3'), s.val('a4')];
  static List<String> _biz(AppState s) =>
      s.one('loc') == 'Somewhere else' ? [s.val('b1'), s.val('b2'), s.val('b3'), s.val('b4')] : _home(s);
  static String _join(List<String> parts) => parts.where((x) => x.trim().isNotEmpty).join(', ');

  /// Puts a list into a fixed number of rows. Extra items share the last row.
  static List<String> fit(List<String> items, int rows) {
    final out = List<String>.filled(rows, '');
    for (var i = 0; i < items.length; i++) {
      if (i < rows) {
        out[i] = items[i];
      } else {
        out[rows - 1] = '${out[rows - 1]}; ${items[i]}';
      }
    }
    return out;
  }

  static int? latestYear(AppState s) {
    final ys = s.statementYears;
    for (final y in ys.reversed) {
      if (s.progress(y, StatementType.income) != Progress.empty || s.progress(y, StatementType.balance) != Progress.empty) return y;
    }
    return null;
  }

  static const _months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];

  static String _dobText(String dob) {
    final p = dob.split('-');
    if (p.length != 3) return dob;
    return '${p[1].padLeft(2, '0')}/${p[2].padLeft(2, '0')}/${p[0]}';
  }

  static String _age(AppState s) {
    final d = DateTime.tryParse(s.val('dob'));
    if (d == null) return '';
    final n = s.now();
    var a = n.year - d.year;
    if (n.month < d.month || (n.month == d.month && n.day < d.day)) a--;
    return a < 0 ? '' : '$a';
  }

  static String _yearsInOperation(AppState s) {
    final st = s.start;
    if (st == null) return '';
    final n = s.now();
    final y = n.year - st.$1 - (n.month < st.$2 ? 1 : 0);
    return '${y < 0 ? 0 : y}';
  }

  /// Annex D asks Permanent, Temporary, On-call or Seasonal.
  static String _planStatus(String? s) => switch (s) {
        'Regular' => 'Permanent',
        'Contract' => 'Temporary',
        'Part-time' => 'On-call',
        'Seasonal' => 'Seasonal',
        _ => s ?? '',
      };

  static String _ownership(String own) => switch (own) {
        'Only me' => 'Single proprietorship',
        'Me and partners' => 'Partnership',
        '' => '',
        _ => 'Others',
      };

  // ---------------- Annex A · Application form ----------------

  static (Map<String, String>, Set<String>) annexA(AppState s) {
    final w = s.rows('workers');
    int count(bool Function(Map<String, String>) f) => w.where(f).length;
    final home = _home(s), biz = _biz(s);
    final y = latestYear(s);
    final inc = y == null ? const <String, String>{} : s.statementValues(y, StatementType.income);
    final bs = y == null ? const <String, String>{} : s.statementValues(y, StatementType.balance);
    final products = fit(s.rows('products').map((p) => p['name'] ?? '').where((x) => x.isNotEmpty).toList(), 5);
    final name = fullName(s);
    final values = <String, String>{
      'last': s.val('ln'), 'first': s.val('fn'), 'middle': s.val('mn'),
      'h_street': home[0], 'h_brgy': home[1], 'h_town': home[2], 'h_prov': home[3],
      'dob': _dobText(s.val('dob')), 'age': _age(s),
      'contact': mobile(s.data.mobile), 'fb': s.val('fb'), 'email': s.val('em'), 'tin': s.val('tin'), 'bank': s.val('bank'),
      'business': s.val('bn'),
      'b_street': biz[0], 'b_brgy': biz[1], 'b_town': biz[2], 'b_prov': biz[3],
      'years_op': _yearsInOperation(s),
      'emp_m': w.isEmpty ? '' : '${count((x) => x['sex'] == 'Male')}',
      'emp_f': w.isEmpty ? '' : '${count((x) => x['sex'] == 'Female')}',
      'emp_total': w.isEmpty ? '' : '${w.length}',
      'st_perm': w.isEmpty ? '' : '${count((x) => x['status'] == 'Regular')}',
      'st_contract': w.isEmpty ? '' : '${count((x) => x['status'] == 'Contract')}',
      'st_casual': w.isEmpty ? '' : '${count((x) => x['status'] == 'Part-time')}',
      'st_seasonal': w.isEmpty ? '' : '${count((x) => x['status'] == 'Seasonal')}',
      'st_other': w.isEmpty ? '' : '${count((x) => x['status'] == 'Other')}',
      for (var i = 0; i < 5; i++) 'prod${i + 1}': products[i],
      'capital': money(bs['capb']),
      'gross_sales': money(inc['sales']),
      'net_assets': money(bs['tcap']),
      'loan': money(s.val('la')),
      'full_name': name,
      'home_address': _join(home),
      'full_name_sign': name.toUpperCase(),
    };
    final flags = <String>{
      if (const {'1st': 'd1', '2nd': 'd2', '3rd': 'd3', '4th': 'd4', '5th': 'd5'}[s.one('dist')] case final d?) d,
      if (s.one('sex') == 'Male') 'male',
      if (s.one('sex') == 'Female') 'female',
      if (const {'Single': 'single', 'Married': 'married', 'Widowed': 'widow', 'Separated': 'separated'}[s.one('civ')] case final c?) c,
      if (s.reqStatus('permit') != 'none') 'reg_mayor',
      if (s.one('bt').isNotEmpty) switch (s.kind) { 'resell' => 'type_trading', 'service' => 'type_service', _ => 'type_mfg' },
      if (const {'Only me': 'own_single', 'Me and partners': 'own_partner', 'Other': 'own_other'}[s.one('own')] case final o?) o,
    };
    return (values, flags);
  }

  // ---------------- Annex C · Certificate of Residency and Business Operation ----------------

  static (Map<String, String>, Set<String>) annexC(AppState s) {
    final st = s.start;
    final values = <String, String>{
      'brgy': s.val('a2'),
      'owner': fullName(s),
      'resident_since': s.val('since'),
      'business': s.val('bn'),
      'operating_since': st == null ? '' : '${_months[(st.$2 - 1).clamp(0, 11).toInt()]} ${st.$1}',
    };
    final flags = <String>{
      if (s.one('cr') == 'Close for 1 month or more') 'closed',
      if (s.one('cr') == 'Lose at least 1/5 of sales for 2 months') 'lost_sales',
    };
    return (values, flags);
  }

  // ---------------- Annex D · Business plan ----------------

  static (Map<String, String>, Set<String>) annexD(AppState s) {
    final kind = s.kind;
    final products = s.rows('products');
    final prices = fit([
      for (final p in products) (p['name'] ?? '') + ((p['unit'] ?? '').isEmpty ? '' : ' (${p['unit']})'),
    ], 5);
    final priceVals = fit([for (final p in products) money(p['price'])], 5);
    final raw = s.rows('raw_$kind');
    final rawNames = fit([
      for (final r in raw) (r['name'] ?? '') + ((r['qty'] ?? '').isEmpty ? '' : ' (${r['qty']} ${r['unit'] ?? ''})'.replaceAll(' )', ')')),
    ], 7);
    final rawSrc = fit([for (final r in raw) r['source'] ?? ''], 7);
    final tools = fit(s.rows('tools_$kind').map((t) => t['name'] ?? '').where((x) => x.isNotEmpty).toList(), 5);
    final w = s.rows('workers');
    final empName = fit([for (final x in w) x['name'] ?? ''], 5);
    final empWork = fit([for (final x in w) x['work'] ?? ''], 5);
    final empStatus = fit([for (final x in w) _planStatus(x['status'])], 5);

    final materials = raw.isEmpty ? null : listTotal(raw, qtyTimesPrice);
    final labor = amt(s.val('lab_$kind'));
    final ovhRows = s.rows('ovh_$kind');
    final overhead = ovhRows.isEmpty ? null : listTotal(ovhRows, costOf);
    final anyCost = materials != null || labor != null || overhead != null;
    final total = anyCost ? (materials ?? 0) + (labor ?? 0) + (overhead ?? 0) : null;
    final units = amt(s.val('units_$kind'));

    final values = <String, String>{
      'project': s.val('pj'),
      'company': s.val('bn'),
      'address': _join(_biz(s)),
      'nature': s.one('bt').isEmpty ? '' : switch (kind) { 'resell' => 'Trading', 'service' => 'Service', _ => 'Manufacturing / Processing' },
      'form': _ownership(s.one('own')),
      'owner': fullName(s),
      'contact': mobile(s.data.mobile),
      'description': s.val('bd'),
      'product_desc': s.val('pd'),
      'target_market': s.sel('tm').join(', '),
      'market_area': s.sel('ma').join(', '),
      'media': s.sel('md').join(', '),
      for (var i = 0; i < 5; i++) 'price${i + 1}_name': prices[i],
      for (var i = 0; i < 5; i++) 'price${i + 1}': priceVals[i],
      for (var i = 0; i < 7; i++) 'raw${i + 1}': rawNames[i],
      for (var i = 0; i < 7; i++) 'raw${i + 1}_src': rawSrc[i],
      for (var i = 0; i < 5; i++) 'tool${i + 1}': tools[i],
      'pc_materials': moneyOf(materials),
      'pc_labor': moneyOf(labor),
      'pc_overhead': moneyOf(overhead),
      'pc_total': moneyOf(total),
      'pc_units': s.val('units_$kind'),
      'pc_per_unit': total == null || units == null || units == 0 ? '' : moneyOf(total / units),
      'experience': s.val('exp'),
      for (var i = 0; i < 5; i++) 'emp${i + 1}': empName[i],
      for (var i = 0; i < 5; i++) 'emp${i + 1}_work': empWork[i],
      for (var i = 0; i < 5; i++) 'emp${i + 1}_status': empStatus[i],
      'emp_total': '${w.length}',
      'loan': s.val('la').trim().isEmpty ? '' : 'Php ${money(s.val('la'))}',
      'sales': money(s.val('es')),
      'expenses': money(s.val('ex')),
      'gross_income': money(s.val('gi')),
      'net_income': money(s.val('ni')),
    };
    return (values, <String>{});
  }
}
