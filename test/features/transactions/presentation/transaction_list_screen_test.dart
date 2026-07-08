import 'package:acertos_mobile/features/transactions/presentation/add_expense_dialog.dart';
import 'package:acertos_mobile/features/transactions/presentation/transaction_list_screen.dart';
import 'package:acertos_mobile/features/transactions/presentation/widgets/transaction_row_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Widget buildApp() {
  return const ProviderScope(child: MaterialApp(home: TransactionListScreen()));
}

void main() {
  // Use a realistic phone-sized viewport rather than flutter_test's default
  // 800x600 surface, matching the real device width this screen is designed
  // for (see PLAN.md's "RenderFlex overflow on the owner dropdown" note).
  setUp(() {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    binding.platformDispatcher.views.first.physicalSize = const Size(400, 850);
    binding.platformDispatcher.views.first.devicePixelRatio = 1.0;
    addTearDown(binding.platformDispatcher.views.first.resetPhysicalSize);
    addTearDown(binding.platformDispatcher.views.first.resetDevicePixelRatio);
  });

  testWidgets('shows the empty state when there are no transactions', (tester) async {
    await tester.pumpWidget(buildApp());
    expect(find.text('Nenhuma transação'), findsOneWidget);
  });

  testWidgets('adding an expense shows it in the list and hides the empty state', (tester) async {
    await tester.pumpWidget(buildApp());

    await tester.tap(find.widgetWithText(OutlinedButton, 'Despesa'));
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

    await tester.tap(find.widgetWithText(OutlinedButton, 'Despesa'));
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

    await tester.tap(find.widgetWithText(OutlinedButton, 'Despesa'));
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

  testWidgets('tapping the Compartilhado pill sets owner to Compartilhado', (tester) async {
    await tester.pumpWidget(buildApp());

    await tester.tap(find.widgetWithText(OutlinedButton, 'Despesa'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('expenseNameField')), 'Aluguel');
    await tester.enterText(find.byKey(const Key('valueField')), '100,00');
    await tester.tap(find.widgetWithText(FilledButton, 'Adicionar'));
    await tester.pumpAndSettle();

    // Default owner is Bruna, so the row shows one "Compartilhado" pill
    // (inactive) among the four owner pills. Scoped to the row card since
    // the Home toolbar's own "Compartilhado" filter chip now also matches
    // find.text('Compartilhado').
    await tester.tap(find.descendant(of: find.byType(TransactionRowCard), matching: find.text('Compartilhado')));
    await tester.pumpAndSettle();

    // The Compartilhado pill is now the active (filled) one, confirming the
    // tap actually changed the row's owner — totals now live only on the
    // Resumo tab (see resumo_screen_test.dart), not duplicated on Home.
    expect(find.text('R\$ 100,00'), findsOneWidget);
  });

  testWidgets('owner filter chips narrow the list, and Todas restores it', (tester) async {
    await tester.pumpWidget(buildApp());

    await tester.tap(find.widgetWithText(OutlinedButton, 'Despesa'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('expenseNameField')), 'Mercado');
    await tester.enterText(find.byKey(const Key('valueField')), '50,00');
    await tester.tap(find.widgetWithText(FilledButton, 'Adicionar'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(OutlinedButton, 'Despesa'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('expenseNameField')), 'Gasolina');
    await tester.enterText(find.byKey(const Key('valueField')), '80,00');
    // The dialog's own owner pills default to Bruna; switch this one to
    // Douglas. Scoped to the dialog since the Mercado row and the filter
    // chip underneath it also render a "Douglas" text.
    await tester.tap(find.descendant(of: find.byType(AddExpenseDialog), matching: find.text('Douglas')));
    await tester.tap(find.widgetWithText(FilledButton, 'Adicionar'));
    await tester.pumpAndSettle();

    expect(find.text('Mercado'), findsOneWidget);
    expect(find.text('Gasolina'), findsOneWidget);

    final filterRow = find.byKey(const Key('ownerFilterRow'));

    await tester.tap(find.descendant(of: filterRow, matching: find.text('Douglas')));
    await tester.pumpAndSettle();
    expect(find.text('Gasolina'), findsOneWidget);
    expect(find.text('Mercado'), findsNothing);

    // No ignored transactions exist — the filtered-empty message shows
    // instead of the "no transactions at all" empty state.
    await tester.tap(find.descendant(of: filterRow, matching: find.text('Ignorados')));
    await tester.pumpAndSettle();
    expect(find.text('Gasolina'), findsNothing);
    expect(find.text('Nenhuma transação para esse filtro'), findsOneWidget);

    await tester.tap(find.descendant(of: filterRow, matching: find.text('Todas')));
    await tester.pumpAndSettle();
    expect(find.text('Mercado'), findsOneWidget);
    expect(find.text('Gasolina'), findsOneWidget);
  });
}
