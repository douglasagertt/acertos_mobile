import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/history/presentation/acertos_screen.dart';
import '../../features/history/providers/acertos_providers.dart';
import '../../features/settlement/presentation/resumo_screen.dart';
import '../../features/transactions/presentation/transaction_list_screen.dart';
import '../../features/transactions/providers/transactions_provider.dart';
import '../theme/app_theme.dart';

/// Which tab the shell is showing. A provider rather than plain State because
/// the Acertos tab switches back to Home after opening a saved acerto.
class SelectedTabNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void select(int index) => state = index;
}

final selectedTabProvider = NotifierProvider<SelectedTabNotifier, int>(SelectedTabNotifier.new);

/// Bottom-tab shell: Home (the transaction list), Resumo (the settlement
/// summary) and Acertos (the saved months). Each tab keeps its own
/// Scaffold/AppBar; this shell only owns the NavigationBar and an IndexedStack
/// so switching tabs doesn't rebuild/lose state (list scroll position,
/// in-progress dialogs) in the others.
///
/// No routing package involved on purpose — flat, always-visible tabs don't
/// need go_router's deep-linking/nested-route machinery. Revisit if a screen
/// ever needs to push its own sub-navigation.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  late final AppLifecycleListener _lifecycle;

  static const _screens = [TransactionListScreen(), ResumoScreen(), AcertosScreen()];

  @override
  void initState() {
    super.initState();

    // The session autosaves on a short debounce; this makes sure the last edit
    // is on disk before the app goes to the background, since both iOS and
    // Android may kill the process from there without running anything else.
    _lifecycle = AppLifecycleListener(onPause: () => ref.read(transactionsProvider.notifier).flushSave());

    final warnings = ref.read(restoredSessionProvider).warnings;
    if (warnings.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(warnings.join('\n')), duration: const Duration(seconds: 8)),
        );
      });
    }
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final index = ref.watch(selectedTabProvider);

    return Scaffold(
      body: IndexedStack(index: index, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: ref.read(selectedTabProvider.notifier).select,
        backgroundColor: AppColors.surfaceContainerLowest,
        indicatorColor: AppColors.primaryContainer.withValues(alpha: 0.25),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.balance_outlined), selectedIcon: Icon(Icons.balance), label: 'Resumo'),
          NavigationDestination(icon: Icon(Icons.history_outlined), selectedIcon: Icon(Icons.history), label: 'Acertos'),
        ],
      ),
    );
  }
}
