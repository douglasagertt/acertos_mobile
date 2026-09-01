import 'dart:async';

import 'package:acertos_mobile/core/navigation/app_shell.dart';
import 'package:acertos_mobile/features/history/acertos_store.dart';
import 'package:acertos_mobile/features/history/presentation/acertos_screen.dart';
import 'package:acertos_mobile/features/history/providers/acertos_providers.dart';
import 'package:acertos_mobile/features/transactions/providers/transactions_provider.dart';
import 'package:acertos_mobile/shared/models/owner.dart';
import 'package:acertos_mobile/shared/models/transaction.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_acertos_store.dart';

void main() {
  late FakeAcertosStore store;

  setUp(() {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    binding.platformDispatcher.views.first.physicalSize = const Size(400, 850);
    binding.platformDispatcher.views.first.devicePixelRatio = 1.0;
    addTearDown(binding.platformDispatcher.views.first.resetPhysicalSize);
    addTearDown(binding.platformDispatcher.views.first.resetDevicePixelRatio);

    store = FakeAcertosStore();
  });

  List<Transaction> sample() => [
    Transaction(expenseName: 'Mercado', value: 135.85, owner: Owner.bruna),
    Transaction(expenseName: 'Farmácia', value: 56.26, owner: Owner.douglas),
  ];

  AcertoRecord august() => const AcertoRecord(
    id: 'august-2026',
    month: 8,
    year: 2026,
    monthName: 'Agosto',
    createdAt: '2026-09-01T21:04:00.000',
    updatedAt: '2026-09-01T21:04:00.000',
    transactionCount: 2,
    grandTotal: 192.11,
    douglasToPay: 56.26,
  );

  Future<ProviderContainer> pumpScreen(WidgetTester tester) async {
    final container = ProviderContainer(overrides: [acertosStoreProvider.overrideWithValue(store)]);
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const MaterialApp(home: AcertosScreen())),
    );
    await tester.pumpAndSettle();
    return container;
  }

  Future<void> openSheetAndTap(WidgetTester tester, String action) async {
    await tester.tap(find.text('Agosto/2026'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(action));
    await tester.pumpAndSettle();
  }

  testWidgets('shows the empty state when no month was ever closed', (tester) async {
    await pumpScreen(tester);

    expect(find.text('Nenhum acerto salvo ainda'), findsOneWidget);
  });

  testWidgets('lists a saved acerto with its month, value and when it was saved', (tester) async {
    store.seed(august(), sample());
    await pumpScreen(tester);

    expect(find.text('Agosto/2026'), findsOneWidget);
    expect(find.text('R\$ 56,26'), findsOneWidget);
    expect(find.textContaining('2 lançamentos'), findsOneWidget);
    expect(find.textContaining('01/09/2026 21:04'), findsOneWidget);
  });

  testWidgets('opening a record loads its transactions and jumps to Home', (tester) async {
    store.seed(august(), sample());
    final container = await pumpScreen(tester);
    container.read(selectedTabProvider.notifier).select(2);

    await openSheetAndTap(tester, 'Abrir');

    expect(container.read(transactionsProvider), hasLength(2));
    expect(container.read(transactionsProvider).first.expenseName, 'Mercado');
    expect(container.read(transactionsProvider.notifier).openRecordId, 'august-2026');
    expect(container.read(selectedTabProvider), 0);
  });

  testWidgets('opening asks first when the session has other unsaved work', (tester) async {
    store.seed(august(), sample());
    final container = await pumpScreen(tester);
    container.read(transactionsProvider.notifier).add(Transaction(expenseName: 'Em andamento', value: 10.0));

    await openSheetAndTap(tester, 'Abrir');

    expect(find.text('Abrir o acerto de Agosto/2026?'), findsOneWidget);

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    // Cancelling leaves the in-progress session exactly as it was.
    expect(container.read(transactionsProvider).single.expenseName, 'Em andamento');
    expect(container.read(transactionsProvider.notifier).openRecordId, isNull);
  });

  testWidgets('confirming the replacement then loads the saved acerto', (tester) async {
    store.seed(august(), sample());
    final container = await pumpScreen(tester);
    container.read(transactionsProvider.notifier).add(Transaction(expenseName: 'Em andamento', value: 10.0));

    await openSheetAndTap(tester, 'Abrir');
    await tester.tap(find.widgetWithText(FilledButton, 'Abrir'));
    await tester.pumpAndSettle();

    expect(container.read(transactionsProvider), hasLength(2));
    expect(container.read(transactionsProvider.notifier).openRecordId, 'august-2026');
  });

  testWidgets('deleting a record asks, then removes it from the list', (tester) async {
    store.seed(august(), sample());
    await pumpScreen(tester);

    await openSheetAndTap(tester, 'Excluir');

    expect(find.text('Excluir o acerto de Agosto/2026?'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Excluir'));
    await tester.pumpAndSettle();

    expect(find.text('Nenhum acerto salvo ainda'), findsOneWidget);
    expect(store.records, isEmpty);
  });

  testWidgets('shows a spinner while the saved acertos are still being read', (tester) async {
    final container = ProviderContainer(
      overrides: [
        acertosStoreProvider.overrideWithValue(store),
        acertoRecordsProvider.overrideWith((ref) => Completer<List<AcertoRecord>>().future),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const MaterialApp(home: AcertosScreen())),
    );
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('says so when the saved acertos cannot be read at all', (tester) async {
    final container = ProviderContainer(
      overrides: [
        acertosStoreProvider.overrideWithValue(store),
        acertoRecordsProvider.overrideWith((ref) => Future<List<AcertoRecord>>.error('disco ilegível')),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const MaterialApp(home: AcertosScreen())),
    );
    await tester.pumpAndSettle();

    expect(find.text('Não foi possível ler os acertos salvos'), findsOneWidget);
    expect(find.textContaining('disco ilegível'), findsOneWidget);
  });

  testWidgets('regenerating a PDF shares it under the acerto\'s own file name', (tester) async {
    final shared = <String>[];
    const channel = MethodChannel('net.nfet.printing');
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'sharePdf') shared.add((call.arguments as Map)['name'] as String);
      return 1;
    });
    addTearDown(() => binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null));

    store.seed(august(), sample());
    await pumpScreen(tester);

    await openSheetAndTap(tester, 'Gerar PDF novamente');

    expect(shared.single, 'Acerto_Agosto_2026.pdf');
  });

  testWidgets('cancelling the delete keeps the acerto', (tester) async {
    store.seed(august(), sample());
    await pumpScreen(tester);

    await openSheetAndTap(tester, 'Excluir');
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(find.text('Agosto/2026'), findsOneWidget);
    expect(store.records, hasLength(1));
  });
}
