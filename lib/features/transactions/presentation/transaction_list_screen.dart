import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../invoice_import/import_invoice.dart';
import '../../settlement/presentation/summary_panel.dart';
import '../../settlement/totals_provider.dart';
import '../providers/transactions_provider.dart';
import 'add_expense_dialog.dart';
import 'widgets/transaction_row_card.dart';

/// Mirrors the transaction table + toolbar area of acertos/web/src/App.tsx
/// and TransactionTable.tsx, as a mobile-appropriate card list instead of a
/// 12-column table.
class TransactionListScreen extends ConsumerStatefulWidget {
  const TransactionListScreen({super.key});

  @override
  ConsumerState<TransactionListScreen> createState() => _TransactionListScreenState();
}

class _TransactionListScreenState extends ConsumerState<TransactionListScreen> {
  bool _importing = false;

  @override
  Widget build(BuildContext context) {
    final transactions = ref.watch(transactionsProvider);
    final notifier = ref.read(transactionsProvider.notifier);
    final totals = ref.watch(totalsProvider);

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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.icon(
                        style: FilledButton.styleFrom(backgroundColor: AppColors.lavender600),
                        onPressed: _importing ? null : _handleImportPdf,
                        icon: _importing
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.upload_file, size: 16),
                        label: const Text('Importar PDF'),
                      ),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.lavender600,
                          side: const BorderSide(color: AppColors.lavender600),
                        ),
                        onPressed: () async {
                          final added = await showAddExpenseDialog(context);
                          if (added != null) notifier.add(added);
                        },
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Despesa'),
                      ),
                    ],
                  ),
                ),
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
          SummaryPanel(totals: totals),
        ],
      ),
    );
  }

  Future<void> _handleImportPdf() async {
    final picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    final filePath = picked?.files.single.path;
    if (filePath == null) return;

    setState(() => _importing = true);
    final parsed = await importInvoicePdf(filePath);
    if (!mounted) return;
    setState(() => _importing = false);

    if (parsed.transactions.isEmpty) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Erro ao importar PDF'),
          content: Text(parsed.warnings.join('\n')),
          actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK'))],
        ),
      );
      return;
    }

    final notifier = ref.read(transactionsProvider.notifier);
    final existing = ref.read(transactionsProvider);

    if (existing.isNotEmpty) {
      final replace = await _confirmReplaceOrAppend(existing.length);
      if (!mounted || replace == null) return;
      notifier.replaceAll(replace ? parsed.transactions : [...existing, ...parsed.transactions]);
    } else {
      notifier.replaceAll(parsed.transactions);
    }

    if (!mounted) return;

    if (parsed.warnings.isNotEmpty) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('PDF importado com avisos'),
          content: Text(parsed.warnings.join('\n')),
          actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK'))],
        ),
      );
      if (!mounted) return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('${parsed.transactions.length} transações importadas')));
  }

  Future<bool?> _confirmReplaceOrAppend(int existingCount) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Já existem $existingCount transações'),
        content: const Text('Substituir pelos dados do novo PDF ou adicionar às existentes?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Adicionar')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Substituir')),
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
