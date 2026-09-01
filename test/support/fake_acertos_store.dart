import 'dart:io';

import 'package:acertos_mobile/features/history/acertos_store.dart';
import 'package:acertos_mobile/shared/models/totals.dart';
import 'package:acertos_mobile/shared/models/transaction.dart';

/// In-memory stand-in for [AcertosStore], for widget tests.
///
/// Widget tests run inside flutter_test's fake-async zone, where a real
/// `dart:io` future never completes — a screen awaiting one hangs until
/// `pumpAndSettle` times out, and `tester.runAsync` does not rescue a future
/// the widget itself is already awaiting. So the screens get their answers
/// from memory here; the real file behaviour (atomic writes, corrupt files,
/// add-or-update) is covered directly in acertos_store_test.dart.
class FakeAcertosStore extends AcertosStore {
  FakeAcertosStore() : super(Directory.systemTemp);

  final List<AcertoRecord> records = [];
  final Map<String, List<Transaction>> transactionsById = {};

  /// Every list of transactions this store was asked to persist as the session.
  final List<List<Transaction>> savedSessions = [];

  int saveRecordCalls = 0;

  /// When set, every call throws it — for exercising the failure paths.
  Object? failWith;

  void seed(AcertoRecord record, List<Transaction> transactions) {
    records.add(record);
    transactionsById[record.id] = transactions;
  }

  void _maybeFail() {
    final failure = failWith;
    if (failure != null) throw failure;
  }

  @override
  Future<SessionSnapshot> loadSession() async => const SessionSnapshot();

  @override
  Future<void> saveSession(List<Transaction> transactions, {String? openRecordId}) async {
    savedSessions.add(List.of(transactions));
  }

  @override
  void saveSessionSync(List<Transaction> transactions, {String? openRecordId}) {
    savedSessions.add(List.of(transactions));
  }

  @override
  Future<List<AcertoRecord>> listRecords() async {
    _maybeFail();
    return List.of(records);
  }

  @override
  Future<AcertoRecord?> findRecord(int month, int year) async {
    _maybeFail();
    for (final record in records) {
      if (record.month == month && record.year == year) return record;
    }
    return null;
  }

  @override
  Future<List<Transaction>> loadRecord(String id) async {
    _maybeFail();
    return transactionsById[id] ?? const [];
  }

  @override
  Future<void> deleteRecord(String id) async {
    _maybeFail();
    records.removeWhere((r) => r.id == id);
    transactionsById.remove(id);
  }

  @override
  Future<AcertoRecord> saveRecord({
    required List<Transaction> transactions,
    required Totals totals,
    required int month,
    required int year,
  }) async {
    _maybeFail();
    saveRecordCalls++;
    final existing = records.where((r) => r.month == month && r.year == year).firstOrNull;
    final record = AcertoRecord(
      id: existing?.id ?? 'record-$month-$year',
      month: month,
      year: year,
      monthName: 'Mês $month',
      createdAt: existing?.createdAt ?? '2026-09-01T21:04:00.000',
      updatedAt: '2026-09-01T21:04:00.000',
      transactionCount: transactions.length,
      grandTotal: totals.grandTotal,
      douglasToPay: totals.douglasToPay,
    );
    records.removeWhere((r) => r.id == record.id);
    records.add(record);
    transactionsById[record.id] = List.of(transactions);
    return record;
  }
}
