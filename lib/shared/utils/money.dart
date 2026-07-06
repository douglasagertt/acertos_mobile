/// Rounds to 2 decimal places — same convention as `round2` in
/// acertos/web/e2e/utils/money.ts (mirrors the backend's Python `round`).
double round2(double value) => (value * 100).round() / 100;

/// Formats a value as pt-BR currency (e.g. "R$ 1.234,56", "-R$ 100,62"),
/// matching `formatMoney` in acertos/web/src/types/index.ts.
String formatMoney(double value) {
  final rounded = round2(value);
  final isNegative = rounded < 0;
  final fixed = rounded.abs().toStringAsFixed(2);
  final parts = fixed.split('.');
  final intPart = parts[0];
  final decPart = parts[1];

  final buffer = StringBuffer();
  for (var i = 0; i < intPart.length; i++) {
    if (i > 0 && (intPart.length - i) % 3 == 0) buffer.write('.');
    buffer.write(intPart[i]);
  }

  return '${isNegative ? '-' : ''}R\$ $buffer,$decPart';
}
