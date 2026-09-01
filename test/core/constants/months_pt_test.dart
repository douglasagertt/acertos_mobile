import 'package:acertos_mobile/core/constants/months_pt.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('covers all twelve months, in Portuguese', () {
    expect(monthsPt, hasLength(12));
    expect(monthsPt[1], 'Janeiro');
    expect(monthsPt[8], 'Agosto');
    expect(monthsPt[12], 'Dezembro');
  });

  test('monthNameOf names a month, and gives an empty name outside 1-12', () {
    expect(monthNameOf(8), 'Agosto');
    expect(monthNameOf(0), isEmpty);
    expect(monthNameOf(13), isEmpty);
  });
}
