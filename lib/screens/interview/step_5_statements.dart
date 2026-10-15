import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../logic/checks.dart';
import '../../logic/format.dart';
import '../../logic/statements.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/form.dart';
import '../../i18n/tr.dart';

// Step 5 · Financial statements by year (S10), then Income statement (S10a),
// Cash flow (S10b) and Balance sheet (S10c) for the year the owner tapped.
// Every amount, totals included, is typed by the owner. Nothing is calculated.

class FinancialsScreen extends StatelessWidget {
  const FinancialsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final years = app.statementYears;
    final done = years.where(app.yearComplete).length;
    final s = app.start;
    const months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
    final startText = s == null ? null : '${months[(s.$2 - 1).clamp(0, 11).toInt()]} ${s.$1}';

    return StepPage(
      step: 5,
      title: 'Your financial statements',
      onNext: () => Navigator.pushNamed(context, '/people'),
      children: [
        Text.rich(
          TextSpan(style: AppText.lead, children: [
            TextSpan(text: trn('Add three statements for every year since your business started')),
            if (startText != null) ...[TextSpan(text: trn(' in ')), TextSpan(text: trn(startText), style: const TextStyle(fontWeight: FontWeight.w700))],
            TextSpan(text: trn('. Type them from your records or ITR.')),
          ]),
        ),
        if (s == null)
          NoteBox('Tell us when your business started in Step 2. We will list each year for you.',
              kind: NoteKind.warn, action: LinkButton('Go to Step 2', onPressed: () => Navigator.pushNamed(context, '/business'))),
        if (years.isNotEmpty)
          Container(
            padding: const EdgeInsets.only(top: 12),
            decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.divider))),
            child: Row(children: [
              Expanded(child: Text(tr('Years complete'), style: TextStyle(fontSize: 16, color: AppColors.text2))),
              Text(tr('$done of ${years.length}'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            ]),
          ),
        for (final y in years) _YearCard(year: y),
        AddButton('Add ${app.nextYear}', onTap: app.addYear),
        Text(tr('Add ${app.nextYear} when you have its records. Your first year comes from Step 2.'), style: AppText.small),
      ],
    );
  }
}

class _YearCard extends StatelessWidget {
  final int year;
  const _YearCard({required this.year});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final left = StatementType.values.where((t) => app.progress(year, t) != Progress.complete).length;
    final complete = left == 0;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: complete ? AppColors.tintBorder : AppColors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(tr('$year'), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
              Text(tr(app.yearSpan(year)), style: const TextStyle(fontSize: 14, color: AppColors.muted2)),
            ]),
          ),
          Text(tr(complete ? 'Complete' : '$left to add'),
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: complete ? AppColors.primary : AppColors.estimateFg)),
        ]),
        const SizedBox(height: 12),
        for (final t in StatementType.values) ...[
          _StatementRow(year: year, type: t),
          const SizedBox(height: 10),
        ],
        if (app.canRemoveYear(year))
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => app.removeYear(year),
              style: TextButton.styleFrom(foregroundColor: AppColors.missingFg),
              child: Text(tr('Remove this year'), style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            ),
          ),
      ]),
    );
  }
}

class _StatementRow extends StatelessWidget {
  final int year;
  final StatementType type;
  const _StatementRow({required this.year, required this.type});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final p = app.progress(year, type);
    final (key, label) = type.headline;
    final value = app.statementValues(year, type)[key];
    final sub = switch (p) {
      Progress.complete => '$label ${peso(amt(value))}',
      Progress.partial => '${app.blankLines(year, type)} lines still blank. Tap to finish.',
      Progress.empty => 'Not added yet. Tap to type it.',
    };
    return Material(
      color: AppColors.surface2,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.pushNamed(context, type.route, arguments: year),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 12, 8),
          child: Row(children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: p == Progress.complete ? AppColors.primary : Colors.white,
                border: p == Progress.complete ? null : Border.all(color: const Color(0xFF9AA49E), width: 1.5),
              ),
              child: p == Progress.complete ? const Icon(Icons.check, size: 15, color: Colors.white) : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(tr(type.title), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                Text(tr(sub),
                    style: TextStyle(
                      fontSize: 14,
                      color: p == Progress.complete ? AppColors.muted2 : AppColors.estimateFg,
                      fontWeight: p == Progress.complete ? FontWeight.w400 : FontWeight.w700,
                    )),
              ]),
            ),
            const Icon(Icons.chevron_right, color: AppColors.muted),
          ]),
        ),
      ),
    );
  }
}

/// One statement for one year. The year is fixed (chosen on the year list).
class StatementScreen extends StatelessWidget {
  final StatementType type;
  const StatementScreen({super.key, required this.type});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final arg = ModalRoute.of(context)?.settings.arguments;
    final year = arg is int ? arg : (app.statementYears.isEmpty ? app.now().year - 1 : app.statementYears.last);
    final vals = app.statementValues(year, type);
    final part = switch (type) {
      StatementType.income => 'Part 1 of 3',
      StatementType.cashFlow => 'Part 2 of 3',
      StatementType.balance => 'Part 3 of 3',
    };

    String formula(StatementLine l) => switch (l.key) {
          'cb' when app.isCalculated(year, 'cb') => 'Cash ending of ${year - 1}',
          'capb' when app.isCalculated(year, 'capb') => 'Total capital of ${year - 1}',
          _ => l.hint,
        };
    Widget line(StatementLine l) => app.isCalculated(year, l.key)
        ? CalcLine(label: l.label, value: vals[l.key], formula: formula(l), big: l.kind == LineKind.grandTotal)
        : AmountField(
          key: ValueKey('$year-${type.name}-${l.key}'),
          label: l.label,
          value: vals[l.key] ?? '',
          eg: l.hint,
          total: l.kind == LineKind.total || l.kind == LineKind.grandTotal,
          big: l.kind == LineKind.grandTotal,
          onChanged: (v) => app.setLine(year, type, l.key, v),
        );

    // Group indented lines under their heading, like the paper template.
    final body = <Widget>[];
    final group = <Widget>[];
    void flush() {
      if (group.isNotEmpty) {
        body.add(Indented(List.of(group)));
        group.clear();
      }
    }

    for (final l in type.lines) {
      if (l.kind == LineKind.heading) {
        flush();
        body.add(LineHeading(l.label));
        continue;
      }
      if (l.indent) {
        group.add(line(l));
      } else {
        flush();
        body.add(line(l));
      }
    }
    flush();

    final span = app.yearSpan(year).split(' · ').first;
    return StepPage(
      step: 5,
      part: part,
      title: type.title,
      intro: 'Copy each line from your records or ITR for this year. The totals are added up for you.',
      nextLabel: type == StatementType.balance ? 'Save this year' : 'Next',
      onNext: () {
        switch (type) {
          case StatementType.income:
            Navigator.pushNamed(context, StatementType.cashFlow.route, arguments: year);
          case StatementType.cashFlow:
            Navigator.pushNamed(context, StatementType.balance.route, arguments: year);
          case StatementType.balance:
            Navigator.popUntil(context, (r) => r.settings.name == '/financials' || r.isFirst);
        }
      },
      children: [
        ReadOnlyQ(
          type == StatementType.balance ? 'As of' : 'Year',
          type == StatementType.balance ? 'December 31, $year' : '$year',
          note: type == StatementType.balance ? 'End of the year' : span,
          tinted: true,
        ),
        ...body,
      ],
    );
  }
}

/// A total the app adds up. Shown, not typed.
class CalcLine extends StatelessWidget {
  final String label;
  final String? value;
  final String formula;
  final bool big;
  const CalcLine({super.key, required this.label, required this.value, required this.formula, this.big = false});

  @override
  Widget build(BuildContext context) {
    final v = amt(value);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(tr(label), style: AppText.label.copyWith(fontSize: big ? 18 : 16, color: AppColors.primary)),
      const SizedBox(height: 10),
      Semantics(
        label: trn('$label, added up for you: ${v == null ? 'not yet' : peso(v)}'),
        excludeSemantics: true,
        child: Container(
          constraints: const BoxConstraints(minHeight: 54),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: AppColors.tint2,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.tintBorder),
          ),
          child: Row(children: [
            Expanded(
              child: Text(tr(v == null ? '—' : peso(v)),
                  style: TextStyle(fontSize: big ? 22 : 20, fontWeight: FontWeight.w700, color: v != null && v < 0 ? AppColors.missingFg : AppColors.primary)),
            ),
            const Icon(Icons.calculate_outlined, size: 18, color: AppColors.muted),
            const SizedBox(width: 4),
            Text(tr('Added up'), style: TextStyle(fontSize: 14, color: AppColors.muted)),
          ]),
        ),
      ),
      if (formula.isNotEmpty) ...[
        const SizedBox(height: 6),
        Text(tr(formula), style: const TextStyle(fontSize: 14, color: AppColors.muted)),
      ],
    ]);
  }
}
