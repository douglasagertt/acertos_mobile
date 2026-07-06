import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../providers/transactions_provider.dart';
import 'add_expense_dialog.dart';
import 'widgets/transaction_row_card.dart';

/// Mirrors the transaction table + toolbar area of acertos/web/src/App.tsx
/// and TransactionTable.tsx, as a mobile-appropriate card list instead of a
/// 12-column table.
class TransactionListScreen extends ConsumerWidget {
  const TransactionListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactions = ref.watch(transactionsProvider);
    final notifier = ref.read(transactionsProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Acertos'),
        centerTitle: false,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: Row(
              children: [
                FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: AppColors.lavender600),
                  onPressed: () async {
                    final added = await showAddExpenseDialog(context);
                    if (added != null) notifier.add(added);
                  },
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Despesa'),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: transactions.isEmpty ? null : () => _confirmClear(context, notifier),
                  icon: const Icon(Icons.delete_sweep_outlined, size: 16),
                  label: const Text('Limpar'),
                ),
              ],
            ),
          ),
          Expanded(
            child: transactions.isEmpty
                ? const _EmptyState()
                : ReorderableListView.builder(
                    buildDefaultDragHandles: false,
                    padding: const EdgeInsets.only(bottom: 12),
                    itemCount: transactions.length,
                    onReorderItem: notifier.reorder,
                    itemBuilder: (context, index) {
                      final t = transactions[index];
                      return TransactionRowCard(
                        key: ValueKey(t.id),
                        transaction: t,
                        index: index,
                        onUpdate: notifier.update,
                        onDelete: notifier.remove,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmClear(BuildContext context, TransactionsNotifier notifier) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remover todas as transações?'),
        content: const Text('Essa ação não pode ser desfeita.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Remover')),
        ],
      ),
    );
    if (confirmed == true) notifier.clear();
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: const Color(0xFFE8E3FF),
              borderRadius: BorderRadius.circular(16),
            ),
            alignment: Alignment.center,
            child: const Text('📄', style: TextStyle(fontSize: 24)),
          ),
          const SizedBox(height: 12),
          const Text('Nenhuma transação', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          const Text(
            'Importe uma fatura PDF ou adicione uma despesa',
            style: TextStyle(fontSize: 12, color: AppColors.charcoal400),
          ),
        ],
      ),
    );
  }
}
