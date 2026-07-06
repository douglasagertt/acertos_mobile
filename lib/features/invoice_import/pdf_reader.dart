import '../../shared/models/owner.dart';
import '../../shared/models/transaction.dart';

/// Result of parsing an invoice's extracted text lines. Mirrors the
/// `(transactions, warnings, invoice_total)` tuple `read_pdf()` returns in
/// acertos/src/core/pdf_reader.py.
class ParsedInvoice {
  const ParsedInvoice({required this.transactions, required this.warnings, required this.invoiceTotal});

  final List<Transaction> transactions;
  final List<String> warnings;
  final double? invoiceTotal;
}

final _reDate = RegExp(r'^(\d{2}/\w{3})\s+(\d{2}:\d{2})\s*(.*)');
final _reValue = RegExp(r'(-?R\$\s*[\d.,]+)\s*$');
final _reInstallment = RegExp(r'\b(\d{2}/\d{2})\b');
final _reTotalLine = RegExp(r'^Total (cartão|cartão virtual|cartão adicional)', caseSensitive: false);
final _rePayment = RegExp('pagamento de fatura', caseSensitive: false);
final _reInvoiceTotal = RegExp(r'Total fatura de \S+\s+R\$\s*([\d.,]+)', caseSensitive: false);
final _rePreviousInvoiceTotal = RegExp(r'Total da fatura anterior\s+([\d.,]+)', caseSensitive: false);

// Lines that look like standalone descriptions before a date line (e.g.
// "Anuidade Diferenc 02/12").
final _reSoloDesc = RegExp(r'^(?!\d{2}/)[A-Za-zÀ-ÿ].*');

const _skipLines = {
  'Data e hora',
  'Valor em Dolar',
  'Valor em reais',
  'Transações',
  'Vencimento',
  'Total fatura',
  'Bruna Hentschel',
  'Mastercard Black',
  'de 6',
  'Legenda:',
};

double _parseValue(String raw) {
  var s = raw.replaceAll('R\$', '').replaceAll(' ', '').trim();
  s = s.replaceAll('.', '').replaceAll(',', '.');
  return double.tryParse(s) ?? 0.0;
}

String? _detectCardGroup(String line) {
  final lower = line.toLowerCase();
  for (final header in cardHeaders) {
    if (lower.contains(header.toLowerCase())) return header;
  }
  return null;
}

/// True when `restNoVal` is a "pagamento de fatura" that fully settles last
/// month's balance — it cancels out "Total da fatura anterior" and isn't
/// part of this month's spending. Any *other* payment of this kind is an
/// extra payment made during the cycle and reduces the amount actually due.
bool _isNettedPayment(String restNoVal, double value, double? previousInvoiceTotal) {
  if (!_rePayment.hasMatch(restNoVal)) return false;
  return previousInvoiceTotal == null || (value.abs() - previousInvoiceTotal).abs() < 0.01;
}

class _ParsedRest {
  const _ParsedRest({
    required this.purchaseType,
    required this.city,
    required this.description,
    required this.installment,
  });

  final String purchaseType;
  final String city;
  final String description;
  final String installment;
}

_ParsedRest _processDescriptionRest(String restNoVal) {
  var purchaseType = '';
  var city = '';
  var description = restNoVal;

  for (final ptype in const ['Presencial', 'Online']) {
    final idx = restNoVal.indexOf(ptype);
    if (idx != -1) {
      city = restNoVal.substring(0, idx).trim();
      description = restNoVal.substring(idx + ptype.length).trim();
      purchaseType = ptype;
      break;
    }
  }

  var installment = '';
  final instMatch = _reInstallment.firstMatch(description);
  if (instMatch != null) {
    installment = instMatch.group(1)!;
    description = (description.substring(0, instMatch.start) + description.substring(instMatch.end)).trim();
  }

  return _ParsedRest(purchaseType: purchaseType, city: city, description: description, installment: installment);
}

Transaction? _parseTransactionLine(String line, String cardGroup, double? previousInvoiceTotal) {
  final m = _reDate.firstMatch(line.trim());
  if (m == null) return null;

  final datePart = m.group(1)!;
  final timePart = m.group(2)!;
  final rest = m.group(3)!.trim();

  final valMatch = _reValue.firstMatch(rest);
  if (valMatch == null) return null;

  final value = _parseValue(valMatch.group(1)!);
  final restNoVal = rest.substring(0, valMatch.start).trim();

  if (_isNettedPayment(restNoVal, value, previousInvoiceTotal)) return null;

  final parsed = _processDescriptionRest(restNoVal);
  return Transaction(
    datetime: '$datePart $timePart',
    city: parsed.city,
    purchaseType: parsed.purchaseType,
    originalDescription: parsed.description,
    expenseName: parsed.description,
    installment: parsed.installment,
    value: value,
    owner: ownerFromCardGroup(cardGroup),
    cardGroup: cardGroup,
    source: 'pdf',
  );
}

/// A date+description line with no trailing value — half of the two-line
/// shape pdfrx produces for multi-line annuity/installment entries (e.g.
/// "Anuidade Diferenc 03/12"), where pdfplumber instead produces three lines
/// (description / date+value / card-last-4-digits). Discovered in the
/// Phase 0 spike; without this, these entries would be silently dropped
/// (the plain port of pdf_reader.py's logic has no line shape that matches
/// "date + description, no value").
class _PendingDateDescription {
  const _PendingDateDescription({required this.datetime, required this.rawRest, required this.parsed});

  final String datetime;
  final String rawRest;
  final _ParsedRest parsed;
}

_PendingDateDescription? _tryParseDateOnly(String line) {
  final m = _reDate.firstMatch(line.trim());
  if (m == null) return null;
  final rest = m.group(3)!.trim();
  if (_reValue.hasMatch(rest)) return null;
  return _PendingDateDescription(
    datetime: '${m.group(1)} ${m.group(2)}',
    rawRest: rest,
    parsed: _processDescriptionRest(rest),
  );
}

/// Parses the flat list of extracted text lines (see `extractInvoiceLines`)
/// into transactions. Pure and synchronous — no PDF library involved here,
/// which is what makes this directly unit-testable with plain string
/// fixtures. Mirrors `read_pdf()` in acertos/src/core/pdf_reader.py line by
/// line, plus the pdfrx-specific two-line pairing above.
ParsedInvoice parseInvoiceLines(List<String> rawLines) {
  final transactions = <Transaction>[];
  final warnings = <String>[];
  double? invoiceTotal;
  double? previousInvoiceTotal;
  var currentGroup = '';
  var pendingDescription = '';
  _PendingDateDescription? pendingDateDesc;

  for (final rawLine in rawLines) {
    final line = rawLine.trim();
    if (line.isEmpty) continue;

    if (invoiceTotal == null) {
      final mTotal = _reInvoiceTotal.firstMatch(line);
      if (mTotal != null) invoiceTotal = _parseValue(mTotal.group(1)!);
    }

    if (previousInvoiceTotal == null) {
      final mPrev = _rePreviousInvoiceTotal.firstMatch(line);
      if (mPrev != null) previousInvoiceTotal = _parseValue(mPrev.group(1)!);
    }

    final group = _detectCardGroup(line);
    if (group != null) {
      currentGroup = group;
      pendingDescription = '';
      pendingDateDesc = null;
      continue;
    }

    if (_reTotalLine.hasMatch(line)) {
      pendingDescription = '';
      pendingDateDesc = null;
      continue;
    }

    if (_skipLines.any(line.contains)) {
      pendingDescription = '';
      pendingDateDesc = null;
      continue;
    }

    if (currentGroup.isEmpty) continue;

    // Pair this line with a still-open date-only line, if one is pending and
    // this line doesn't start a new dated entry itself.
    if (pendingDateDesc != null && !_reDate.hasMatch(line)) {
      final valMatch = _reValue.firstMatch(line);
      if (valMatch != null) {
        final pending = pendingDateDesc;
        final value = _parseValue(valMatch.group(1)!);
        if (!_isNettedPayment(pending.rawRest, value, previousInvoiceTotal)) {
          transactions.add(
            Transaction(
              datetime: pending.datetime,
              city: pending.parsed.city,
              purchaseType: pending.parsed.purchaseType,
              originalDescription: pending.parsed.description,
              expenseName: pending.parsed.description,
              installment: pending.parsed.installment,
              value: value,
              owner: ownerFromCardGroup(currentGroup),
              cardGroup: currentGroup,
              source: 'pdf',
            ),
          );
        }
        pendingDateDesc = null;
        pendingDescription = '';
        continue;
      }
    }

    final t = _parseTransactionLine(line, currentGroup, previousInvoiceTotal);
    if (t != null) {
      pendingDateDesc = null;
      var finalTransaction = t;
      // If this transaction has no description, use the pending one from
      // the line before it.
      if (t.expenseName.isEmpty && pendingDescription.isNotEmpty) {
        var pending = pendingDescription;
        var installment = t.installment;
        final instMatch = _reInstallment.firstMatch(pending);
        if (instMatch != null) {
          installment = instMatch.group(1)!;
          pending = (pending.substring(0, instMatch.start) + pending.substring(instMatch.end)).trim();
        }
        finalTransaction = t.copyWith(originalDescription: pending, expenseName: pending, installment: installment);
      }
      pendingDescription = '';
      transactions.add(finalTransaction);
      continue;
    }

    final dateOnly = _tryParseDateOnly(line);
    if (dateOnly != null) {
      pendingDateDesc = dateOnly;
      pendingDescription = '';
      continue;
    }

    if (_reSoloDesc.hasMatch(line) && !_reValue.hasMatch(line)) {
      pendingDescription = line;
    } else {
      pendingDescription = '';
    }
  }

  if (transactions.isEmpty && warnings.isEmpty) {
    warnings.add('Nenhuma transação encontrada no PDF. Verifique se o arquivo é uma fatura Sicredi.');
  }

  return ParsedInvoice(transactions: transactions, warnings: warnings, invoiceTotal: invoiceTotal);
}
