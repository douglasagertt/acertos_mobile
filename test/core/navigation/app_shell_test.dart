import 'package:acertos_mobile/core/navigation/app_shell.dart';
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

  testWidgets('starts on Home and switches to Resumo without losing Home state', (tester) async {
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
  });
}
