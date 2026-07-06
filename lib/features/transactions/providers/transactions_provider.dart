import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/transaction.dart';

/// Holds the current reconciliation session's transactions — client-side
/// state, same role as the `transactions` useState in web/src/App.tsx.
class TransactionsNotifier extends Notifier<List<Transaction>> {
  @override
  List<Transaction> build() => [];

  void add(Transaction t) => state = [...state, t];

  void update(Transaction updated) => state = [
    for (final t in state) t.id == updated.id ? updated : t,
  ];

  void remove(String id) => state = state.where((t) => t.id != id).toList();

  void reorder(int oldIndex, int newIndex) {
    final list = [...state];
    final item = list.removeAt(oldIndex);
    list.insert(newIndex, item);
    state = list;
  }

  void replaceAll(List<Transaction> transactions) => state = transactions;

  void clear() => state = [];
}

final transactionsProvider = NotifierProvider<TransactionsNotifier, List<Transaction>>(
  TransactionsNotifier.new,
);
