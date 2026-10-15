import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../logic/format.dart';
import '../theme/app_theme.dart';
import '../i18n/tr.dart';

/// Vertical gap.
class Gap extends StatelessWidget {
  final double size;
  const Gap(this.size, {super.key});
  @override
  Widget build(BuildContext context) => SizedBox(width: size, height: size);
}

/// Inserts a gap between widgets.
List<Widget> spaced(List<Widget> children, double gap) {
  final out = <Widget>[];
  for (var i = 0; i < children.length; i++) {
    if (i > 0) out.add(SizedBox(height: gap));
    out.add(children[i]);
  }
  return out;
}

enum BtnStyle { primary, secondary, dark, danger }

/// Large touch-friendly button (60 px by default).
class BigButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final BtnStyle style;
  final IconData? icon;
  final double height;
  const BigButton(this.label, {super.key, this.onPressed, this.style = BtnStyle.primary, this.icon, this.height = 56});

  @override
  Widget build(BuildContext context) {
    final bg = switch (style) {
      BtnStyle.primary => AppColors.primary,
      BtnStyle.secondary => Colors.white,
      BtnStyle.dark => AppColors.text,
      BtnStyle.danger => AppColors.missingFg,
    };
    final fg = style == BtnStyle.secondary ? AppColors.text : Colors.white;
    final child = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[Icon(icon, size: 22), const SizedBox(width: 8)],
        Flexible(child: Text(tr(label), textAlign: TextAlign.center, overflow: TextOverflow.ellipsis)),
      ],
    );
    return SizedBox(
      height: height,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: fg,
          disabledBackgroundColor: bg.withOpacity(0.4),
          disabledForegroundColor: fg.withOpacity(0.7),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          textStyle: TextStyle(fontSize: height >= 56 ? 17 : 16, fontWeight: FontWeight.w700, fontFamily: AppTheme.fontFamily),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: style == BtnStyle.secondary ? const BorderSide(color: AppColors.borderStrong) : BorderSide.none,
          ),
        ),
        child: child,
      ),
    );
  }
}

/// Text-only link button.
class LinkButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  const LinkButton(this.label, {super.key, required this.onPressed});
  @override
  Widget build(BuildContext context) => TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 0),
          minimumSize: const Size(44, 44),
          alignment: Alignment.centerLeft,
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, fontFamily: AppTheme.fontFamily),
        ),
        child: Text(tr(label)),
      );
}

/// Round 48 px back button.
class BackCircle extends StatelessWidget {
  final VoidCallback? onPressed;
  const BackCircle({super.key, this.onPressed});
  @override
  Widget build(BuildContext context) => SizedBox(
        width: 44,
        height: 44,
        child: IconButton(
          onPressed: onPressed ?? () => Navigator.of(context).maybePop(),
          padding: EdgeInsets.zero,
          color: AppColors.text,
          tooltip: trn('Back'),
          icon: Icon(Icons.chevron_left, size: 28, semanticLabel: trn('Back')),
        ),
      );
}

class ProgressBar extends StatelessWidget {
  final double value;
  final double height;
  final Color background;
  final Color color;
  const ProgressBar(this.value, {super.key, this.height = 8, this.background = AppColors.track, this.color = AppColors.primary});
  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(height / 2),
        child: LinearProgressIndicator(
          value: value.clamp(0.0, 1.0).toDouble(),
          minHeight: height,
          backgroundColor: background,
          valueColor: AlwaysStoppedAnimation<Color>(color),
        ),
      );
}

/// Phone-first page: header, scrolling content, pinned footer.
/// On wide screens the content is centred at phone width.
class PhonePage extends StatelessWidget {
  final Widget? header;
  final List<Widget> children;
  final Widget? footer;
  final double gap;
  final EdgeInsets padding;
  final Color background;
  const PhonePage({
    super.key,
    this.header,
    required this.children,
    this.footer,
    this.gap = 20,
    this.padding = const EdgeInsets.fromLTRB(20, 16, 20, 24),
    this.background = AppColors.surface,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(children: [
              if (header != null) header!,
              Expanded(
                child: SingleChildScrollView(
                  padding: padding,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: spaced(children, gap)),
                ),
              ),
              if (footer != null) footer!,
            ]),
          ),
        ),
      ),
    );
  }
}

/// Footer bar with one or more large buttons side by side.
class FooterBar extends StatelessWidget {
  final List<Widget> children;
  final bool vertical;
  const FooterBar({super.key, required this.children, this.vertical = false});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
        decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: AppColors.divider))),
        child: vertical
            ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: spaced(children, 14))
            : Row(children: [
                for (var i = 0; i < children.length; i++) ...[
                  if (i > 0) const SizedBox(width: 12),
                  Expanded(flex: i == children.length - 1 && children.length > 1 ? 13 : 10, child: children[i]),
                ],
              ]),
      );
}

class H1 extends StatelessWidget {
  final String text;
  final double size;
  const H1(this.text, {super.key, this.size = 26});
  @override
  Widget build(BuildContext context) => Semantics(
        header: true,
        child: Text(tr(text), style: AppText.h1.copyWith(fontSize: size)),
      );
}

/// Labelled block with an optional example under the field.
class FieldBlock extends StatelessWidget {
  final String label;
  final String? example;
  final Widget child;
  const FieldBlock({super.key, required this.label, required this.child, this.example});
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(tr(label), style: AppText.label),
        const SizedBox(height: 10),
        child,
        if (example != null) ...[const SizedBox(height: 8), Text(tr(example!), style: AppText.small)],
      ]);
}

/// Text field that owns its controller and reports every change.
class AppTextField extends StatefulWidget {
  final String initial;
  final String? hint;
  final ValueChanged<String> onChanged;
  final TextInputType? keyboardType;
  final String? prefix;
  final int maxLines;
  final bool obscure;
  final int? maxLength;
  final TextAlign textAlign;
  final TextStyle? style;
  final String? semanticLabel;
  final bool showError;

  const AppTextField({
    super.key,
    required this.initial,
    required this.onChanged,
    this.hint,
    this.keyboardType,
    this.prefix,
    this.maxLines = 1,
    this.obscure = false,
    this.maxLength,
    this.textAlign = TextAlign.start,
    this.style,
    this.semanticLabel,
    this.showError = false,
  });

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  late final TextEditingController _c = TextEditingController(text: widget.initial);

  @override
  void didUpdateWidget(covariant AppTextField old) {
    super.didUpdateWidget(old);
    // Keep in sync when the value changes from elsewhere (e.g. "restore sample").
    if (widget.initial != _c.text && widget.initial != old.initial) {
      _c.text = widget.initial;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final numeric = widget.keyboardType == TextInputType.number;
    // Note: the "showError" style marks a blank field in red; it never fills in a value.
    return Semantics(
      label: trn(widget.semanticLabel),
      child: TextField(
        controller: _c,
        onChanged: widget.onChanged,
        keyboardType: widget.keyboardType,
        inputFormatters: numeric ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))] : null,
        obscureText: widget.obscure,
        maxLines: widget.obscure ? 1 : widget.maxLines,
        maxLength: widget.maxLength,
        textAlign: widget.textAlign,
        style: widget.style ?? const TextStyle(fontSize: 18, color: AppColors.text),
        decoration: InputDecoration(
          hintText: trn(widget.hint),
          counterText: '',
          prefixText: trn(widget.prefix),
          fillColor: widget.showError ? AppColors.missingBg : Colors.white,
          enabledBorder: widget.showError
              ? OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFC4554D), width: 1.5))
              : null,
        ),
      ),
    );
  }
}

/// Peso amount field. Empty = blank (null), never zero.
class PesoField extends StatelessWidget {
  final double? value;
  final ValueChanged<double?> onChanged;
  final String? hint;
  final bool flagBlank;
  const PesoField({super.key, required this.value, required this.onChanged, this.hint, this.flagBlank = false});
  @override
  Widget build(BuildContext context) => AppTextField(
        initial: amountText(value),
        hint: hint ?? '0',
        prefix: '₱ ',
        keyboardType: TextInputType.number,
        showError: flagBlank && value == null,
        onChanged: (s) => onChanged(parseAmount(s)),
      );
}

/// Row of large options; one selected.
class OptionRow<T> extends StatelessWidget {
  final List<(T, String)> options;
  final T value;
  final ValueChanged<T> onChanged;
  final double height;
  const OptionRow({super.key, required this.options, required this.value, required this.onChanged, this.height = 52});
  @override
  Widget build(BuildContext context) => Row(children: [
        for (var i = 0; i < options.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: Semantics(
              selected: options[i].$1 == value,
              button: true,
              child: SizedBox(
                height: height,
                child: TextButton(
                  onPressed: () => onChanged(options[i].$1),
                  style: TextButton.styleFrom(
                    backgroundColor: options[i].$1 == value ? AppColors.text : Colors.white,
                    foregroundColor: options[i].$1 == value ? Colors.white : AppColors.text,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, fontFamily: AppTheme.fontFamily),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: options[i].$1 == value ? AppColors.text : AppColors.borderStrong, width: 1.5),
                    ),
                  ),
                  child: Text(tr(options[i].$2), textAlign: TextAlign.center),
                ),
              ),
            ),
          ),
        ],
      ]);
}

/// − value + stepper with 52 px buttons.
class NumberStepper extends StatelessWidget {
  final String label;
  final int value;
  final ValueChanged<int> onChanged;
  final int min;
  const NumberStepper({super.key, required this.label, required this.value, required this.onChanged, this.min = 0});

  @override
  Widget build(BuildContext context) {
    Widget btn(IconData icon, String sem, VoidCallback onTap) => SizedBox(
          width: 52,
          height: 52,
          child: OutlinedButton(
            onPressed: onTap,
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.zero,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              side: const BorderSide(color: AppColors.borderStrong, width: 1.5),
              foregroundColor: AppColors.text,
            ),
            child: Icon(icon, semanticLabel: trn(sem)),
          ),
        );
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(tr(label), style: AppText.label),
      const SizedBox(height: 10),
      Row(children: [
        btn(Icons.remove, 'Less', () => onChanged(value > min ? value - 1 : min)),
        Expanded(child: Text(tr('$value'), textAlign: TextAlign.center, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700))),
        btn(Icons.add, 'More', () => onChanged(value + 1)),
      ]),
    ]);
  }
}

/// Multi-select chips ("Tap all that apply").
class ChoiceChips extends StatelessWidget {
  final String label;
  final List<String> options;
  final List<String> selected;
  final ValueChanged<String> onToggle;
  const ChoiceChips({super.key, required this.label, required this.options, required this.selected, required this.onToggle});
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(tr(label), style: AppText.label),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final o in options)
            FilterChip(
              label: Text(tr(o)),
              selected: selected.contains(o),
              onSelected: (_) => onToggle(o),
              showCheckmark: false,
              labelStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: selected.contains(o) ? Colors.white : AppColors.text),
              selectedColor: AppColors.primary,
              backgroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              shape: StadiumBorder(side: BorderSide(color: selected.contains(o) ? AppColors.primary : AppColors.borderStrong, width: 1.5)),
            ),
        ]),
      ]);
}

/// Pill toggle such as "Have it / Not yet".
class PillToggle extends StatelessWidget {
  final bool on;
  final VoidCallback onTap;
  final String onLabel;
  final String offLabel;
  const PillToggle({super.key, required this.on, required this.onTap, this.onLabel = 'Have it', this.offLabel = 'Not yet'});
  @override
  Widget build(BuildContext context) => Semantics(
        toggled: on,
        child: SizedBox(
          height: 44,
          child: TextButton(
            onPressed: onTap,
            style: TextButton.styleFrom(
              backgroundColor: on ? AppColors.primary : Colors.white,
              foregroundColor: on ? Colors.white : AppColors.text,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, fontFamily: AppTheme.fontFamily),
              shape: StadiumBorder(side: BorderSide(color: on ? AppColors.primary : AppColors.borderStrong, width: 1.5)),
            ),
            child: Text(tr(on ? onLabel : offLabel)),
          ),
        ),
      );
}

enum TagKind { actual, estimate, verified, self, missing, neutral }

class StatusTag extends StatelessWidget {
  final TagKind kind;
  final String? label;
  const StatusTag(this.kind, {super.key, this.label});

  @override
  Widget build(BuildContext context) {
    final (bg, fg, def) = switch (kind) {
      TagKind.actual => (AppColors.actualBg, AppColors.actualFg, 'Actual'),
      TagKind.estimate => (AppColors.estimateBg, AppColors.estimateFg, 'Estimate'),
      TagKind.verified => (AppColors.tint, AppColors.primary, 'Verified'),
      TagKind.self => (AppColors.surface2, AppColors.text2, 'Self-reported'),
      TagKind.missing => (AppColors.missingBg, AppColors.missingFg, 'Missing'),
      TagKind.neutral => (AppColors.surface2, AppColors.text2, ''),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(15)),
      child: Text(tr(label ?? def), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: fg)),
    );
  }
}

enum NoteKind { ok, info, warn, missing }

class NoteBox extends StatelessWidget {
  final String text;
  final NoteKind kind;
  final String? title;
  final Widget? action;
  const NoteBox(this.text, {super.key, this.kind = NoteKind.info, this.title, this.action});
  @override
  Widget build(BuildContext context) {
    final (bg, fg, border, icon) = switch (kind) {
      NoteKind.ok => (AppColors.tint, AppColors.primary, null, Icons.check_circle_outline),
      NoteKind.info => (AppColors.surface2, AppColors.text2, null, null),
      NoteKind.warn => (AppColors.warnBg, AppColors.text, AppColors.warnBorder, null),
      NoteKind.missing => (AppColors.missingBg, AppColors.missingFg, null, Icons.error_outline),
    };
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: border == null ? null : Border.all(color: border, width: 1.5),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (icon != null) ...[Icon(icon, color: fg, size: 24), const SizedBox(width: 12)],
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (title != null) ...[Text(tr(title!), style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: fg)), const SizedBox(height: 4)],
            Text(tr(text), style: TextStyle(fontSize: 16, height: 1.45, color: fg)),
            if (action != null) ...[const SizedBox(height: 12), action!],
          ]),
        ),
      ]),
    );
  }
}

/// Tinted "worked out for you" result.
class ResultCard extends StatelessWidget {
  final String label;
  final String sub;
  final String value;
  const ResultCard({super.key, required this.label, required this.sub, required this.value});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: AppColors.tint, borderRadius: BorderRadius.circular(16)),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(tr(label), style: const TextStyle(fontSize: 17, color: AppColors.primary)),
              Text(tr(sub), style: const TextStyle(fontSize: 14, color: AppColors.primary)),
            ]),
          ),
          Text(tr(value), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.primary)),
        ]),
      );
}

/// Bordered card.
class CardBox extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final Color? color;
  final Color borderColor;
  final double radius;
  const CardBox({super.key, required this.child, this.padding = const EdgeInsets.all(18), this.color, this.borderColor = AppColors.border, this.radius = 16});
  @override
  Widget build(BuildContext context) => Container(
        padding: padding,
        decoration: BoxDecoration(
          color: color ?? Colors.white,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: borderColor, width: 1.5),
        ),
        child: child,
      );
}

/// Label / value line with divider.
class KeyValueRow extends StatelessWidget {
  final String label;
  final String value;
  final bool total;
  final bool divider;
  final double size;
  const KeyValueRow(this.label, this.value, {super.key, this.total = false, this.divider = true, this.size = 17});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: divider ? Border(bottom: BorderSide(color: total ? AppColors.text : AppColors.divider, width: total ? 2 : 1)) : null,
        ),
        child: Row(children: [
          Expanded(
            child: Text(tr(label), style: TextStyle(fontSize: size, fontWeight: total ? FontWeight.w700 : FontWeight.w400)),
          ),
          const SizedBox(width: 12),
          Text(tr(value), style: TextStyle(fontSize: size, fontWeight: FontWeight.w700)),
        ]),
      );
}

/// Dashed-style "+ Add" button.
class AddButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const AddButton(this.label, {super.key, required this.onTap});
  @override
  Widget build(BuildContext context) => SizedBox(
        height: 56,
        child: OutlinedButton.icon(
          onPressed: onTap,
          icon: const Icon(Icons.add),
          label: Text(tr(label)),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primary,
            side: const BorderSide(color: Color(0xFF9AA49E), width: 1.5),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, fontFamily: AppTheme.fontFamily),
          ),
        ),
      );
}

/// Small rounded icon tile used in lists.
class IconTile extends StatelessWidget {
  final IconData icon;
  final double size;
  final Color bg;
  final Color fg;
  const IconTile(this.icon, {super.key, this.size = 44, this.bg = AppColors.tint, this.fg = AppColors.primary});
  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(size * 0.27)),
        child: Icon(icon, color: fg, size: size * 0.5),
      );
}

void toast(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(tr(message))));
}

/// Two-way switch used in settings.
class AppSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final String semanticLabel;
  const AppSwitch({super.key, required this.value, required this.onChanged, required this.semanticLabel});
  @override
  Widget build(BuildContext context) => Semantics(
        label: trn(semanticLabel),
        child: Switch(
          value: value,
          onChanged: onChanged,
          activeColor: Colors.white,
          activeTrackColor: AppColors.primary,
          inactiveThumbColor: Colors.white,
          inactiveTrackColor: AppColors.borderStrong,
        ),
      );
}
