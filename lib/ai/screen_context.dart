import 'dart:convert';

import 'package:flutter/widgets.dart';

import '../logic/checks.dart';
import '../logic/format.dart';
import '../logic/statements.dart';
import '../state/app_state.dart';

/// A quick question shown as a chip in the helper.
/// [target] = the answer key the reply can be put into (e.g. 'bd').
class AiChip {
  const AiChip(this.text, {this.target});
  final String text;
  final String? target;
}

/// What the helper knows about one screen.
class ScreenHelp {
  const ScreenHelp({
    required this.title,
    required this.about,
    this.chips = const [],
    this.writable = const {},
    this.data,
  });

  final String title;

  /// What the screen is for, in plain words (sent to the AI).
  final String about;
  final List<AiChip> chips;

  /// Text answers the helper may fill when the owner taps "Use as answer".
  /// answer key → field label.
  final Map<String, String> writable;

  /// The owner's answers on this screen (sent to the AI).
  final Map<String, Object?> Function(AppState s)? data;
}

/// Remembers which screen the owner is on. The chat opens on top of it,
/// so the helper can talk about that screen.
/// Add to MaterialApp.navigatorObservers (see app.dart).
class CurrentScreen extends NavigatorObserver {
  CurrentScreen._();
  static final CurrentScreen instance = CurrentScreen._();

  RouteSettings? settings;

  void _set(Route<dynamic>? r) {
    if (r is! PageRoute) return; // skip dialogs and bottom sheets
    final name = r.settings.name;
    if (name == null || name == '/chat') return;
    settings = r.settings;
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) => _set(route);
  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) => _set(previousRoute);
  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) => _set(newRoute);

  ScreenHelp get help => helpFor(settings?.name, settings?.arguments);

  /// One chat per screen (and per year on statement screens).
  String get key => '${settings?.name}|${settings?.arguments}';
}

/// Answer keys that hold peso amounts (filled with digits only).
const amountKeys = {'es', 'ex', 'gi', 'ni', 'la'};

// ---------------------------------------------------------------- helpers

String? _t(String v) => v.trim().isEmpty ? null : v.trim();
String? _p(String? v) => amt(v) == null ? null : peso(amt(v));

/// Private answers are never sent to the AI, only whether they are filled.
String _private(String v) => v.trim().isEmpty ? 'blank' : 'filled in (hidden for privacy)';

/// Drops blank values so fewer words are sent (saves the free quota).
Map<String, Object?> _clean(Map<String, Object?> m) => {
      for (final e in m.entries)
        if (e.value != null &&
            !(e.value is String && (e.value as String).trim().isEmpty) &&
            !(e.value is Iterable && (e.value as Iterable).isEmpty) &&
            !(e.value is Map && (e.value as Map).isEmpty))
          e.key: e.value,
    };

int _yearFrom(AppState s, Object? args) {
  if (args is int) return args;
  final ys = s.statementYears;
  return ys.isEmpty ? s.now().year - 1 : ys.last;
}

Map<String, Object?> _yearHeadlines(AppState s, int y) {
  final f = s.figures(y);
  return _clean({
    'sales': _p(f.inc['sales']),
    'grossIncome': _p(f.inc['gi']),
    'operatingExpenses': _p(f.inc['toe']),
    'netIncome': _p(f.inc['ni']),
    'cashEnding': _p(f.cf['ce']),
    'totalAssets': _p(f.bs['ta']),
  });
}

Map<String, Object?> _statement(AppState s, StatementType t, int year) {
  final vals = s.statementValues(year, t);
  return _clean({
    'statement': t.title,
    'year': year,
    'period': s.yearSpan(year),
    'lines': [
      for (final l in t.lines)
        if (l.kind != LineKind.heading)
          {
            'line': l.label,
            'amount': _p(vals[l.key]) ?? 'blank',
            'source': s.isCalculated(year, l.key) ? 'worked out by the app' : 'typed by the owner',
            if (l.hint.isNotEmpty) 'meaning': l.hint,
          }
    ],
    'blankLinesLeft': s.blankLines(year, t),
    if (s.statementYears.contains(year - 1)) 'previousYear${year - 1}': _yearHeadlines(s, year - 1),
  });
}

Map<String, Object?> _costs(AppState s, String k) {
  final raw = s.rows('raw_$k');
  final ovh = s.rows('ovh_$k');
  final rawTotal = listTotal(raw, qtyTimesPrice);
  final ovhTotal = listTotal(ovh, costOf);
  final labor = amt(s.val('lab_$k')) ?? 0;
  final units = amt(s.val('units_$k'));
  final perUnit = (units == null || units <= 0) ? null : (rawTotal + ovhTotal + labor) / units;
  return _clean({
    'kind': k,
    'period': switch (k) { 'resell' => 'one normal week of buying', 'service' => 'one normal week of work', _ => 'one batch' },
    'thingsBought': [
      for (final r in raw)
        _clean({
          'item': r['name'],
          'from': r['source'],
          'qty': '${r['qty'] ?? ''} ${r['unit'] ?? ''}'.trim(),
          'priceEach': _p(r['price']),
          'total': peso(qtyTimesPrice(r)),
        })
    ],
    'totalBought': raw.isEmpty ? null : peso(rawTotal),
    'tools': [for (final r in s.rows('tools_$k')) r['name']],
    'paidToWorkers': _p(s.val('lab_$k')),
    'otherCosts': [for (final r in ovh) '${r['name']}: ${peso(costOf(r))}'],
    'totalOtherCosts': ovh.isEmpty ? null : peso(ovhTotal),
    'unitsMadeOrCustomersServed': _t(s.val('units_$k')),
    'roughCostPerUnit': perUnit == null ? null : '${peso(perUnit)} (materials + workers + other costs ÷ units)',
    'sellingPrices': [for (final r in s.rows('products')) '${r['name']}: ${_p(r['price']) ?? '—'} per ${r['unit'] ?? 'unit'}'],
  });
}

/// A short picture of the whole business, sent with every question.
Map<String, Object?> businessSnapshot(AppState s) {
  final ys = s.statementYears;
  return _clean({
    'businessName': _t(s.val('bn')),
    'kindOfBusiness': _t(s.one('bt')),
    'started': _t(s.val('os')),
    'town': _t([s.val('a3'), s.val('a4')].where((x) => x.trim().isNotEmpty).join(', ')),
    'products': [for (final r in s.rows('products')) '${r['name']} (${_p(r['price']) ?? 'no price'} per ${r['unit'] ?? 'unit'})'],
    'statementYears': ys,
    if (ys.isNotEmpty) 'latestYear${ys.last}': _yearHeadlines(s, ys.last),
    'loanAmountWanted': _p(s.val('la')),
    'papersDone': '${(readiness(s) * 100).round()}%',
    'applicationStatus': s.data.appStatus.isNotEmpty ? s.data.appStatus : (s.submitted ? 'Submitted' : 'Not submitted yet'),
    'staffNote': _t(s.data.staffNote),
  });
}

Map<String, Object?> _missingAndWarnings(AppState s) => _clean({
      'missing': [for (final m in missingItems(s)) '${m.label} — ${m.where}'],
      'warnings': [for (final w in warnings(s)) '${w.title}: ${w.text}'],
    });

// ---------------------------------------------------------------- screens

const _general = [
  AiChip('What should I type on this screen?'),
  AiChip('Explain this screen in simple words'),
];

ScreenHelp helpFor(String? route, Object? args) {
  switch (route) {
    case '/about':
      return ScreenHelp(
        title: 'Step 1 · About you',
        about: 'The owner types personal details for the loan application form (Annex A) and the barangay certificate (Annex C): name, address, district, birthday, sex, civil status, contact, TIN, bank, the year they started living in the barangay, and their work experience.',
        writable: const {'exp': 'Your experience'},
        chips: const [
          AiChip('Help me write my experience', target: 'exp'),
          AiChip('Which congressional district am I in?'),
          AiChip('I have no TIN. Is that okay?'),
          ..._general,
        ],
        data: (s) => _clean({
          'firstName': _t(s.val('fn')),
          'surname': _private(s.val('ln')),
          'street': _private(s.val('a1')),
          'barangay': _t(s.val('a2')),
          'townOrCity': _t(s.val('a3')),
          'province': _t(s.val('a4')),
          'district': _t(s.one('dist')),
          'birthday': _private(s.val('dob')),
          'sex': _t(s.one('sex')),
          'civilStatus': _t(s.one('civ')),
          'email': _private(s.val('em')),
          'facebook': _private(s.val('fb')),
          'tin': _private(s.val('tin')),
          'bank': _private(s.val('bank')),
          'livingInBarangaySince': _t(s.val('since')),
          'experience': _t(s.val('exp')),
        }),
      );

    case '/business':
      return ScreenHelp(
        title: 'Step 2 · Your business',
        about: 'Business name, a short title for what the loan will help do, where the business is, when it started (this decides which years of financial statements are needed), who owns it, a 1–2 sentence description, and how a crisis (pandemic, typhoon) affected sales.',
        writable: const {'bd': 'Business description', 'pj': 'What the loan will help you do'},
        chips: const [
          AiChip('Write my business description', target: 'bd'),
          AiChip('Write what the loan will help me do', target: 'pj'),
          AiChip('Why does the start date matter?'),
          ..._general,
        ],
        data: (s) => _clean({
          'businessName': _t(s.val('bn')),
          'loanWillHelp': _t(s.val('pj')),
          'location': _t(s.one('loc')),
          'businessBarangay': _t(s.val('b2')),
          'businessTown': _t(s.val('b3')),
          'started': _t(s.val('os')),
          'owners': _t(s.one('own')),
          'description': _t(s.val('bd')),
          'crisisEffect': _t(s.one('cr')),
        }),
      );

    case '/products':
      return ScreenHelp(
        title: 'Step 3 · What you sell',
        about: 'The kind of business (make products, buy and resell, or offer a service), the products with how they are sold and the price, what makes the product good, who buys, where customers are, and how people hear about the business. Used for the application form and the business plan (Annex D).',
        writable: const {'pd': 'What makes your product good'},
        chips: const [
          AiChip('Write what makes my product good', target: 'pd'),
          AiChip('Is my price right?'),
          AiChip('Which kind of business am I?'),
          ..._general,
        ],
        data: (s) => _clean({
          'kindOfBusiness': _t(s.one('bt')),
          'products': [for (final r in s.rows('products')) _clean({'name': r['name'], 'soldBy': r['unit'], 'price': _p(r['price'])})],
          'whatMakesItGood': _t(s.val('pd')),
          'customers': s.sel('tm'),
          'customerAreas': s.sel('ma'),
          'howPeopleHear': s.sel('md'),
        }),
      );

    case '/costs/prod':
    case '/costs/resell':
    case '/costs/service':
      {
      final k = route!.split('/').last;
      return ScreenHelp(
        title: switch (k) { 'resell' => 'Step 4 · Buying your goods', 'service' => 'Step 4 · Your service supplies', _ => 'Step 4 · Making your product' },
        about: 'For the business plan (Annex D). The owner lists what they buy for ${switch (k) { 'resell' => 'one normal week of reselling', 'service' => 'one normal week of service', _ => 'one normal batch' }} (quantity × price), their tools, what they pay workers, other costs like electricity, and how many units they make or customers they serve. This gives the cost per unit.',
        chips: const [
          AiChip('What is my cost per unit?'),
          AiChip('Am I earning from each sale?'),
          AiChip('What costs am I forgetting?'),
          ..._general,
        ],
        data: (s) => _costs(s, k),
      );
      }

    case '/financials':
    case '/statements':
      return ScreenHelp(
        title: route == '/financials' ? 'Step 5 · Financial statements' : 'Financial statements',
        about: 'Each year from the business start to last year needs 3 statements: income statement, cash flow statement and balance sheet. The owner types item lines from records or ITR; the app works out totals.',
        chips: const [
          AiChip('Summarize my statements year by year'),
          AiChip('Is my business growing?'),
          AiChip('I have no records. What do I do?'),
          AiChip('What is the difference of the 3 statements?'),
        ],
        data: (s) => _clean({
          'years': [
            for (final y in s.statementYears)
              _clean({
                'year': y,
                'period': s.yearSpan(y),
                for (final t in StatementType.values)
                  t.title: switch (s.progress(y, t)) {
                    Progress.complete => 'complete',
                    Progress.partial => '${s.blankLines(y, t)} lines blank',
                    Progress.empty => 'not started',
                  },
                'figures': _yearHeadlines(s, y),
              })
          ],
        }),
      );

    case '/statement/income':
    case '/statement/cashflow':
    case '/statement/balance':
      {
      final t = StatementType.values.firstWhere((x) => x.route == route);
      final explain = switch (t) {
        StatementType.income => 'Explain net income simply',
        StatementType.cashFlow => 'What are cash disbursements?',
        StatementType.balance => 'What is depreciation?',
      };
      return ScreenHelp(
        title: '${t.title} · ${args is int ? args : 'year'}',
        about: switch (t) {
          StatementType.income => 'Income statement for one year. Sales, then cost of sales (beginning inventory + purchases − ending inventory), gross income, operating expenses (salaries, permits, power/light/water, travel), and net income. The owner types item lines; the app works out totals.',
          StatementType.cashFlow => 'Cash flow statement for one year. Cash beginning (carried from last year’s cash ending after the first year), plus income from operation (= net income), minus cash disbursements (all money paid out: equipment, loan payments, owner withdrawals) = cash ending.',
          StatementType.balance => 'Balance sheet as of December 31. Cash, merchandise inventory, lot/building, vehicles, equipment and their accumulated depreciation, capital, accumulated net income and drawings. Drawings is worked out as Total − Total assets, as in the OLEDIPO template; if it is below zero, numbers likely need checking.',
        },
        chips: [
          AiChip('Summarize this ${t.title.toLowerCase()}'),
          AiChip(explain),
          const AiChip('Check my numbers'),
          const AiChip('Where do I find these numbers?'),
        ],
        data: (s) => _statement(s, t, _yearFrom(s, args)),
      );
      }

    case '/people':
      return ScreenHelp(
        title: 'Step 6 · Your workers',
        about: 'The owner lists workers (not themselves) with sex, kind of work, job, years with the business and whether they live in Iloilo. The barangay certificate (Annex C) needs at least 2 workers with 2+ years who live in Iloilo.',
        chips: const [
          AiChip('Do I meet the barangay certificate rule?'),
          AiChip('Should I list family members who help?'),
          ..._general,
        ],
        data: (s) => _clean({
          'workers': [
            for (final w in s.rows('workers'))
              _clean({'job': w['work'], 'sex': w['sex'], 'kind': w['status'], 'years': w['years'], 'livesInIloilo': w['iloilo']})
          ],
          'workersMeetingRule': qualifiedWorkers(s),
        }),
      );

    case '/projection':
      return ScreenHelp(
        title: 'Step 7 · Financial projection',
        writable: const {
          'es': 'Expected annual sales',
          'ex': 'Expected annual expenses',
          'gi': 'Expected annual gross income',
          'ni': 'Expected annual net income',
        },
        about: 'For the business plan (Annex D): expected sales, expenses, gross income and net income for the next 12 months. Should be realistic compared with past years.',
        chips: const [
          AiChip('Is my projection realistic?'),
          AiChip('Help me estimate my next 12 months'),
          AiChip('What is the difference of gross and net income?'),
        ],
        data: (s) => _clean({
          'expectedSales': _p(s.val('es')),
          'expectedExpenses': _p(s.val('ex')),
          'expectedGrossIncome': _p(s.val('gi')),
          'expectedNetIncome': _p(s.val('ni')),
          'pastYears': {for (final y in s.statementYears.reversed.take(3)) '$y': _yearHeadlines(s, y)},
        }),
      );

    case '/loan':
      return ScreenHelp(
        title: 'Step 8 · Your loan',
        about: 'The amount the owner wants to borrow from the EMBRACE program. No spending list is needed; a LIDEP officer checks how the loan was used about 3 months after release.',
        chips: const [
          AiChip('How much should I borrow?'),
          AiChip('Can my business pay this back?'),
          AiChip('What happens after I submit?'),
        ],
        data: (s) => _clean({
          'amountToBorrow': _p(s.val('la')),
          'loanWillHelp': _t(s.val('pj')),
          'expectedNetIncomeNext12Months': _p(s.val('ni')),
          'pastYears': {for (final y in s.statementYears.reversed.take(2)) '$y': _yearHeadlines(s, y)},
        }),
      );

    case '/requirements':
      return ScreenHelp(
        title: 'Upload requirements',
        about: 'The last step before submitting: upload PDFs of the business permit, the barangay certificate (Annex C, signed by the barangay captain) and at least one training certificate.',
        chips: const [
          AiChip('How do I get Annex C signed?'),
          AiChip('How do I make a PDF from a photo?'),
          AiChip('What trainings count?'),
        ],
        data: (s) => _clean({
          'businessPermit': s.reqFile('permit') == null ? 'not uploaded' : 'uploaded',
          'annexC': s.reqFile('annexC') == null ? 'not uploaded' : 'uploaded',
          'trainingCertificates': s.trainingFiles.length,
          'allComplete': s.requirementsComplete,
        }),
      );

    case '/check':
    case '/missing':
    case '/warnings':
      return ScreenHelp(
        title: switch (route) { '/missing' => 'What is missing', '/warnings' => 'Please check these', _ => 'Check your answers' },
        about: 'Review before making documents: what is still blank and things worth a second look.',
        chips: const [
          AiChip('What should I fix first?'),
          AiChip('Explain these warnings'),
          AiChip('Summarize my application'),
        ],
        data: _missingAndWarnings,
      );

    case '/plan':
      return ScreenHelp(
        title: 'Your business plan (Annex D)',
        about: 'The business plan the app builds from all answers: the business, products, costs, financial statements, projection and loan.',
        chips: const [
          AiChip('Summarize my business plan'),
          AiChip('What are the strong and weak points?'),
          AiChip('How can I make my plan better?'),
        ],
        data: (s) => _clean({
          'description': _t(s.val('bd')),
          'whatMakesItGood': _t(s.val('pd')),
          'loanWillHelp': _t(s.val('pj')),
          'customers': s.sel('tm'),
          'costs': _costs(s, s.kind),
          'workers': s.rows('workers').length,
          'projection': _clean({'sales': _p(s.val('es')), 'expenses': _p(s.val('ex')), 'grossIncome': _p(s.val('gi')), 'netIncome': _p(s.val('ni'))}),
          ..._missingAndWarnings(s),
        }),
      );

    case '/home':
    case '/tracker':
    case '/passport':
      return ScreenHelp(
        title: switch (route) { '/tracker' => 'Application tracker', '/passport' => 'Enterprise Passport', _ => 'Home' },
        about: 'Overview of the owner’s loan papers: how much is done, what is next, and the status OLEDIPO staff set after submitting (Pending, Returned for completion, Accepted).',
        chips: const [
          AiChip('What should I do next?'),
          AiChip('How does the EMBRACE loan work?'),
          AiChip('Summarize my business'),
        ],
        data: _missingAndWarnings,
      );

    case '/documents':
    case '/preview':
    case '/form':
    case '/consent':
      return ScreenHelp(
        title: 'Your documents',
        about: 'The app fills the OLEDIPO forms from the answers: application form (Annex A), barangay certificate (Annex C), business plan (Annex D) and financial statements. The owner previews, saves, prints, signs, uploads and submits.',
        chips: const [
          AiChip('What do I do with these documents?'),
          AiChip('Who signs which form?'),
          ..._general,
        ],
      );

    default:
      return const ScreenHelp(
        title: 'NegosyoPlan',
        about: 'General help with the NegosyoPlan app and the EMBRACE loan papers.',
        chips: [
          AiChip('How do I use NegosyoPlan?'),
          AiChip('What papers do I need for the loan?'),
          AiChip('Summarize my business'),
        ],
      );
  }
}

// ---------------------------------------------------------------- prompt

String buildSystemPrompt(AppState s, ScreenHelp h) {
  final lang = switch (s.data.lang) { 'en' => 'English', 'fil' => 'Filipino (Tagalog)', _ => 'Hiligaynon (Ilonggo)' };
  Map<String, Object?>? data;
  try {
    data = h.data?.call(s);
  } catch (_) {}

  return '''
You are "Negosyo Helper" inside NegosyoPlan, an app that helps micro and small business owners in Iloilo, Philippines prepare their EMBRACE loan papers for OLEDIPO: the application form (Annex A), the Certificate of Residency and Business Operation signed by the barangay captain (Annex C), the business plan (Annex D) and yearly financial statements (income statement, cash flow statement, balance sheet). Many owners are 40–60 years old with no accounting background.

HOW TO ANSWER
- The owner's app language is $lang. Reply in $lang, unless the owner writes in another language; then reply in theirs.
- Be warm and simple. Short answers for a phone: 2–6 sentences or a few bullets. Offer to explain more instead of writing long.
- Teach with everyday Iloilo examples (piaya bakery, sari-sari store, carinderia, salon).
- Money is in pesos (₱).
- When asked what to type, say what the field means, give a clearly labeled SAMPLE value, and how to find or compute their own number.
- When the owner's numbers are given below, use them. Do the math step by step and double-check it. Point out blanks and anything that looks off. Never make up the owner's own figures.
- Lines marked "worked out by the app" are calculated automatically; tell the owner to fix the typed lines instead.
- Text the owner will put into a form (descriptions, experience, plans) must be in simple, clear English because OLEDIPO forms are in English. Write it in first person, based on their answers.
- Never promise the loan will be approved. For loan decisions, interest, permits and taxes, give general guidance and tell them to confirm with OLEDIPO staff or the agency.
- Format: plain text, **bold** for key words, "- " for bullets. No tables, no code.
- Stay on business, money, the loan papers and how to use this app. Gently steer back otherwise.

${_fillRules(s, h)}
THE OWNER IS ON THIS SCREEN: ${h.title}
About this screen: ${h.about}
${data == null || data.isEmpty ? '' : "Owner's answers on this screen (blank means not filled yet):\n${jsonEncode(data)}\n"}
Business snapshot: ${jsonEncode(businessSnapshot(s))}
''';
}

/// Tells the AI how to suggest an answer the owner can put in a field.
String _fillRules(AppState s, ScreenHelp h) {
  if (h.writable.isEmpty) {
    return 'FORM FIELDS: There are no fields you can fill on this screen. Never write <fill> blocks. '
        'If the owner asks you to fill something, help them decide what to type and tell them to type it on the screen.\n';
  }
  final list = [
    for (final e in h.writable.entries)
      '- ${e.key}: "${e.value}" (now: ${s.val(e.key).trim().isEmpty ? 'blank' : '"${s.val(e.key).trim()}"'})'
  ].join('\n');
  return '''
FORM FIELDS YOU CAN SUGGEST ON THIS SCREEN:
$list
When the owner asks you to write, suggest, improve or estimate an answer for one of these fields, put ONLY the exact text for the form inside a block, like this:
<fill field="KEY">the exact answer</fill>
Rules for fill blocks:
- Before the block, say in one short sentence (in the owner's language) that this is a suggestion they can put in the form.
- Inside the block: only the answer itself, in simple English, first person, 1–3 sentences. No quotes, no labels, no notes.
- Money fields: only the number, no peso sign or commas (example: <fill field="es">250000</fill>). Explain briefly how you got it, outside the block.
- One block per field. Only use the keys listed above.
- Do NOT use fill blocks when you are only explaining or answering a question.
''';
}