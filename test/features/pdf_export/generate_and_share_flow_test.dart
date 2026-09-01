// Covers "Salvar e gerar PDF" end to end: validation, the month/year sheet,
// the overwrite prompt, recording the acerto, sharing it, and what the user
// sees when any of that fails.
import 'package:acertos_mobile/features/history/acertos_store.dart';
import 'package:acertos_mobile/features/history/providers/acertos_providers.dart';
import 'package:acertos_mobile/features/pdf_export/generate_and_share_flow.dart';
import 'package:acertos_mobile/features/transactions/providers/transactions_provider.dart';
import 'package:acertos_mobile/shared/models/owner.dart';
import 'package:acertos_mobile/shared/models/transaction.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_acertos_store.dart';

void main() {
  late FakeAcertosStore store;
  late List<String> sharedFilenames;
  late bool sharingFails;

  final now = DateTime.now();

  setUp(() {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    binding.platformDispatcher.views.first.physicalSize = const Size(400, 850);
    binding.platformDispatcher.views.first.devicePixelRatio = 1.0;
    addTearDown(binding.platformDispatcher.views.first.resetPhysicalSize);
    addTearDown(binding.platformDispatcher.views.first.resetDevicePixelRatio);

    store = FakeAcertosStore();
    sharedFilenames = [];
    sharingFails = false;

    // Stand in for the native share sheet, which no test can open.
    const channel = MethodChannel('net.nfet.printing');
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method != 'sharePdf') return null;
      if (sharingFails) throw PlatformException(code: 'share_failed', message: 'sem app de compartilhamento');
      sharedFilenames.add((call.arguments as Map)['name'] as String);
      return 1;
    });
    addTearDown(() => binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null));
  });

  Future<ProviderContainer> pumpFlow(
    WidgetTester tester,
    List<Transaction> transactions, {
    AcertoRecord? shareRecord,
  }) async {
    final container = ProviderContainer(overrides: [acertosStoreProvider.overrideWithValue(store)]);
    addTearDown(container.dispose);
    container.read(transactionsProvider.notifier).replaceAll(transactions);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(home: _CloseAcertoScreen(shareRecord: shareRecord)),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  Future<void> tapClose(WidgetTester tester) async {
    await tester.tap(find.text('Salvar e gerar PDF'));
    await tester.pumpAndSettle();
  }

  List<Transaction> validExpenses() => [
    Transaction(expenseName: 'Mercado', value: 135.85, owner: Owner.bruna),
    Transaction(expenseName: 'Farmácia', value: 56.26, owner: Owner.douglas),
  ];

  AcertoRecord thisMonthSaved({String id = 'outro-registro'}) => AcertoRecord(
    id: id,
    month: now.month,
    year: now.year,
    monthName: 'Mês ${now.month}',
    createdAt: '2026-09-01T21:04:00.000',
    updatedAt: '2026-09-01T21:04:00.000',
    transactionCount: 9,
    grandTotal: 100,
    douglasToPay: 50,
  );

  group('validation', () {
    testWidgets('refuses an empty list, without opening the sheet', (tester) async {
      await pumpFlow(tester, []);

      await tapClose(tester);

      expect(find.textContaining('Adicione pelo menos uma despesa válida'), findsOneWidget);
      expect(find.text('Fechar o acerto'), findsNothing);
      expect(store.saveRecordCalls, 0);
    });

    testWidgets('refuses a list where everything is ignored or worthless', (tester) async {
      await pumpFlow(tester, [
        Transaction(expenseName: 'Pagamento', value: -14032.90, owner: Owner.ignorar),
        Transaction(expenseName: 'Sem valor', value: 0, owner: Owner.bruna),
      ]);

      await tapClose(tester);

      expect(find.textContaining('Adicione pelo menos uma despesa válida'), findsOneWidget);
      expect(store.saveRecordCalls, 0);
    });
  });

  group('closing the month', () {
    testWidgets('saves the acerto, shares the PDF and binds the session to it', (tester) async {
      final container = await pumpFlow(tester, validExpenses());

      await tapClose(tester);
      expect(find.text('Fechar o acerto'), findsOneWidget);

      await tester.tap(find.text('Salvar e compartilhar'));
      await tester.pumpAndSettle();

      expect(store.saveRecordCalls, 1);
      expect(store.records.single.month, now.month);
      expect(store.records.single.transactionCount, 2);
      expect(store.transactionsById[store.records.single.id], hasLength(2));
      expect(container.read(transactionsProvider.notifier).openRecordId, store.records.single.id);
      expect(sharedFilenames.single, endsWith('_${now.year}.pdf'));
      expect(find.text('CARREGANDO'), findsNothing);
    });

    testWidgets('cancelling the sheet saves nothing and shares nothing', (tester) async {
      await pumpFlow(tester, validExpenses());

      await tapClose(tester);
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(store.saveRecordCalls, 0);
      expect(sharedFilenames, isEmpty);
      expect(find.text('CARREGANDO'), findsNothing);
    });
  });

  group('overwriting a month that is already saved', () {
    testWidgets('asks first, and cancelling leaves the saved acerto alone', (tester) async {
      store.seed(thisMonthSaved(), []);
      await pumpFlow(tester, validExpenses());

      await tapClose(tester);
      await tester.tap(find.text('Salvar e compartilhar'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Já existe o acerto'), findsOneWidget);

      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(store.saveRecordCalls, 0);
      expect(store.records.single.transactionCount, 9); // untouched
      expect(sharedFilenames, isEmpty);
    });

    testWidgets('confirming replaces it', (tester) async {
      store.seed(thisMonthSaved(), []);
      await pumpFlow(tester, validExpenses());

      await tapClose(tester);
      await tester.tap(find.text('Salvar e compartilhar'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Substituir'));
      await tester.pumpAndSettle();

      expect(store.saveRecordCalls, 1);
      expect(store.records.single.transactionCount, 2);
    });

    testWidgets('does not ask when the saved acerto is the one already open', (tester) async {
      store.seed(thisMonthSaved(id: 'aberto'), []);
      final container = await pumpFlow(tester, validExpenses());
      container.read(transactionsProvider.notifier).openRecord('aberto', validExpenses());

      await tapClose(tester);
      await tester.tap(find.text('Salvar e compartilhar'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Já existe o acerto'), findsNothing);
      expect(store.saveRecordCalls, 1);
    });
  });

  group('when something goes wrong', () {
    // Regression: a failure here used to leave the button spinning forever
    // with nothing on screen to say the acerto had not been closed.
    testWidgets('a failing save reports it and gives the button back', (tester) async {
      await pumpFlow(tester, validExpenses());
      store.failWith = Exception('disco cheio');

      await tapClose(tester);
      await tester.tap(find.text('Salvar e compartilhar'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Não foi possível fechar o acerto'), findsOneWidget);
      expect(find.text('CARREGANDO'), findsNothing);
      expect(sharedFilenames, isEmpty);
    });

    testWidgets('a failing share says the acerto was still saved', (tester) async {
      await pumpFlow(tester, validExpenses());
      sharingFails = true;

      await tapClose(tester);
      await tester.tap(find.text('Salvar e compartilhar'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Acerto salvo, mas não foi possível compartilhar'), findsOneWidget);
      expect(store.saveRecordCalls, 1);
      expect(find.text('CARREGANDO'), findsNothing);
    });
  });

  group('re-sharing a saved acerto', () {
    testWidgets('regenerates the PDF from the stored transactions', (tester) async {
      final record = thisMonthSaved();
      store.seed(record, validExpenses());
      await pumpFlow(tester, [], shareRecord: record);

      await tester.tap(find.text('Compartilhar salvo'));
      await tester.pumpAndSettle();

      expect(sharedFilenames.single, record.pdfFilename);
    });

    testWidgets('says so when the stored acerto has no transactions left', (tester) async {
      final record = thisMonthSaved();
      store.seed(record, []);
      await pumpFlow(tester, [], shareRecord: record);

      await tester.tap(find.text('Compartilhar salvo'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Não foi possível ler o acerto'), findsOneWidget);
      expect(sharedFilenames, isEmpty);
    });

    testWidgets('reports a failure instead of throwing into the void', (tester) async {
      final record = thisMonthSaved();
      store.seed(record, validExpenses());
      await pumpFlow(tester, [], shareRecord: record);
      store.failWith = Exception('arquivo ilegível');

      await tester.tap(find.text('Compartilhar salvo'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Não foi possível gerar o PDF'), findsOneWidget);
    });
  });
}

/// Minimal host for the flow: one button that closes the month, one that
/// re-shares the first saved acerto, and a marker for the loading state.
class _CloseAcertoScreen extends ConsumerStatefulWidget {
  const _CloseAcertoScreen({this.shareRecord});

  final AcertoRecord? shareRecord;

  @override
  ConsumerState<_CloseAcertoScreen> createState() => _CloseAcertoScreenState();
}

class _CloseAcertoScreenState extends ConsumerState<_CloseAcertoScreen> {
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_loading) const Text('CARREGANDO'),
            ElevatedButton(
              onPressed: () => generateAndShareSettlementPdf(
                context: context,
                ref: ref,
                onLoadingChanged: (loading) => setState(() => _loading = loading),
              ),
              child: const Text('Salvar e gerar PDF'),
            ),
            if (widget.shareRecord != null)
              ElevatedButton(
                onPressed: () => shareRecordPdf(context: context, ref: ref, record: widget.shareRecord!),
                child: const Text('Compartilhar salvo'),
              ),
          ],
        ),
      ),
    );
  }
}
