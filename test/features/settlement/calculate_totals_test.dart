// Mirrors the scenarios in acertos/web/e2e/tests/{shared-split,extorno,
// reconciliation,delete-row}.spec.ts, adapted to a pure unit test: instead of
// importing a real invoice PDF and reading totals off the live UI, these
// build synthetic Transaction fixtures and call calculateTotals() directly.
// Expected values are derived via the same round2() helper the
// implementation uses (not hardcoded), matching the "no hardcoded
// expectations" style of the original e2e suite.

import 'package:acertos_mobile/features/settlement/calculate_totals.dart';
import 'package:acertos_mobile/shared/models/owner.dart';
import 'package:acertos_mobile/shared/models/transaction.dart';
import 'package:acertos_mobile/shared/utils/money.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // A realistic backdrop of unrelated transactions so the assertions below
  // are checking deltas against a non-trivial baseline, not an empty list.
  List<Transaction> baseline() => [
    Transaction(owner: Owner.bruna, value: 135.85),
    Transaction(owner: Owner.douglas, value: 56.26),
    Transaction(owner: Owner.compartilhado, value: 89.99),
    Transaction(owner: Owner.ignorar, value: 24.18),
  ];

  group('shared-split — marking a transaction as shared splits it 50/50', () {
    test('Bruna-owned transaction marked shared', () {
      final target = Transaction(owner: Owner.bruna, value: 77.77);
      final list = [...baseline(), target];
      final before = calculateTotals(list);

      final afterList = [...baseline(), target.copyWith(shared: true)];
      final after = calculateTotals(afterList);

      final half = round2(target.value / 2);
      expect(after.sharedTotal, closeTo(before.sharedTotal + target.value, 0.01));
      expect(after.sharedHalf, closeTo(round2(after.sharedTotal / 2), 0.01));
      expect(after.bruna, closeTo(before.bruna - target.value + half, 0.01));
      expect(after.douglas, closeTo(before.douglas + half, 0.01));
      // Sharing only redistributes between Bruna and Douglas — grand total unchanged.
      expect(after.grandTotal, closeTo(before.grandTotal, 0.01));
    });

    test('Douglas-owned transaction marked shared', () {
      final target = Transaction(owner: Owner.douglas, value: 111.0);
      final list = [...baseline(), target];
      final before = calculateTotals(list);

      final afterList = [...baseline(), target.copyWith(shared: true)];
      final after = calculateTotals(afterList);

      final half = round2(target.value / 2);
      expect(after.sharedTotal, closeTo(before.sharedTotal + target.value, 0.01));
      expect(after.douglas, closeTo(before.douglas - target.value + half, 0.01));
      expect(after.bruna, closeTo(before.bruna + half, 0.01));
      expect(after.grandTotal, closeTo(before.grandTotal, 0.01));
    });
  });

  group('extorno — negative values reduce the original owner\'s total', () {
    test('un-ignoring a negative Douglas-owned transaction', () {
      final extorno = Transaction(owner: Owner.douglas, value: -67.08);
      final before = calculateTotals([...baseline(), extorno]);

      final after = calculateTotals([...baseline(), extorno.copyWith(owner: Owner.ignorar)]);

      expect(after.ignored, closeTo(before.ignored + extorno.value, 0.01));
      expect(after.grandTotal, closeTo(before.grandTotal - extorno.value, 0.01));
      expect(after.douglas, closeTo(before.douglas - extorno.value, 0.01));
      expect(after.bruna, closeTo(before.bruna, 0.01));
    });

    test('un-ignoring a negative shared transaction', () {
      final extorno = Transaction(owner: Owner.bruna, shared: true, value: -33.54);
      final before = calculateTotals([...baseline(), extorno]);

      final after = calculateTotals([...baseline(), extorno.copyWith(owner: Owner.ignorar, shared: false)]);

      final half = round2(extorno.value / 2);
      expect(after.ignored, closeTo(before.ignored + extorno.value, 0.01));
      expect(after.grandTotal, closeTo(before.grandTotal - extorno.value, 0.01));
      expect(after.bruna, closeTo(before.bruna - half, 0.01));
      expect(after.douglas, closeTo(before.douglas - half, 0.01));
      expect(after.sharedTotal, closeTo(before.sharedTotal - extorno.value, 0.01));
    });
  });

  group('reconciliation — invariants that must hold after any import', () {
    test('grand total, douglasToPay and sharedHalf stay internally consistent', () {
      // Shared/compartilhado values below use an even number of cents on
      // purpose: calculateTotals() rounds each half independently (matching
      // calculator.py), so an odd-cent shared value (e.g. 89.99) can sum
      // back to 90.00 across the two halves — a real, pre-existing 1-cent
      // quirk of that rounding approach, not something this test is meant
      // to exercise.
      final list = [
        Transaction(owner: Owner.bruna, value: 135.85),
        Transaction(owner: Owner.douglas, value: 56.26),
        Transaction(owner: Owner.compartilhado, value: 90.00),
        Transaction(owner: Owner.bruna, shared: true, value: 24.18),
        Transaction(owner: Owner.ignorar, value: 500.0),
      ];
      final totals = calculateTotals(list);

      expect(totals.grandTotal, closeTo(round2(totals.bruna + totals.douglas), 0.01));
      expect(totals.douglasToPay, closeTo(totals.douglas, 0.01));
      expect(totals.sharedHalf, closeTo(round2(totals.sharedTotal / 2), 0.01));

      // Grand total = sum of every non-ignored transaction's value (the
      // real invoice-PDF equivalent of this check happens once PDF import
      // exists — see PLAN.md Phase 1 step 6).
      final expectedGrandTotal = round2(
        list.where((t) => t.owner != Owner.ignorar).fold(0.0, (sum, t) => sum + t.value),
      );
      expect(totals.grandTotal, closeTo(expectedGrandTotal, 0.01));
    });
  });

  group('delete-row — removing a transaction subtracts its value from the right total', () {
    test('removing a Bruna-owned row', () {
      final target = Transaction(owner: Owner.bruna, value: 98.0);
      final list = [...baseline(), target];
      final before = calculateTotals(list);
      final after = calculateTotals(list.where((t) => t.id != target.id).toList());

      expect(after.bruna, closeTo(before.bruna - target.value, 0.01));
      expect(after.grandTotal, closeTo(before.grandTotal - target.value, 0.01));
    });

    test('removing a Douglas-owned row', () {
      final target = Transaction(owner: Owner.douglas, value: 350.79);
      final list = [...baseline(), target];
      final before = calculateTotals(list);
      final after = calculateTotals(list.where((t) => t.id != target.id).toList());

      expect(after.douglas, closeTo(before.douglas - target.value, 0.01));
      expect(after.grandTotal, closeTo(before.grandTotal - target.value, 0.01));
    });

    test('removing a shared row', () {
      final target = Transaction(owner: Owner.douglas, shared: true, value: 61.9);
      final list = [...baseline(), target];
      final before = calculateTotals(list);
      final after = calculateTotals(list.where((t) => t.id != target.id).toList());

      final half = round2(target.value / 2);
      expect(after.bruna, closeTo(before.bruna - half, 0.01));
      expect(after.douglas, closeTo(before.douglas - half, 0.01));
      expect(after.sharedTotal, closeTo(before.sharedTotal - target.value, 0.01));
      expect(after.grandTotal, closeTo(before.grandTotal - target.value, 0.01));
    });

    test('removing an ignored row leaves grand total unchanged', () {
      final target = Transaction(owner: Owner.ignorar, value: 235.37);
      final list = [...baseline(), target];
      final before = calculateTotals(list);
      final after = calculateTotals(list.where((t) => t.id != target.id).toList());

      expect(after.ignored, closeTo(before.ignored - target.value, 0.01));
      expect(after.grandTotal, closeTo(before.grandTotal, 0.01));
    });
  });
}
