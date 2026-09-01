import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdfrx/pdfrx.dart';

import 'core/navigation/app_shell.dart';
import 'core/theme/app_theme.dart';
import 'features/history/acertos_store.dart';
import 'features/history/providers/acertos_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await pdfrxFlutterInitialize();

  // Restore the working session before the first frame: the list is then
  // simply the app's initial state, with no loading spinner and no
  // empty-then-populated flash. The documents directory is per-app and
  // private on both iOS and Android.
  AcertosStore? store;
  var session = const SessionSnapshot();
  try {
    final documents = await getApplicationDocumentsDirectory();
    store = AcertosStore(Directory('${documents.path}/acertos'));
    session = await store.loadSession();
  } catch (e) {
    // Storage unavailable: the app still runs, in-memory only, and says so
    // rather than pretending the work is being saved.
    session = SessionSnapshot(warnings: ['Não foi possível acessar o armazenamento do app: $e']);
  }

  runApp(
    ProviderScope(
      overrides: [
        acertosStoreProvider.overrideWithValue(store),
        restoredSessionProvider.overrideWithValue(session),
      ],
      child: const AcertosApp(),
    ),
  );
}

class AcertosApp extends StatelessWidget {
  const AcertosApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Acertos',
      theme: AppTheme.light(),
      home: const AppShell(),
    );
  }
}
