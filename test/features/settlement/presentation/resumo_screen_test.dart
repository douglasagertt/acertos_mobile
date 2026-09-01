import 'package:acertos_mobile/features/settlement/presentation/resumo_screen.dart';
import 'package:acertos_mobile/features/transactions/providers/transactions_provider.dart';
import 'package:acertos_mobile/shared/models/owner.dart';
import 'package:acertos_mobile/shared/models/transaction.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders the settlement totals derived from the shared transactions provider', (tester) async {
    final container = ProviderContainer();
    container.read(transactionsProvider.notifier).replaceAll([
      Transaction(owner: Owner.bruna, value: 135.85),
      Transaction(owner: Owner.douglas, value: 56.26),
      Transaction(owner: Owner.compartilhado, shared: true, value: 90.0),
    ]);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const MaterialApp(home: ResumoScreen())),
    );

    expect(find.text('Resumo do Acerto'), findsOneWidget);
    expect(find.text('Bruna'), findsOneWidget);
    expect(find.text('Douglas'), findsOneWidget);

    // The person cards show *individual* spend only, without the shared
    // half — otherwise Douglas's card would just restate "Douglas deve
    // pagar" (which is his individual spend + half the shared).
    expect(find.text('R\$ 135,85'), findsOneWidget); // Bruna individual
    expect(find.text('R\$ 56,26'), findsOneWidget); // Douglas individual
    // Douglas deve pagar: 56.26 + 45.00 (half of 90) = 101.26.
    expect(tester.widget<Text>(find.byKey(const Key('resumo-douglas-to-pay'))).data, 'R\$ 101,26');

    expect(find.text('R\$ 90,00'), findsOneWidget); // Compartilhado total
    expect(find.text('R\$ 45,00'), findsOneWidget); // Cada um
    expect(find.text('R\$ 282,11'), findsOneWidget); // grand total (180.85 + 101.26)
    expect(find.text('R\$ 180,85'), findsNothing); // Bruna's card is not her total-with-shared
  });

  testWidgets('shows zeros with no transactions', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: MaterialApp(home: ResumoScreen())));
    expect(find.text('R\$ 0,00'), findsWidgets);
  });
}
