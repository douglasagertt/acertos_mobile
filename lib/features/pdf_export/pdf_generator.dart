import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/constants/months_pt.dart';
import '../../shared/models/owner.dart';
import '../../shared/models/totals.dart';
import '../../shared/models/transaction.dart';
import '../../shared/utils/money.dart';

/// Direct port of `generate_pdf()` in acertos/src/core/pdf_generator.py.
Future<Uint8List> generateSettlementPdf({
  required List<Transaction> transactions,
  required Totals totals,
  required int month,
  required int year,
}) async {
  final doc = pw.Document();

  const rowColors = {
    Owner.bruna: PdfColor.fromInt(0xFFFFE4ED),
    Owner.douglas: PdfColor.fromInt(0xFFD6EAFF),
    Owner.compartilhado: PdfColor.fromInt(0xFFD6F5E3),
    Owner.ignorar: PdfColor.fromInt(0xFFEEEEEE),
  };
  const border = PdfColor.fromInt(0xFFDEE2E6);
  const sectionBlue = PdfColor.fromInt(0xFF1565C0);
  const subGrey = PdfColor.fromInt(0xFF546E7A);

  final tableData = <List<String>>[
    for (final t in transactions)
      [
        t.datetime,
        t.city,
        t.purchaseType,
        t.expenseName.isNotEmpty ? t.expenseName : t.originalDescription,
        t.installment,
        (t.shared || t.owner == Owner.compartilhado)
            ? '${formatMoney(t.value)} (÷2 = ${formatMoney(t.value / 2)})'
            : formatMoney(t.value),
        (t.shared || t.owner == Owner.compartilhado) ? 'Compartilhado' : t.owner.label,
        t.obs,
      ],
  ];

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape.copyWith(
        marginLeft: 12 * PdfPageFormat.mm,
        marginRight: 12 * PdfPageFormat.mm,
        marginTop: 15 * PdfPageFormat.mm,
        marginBottom: 15 * PdfPageFormat.mm,
      ),
      build: (context) => [
        // Plain hyphen, not an em-dash: the base Helvetica font used here
        // only supports Latin-1/WinAnsi (covers Portuguese accents fine,
        // but not "—" U+2014 — confirmed by a real "no Unicode support"
        // warning when this was an em-dash).
        pw.Text('Acerto - ${monthsPt[month]}/$year', style: const pw.TextStyle(fontSize: 16)),
        pw.SizedBox(height: 2),
        pw.Text('Gerado automaticamente pelo Acertos', style: const pw.TextStyle(fontSize: 10, color: subGrey)),
        pw.SizedBox(height: 4),
        pw.Divider(color: border, thickness: 1),
        pw.SizedBox(height: 12),
        pw.Text('Despesas', style: const pw.TextStyle(fontSize: 11, color: sectionBlue)),
        pw.SizedBox(height: 4),
        pw.TableHelper.fromTextArray(
          context: context,
          headers: const ['Data/hora', 'Cidade', 'Compra', 'Despesa', 'Parcela', 'Valor', 'Responsável', 'Obs'],
          data: tableData,
          cellStyle: const pw.TextStyle(fontSize: 8),
          headerStyle: const pw.TextStyle(fontSize: 8, color: PdfColor.fromInt(0xFF212529)),
          headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFECEFF1)),
          cellAlignments: const {5: pw.Alignment.centerRight},
          cellPadding: const pw.EdgeInsets.all(4),
          border: pw.TableBorder.all(color: border, width: 0.4),
          columnWidths: const {
            0: pw.FixedColumnWidth(55),
            1: pw.FixedColumnWidth(60),
            2: pw.FixedColumnWidth(55),
            3: pw.FlexColumnWidth(130),
            4: pw.FixedColumnWidth(38),
            5: pw.FixedColumnWidth(55),
            6: pw.FixedColumnWidth(70),
            7: pw.FixedColumnWidth(100),
          },
          cellDecoration: (index, data, rowNum) {
            if (rowNum == 0) return const pw.BoxDecoration();
            final t = transactions[rowNum - 1];
            final owner = t.shared ? Owner.compartilhado : t.owner;
            return pw.BoxDecoration(color: rowColors[owner]);
          },
        ),
        pw.SizedBox(height: 16),
        pw.Divider(color: border, thickness: 1),
        pw.SizedBox(height: 8),
        pw.Text('Resumo dos Totais', style: const pw.TextStyle(fontSize: 11, color: sectionBlue)),
        pw.SizedBox(height: 4),
        _summaryTable(totals, rowColors, border),
        pw.SizedBox(height: 8),
        _highlightBox(totals),
      ],
    ),
  );

  return doc.save();
}

pw.Widget _summaryTable(Totals totals, Map<Owner, PdfColor> rowColors, PdfColor border) {
  final rows = [
    ('Total Bruna', totals.bruna, rowColors[Owner.bruna]!),
    ('Total Douglas', totals.douglas, rowColors[Owner.douglas]!),
    ('Total Compartilhado', totals.sharedTotal, rowColors[Owner.compartilhado]!),
    ('Metade do Compartilhado', totals.sharedHalf, rowColors[Owner.compartilhado]!),
    ('Total Ignorado', totals.ignored, rowColors[Owner.ignorar]!),
  ];

  return pw.Table(
    columnWidths: const {0: pw.FixedColumnWidth(160), 1: pw.FixedColumnWidth(100)},
    border: pw.TableBorder.all(color: border, width: 0.4),
    children: [
      for (final (label, value, bg) in rows)
        pw.TableRow(
          decoration: pw.BoxDecoration(color: bg),
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Text(label, style: const pw.TextStyle(fontSize: 10)),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Text(formatMoney(value), textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 10)),
            ),
          ],
        ),
    ],
  );
}

pw.Widget _highlightBox(Totals totals) {
  return pw.Container(
    width: 260,
    padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: pw.BoxDecoration(
      color: const PdfColor.fromInt(0xFFD32F2F),
      borderRadius: pw.BorderRadius.circular(4),
    ),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          'Douglas deve pagar à Bruna',
          style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
        ),
        pw.Text(
          formatMoney(totals.douglasToPay),
          style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
        ),
      ],
    ),
  );
}
