import 'package:acertos_mobile/shared/models/owner.dart';
import 'package:acertos_mobile/shared/models/totals.dart';
import 'package:acertos_mobile/shared/models/transaction.dart';
import 'package:acertos_mobile/shared/utils/money.dart';

/// Direct port of `calculate_totals()` in acertos/src/core/calculator.py.
///
/// `Douglas deve pagar = Douglas exclusivo + 50% compartilhado`.
Totals calculateTotals(List<Transaction> transactions) {
  var bruna = 0.0;
  var douglas = 0.0;
  var sharedTotal = 0.0;
  var ignored = 0.0;

  for (final t in transactions) {
    final v = t.value;
    if (t.owner == Owner.ignorar) {
      ignored += v;
      continue;
    }
    if (t.shared || t.owner == Owner.compartilhado) {
      sharedTotal += v;
      bruna += round2(v / 2);
      douglas += round2(v / 2);
    } else if (t.owner == Owner.bruna) {
      bruna += v;
    } else if (t.owner == Owner.douglas) {
      douglas += v;
    }
  }

  final sharedHalf = round2(sharedTotal / 2);
  final douglasToPay = round2(douglas);

  return Totals(
    bruna: round2(bruna),
    douglas: round2(douglas),
    sharedTotal: round2(sharedTotal),
    sharedHalf: sharedHalf,
    douglasToPay: douglasToPay,
    grandTotal: round2(bruna + douglas),
    ignored: round2(ignored),
  );
}
