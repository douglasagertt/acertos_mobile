import 'dart:convert';
import 'dart:io';

import 'package:acertos_mobile/features/history/acertos_store.dart';
import 'package:acertos_mobile/features/settlement/calculate_totals.dart';
import 'package:acertos_mobile/shared/models/owner.dart';
import 'package:acertos_mobile/shared/models/transaction.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory dir;
  late AcertosStore store;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('acertos_store_test');
    store = AcertosStore(dir);
    addTearDown(() => dir.deleteSync(recursive: true));
  });

  List<Transaction> sample() => [
    Transaction(expenseName: 'Mercado', value: 135.85, owner: Owner.bruna),
    Transaction(expenseName: 'Farmácia', value: 56.26, owner: Owner.douglas),
    Transaction(expenseName: 'Escolinha', value: 90.0, owner: Owner.compartilhado, shared: true),
  ];

  group('session', () {
    test('starts empty when nothing was ever saved', () async {
      final snapshot = await store.loadSession();

      expect(snapshot.transactions, isEmpty);
      expect(snapshot.openRecordId, isNull);
      expect(snapshot.warnings, isEmpty);
    });

    test('round-trips the transaction list and the open record id', () async {
      await store.saveSession(sample(), openRecordId: 'record-1');
      final snapshot = await store.loadSession();

      expect(snapshot.transactions, hasLength(3));
      expect(snapshot.transactions[1].expenseName, 'Farmácia');
      expect(snapshot.transactions[2].owner, Owner.compartilhado);
      expect(snapshot.openRecordId, 'record-1');
    });

    test('the sync flush writes what the async save would', () async {
      store.saveSessionSync(sample(), openRecordId: 'record-2');
      final snapshot = await store.loadSession();

      expect(snapshot.transactions, hasLength(3));
      expect(snapshot.openRecordId, 'record-2');
    });

    test('leaves no temp file behind', () async {
      await store.saveSession(sample());

      final leftovers = dir.listSync().where((e) => e.path.endsWith('.tmp'));
      expect(leftovers, isEmpty);
    });

    test('a corrupt session file warns, keeps a .bak and starts empty', () async {
      File('${dir.path}/session.json').writeAsStringSync('{"transactions": [ truncated');

      final snapshot = await store.loadSession();

      expect(snapshot.transactions, isEmpty);
      expect(snapshot.warnings, hasLength(1));
      expect(File('${dir.path}/session.json.bak').existsSync(), isTrue);
    });

    test('a session whose transactions key holds the wrong type starts empty', () async {
      // Regression: valid JSON of the wrong shape used to throw a TypeError
      // out of loadSession, so the app started with a misleading "storage
      // unavailable" warning and silently dropped the session every launch.
      File('${dir.path}/session.json').writeAsStringSync(jsonEncode({'transactions': {'a': 1}}));

      final snapshot = await store.loadSession();

      expect(snapshot.transactions, isEmpty);
      expect(snapshot.openRecordId, isNull);
    });

    test('an openRecordId of the wrong type is ignored, keeping the transactions', () async {
      File('${dir.path}/session.json').writeAsStringSync(
        jsonEncode({
          'openRecordId': 7,
          'transactions': [
            {'expenseName': 'Mercado', 'value': 50.0},
          ],
        }),
      );

      final snapshot = await store.loadSession();

      expect(snapshot.transactions, hasLength(1));
      expect(snapshot.openRecordId, isNull);
    });

    test('a transaction with unexpected field types still loads', () async {
      File('${dir.path}/session.json').writeAsStringSync(
        jsonEncode({
          'transactions': [
            {'expenseName': 'Sem valor'},
            'não é um objeto',
          ],
        }),
      );

      final snapshot = await store.loadSession();

      expect(snapshot.transactions, hasLength(1));
      expect(snapshot.transactions.single.value, 0.0);
      expect(snapshot.warnings, isEmpty);
    });
  });

  group('records', () {
    test('saves an acerto and reads its transactions back', () async {
      final transactions = sample();
      final record = await store.saveRecord(
        transactions: transactions,
        totals: calculateTotals(transactions),
        month: 8,
        year: 2026,
      );

      expect(record.monthName, 'Agosto');
      expect(record.title, 'Agosto/2026');
      expect(record.pdfFilename, 'Acerto_Agosto_2026.pdf');
      expect(record.transactionCount, 3);
      expect(record.douglasToPay, closeTo(101.26, 0.01));
      expect(await store.loadRecord(record.id), hasLength(3));
    });

    test('saving the same month twice updates it instead of duplicating', () async {
      final first = await store.saveRecord(
        transactions: sample(),
        totals: calculateTotals(sample()),
        month: 8,
        year: 2026,
      );
      final second = await store.saveRecord(
        transactions: sample().sublist(0, 1),
        totals: calculateTotals(sample().sublist(0, 1)),
        month: 8,
        year: 2026,
      );

      final records = await store.listRecords();
      expect(records, hasLength(1));
      expect(second.id, first.id);
      expect(second.createdAt, first.createdAt);
      expect(records.single.transactionCount, 1);
    });

    test('lists newest first across months and years', () async {
      for (final (month, year) in const [(8, 2026), (12, 2025), (1, 2026)]) {
        await store.saveRecord(
          transactions: sample(),
          totals: calculateTotals(sample()),
          month: month,
          year: year,
        );
      }

      final titles = (await store.listRecords()).map((r) => r.title).toList();
      expect(titles, ['Agosto/2026', 'Janeiro/2026', 'Dezembro/2025']);
    });

    test('finds a record by month and year, and nothing for an unsaved month', () async {
      await store.saveRecord(
        transactions: sample(),
        totals: calculateTotals(sample()),
        month: 8,
        year: 2026,
      );

      expect((await store.findRecord(8, 2026))?.title, 'Agosto/2026');
      expect(await store.findRecord(9, 2026), isNull);
    });

    test('deleting removes both the index entry and the record file', () async {
      final record = await store.saveRecord(
        transactions: sample(),
        totals: calculateTotals(sample()),
        month: 8,
        year: 2026,
      );
      final file = File('${dir.path}/records/${record.id}.json');
      expect(file.existsSync(), isTrue);

      await store.deleteRecord(record.id);

      expect(await store.listRecords(), isEmpty);
      expect(file.existsSync(), isFalse);
    });

    test('deleting one acerto leaves the others intact', () async {
      final august = await store.saveRecord(
        transactions: sample(),
        totals: calculateTotals(sample()),
        month: 8,
        year: 2026,
      );
      await store.saveRecord(
        transactions: sample(),
        totals: calculateTotals(sample()),
        month: 9,
        year: 2026,
      );

      await store.deleteRecord(august.id);

      final records = await store.listRecords();
      expect(records.map((r) => r.title), ['Setembro/2026']);
    });

    test('reading a record that no longer exists gives an empty list', () async {
      expect(await store.loadRecord('missing'), isEmpty);
    });

    test('an index whose records key holds the wrong type reads as empty', () async {
      File('${dir.path}/history.json').writeAsStringSync(jsonEncode({'records': 'oops'}));

      expect(await store.listRecords(), isEmpty);
    });

    test('an index entry with wrong field types loads with defaults', () async {
      File('${dir.path}/history.json').writeAsStringSync(
        jsonEncode({
          'records': [
            {'id': 'r1', 'month': '8', 'year': 2026, 'douglasToPay': 'muito'},
            'nem é um objeto',
          ],
        }),
      );

      final records = await store.listRecords();
      expect(records, hasLength(1));
      expect(records.single.month, 1); // fell back, rather than taking the list down
      expect(records.single.douglasToPay, 0.0);
      expect(records.single.year, 2026);
    });
  });

  group('record labels', () {
    AcertoRecord recordWith(String updatedAt) => AcertoRecord(
      id: 'r1',
      month: 8,
      year: 2026,
      monthName: 'Agosto',
      createdAt: updatedAt,
      updatedAt: updatedAt,
      transactionCount: 1,
      grandTotal: 10,
      douglasToPay: 5,
    );

    test('formats the saved-at stamp as dd/MM/yyyy HH:mm', () {
      expect(recordWith('2026-09-01T21:04:07.000').updatedAtLabel, '01/09/2026 21:04');
      expect(recordWith('2026-01-05T09:07:00.000').updatedAtLabel, '05/01/2026 09:07');
    });

    test('an unparseable stamp is shown as stored instead of blowing up', () {
      expect(recordWith('ontem').updatedAtLabel, 'ontem');
    });
  });
}
