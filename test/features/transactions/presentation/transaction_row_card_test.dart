import 'package:acertos_mobile/features/transactions/presentation/widgets/transaction_row_card.dart';
import 'package:acertos_mobile/shared/models/owner.dart';
import 'package:acertos_mobile/shared/models/transaction.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows installment info in the subtitle when present', (tester) async {
    final t = Transaction(
      datetime: '11/jun 21:14',
      expenseName: 'Anuidade Diferenc',
      installment: '03/12',
      value: -67.08,
      owner: Owner.ignorar,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TransactionRowCard(transaction: t, index: 0, onUpdate: (_) {}, onDelete: (_) {}),
        ),
      ),
    );

    expect(find.textContaining('Parcela 03/12'), findsOneWidget);
  });

  testWidgets('omits the subtitle line entirely when there is nothing to show', (tester) async {
    final t = Transaction(expenseName: 'Despesa manual', value: 10);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TransactionRowCard(transaction: t, index: 0, onUpdate: (_) {}, onDelete: (_) {}),
        ),
      ),
    );

    expect(find.textContaining('Parcela'), findsNothing);
  });
}
