import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../logic/format.dart';
import '../services/pdf_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'admin_data.dart';

// OLEDIPO staff dashboard. Sample data only; staff sign-in and the server API
// still need to be built (see README).

enum AdminSection { overview, passports, documents, reports, staff, privacy }

extension AdminSectionInfo on AdminSection {
  String get label => switch (this) {
        AdminSection.overview => 'Overview',
        AdminSection.passports => 'MSME Passports',
        AdminSection.documents => 'Requirements review',
        AdminSection.reports => 'Reports',
        AdminSection.staff => 'Staff and roles',
        AdminSection.privacy => 'Privacy and audit',
      };
}

/// What the side drawer shows.
enum _DrawerMode { application, requirements }

class AdminShell extends StatefulWidget {
  const AdminShell({super.key});
  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  final _store = AdminStore();
  final _scaffold = GlobalKey<ScaffoldState>();
  AdminSection _section = AdminSection.overview;
  Application? _selected;
  _DrawerMode _mode = _DrawerMode.application;

  @override
  void dispose() {
    _store.dispose();
    super.dispose();
  }

  void _go(AdminSection s) {
    setState(() => _section = s);
    if (_scaffold.currentState?.isDrawerOpen ?? false) Navigator.pop(context);
  }

  /// Opens the side drawer for an application or its requirements.
  void _open(Application a, _DrawerMode mode) {
    if (mode == _DrawerMode.application) {
      _store.viewed(a);
    } else {
      _store.checkedRequirements(a);
    }
    setState(() {
      _selected = a;
      _mode = mode;
    });
    if (!(_scaffold.currentState?.isEndDrawerOpen ?? false)) _scaffold.currentState?.openEndDrawer();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AdminStore>.value(
      value: _store,
      child: Consumer<AdminStore>(builder: (context, store, _) {
        return LayoutBuilder(builder: (context, c) {
          final wide = c.maxWidth >= 1000;
          final sidebar = _Sidebar(current: _section, store: store, onGo: _go);
          return Scaffold(
            key: _scaffold,
            backgroundColor: AppColors.adminBg,
            appBar: wide
                ? null
                : AppBar(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    title: Text(_section.label),
                  ),
            drawer: wide ? null : Drawer(backgroundColor: AppColors.primary, child: sidebar),
            endDrawer: _selected == null
                ? null
                : Drawer(
                    width: 560,
                    backgroundColor: Colors.white,
                    child: _mode == _DrawerMode.application
                        ? _ApplicationDetail(app: _selected!, onRequirements: () => _open(_selected!, _DrawerMode.requirements))
                        : _RequirementsDrawer(app: _selected!, onApplication: () => _open(_selected!, _DrawerMode.application)),
                  ),
            body: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              if (wide) SizedBox(width: 260, child: Material(color: AppColors.primary, child: sidebar)),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(horizontal: wide ? 48 : 20, vertical: wide ? 36 : 20),
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 1100), child: _content(store)),
                  ),
                ),
              ),
            ]),
          );
        });
      }),
    );
  }

  Widget _content(AdminStore s) => switch (_section) {
        AdminSection.overview => _Overview(store: s, onGo: _go),
        AdminSection.passports => _Passports(store: s, onOpen: _open),
        AdminSection.documents => _Documents(store: s),
        AdminSection.reports => _Reports(store: s),
        AdminSection.staff => _Staff(store: s),
        AdminSection.privacy => _Privacy(store: s),
      };
}

// ------------------------------------------------------------ shared pieces

/// Sidebar. No count badges.
class _Sidebar extends StatelessWidget {
  final AdminSection current;
  final AdminStore store;
  final ValueChanged<AdminSection> onGo;
  const _Sidebar({required this.current, required this.store, required this.onGo});

  @override
  Widget build(BuildContext context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 24, 14, 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(
                    width: 44,
                    height: 44,
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                    child: Image.asset('assets/images/logo.png'),
                  ),
                  const SizedBox(width: 12),
                  const Text('NegosyoPlan', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700, color: Colors.white)),
                ]),
                const SizedBox(height: 8),
                const Text('OLEDIPO Admin · EMBRACE Program', style: TextStyle(fontSize: 13, color: AppColors.adminSideMuted)),
              ]),
            ),
            for (final s in AdminSection.values)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Material(
                  color: s == current ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => onGo(s),
                    child: Container(
                      height: 48,
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Text(s.label,
                          style: TextStyle(fontSize: 16, color: s == current ? AppColors.primary : Colors.white, fontWeight: s == current ? FontWeight.w700 : FontWeight.w400)),
                    ),
                  ),
                ),
              ),
            const Spacer(),
            const Divider(color: Color(0x26FFFFFF)),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
              child: Text('Signed in as ${store.me} · Admin\nSample data for demo', style: const TextStyle(fontSize: 14, height: 1.5, color: AppColors.adminSideMuted)),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => Navigator.of(context, rootNavigator: true).pushNamedAndRemoveUntil('/', (r) => false),
                style: TextButton.styleFrom(foregroundColor: Colors.white),
                child: const Text('Sign out'),
              ),
            ),
          ]),
        ),
      );
}

class _Header extends StatelessWidget {
  final String title;
  final String? sub;
  final List<Widget> actions;
  const _Header(this.title, {this.sub, this.actions = const []});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 22),
        child: Wrap(spacing: 16, runSpacing: 12, alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.end, children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Semantics(header: true, child: Text(title, style: AppText.h1Desktop.copyWith(fontSize: 30))),
              if (sub != null) ...[const SizedBox(height: 6), Text(sub!, style: AppText.lead.copyWith(fontSize: 16))],
            ]),
          ),
          if (actions.isNotEmpty) Wrap(spacing: 8, runSpacing: 8, children: actions),
        ]),
      );
}

Widget _btn(String label, VoidCallback onPressed, {BtnStyle style = BtnStyle.primary, double width = 170, double height = 46}) =>
    SizedBox(width: width, child: BigButton(label, style: style, height: height, onPressed: onPressed));

class _Kpis extends StatelessWidget {
  final List<(String, String, String)> items;
  const _Kpis(this.items);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: Wrap(spacing: 12, runSpacing: 12, children: [
          for (final (l, v, s) in items)
            SizedBox(
              width: 196,
              child: CardBox(
                padding: const EdgeInsets.all(16),
                radius: 14,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(l, style: AppText.small.copyWith(fontSize: 14)),
                  const SizedBox(height: 4),
                  Text(v, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700)),
                  Text(s, style: AppText.tiny),
                ]),
              ),
            ),
        ]),
      );
}

class _Bars extends StatelessWidget {
  final List<(String, num)> rows;
  const _Bars(this.rows);
  @override
  Widget build(BuildContext context) {
    final max = rows.fold<num>(1, (a, r) => r.$2 > a ? r.$2 : a);
    return Column(children: [
      for (final (l, n) in rows)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(children: [
            SizedBox(width: 170, child: Text(l, style: const TextStyle(fontSize: 14))),
            Expanded(child: ProgressBar(n / max, height: 14, background: AppColors.divider)),
            SizedBox(width: 44, child: Text('$n', textAlign: TextAlign.right, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700))),
          ]),
        ),
    ]);
  }
}

class StatusPill extends StatelessWidget {
  final String label;
  const StatusPill(this.label, {super.key});
  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (label) {
      'Invited' => (AppColors.actualBg, AppColors.actualFg),
      'Accepted' || 'Verified' || 'Active' => (AppColors.tint, AppColors.primary),
      'Returned for completion' || 'New copy requested' => (AppColors.missingBg, AppColors.missingFg),
      'Pending' => (AppColors.estimateBg, AppColors.estimateFg),
      _ => (AppColors.surface2, AppColors.text2),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
      child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: fg)),
    );
  }
}

/// White card with a title.
class _Panel extends StatelessWidget {
  final String? title;
  final Widget child;
  const _Panel({this.title, required this.child});
  @override
  Widget build(BuildContext context) => CardBox(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (title != null) ...[Text(title!, style: AppText.h2.copyWith(fontSize: 19)), const SizedBox(height: 12)],
          child,
        ]),
      );
}

/// Two panels side by side on wide screens, stacked on narrow.
class _Pair extends StatelessWidget {
  final Widget a;
  final Widget b;
  const _Pair(this.a, this.b);
  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, c) => c.maxWidth >= 760
            ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: a), const SizedBox(width: 16), Expanded(child: b)])
            : Column(children: [a, const SizedBox(height: 16), b]),
      );
}

/// Horizontal-scrolling data table in a card.
class _Table extends StatelessWidget {
  final List<String> columns;
  final List<List<Widget>> rows;
  const _Table({required this.columns, required this.rows});
  @override
  Widget build(BuildContext context) => CardBox(
        padding: EdgeInsets.zero,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(const Color(0xFFF7F8F7)),
            headingTextStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.muted, fontFamily: AppTheme.fontFamily),
            dataRowMinHeight: 60,
            dataRowMaxHeight: 76,
            columns: [for (final c in columns) DataColumn(label: Text(c.toUpperCase()))],
            rows: [for (final r in rows) DataRow(cells: [for (final cell in r) DataCell(cell)])],
          ),
        ),
      );
}

// ------------------------------------------------------------ sections

class _Overview extends StatelessWidget {
  final AdminStore store;
  final ValueChanged<AdminSection> onGo;
  const _Overview({required this.store, required this.onGo});

  @override
  Widget build(BuildContext context) {
    final s = store;
    final returned = s.count(AppStatus.returned);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _Header('Overview',
          sub: 'EMBRACE applications prepared with NegosyoPlan. Loan approval is decided by the EMBRACE TWG, not by this system.',
          actions: [_btn('Open reports', () => onGo(AdminSection.reports), style: BtnStyle.secondary, width: 150)]),
      _Kpis([
        ('Applicants', '${s.apps.length}', 'Sharing by consent'),
        ('Pending', '${s.count(AppStatus.pending)}', 'Waiting for review'),
        ('Accepted', '${s.count(AppStatus.accepted)}', 'Papers complete'),
        ('Avg. preparation', '${s.avgPrep.toStringAsFixed(1)} days', 'Baseline: 7–14 days'),
        ('Returned for completion', '$returned', '${(100 * returned / (s.submittedLike.isEmpty ? 1 : s.submittedLike.length)).round()}% of submitted'),
      ]),
      _Pair(
        _Panel(title: 'Applications by status', child: _Bars([for (final st in AppStatus.values) (st.label, s.count(st))])),
        _Panel(
          title: 'Recent activity',
          child: Column(children: [
            for (final e in s.audit.take(5))
              Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.divider))),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  SizedBox(width: 110, child: Text(e.time, style: AppText.tiny.copyWith(fontSize: 14))),
                  Expanded(child: Text(e.action, style: const TextStyle(fontSize: 15))),
                ]),
              ),
            Align(alignment: Alignment.centerLeft, child: LinkButton('See audit log', onPressed: () => onGo(AdminSection.privacy))),
          ]),
        ),
      ),
    ]);
  }
}

/// MSME Passports: each applicant's business profile and loan application in one place.
class _Passports extends StatefulWidget {
  final AdminStore store;
  final void Function(Application, _DrawerMode) onOpen;
  const _Passports({required this.store, required this.onOpen});
  @override
  State<_Passports> createState() => _PassportsState();
}

class _PassportsState extends State<_Passports> {
  String _q = '';
  String _town = 'All towns';
  AppStatus? _status;

  @override
  Widget build(BuildContext context) {
    final s = widget.store;
    final towns = ['All towns', ...{for (final a in s.apps) a.town}.toList()..sort()];
    final q = _q.trim().toLowerCase();
    final rows = s.apps
        .where((a) =>
            (_status == null || a.status == _status) &&
            (_town == 'All towns' || a.town == _town) &&
            (q.isEmpty || '${a.owner} ${a.business} ${a.id}'.toLowerCase().contains(q)))
        .toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _Header('MSME Passports',
          sub: 'Each applicant’s business profile and loan application, shared with OLEDIPO by consent. Open one to accept it or return it for completion.',
          actions: [_btn('Export list (CSV)', () => toast(context, 'Export needs the server connection'), style: BtnStyle.secondary, width: 180)]),
      _Kpis([
        ('Passports shared', '${s.apps.length}', 'By applicant consent'),
        ('Pending', '${s.count(AppStatus.pending)}', 'Waiting for review'),
        ('Accepted', '${s.count(AppStatus.accepted)}', 'Papers complete'),
        ('Returned for completion', '${s.count(AppStatus.returned)}', 'Waiting for the applicant'),
      ]),
      _Panel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Wrap(spacing: 12, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.end, children: [
            SizedBox(
              width: 360,
              child: FieldBlock(label: 'Search name, business or ID', child: AppTextField(initial: _q, hint: 'e.g. Piaya or EMB-2026-0141', onChanged: (v) => setState(() => _q = v))),
            ),
            SizedBox(
              width: 240,
              child: FieldBlock(
                label: 'Town or city',
                child: DropdownButtonFormField<String>(
                  value: _town,
                  items: [for (final t in towns) DropdownMenuItem(value: t, child: Text(t))],
                  onChanged: (v) => setState(() => _town = v ?? 'All towns'),
                ),
              ),
            ),
          ]),
          const SizedBox(height: 14),
          Wrap(spacing: 8, runSpacing: 8, children: [
            ChoiceChip(label: Text('All · ${s.apps.length}'), selected: _status == null, onSelected: (_) => setState(() => _status = null)),
            for (final st in AppStatus.values)
              ChoiceChip(label: Text('${st.label} · ${s.count(st)}'), selected: _status == st, onSelected: (_) => setState(() => _status = st)),
          ]),
        ]),
      ),
      const SizedBox(height: 16),
      if (rows.isEmpty) const NoteBox('No passports match these filters.'),
      Wrap(spacing: 16, runSpacing: 16, children: [
        for (final a in rows)
          SizedBox(
            width: 480,
            child: CardBox(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(a.business, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                      Text('${a.owner} · ${a.town} · ${a.type}', style: AppText.tiny.copyWith(fontSize: 14)),
                      Text('${a.id} · Loan ${peso(a.loan)}', style: AppText.tiny.copyWith(fontSize: 14)),
                    ]),
                  ),
                  StatusPill(a.status.label),
                ]),
                const SizedBox(height: 8),
                Text(
                    '${a.completeness}% complete  ·  ${s.docsFor(a).where((d) => d.status == DocStatus.verified).length} verified  ·  ${a.trainings} trainings',
                    style: const TextStyle(fontSize: 14)),
                const SizedBox(height: 8),
                ProgressBar(a.completeness / 100, background: AppColors.divider),
                const SizedBox(height: 12),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  _btn('Open', () => widget.onOpen(a, _DrawerMode.application), width: 100, height: 40),
                  _btn('Check requirements', () => widget.onOpen(a, _DrawerMode.requirements), style: BtnStyle.secondary, width: 190, height: 40),
                ]),
              ]),
            ),
          ),
      ]),
    ]);
  }
}

class _DrawerHead extends StatelessWidget {
  final Application app;
  final String eyebrow;
  const _DrawerHead(this.app, this.eyebrow);
  @override
  Widget build(BuildContext context) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(eyebrow, style: AppText.small.copyWith(fontWeight: FontWeight.w700)),
            Text(app.business, style: AppText.h2.copyWith(fontSize: 24)),
            Text('${app.owner} · ${app.town}', style: AppText.small),
          ]),
        ),
        IconButton.outlined(tooltip: 'Close', onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
      ]);
}

/// Side drawer: one application. Accept, or return for completion with a note.
class _ApplicationDetail extends StatefulWidget {
  final Application app;
  final VoidCallback onRequirements;
  const _ApplicationDetail({required this.app, required this.onRequirements});
  @override
  State<_ApplicationDetail> createState() => _ApplicationDetailState();
}

class _ApplicationDetailState extends State<_ApplicationDetail> {
  String _note = '';

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AdminStore>();
    final a = widget.app;
    final docs = store.docsFor(a);
    final actions = <Widget>[];
    void add(String l, BtnStyle st, VoidCallback f, {double w = 170}) => actions.add(_btn(l, f, style: st, width: w));
    switch (a.status) {
      case AppStatus.pending:
        add('Accept', a.missing.isEmpty ? BtnStyle.primary : BtnStyle.secondary, () {
          if (a.missing.isNotEmpty) {
            toast(context, 'Cannot accept: ${a.missing.length} item(s) still missing');
            return;
          }
          store.setStatus(a, AppStatus.accepted, 'Accepted');
        }, w: 120);
        add('Return for completion', BtnStyle.danger, () {
          if (_note.trim().isEmpty) {
            toast(context, 'Write a note so the applicant knows what to fix');
            return;
          }
          store.setStatus(a, AppStatus.returned, 'Returned for completion (${_note.trim()}):');
        }, w: 230);
      case AppStatus.returned:
        add('Mark as pending again', BtnStyle.primary, () => store.setStatus(a, AppStatus.pending, 'Marked pending again:'), w: 230);
      case AppStatus.accepted:
        add('Move back to pending', BtnStyle.secondary, () => store.setStatus(a, AppStatus.pending, 'Moved back to pending:'), w: 230);
    }

    Widget kv(String k, String v) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(width: 150, child: Text(k, style: AppText.small)),
            Expanded(child: Text(v, style: const TextStyle(fontSize: 15))),
          ]),
        );

    return SafeArea(
      child: ListView(padding: const EdgeInsets.all(28), children: spaced([
        _DrawerHead(a, a.id),
        Align(alignment: Alignment.centerLeft, child: StatusPill(a.status.label)),
        Column(children: [
          kv('Business type', a.type),
          kv('Loan requested', '${peso(a.loan)} · ${a.years} ${a.years == 1 ? 'year' : 'years'}'),
          kv('Submitted', a.submitted),
          kv('Preparation time', a.prepDays == null ? 'Still preparing' : '${a.prepDays} days (baseline 7–14)'),
          kv('Completeness', '${a.completeness}%'),
        ]),
        _Panel(
          title: 'Still missing',
          child: a.missing.isEmpty
              ? const NoteBox('Nothing missing', kind: NoteKind.ok)
              : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [for (final m in a.missing) Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Text(m, style: const TextStyle(fontSize: 15)))]),
        ),
        _Panel(
          title: 'Uploaded documents',
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (docs.isEmpty) const Text('No uploads yet.', style: AppText.small),
            for (final d in docs)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(children: [
                  Expanded(child: Text(d.doc, style: const TextStyle(fontSize: 15))),
                  StatusPill(d.status.label),
                  const SizedBox(width: 8),
                  _btn('View', () => showDocViewer(context, store, d), style: BtnStyle.secondary, width: 80, height: 38),
                ]),
              ),
            LinkButton('Check these requirements', onPressed: widget.onRequirements),
          ]),
        ),
        FieldBlock(
          label: 'Note to applicant (sent with “Return for completion”)',
          child: AppTextField(initial: '', maxLines: 3, hint: 'Example: Please bring the barangay certificate signed by the captain.', onChanged: (v) => _note = v),
        ),
        Wrap(spacing: 8, runSpacing: 8, children: actions),
        const NoteBox('Accepted means the papers are complete. The EMBRACE TWG still decides on the loan.'),
      ], 16)),
    );
  }
}

/// Side drawer: one applicant's uploaded requirements. Files open with View only.
class _RequirementsDrawer extends StatelessWidget {
  final Application app;
  final VoidCallback onApplication;
  const _RequirementsDrawer({required this.app, required this.onApplication});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AdminStore>();
    final docs = store.docsFor(app);
    int n(DocStatus st) => docs.where((d) => d.status == st).length;
    return SafeArea(
      child: ListView(padding: const EdgeInsets.all(28), children: spaced([
        _DrawerHead(app, '${app.id} · Requirements'),
        Text('${n(DocStatus.verified)} verified  ·  ${n(DocStatus.pending)} to check  ·  ${n(DocStatus.newCopy)} new copy asked', style: const TextStyle(fontSize: 14)),
        if (docs.isEmpty) const NoteBox('No files uploaded yet.'),
        for (final d in docs)
          CardBox(
            padding: const EdgeInsets.all(16),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(d.doc, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  if (d.detail.isNotEmpty) Text(d.detail, style: AppText.tiny),
                  Text('Uploaded ${d.uploaded}', style: AppText.tiny),
                  if (d.note.isNotEmpty) Text('Note: ${d.note}', style: AppText.tiny),
                  const SizedBox(height: 10),
                  _btn('View', () => showDocViewer(context, store, d), style: BtnStyle.secondary, width: 90, height: 40),
                ]),
              ),
              const SizedBox(width: 10),
              StatusPill(d.status.label),
            ]),
          ),
        if (app.missing.isNotEmpty)
          _Panel(
            title: 'Still missing',
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              for (final m in app.missing) Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Text(m, style: const TextStyle(fontSize: 15))),
            ]),
          ),
        Align(alignment: Alignment.centerLeft, child: _btn('Open application', onApplication, style: BtnStyle.secondary, width: 190)),
        const NoteBox('Tap View to open a file. You can verify or print it there.'),
      ], 16)),
    );
  }
}

class _Documents extends StatefulWidget {
  final AdminStore store;
  const _Documents({required this.store});
  @override
  State<_Documents> createState() => _DocumentsState();
}

class _DocumentsState extends State<_Documents> {
  DocStatus? _status = DocStatus.pending;
  bool? _training; // null = all types

  @override
  Widget build(BuildContext context) {
    final s = widget.store;
    final rows = s.docs
        .where((d) => (_status == null || d.status == _status) && (_training == null || (d.kind == DocKind.training) == _training))
        .toList();
    int kindCount(bool? t) => s.docs.where((d) => t == null || (d.kind == DocKind.training) == t).length;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const _Header('Requirements review',
          sub: 'Business permits, barangay certificates (Annex C) and training certificates uploaded by applicants. Open each file to check it against the original.'),
      Wrap(spacing: 8, runSpacing: 8, children: [
        ChoiceChip(label: Text('All types · ${kindCount(null)}'), selected: _training == null, onSelected: (_) => setState(() => _training = null)),
        ChoiceChip(label: Text('Permits and certificates · ${kindCount(false)}'), selected: _training == false, onSelected: (_) => setState(() => _training = false)),
        ChoiceChip(label: Text('Training certificates · ${kindCount(true)}'), selected: _training == true, onSelected: (_) => setState(() => _training = true)),
      ]),
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final st in DocStatus.values)
          ChoiceChip(label: Text('${st.label} · ${s.docs.where((d) => d.status == st).length}'), selected: _status == st, onSelected: (_) => setState(() => _status = st)),
        ChoiceChip(label: Text('All · ${s.docs.length}'), selected: _status == null, onSelected: (_) => setState(() => _status = null)),
      ]),
      const SizedBox(height: 16),
      if (rows.isEmpty)
        const NoteBox('Nothing here.')
      else
        _Table(columns: const ['Application', 'Applicant', 'Document', 'Uploaded', 'Status', ''], rows: [
          for (final d in rows)
            [
              Text(d.appId, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.text2)),
              Text(d.owner),
              Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(d.doc, style: const TextStyle(fontWeight: FontWeight.w700)),
                if (d.detail.isNotEmpty) Text(d.detail, style: AppText.tiny),
                if (d.note.isNotEmpty) Text(d.note, style: AppText.tiny),
              ]),
              Text(d.uploaded),
              StatusPill(d.status.label),
              _btn('View', () => showDocViewer(context, s, d), style: BtnStyle.secondary, width: 80, height: 40),
            ],
        ]),
    ]);
  }
}

// ------------------------------------------------------------ document viewer

/// What the uploaded photo says, for the sample viewer and the printout.
class _DocFace {
  final String issuer;
  final String title;
  final List<(String, String)> lines;
  final String body;
  final String signer;
  final String seal;
  const _DocFace(this.issuer, this.title, this.lines, this.body, this.signer, this.seal);

  factory _DocFace.of(UploadedDoc d, Application? a) {
    final town = a?.town ?? '';
    final business = a?.business ?? '';
    final parts = d.detail.split(' · ');
    return switch (d.kind) {
      DocKind.training => _DocFace(
          parts.first.isEmpty ? 'Training provider' : parts.first,
          'Certificate of Completion',
          [('Awarded to', d.owner), ('Training', d.doc.replaceFirst('Training certificate: ', '')), ('Date', parts.length > 1 ? parts[1] : '—')],
          'This certifies that the person named above completed the training.',
          'Training coordinator',
          'CERTIFIED'),
      DocKind.annexC => _DocFace(
          'Republic of the Philippines · $town, Iloilo',
          'Certificate of Residency and Business Operation',
          [('Resident', d.owner), ('Business', business), ('Barangay', town)],
          'This certifies that the person named above is a resident of this barangay and operates the business named above.',
          'Punong Barangay',
          'OFFICIAL SEAL'),
      DocKind.permit => _DocFace(
          'Office of the Mayor · $town, Iloilo',
          'Business Permit',
          [('Business name', business), ('Owner', d.owner), ('Address', '$town, Iloilo'), ('Valid until', 'December 31, 2026')],
          'This permit is granted to operate the business named above, subject to existing laws and ordinances.',
          'Municipal Mayor',
          'OFFICIAL SEAL'),
    };
  }
}

/// Opens one uploaded file. Verify, ask for a new copy, or print it from here.
/// In the real app the image is the photo the applicant uploaded; the demo
/// draws a sample of it.
Future<void> showDocViewer(BuildContext context, AdminStore store, UploadedDoc d) {
  store.openedDoc(d);
  return showDialog<void>(
    context: context,
    builder: (_) => ChangeNotifierProvider<AdminStore>.value(value: store, child: _DocViewer(doc: d)),
  );
}

class _DocViewer extends StatelessWidget {
  final UploadedDoc doc;
  const _DocViewer({required this.doc});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AdminStore>();
    final face = _DocFace.of(doc, store.appFor(doc));
    final pending = doc.status == DocStatus.pending;
    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 16, 16),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${doc.appId} · ${doc.owner}', style: AppText.small.copyWith(fontWeight: FontWeight.w700)),
                  Text(doc.doc, style: AppText.h2.copyWith(fontSize: 22)),
                  Text('Uploaded ${doc.uploaded} · photo from the applicant’s phone', style: AppText.small),
                ]),
              ),
              StatusPill(doc.status.label),
              const SizedBox(width: 8),
              IconButton.outlined(tooltip: 'Close', onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
            ]),
          ),
          const Divider(height: 1),
          Flexible(
            child: Container(
              color: const Color(0xFFE9ECEA),
              padding: const EdgeInsets.all(24),
              child: SingleChildScrollView(child: Center(child: _Paper(face))),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 14, 24, 18),
            child: Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center, children: [
              const Text('Compare with the original before you verify. Sample image for the demo.', style: AppText.small),
              Wrap(spacing: 8, runSpacing: 8, children: [
                _btn('Print', () async {
                  store.printedDoc(doc);
                  await Printing.layoutPdf(name: '${doc.appId} ${doc.doc}', onLayout: (_) => _docPdf(doc, face));
                }, style: BtnStyle.secondary, width: 100, height: 42),
                if (pending) ...[
                  _btn('Ask new copy', () => store.setDoc(doc, DocStatus.newCopy, note: 'Photo unclear or expired'), style: BtnStyle.danger, width: 150, height: 42),
                  _btn('Verify', () => store.setDoc(doc, DocStatus.verified), width: 100, height: 42),
                ] else
                  _btn('Undo', () => store.setDoc(doc, DocStatus.pending), style: BtnStyle.secondary, width: 100, height: 42),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _Paper extends StatelessWidget {
  final _DocFace f;
  const _Paper(this.f);
  @override
  Widget build(BuildContext context) {
    const serif = TextStyle(fontFamily: 'serif', color: Color(0xFF222222));
    return Container(
      constraints: const BoxConstraints(maxWidth: 560),
      padding: const EdgeInsets.fromLTRB(40, 36, 40, 36),
      decoration: const BoxDecoration(color: Color(0xFFFFFDF7), boxShadow: [BoxShadow(color: Color(0x2E000000), blurRadius: 8, offset: Offset(0, 2))]),
      child: Stack(children: [
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(f.issuer.toUpperCase(), textAlign: TextAlign.center, style: serif.copyWith(fontSize: 12, letterSpacing: 1.4, color: const Color(0xFF555555))),
          const SizedBox(height: 8),
          Text(f.title, textAlign: TextAlign.center, style: serif.copyWith(fontSize: 26, fontWeight: FontWeight.w700)),
          const SizedBox(height: 14),
          for (final (k, v) in f.lines)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 5),
              decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFBBBBBB)))),
              child: Row(children: [Expanded(child: Text(k, style: serif.copyWith(fontSize: 14))), Text(v, style: serif.copyWith(fontSize: 14, fontWeight: FontWeight.w700))]),
            ),
          const SizedBox(height: 12),
          Text(f.body, style: serif.copyWith(fontSize: 14, height: 1.6)),
          const SizedBox(height: 40),
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              width: 220,
              padding: const EdgeInsets.only(top: 4),
              decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFF333333)))),
              child: Text(f.signer, style: serif.copyWith(fontSize: 12)),
            ),
          ),
        ]),
        Positioned(
          right: 0,
          bottom: 0,
          child: Transform.rotate(
            angle: -0.2,
            child: Container(
              width: 84,
              height: 84,
              alignment: Alignment.center,
              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppColors.missingFg, width: 3)),
              child: Text(f.seal, textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.missingFg)),
            ),
          ),
        ),
      ]),
    );
  }
}

/// Printout of the open file only.
Future<Uint8List> _docPdf(UploadedDoc d, _DocFace f) async {
  final doc = pw.Document(theme: await PdfService.loadTheme(), title: d.doc);
  doc.addPage(pw.Page(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.all(56),
    build: (_) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
      pw.Text('${d.appId} · ${d.owner} · uploaded ${d.uploaded}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
      pw.SizedBox(height: 24),
      pw.Text(f.issuer.toUpperCase(), textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700)),
      pw.SizedBox(height: 8),
      pw.Text(f.title, textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 16),
      for (final (k, v) in f.lines)
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(vertical: 5),
          decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey400, width: 0.5))),
          child: pw.Row(children: [pw.Expanded(child: pw.Text(k)), pw.Text(v, style: pw.TextStyle(fontWeight: pw.FontWeight.bold))]),
        ),
      pw.SizedBox(height: 12),
      pw.Text(f.body),
      pw.SizedBox(height: 50),
      pw.Container(
        width: 220,
        padding: const pw.EdgeInsets.only(top: 4),
        decoration: const pw.BoxDecoration(border: pw.Border(top: pw.BorderSide())),
        child: pw.Text(f.signer, style: const pw.TextStyle(fontSize: 10)),
      ),
      pw.Spacer(),
      pw.Text('Printed from the NegosyoPlan staff dashboard. Status: ${d.status.label}.', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
    ]),
  ));
  return doc.save();
}

class _Reports extends StatelessWidget {
  final AdminStore store;
  const _Reports({required this.store});

  @override
  Widget build(BuildContext context) {
    final s = store;
    final sub = s.submittedLike;
    final complete = sub.where((a) => a.completeness == 100).length;
    final towns = s.byTown.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final missing = s.commonMissing.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _Header('Reports and user testing',
          sub: 'Measures agreed with OLEDIPO: preparation time against the 1–2 week baseline, completeness, errors, and use with limited internet.',
          actions: [
            _btn('Export CSV', () => toast(context, 'Report export needs the server connection'), style: BtnStyle.secondary, width: 140),
            _btn('Print report', () => Printing.layoutPdf(name: 'NegosyoPlan report', onLayout: (_) => _reportPdf(s)), width: 150),
          ]),
      _Kpis([
        ('Average preparation', '${s.avgPrep.toStringAsFixed(1)} days', 'Was 7–14 days on paper'),
        ('Complete on first submit', '${sub.isEmpty ? 0 : (100 * complete / sub.length).round()}%', '$complete of ${sub.length} submitted'),
        ('Returned', '${s.count(AppStatus.returned)}', 'Mostly missing papers'),
        ('Used offline', '64%', 'Sessions without internet (sample)'),
        ('Sync errors', '0', 'No data lost (sample)'),
      ]),
      _Pair(
        _Panel(
          title: 'Preparation time, in days',
          child: _Bars([('Paper, slowest', 14), ('Paper, fastest', 7), ('NegosyoPlan average', double.parse(s.avgPrep.toStringAsFixed(1)))]),
        ),
        _Panel(title: 'Applications by town', child: _Bars([for (final e in towns.take(8)) (e.key, e.value)])),
      ),
      const SizedBox(height: 16),
      _Panel(title: 'Most common missing items', child: _Bars([for (final e in missing.take(5)) (e.key, e.value)])),
      const SizedBox(height: 16),
      const NoteBox('Usability sessions are coordinated with OLEDIPO on phones and computers, including offline use. Figures here are sample data until testing begins.'),
    ]);
  }

  static Future<Uint8List> _reportPdf(AdminStore s) async {
    final doc = pw.Document(theme: await PdfService.loadTheme());
    final sub = s.submittedLike;
    final complete = sub.where((a) => a.completeness == 100).length;
    pw.Widget row(String k, String v) => pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 4),
          child: pw.Row(children: [pw.Expanded(child: pw.Text(k)), pw.Text(v, style: pw.TextStyle(fontWeight: pw.FontWeight.bold))]),
        );
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(40),
      build: (_) => [
        pw.Text('NegosyoPlan report', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 4),
        pw.Text('OLEDIPO · EMBRACE Program · sample data'),
        pw.SizedBox(height: 16),
        row('Applications', '${s.apps.length}'),
        row('Average preparation', '${s.avgPrep.toStringAsFixed(1)} days (baseline 7–14 days)'),
        row('Complete on first submit', '$complete of ${sub.length}'),
        row('Returned for completion', '${s.count(AppStatus.returned)}'),
        row('Accepted', '${s.count(AppStatus.accepted)}'),
        pw.SizedBox(height: 14),
        pw.Text('Applications by town', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        for (final e in s.byTown.entries) row(e.key, '${e.value}'),
        pw.SizedBox(height: 14),
        pw.Text('Most common missing items', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        for (final e in s.commonMissing.entries) row(e.key, '${e.value}'),
        pw.SizedBox(height: 20),
        pw.Text('Loan approval is decided by the EMBRACE TWG, not by this system.', style: const pw.TextStyle(fontSize: 10)),
      ],
    ));
    return doc.save();
  }
}

class _Staff extends StatefulWidget {
  final AdminStore store;
  const _Staff({required this.store});
  @override
  State<_Staff> createState() => _StaffState();
}

class _StaffState extends State<_Staff> {
  String _name = '', _email = '', _role = 'Reviewer';
  int _formKey = 0;
  static const roles = ['Admin', 'Reviewer', 'Trainer', 'Viewer'];

  @override
  Widget build(BuildContext context) {
    final s = widget.store;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const _Header('Staff and roles', sub: 'Who can see applicant data. Reviewers check documents; trainers see training records only.'),
      _Table(columns: const ['Name', 'Email', 'Role', 'Status', ''], rows: [
        for (final m in s.staff)
          [
            Text(m.name, style: const TextStyle(fontWeight: FontWeight.w700)),
            Text(m.email),
            DropdownButton<String>(
              value: m.role,
              underline: const SizedBox(),
              items: [for (final r in roles) DropdownMenuItem(value: r, child: Text(r))],
              onChanged: (v) => s.setRole(m, v ?? m.role),
            ),
            StatusPill(m.active ? 'Active' : (m.invited ? 'Invited' : 'Inactive')),
            _btn(m.active ? 'Turn off' : 'Turn on', () => s.toggleStaff(m), style: BtnStyle.secondary, width: 100, height: 40),
          ],
      ]),
      const SizedBox(height: 16),
      _Panel(
        title: 'Invite staff',
        child: Wrap(key: ValueKey(_formKey), spacing: 12, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.end, children: [
          SizedBox(width: 220, child: FieldBlock(label: 'Name', child: AppTextField(initial: '', onChanged: (v) => _name = v))),
          SizedBox(width: 260, child: FieldBlock(label: 'Email', child: AppTextField(initial: '', keyboardType: TextInputType.emailAddress, onChanged: (v) => _email = v))),
          SizedBox(
            width: 170,
            child: FieldBlock(
              label: 'Role',
              child: DropdownButtonFormField<String>(
                value: _role,
                items: [for (final r in roles) DropdownMenuItem(value: r, child: Text(r))],
                onChanged: (v) => setState(() => _role = v ?? 'Reviewer'),
              ),
            ),
          ),
          _btn('Send invite', () {
            if (_name.trim().isEmpty || !RegExp(r'.+@.+\..+').hasMatch(_email)) {
              toast(context, 'Add a name and a valid email');
              return;
            }
            s.invite(_name.trim(), _email.trim(), _role);
            toast(context, 'Invite sent to $_email');
            setState(() {
              _name = _email = '';
              _role = 'Reviewer';
              _formKey++;
            });
          }, width: 150, height: 56),
        ]),
      ),
    ]);
  }
}

class _Privacy extends StatelessWidget {
  final AdminStore store;
  const _Privacy({required this.store});
  @override
  Widget build(BuildContext context) {
    final s = store;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _Header('Privacy and audit log',
          sub: 'Applicant data reaches OLEDIPO only with consent. Every staff action is recorded here.',
          actions: [_btn('Export log', () => toast(context, 'Audit log export needs the server connection'), style: BtnStyle.secondary, width: 140)]),
      _Kpis([
        ('Shared with consent', '${s.apps.length}', 'Applicants who allowed sharing'),
        ('Consent withdrawn', '1', 'Data removed from view'),
        ('Staff with access', '${s.staff.where((m) => m.active).length}', 'Active accounts'),
        ('Actions logged', '${s.audit.length}', 'Including this session'),
      ]),
      _Table(columns: const ['When', 'Staff', 'Action'], rows: [
        for (final e in s.audit) [Text(e.time, style: AppText.tiny.copyWith(fontSize: 14)), Text(e.who), Text(e.action)],
      ]),
    ]);
  }
}
