import 'package:pdfrx/pdfrx.dart';

/// Extracts every page's text as a flat list of lines, in reading order —
/// the same shape `pdfplumber`'s `page.extract_text().splitlines()` gives
/// `acertos/src/core/pdf_reader.py` (validated in the Phase 0 spike).
///
/// Requires pdfrx to already be initialized by the caller: the real app
/// calls `pdfrxFlutterInitialize()` once at startup; tests use the
/// lightweight Dart-only `pdfrxInitialize()` instead (see
/// `pdf_reader_fixture_test.dart`) since `pdfrxFlutterInitialize()` needs a
/// `path_provider` platform channel that isn't available under `flutter
/// test`.
Future<List<String>> extractInvoiceLines(String filePath) async {
  final document = await PdfDocument.openFile(filePath);
  try {
    final lines = <String>[];
    for (final page in document.pages) {
      final pageText = await page.loadText();
      lines.addAll((pageText?.fullText ?? '').split(RegExp(r'\r?\n')));
    }
    return lines;
  } finally {
    await document.dispose();
  }
}
