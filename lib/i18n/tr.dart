import 'hil.dart';
import 'hil_extra.dart';

/// On-screen language. The app screens follow the language the owner picked
/// (Hiligaynon by default). Printed documents — the PDFs, the Word forms and
/// the Excel file — are always in English, because OLEDIPO's forms are in
/// English; nothing in lib/services calls [tr].
class Lang {
  Lang._();

  /// 'hil' Hiligaynon · 'fil' Filipino (not translated yet, shows English) · 'en' English.
  static String code = 'hil';
}

/// Shows [s] in the owner's language. Text with no translation stays English.
String tr(String s) {
  if (Lang.code != 'hil' || s.isEmpty) return s;
  final exact = hil[s] ?? hilExtra[s];
  if (exact != null) return exact;
  for (final (re, build) in _patterns) {
    final m = re.firstMatch(s);
    if (m != null) return build(m);
  }
  return s;
}

/// [tr] for optional text.
String trn(String? s) => s == null ? '' : tr(s);

String _g(Match m, int i) => m.group(i) ?? '';

/// Sentences with numbers or names in them.
final List<(RegExp, String Function(Match))> _patterns = [
  (RegExp(r'^(\d+) (?:thing|things) missing$'), (m) => '${_g(m, 1)} ang kulang'),
  (RegExp(r'^(\d+) (?:thing is|things are) missing$'), (m) => '${_g(m, 1)} ang kulang'),
  (RegExp(r'^(\d+) (?:thing is|things are) not filled in$'), (m) => '${_g(m, 1)} ang wala pa napun-an'),
  (RegExp(r'^Your loan papers are (\d+)% done\. Everything you entered is saved on this phone\.$'),
      (m) => 'Ang imo papeles sang loan ${_g(m, 1)}% na ang tapos. Tanan nga imo gin-type naka-save sa sini nga telepono.'),
  (RegExp(r'^Since (.+)$'), (m) => 'Sugod ${_g(m, 1)}'),
  (RegExp(r'^(\d{4}) net income$'), (m) => 'Net income sang ${_g(m, 1)}'),
  (RegExp(r'^(.+) · saved on this phone$'), (m) => '${tr(_g(m, 1))} · naka-save sa sini nga telepono'),
  (RegExp(r'^(\d{4}) \(first year\)$'), (m) => '${_g(m, 1)} (una nga tuig)'),
  (RegExp(r'^You have not typed this statement for (\d{4})\.$'), (m) => 'Wala mo pa na-type ini nga statement para sa ${_g(m, 1)}.'),
  (RegExp(r'^As of December 31, (\d{4})$'), (m) => 'Asta sang Disyembre 31, ${_g(m, 1)}'),
  (RegExp(r'^December 31, (\d{4})$'), (m) => 'Disyembre 31, ${_g(m, 1)}'),
  (RegExp(r'^For the year (\d{4}) · (.+)$'), (m) => 'Para sa tuig ${_g(m, 1)} · ${tr(_g(m, 2))}'),
  (RegExp(r'^(\w+) to December · first year$'), (m) => '${tr(_g(m, 1))} asta Disyembre · una nga tuig'),
  (RegExp(r'^(\d{4}) · (.+)$'), (m) => '${_g(m, 1)} · ${tr(_g(m, 2))}'),
  (RegExp(r'^(.+) · from your account$'), (m) => '${_g(m, 1)} · halin sa imo account'),
  (RegExp(r'^Bought for (.+)$'), (m) => 'Ginbakal para sa ${tr(_g(m, 1))}'),
  (RegExp(r'^Other costs for (.+)$'), (m) => 'Iban nga gasto para sa ${tr(_g(m, 1))}'),
  (RegExp(r'^Total cost of (.+)$'), (m) => 'Kabug-osan nga gasto sang ${tr(_g(m, 1))}'),
  (RegExp(r'^(\d+) lines still blank\. Tap to finish\.$'), (m) => '${_g(m, 1)} ka linya ang blangko pa. Pinduta para tapuson.'),
  (RegExp(r'^(\d+) lines still blank$'), (m) => '${_g(m, 1)} ka linya ang blangko pa'),
  (RegExp(r'^Step 5 · (\d{4})$'), (m) => 'Hakbang 5 · ${_g(m, 1)}'),
  (RegExp(r'^(\d+) workers have been with you 2 years or more and live in Iloilo\. This meets the barangay certificate\.$'),
      (m) => '${_g(m, 1)} ka trabahante ang 2 ka tuig na ukon labaw sa imo kag nagaestar sa Iloilo. Pasar ini sa barangay certificate.'),
  (RegExp(r'^The barangay certificate needs at least 2 workers with you 2 years or more who live in Iloilo\. You have (\d+)\.$'),
      (m) => 'Ang barangay certificate nagakinahanglan sang bisan 2 ka trabahante nga 2 ka tuig na ukon labaw sa imo kag nagaestar sa Iloilo. May ${_g(m, 1)} ka.'),
  (RegExp(r'^(\d+) of (\d+) files? ready$'), (m) => '${_g(m, 1)} sa ${_g(m, 2)} ka file ang handa na'),
  (RegExp(r'^(\d+) of (\d+) files$'), (m) => '${_g(m, 1)} sa ${_g(m, 2)} ka file'),
  (RegExp(r'^(\d+) of (\d+) digits entered$'), (m) => '${_g(m, 1)} sa ${_g(m, 2)} ka numero ang na-type'),
  (RegExp(r'^(\d+) of (\d+)$'), (m) => '${_g(m, 1)} sa ${_g(m, 2)}'),
  (RegExp(r'^Still needed: (.+)\.$'), (m) => 'Kinahanglan pa: ${_g(m, 1).split(', ').map(tr).join(', ')}.'),
  (RegExp(r'^(\d+) left$'), (m) => '${_g(m, 1)} pa ang nabilin'),
  (RegExp(r'^(\d+) to add$'), (m) => '${_g(m, 1)} pa ang idugang'),
  (RegExp(r'^Ready · (\d+) blanks? marked$'), (m) => 'Handa na · ${_g(m, 1)} ka blangko ang namarkahan'),
  (RegExp(r'^This is how your form will look\. Read it before you save or print it\. (.+)$', dotAll: true),
      (m) => 'Amo ini ang itsura sang imo form. Basaha antes mo i-save ukon i-print. ${tr(_g(m, 1))}'),
  (RegExp(r'^Add (\d{4}) when you have its records\. Your first year comes from Step 2\.$'),
      (m) => 'Idugang ang ${_g(m, 1)} kon may rekord ka na sini. Ang imo una nga tuig halin sa Hakbang 2.'),
  (RegExp(r'^Add (\d{4})$'), (m) => 'Idugang ang ${_g(m, 1)}'),
  (RegExp(r'^Cash ending of (\d{4})$'), (m) => 'Cash ending sang ${_g(m, 1)}'),
  (RegExp(r'^Total capital of (\d{4})$'), (m) => 'Total capital sang ${_g(m, 1)}'),
  (RegExp(r'^(.+), added up for you: (.+)$'), (m) => '${tr(_g(m, 1))}, ginkuwenta para sa imo: ${tr(_g(m, 2))}'),
  (RegExp(r'^Take a photo of (.+)$'), (m) => 'Kuhai sang litrato ang ${tr(_g(m, 1))}'),
  (RegExp(r'^Per (.+)$'), (m) => 'Kada ${_g(m, 1)}'),
  (RegExp(r'^Please fill in: (.+)$'), (m) => 'Palihog pun-i: ${_trLabel(_g(m, 1))}'),
  (RegExp(r'^(\d{4}) (income statement|cash flow statement|balance sheet): (\d+) lines blank$'),
      (m) => '${_statement(_g(m, 2))} sang ${_g(m, 1)}: ${_g(m, 3)} ka linya ang blangko'),
  (RegExp(r'^(\d{4}) (income statement|cash flow statement|balance sheet)$'), (m) => '${_statement(_g(m, 2))} sang ${_g(m, 1)}'),
  (RegExp(r'^Check your (\d{4}) balance sheet$'), (m) => 'Tan-awa ang imo balance sheet sang ${_g(m, 1)}'),
  (RegExp(r'^Drawings came out below zero \((.+)\)\. '), (m) =>
      'Ang Drawings nag-ubos sa zero (${_g(m, 1)}). Buot silingon, ang imo assets mas daku sang sa imo kapital kag net income. Tan-awa ang Cash on hand, ang non-current assets, kag ang Capital, beginning.'),
  (RegExp(r'^Hello(?: (.+))?! I can explain any question in NegosyoPlan in simple words\.\nTap a question below or type your own\.$'),
      (m) => 'Maayong adlaw${_g(m, 1).isEmpty ? '' : ' ${_g(m, 1)}'}! Mapaathag ko sa simple nga pulong ang bisan ano nga pamangkot sa NegosyoPlan.\nPinduta ang pamangkot sa idalom ukon i-type ang imo.'),
  (RegExp(r'^(.+) certificate$'), (m) => 'Certificate sang ${_g(m, 1)}'),
  (RegExp(r'^(Net income|Cash ending|Total assets) (₱.+)$'), (m) => '${tr(_g(m, 1))} ${_g(m, 2)}'),
  (RegExp(r'^STEP (\d+) OF 8 · SAVED$'), (m) => 'HAKBANG ${_g(m, 1)} SA 8 · NA-SAVE'),
  (RegExp(r'^STEP (\d+) OF 8 · PART (\d) OF 3 · SAVED$'), (m) => 'HAKBANG ${_g(m, 1)} SA 8 · PARTE ${_g(m, 2)} SA 3 · NA-SAVE'),
];

String _trLabel(String label) {
  final withQ = hil['$label?'];
  return withQ ?? tr(label);
}

String _statement(String lower) => switch (lower) {
      'income statement' => 'Income statement',
      'cash flow statement' => 'Cash flow statement',
      _ => 'Balance sheet',
    };