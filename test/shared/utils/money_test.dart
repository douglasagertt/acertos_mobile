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
  });
}
