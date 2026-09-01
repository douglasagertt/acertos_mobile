import 'package:acertos_mobile/shared/utils/money.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('round2', () {
    test('rounds to 2 decimal places', () {
      expect(round2(16.666), 16.67);
      expect(round2(16.664), 16.66);
    });
  });

  group('formatMoney', () {
    test('formats positive values with thousands separator and comma decimal', () {
      expect(formatMoney(1234.5), 'R\$ 1.234,50');
      expect(formatMoney(98.0), 'R\$ 98,00');
    });

    test('negative values (extorno) start with a minus sign', () {
      final text = formatMoney(-100.62);
      expect(text.startsWith('-'), isTrue);
      expect(text, '-R\$ 100,62');
    });

    test('groups every three digits, however large the value', () {
      expect(formatMoney(1000), 'R\$ 1.000,00');
      expect(formatMoney(15568.34), 'R\$ 15.568,34');
      expect(formatMoney(1234567.89), 'R\$ 1.234.567,89');
      expect(formatMoney(-1234567.89), '-R\$ 1.234.567,89');
    });

    test('values under a cent read as zero, without a stray minus sign', () {
      // -0.001 rounds to -0.0, which must not print as "-R\$ 0,00".
      expect(formatMoney(-0.001), 'R\$ 0,00');
      expect(formatMoney(0), 'R\$ 0,00');
    });

    test('rounds half away from zero at the cent boundary, like the Python original', () {
      expect(formatMoney(-0.005), '-R\$ 0,01');
      expect(formatMoney(0.005), 'R\$ 0,01');
      expect(round2(-16.665), -16.67);
    });
  });

  group('displayValue', () {
    test('shows a dash for zero and the formatted value otherwise', () {
      expect(displayValue(0), '—');
      expect(displayValue(-0.0), '—');
      expect(displayValue(98.0), 'R\$ 98,00');
      expect(displayValue(-50.0), '-R\$ 50,00');
    });
  });
}
