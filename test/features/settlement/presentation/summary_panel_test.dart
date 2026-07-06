import 'package:acertos_mobile/features/settlement/presentation/summary_panel.dart';
import 'package:acertos_mobile/shared/models/totals.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders all metrics formatted as pt-BR currency', (tester) async {
    const totals = Totals(
      bruna: 135.85,
      douglas: 56.26,
      sharedTotal: 89.99,
      sharedHalf: 45.0,
      douglasToPay: 56.26,
      grandTotal: 282.10,
      ignored: 24.18,
    );

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: SummaryPanel(totals: totals))),
    );

    expect(find.text('R\$ 135,85'), findsOneWidget); // Cartão Bruna
    expect(find.text('R\$ 56,26'), findsNWidgets(2)); // Cartão Douglas + Douglas deve pagar
    expect(find.text('R\$ 89,99'), findsOneWidget); // Compartilhado total
    expect(find.text('R\$ 45,00'), findsOneWidget); // Compartilhado cada um
    expect(find.text('R\$ 24,18'), findsOneWidget); // Ignorados
    expect(find.text('R\$ 282,10'), findsOneWidget); // Total
    expect(find.text('Douglas deve pagar'), findsOneWidget);
  });

  testWidgets('renders zeros for empty totals', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: SummaryPanel(totals: Totals()))),
    );

    expect(find.text('R\$ 0,00'), findsWidgets);
  });
}
