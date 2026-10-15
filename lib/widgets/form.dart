import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../logic/checks.dart';
import '../logic/format.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import 'common.dart';
import '../i18n/tr.dart';

const logoAsset = 'assets/images/logo.png';

/// Round helper button on the right side of the screen (opens the chatbot).
class ChatFab extends StatelessWidget {
  const ChatFab({super.key});
  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: trn('Ask the Negosyo Helper'),
        child: SizedBox(
          width: 60,
          height: 60,
          child: FloatingActionButton(
            heroTag: 'chat',
            onPressed: () => Navigator.of(context).pushNamed('/chat'),
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            elevation: 6,
            shape: const CircleBorder(),
            tooltip: trn('Ask the Negosyo Helper'),
            child: const Icon(Icons.contact_support_outlined, size: 30),
          ),
        ),
      );
}

/// "EN" language switch in the step header.
class LangButton extends StatelessWidget {
  const LangButton({super.key});
  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final code = switch (app.data.lang) { 'hil' => 'HIL', 'fil' => 'FIL', _ => 'EN' };
    return TextButton(
      onPressed: () => showModalBottomSheet<void>(
        context: context,
        builder: (_) => SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            for (final e in const [('hil', 'Hiligaynon'), ('fil', 'Filipino'), ('en', 'English')])
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
                title: Text(tr(e.$2), style: AppText.body),
                trailing: app.data.lang == e.$1 ? const Icon(Icons.check, color: AppColors.primary) : null,
                onTap: () {
                  app.change((d) => d.lang = e.$1);
                  Navigator.pop(context);
                },
              ),
          ]),
        ),
      ),
      style: TextButton.styleFrom(foregroundColor: AppColors.muted, minimumSize: const Size(44, 44)),
      child: Text(tr(code), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
    );
  }
}

/// Logo + NegosyoPlan word mark, used in headers.
class LogoMark extends StatelessWidget {
  final double size;
  final bool word;
  const LogoMark({super.key, this.size = 30, this.word = true});
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Image.asset(logoAsset, width: size, height: size, semanticLabel: trn(word ? null : 'NegosyoPlan')),
        if (word) ...[
          const SizedBox(width: 10),
          Text(tr('NegosyoPlan'), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.primary)),
        ],
      ]);
}

/// A plain page: back button, scrolling content, optional pinned footer and chat button.
class AppPage extends StatelessWidget {
  final String? title;
  final List<Widget> children;
  final Widget? footer;
  final bool back;
  final Widget? headerTrailing;
  final bool chat;
  final double gap;
  final VoidCallback? onBack;
  const AppPage({super.key, this.title, required this.children, this.footer, this.back = true, this.headerTrailing, this.chat = false, this.gap = 22, this.onBack});

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.white,
        floatingActionButton: chat ? const ChatFab() : null,
        bottomNavigationBar: footer,
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(children: [
                if (back || headerTrailing != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 10, 24, 0),
                    child: Row(children: [
                      if (back) BackCircle(onPressed: onBack),
                      const Spacer(),
                      if (headerTrailing != null) headerTrailing!,
                    ]),
                  ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 100),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: spaced([if (title != null) H1(title!), ...children], gap)),
                  ),
                ),
              ]),
            ),
          ),
        ),
      );
}

/// Footer with one or two large buttons.
class Footer extends StatelessWidget {
  final List<Widget> children;
  final bool vertical;
  const Footer(this.children, {super.key, this.vertical = false});
  @override
  Widget build(BuildContext context) => SafeArea(
        top: false,
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
              child: vertical
                  ? Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: spaced(children, 12))
                  : Row(children: [
                      for (var i = 0; i < children.length; i++) ...[
                        if (i > 0) const SizedBox(width: 12),
                        Expanded(flex: i == children.length - 1 && children.length > 1 ? 13 : 10, child: children[i]),
                      ],
                    ]),
            ),
          ),
        ),
      );
}

/// Interview step: "Step n of 9 · Saved", progress, title, questions, Save for later + Next, chat button.
class StepPage extends StatelessWidget {
  final int step;
  final String? part;
  final String title;
  final String? intro;
  final List<Widget> children;
  final VoidCallback onNext;
  final String nextLabel;
  final VoidCallback? onBack;
  const StepPage({
    super.key,
    required this.step,
    required this.title,
    required this.children,
    required this.onNext,
    this.part,
    this.intro,
    this.nextLabel = 'Next',
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final label = 'STEP $step OF 8${part == null ? '' : ' · ${part!.toUpperCase()}'} · SAVED';
    return Scaffold(
      backgroundColor: Colors.white,
      floatingActionButton: const ChatFab(),
      bottomNavigationBar: Footer([
        BigButton('Save for later', style: BtnStyle.secondary, onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil('/home', (r) => false)),
        BigButton(nextLabel, onPressed: onNext),
      ]),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 10, 16, 0),
                child: Row(children: [
                  BackCircle(onPressed: onBack),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(tr(label), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: AppColors.muted2)),
                      const SizedBox(height: 8),
                      ProgressBar(step / 9, height: 4),
                    ]),
                  ),
                  const SizedBox(width: 6),
                  const LangButton(),
                ]),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 100),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: spaced([
                      H1(title),
                      if (intro != null) IntroBox(intro!),
                      ...children,
                    ], 26),
                  ),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class IntroBox extends StatelessWidget {
  final String text;
  const IntroBox(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(14)),
        child: Text(tr(text), style: const TextStyle(fontSize: 15, height: 1.5, color: AppColors.text2)),
      );
}

/// Section heading: "ABOUT THE BUSINESS" + which form it is for.
class SectionHead extends StatelessWidget {
  final String title;
  final String? sub;
  const SectionHead(this.title, {super.key, this.sub});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.only(top: 18),
        decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.divider))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(tr(title).toUpperCase(), style: AppText.eyebrow),
          if (sub != null) ...[const SizedBox(height: 2), Text(tr(sub!), style: const TextStyle(fontSize: 13, color: AppColors.hint))],
        ]),
      );
}

/// "LESS: COST OF SALES" style heading inside a statement.
class LineHeading extends StatelessWidget {
  final String text;
  const LineHeading(this.text, {super.key});
  @override
  Widget build(BuildContext context) =>
      Text(tr(text).toUpperCase(), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: 0.7, color: AppColors.text));
}

/// Indented group with a left rule (lines under a heading).
class Indented extends StatelessWidget {
  final List<Widget> children;
  const Indented(this.children, {super.key});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.only(left: 14),
        decoration: const BoxDecoration(border: Border(left: BorderSide(color: AppColors.border, width: 2))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: spaced(children, 22)),
      );
}

/// Text question bound to an answer key.
class TextQ extends StatelessWidget {
  final String k;
  final String label;
  final String? hint;
  final String? eg;
  final TextInputType? keyboard;
  final int maxLines;
  const TextQ(this.k, this.label, {super.key, this.hint, this.eg, this.keyboard, this.maxLines = 1});
  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return FieldBlock(
      label: label,
      example: eg,
      child: AppTextField(
        initial: app.val(k),
        hint: hint,
        keyboardType: maxLines > 1 ? TextInputType.multiline : keyboard,
        maxLines: maxLines,
        semanticLabel: trn(label),
        onChanged: (v) => app.setVal(k, v),
      ),
    );
  }
}

/// Date or month question (opens a picker; stored as YYYY-MM-DD or YYYY-MM).
class DateQ extends StatelessWidget {
  final String k;
  final String label;
  final bool monthOnly;
  final String? eg;
  const DateQ(this.k, this.label, {super.key, this.monthOnly = false, this.eg});

  static const _months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];

  static String show(String v, {bool monthOnly = false}) {
    final p = v.split('-');
    if (p.length < 2) return v;
    final m = int.tryParse(p[1]) ?? 1;
    final name = _months[(m - 1).clamp(0, 11).toInt()];
    if (monthOnly || p.length < 3) return '$name ${p[0]}';
    return '$name ${int.tryParse(p[2]) ?? p[2]}, ${p[0]}';
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final v = app.val(k);
    return FieldBlock(
      label: label,
      example: eg,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () async {
          final init = DateTime.tryParse(v.length == 7 ? '$v-01' : v) ?? DateTime(1980);
          final d = await showDatePicker(
            context: context,
            initialDate: init,
            firstDate: DateTime(1930),
            lastDate: DateTime.now(),
            initialDatePickerMode: monthOnly ? DatePickerMode.year : DatePickerMode.day,
          );
          if (d != null) {
            final mm = d.month.toString().padLeft(2, '0');
            app.setVal(k, monthOnly ? '${d.year}-$mm' : '${d.year}-$mm-${d.day.toString().padLeft(2, '0')}');
          }
        },
        child: Container(
          height: 54,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(border: Border.all(color: AppColors.borderStrong), borderRadius: BorderRadius.circular(10)),
          child: Row(children: [
            Expanded(child: Text(tr(v.isEmpty ? 'Tap to choose' : show(v, monthOnly: monthOnly)), style: TextStyle(fontSize: 18, color: v.isEmpty ? AppColors.hint : AppColors.text))),
            const Icon(Icons.calendar_today_outlined, color: AppColors.muted),
          ]),
        ),
      ),
    );
  }
}

/// Peso amount box. Stores exactly what the user types.
class AmountField extends StatelessWidget {
  final String label;
  final String value;
  final ValueChanged<String> onChanged;
  final String? eg;
  final bool total;
  final bool big;
  const AmountField({super.key, required this.label, required this.value, required this.onChanged, this.eg, this.total = false, this.big = false});
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(tr(label), style: AppText.label.copyWith(fontSize: big ? 18 : 16, color: total ? AppColors.primary : AppColors.text)),
        const SizedBox(height: 10),
        Theme(
          data: Theme.of(context).copyWith(
            inputDecorationTheme: Theme.of(context).inputDecorationTheme.copyWith(
                  fillColor: total ? AppColors.tint2 : Colors.white,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: total ? AppColors.primary : AppColors.borderStrong),
                  ),
                ),
          ),
          child: AppTextField(
            initial: value,
            hint: '0',
            prefix: '₱ ',
            keyboardType: TextInputType.number,
            semanticLabel: trn(label),
            // Stored exactly as typed (e.g. "1,200"); read with amt() when needed.
            onChanged: onChanged,
          ),
        ),
        if (eg != null && eg!.isNotEmpty) ...[const SizedBox(height: 8), Text(tr(eg!), style: AppText.small)],
      ]);
}

/// Peso question bound to an answer key.
class PesoQ extends StatelessWidget {
  final String k;
  final String label;
  final String? eg;
  const PesoQ(this.k, this.label, {super.key, this.eg});
  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return AmountField(label: label, value: app.val(k), eg: eg, onChanged: (v) => app.setVal(k, v));
  }
}

/// Tap-to-choose question (one or many).
class ChipsQ extends StatelessWidget {
  final String k;
  final String label;
  final List<String> options;
  final bool multi;
  final String? eg;
  const ChipsQ(this.k, this.label, this.options, {super.key, this.multi = false, this.eg});
  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final selected = app.sel(k);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(tr(label), style: AppText.label),
      const SizedBox(height: 10),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final o in options)
          Semantics(
            selected: selected.contains(o),
            button: true,
            child: ChoiceChip(
              label: Text(tr(o)),
              selected: selected.contains(o),
              onSelected: (_) => app.pick(k, o, multi: multi),
              showCheckmark: false,
              labelStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: selected.contains(o) ? Colors.white : AppColors.text),
              selectedColor: AppColors.primary,
              backgroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
              shape: StadiumBorder(side: BorderSide(color: selected.contains(o) ? AppColors.primary : AppColors.borderStrong)),
            ),
          ),
      ]),
      if (eg != null) ...[const SizedBox(height: 8), Text(tr(eg!), style: AppText.small)],
    ]);
  }
}

/// A value shown but not typed here (e.g. mobile number from the account).
class ReadOnlyQ extends StatelessWidget {
  final String label;
  final String value;
  final String note;
  final bool tinted;
  const ReadOnlyQ(this.label, this.value, {super.key, this.note = '', this.tinted = false});
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(tr(label), style: AppText.label),
        const SizedBox(height: 10),
        Container(
          constraints: const BoxConstraints(minHeight: 54),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: tinted ? AppColors.tint2 : AppColors.surface2,
            borderRadius: BorderRadius.circular(10),
            border: tinted ? Border.all(color: AppColors.tintBorder) : null,
          ),
          child: Row(children: [
            Expanded(
              child: Text(tr(value),
                  style: tinted ? const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.primary) : const TextStyle(fontSize: 18)),
            ),
            if (note.isNotEmpty) Text(tr(note), style: const TextStyle(fontSize: 14, color: AppColors.muted)),
          ]),
        ),
      ]);
}

// ---------------------------------------------------------------------------
// Editable lists (materials, workers, loan items …)
// ---------------------------------------------------------------------------

enum FieldType { text, number, peso, select }

class FieldSpec {
  final String key;
  final String label;
  final String hint;
  final FieldType type;
  final List<String> options;
  final bool required;

  /// Shown side by side with the next half field.
  final bool half;
  const FieldSpec(this.key, this.label, {this.hint = '', this.type = FieldType.text, this.options = const [], this.required = false, this.half = false});
}

/// A list the user can add to, edit and remove from. Totals (when [amount] is
/// given) are a sum of the user's own rows, shown under the list.
class ListQ extends StatefulWidget {
  final String label;
  final List<FieldSpec> fields;
  final List<Map<String, String>> rows;
  final ValueChanged<List<Map<String, String>>> onChanged;
  final String addLabel;
  final String Function(Map<String, String>)? detail;
  final double Function(Map<String, String>)? amount;
  final int? max;
  final String? eg;
  const ListQ({
    super.key,
    required this.label,
    required this.fields,
    required this.rows,
    required this.onChanged,
    required this.addLabel,
    this.detail,
    this.amount,
    this.max,
    this.eg,
  });

  /// Convenience: bind to a list key in AppState.
  static Widget bound(BuildContext context, String listKey,
      {required String label,
      required List<FieldSpec> fields,
      required String addLabel,
      String Function(Map<String, String>)? detail,
      double Function(Map<String, String>)? amount,
      int? max,
      String? eg}) {
    final app = context.watch<AppState>();
    return ListQ(
      label: label,
      fields: fields,
      rows: app.rows(listKey),
      onChanged: (rows) => app.change((d) => d.lists[listKey] = rows),
      addLabel: addLabel,
      detail: detail,
      amount: amount,
      max: max,
      eg: eg,
    );
  }

  @override
  State<ListQ> createState() => _ListQState();
}

class _ListQState extends State<ListQ> {
  bool _open = false;
  int _edit = -1;
  Map<String, String> _draft = {};
  String _err = '';
  int _formKey = 0;

  void _start([int i = -1]) => setState(() {
        _open = true;
        _edit = i;
        _err = '';
        _formKey++;
        _draft = i >= 0 ? Map<String, String>.from(widget.rows[i]) : {for (final f in widget.fields) if (f.type == FieldType.select) f.key: f.options.first};
      });

  void _save() {
    for (final f in widget.fields) {
      if (f.required && (_draft[f.key] ?? '').trim().isEmpty) {
        setState(() => _err = 'Please fill in: ${f.label.replaceAll('?', '')}');
        return;
      }
    }
    final clean = {for (final f in widget.fields) f.key: (_draft[f.key] ?? '').trim()};
    final rows = List<Map<String, String>>.from(widget.rows);
    if (_edit >= 0) {
      rows[_edit] = clean;
    } else {
      rows.add(clean);
    }
    widget.onChanged(rows);
    setState(() {
      _open = false;
      _edit = -1;
    });
  }

  Widget _field(FieldSpec f) {
    final Widget input;
    if (f.type == FieldType.select) {
      input = DropdownButtonFormField<String>(
        value: f.options.contains(_draft[f.key]) ? _draft[f.key] : f.options.first,
        items: [for (final o in f.options) DropdownMenuItem(value: o, child: Text(tr(o), style: const TextStyle(fontSize: 18)))],
        onChanged: (v) => setState(() => _draft[f.key] = v ?? f.options.first),
      );
    } else {
      input = AppTextField(
        key: ValueKey('${f.key}-$_formKey'),
        initial: _draft[f.key] ?? '',
        hint: f.hint.isEmpty ? (f.type == FieldType.text ? null : '0') : f.hint,
        prefix: f.type == FieldType.peso ? '₱ ' : null,
        keyboardType: f.type == FieldType.text ? TextInputType.text : TextInputType.number,
        semanticLabel: trn(f.label),
        onChanged: (v) => _draft[f.key] = v,
      );
    }
    return FieldBlock(label: f.label, child: input);
  }

  List<Widget> _formFields() {
    final out = <Widget>[];
    final fs = widget.fields;
    for (var i = 0; i < fs.length; i++) {
      if (fs[i].half && i + 1 < fs.length && fs[i + 1].half) {
        out.add(Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: _field(fs[i])),
          const SizedBox(width: 10),
          Expanded(child: _field(fs[i + 1])),
        ]));
        i++;
      } else {
        out.add(_field(fs[i]));
      }
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final rows = widget.rows;
    final canAdd = !_open && (widget.max == null || rows.length < widget.max!);
    final total = widget.amount == null ? null : listTotal(rows, widget.amount!);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(tr(widget.label), style: AppText.label),
      if (widget.eg != null) ...[const SizedBox(height: 4), Text(tr(widget.eg!), style: AppText.small)],
      const SizedBox(height: 10),
      if (rows.isEmpty && !_open) Padding(padding: EdgeInsets.only(bottom: 10), child: Text(tr('None added yet.'), style: TextStyle(fontSize: 15, color: AppColors.muted))),
      for (var i = 0; i < rows.length; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 4, 8),
            decoration: BoxDecoration(border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(tr(rows[i][widget.fields.first.key] ?? '—'), style: const TextStyle(fontSize: 17)),
                  if (widget.detail != null && widget.detail!(rows[i]).isNotEmpty)
                    Text(tr(widget.detail!(rows[i])), style: const TextStyle(fontSize: 14, color: AppColors.muted)),
                ]),
              ),
              if (widget.amount != null) Text(tr(peso(widget.amount!(rows[i]))), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              IconButton(tooltip: trn('Edit'), onPressed: () => _start(i), icon: const Icon(Icons.edit_outlined, size: 20, color: AppColors.muted)),
              IconButton(
                tooltip: trn('Remove'),
                onPressed: () {
                  final r = List<Map<String, String>>.from(rows)..removeAt(i);
                  widget.onChanged(r);
                  setState(() => _open = false);
                },
                icon: const Icon(Icons.close, size: 20, color: AppColors.muted),
              ),
            ]),
          ),
        ),
      if (_open)
        Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: AppColors.tint2, border: Border.all(color: AppColors.primary, width: 1.5), borderRadius: BorderRadius.circular(14)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(tr(_edit >= 0 ? 'Edit' : 'Add'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 14),
            ...spaced(_formFields(), 14),
            if (_err.isNotEmpty) ...[const SizedBox(height: 10), Text(tr(_err), style: const TextStyle(fontSize: 14, color: AppColors.missingFg))],
            const SizedBox(height: 14),
            Row(children: [
              Expanded(child: BigButton('Cancel', height: 48, style: BtnStyle.secondary, onPressed: () => setState(() => _open = false))),
              const SizedBox(width: 10),
              Expanded(child: BigButton('Save', height: 48, onPressed: _save)),
            ]),
          ]),
        ),
      if (canAdd) AddButton(widget.addLabel, onTap: _start),
      if (total != null)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(children: [
            Expanded(child: Text(tr('Total'), style: TextStyle(fontSize: 17, color: AppColors.text2))),
            Text(tr(peso(total)), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          ]),
        ),
    ]);
  }
}

/// Folder-style link card (e.g. to the requirements page).
class LinkCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String sub;
  final VoidCallback onTap;
  const LinkCard({super.key, required this.icon, required this.title, required this.sub, required this.onTap});
  @override
  Widget build(BuildContext context) => Material(
        color: AppColors.tint2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: AppColors.primary, width: 1.5)),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(children: [
              IconTile(icon),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(tr(title), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                  Text(tr(sub), style: const TextStyle(fontSize: 14, color: AppColors.muted)),
                ]),
              ),
              const Icon(Icons.chevron_right),
            ]),
          ),
        ),
      );
}
