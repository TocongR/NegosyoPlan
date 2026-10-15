import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../logic/checks.dart';
import '../logic/format.dart';
import '../logic/statements.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/form.dart';
import '../i18n/tr.dart';

// S16 Check your answers (summary) · S17 Missing items · S18 Warnings · S19 Business plan review

String joinNonEmpty(Iterable<String?> parts, [String sep = ', ']) => parts.where((p) => (p ?? '').trim().isNotEmpty).join(sep);

/// Home address from Step 1.
String homeAddress(AppState a) => joinNonEmpty([a.val('a1'), a.val('a2'), a.val('a3'), joinNonEmpty([a.val('a4'), a.val('a5')], ' ')]);

/// Business address: home, or the one typed in Step 2.
String businessAddress(AppState a) => a.one('loc') == 'Somewhere else'
    ? joinNonEmpty([a.val('b1'), a.val('b2'), a.val('b3'), joinNonEmpty([a.val('b4'), a.val('b5')], ' ')])
    : homeAddress(a);

String fullName(AppState a) => joinNonEmpty([a.val('fn'), a.val('mn'), a.val('ln')], ' ');

/// One step on the summary, with an Edit link.
class SumCard extends StatelessWidget {
  final String step;
  final String title;
  final String forms;
  final String route;
  final Object? args;
  final List<Widget> children;
  const SumCard({super.key, required this.step, required this.title, required this.forms, required this.route, required this.children, this.args});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(16)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(
            padding: const EdgeInsets.only(bottom: 12),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.divider))),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(tr(step).toUpperCase(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: AppColors.muted2)),
                  Text(tr(title), style: AppText.h2),
                  Text(tr(forms), style: const TextStyle(fontSize: 13, color: AppColors.hint)),
                ]),
              ),
              OutlinedButton.icon(
                onPressed: () => Navigator.pushNamed(context, route, arguments: args),
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: Text(tr('Edit')),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  minimumSize: const Size(44, 44),
                  shape: const StadiumBorder(),
                  side: const BorderSide(color: AppColors.borderStrong),
                  textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, fontFamily: AppTheme.fontFamily),
                ),
              ),
            ]),
          ),
          ...children,
        ]),
      );
}

/// Key / value line. Blank answers show in red as "Not filled in".
class KV extends StatelessWidget {
  final String k;
  final String v;
  const KV(this.k, this.v, {super.key});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFF0F2F0)))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(tr(k), style: const TextStyle(fontSize: 14, color: AppColors.muted2)),
          v.trim().isEmpty
              ? Text(tr('Not filled in'), style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.missingFg))
              : Text(tr(v), style: const TextStyle(fontSize: 17, height: 1.4)),
        ]),
      );
}

/// List line with an amount on the right.
class LI extends StatelessWidget {
  final String title;
  final String? sub;
  final String? value;
  final bool missing;
  const LI(this.title, {super.key, this.sub, this.value, this.missing = false});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFF0F2F0)))),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(tr(title), style: const TextStyle(fontSize: 17, height: 1.4)),
              if (sub != null && sub!.isNotEmpty) Text(tr(sub!), style: const TextStyle(fontSize: 14, color: AppColors.muted2)),
            ]),
          ),
          if (missing)
            Text(tr('Not added yet'), style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.missingFg))
          else if (value != null)
            Text(tr(value!), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        ]),
      );
}

class TotalLine extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;
  const TotalLine(this.label, this.value, {super.key, this.highlight = false});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(children: [
          Expanded(child: Text(tr(label), style: TextStyle(fontSize: highlight ? 18 : 17, fontWeight: FontWeight.w700, color: highlight ? AppColors.primary : AppColors.text))),
          Text(tr(value), style: TextStyle(fontSize: highlight ? 18 : 17, fontWeight: FontWeight.w700, color: highlight ? AppColors.primary : AppColors.text)),
        ]),
      );
}

class SubTitle extends StatelessWidget {
  final String text;
  const SubTitle(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 14, bottom: 2),
        child: Text(tr(text), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.primary)),
      );
}

/// Statement lines for one year: typed lines and worked-out totals.
List<Widget> statementLines(AppState app, int year, StatementType t) {
  final vals = app.statementValues(year, t);
  final out = <Widget>[];
  for (final l in t.lines) {
    if (l.kind == LineKind.heading) {
      out.add(SubTitle(l.label));
      continue;
    }
    final v = vals[l.key];
    final shown = (v ?? '').trim().isEmpty ? '' : peso(amt(v));
    if (l.kind == LineKind.item) {
      out.add(shown.isEmpty ? LI(l.label, missing: true) : LI(l.label, value: shown));
    } else {
      out.add(shown.isEmpty ? LI(l.label, missing: true) : TotalLine(l.label, shown, highlight: l.kind == LineKind.grandTotal));
    }
  }
  return out;
}

class CheckAnswersScreen extends StatelessWidget {
  const CheckAnswersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final missing = missingItems(app);
    final kind = app.kind;
    final raw = app.rows('raw_$kind');
    final ovh = app.rows('ovh_$kind');
    final labor = amt(app.val('lab_$kind')) ?? 0;
    final materials = listTotal(raw, qtyTimesPrice);
    final other = listTotal(ovh, costOf);
    final batchTotal = materials + labor + other;
    final units = amt(app.val('units_$kind'));
    final kindTitle = switch (kind) { 'resell' => 'Buying your goods', 'service' => 'Your service supplies', _ => 'Making your product' };
    final period = switch (kind) { 'prod' => 'one batch', _ => 'one week' };
    final years = app.statementYears;
    int? latest = years.isEmpty ? null : years.last;
    for (final y in years.reversed) {
      if (app.yearComplete(y)) {
        latest = y;
        break;
      }
    }
    final la = amt(app.val('la'));
    final workersOk = qualifiedWorkers(app);

    return AppPage(
      title: 'Check your answers',
      chat: true,
      gap: 16,
      footer: Footer(vertical: true, [
        BigButton('Everything is correct', onPressed: () => Navigator.pushNamed(context, '/missing')),
        Text(tr('Next, we check for anything missing before making your documents.'), textAlign: TextAlign.center, style: AppText.small),
      ]),
      children: [
        Text(tr('This is everything that will go on your forms, exactly as you typed it. Read it once. Tap Edit to fix anything.'), style: AppText.lead),
        if (missing.isNotEmpty)
          NoteBox('They are marked in red below. You can still continue and add them later.',
              kind: NoteKind.warn, title: '${missing.length} ${missing.length == 1 ? 'thing is' : 'things are'} not filled in'),
        SumCard(step: 'Step 1', title: 'About you', forms: 'Application form · Barangay certificate · Business plan', route: '/about', children: [
          KV('Name', fullName(app)),
          KV('Home address', homeAddress(app)),
          KV('District', app.one('dist')),
          KV('Birthday', app.val('dob').isEmpty ? '' : DateQ.show(app.val('dob'))),
          KV('Male or female', app.one('sex')),
          KV('Civil status', app.one('civ')),
          KV('Mobile number', app.data.mobile.isEmpty ? '' : '${app.data.mobile} · from your account'),
          KV('Email', app.val('em')),
          KV('Facebook name', app.val('fb')),
          KV('TIN', app.val('tin')),
          KV('Bank', app.val('bank')),
          KV('Living in the barangay since', app.val('since')),
          KV('Experience', app.val('exp')),
        ]),
        SumCard(step: 'Step 2', title: 'Your business', forms: 'Application form · Barangay certificate · Business plan', route: '/business', children: [
          KV('Business name', app.val('bn')),
          KV('What the loan will help you do', app.val('pj')),
          KV('Business address', app.one('loc') == 'Somewhere else' ? businessAddress(app) : (homeAddress(app).isEmpty ? '' : 'At my home (same as Step 1)')),
          KV('Started', app.val('os').isEmpty ? '' : DateQ.show(app.val('os'), monthOnly: true)),
          KV('Who owns it', app.one('own')),
          KV('About the business', app.val('bd')),
          KV('During a crisis', app.one('cr')),
        ]),
        SumCard(step: 'Step 3', title: 'What you sell', forms: 'Application form · Business plan', route: '/products', children: [
          KV('Kind of business', app.one('bt')),
          const SubTitle('Products and prices'),
          if (app.rows('products').isEmpty) const LI('What you sell', missing: true),
          for (final p in app.rows('products')) LI(p['name'] ?? '', sub: p['unit'], value: peso(amt(p['price']))),
          KV('About it', app.val('pd')),
          KV('Who buys', app.sel('tm').join(', ')),
          KV('Where your customers are', app.sel('ma').join(', ')),
          KV('How people hear about you', app.sel('md').join(', ')),
        ]),
        SumCard(step: 'Step 4', title: kindTitle, forms: 'Business plan', route: app.costRoute, children: [
          SubTitle('Bought for $period'),
          if (raw.isEmpty) const LI('Nothing added', missing: true),
          for (final r in raw)
            LI(r['name'] ?? '',
                sub: '${r['qty'] ?? ''} ${r['unit'] ?? ''} × ${peso(amt(r['price']))}${(r['source'] ?? '').isEmpty ? '' : ' · ${r['source']}'}',
                value: peso(qtyTimesPrice(r))),
          TotalLine('Materials', peso(materials)),
          if (kind != 'resell') KV('Tools', app.rows('tools_$kind').map((t) => t['name'] ?? '').join(', ')),
          SubTitle('Other costs for $period'),
          LI('Workers’ pay', value: app.val('lab_$kind').isEmpty ? null : peso(labor), missing: app.val('lab_$kind').isEmpty),
          for (final o in ovh) LI(o['name'] ?? '', value: peso(costOf(o))),
          TotalLine('Total cost of $period', peso(batchTotal)),
          KV(kind == 'service' ? 'Customers served' : 'Made or sold from this', app.val('units_$kind')),
          if (units != null && units > 0) TotalLine('Your cost for each one', peso(batchTotal / units), highlight: true),
        ]),
        SumCard(step: 'Step 5', title: 'Financial statements by year', forms: 'Financial statements · Application form', route: '/financials', children: [
          for (final y in years) ...[
            SubTitle('$y · ${app.yearSpan(y)}'),
            for (final t in StatementType.values)
              Builder(builder: (_) {
                final p = app.progress(y, t);
                final (k, label) = t.headline;
                if (p == Progress.empty) return LI(t.title, missing: true);
                if (p == Progress.partial) return LI(t.title, sub: '${app.blankLines(y, t)} lines still blank', missing: true);
                return LI(t.title, sub: label, value: peso(amt(app.statementValues(y, t)[k])));
              }),
          ],
          if (years.isEmpty) const KV('Years', ''),
        ]),
        if (latest != null)
          for (final t in StatementType.values)
            SumCard(
              step: 'Step 5 · $latest',
              title: t.title,
              forms: 'Exactly as you typed it',
              route: t.route,
              args: latest,
              children: [
                if (t == StatementType.balance) KV('As of', 'December 31, $latest') else KV('Year', '$latest · ${app.yearSpan(latest)}'),
                ...statementLines(app, latest, t),
              ],
            ),
        SumCard(step: 'Step 6', title: 'Your workers', forms: 'Application form · Barangay certificate · Business plan', route: '/people', children: [
          if (app.rows('workers').isEmpty) const LI('Workers', missing: true),
          for (final w in app.rows('workers'))
            LI(w['name'] ?? '', sub: '${w['work'] ?? ''} · ${w['status'] ?? ''} · ${w['years'] ?? '—'} years · ${w['sex'] ?? ''} · ${w['iloilo'] == 'No' ? 'Lives outside Iloilo' : 'Lives in Iloilo'}'),
          const SizedBox(height: 10),
          NoteBox(
            workersOk >= 2
                ? '$workersOk workers have been with you 2 years or more and live in Iloilo. This meets the barangay certificate.'
                : 'The barangay certificate needs at least 2 workers with you 2 years or more who live in Iloilo. You have $workersOk.',
            kind: workersOk >= 2 ? NoteKind.ok : NoteKind.warn,
          ),
        ]),
        SumCard(step: 'Step 7', title: 'Financial projection', forms: 'Business plan (Annex D)', route: '/projection', children: [
          for (final (k, label) in const [
            ('es', 'Expected annual sales'),
            ('ex', 'Expected annual expenses'),
            ('gi', 'Expected annual gross income'),
            ('ni', 'Expected annual net income'),
          ])
            app.val(k).isEmpty ? LI(label, missing: true) : LI(label, value: peso(amt(app.val(k)))),
        ]),
        SumCard(step: 'Step 8', title: 'Your loan', forms: 'Application form', route: '/loan', children: [
          KV('Amount to borrow', la == null ? '' : peso(la)),
        ]),
      ],
    );
  }
}

class MissingScreen extends StatelessWidget {
  const MissingScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final items = missingItems(app);
    return AppPage(
      title: items.isEmpty ? 'Nothing is missing' : '${items.length} ${items.length == 1 ? 'thing is' : 'things are'} missing',
      gap: 14,
      footer: Footer([BigButton('Continue to review', onPressed: () => Navigator.pushNamed(context, '/warnings'))]),
      children: [
        Text(tr(items.isEmpty ? 'Good work. Everything the forms need is filled in.' : 'Fix these so your papers are not returned.'), style: AppText.lead),
        for (final m in items)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(border: Border.all(color: AppColors.missingBorder), borderRadius: BorderRadius.circular(16)),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(tr(m.label), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  Text(tr(m.where), style: const TextStyle(fontSize: 15, color: AppColors.muted)),
                ]),
              ),
              const SizedBox(width: 10),
              SizedBox(width: 104, child: BigButton('Fix this', height: 48, style: BtnStyle.dark, onPressed: () => Navigator.pushNamed(context, m.route, arguments: m.args))),
            ]),
          ),
        if (items.isNotEmpty) Text(tr('You can still review your plan now and come back to these.'), style: TextStyle(fontSize: 15, color: AppColors.muted)),
      ],
    );
  }
}

class WarningsScreen extends StatelessWidget {
  const WarningsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final list = warnings(app);
    return AppPage(
      title: 'Please check these',
      gap: 14,
      footer: Footer([BigButton('Review my business plan', onPressed: () => Navigator.pushNamed(context, '/plan'))]),
      children: [
        Text.rich(TextSpan(style: AppText.lead, children: [
          TextSpan(text: trn('Fix each one, or keep it as it is. ')),
          TextSpan(text: trn('${list.length} left'), style: const TextStyle(fontWeight: FontWeight.w700)),
        ])),
        for (final w in list)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppColors.warnBg, border: Border.all(color: AppColors.warnBorder, width: 1.5), borderRadius: BorderRadius.circular(16)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(tr(w.title), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text(tr(w.text), style: const TextStyle(fontSize: 16, height: 1.4, color: AppColors.text2)),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: BigButton('Fix this', height: 48, style: BtnStyle.dark, onPressed: () => Navigator.pushNamed(context, w.route, arguments: w.args))),
                const SizedBox(width: 10),
                Expanded(child: BigButton('Keep as is', height: 48, style: BtnStyle.secondary, onPressed: () => app.change((d) => d.keptWarnings.add(w.id)))),
              ]),
            ]),
          ),
        if (list.isEmpty) const NoteBox('Nothing left to check.', kind: NoteKind.ok),
      ],
    );
  }
}

/// S19 · The business plan in the order of Annex D, built from the answers.
class PlanReviewScreen extends StatefulWidget {
  const PlanReviewScreen({super.key});
  @override
  State<PlanReviewScreen> createState() => _PlanReviewScreenState();
}

class _PlanReviewScreenState extends State<PlanReviewScreen> {
  int _open = 0;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final kind = app.kind;
    final units = amt(app.val('units_$kind'));
    final batch = listTotal(app.rows('raw_$kind'), qtyTimesPrice) + (amt(app.val('lab_$kind')) ?? 0) + listTotal(app.rows('ovh_$kind'), costOf);
    final products = app.rows('products').map((p) => '${p['name']} ${peso(amt(p['price']))}${(p['unit'] ?? '').isEmpty ? '' : ' per ${p['unit']}'}').join('; ');
    final parts = <(String, String, String, bool)>[
      (
        '1. Background of the business',
        '${app.val('bn').isEmpty ? '[Business name]' : app.val('bn')}. Owner: ${fullName(app)}. ${app.val('bd')}',
        '/business',
        app.val('bn').isNotEmpty && app.val('bd').isNotEmpty,
      ),
      (
        '2. Marketing plan',
        'Products: ${products.isEmpty ? '—' : products}. Customers: ${app.sel('tm').join(', ')}. Market area: ${app.sel('ma').join(', ')}. Promotion: ${app.sel('md').join(', ')}.',
        '/products',
        app.rows('products').isNotEmpty,
      ),
      (
        '3. Production plan',
        'Materials, tools and costs for one ${kind == 'prod' ? 'batch' : 'week'}: ${peso(batch)}.${units != null && units > 0 ? ' Cost for each one: ${peso(batch / units)}.' : ''}',
        app.costRoute,
        app.rows('raw_$kind').isNotEmpty && units != null,
      ),
      (
        '4. Organization and management',
        'Experience: ${app.val('exp')}. ${app.rows('workers').length} workers.',
        '/people',
        app.val('exp').isNotEmpty && app.rows('workers').isNotEmpty,
      ),
      (
        '5. Financial plan',
        'Loan amount: ${peso(amt(app.val('la')))}. Expected annual sales ${peso(amt(app.val('es')))}, net income ${peso(amt(app.val('ni')))} (as you typed them). A LIDEP officer checks how the loan was used about 3 months after release.',
        '/loan',
        app.val('la').isNotEmpty && app.val('ni').isNotEmpty,
      ),
    ];
    return AppPage(
      title: 'Your business plan',
      gap: 12,
      footer: Footer([BigButton('Looks good — make my documents', onPressed: () => Navigator.pushNamed(context, '/consent'))]),
      children: [
        Text(tr('Read each part. Tap to open. It follows the Annex D business plan.'), style: AppText.lead),
        for (var i = 0; i < parts.length; i++)
          Container(
            decoration: BoxDecoration(border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(14)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              InkWell(
                onTap: () => setState(() => _open = _open == i ? -1 : i),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  child: Row(children: [
                    Container(
                      width: 28,
                      height: 28,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: parts[i].$4 ? AppColors.tint : AppColors.estimateBg),
                      child: Text(tr(parts[i].$4 ? '✓' : '!'), style: TextStyle(fontWeight: FontWeight.w700, color: parts[i].$4 ? AppColors.primary : AppColors.estimateFg)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Text(tr(parts[i].$1), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700))),
                    Icon(_open == i ? Icons.remove : Icons.add, color: AppColors.muted),
                  ]),
                ),
              ),
              if (_open == i)
                Padding(
                  padding: const EdgeInsets.fromLTRB(56, 0, 16, 16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(tr(parts[i].$2), style: const TextStyle(fontSize: 16, height: 1.5, color: AppColors.text2)),
                    const SizedBox(height: 10),
                    OutlinedButton(onPressed: () => Navigator.pushNamed(context, parts[i].$3), child: Text(tr('Edit answers'))),
                  ]),
                ),
            ]),
          ),
      ],
    );
  }
}
