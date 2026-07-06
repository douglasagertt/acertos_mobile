// Validates the full pdfrx extraction + parsing pipeline against the real
// Sicredi invoice fixture, cross-checked against a Python `pdf_reader.py` +
// `calculator.py` reference run (see the reference numbers below — captured
// 2026-07-06 via `uv run python3 -c "..."` in the acertos/ repo against the
// same fixture file). This is the strongest validation available: the real
// PDF, the real pdfrx extraction, the real parser — not a synthetic line
// fixture.
//
// pdfrx's native pdfium loading needs a real libpdfium shared library, which
// `flutter test` doesn't fetch automatically (unlike `flutter run`/`flutter
// build`, native-assets build hooks don't fire under the test runner as of
// Flutter 3.44 stable — see PLAN.md's "on-device PDF parsing" section).
//
// This test does NOT auto-download that binary — fetching and dynamically
// loading third-party native code should be a deliberate human decision, not
// something that happens silently on every `flutter test` run. To run this
// specific test, fetch pdfium yourself once and point PDFIUM_PATH at it
// (pdfrxInitialize() already reads that env var natively):
//
//   curl -fL -o /tmp/pdfium.tgz \
//     https://github.com/bblanchon/pdfium-binaries/releases/download/chromium%2F7811/pdfium-linux-x64.tgz
//   tar xzf /tmp/pdfium.tgz -C /tmp/pdfium
//   PDFIUM_PATH=/tmp/pdfium/lib/libpdfium.so flutter test test/features/invoice_import/pdf_reader_fixture_test.dart
//
// Without PDFIUM_PATH set, this test is skipped (not failed) so the normal
// `flutter test` gate stays green without needing this manual step.
import 'dart:io';

import 'package:acertos_mobile/features/invoice_import/pdf_reader.dart';
import 'package:acertos_mobile/features/invoice_import/pdf_text_extractor.dart';
import 'package:acertos_mobile/features/settlement/calculate_totals.dart';
import 'package:acertos_mobile/shared/models/owner.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdfrx/pdfrx.dart';

final _pdfiumPath = Platform.environment['PDFIUM_PATH'];

void main() {
  setUpAll(() async {
    if (_pdfiumPath != null) await pdfrxInitialize();
  });

  test(
    'parses the real Sicredi invoice fixture matching the Python reference',
    () async {
      final lines = await extractInvoiceLines('test/fixtures/invoice.pdf');
      final result = parseInvoiceLines(lines);

      expect(result.warnings, isEmpty);
      expect(result.invoiceTotal, 15568.34);
      expect(result.transactions, hasLength(80));

      final totals = calculateTotals(result.transactions);
      expect(totals.bruna, closeTo(11039.43, 0.01));
      expect(totals.douglas, closeTo(4528.91, 0.01));
      expect(totals.sharedTotal, 0);
      expect(totals.ignored, 0);
      expect(totals.grandTotal, closeTo(15568.34, 0.01));

      // The two-line annuity/installment pairing found in the Phase 0 spike
      // (pdfrx-specific) — both entries must be present with the right
      // values, not silently dropped.
      final annuities = result.transactions.where((t) => t.expenseName == 'Anuidade Diferenc');
      expect(annuities.map((t) => t.value).toList(), unorderedEquals([67.08, 33.54]));
      expect(annuities.every((t) => t.installment == '03/12'), isTrue);
      expect(annuities.every((t) => t.owner == Owner.bruna), isTrue);
    },
    skip: _pdfiumPath == null ? 'Set PDFIUM_PATH to run this (see file header comment).' : false,
  );
}
