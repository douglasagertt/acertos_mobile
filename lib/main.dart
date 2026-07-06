import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'features/transactions/presentation/transaction_list_screen.dart';

void main() {
  runApp(const ProviderScope(child: AcertosApp()));
}

class AcertosApp extends StatelessWidget {
  const AcertosApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Acertos',
      theme: AppTheme.light(),
      home: const TransactionListScreen(),
    );
  }
}
