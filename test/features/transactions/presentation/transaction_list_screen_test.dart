import 'package:acertos_mobile/features/transactions/presentation/transaction_list_screen.dart';
import 'package:acertos_mobile/shared/models/owner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Widget buildApp() {
  return const ProviderScope(child: MaterialApp(home: TransactionListScreen()));
}

void main() {
  testWidgets('shows the empty state when there are no transactions', (tester) async {
    await tester.pumpWidget(buildApp());
    expect(find.text('Nenhuma transação'), findsOneWidget);
  });

  testWidgets('adding an expense shows it in the list and hides the empty state', (tester) async {
    await tester.pumpWidget(buildApp());

    await tester.tap(find.widgetWithText(FilledButton, 'Despesa'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('expenseNameField')), 'Mercado');
    await tester.enterText(find.byKey(const Key('valueField')), '50,00');
    await tester.tap(find.widgetWithText(FilledButton, 'Adicionar'));
    await tester.pumpAndSettle();

    expect(find.text('Nenhuma transação'), findsNothing);
    expect(find.text('Mercado'), findsOneWidget);
    expect(find.text('R\$ 50,00'), findsOneWidget);
  });

  testWidgets('submitting with an empty description does not add a row', (tester) async {
    await tester.pumpWidget(buildApp());

    await tester.tap(find.widgetWithText(FilledButton, 'Despesa'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('valueField')), '50,00');
    await tester.tap(find.widgetWithText(FilledButton, 'Adicionar'));
    await tester.pumpAndSettle();

    // Dialog should still be open (submit was a no-op), matching
    // AddExpenseDialog.tsx's silent-no-op-on-invalid-input behavior.
    expect(find.byKey(const Key('expenseNameField')), findsOneWidget);
  });

  testWidgets('deleting a row removes it from the list', (tester) async {
    await tester.pumpWidget(buildApp());

    await tester.tap(find.widgetWithText(FilledButton, 'Despesa'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('expenseNameField')), 'Farmácia');
    await tester.enterText(find.byKey(const Key('valueField')), '20,00');
    await tester.tap(find.widgetWithText(FilledButton, 'Adicionar'));
    await tester.pumpAndSettle();

    expect(find.text('Farmácia'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();

    expect(find.text('Farmácia'), findsNothing);
    expect(find.text('Nenhuma transação'), findsOneWidget);
  });

  testWidgets('changing owner to Compartilhado checks the shared box', (tester) async {
    await tester.pumpWidget(buildApp());

    await tester.tap(find.widgetWithText(FilledButton, 'Despesa'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('expenseNameField')), 'Aluguel');
    await tester.enterText(find.byKey(const Key('valueField')), '100,00');
    await tester.tap(find.widgetWithText(FilledButton, 'Adicionar'));
    await tester.pumpAndSettle();

    // Only one row exists at this point, so its owner dropdown (whose Key is
    // derived from the transaction's server-generated id, unknown here) is
    // the only DropdownButtonFormField<Owner> on screen.
    final ownerDropdownFinder = find.byType(DropdownButtonFormField<Owner>);
    expect(ownerDropdownFinder, findsOneWidget);

    await tester.tap(ownerDropdownFinder);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Compartilhado').last);
    await tester.pumpAndSettle();

    final checkbox = tester.widget<Checkbox>(find.byType(Checkbox));
    expect(checkbox.value, isTrue);
  });
}
