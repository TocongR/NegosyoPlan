// The lines of each financial statement, in the order of the OLEDIPO templates.
//
// The owner types the item lines. Totals (Total goods available, Gross income,
// Net income, Total assets…) are added up by the app from the typed lines —
// see [computeYear]. Blank item lines stay blank; they are never filled in.
import 'format.dart';

enum LineKind { heading, item, total, grandTotal }

class StatementLine {
  final String key;
  final String label;
  final String hint;
  final LineKind kind;

  /// Item sits under a heading (drawn indented).
  final bool indent;
  const StatementLine(this.key, this.label, {this.hint = '', this.kind = LineKind.item, this.indent = false});
  const StatementLine.heading(this.label)
      : key = '',
        hint = '',
        kind = LineKind.heading,
        indent = false;

  /// A line the owner may type (some are carried from last year; see
  /// [carriedKeys] and `AppState.isCalculated`).
  bool get isInput => kind != LineKind.heading && !isCalculated;

  /// A line the app always works out.
  bool get isCalculated => calculatedKeys.contains(key);
}

enum StatementType { income, cashFlow, balance }

extension StatementTypeInfo on StatementType {
  String get title => switch (this) {
        StatementType.income => 'Income statement',
        StatementType.cashFlow => 'Cash flow statement',
        StatementType.balance => 'Balance sheet',
      };

  /// The line shown on the year list when the statement is complete.
  (String, String) get headline => switch (this) {
        StatementType.income => ('ni', 'Net income'),
        StatementType.cashFlow => ('ce', 'Cash ending'),
        StatementType.balance => ('ta', 'Total assets'),
      };

  String get route => switch (this) {
        StatementType.income => '/statement/income',
        StatementType.cashFlow => '/statement/cashflow',
        StatementType.balance => '/statement/balance',
      };

  List<StatementLine> get lines => switch (this) {
        StatementType.income => incomeLines,
        StatementType.cashFlow => cashFlowLines,
        StatementType.balance => balanceLines,
      };
}

const incomeLines = <StatementLine>[
  StatementLine('sales', 'Sales', hint: 'All the money from selling during the year.', kind: LineKind.grandTotal),
  StatementLine.heading('Less: Cost of sales'),
  StatementLine('bi', 'Beginning inventory', hint: 'Value of your stock at the start of the year.', indent: true),
  StatementLine('pu', 'Purchases', hint: 'What you bought to make or resell.', indent: true),
  StatementLine('tga', 'Total goods available for sale', hint: 'Beginning inventory + Purchases', kind: LineKind.total, indent: true),
  StatementLine('ei', 'Ending inventory', hint: 'Value of your stock left at the end of the year.', indent: true),
  StatementLine('tcs', 'Total cost of sales', hint: 'Total goods available − Ending inventory', kind: LineKind.total, indent: true),
  StatementLine('gi', 'Gross income', hint: 'Sales − Total cost of sales', kind: LineKind.grandTotal),
  StatementLine.heading('Less: Operating expenses'),
  StatementLine('sw', 'Salaries and wages', indent: true),
  StatementLine('pl', 'Permits and licenses', indent: true),
  StatementLine('plw', 'Power, light and water', indent: true),
  StatementLine('tt', 'Travel and transportation', indent: true),
  StatementLine('toe', 'Total operating expenses', hint: 'Salaries + Permits + Power + Travel', kind: LineKind.total, indent: true),
  StatementLine('ni', 'Net income', hint: 'Gross income − Total operating expenses', kind: LineKind.grandTotal),
];

const cashFlowLines = <StatementLine>[
  StatementLine('cb', 'Cash beginning', hint: 'Cash on hand and in the bank at the start. For later years this is last year’s Cash ending.', kind: LineKind.grandTotal),
  StatementLine.heading('Add:'),
  StatementLine('io', 'Income from operation', hint: 'Net income on your income statement', indent: true),
  StatementLine('tc', 'Total cash', hint: 'Cash beginning + Income from operation', kind: LineKind.total),
  StatementLine.heading('Less:'),
  StatementLine('cd', 'Cash disbursements', hint: 'All money paid out: equipment, loan payments, your own withdrawals.', indent: true),
  StatementLine('ce', 'Cash ending', hint: 'Total cash − Cash disbursements', kind: LineKind.grandTotal),
];

/// Balance sheet lines, in the order of the OLEDIPO Excel template.
const balanceLines = <StatementLine>[
  StatementLine.heading('Assets'),
  StatementLine.heading('Current assets'),
  StatementLine('cash', 'Cash on hand and in bank', hint: 'All your cash and bank money on December 31.', indent: true),
  StatementLine('inv', 'Merchandise inventory', hint: 'Ending inventory on your income statement', indent: true),
  StatementLine('tca', 'Total current assets', hint: 'Cash + Merchandise inventory', kind: LineKind.total, indent: true),
  StatementLine.heading('Non-current assets'),
  StatementLine('lb', 'Lot, building', hint: 'What you paid for your lot and building. Type 0 if none.', indent: true),
  StatementLine('lbd', 'Accum. depreciation (lot, building)', hint: 'How much of that value is used up so far. Type 0 if none.', indent: true),
  StatementLine('cm', 'Cars, motorcycle', hint: 'What you paid for vehicles used in the business. Type 0 if none.', indent: true),
  StatementLine('cmd', 'Accum. depreciation (cars, motorcycle)', hint: 'Type 0 if none.', indent: true),
  StatementLine('eq', 'Equipment', hint: 'What you paid for machines and tools. Type 0 if none.', indent: true),
  StatementLine('eqd', 'Accum. depreciation (equipment)', hint: 'Type 0 if none.', indent: true),
  StatementLine('tnca', 'Total non-current assets', hint: 'Each cost − its accumulated depreciation, added up', kind: LineKind.total, indent: true),
  StatementLine('ta', 'Total assets', hint: 'Total current + Total non-current assets', kind: LineKind.grandTotal),
  StatementLine.heading('Liabilities and capital'),
  StatementLine('capb', 'Capital, beginning', hint: 'Your own money in the business at the start. For later years this is last year’s Total capital.', indent: true),
  StatementLine('ani', 'Accumulated net income', hint: 'Net income on your income statement', indent: true),
  StatementLine('capt', 'Total', hint: 'Capital, beginning + Accumulated net income', kind: LineKind.total, indent: true),
  StatementLine('dr', 'Less: Drawings', hint: 'Total − Total assets (as in the OLEDIPO template)', indent: true),
  StatementLine('tcap', 'Total capital', hint: 'Total − Drawings', kind: LineKind.total, indent: true),
  StatementLine('tlc', 'Total liabilities and capital', hint: 'Same as Total capital', kind: LineKind.grandTotal),
];

/// How much of a statement the owner has typed.
enum Progress { empty, partial, complete }

/// Lines the app always works out, as in the OLEDIPO Excel template.
/// Everything else is typed by the owner.
const calculatedKeys = {
  'tga', 'tcs', 'gi', 'toe', 'ni', // income statement
  'io', 'tc', 'ce', // cash flow
  'inv', 'tca', 'tnca', 'ta', 'ani', 'capt', 'dr', 'tcap', 'tlc', // balance sheet
};

/// Lines carried from the year before: typed only for the first year.
const carriedKeys = {'cb': 'ce', 'capb': 'tcap'};

/// One year's three statements, with every total worked out.
class YearFigures {
  final Map<String, String> inc, cf, bs;
  const YearFigures(this.inc, this.cf, this.bs);

  Map<String, String> of(StatementType t) => switch (t) {
        StatementType.income => inc,
        StatementType.cashFlow => cf,
        StatementType.balance => bs,
      };
}

/// Works out one year from what the owner typed, following the formulas of
/// the OLEDIPO Excel template:
///
/// * Income: Total goods = Beginning inventory + Purchases; Total cost of
///   sales = Total goods − Ending inventory; Gross income = Sales − Total cost
///   of sales; Total operating expenses = the expense lines; Net income =
///   Gross income − Total operating expenses.
/// * Cash flow: Cash beginning = last year's Cash ending; Income from
///   operation = Net income; Total cash; Cash ending = Total cash − Cash
///   disbursements.
/// * Balance sheet: Merchandise inventory = Ending inventory; Total current
///   and non-current assets; Total assets; Capital, beginning = last year's
///   Total capital; Accumulated net income = Net income; Total; Drawings =
///   Total − Total assets; Total capital = Total − Drawings; Total liabilities
///   and capital = Total capital.
///
/// [previous] is last year's figures, or null for the first year (then Cash
/// beginning and Capital, beginning are typed). A blank line counts as 0 in a
/// total, but a total stays blank while every line it uses is blank.
YearFigures computeYear(Map<String, String> inc, Map<String, String> cf, Map<String, String> bs, YearFigures? previous) {
  Map<String, String> typed(Map<String, String> m) => {
        for (final e in m.entries)
          if (!calculatedKeys.contains(e.key) && !(previous != null && carriedKeys.containsKey(e.key))) e.key: e.value,
      };
  final i = typed(inc), c = typed(cf), b = typed(bs);
  double? v(Map<String, String> m, String k) => parseAmount(m[k] ?? '');
  double? add(List<double?> xs) => xs.every((x) => x == null) ? null : xs.fold<double>(0, (a, x) => a + (x ?? 0));
  double? sub(double? a, double? b) => a == null && b == null ? null : (a ?? 0) - (b ?? 0);
  void put(Map<String, String> m, String k, double? x) {
    if (x != null) m[k] = amountText(x);
  }

  put(i, 'tga', add([v(i, 'bi'), v(i, 'pu')]));
  put(i, 'tcs', sub(v(i, 'tga'), v(i, 'ei')));
  put(i, 'gi', sub(v(i, 'sales'), v(i, 'tcs')));
  put(i, 'toe', add([v(i, 'sw'), v(i, 'pl'), v(i, 'plw'), v(i, 'tt')]));
  put(i, 'ni', sub(v(i, 'gi'), v(i, 'toe')));

  if (previous != null) put(c, 'cb', v(previous.cf, 'ce'));
  put(c, 'io', v(i, 'ni'));
  put(c, 'tc', add([v(c, 'cb'), v(c, 'io')]));
  put(c, 'ce', sub(v(c, 'tc'), v(c, 'cd')));

  put(b, 'inv', v(i, 'ei'));
  put(b, 'tca', add([v(b, 'cash'), v(b, 'inv')]));
  put(b, 'tnca', add([v(b, 'lb'), v(b, 'lbd') == null ? null : -v(b, 'lbd')!, v(b, 'cm'), v(b, 'cmd') == null ? null : -v(b, 'cmd')!, v(b, 'eq'), v(b, 'eqd') == null ? null : -v(b, 'eqd')!]));
  put(b, 'ta', add([v(b, 'tca'), v(b, 'tnca')]));
  if (previous != null) put(b, 'capb', v(previous.bs, 'tcap'));
  put(b, 'ani', v(i, 'ni'));
  put(b, 'capt', add([v(b, 'capb'), v(b, 'ani')]));
  if (v(b, 'capt') != null && v(b, 'ta') != null) put(b, 'dr', v(b, 'capt')! - v(b, 'ta')!);
  put(b, 'tcap', sub(v(b, 'capt'), v(b, 'dr')));
  put(b, 'tlc', v(b, 'tcap'));
  return YearFigures(i, c, b);
}
