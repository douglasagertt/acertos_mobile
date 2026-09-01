import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';

import '../../core/constants/months_pt.dart';
import '../../shared/models/owner.dart';
import '../history/acertos_store.dart';
import '../history/providers/acertos_providers.dart';
import '../settlement/calculate_totals.dart';
import '../settlement/totals_provider.dart';
import '../transactions/providers/transactions_provider.dart';
import 'pdf_generator.dart';
import 'presentation/save_pdf_dialog.dart';

/// Closing the month: validate, ask for month/year, generate the PDF, record
/// the acerto, share it. Shared between the Home screen's toolbar button and
/// the Resumo screen's action button so the rule and the wiring live in
/// exactly one place.
///
/// Generating a PDF *is* how an acerto gets closed here, so this is also the
/// only thing that writes to the Acertos list — there is no separate "save"
/// action beside it.
Future<void> generateAndShareSettlementPdf({
  required BuildContext context,
  required WidgetRef ref,
  required ValueChanged<bool> onLoadingChanged,
}) async {
  final transactions = ref.read(transactionsProvider);
  final totals = ref.read(totalsProvider);

  final valid = transactions.where((t) => t.owner != Owner.ignorar && t.value > 0);
  if (valid.isEmpty) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Adicione pelo menos uma despesa válida antes de gerar o PDF.')));
    return;
  }

  final result = await showSavePdfDialog(context);
  if (result == null || !context.mounted) return;

  final store = ref.read(acertosStoreProvider);
  final notifier = ref.read(transactionsProvider.notifier);

  if (store != null) {
    // Only ask when it would replace a *different* acerto: saving the month
    // you already have open is the normal way to update it.
    final AcertoRecord? existing;
    try {
      existing = await store.findRecord(result.month, result.year);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Não foi possível fechar o acerto: $e')));
      }
      return;
    }
    if (existing != null && existing.id != notifier.openRecordId) {
      if (!context.mounted) return;
      final overwrite = await _confirmOverwrite(context, existing);
      if (overwrite != true || !context.mounted) return;
    }
  }

  onLoadingChanged(true);
  final Uint8List bytes;
  try {
    bytes = await generateSettlementPdf(
      transactions: transactions,
      totals: totals,
      month: result.month,
      year: result.year,
    );

    // Recorded only once the PDF actually generated, so a failure there leaves
    // no half-closed acerto behind.
    if (store != null) {
      final record = await store.saveRecord(
        transactions: transactions,
        totals: totals,
        month: result.month,
        year: result.year,
      );
      notifier.markSavedAs(record.id);
      ref.invalidate(acertoRecordsProvider);
    }
  } catch (e) {
    // Without this the button would sit on its spinner forever and the user
    // would never learn the acerto wasn't closed.
    if (context.mounted) {
      onLoadingChanged(false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Não foi possível fechar o acerto: $e')));
    }
    return;
  }

  if (context.mounted) onLoadingChanged(false);

  final filename = 'Acerto_${monthNameOf(result.month)}_${result.year}.pdf';
  try {
    await Printing.sharePdf(bytes: bytes, filename: filename);
  } catch (e) {
    // The acerto is already saved at this point, so say exactly that: only
    // the sharing step failed, and it can be retried from the Acertos tab.
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Acerto salvo, mas não foi possível compartilhar o PDF: $e')),
      );
    }
  }
}

/// Regenerates a saved acerto's PDF from its stored transactions and hands it
/// to the share sheet. Nothing is kept on disk as a PDF: the transactions are
/// the source of truth, so there is no stale or missing file to deal with.
Future<void> shareRecordPdf({
  required BuildContext context,
  required WidgetRef ref,
  required AcertoRecord record,
}) async {
  final store = ref.read(acertosStoreProvider);
  if (store == null) return;

  try {
    final transactions = await store.loadRecord(record.id);
    if (transactions.isEmpty) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Não foi possível ler o acerto de ${record.title}.')));
      return;
    }

    final bytes = await generateSettlementPdf(
      transactions: transactions,
      totals: calculateTotals(transactions),
      month: record.month,
      year: record.year,
    );
    await Printing.sharePdf(bytes: bytes, filename: record.pdfFilename);
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Não foi possível gerar o PDF de ${record.title}: $e')));
    }
  }
}

Future<bool?> _confirmOverwrite(BuildContext context, AcertoRecord existing) {
  return showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Já existe o acerto de ${existing.title}'),
      content: Text(
        'Salvo em ${existing.updatedAtLabel} com ${existing.transactionCount} lançamentos. '
        'Substituir pelo que está na tela?',
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
        FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Substituir')),
      ],
    ),
  );
}
