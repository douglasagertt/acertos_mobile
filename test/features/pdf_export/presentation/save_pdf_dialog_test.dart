import 'package:acertos_mobile/features/pdf_export/presentation/save_pdf_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late TestWidgetsFlutterBinding binding;

  setUp(() {
    binding = TestWidgetsFlutterBinding.ensureInitialized();
    binding.platformDispatcher.views.first.devicePixelRatio = 1.0;
    addTearDown(binding.platformDispatcher.views.first.resetPhysicalSize);
    addTearDown(binding.platformDispatcher.views.first.resetDevicePixelRatio);
  });

  void useWidth(double width) {
    binding.platformDispatcher.views.first.physicalSize = Size(width, 850);
  }

  Future<SavePdfResult?> openDialog(WidgetTester tester) async {
    SavePdfResult? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async => result = await showSavePdfDialog(context),
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    return result;
  }

  testWidgets('opens on the current month and year, and says the acerto will be saved', (tester) async {
    useWidth(400);
    await openDialog(tester);

    final now = DateTime.now();
    expect(find.text('Fechar o acerto'), findsOneWidget);
    expect(find.textContaining('fica salvo na aba Acertos'), findsOneWidget);
    expect(find.text(const {
      1: 'Janeiro', 2: 'Fevereiro', 3: 'Março', 4: 'Abril', 5: 'Maio', 6: 'Junho',
      7: 'Julho', 8: 'Agosto', 9: 'Setembro', 10: 'Outubro', 11: 'Novembro', 12: 'Dezembro',
    }[now.month]!), findsOneWidget);
    expect(find.widgetWithText(TextFormField, '${now.year}'), findsOneWidget);
  });

  testWidgets('returns the month and year that were picked', (tester) async {
    useWidth(400);
    await tester.runAsync(() async {});
    SavePdfResult? captured;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async => captured = await showSavePdfDialog(context),
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButtonFormField<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Março').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '2031');
    await tester.tap(find.text('Salvar e compartilhar'));
    await tester.pumpAndSettle();

    expect(captured?.month, 3);
    expect(captured?.year, 2031);
  });

  testWidgets('cancelling returns nothing', (tester) async {
    useWidth(400);
    SavePdfResult? captured = const SavePdfResult(1, 1);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async => captured = await showSavePdfDialog(context),
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(captured, isNull);
  });

  testWidgets('keeps the current year when the field is cleared', (tester) async {
    useWidth(400);
    SavePdfResult? captured;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async => captured = await showSavePdfDialog(context),
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '');
    await tester.tap(find.text('Salvar e compartilhar'));
    await tester.pumpAndSettle();

    expect(captured?.year, DateTime.now().year);
  });

  // Regression: the actions used to be a Row, which overflowed once the two
  // labels no longer fit side by side on a narrow screen.
  testWidgets('lays out its actions without overflowing on a narrow phone', (tester) async {
    useWidth(320);
    await openDialog(tester);

    expect(find.text('Cancelar'), findsOneWidget);
    expect(find.text('Salvar e compartilhar'), findsOneWidget);
  });
}
