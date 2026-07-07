import 'package:acertos_mobile/features/pdf_export/pdf_generator.dart';
import 'package:acertos_mobile/features/settlement/calculate_totals.dart';
import 'package:acertos_mobile/shared/models/owner.dart';
import 'package:acertos_mobile/shared/models/totals.dart';
import 'package:acertos_mobile/shared/models/transaction.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('generates valid, non-empty PDF bytes for a settlement', () async {
    final transactions = [
      Transaction(
        datetime: '09/jun 12:41',
        city: 'Novo Hamburgo',
        purchaseType: 'Presencial',
        expenseName: 'Restaurante Mm E Ef Nh',
        value: 98.0,
        owner: Owner.bruna,
      ),
      Transaction(
        datetime: '06/jun 13:22',
        city: 'Novo Hamburgo',
        purchaseType: 'Presencial',
        expenseName: 'Panvel Filial 170',
        value: 135.85,
        owner: Owner.douglas,
      ),
      Transaction(
        datetime: '31/mai 14:44',
        city: 'Porto Alegre',
        purchaseType: 'Presencial',
        expenseName: 'Lego Porto Alegre',
        value: 89.99,
        owner: Owner.compartilhado,
        shared: true,
        obs: 'presente',
      ),
      Transaction(
        datetime: '11/jun 21:14',
        expenseName: 'Anuidade Diferenc',
        installment: '03/12',
        value: -67.08,
        owner: Owner.ignorar,
      ),
    ];
    final totals = calculateTotals(transactions);

    final bytes = await generateSettlementPdf(transactions: transactions, totals: totals, month: 6, year: 2026);

    expect(bytes, isNotEmpty);
    // "%PDF" magic header.
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
    // A real document with a table + summary, not a near-empty stub.
    expect(bytes.length, greaterThan(2000));
  });

  test('handles an empty transaction list without throwing', () async {
    const totals = Totals();
    final bytes = await generateSettlementPdf(transactions: const [], totals: totals, month: 1, year: 2026);
    expect(bytes, isNotEmpty);
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
  });
}
