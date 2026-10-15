import '../state/app_state.dart';
import 'format.dart';
import 'statements.dart';

/// Reads a typed amount. Blank stays null (never 0).
double? amt(String? s) => parseAmount(s ?? '');

/// Sum of a list column (e.g. materials: qty × price). Used only for the
/// "Total" lines under lists and the cost per unit in the business plan
/// (Annex D 3.3), and the totals of the financial statements (see statements.dart computeYear).
double listTotal(List<Map<String, String>> rows, double Function(Map<String, String>) f) => rows.fold(0, (t, r) => t + f(r));
double qtyTimesPrice(Map<String, String> r) => (amt(r['qty']) ?? 0) * (amt(r['price']) ?? 0);
double costOf(Map<String, String> r) => amt(r['cost']) ?? 0;

class MissingItem {
  final String label;
  final String where;
  final String route;
  final Object? args;
  const MissingItem(this.label, this.where, this.route, [this.args]);
}

class Warning {
  final String id;
  final String title;
  final String text;
  final String route;
  final Object? args;
  const Warning(this.id, this.title, this.text, this.route, [this.args]);
}

/// Required answers the forms need, by step. Optional ones (email, Facebook,
/// TIN, bank) are left out on purpose.
const requiredAnswers = <(String, String, String, String)>[
  // key, label, step label, route
  ('ln', 'Surname', 'Step 1 · About you', '/about'),
  ('fn', 'First name', 'Step 1 · About you', '/about'),
  ('a1', 'House number and street', 'Step 1 · About you', '/about'),
  ('a2', 'Barangay', 'Step 1 · About you', '/about'),
  ('a3', 'Town or city', 'Step 1 · About you', '/about'),
  ('dob', 'Birthday', 'Step 1 · About you', '/about'),
  ('since', 'Year you started living in your barangay', 'Step 1 · About you', '/about'),
  ('exp', 'Your experience', 'Step 1 · About you', '/about'),
  ('bn', 'Business name', 'Step 2 · Your business', '/business'),
  ('pj', 'What the loan will help you do', 'Step 2 · Your business', '/business'),
  ('os', 'When the business started', 'Step 2 · Your business', '/business'),
  ('bd', 'Description of your business', 'Step 2 · Your business', '/business'),
  ('pd', 'What makes your product good', 'Step 3 · What you sell', '/products'),
  ('es', 'Expected annual sales', 'Step 7 · Financial projection', '/projection'),
  ('ex', 'Expected annual expenses', 'Step 7 · Financial projection', '/projection'),
  ('gi', 'Expected annual gross income', 'Step 7 · Financial projection', '/projection'),
  ('ni', 'Expected annual net income', 'Step 7 · Financial projection', '/projection'),
  ('la', 'Amount to borrow', 'Step 8 · Your loan', '/loan'),
];

List<MissingItem> missingItems(AppState s) {
  final out = <MissingItem>[];
  for (final (k, label, where, route) in requiredAnswers) {
    if (s.val(k).trim().isEmpty) out.add(MissingItem(label, where, route));
  }
  if (s.rows('products').isEmpty) out.add(const MissingItem('What you sell', 'Step 3 · What you sell', '/products'));
  if (s.rows('raw_${s.kind}').isEmpty) out.add(MissingItem('What you buy for your business', 'Step 4', s.costRoute));
  if (s.val('units_${s.kind}').trim().isEmpty) out.add(MissingItem('How many you make or serve', 'Step 4', s.costRoute));
  for (final y in s.statementYears) {
    for (final t in StatementType.values) {
      final p = s.progress(y, t);
      if (p == Progress.empty) {
        out.add(MissingItem('$y ${t.title.toLowerCase()}', 'Step 5 · Financial statements', t.route, y));
      } else if (p == Progress.partial) {
        out.add(MissingItem('$y ${t.title.toLowerCase()}: ${s.blankLines(y, t)} lines blank', 'Step 5 · Financial statements', t.route, y));
      }
    }
  }
  if (s.rows('workers').isEmpty) out.add(const MissingItem('Your workers', 'Step 6 · Your workers', '/people'));
  // Requirement PDFs are uploaded at the very end (Upload requirements screen), not checked here.
  return out;
}

/// Things worth a second look. Each can be fixed or kept as it is.
/// These compare the owner's own typed numbers; nothing is changed for them.
List<Warning> warnings(AppState s) {
  final out = <Warning>[];
  for (final y in s.statementYears) {
    final bs = s.statementValues(y, StatementType.balance);
    final dr = amt(bs['dr']);
    if (dr != null && dr < 0) {
      out.add(Warning('bs$y', 'Check your $y balance sheet',
          'Drawings came out below zero (${peso(dr)}). This means your assets are more than your capital and net income. Check Cash on hand, the non-current assets, and Capital, beginning.',
          StatementType.balance.route, y));
    }
  }
  out.add(const Warning('review', 'Have your statements reviewed',
      'You typed them yourself. A bookkeeper or OLEDIPO staff can check that the totals are right.', '/statements'));
  return out.where((w) => !s.data.keptWarnings.contains(w.id)).toList();
}

/// Workers rule for the barangay certificate (Annex C): at least 2 workers
/// with 2+ years who live in Iloilo. Counting only; shown as a note.
int qualifiedWorkers(AppState s) =>
    s.rows('workers').where((w) => (amt(w['years']) ?? 0) >= 2 && (w['iloilo'] ?? 'Yes') == 'Yes').length;

/// Percent of required items answered, for the Home and Resume screens.
double readiness(AppState s) {
  final total = requiredAnswers.length + 4 + s.statementYears.length * 3;
  final missing = missingItems(s).length;
  return total == 0 ? 0 : ((total - missing) / total).clamp(0, 1).toDouble();
}
