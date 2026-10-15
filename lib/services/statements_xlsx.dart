import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:share_plus/share_plus.dart';

import '../logic/format.dart';
import '../logic/statement_layout.dart';
import '../logic/statements.dart';
import '../state/app_state.dart';
import 'pdf_service.dart';

/// The financial statements as an Excel file, in the layout of the OLEDIPO
/// sample (FINANCIAL STATEMENT.xlsx): one sheet, Income statement, Cash flow
/// and Balance sheet one under the other (one printed page each), every year
/// side by side, with the same formulas as the sample so the totals stay
/// right if someone edits a number in Excel. Always in English.
///
/// Written by hand (a .xlsx is a zip of XML files), so no extra package is
/// needed. `tool/statements/xlsx_twin.py` is the same writer in Python, used to
/// check the output in LibreOffice.
class StatementsXlsx {
  StatementsXlsx._();

  static const mime = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
  static const fileName = 'Financial-Statements.xlsx';

  static Future<void> share(AppState s) async {
    await Share.shareXFiles([XFile.fromData(build(s), name: fileName, mimeType: mime)], subject: 'Financial statements');
  }

  /// Column letters: 0 -> A, 25 -> Z, 26 -> AA.
  static String col(int n) {
    var s = '';
    var x = n + 1;
    while (x > 0) {
      final r = (x - 1) % 26;
      s = String.fromCharCode(65 + r) + s;
      x = (x - 1) ~/ 26;
    }
    return s;
  }

  static String _esc(String s) => s.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');

  static Uint8List build(AppState s) {
    final years = s.statementYears.isEmpty ? [s.now().year - 1] : s.statementYears;
    final n = years.length;
    final first = years.first, last = years.last;
    final lastCol = 3 + 2 * n - 1;
    final business = s.val('bn').trim().toUpperCase();
    final address = PdfService.businessAddress(s);
    final name = PdfService.fullNameOf(s);
    final role = s.one('sex') == 'Female' ? 'Proprietress' : 'Proprietor';

    final rows = <int, Map<int, String>>{};
    final merges = <String>[];
    final breaks = <int>[];
    final ref = <String, String>{}; // 'type|key|i' -> cell
    final layout = <(StatementType, int, FsRow)>[];

    void cell(int r, int c, String xml) => (rows[r] ??= {})[c] = xml;
    void text(int r, int c, String t, int style) =>
        cell(r, c, '<c r="${col(c)}$r" s="$style" t="inlineStr"><is><t xml:space="preserve">${_esc(t)}</t></is></c>');
    void merged(int r) => merges.add('A$r:${col(lastCol)}$r');

    var r = 1;
    for (final t in StatementType.values) {
      if (r > 1) breaks.add(r - 1);
      text(r, 0, business, 2);
      merged(r);
      r += 1;
      text(r, 0, address, 3);
      merged(r);
      r += 2;
      text(r, 0, fsTitle(t), 4);
      merged(r);
      r += 1;
      text(r, 0, 'For the Period Ended December 31, $last', 5);
      merged(r);
      r += 2;
      for (var i = 0; i < n; i++) {
        cell(r, 4 + 2 * i, '<c r="${col(4 + 2 * i)}$r" s="9"><v>${years[i]}</v></c>');
      }
      r += 2;
      for (final row in fsRows(t, first)) {
        if (row.isSpace) {
          r += 1;
          continue;
        }
        if (row.side.isNotEmpty) text(r, 0, row.side, 1);
        text(r, row.level, row.label, row.bold ? 1 : 0);
        if (row.key != null) {
          for (var i = 0; i < n; i++) {
            ref['${t.name}|${row.key}|$i'] = '${col(4 + 2 * i)}$r';
          }
        }
        layout.add((t, r, row));
        r += 1;
      }
      r += 1;
      text(r, lastCol - 3, 'Certified by:', 0);
      r += 2;
      text(r, lastCol - 3, name, 15);
      text(r, lastCol - 2, '', 16);
      text(r, lastCol - 1, '', 16);
      r += 1;
      text(r, lastCol - 3, role, 0);
      r += 2;
    }

    String f(StatementType t, String key, int i) => ref['${t.name}|$key|$i']!;

    /// The sample's formula for a worked-out line, or null for a typed line.
    String? formula(StatementType t, String key, int i) {
      String c(String k) => f(t, k, i);
      switch (t) {
        case StatementType.income:
          return switch (key) {
            'tga' => 'SUM(${c('bi')},${c('pu')})',
            'tcs' => '${c('tga')}-${c('ei')}',
            'gi' => '${c('sales')}-${c('tcs')}',
            'toe' => 'SUM(${c('sw')},${c('pl')},${c('plw')},${c('tt')})',
            'ni' => '${c('gi')}-${c('toe')}',
            _ => null,
          };
        case StatementType.cashFlow:
          if (key == 'cb') return s.isCalculated(years[i], 'cb') && i > 0 ? f(t, 'ce', i - 1) : null;
          return switch (key) {
            'io' => f(StatementType.income, 'ni', i),
            'tc' => 'SUM(${c('cb')},${c('io')})',
            'ce' => '${c('tc')}-${c('cd')}',
            _ => null,
          };
        case StatementType.balance:
          if (key == 'capb') return s.isCalculated(years[i], 'capb') && i > 0 ? f(t, 'tcap', i - 1) : null;
          return switch (key) {
            'inv' => f(StatementType.income, 'ei', i),
            'tca' => 'SUM(${c('cash')},${c('inv')})',
            'tnca' => '${c('lb')}-${c('lbd')}+${c('cm')}-${c('cmd')}+${c('eq')}-${c('eqd')}',
            'ta' => '${c('tca')}+${c('tnca')}',
            'ani' => f(StatementType.income, 'ni', i),
            'capt' => 'SUM(${c('capb')},${c('ani')})',
            'dr' => '${c('capt')}-${c('ta')}',
            'tcap' => '${c('capt')}-${c('dr')}',
            'tlc' => c('tcap'),
            _ => null,
          };
      }
    }

    final values = {for (final t in StatementType.values) t: [for (final y in years) s.statementValues(y, t)]};
    for (final (t, row, fr) in layout) {
      final key = fr.key;
      if (key == null) continue;
      for (var i = 0; i < n; i++) {
        final c = 4 + 2 * i;
        final a = f(t, key, i);
        final style = switch (fr.rule) {
          Rule.none => fr.bold ? 11 : 10,
          Rule.single => fr.bold ? 13 : 12,
          Rule.double => 14,
        };
        final v = parseAmount(values[t]![i][key] ?? '');
        final vx = v == null ? '' : '<v>$v</v>';
        final fx = formula(t, key, i);
        if (fx != null) {
          cell(row, c, '<c r="$a" s="$style"><f>${_esc(fx)}</f>$vx</c>');
        } else if (v != null) {
          cell(row, c, '<c r="$a" s="$style"><v>$v</v></c>');
        } else {
          cell(row, c, '<c r="$a" s="$style"/>');
        }
        if (fr.peso) text(row, c - 1, 'P', 1);
      }
    }

    final sheet = StringBuffer()
      ..write('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>')
      ..write('<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">')
      ..write('<sheetPr><pageSetUpPr fitToPage="1"/></sheetPr><sheetViews><sheetView workbookViewId="0" showGridLines="0"/></sheetViews>')
      ..write('<sheetFormatPr defaultRowHeight="12" customHeight="1"/>')
      ..write('<cols><col min="1" max="1" width="3" customWidth="1"/><col min="2" max="2" width="3" customWidth="1"/><col min="3" max="3" width="32" customWidth="1"/>');
    for (var i = 0; i < n; i++) {
      sheet.write('<col min="${4 + 2 * i}" max="${4 + 2 * i}" width="2.5" customWidth="1"/><col min="${5 + 2 * i}" max="${5 + 2 * i}" width="14" customWidth="1"/>');
    }
    sheet.write('</cols><sheetData>');
    for (final rr in rows.keys.toList()..sort()) {
      final cols = rows[rr]!.keys.toList()..sort();
      sheet.write('<row r="$rr">');
      for (final c in cols) {
        sheet.write(rows[rr]![c]);
      }
      sheet.write('</row>');
    }
    sheet
      ..write('</sheetData>')
      ..write('<mergeCells count="${merges.length}">${merges.map((m) => '<mergeCell ref="$m"/>').join()}</mergeCells>')
      ..write('<pageMargins left="0.5" right="0.5" top="0.6" bottom="0.6" header="0.3" footer="0.3"/>')
      ..write('<pageSetup paperSize="9" orientation="${n > 6 ? 'landscape' : 'portrait'}" fitToWidth="1" fitToHeight="0"/>')
      ..write('<rowBreaks count="${breaks.length}" manualBreakCount="${breaks.length}">${breaks.map((b) => '<brk id="$b" max="16383" man="1"/>').join()}</rowBreaks>')
      ..write('</worksheet>');

    final archive = Archive();
    void add(String path, String content) {
      final bytes = utf8.encode(content);
      archive.addFile(ArchiveFile(path, bytes.length, bytes));
    }

    add('[Content_Types].xml',
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/><Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/><Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/></Types>');
    add('_rels/.rels',
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/></Relationships>');
    add('xl/workbook.xml',
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets><sheet name="Financial Statements" sheetId="1" r:id="rId1"/></sheets><calcPr calcId="191029" fullCalcOnLoad="1"/></workbook>');
    add('xl/_rels/workbook.xml.rels',
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/><Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/></Relationships>');
    add('xl/styles.xml', _styles);
    add('xl/worksheets/sheet1.xml', sheet.toString());
    return Uint8List.fromList(ZipEncoder().encode(archive)!);
  }

  // Cell styles: 0 text, 1 bold, 2 business name, 3 address, 4 title, 5 period,
  // 9 year header, 10–14 amounts (plain, bold, underlined, bold underlined,
  // double underlined), 15–16 signature line.
  static const _styles = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
      '<numFmts count="1"><numFmt numFmtId="164" formatCode="#,##0.00_);(#,##0.00);&quot;-&quot;_)"/></numFmts>'
      '<fonts count="6"><font><sz val="9"/><name val="Calibri"/></font><font><b/><sz val="9"/><name val="Calibri"/></font><font><b/><sz val="8"/><name val="Calibri"/></font><font><i/><sz val="8"/><name val="Calibri"/></font><font><b/><sz val="12"/><name val="Calibri"/></font><font><sz val="11"/><name val="Calibri"/></font></fonts>'
      '<fills count="2"><fill><patternFill patternType="none"/></fill><fill><patternFill patternType="gray125"/></fill></fills>'
      '<borders count="4"><border><left/><right/><top/><bottom/><diagonal/></border><border><left/><right/><top/><bottom style="thin"/><diagonal/></border><border><left/><right/><top/><bottom style="double"/><diagonal/></border><border><left/><right/><top style="thin"/><bottom/><diagonal/></border></borders>'
      '<cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>'
      '<cellXfs count="17">'
      '<xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>'
      '<xf numFmtId="0" fontId="1" fillId="0" borderId="0" xfId="0" applyFont="1"/>'
      '<xf numFmtId="0" fontId="2" fillId="0" borderId="0" xfId="0" applyFont="1" applyAlignment="1"><alignment horizontal="center"/></xf>'
      '<xf numFmtId="0" fontId="3" fillId="0" borderId="0" xfId="0" applyFont="1" applyAlignment="1"><alignment horizontal="center"/></xf>'
      '<xf numFmtId="0" fontId="4" fillId="0" borderId="0" xfId="0" applyFont="1" applyAlignment="1"><alignment horizontal="center"/></xf>'
      '<xf numFmtId="0" fontId="5" fillId="0" borderId="0" xfId="0" applyFont="1" applyAlignment="1"><alignment horizontal="center"/></xf>'
      '<xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>'
      '<xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>'
      '<xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>'
      '<xf numFmtId="0" fontId="1" fillId="0" borderId="1" xfId="0" applyFont="1" applyBorder="1" applyAlignment="1"><alignment horizontal="center"/></xf>'
      '<xf numFmtId="164" fontId="0" fillId="0" borderId="0" xfId="0" applyNumberFormat="1"/>'
      '<xf numFmtId="164" fontId="1" fillId="0" borderId="0" xfId="0" applyNumberFormat="1" applyFont="1"/>'
      '<xf numFmtId="164" fontId="0" fillId="0" borderId="1" xfId="0" applyNumberFormat="1" applyBorder="1"/>'
      '<xf numFmtId="164" fontId="1" fillId="0" borderId="1" xfId="0" applyNumberFormat="1" applyFont="1" applyBorder="1"/>'
      '<xf numFmtId="164" fontId="1" fillId="0" borderId="2" xfId="0" applyNumberFormat="1" applyFont="1" applyBorder="1"/>'
      '<xf numFmtId="0" fontId="1" fillId="0" borderId="3" xfId="0" applyFont="1" applyBorder="1"/>'
      '<xf numFmtId="0" fontId="0" fillId="0" borderId="3" xfId="0" applyBorder="1"/>'
      '</cellXfs>'
      '<cellStyles count="1"><cellStyle name="Normal" xfId="0" builtinId="0"/></cellStyles>'
      '</styleSheet>';
}
