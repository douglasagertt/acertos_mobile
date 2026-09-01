import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/navigation/app_shell.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/transaction.dart';
import '../../../shared/utils/money.dart';
import '../../pdf_export/generate_and_share_flow.dart';
import '../../transactions/providers/transactions_provider.dart';
import '../acertos_store.dart';
import '../providers/acertos_providers.dart';

/// The months already closed. An acerto lands here when "Salvar e gerar PDF"
/// succeeds; from here it can be reopened for editing, re-shared as a PDF, or
/// deleted.
class AcertosScreen extends ConsumerWidget {
  const AcertosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final records = ref.watch(acertoRecordsProvider);

    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Acertos salvos',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: AppColors.onSurface),
              ),
              const SizedBox(height: 4),
              const Text(
                'Cada mês fechado fica guardado aqui, com os lançamentos como estavam.',
                style: TextStyle(fontSize: 13, color: AppColors.onSurfaceVariant),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: records.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (error, _) => _Message(
                    icon: Icons.error_outline,
                    title: 'Não foi possível ler os acertos salvos',
                    subtitle: '$error',
                  ),
                  data: (list) => list.isEmpty
                      ? const _Message(
                          icon: Icons.inbox_outlined,
                          title: 'Nenhum acerto salvo ainda',
                          subtitle: 'Feche um mês com "Salvar e gerar PDF" para ele aparecer aqui.',
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.only(bottom: 24),
                          itemCount: list.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 12),
                          itemBuilder: (context, i) => _RecordCard(
                            record: list[i],
                            onTap: () => _showActions(context, ref, list[i]),
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showActions(BuildContext context, WidgetRef ref, AcertoRecord record) async {
    final action = await showModalBottomSheet<_RecordAction>(
      context: context,
      showDragHandle: true,
      backgroundColor: AppColors.brandCard,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (context) => SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      record.title,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.onSurface),
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.folder_open_outlined, color: AppColors.lavender),
              title: const Text('Abrir'),
              subtitle: const Text('Carrega os lançamentos na aba Home'),
              onTap: () => Navigator.of(context).pop(_RecordAction.open),
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf_outlined, color: AppColors.salvia),
              title: const Text('Gerar PDF novamente'),
              subtitle: const Text('Refaz o PDF a partir dos lançamentos salvos'),
              onTap: () => Navigator.of(context).pop(_RecordAction.share),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: AppColors.error),
              title: const Text('Excluir'),
              onTap: () => Navigator.of(context).pop(_RecordAction.delete),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (action == null || !context.mounted) return;

    switch (action) {
      case _RecordAction.open:
        await _open(context, ref, record);
      case _RecordAction.share:
        await shareRecordPdf(context: context, ref: ref, record: record);
      case _RecordAction.delete:
        await _delete(context, ref, record);
    }
  }

  Future<void> _open(BuildContext context, WidgetRef ref, AcertoRecord record) async {
    final notifier = ref.read(transactionsProvider.notifier);
    final current = ref.read(transactionsProvider);

    // Opening replaces what's on screen, and the session is the only working
    // copy — so ask first whenever there is unsaved work that isn't already
    // this acerto.
    if (current.isNotEmpty && notifier.openRecordId != record.id) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Abrir o acerto de ${record.title}?'),
          content: Text(
            'Os ${current.length} lançamentos que estão na tela serão substituídos. '
            'Feche o mês atual antes se ainda quiser guardá-lo.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Abrir')),
          ],
        ),
      );
      if (confirmed != true || !context.mounted) return;
    }

    final store = ref.read(acertosStoreProvider);
    if (store == null) return;

    List<Transaction> transactions;
    try {
      transactions = await store.loadRecord(record.id);
    } catch (e) {
      transactions = const [];
    }
    if (!context.mounted) return;

    if (transactions.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Não foi possível ler o acerto de ${record.title}.')));
      return;
    }

    notifier.openRecord(record.id, transactions);
    ref.read(selectedTabProvider.notifier).select(0);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Acerto de ${record.title} aberto na Home.')));
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, AcertoRecord record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Excluir o acerto de ${record.title}?'),
        content: const Text('Os lançamentos salvos desse mês serão apagados. Essa ação não pode ser desfeita.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Excluir')),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref.read(acertosStoreProvider)?.deleteRecord(record.id);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Não foi possível excluir o acerto: $e')));
      }
    }
    ref.invalidate(acertoRecordsProvider);
  }
}

enum _RecordAction { open, share, delete }

class _RecordCard extends StatelessWidget {
  const _RecordCard({required this.record, required this.onTap});

  final AcertoRecord record;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.brandCard,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      record.title,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.onSurface),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: AppColors.outline),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'DOUGLAS DEVE PAGAR',
                style: TextStyle(fontSize: 10, letterSpacing: 0.8, color: AppColors.onSurfaceVariant),
              ),
              const SizedBox(height: 2),
              Text(
                formatMoney(record.douglasToPay),
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.salvia),
              ),
              const SizedBox(height: 10),
              Text(
                '${record.transactionCount} lançamentos · salvo em ${record.updatedAtLabel}',
                style: const TextStyle(fontSize: 12, color: AppColors.outline),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.title, required this.subtitle});

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44, color: AppColors.outlineVariant),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.onSurfaceVariant),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: AppColors.outline),
            ),
          ],
        ),
      ),
    );
  }
}
