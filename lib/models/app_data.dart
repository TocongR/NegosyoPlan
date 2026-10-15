import '../logic/statements.dart';

/// Everything the applicant types, stored exactly as typed.
///
/// Answers are kept by key so the screens, the summary and the PDFs all read
/// the same value. The app never fills in or calculates statement lines:
/// every amount in [YearStatements] is typed by the owner.
class AppData {
  // ---- account (stays on the phone) ----
  String accountName = '';
  String mobile = '';
  String pinHash = '';
  bool verified = false;
  String lang = 'hil'; // hil | fil | en
  bool langChosen = false; // language picked on first launch
  bool privacyAgreed = false;

  // ---- interview answers ----
  /// Single answers, e.g. `ln` (surname), `bn` (business name), `la` (loan amount).
  Map<String, String> v = {};

  /// Tap-to-choose answers, e.g. `sex`, `bt` (kind of business), `tm` (who buys).
  Map<String, List<String>> g = {};

  /// List answers, e.g. `products`, `raw_prod`, `workers`.
  Map<String, List<Map<String, String>>> lists = {};

  /// Income statement, cash flow and balance sheet for each year since the business started.
  Map<int, YearStatements> years = {};

  /// Years the owner added by hand (beyond the ones from the start date).
  Set<int> extraYears = {};

  /// Old requirement photo statuses (before PDFs). Not used now; kept so old saved data still loads.
  Map<String, String> req = {};

  /// Old training list (before PDFs). Trainings are now uploaded with their PDF.
  List<Map<String, String>> trainings = [];

  // ---- documents and submission ----
  bool consentSave = true;
  bool consentShare = false;
  int trackerAt = 0;
  String submittedAt = ''; // when the owner submitted (ISO date), empty if not yet
  Set<String> keptWarnings = {};

  // ---- settings ----
  int textSize = 0; // 0 normal, 1 large, 2 largest
  bool readAloud = false;
  String lastRoute = '/about';

  AppData();

  Map<String, dynamic> toJson() => {
        'accountName': accountName,
        'mobile': mobile,
        'pinHash': pinHash,
        'verified': verified,
        'lang': lang,
        'langChosen': langChosen,
        'privacyAgreed': privacyAgreed,
        'v': v,
        'g': g,
        'lists': lists,
        'years': years.map((k, y) => MapEntry(k.toString(), y.toJson())),
        'extraYears': extraYears.toList(),
        'req': req,
        'trainings': trainings,
        'consentSave': consentSave,
        'consentShare': consentShare,
        'trackerAt': trackerAt,
        'submittedAt': submittedAt,
        'keptWarnings': keptWarnings.toList(),
        'textSize': textSize,
        'readAloud': readAloud,
        'lastRoute': lastRoute,
      };

  factory AppData.fromJson(Map<String, dynamic> j) {
    Map<String, String> strMap(dynamic m) => (m as Map? ?? {}).map((k, v) => MapEntry(k.toString(), v.toString()));
    List<Map<String, String>> rows(dynamic l) => (l as List? ?? []).map((r) => strMap(r)).toList();
    final d = AppData()
      ..accountName = j['accountName'] as String? ?? ''
      ..mobile = j['mobile'] as String? ?? ''
      ..pinHash = j['pinHash'] as String? ?? ''
      ..verified = j['verified'] as bool? ?? false
      ..lang = j['lang'] as String? ?? 'hil'
      ..langChosen = j['langChosen'] as bool? ?? false
      ..privacyAgreed = j['privacyAgreed'] as bool? ?? false
      ..v = strMap(j['v'])
      ..g = (j['g'] as Map? ?? {}).map((k, v) => MapEntry(k.toString(), (v as List).map((e) => e.toString()).toList()))
      ..lists = (j['lists'] as Map? ?? {}).map((k, v) => MapEntry(k.toString(), rows(v)))
      ..years = (j['years'] as Map? ?? {}).map((k, v) => MapEntry(int.parse(k.toString()), YearStatements.fromJson(v as Map<String, dynamic>)))
      ..extraYears = ((j['extraYears'] as List?) ?? []).map((e) => e as int).toSet()
      ..req = strMap(j['req'])
      ..trainings = rows(j['trainings'])
      ..consentSave = j['consentSave'] as bool? ?? true
      ..consentShare = j['consentShare'] as bool? ?? false
      ..trackerAt = j['trackerAt'] as int? ?? 0
      ..submittedAt = j['submittedAt'] as String? ?? ''
      ..keptWarnings = ((j['keptWarnings'] as List?) ?? []).map((e) => e.toString()).toSet()
      ..textSize = j['textSize'] as int? ?? 0
      ..readAloud = j['readAloud'] as bool? ?? false
      ..lastRoute = j['lastRoute'] as String? ?? '/about';
    return d;
  }

  /// Sample answers for trying the app (Lola Nena’s Piaya). Clearly sample data.
  factory AppData.sample() {
    final d = AppData()
      ..accountName = 'Maria L. Santos'
      ..mobile = '09171234567'
      ..verified = true
      ..privacyAgreed = true
      ..v = {
        'ln': 'Santos', 'fn': 'Maria', 'mn': 'Lopez', 'a1': '', 'a2': 'Tabuc Suba', 'a3': 'Iloilo City', 'a4': 'Iloilo', 'a5': '5000',
        'dob': '1981-05-12', 'em': '', 'fb': '', 'tin': '', 'bank': '', 'since': '2012', 'exp': '6 years baking and selling piaya',
        'bn': 'Lola Nena’s Piaya', 'pj': '', 'os': '2019-06', 'bd': 'Home-based bakery making piaya for stores in Jaro.',
        'pd': 'Flat bread filled with muscovado, baked fresh daily and sold in packs of 10.',
        'lab_prod': '1500', 'units_prod': '50',
        'es': '864000', 'ex': '684000', 'gi': '432000', 'ni': '180000',
        'la': '100000',
      }
      ..g = {
        'dist': ['2nd'], 'sex': ['Female'], 'civ': ['Married'],
        'loc': ['At my home'], 'own': ['Only me'], 'cr': ['Lose at least 1/5 of sales for 2 months'],
        'bt': ['I make products'], 'tm': ['Sari-sari stores', 'Pasalubong shops'], 'ma': ['My town or city'], 'md': ['Friends and neighbors', 'Facebook'],
      }
      ..lists = {
        'products': [
          {'name': 'Piaya', 'unit': 'Pack of 10', 'price': '120'},
          {'name': 'Ube piaya', 'unit': 'Pack of 10', 'price': '140'},
        ],
        'raw_prod': [
          {'name': 'Flour', 'source': 'Jaro Public Market', 'qty': '25', 'unit': 'kg', 'price': '44'},
          {'name': 'Muscovado sugar', 'source': 'Jaro Public Market', 'qty': '10', 'unit': 'kg', 'price': '80'},
          {'name': 'Margarine and oil', 'source': 'Iloilo Supermart', 'qty': '4', 'unit': 'L', 'price': '150'},
          {'name': 'Plastic packs', 'source': 'Iloilo Terminal Market', 'qty': '50', 'unit': 'pcs', 'price': '10'},
        ],
        'tools_prod': [
          {'name': 'Oven'},
          {'name': 'Mixing bowls and trays'},
        ],
        'ovh_prod': [
          {'name': 'Electricity', 'cost': '300'},
          {'name': 'Water', 'cost': '100'},
          {'name': 'Gas (LPG)', 'cost': '200'},
          {'name': 'Rent', 'cost': '100'},
        ],
        'workers': [
          {'name': 'Ana Reyes', 'sex': 'Female', 'status': 'Regular', 'work': 'Baker', 'years': '3', 'iloilo': 'Yes'},
          {'name': 'Jun Panes', 'sex': 'Male', 'status': 'Part-time', 'work': 'Packer and delivery', 'years': '2', 'iloilo': 'Yes'},
        ],
      }
      ..req = {'permit': 'verified', 'annexC': 'none'}
      ..trainings = [
        {'name': 'Food Safety and Handling', 'provider': 'DTI Negosyo Center', 'date': 'Mar 2025', 'status': 'verified'},
        {'name': 'Costing and Pricing', 'provider': 'DOST', 'date': 'Aug 2025', 'status': 'sent'},
        {'name': 'Simple Bookkeeping', 'provider': 'Coaching session', 'date': 'Jul 2024', 'status': 'none'},
      ];

    // Statements as the owner typed them (sample). 2019 cash flow and balance sheet,
    // and 2022 cash flow, are left empty on purpose to show "not added yet".
    d.years[2025] = YearStatements.sample2025();
    const scale = {2019: 0.2, 2020: 0.32, 2021: 0.46, 2022: 0.62, 2023: 0.78, 2024: 0.89};
    scale.forEach((y, f) {
      final s = YearStatements.sample2025().scaled(f);
      if (y == 2019) {
        s.cf.clear();
        s.bs.clear();
      }
      if (y == 2022) s.cf.clear();
      d.years[y] = s;
    });
    _cashFromCashFlow(d);
    return d;
  }

  /// TESTING ONLY (see `kTestAnswers`): the sample business with every
  /// question answered and every year's statements complete, so the whole
  /// app can be tapped through without typing.
  factory AppData.testFill() {
    final d = AppData.sample();
    d.v.addAll({
      'a1': '123 Rizal Street', 'em': 'maria.santos@example.com', 'fb': 'facebook.com/lolanenaspiaya', 'tin': '123-456-789-000',
      'bank': 'Landbank of the Philippines', 'pj': 'More ovens to bake twice as many piaya',
      'b1': '45 Jalandoni Street', 'b2': 'Tabuc Suba', 'b3': 'Iloilo City', 'b4': 'Iloilo', 'b5': '5000',
      'lab_resell': '1000', 'units_resell': '200', 'lab_service': '1200', 'units_service': '40',
    });
    d.lists.addAll({
      'raw_resell': [
        {'name': 'Rice', 'source': 'Iloilo Terminal Market', 'qty': '10', 'unit': 'sack', 'price': '1900'},
        {'name': 'Canned goods', 'source': 'Iloilo Supermart', 'qty': '48', 'unit': 'can', 'price': '35'},
      ],
      'tools_resell': [{'name': 'Weighing scale'}, {'name': 'Display shelf'}],
      'ovh_resell': [{'name': 'Electricity', 'cost': '150'}, {'name': 'Tricycle delivery', 'cost': '300'}],
      'raw_service': [
        {'name': 'Shampoo', 'source': 'Iloilo Supermart', 'qty': '4', 'unit': 'bottle', 'price': '180'},
        {'name': 'Hair color', 'source': 'Robinsons Place Iloilo', 'qty': '6', 'unit': 'box', 'price': '250'},
      ],
      'tools_service': [{'name': 'Hair dryer'}, {'name': 'Salon chair'}],
      'ovh_service': [{'name': 'Electricity', 'cost': '250'}, {'name': 'Water', 'cost': '80'}],
    });
    d.req = {'permit': 'saved', 'annexC': 'saved'};
    for (final t in d.trainings) {
      t['status'] = 'saved';
    }
    // Every year complete, nothing left empty.
    d.years[2025] = YearStatements.sample2025();
    const scale = {2019: 0.2, 2020: 0.32, 2021: 0.46, 2022: 0.62, 2023: 0.78, 2024: 0.89};
    scale.forEach((y, f) => d.years[y] = YearStatements.sample2025().scaled(f));
    _cashFromCashFlow(d);
    return d;
  }

  /// Sample only: sets each year's Cash on hand to its Cash ending, as a
  /// careful owner would, so the sample balance sheets look right.
  static void _cashFromCashFlow(AppData d) {
    YearFigures? prev;
    for (final y in d.years.keys.toList()..sort()) {
      final s = d.years[y]!;
      var f = computeYear(s.inc, s.cf, s.bs, prev);
      if (s.bs.isNotEmpty && f.cf['ce'] != null) {
        s.bs['cash'] = f.cf['ce']!;
        f = computeYear(s.inc, s.cf, s.bs, prev);
      }
      prev = f;
    }
  }
}

/// The three statements for one year, as the owner typed them. Totals are
/// worked out by `computeYear` and not stored.
class YearStatements {
  Map<String, String> inc = {}; // income statement lines
  Map<String, String> cf = {}; // cash flow lines
  Map<String, String> bs = {}; // balance sheet lines
  List<Map<String, String>> assets = []; // old free list of assets; replaced by fixed lines lb..eqd, kept for saved data

  YearStatements();

  Map<String, dynamic> toJson() => {'inc': inc, 'cf': cf, 'bs': bs, 'assets': assets};

  factory YearStatements.fromJson(Map<String, dynamic> j) {
    Map<String, String> m(dynamic x) => (x as Map? ?? {}).map((k, v) => MapEntry(k.toString(), v.toString()));
    return YearStatements()
      ..inc = m(j['inc'])
      ..cf = m(j['cf'])
      ..bs = m(j['bs'])
      ..assets = (j['assets'] as List? ?? []).map((r) => m(r)).toList();
  }

  /// Sample owner's typed lines for 2025 (totals are worked out by the app).
  factory YearStatements.sample2025() => YearStatements()
    ..inc = {'sales': '820000', 'bi': '20000', 'pu': '400000', 'ei': '15000', 'sw': '156000', 'pl': '6000', 'plw': '36000', 'tt': '24000'}
    ..cf = {'cb': '30000', 'cd': '180000'}
    ..bs = {'cash': '43000', 'lb': '60000', 'lbd': '12000', 'cm': '70000', 'cmd': '28000', 'eq': '25000', 'eqd': '10000', 'capb': '50000'};

  /// Only used to build sample years for the demo: the 2025 sample, scaled.
  YearStatements scaled(double f) {
    String s(String v) => '${((double.tryParse(v) ?? 0) * f / 1000).round() * 1000}';
    return YearStatements()
      ..inc = inc.map((k, v) => MapEntry(k, s(v)))
      ..cf = cf.map((k, v) => MapEntry(k, s(v)))
      ..bs = bs.map((k, v) => MapEntry(k, s(v)));
  }
}
