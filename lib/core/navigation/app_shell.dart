import 'package:flutter/material.dart';

import '../../features/settlement/presentation/resumo_screen.dart';
import '../../features/transactions/presentation/transaction_list_screen.dart';
import '../theme/app_theme.dart';

/// Bottom-tab shell added 2026-07-07: Home (the transaction list) and
/// Resumo (the settlement summary). Each tab keeps its own Scaffold/AppBar;
/// this shell only owns the NavigationBar and an IndexedStack so switching
/// tabs doesn't rebuild/lose state (list scroll position, in-progress
/// dialogs) in the other tab.
///
/// No routing package involved on purpose — two flat, always-visible tabs
/// don't need go_router's deep-linking/nested-route machinery. Revisit if a
/// third screen ever needs to push its own sub-navigation.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  static const _screens = [TransactionListScreen(), ResumoScreen()];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (index) => setState(() => _index = index),
        backgroundColor: AppColors.surfaceContainerLowest,
        indicatorColor: AppColors.primaryContainer.withValues(alpha: 0.25),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.balance_outlined), selectedIcon: Icon(Icons.balance), label: 'Resumo'),
        ],
      ),
    );
  }
}
