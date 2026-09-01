import 'package:acertos_mobile/core/navigation/app_shell.dart';
import 'package:acertos_mobile/features/history/acertos_store.dart';
import 'package:acertos_mobile/features/history/providers/acertos_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    binding.platformDispatcher.views.first.physicalSize = const Size(400, 850);
    binding.platformDispatcher.views.first.devicePixelRatio = 1.0;
    addTearDown(binding.platformDispatcher.views.first.resetPhysicalSize);
    addTearDown(binding.platformDispatcher.views.first.resetDevicePixelRatio);
  });

  testWidgets('starts on Home and switches tabs without losing Home state', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: MaterialApp(home: AppShell())));

    // Home tab first: the transaction list's empty state is visible.
    expect(find.text('Nenhuma transação'), findsOneWidget);
    expect(find.text('Resumo do Acerto'), findsNothing);

    await tester.tap(find.text('Resumo'));
    await tester.pumpAndSettle();

    expect(find.text('Resumo do Acerto'), findsOneWidget);
    expect(find.text('Nenhuma transação'), findsNothing);

    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();

    // Back on Home: IndexedStack should have kept it mounted, not rebuilt.
    expect(find.text('Nenhuma transação'), findsOneWidget);

    await tester.tap(find.text('Acertos'));
    await tester.pumpAndSettle();

    expect(find.text('Acertos salvos'), findsOneWidget);
    expect(find.text('Nenhuma transação'), findsNothing);
  });

  testWidgets('surfaces a warning from the restored session instead of failing silently', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          restoredSessionProvider.overrideWithValue(
            const SessionSnapshot(warnings: ['Não foi possível ler a sessão em andamento.']),
          ),
        ],
        child: const MaterialApp(home: AppShell()),
      ),
    );
    await tester.pump(); // the warning is posted after the first frame

    expect(find.text('Não foi possível ler a sessão em andamento.'), findsOneWidget);
  });

  testWidgets('says nothing when the session was restored cleanly', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: MaterialApp(home: AppShell())));
    await tester.pump();

    expect(find.byType(SnackBar), findsNothing);
  });
}
