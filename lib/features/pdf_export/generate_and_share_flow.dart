import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../../core/constants/months_pt.dart';
import '../../shared/models/owner.dart';
import '../../shared/models/totals.dart';
import '../../shared/models/transaction.dart';
import 'pdf_generator.dart';
import 'presentation/save_pdf_dialog.dart';

/// The full "Gerar PDF" flow — validate, ask for month/year, generate,
/// share — shared between the Home screen's toolbar button and the Resumo
/// screen's action button so the logic (and the validation rule) lives in
/// exactly one place.
Future<void> generateAndShareSettlementPdf({
  required BuildContext context,
  required List<Transaction> transactions,
  required Totals totals,
  required ValueChanged<bool> onLoadingChanged,
}) async {
  final valid = transactions.where((t) => t.owner != Owner.ignorar && t.value > 0);
  if (valid.isEmpty) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Adicione pelo menos uma despesa válida antes de gerar o PDF.')));
    return;
  }

  final result = await showSavePdfDialog(context);
  if (result == null || !context.mounted) return;

  onLoadingChanged(true);
  final bytes = await generateSettlementPdf(
    transactions: transactions,
    totals: totals,
    month: result.month,
    year: result.year,
  );
  if (context.mounted) onLoadingChanged(false);

  final monthName = monthsPt[result.month];
  await Printing.sharePdf(bytes: bytes, filename: 'Acerto_${monthName}_${result.year}.pdf');
}
