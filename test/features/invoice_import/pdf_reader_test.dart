import 'package:acertos_mobile/features/invoice_import/pdf_reader.dart';
import 'package:acertos_mobile/shared/models/owner.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('basic transaction parsing', () {
    test('parses a standard Presencial line under the Bruna card group', () {
      final result = parseInvoiceLines([
        'Cartão Bruna Hentschel (final 1113)',
        'Data e hora Cidade Compra Descrição Parcela',
        '09/jun 12:41 Novo Hamburgo Presencial Restaurante Mm E Ef Nh R\$ 98,00',
      ]);

      expect(result.transactions, hasLength(1));
      final t = result.transactions.single;
      expect(t.datetime, '09/jun 12:41');
      expect(t.city, 'Novo Hamburgo');
      expect(t.purchaseType, 'Presencial');
      expect(t.expenseName, 'Restaurante Mm E Ef Nh');
      expect(t.value, 98.0);
      expect(t.owner, Owner.bruna);
      expect(t.source, 'pdf');
      expect(result.warnings, isEmpty);
    });

    test('assigns Douglas as owner under his card group', () {
      final result = parseInvoiceLines([
        'Cartão adicional Douglas A Pereira (final 2222)',
        '06/jun 13:22 Novo Hamburgo Presencial Panvel Filial 170 R\$ 135,85',
      ]);

      expect(result.transactions.single.owner, Owner.douglas);
    });

    test('parses installment tags out of the description', () {
      final result = parseInvoiceLines([
        'Cartão Bruna Hentschel (final 1113)',
        '15/mai 10:00 Loja Presencial Compra Parcelada 02/12 R\$ 50,00',
      ]);

      final t = result.transactions.single;
      expect(t.installment, '02/12');
      expect(t.expenseName, 'Compra Parcelada');
    });

    test('ignores lines before any card group header is seen', () {
      final result = parseInvoiceLines(['09/jun 12:41 Novo Hamburgo Presencial Mercado R\$ 10,00']);
      expect(result.transactions, isEmpty);
    });

    test('negative values (extornos) parse with their sign intact', () {
      final result = parseInvoiceLines([
        'Cartão Bruna Hentschel (final 1113)',
        '11/jun 21:14 Loja Presencial Estorno de compra -R\$ 50,00',
      ]);
      expect(result.transactions.single.value, -50.0);
    });
  });

  group('line shapes seen in real invoices', () {
    test('parses an Online purchase, splitting city from description', () {
      final result = parseInvoiceLines([
        'Cartão virtual Bruna Hentschel (final 1915)',
        '13/jul 07:53 Sao Paulo Online Apple Com/bill R\$ 19,90',
      ]);

      final t = result.transactions.single;
      expect(t.purchaseType, 'Online');
      expect(t.city, 'Sao Paulo');
      expect(t.expenseName, 'Apple Com/bill');
      expect(t.cardGroup, cardGroupVirtualBruna);
      expect(t.owner, Owner.bruna);
    });

    test('a line with no Presencial/Online marker keeps the whole rest as the description', () {
      final result = parseInvoiceLines([
        'Cartão Bruna Hentschel (final 1113)',
        '29/jul 22:28 Cob Anuidade 8/12 R\$ 100,62',
      ]);

      final t = result.transactions.single;
      expect(t.purchaseType, isEmpty);
      expect(t.city, isEmpty);
      // "8/12" is not read as an installment tag — that pattern needs two
      // digits on each side (dd/dd) — so it stays part of the description.
      expect(t.expenseName, 'Cob Anuidade 8/12');
      expect(t.installment, isEmpty);
    });

    test('reads thousands separators, and a value written without cents', () {
      final result = parseInvoiceLines([
        'Cartão Bruna Hentschel (final 1113)',
        '10/jul 14:23 Loja Presencial Escolinha R\$ 1.495,12',
        '11/jul 14:23 Loja Presencial Sem centavos R\$ 1.234',
      ]);

      expect(result.transactions[0].value, 1495.12);
      expect(result.transactions[1].value, 1234.0);
    });

    test('takes the trailing value when the line carries more than one', () {
      final result = parseInvoiceLines([
        'Cartão Bruna Hentschel (final 1113)',
        '10/jul 14:23 Loja Presencial Compra R\$ 10,00 R\$ 20,00',
      ]);

      expect(result.transactions.single.value, 20.0);
    });
  });

  group('known hazard: the skip list matches anywhere in the line', () {
    test('a real transaction containing a footer phrase is dropped', () {
      // "de 6" is in SKIP_LINES to drop the "Página 1 de 6" footer, and the
      // check is a substring match — inherited as-is from pdf_reader.py. A
      // description that happens to contain it disappears silently. Asserting
      // the current behaviour so a future change to it is a deliberate one.
      final result = parseInvoiceLines([
        'Cartão Bruna Hentschel (final 1113)',
        '09/jun 12:41 Novo Hamburgo Presencial Cinema de 6 Salas R\$ 30,00',
      ]);

      expect(result.transactions, isEmpty);
    });

    test('and it reaches further than it looks: "de 60" contains "de 6" too', () {
      final result = parseInvoiceLines([
        'Cartão Bruna Hentschel (final 1113)',
        '09/jun 12:41 Novo Hamburgo Presencial Cinema de 60 Salas R\$ 30,00',
      ]);

      expect(result.transactions, isEmpty);
    });

    test('a description without any skip phrase comes through normally', () {
      final result = parseInvoiceLines([
        'Cartão Bruna Hentschel (final 1113)',
        '09/jun 12:41 Novo Hamburgo Presencial Cinema de 7 Salas R\$ 30,00',
      ]);

      expect(result.transactions, hasLength(1));
      expect(result.transactions.single.expenseName, 'Cinema de 7 Salas');
    });
  });

  group('pending description bookkeeping', () {
    test('a card group header clears a pending description', () {
      final result = parseInvoiceLines([
        'Cartão Bruna Hentschel (final 1113)',
        'Anuidade Diferenc 03/12',
        'Cartão adicional Douglas A Pereira (final 1212)',
        '11/jun 21:14 R\$ 67,08',
      ]);

      // The description belonged to the previous card's section, so it must
      // not leak into the first transaction of the next one.
      expect(result.transactions.single.expenseName, isEmpty);
      expect(result.transactions.single.owner, Owner.douglas);
    });

    test('a total line clears a pending description', () {
      final result = parseInvoiceLines([
        'Cartão Bruna Hentschel (final 1113)',
        'Anuidade Diferenc 03/12',
        'Total cartão (final 1113) R\$ 10,00',
        '11/jun 21:14 R\$ 67,08',
      ]);

      expect(result.transactions.single.expenseName, isEmpty);
    });

    test('a transaction that has its own description keeps it', () {
      final result = parseInvoiceLines([
        'Cartão Bruna Hentschel (final 1113)',
        'Anuidade Diferenc 03/12',
        '11/jun 21:14 Novo Hamburgo Presencial Mercado R\$ 67,08',
      ]);

      expect(result.transactions.single.expenseName, 'Mercado');
    });

    test('a line starting with a digit is not treated as a description', () {
      final result = parseInvoiceLines([
        'Cartão Bruna Hentschel (final 1113)',
        '1113',
        '11/jun 21:14 R\$ 67,08',
      ]);

      expect(result.transactions.single.expenseName, isEmpty);
    });
  });

  group('invoice totals', () {
    test('extracts the invoice total and previous invoice total', () {
      final result = parseInvoiceLines([
        'Total fatura de junho R\$ 15.568,34 Total de parcelas em próximas faturas R\$ 12.274,24',
        'Total da fatura anterior 17.196,49 Saque à crédito Crédito',
      ]);
      expect(result.invoiceTotal, 15568.34);
    });

    test('keeps the first total, since the header repeats on every page', () {
      final result = parseInvoiceLines([
        'Total fatura de agosto R\$ 11.820,97',
        'Total fatura de agosto R\$ 11.820,97',
        'Total fatura de setembro R\$ 99,99',
      ]);
      expect(result.invoiceTotal, 11820.97);
    });

    test('is null when the PDF carries no total line', () {
      final result = parseInvoiceLines([
        'Cartão Bruna Hentschel (final 1113)',
        '09/jun 12:41 Loja Presencial Mercado R\$ 10,00',
      ]);
      expect(result.invoiceTotal, isNull);
    });
  });

  group('pagamento de fatura nets out against last month\'s balance', () {
    test('a full payoff matching the previous total is excluded entirely', () {
      final result = parseInvoiceLines([
        'Total da fatura anterior 500,00 Saque à crédito Crédito',
        'Cartão Bruna Hentschel (final 1113)',
        '10/jun 09:00 Pagamento de fatura -R\$ 500,00',
      ]);
      expect(result.transactions, isEmpty);
    });

    test('a partial payment (not matching the previous total) is kept as a transaction', () {
      final result = parseInvoiceLines([
        'Total da fatura anterior 500,00 Saque à crédito Crédito',
        'Cartão Bruna Hentschel (final 1113)',
        '10/jun 09:00 Pagamento de fatura -R\$ 200,00',
      ]);
      expect(result.transactions, hasLength(1));
      expect(result.transactions.single.value, -200.0);
    });

    test('a payoff within a cent of the previous total still nets out', () {
      final result = parseInvoiceLines([
        'Total da fatura anterior 500,00 Saque à crédito Crédito',
        'Cartão Bruna Hentschel (final 1113)',
        '10/jun 09:00 Pagamento de fatura -R\$ 500,00',
      ]);
      expect(result.transactions, isEmpty);
    });

    test('a credit that is not a "pagamento de fatura" is kept, whatever its value', () {
      // The August invoice's real payment line reads "Pagamento Em Dinheiro",
      // which the parser does not net out — it has to be marked Ignorar by hand.
      final result = parseInvoiceLines([
        'Total da fatura anterior 14.032,90 Saque à crédito Crédito',
        'Cartão Bruna Hentschel (final 1113)',
        '12/jul 10:01 Pagamento Em Dinheiro Na -R\$ 14.032,90',
      ]);

      expect(result.transactions, hasLength(1));
      expect(result.transactions.single.value, -14032.90);
    });

    test('a payment with no known previous total is conservatively excluded too', () {
      // Matches pdf_reader.py: `previous_invoice_total is None` also nets
      // out, since there's no way to prove this payment *isn't* a full
      // payoff — the original code errs toward not double-counting.
      final result = parseInvoiceLines([
        'Cartão Bruna Hentschel (final 1113)',
        '10/jun 09:00 Pagamento de fatura -R\$ 500,00',
      ]);
      expect(result.transactions, isEmpty);
    });
  });

  group('pending-description-on-previous-line (pdfplumber 3-line shape)', () {
    test('uses the previous solo-description line when the date line has no description', () {
      final result = parseInvoiceLines([
        'Cartão Bruna Hentschel (final 1113)',
        'Anuidade Diferenc 03/12',
        '11/jun 21:14 R\$ 67,08',
        '1113',
      ]);

      expect(result.transactions, hasLength(1));
      final t = result.transactions.single;
      expect(t.expenseName, 'Anuidade Diferenc');
      expect(t.installment, '03/12');
      expect(t.value, 67.08);
    });
  });

  group('pdfrx-specific date+description / digits+value pairing', () {
    test('pairs a date-only line with the value-only line that follows it', () {
      final result = parseInvoiceLines([
        'Cartão Bruna Hentschel (final 1113)',
        '11/jun 21:14 Anuidade Diferenc 03/12 ',
        '1113 R\$ 67,08',
      ]);

      expect(result.transactions, hasLength(1));
      final t = result.transactions.single;
      expect(t.datetime, '11/jun 21:14');
      expect(t.expenseName, 'Anuidade Diferenc');
      expect(t.installment, '03/12');
      expect(t.value, 67.08);
    });

    test('handles two consecutive date-only/value-only pairs (two installment fees)', () {
      final result = parseInvoiceLines([
        'Cartão Bruna Hentschel (final 1113)',
        '11/jun 21:14 Anuidade Diferenc 03/12 ',
        '1113 R\$ 67,08',
        '11/jun 21:14 Anuidade Diferenc 03/12 ',
        '1212 R\$ 33,54',
      ]);

      expect(result.transactions, hasLength(2));
      expect(result.transactions[0].value, 67.08);
      expect(result.transactions[1].value, 33.54);
    });

    test('a fresh dated line supersedes a stale unresolved date-only line', () {
      final result = parseInvoiceLines([
        'Cartão Bruna Hentschel (final 1113)',
        '11/jun 21:14 Anuidade Diferenc 03/12 ', // never gets its value line
        '12/jun 09:00 Novo Hamburgo Presencial Mercado R\$ 20,00',
      ]);

      // The stale date-only line contributes nothing; only the real
      // transaction is kept.
      expect(result.transactions, hasLength(1));
      expect(result.transactions.single.value, 20.0);
    });
  });

  group('section boundaries', () {
    test('total/summary lines and card group switches do not become transactions', () {
      final result = parseInvoiceLines([
        'Cartão Bruna Hentschel (final 1113)',
        '09/jun 12:41 Novo Hamburgo Presencial Mercado R\$ 10,00',
        'Total cartão (final 1113) R\$ 10,00',
        'Cartão adicional Douglas A Pereira (final 2222)',
        '10/jun 12:41 Novo Hamburgo Presencial Farmácia R\$ 20,00',
      ]);

      expect(result.transactions, hasLength(2));
      expect(result.transactions[0].owner, Owner.bruna);
      expect(result.transactions[1].owner, Owner.douglas);
    });
  });

  group('warnings', () {
    test('warns when no transactions are found at all', () {
      final result = parseInvoiceLines(['Some unrelated header text']);
      expect(result.transactions, isEmpty);
      expect(result.warnings, isNotEmpty);
    });

    test('does not warn when transactions were found', () {
      final result = parseInvoiceLines([
        'Cartão Bruna Hentschel (final 1113)',
        '09/jun 12:41 Novo Hamburgo Presencial Mercado R\$ 10,00',
      ]);
      expect(result.warnings, isEmpty);
    });
  });
}
