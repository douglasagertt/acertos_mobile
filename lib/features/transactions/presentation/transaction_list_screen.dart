import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/models/owner.dart';
import '../../../shared/widgets/owner_pill.dart';
import '../../invoice_import/import_invoice.dart';
import '../../pdf_export/generate_and_share_flow.dart';
import '../../settlement/totals_provider.dart';
import '../providers/transactions_provider.dart';
import 'add_expense_dialog.dart';
import 'widgets/transaction_row_card.dart';

/// Mirrors the transaction table + toolbar area of acertos/web/src/App.tsx
/// and TransactionTable.tsx, as a mobile-appropriate card list instead of a
/// 12-column table. Restyled 2026-07-07 per a UI mockup: side-by-side
/// primary actions and pill-based owner editing inside each row (see
/// TransactionRowCard). The totals summary lives on the dedicated "Resumo"
/// tab (see ResumoScreen) instead of a floating card overlaid on this list.
class TransactionListScreen extends ConsumerStatefulWidget {
  const TransactionListScreen({super.key});

  @override
  ConsumerState<TransactionListScreen> createState() => _TransactionListScreenState();
}

class _TransactionListScreenState extends ConsumerState<TransactionListScreen> {
  bool _importing = false;
  bool _generatingPdf = false;

  /// Null means "Todas" (no filter). Purely a display filter — reordering,
  /// totals and "Gerar PDF" always operate on the full, unfiltered list.
  Owner? _filter;

  @override
  Widget build(BuildContext context) {
    final transactions = ref.watch(transactionsProvider);
    final notifier = ref.read(transactionsProvider.notifier);
    final visibleTransactions = _filter == null
        ? transactions
        : transactions.where((t) => t.owner == _filter).toList();

    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.lavender,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          onPressed: _importing ? null : _handleImportPdf,
                          icon: _importing
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.upload_file, size: 18),
                          label: const Text('Importar Fatura'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.salvia,
                            side: const BorderSide(color: AppColors.salvia, width: 2),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          onPressed: () async {
                            final added = await showAddExpenseDialog(context);
                            if (added != null) notifier.add(added);
                          },
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Despesa'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.salvia,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: transactions.isEmpty || _generatingPdf
                        ? null
                        : () => generateAndShareSettlementPdf(
                            context: context,
                            transactions: ref.read(transactionsProvider),
                            totals: ref.read(totalsProvider),
                            onLoadingChanged: (loading) => setState(() => _generatingPdf = loading),
                          ),
                    icon: _generatingPdf
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.picture_as_pdf_outlined, size: 18),
                    label: const Text('Gerar PDF'),
                  ),
                  if (transactions.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Expanded(
                          child: Text(
                            'Transações',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w600,
                              color: AppColors.onSurface,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () => _confirmClear(context, notifier),
                          style: TextButton.styleFrom(foregroundColor: AppColors.outline),
                          icon: const Icon(Icons.delete_sweep_outlined, size: 16),
                          label: const Text('Limpar'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      key: const Key('ownerFilterRow'),
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final owner in Owner.values)
                          OwnerPill(
                            owner: owner,
                            label: owner == Owner.ignorar ? 'Ignorados' : null,
                            active: _filter == owner,
                            onTap: () => setState(() => _filter = owner),
                          ),
                        _AllPill(active: _filter == null, onTap: () => setState(() => _filter = null)),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            Expanded(
              child: transactions.isEmpty
                  ? const _EmptyState()
                  : visibleTransactions.isEmpty
                  ? const _EmptyFilterState()
                  : _filter == null
                  ? ReorderableListView.builder(
                      buildDefaultDragHandles: false,
                      padding: const EdgeInsets.fromLTRB(0, 8, 0, 16),
                      itemCount: visibleTransactions.length,
                      onReorderItem: notifier.reorder,
                      itemBuilder: (context, index) {
                        final t = visibleTransactions[index];
                        return TransactionRowCard(
                          key: ValueKey(t.id),
                          transaction: t,
                          index: index,
                          onUpdate: notifier.update,
                          onDelete: notifier.remove,
                        );
                      },
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(0, 8, 0, 16),
                      itemCount: visibleTransactions.length,
                      itemBuilder: (context, index) {
                        final t = visibleTransactions[index];
                        return TransactionRowCard(
                          key: ValueKey(t.id),
                          transaction: t,
                          index: null,
                          onUpdate: notifier.update,
                          onDelete: notifier.remove,
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleImportPdf() async {
    final picked = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['pdf']);
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
              color: AppColors.primaryContainer.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(16),
            ),
            alignment: Alignment.center,
            child: const Text('📄', style: TextStyle(fontSize: 24)),
          ),
          const SizedBox(height: 12),
          const Text('Nenhuma transação', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.onSurface)),
          const SizedBox(height: 4),
          const Text(
            'Importe uma fatura PDF ou adicione uma despesa',
            style: TextStyle(fontSize: 12, color: AppColors.outline),
          ),
        ],
      ),
    );
  }
}

/// The "Todas" filter chip — same visual language as [OwnerPill], but not
/// tied to an [Owner] since it means "no filter".
class _AllPill extends StatelessWidget {
  const _AllPill({required this.active, required this.onTap});

  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg) = active
        ? (AppColors.primary, Colors.white)
        : (AppColors.surfaceVariant, AppColors.onSurfaceVariant);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
        child: Text('Todas', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: fg)),
      ),
    );
  }
}

class _EmptyFilterState extends StatelessWidget {
  const _EmptyFilterState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('Nenhuma transação para esse filtro', style: TextStyle(fontSize: 13, color: AppColors.outline)),
    );
  }
}
