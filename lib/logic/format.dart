/// Peso and number formatting without extra packages.
String groupDigits(int n) {
  final s = n.abs().toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return (n < 0 ? '-' : '') + b.toString();
}

/// `₱12,345`. Returns `—` for a blank (null) value — blanks are never shown as 0.
String peso(double? v, {bool parens = false}) {
  if (v == null) return '—';
  final body = '₱${groupDigits(v.abs().round())}';
  if (parens) return '($body)';
  return v < 0 ? '−$body' : body;
}

String pct(double? v, {int digits = 1}) => v == null ? '—' : '${(v * 100).toStringAsFixed(digits)}%';

String times(double? v) => v == null ? '—' : '${v.toStringAsFixed(1)}×';

/// Parses user input such as "1,200" or "₱ 3000". Returns null when blank or invalid.
double? parseAmount(String input) {
  final cleaned = input.replaceAll(RegExp(r'[^0-9.\-]'), '');
  if (cleaned.isEmpty) return null;
  return double.tryParse(cleaned);
}

/// Shows a stored number in an input box (no trailing ".0").
String amountText(double? v) {
  if (v == null) return '';
  return v == v.roundToDouble() ? v.round().toString() : v.toString();
}
