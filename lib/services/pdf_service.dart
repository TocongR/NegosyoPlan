import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../logic/checks.dart';
import '../logic/format.dart';
import '../logic/statement_layout.dart';
import '../logic/statements.dart';
import '../state/app_state.dart';

/// The documents NegosyoPlan makes, all on the phone and offline.
/// Financial statements are printed exactly as the owner typed them.
enum DocType { plan, annexA, annexC, income, cashFlow, balance, passport, checklist }

extension DocTypeInfo on DocType {
  String get title => switch (this) {
        DocType.plan => 'Business plan (Annex D)',
        DocType.annexA => 'Application form (Annex A)',
        DocType.annexC => 'Certificate of Residency and Business Operation (Annex C)',
        DocType.income => 'Income statement',
        DocType.cashFlow => 'Cash flow statement',
        DocType.balance => 'Balance sheet',
        DocType.passport => 'Enterprise Passport',
        DocType.checklist => 'Requirements and training checklist',
      };

  String get fileName => '${title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-')}.pdf';

  StatementType? get statement => switch (this) {
        DocType.income => StatementType.income,
        DocType.cashFlow => StatementType.cashFlow,
        DocType.balance => StatementType.balance,
        _ => null,
      };

  static DocType? byName(String? name) {
    for (final d in DocType.values) {
      if (d.name == name) return d;
    }
    return null;
  }
}

class PdfService {
  PdfService._();

  static const blank = '[Blank — not filled in]';
  static const disclaimer = 'Prepared with NegosyoPlan. Amounts entered by the owner. This does not guarantee loan approval. '
      'Approval is decided by the EMBRACE TWG. Professional review of financial statements is recommended.';

  static pw.ThemeData? _theme;

  static Future<pw.ThemeData> loadTheme() async {
    if (_theme != null) return _theme!;
    Future<pw.Font> font(String path) async => pw.Font.ttf(await rootBundle.load(path));
    final regular = await font('assets/fonts/AtkinsonHyperlegible-Regular.ttf');
    final bold = await font('assets/fonts/AtkinsonHyperlegible-Bold.ttf');
    // DejaVu covers the peso sign (₱) and ✓, which Atkinson Hyperlegible lacks.
    final dv = await font('assets/fonts/DejaVuSans.ttf');
    final dvBold = await font('assets/fonts/DejaVuSans-Bold.ttf');
    _theme = pw.ThemeData.withFont(base: regular, bold: bold, fontFallback: [dv, dvBold]);
    return _theme!;
  }

  /// How many blanks a document will show in red.
  static int blanks(AppState s, DocType t) {
    final st = t.statement;
    if (st != null) {
      return s.statementYears.fold(0, (n, y) => n + (s.progress(y, st) == Progress.empty ? 0 : s.blankLines(y, st)) + (s.progress(y, st) == Progress.empty ? 1 : 0));
    }
    return switch (t) {
      DocType.plan => ['bn', 'pj', 'bd', 'pd', 'exp', 'es', 'ex', 'gi', 'ni'].where((k) => s.val(k).trim().isEmpty).length,
      DocType.annexA => ['ln', 'fn', 'a2', 'a3', 'dob', 'bn', 'la'].where((k) => s.val(k).trim().isEmpty).length,
      DocType.annexC => ['since', 'os'].where((k) => s.val(k).trim().isEmpty).length,
      _ => 0,
    };
  }

  static Future<Uint8List> build(AppState s, DocType t) async {
    if (t.statement != null) return buildStatement(s, t.statement!);
    final doc = pw.Document(theme: await loadTheme(), title: t.title, author: 'NegosyoPlan');
    final business = s.val('bn').isEmpty ? 'Your business' : s.val('bn');
    final pages = switch (t) {
      DocType.plan => _plan(s),
      DocType.annexA => _annexA(s),
      DocType.annexC => _annexC(s),
      DocType.income || DocType.cashFlow || DocType.balance => const <pw.Widget>[],
      DocType.passport => _passport(s),
      DocType.checklist => _checklist(s),
    };
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(48, 48, 48, 56),
      header: (c) => pw.Container(
        margin: const pw.EdgeInsets.only(bottom: 14),
        child: pw.Row(children: [
          pw.Expanded(child: pw.Text('$business · ${t.title}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700))),
          pw.Text('EMBRACE Program', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
        ]),
      ),
      footer: (c) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Divider(color: PdfColors.grey400),
        pw.Text(disclaimer, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
        pw.Align(alignment: pw.Alignment.centerRight, child: pw.Text('Page ${c.pageNumber} of ${c.pagesCount}', style: const pw.TextStyle(fontSize: 8))),
      ]),
      build: (_) => [
        pw.Text(t.title, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColor.fromInt(0xFF0A5763))),
        pw.SizedBox(height: 12),
        ...pages,
      ],
    ));
    return doc.save();
  }

  // ---------------- helpers ----------------

  static pw.Widget _v(String v) => v.trim().isEmpty
      ? pw.Text(blank, style: pw.TextStyle(color: PdfColors.red800, fontWeight: pw.FontWeight.bold))
      : pw.Text(v);

  static pw.Widget _kv(String k, String v) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 3),
        child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.SizedBox(width: 190, child: pw.Text(k, style: const pw.TextStyle(color: PdfColors.grey800))),
          pw.Expanded(child: _v(v)),
        ]),
      );

  static pw.Widget _h(String t) => pw.Padding(
        padding: const pw.EdgeInsets.only(top: 14, bottom: 6),
        child: pw.Text(t, style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
      );

  static pw.Widget _table(List<String> head, List<List<String>> rows) => pw.TableHelper.fromTextArray(
        headers: head,
        data: rows.isEmpty ? [List.filled(head.length, blank)] : rows,
        headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
        headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
        cellStyle: const pw.TextStyle(fontSize: 10),
        cellAlignment: pw.Alignment.centerLeft,
      );

  static String _p(String? v) => (v ?? '').trim().isEmpty ? '' : peso(amt(v));

  static String _fullName(AppState s) => [s.val('fn'), s.val('mn'), s.val('ln')].where((x) => x.isNotEmpty).join(' ');
  static String _home(AppState s) => [s.val('a1'), s.val('a2'), s.val('a3'), s.val('a4'), s.val('a5')].where((x) => x.isNotEmpty).join(', ');
  static String _bizAddr(AppState s) => s.one('loc') == 'Somewhere else'
      ? [s.val('b1'), s.val('b2'), s.val('b3'), s.val('b4'), s.val('b5')].where((x) => x.isNotEmpty).join(', ')
      : _home(s);

  static int? _latestYear(AppState s) {
    final ys = s.statementYears;
    for (final y in ys.reversed) {
      if (s.progress(y, StatementType.income) != Progress.empty || s.progress(y, StatementType.balance) != Progress.empty) return y;
    }
    return ys.isEmpty ? null : ys.last;
  }

  // ---------------- documents ----------------

  // ---------------- financial statements (OLEDIPO sample format) ----------------

  /// Font for the statements: plain and narrow, like the Excel sample.
  static Future<pw.ThemeData> _fsTheme() async => loadTheme();

  /// One statement, every year side by side, in the layout of the OLEDIPO
  /// sample (FINANCIAL STATEMENT.xlsx). Always in English.
  static Future<Uint8List> buildStatement(AppState s, StatementType t) async {
    final doc = pw.Document(theme: await _fsTheme(), title: fsTitle(t), author: 'NegosyoPlan');
    _statementPage(doc, s, t);
    return doc.save();
  }

  /// All three statements in one PDF, one page each (same as the Excel file).
  static Future<Uint8List> buildAllStatements(AppState s) async {
    final doc = pw.Document(theme: await _fsTheme(), title: 'Financial Statements', author: 'NegosyoPlan');
    for (final t in StatementType.values) {
      _statementPage(doc, s, t);
    }
    return doc.save();
  }

  static void _statementPage(pw.Document doc, AppState s, StatementType t) {
    final years = s.statementYears;
    final wide = years.length > 6;
    final format = wide ? PdfPageFormat.a4.landscape : PdfPageFormat.a4;
    const margin = 36.0;
    final avail = format.width - margin * 2;
    final n = years.isEmpty ? 1 : years.length;
    const pW = 9.0;
    final amtW = ((avail - 150) / n - pW).clamp(44.0, 74.0).toDouble();
    final labelW = avail - n * (pW + amtW);
    final fs = n > 5 ? 7.0 : 8.0;
    final figs = {for (final y in years) y: s.statementValues(y, t)};
    final first = years.isEmpty ? s.now().year - 1 : years.first;
    final last = years.isEmpty ? s.now().year - 1 : years.last;
    final owner = s.one('sex') == 'Female' ? 'Proprietress' : 'Proprietor';

    pw.TextStyle st({bool bold = false, double? size}) => pw.TextStyle(fontSize: size ?? fs, fontWeight: bold ? pw.FontWeight.bold : null);

    pw.Widget amountCell(String text, {bool bold = false, Rule rule = Rule.none}) {
      const line = pw.BorderSide(width: 0.7);
      final inner = pw.Container(
        width: amtW,
        padding: const pw.EdgeInsets.only(top: 1.5, bottom: 1.5, right: 1),
        decoration: rule == Rule.none ? null : const pw.BoxDecoration(border: pw.Border(bottom: line)),
        child: pw.Text(text, textAlign: pw.TextAlign.right, style: st(bold: bold)),
      );
      if (rule != Rule.double) return inner;
      // Double underline: a second line just under the first.
      return pw.Container(
        padding: const pw.EdgeInsets.only(bottom: 1.2),
        decoration: const pw.BoxDecoration(border: pw.Border(bottom: line)),
        child: inner,
      );
    }

    pw.Widget row(FsRow r) {
      if (r.isSpace) return pw.SizedBox(height: fs * 1.1);
      final indent = [0.0, 10.0, 26.0][r.level];
      final cells = <pw.Widget>[
        pw.SizedBox(
          width: labelW,
          child: pw.Row(children: [
            if (r.side.isNotEmpty) pw.SizedBox(width: 26, child: pw.Text(r.side, style: st(bold: true))) else pw.SizedBox(width: indent),
            pw.Expanded(child: pw.Text(r.label, style: st(bold: r.bold))),
          ]),
        ),
      ];
      for (var i = 0; i < years.length; i++) {
        final v = r.key == null ? null : figs[years[i]]![r.key];
        final shown = r.key == null ? '' : fsAmount(parseAmount(v ?? ''));
        cells.add(pw.SizedBox(width: pW, child: pw.Text(r.peso && shown.isNotEmpty ? 'P' : '', style: st(bold: true))));
        cells.add(r.key == null ? pw.SizedBox(width: amtW) : amountCell(shown, bold: r.bold, rule: r.rule));
      }
      return pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.end, children: cells);
    }

    final business = s.val('bn').trim().isEmpty ? '' : s.val('bn').toUpperCase();
    final address = _bizAddr(s);
    doc.addPage(pw.Page(
      pageFormat: format,
      margin: const pw.EdgeInsets.all(margin),
      build: (_) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
        pw.Center(child: pw.Text(business, style: st(bold: true, size: 7.5))),
        pw.SizedBox(height: 4),
        pw.Center(child: pw.Text(address, style: pw.TextStyle(fontSize: 7, fontStyle: pw.FontStyle.italic))),
        pw.SizedBox(height: 18),
        pw.Center(child: pw.Text(fsTitle(t), style: st(bold: true, size: 10))),
        pw.Center(child: pw.Text('For the Period Ended December 31, $last', style: st(size: 9.5))),
        pw.SizedBox(height: 24),
        // Year header
        pw.Row(children: [
          pw.SizedBox(width: labelW),
          for (final y in years) ...[
            pw.SizedBox(width: pW),
            pw.Container(
              width: amtW,
              padding: const pw.EdgeInsets.only(bottom: 2),
              decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(width: 0.7))),
              child: pw.Text('$y', textAlign: pw.TextAlign.center, style: st(bold: true)),
            ),
          ],
        ]),
        pw.SizedBox(height: 8),
        for (final r in fsRows(t, first)) row(r),
        pw.SizedBox(height: 30),
        pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.SizedBox(
            width: 170,
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text('Certified by:', style: st(size: 8)),
              pw.SizedBox(height: 30),
              pw.Container(
                width: 150,
                padding: const pw.EdgeInsets.only(top: 2),
                decoration: const pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(width: 0.7))),
                child: pw.Column(children: [
                  pw.Text(fullNameOf(s), style: st(size: 7.5, bold: true)),
                  pw.Text(owner, style: st(size: 8)),
                ]),
              ),
            ]),
          ),
        ),
      ]),
    ));
  }

  static String fullNameOf(AppState s) => _fullName(s);
  static String businessAddress(AppState s) => _bizAddr(s);

  static List<pw.Widget> _plan(AppState s) {
    final kind = s.kind;
    final raw = s.rows('raw_$kind');
    final labor = amt(s.val('lab_$kind')) ?? 0;
    final materials = listTotal(raw, qtyTimesPrice);
    final overhead = listTotal(s.rows('ovh_$kind'), costOf);
    final total = materials + labor + overhead;
    final units = amt(s.val('units_$kind'));
    return [
      _h('1. Background of the business'),
      _kv('1.1 Name of project', s.val('pj')),
      _kv('1.2 Name of company', s.val('bn')),
      _kv('1.3 Business address', _bizAddr(s)),
      _kv('1.4 Nature of business', s.one('bt')),
      _kv('1.5 Form of business', s.one('own')),
      _kv('1.6 Name of owner', _fullName(s)),
      _kv('1.7 Contact number', s.data.mobile),
      _kv('1.8 Brief description', s.val('bd')),
      _h('2. Marketing plan'),
      _kv('2.1 Description of the product', s.val('pd')),
      _kv('2.2 Target market / main customers', s.sel('tm').join(', ')),
      _kv('2.3 Market area', s.sel('ma').join(', ')),
      _kv('2.4 Media used to promote', s.sel('md').join(', ')),
      pw.SizedBox(height: 6),
      _table(['2.5 Product', 'Unit price'], [for (final p in s.rows('products')) [p['name'] ?? '', '${_p(p['price'])}${(p['unit'] ?? '').isEmpty ? '' : ' per ${p['unit']}'}']]),
      _h('3. Production plan (one production cycle)'),
      _table(['3.1 Raw materials', 'Source', 'Quantity', 'Cost'], [
        for (final r in raw) [r['name'] ?? '', r['source'] ?? '', '${r['qty'] ?? ''} ${r['unit'] ?? ''}', peso(qtyTimesPrice(r))]
      ]),
      pw.SizedBox(height: 6),
      _kv('3.2 Tools / equipment used', s.rows('tools_$kind').map((t) => t['name'] ?? '').join(', ')),
      pw.SizedBox(height: 6),
      _table(['3.3 Production cost', 'Cost'], [
        ['Materials', peso(materials)],
        ['Labor', s.val('lab_$kind').isEmpty ? blank : peso(labor)],
        ['Mfg. overhead (${s.rows('ovh_$kind').map((o) => o['name']).join(', ')})', peso(overhead)],
        ['Total production cost', peso(total)],
        ['Divide by: no. of units produced', s.val('units_$kind').isEmpty ? blank : s.val('units_$kind')],
        ['Production cost / unit', units == null || units == 0 ? blank : peso(total / units)],
      ]),
      _h('4. Organization and management plan'),
      _kv('4.1 Experience and qualification', s.val('exp')),
      pw.SizedBox(height: 6),
      _table(['4.2 Name of employee', 'Nature of work', 'Status of employment'], [
        for (final w in s.rows('workers')) [w['name'] ?? '', w['work'] ?? '', w['status'] ?? '']
      ]),
      _kv('Total no. of employees', '${s.rows('workers').length}'),
      _h('5. Financial plan'),
      _kv('Amount of loan', _p(s.val('la'))),
      pw.SizedBox(height: 6),
      _h('Financial projection (as typed by the owner)'),
      _kv('Expected annual sales', _p(s.val('es'))),
      _kv('Expected annual expenses', _p(s.val('ex'))),
      _kv('Expected annual gross income', _p(s.val('gi'))),
      _kv('Expected annual net income', _p(s.val('ni'))),
    ];
  }

  static List<pw.Widget> _annexA(AppState s) {
    final w = s.rows('workers');
    int c(bool Function(Map<String, String>) f) => w.where(f).length;
    final y = _latestYear(s);
    final inc = y == null ? <String, String>{} : s.statementValues(y, StatementType.income);
    final bs = y == null ? <String, String>{} : s.statementValues(y, StatementType.balance);
    final st = s.start;
    final yearsOp = st == null ? '' : '${(s.now().year - st.$1 - (s.now().month < st.$2 ? 1 : 0)).clamp(0, 99)}';
    return [
      _h('A. Personal profile'),
      _kv('I. Name (last, first, middle)', [s.val('ln'), s.val('fn'), s.val('mn')].where((x) => x.isNotEmpty).join(', ')),
      _kv('II. Address', _home(s)),
      _kv('III. District', s.one('dist')),
      _kv('IV. Date of birth', s.val('dob')),
      _kv('VI. Sex', s.one('sex')),
      _kv('VII. Contact no.', s.data.mobile),
      _kv('VIII. Facebook account', s.val('fb')),
      _kv('IX. Email address', s.val('em')),
      _kv('X. TIN', s.val('tin')),
      _kv('XI. Bank affiliations', s.val('bank')),
      _kv('XII. Civil status', s.one('civ')),
      _h('B. Business profile'),
      _kv('XIII. Name of business', s.val('bn')),
      _kv('XIV. Principal address', _bizAddr(s)),
      _kv('XV. No. of years in operation', yearsOp),
      _kv('XVI. No. of employees', '${w.length} (male ${c((x) => x['sex'] == 'Male')}, female ${c((x) => x['sex'] == 'Female')})'),
      _kv('XVII. Employment status',
          'Permanent ${c((x) => x['status'] == 'Regular')} · Contractual ${c((x) => x['status'] == 'Contract')} · Casual ${c((x) => x['status'] == 'Part-time')} · Seasonal ${c((x) => x['status'] == 'Seasonal')} · Others ${c((x) => x['status'] == 'Other')}'),
      _kv('XVIII. Registration', s.reqStatus('permit') == 'none' ? '' : 'Business permit (PDF attached)'),
      _kv('XIX. Business type', switch (s.kind) { 'resell' => 'Trading', 'service' => 'Service', _ => 'Manufacturing / Processing' }),
      _kv('XX. Ownership', switch (s.one('own')) { 'Only me' => 'Single proprietorship', 'Me and partners' => 'Partnership', '' => '', _ => 'Others' }),
      _kv('XXI. Products / services', s.rows('products').map((p) => p['name']).join('; ')),
      _kv('XXX. Capital${y == null ? '' : ' ($y balance sheet: Capital, beginning)'}', _p(bs['capb'])),
      _kv('XXXI. Annual gross sales${y == null ? '' : ' ($y income statement: Sales)'}', _p(inc['sales'])),
      _kv('XXXII. Business net assets${y == null ? '' : ' ($y balance sheet: Total capital)'}', _p(bs['tcap'])),
      _h('C. Application details'),
      _kv('XXXIII. Amount of loan applied', _p(s.val('la'))),
      pw.SizedBox(height: 36),
      pw.Container(width: 260, decoration: const pw.BoxDecoration(border: pw.Border(top: pw.BorderSide())), padding: const pw.EdgeInsets.only(top: 4), child: pw.Text('Signature over printed name of beneficiary / date')),
    ];
  }

  static List<pw.Widget> _annexC(AppState s) {
    final name = _fullName(s);
    final brgy = s.val('a2');
    final st = s.start;
    final since = st == null ? '' : '${const ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'][(st.$2 - 1).clamp(0, 11).toInt()]} ${st.$1}';
    final crisis = s.one('cr');
    final ok = qualifiedWorkers(s);
    pw.Widget sign() => pw.Padding(
          padding: const pw.EdgeInsets.only(top: 30),
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text('Signed this ____ day of ______________ 20__ at ______________________, Iloilo, Philippines.'),
            pw.SizedBox(height: 30),
            pw.Container(width: 260, decoration: const pw.BoxDecoration(border: pw.Border(top: pw.BorderSide())), padding: const pw.EdgeInsets.only(top: 4), child: pw.Text('Signature over printed name of Brgy. Captain')),
          ]),
        );
    return [
      _h('Certificate of Residency'),
      pw.Text('I, ______________________________, a bonafide resident of ${brgy.isEmpty ? '__________' : brgy} and the concurrent Barangay Captain of ${brgy.isEmpty ? '__________' : brgy}, do hereby attest that:'),
      pw.SizedBox(height: 8),
      pw.Text('${name.isEmpty ? '______________' : name} is a resident of this barangay since ${s.val('since').isEmpty ? '__________' : s.val('since')}.'),
      sign(),
      pw.SizedBox(height: 30),
      _h('Certificate of Business Operation'),
      pw.Text('I, ______________________________, a bonafide resident of ${brgy.isEmpty ? '__________' : brgy} and the concurrent Barangay Captain of ${brgy.isEmpty ? '__________' : brgy}, do hereby depose and say:'),
      pw.SizedBox(height: 8),
      pw.Text('(1) That ${name.isEmpty ? '______________' : name} is the business owner of ${s.val('bn').isEmpty ? '______________' : s.val('bn')} operating within this barangay since ${since.isEmpty ? '__________' : since};'),
      pw.SizedBox(height: 6),
      pw.Text('(2) That his/her business suffered substantial losses due to either of the following:'),
      pw.Padding(
        padding: const pw.EdgeInsets.only(left: 18, top: 4),
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text('${crisis == 'Close for 1 month or more' ? '[✓]' : '[  ]'} Temporary closure for at least a month within the period of pandemic/crisis/emergency;'),
          pw.Text('${crisis == 'Lose at least 1/5 of sales for 2 months' ? '[✓]' : '[  ]'} At least twenty percent (20%) decrease in monthly revenues for 2 months within the period of pandemic/crisis/emergency based on the latest ITR / Financial Statement presented before me.'),
        ]),
      ),
      pw.SizedBox(height: 6),
      pw.Text('(3) That he/she has employed at least two (2) personnel, other than himself/herself, for a period of at least two (2) years prior to this issuance; and'),
      pw.Text('(4) That the employees referred above are permanent residents of the Province of Iloilo.'),
      pw.SizedBox(height: 6),
      pw.Text('Owner’s answers (for the Barangay Captain to check): $ok worker(s) with 2+ years who live in Iloilo.', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
      sign(),
    ];
  }

  static List<pw.Widget> _passport(AppState s) => [
        _h('You'),
        _kv('Name', _fullName(s)),
        _kv('Mobile', s.data.mobile),
        _kv('Living in the barangay since', s.val('since')),
        _kv('Experience', s.val('exp')),
        _h('Business'),
        _kv('Business name', s.val('bn')),
        _kv('Address', _bizAddr(s)),
        _kv('Started', s.val('os')),
        _kv('Kind of business', s.one('bt')),
        _kv('Workers', '${s.rows('workers').length}'),
        _h('Financial statements on file (typed by the owner)'),
        _table(['Year', 'Income statement', 'Cash flow', 'Balance sheet'], [
          for (final y in s.statementYears)
            ['$y', for (final t in StatementType.values) switch (s.progress(y, t)) { Progress.complete => 'Complete', Progress.partial => 'Partly typed', Progress.empty => 'Not added' }]
        ]),
        _h('Papers'),
        _kv('Business permit', _statusText(s.reqStatus('permit'))),
        _kv('Certificate of Residency and Business Operation', _statusText(s.reqStatus('annexC'))),
        for (final t in s.trainingFiles) _kv('Training: ${t.title}', '${[t.provider, t.date].where((x) => x.isNotEmpty).join(' · ')} · ${_statusText(t.status)}'),
      ];

  static String _statusText(String st) => switch (st) { 'verified' => 'Verified by OLEDIPO', 'sent' => 'Sent, waiting for check', 'saved' => 'PDF uploaded', _ => '' };

  static List<pw.Widget> _checklist(AppState s) => [
        _table(['Requirement', 'Status'], [
          ['Business permit', _statusText(s.reqStatus('permit')).isEmpty ? 'Not yet' : _statusText(s.reqStatus('permit'))],
          ['Certificate of Residency and Business Operation (Annex C)', _statusText(s.reqStatus('annexC')).isEmpty ? 'Not yet' : _statusText(s.reqStatus('annexC'))],
          for (final t in s.trainingFiles) ['Training certificate: ${t.title}', _statusText(t.status)],
        ]),
        _h('Still missing in the application'),
        for (final m in missingItems(s)) pw.Bullet(text: '${m.label} (${m.where})'),
      ];
}
