import 'package:acertos_mobile/features/invoice_import/import_invoice.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('an unreadable file comes back as a warning, not an exception', () async {
    // The importer's contract: whatever goes wrong reading a PDF (missing
    // file, corrupt bytes, pdfium unavailable) reaches the UI as a warning it
    // can show, never as a crash. Mirrors the try/except around read_pdf().
    final parsed = await importInvoicePdf('/caminho/que/nao/existe/fatura.pdf');

    expect(parsed.transactions, isEmpty);
    expect(parsed.warnings, hasLength(1));
    expect(parsed.warnings.single, startsWith('Erro ao ler PDF:'));
    expect(parsed.invoiceTotal, isNull);
  });
}
