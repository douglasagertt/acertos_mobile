import 'pdf_reader.dart';
import 'pdf_text_extractor.dart';

/// Orchestrates extraction + parsing, converting any extraction failure
/// (corrupt/unreadable file) into a warning instead of letting it throw —
/// mirrors the try/except wrapping the whole read in `read_pdf()` in
/// acertos/src/core/pdf_reader.py.
Future<ParsedInvoice> importInvoicePdf(String filePath) async {
  try {
    final lines = await extractInvoiceLines(filePath);
    return parseInvoiceLines(lines);
  } catch (e) {
    return ParsedInvoice(transactions: const [], warnings: ['Erro ao ler PDF: $e'], invoiceTotal: null);
  }
}
