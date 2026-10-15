import 'statements.dart';

/// The printed layout of the financial statements, row by row, copied from
/// the OLEDIPO sample (FINANCIAL STATEMENT.xlsx, "sample FS"): all years side
/// by side, one statement per page. Used by both the PDF and the Excel file,
/// so they always match. Printed documents are always in English.

/// What is drawn under the amounts of a row.
enum Rule { none, single, double }

class FsRow {
  /// Text of the row. Empty for a spacer row.
  final String label;

  /// Statement line key, or null for a heading or spacer.
  final String? key;

  /// 0 = column A (main headings), 1 = column B, 2 = column C (items).
  final int level;
  final bool bold;

  /// Show the "P" (peso) sign before the amounts.
  final bool peso;
  final Rule rule;

  /// Small label in column A on the same row (e.g. "Capital").
  final String side;

  const FsRow(this.label, this.key, {this.level = 2, this.bold = false, this.peso = false, this.rule = Rule.none, this.side = ''});
  const FsRow.space()
      : label = '',
        key = null,
        level = 0,
        bold = false,
        peso = false,
        rule = Rule.none,
        side = '';
  const FsRow.head(this.label, {this.level = 0})
      : key = null,
        bold = true,
        peso = false,
        rule = Rule.none,
        side = '';

  bool get isSpace => label.isEmpty && key == null;
}

String fsTitle(StatementType t) => switch (t) {
      StatementType.income => 'INCOME STATEMENT',
      StatementType.cashFlow => 'CASH FLOW STATEMENT',
      StatementType.balance => 'BALANCE SHEET',
    };

List<FsRow> fsRows(StatementType t, int firstYear) => switch (t) {
      StatementType.income => const [
          FsRow('SALES', 'sales', level: 0, bold: true, peso: true, rule: Rule.single),
          FsRow.space(),
          FsRow.head('Less: Cost of Sales'),
          FsRow('Beginning Inventory', 'bi'),
          FsRow('Purchases', 'pu', rule: Rule.single),
          FsRow('Total Goods available for sale', 'tga', bold: true),
          FsRow('Ending Inventory', 'ei', rule: Rule.single),
          FsRow('Total Cost of Sales', 'tcs', bold: true, rule: Rule.single),
          FsRow.space(),
          FsRow('GROSS INCOME', 'gi', level: 0, bold: true, peso: true, rule: Rule.single),
          FsRow.space(),
          FsRow.head('LESS: Operating Expenses'),
          FsRow('Salaries and Wages', 'sw', peso: true),
          FsRow('Permits and Licenses', 'pl'),
          FsRow('Power, Light, Water', 'plw'),
          FsRow('Travel and Transportation', 'tt', rule: Rule.single),
          FsRow('Total Operating Expenses', 'toe', level: 0, bold: true, peso: true, rule: Rule.single),
          FsRow.space(),
          FsRow('NET INCOME', 'ni', level: 0, bold: true, peso: true, rule: Rule.double),
        ],
      StatementType.cashFlow => [
          FsRow('Cash Beginning January $firstYear', 'cb', level: 0, rule: Rule.single),
          const FsRow.head('Add:'),
          const FsRow('Income from operation', 'io', rule: Rule.single),
          const FsRow('Total Cash', 'tc', level: 0, bold: true, peso: true, rule: Rule.single),
          const FsRow.space(),
          const FsRow('Less: Cash Disbursements', 'cd', level: 0, rule: Rule.single),
          const FsRow.space(),
          const FsRow('Cash Ending:', 'ce', level: 0, bold: true, rule: Rule.double),
        ],
      StatementType.balance => const [
          FsRow.head('ASSETS'),
          FsRow.head('Current Assets', level: 1),
          FsRow('Cash on Hand & in Bank', 'cash', peso: true),
          FsRow('Merchandise Inventory', 'inv', rule: Rule.single),
          FsRow('Total Current Assets', 'tca', level: 1, bold: true, peso: true, rule: Rule.single),
          FsRow.space(),
          FsRow.head('Non - Current Assets', level: 1),
          FsRow('Lot, Building', 'lb', peso: true),
          FsRow('Accum. Depreciation', 'lbd'),
          FsRow('Cars, Motorcycle', 'cm'),
          FsRow('Accum. Depreciation', 'cmd'),
          FsRow('Equipment', 'eq'),
          FsRow('Accum. Depreciation', 'eqd', rule: Rule.single),
          FsRow('Total Non - Current Assets', 'tnca', level: 1, bold: true, rule: Rule.single),
          FsRow.space(),
          FsRow('TOTAL ASSETS', 'ta', level: 0, bold: true, peso: true, rule: Rule.double),
          FsRow.space(),
          FsRow.head('LIABILITIES & CAPITAL'),
          FsRow.space(),
          FsRow('Capital, Beg.', 'capb', side: 'Capital'),
          FsRow('Accum. Net Income', 'ani'),
          FsRow('Total', 'capt'),
          FsRow('Less: Drawings', 'dr', rule: Rule.single),
          FsRow('Total Capital', 'tcap', bold: true, peso: true, rule: Rule.single),
          FsRow.space(),
          FsRow('TOTAL LIABILITIES & CAPITAL', 'tlc', bold: true, rule: Rule.double),
        ],
    };

/// `1234.5` -> `1,234.50`; negatives in brackets; zero as "-" (as in the sample).
String fsAmount(double? v) {
  if (v == null) return '';
  if (v.abs() < 0.005) return '-';
  final cents = (v.abs() * 100).round();
  final whole = (cents ~/ 100).toString();
  final b = StringBuffer();
  for (var i = 0; i < whole.length; i++) {
    if (i > 0 && (whole.length - i) % 3 == 0) b.write(',');
    b.write(whole[i]);
  }
  final s = '$b.${(cents % 100).toString().padLeft(2, '0')}';
  return v < 0 ? '($s)' : s;
}
