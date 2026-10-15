import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config.dart';

import '../logic/checks.dart';
import '../logic/format.dart';
import '../logic/statements.dart';
import '../services/pdf_service.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/form.dart';
import 'review_screens.dart' show fullName, businessAddress;
import 'statement_download.dart';
import '../i18n/tr.dart';

// S24 Home · S25 Enterprise Passport · S26 Financial statements · S27 Settings

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final pct = readiness(app);
    final missing = missingItems(app).length;
    final hour = DateTime.now().hour;
    final greet = switch (app.data.lang) {
      'hil' => hour < 12 ? 'Maayong aga,' : (hour < 18 ? 'Maayong hapon,' : 'Maayong gab-i,'),
      'fil' => hour < 12 ? 'Magandang umaga,' : (hour < 18 ? 'Magandang hapon,' : 'Magandang gabi,'),
      _ => hour < 12 ? 'Good morning,' : (hour < 18 ? 'Good afternoon,' : 'Good evening,'),
    };
    Widget tile(IconData icon, String label, String route, {bool wide = false}) => Material(
          color: AppColors.surface2,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => Navigator.pushNamed(context, route),
            child: Container(
              constraints: BoxConstraints(minHeight: wide ? 96 : 120),
              padding: const EdgeInsets.all(18),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Icon(icon, color: AppColors.primary),
                const SizedBox(height: 12),
                Text(tr(label), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, height: 1.25)),
              ]),
            ),
          ),
        );
    return Scaffold(
      backgroundColor: Colors.white,
      floatingActionButton: const ChatFab(),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(padding: const EdgeInsets.fromLTRB(24, 24, 24, 100), children: spaced([
              Row(children: [
                const LogoMark(size: 40, word: false),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(tr(greet), style: const TextStyle(fontSize: 15, color: AppColors.muted2)),
                    Text(tr(app.firstName.isEmpty ? 'Welcome' : app.firstName), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700)),
                  ]),
                ),
                IconButton(tooltip: trn('Settings'), onPressed: () => Navigator.pushNamed(context, '/settings'), icon: const Icon(Icons.settings_outlined)),
              ]),
              Row(children: [
                Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle)),
                const SizedBox(width: 8),
                Text(tr('Saved on this phone'), style: TextStyle(fontSize: 15, color: AppColors.text2)),
              ]),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(20)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: spaced([
                  Row(children: [
                    Expanded(child: Text(tr('Loan papers'), style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white))),
                    Text(tr('${(pct * 100).round()}%'), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: Colors.white)),
                  ]),
                  ProgressBar(pct, height: 10, background: const Color(0x4DFFFFFF), color: AppColors.mint),
                  Text(tr(missing == 0 ? 'Nothing missing' : '$missing ${missing == 1 ? 'thing' : 'things'} missing'), style: const TextStyle(fontSize: 16, color: Colors.white)),
                  SizedBox(
                    height: 56,
                    child: TextButton(
                      onPressed: () => Navigator.pushNamed(context, missing == 0 ? '/check' : '/missing'),
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, fontFamily: AppTheme.fontFamily),
                      ),
                      child: Text(tr('Continue')),
                    ),
                  ),
                ], 14)),
              ),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.25,
                children: [
                  tile(Icons.description_outlined, 'Business plan', '/plan'),
                  tile(Icons.bar_chart, 'Financial statements', '/statements'),
                  tile(Icons.fact_check_outlined, 'Requirements and trainings', '/requirements'),
                  tile(Icons.badge_outlined, 'Enterprise Passport', '/passport'),
                ],
              ),
              tile(Icons.download_outlined, 'Documents', '/documents', wide: true),
              if (app.data.v.isEmpty)
                NoteBox('Start your Enterprise Passport to make your business plan.',
                    title: 'Not started yet', action: LinkButton('Begin', onPressed: () => Navigator.pushNamed(context, '/passport-start'))),
            ], 24)),
          ),
        ),
      ),
    );
  }
}

class PassportScreen extends StatefulWidget {
  const PassportScreen({super.key});
  @override
  State<PassportScreen> createState() => _PassportScreenState();
}

class _PassportScreenState extends State<PassportScreen> {
  String _tab = 'Business';

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    String st(String s) => switch (s) { 'verified' => 'Verified', 'sent' => 'Sent', 'saved' => 'Photo saved', _ => 'Not yet' };
    final years = app.statementYears;
    final data = <String, List<(String, String, bool)>>{
      'You': [
        ('Name', fullName(app), false),
        ('Years in barangay', app.val('since').isEmpty ? '' : 'Since ${app.val('since')}', false),
        ('Experience', app.val('exp'), false),
      ],
      'Business': [
        ('Business name', app.val('bn'), false),
        ('Location', businessAddress(app), false),
        ('Started', app.val('os').isEmpty ? '' : DateQ.show(app.val('os'), monthOnly: true), false),
        ('Workers', '${app.rows('workers').length}', false),
      ],
      'Money': [
        for (final y in years.reversed.take(3)) ('$y net income', peso(amt(app.statementValues(y, StatementType.income)['ni'])), false),
        ('Loan needed', app.val('la').isEmpty ? '' : peso(amt(app.val('la'))), false),
      ],
      'Papers': [
        ('Business permit', st(app.reqStatus('permit')), app.reqStatus('permit') == 'verified'),
        ('Certificate of Residency and Business Operation', st(app.reqStatus('annexC')), app.reqStatus('annexC') == 'verified'),
        for (final t in app.trainingFiles) ('Training: ${t.title}', [t.provider, t.date].where((x) => x.isNotEmpty).join(' · '), false),
      ],
    };
    return AppPage(
      title: 'Enterprise Passport',
      gap: 16,
      footer: Footer([
        BigButton('Edit', style: BtnStyle.secondary, onPressed: () => Navigator.pushNamed(context, '/check')),
        BigButton('Download', onPressed: () => Navigator.pushNamed(context, '/preview', arguments: DocType.passport.name)),
      ]),
      children: [
        Text(tr('${app.val('bn').isEmpty ? 'Your business' : app.val('bn')} · saved on this phone'), style: const TextStyle(fontSize: 15, color: AppColors.muted)),
        SegmentedButton<String>(
          segments: [for (final k in data.keys) ButtonSegment(value: k, label: Text(tr(k)))],
          selected: {_tab},
          showSelectedIcon: false,
          onSelectionChanged: (s) => setState(() => _tab = s.first),
        ),
        for (final (k, v, verified) in data[_tab]!)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.divider))),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(tr(k), style: const TextStyle(fontSize: 14, color: AppColors.muted)),
                  Text(tr(v.isEmpty ? '—' : v), style: const TextStyle(fontSize: 17)),
                ]),
              ),
              StatusTag(verified ? TagKind.verified : TagKind.self),
            ]),
          ),
        Text(tr('Use this again for EMBRACE and other financing, training and assistance programs.'), style: AppText.small),
      ],
    );
  }
}

/// Everyday view of the statements, by year and exactly as typed.
class StatementsScreen extends StatefulWidget {
  const StatementsScreen({super.key});
  @override
  State<StatementsScreen> createState() => _StatementsScreenState();
}

class _StatementsScreenState extends State<StatementsScreen> {
  StatementType _tab = StatementType.income;
  int? _year;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final years = app.statementYears;
    final year = _year != null && years.contains(_year) ? _year! : (years.isEmpty ? null : years.last);
    final p = year == null ? Progress.empty : app.progress(year, _tab);
    final vals = year == null ? <String, String>{} : app.statementValues(year, _tab);

    final rows = <Widget>[];
    if (year != null && p != Progress.empty) {
      for (final l in _tab.lines) {
        if (l.kind == LineKind.heading) {
          rows.add(Padding(
            padding: const EdgeInsets.only(top: 18, bottom: 4),
            child: Text(tr(l.label).toUpperCase(), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 0.7, color: AppColors.muted2)),
          ));
          continue;
        }
        final v = vals[l.key];
        rows.add(KeyValueRow('${l.indent ? '   ' : ''}${l.label}', (v ?? '').isEmpty ? '—' : peso(amt(v)), total: l.kind != LineKind.item));
      }
    }

    return AppPage(
      title: 'Financial statements',
      chat: true,
      gap: 18,
      footer: Footer([
        BigButton('See printable version', style: BtnStyle.secondary, onPressed: () => Navigator.pushNamed(context, '/preview', arguments: switch (_tab) {
              StatementType.income => DocType.income.name,
              StatementType.cashFlow => DocType.cashFlow.name,
              StatementType.balance => DocType.balance.name,
            })),
        BigButton('Download', icon: Icons.download_outlined, onPressed: () => showStatementDownload(context, app)),
      ]),
      children: [
        if (years.isEmpty)
          NoteBox('Tell us when your business started (Step 2) to list your years.', action: LinkButton('Go to Step 2', onPressed: () => Navigator.pushNamed(context, '/business')))
        else
          FieldBlock(
            label: 'Year',
            child: DropdownButtonFormField<int>(
              value: year,
              items: [for (final y in years.reversed) DropdownMenuItem(value: y, child: Text(tr(app.start?.$1 == y ? '$y (first year)' : '$y'), style: const TextStyle(fontSize: 18)))],
              onChanged: (v) => setState(() => _year = v),
            ),
          ),
        SegmentedButton<StatementType>(
          segments: [
            ButtonSegment(value: StatementType.income, label: Text(tr('Income'))),
            ButtonSegment(value: StatementType.cashFlow, label: Text(tr('Cash flow'))),
            ButtonSegment(value: StatementType.balance, label: Text(tr('Balance'))),
          ],
          selected: {_tab},
          showSelectedIcon: false,
          onSelectionChanged: (s) => setState(() => _tab = s.first),
        ),
        if (year != null && p == Progress.empty)
          NoteBox('You have not typed this statement for $year.',
              title: 'Not added yet', kind: NoteKind.warn, action: LinkButton('Add it now', onPressed: () => Navigator.pushNamed(context, _tab.route, arguments: year))),
        if (year != null && p != Progress.empty) ...[
          Text(tr(_tab == StatementType.balance ? 'As of December 31, $year' : 'For the year $year · ${app.yearSpan(year)}'), style: const TextStyle(fontSize: 15, color: AppColors.muted)),
          Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: rows),
          const NoteBox('These are the amounts you typed. NegosyoPlan does not change them. A bookkeeper or OLEDIPO staff can check them before you submit.'),
          Align(alignment: Alignment.centerLeft, child: OutlinedButton(onPressed: () => Navigator.pushNamed(context, _tab.route, arguments: year), child: Text(tr('Edit this statement')))),
        ],
      ],
    );
  }
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final langName = switch (app.data.lang) { 'hil' => 'Hiligaynon', 'fil' => 'Filipino', _ => 'English' };
    Widget row(String title, {String? sub, Widget? trailing, VoidCallback? onTap, Color? color}) => ListTile(
          contentPadding: EdgeInsets.zero,
          minVerticalPadding: 14,
          title: Text(tr(title), style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: color)),
          subtitle: sub == null ? null : Text(tr(sub), style: const TextStyle(fontSize: 15)),
          trailing: trailing,
          onTap: onTap,
        );
    return AppPage(
      title: 'Settings',
      gap: 8,
      children: [
        const SectionHead('Easy to use'),
        row('Language', trailing: Text(tr('$langName ›'), style: const TextStyle(fontSize: 16)), onTap: () => Navigator.pushNamed(context, '/language')),
        Text(tr('Text size'), style: AppText.label),
        const SizedBox(height: 6),
        SegmentedButton<int>(
          segments: [
            ButtonSegment(value: 0, label: Text(tr('Normal'))),
            ButtonSegment(value: 1, label: Text(tr('Large'), style: TextStyle(fontSize: 18))),
            ButtonSegment(value: 2, label: Text(tr('Largest'), style: TextStyle(fontSize: 20))),
          ],
          selected: {app.data.textSize},
          showSelectedIcon: false,
          onSelectionChanged: (s) => app.change((d) => d.textSize = s.first),
        ),
        row('Read questions aloud',
            // TODO(tts): read questions with flutter_tts when this is on.
            trailing: AppSwitch(value: app.data.readAloud, onChanged: (v) => app.change((d) => d.readAloud = v), semanticLabel: trn('Read questions aloud'))),
        const SizedBox(height: 10),
        const SectionHead('Your data'),
        row('Sync and backup', sub: 'Needs internet. Coming soon.', onTap: () => toast(context, 'Sync is not available yet. Your data is saved on this phone.')),
        row('Who can see my data', trailing: Text(tr(app.data.consentShare ? 'Me and OLEDIPO ›' : 'Only me ›'), style: const TextStyle(fontSize: 16)), onTap: () => Navigator.pushNamed(context, '/consent')),
        row('Try with a sample business', sub: 'Replaces your answers with sample answers', onTap: () async {
          final ok = await showDialog<bool>(
            context: context,
            builder: (c) => AlertDialog(
              title: Text(tr('Use sample answers?')),
              content: Text(tr('Your current answers will be replaced.')),
              actions: [
                TextButton(onPressed: () => Navigator.pop(c, false), child: Text(tr('Cancel'))),
                FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(tr('Use sample'))),
              ],
            ),
          );
          if (ok == true) app.loadSample();
        }),
        if (kTestAnswers)
          row('Fill all answers with test data', sub: 'Testing only. Replaces your answers so you can tap through without typing.', onTap: () {
            app.loadTestAnswers();
            toast(context, 'Test answers filled in.');
          }),
        row('Log out', onTap: () {
          app.logout();
          Navigator.pushNamedAndRemoveUntil(context, '/login', (r) => false);
        }),
        row('Delete my data', color: AppColors.missingFg, onTap: () async {
          final ok = await showDialog<bool>(
            context: context,
            builder: (c) => AlertDialog(
              title: Text(tr('Delete everything?')),
              content: Text(tr('Your account and all your answers will be removed from this phone. This cannot be undone.')),
              actions: [
                TextButton(onPressed: () => Navigator.pop(c, false), child: Text(tr('Cancel'))),
                FilledButton(style: FilledButton.styleFrom(backgroundColor: AppColors.missingFg), onPressed: () => Navigator.pop(c, true), child: Text(tr('Delete'))),
              ],
            ),
          );
          if (ok == true) {
            await app.deleteAll();
            if (context.mounted) Navigator.pushNamedAndRemoveUntil(context, '/welcome', (r) => false);
          }
        }),
      ],
    );
  }
}
