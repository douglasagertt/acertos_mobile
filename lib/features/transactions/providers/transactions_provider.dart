import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/transaction.dart';
import '../../history/providers/acertos_providers.dart';

/// How long to wait after a change before writing the session to disk.
/// Long enough that dragging a row or typing a value doesn't write on every
/// frame, short enough that nothing is ever more than a moment from saved.
const _saveDebounce = Duration(milliseconds: 400);

/// Holds the current reconciliation session's transactions — same role as the
/// `transactions` useState in web/src/App.tsx, but persisted: the list is
/// restored from disk at startup and written back after every change, so
/// closing (or the OS killing) the app mid-reconciliation loses nothing.
class TransactionsNotifier extends Notifier<List<Transaction>> {
  Timer? _saveTimer;
  String? _openRecordId;

  /// The saved acerto this session came from, if any.
  String? get openRecordId => _openRecordId;

  @override
  List<Transaction> build() {
    final restored = ref.watch(restoredSessionProvider);
    _openRecordId = restored.openRecordId;

    // Every mutation below goes through the state setter, so listening to
    // ourselves covers all of them at once — add/update/remove/reorder/
    // replaceAll/clear need no save call of their own.
    listenSelf((_, _) => _scheduleSave());
    ref.onDispose(() => _saveTimer?.cancel());

    return restored.transactions;
  }

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

  /// A fresh import starts a new session, so it stops belonging to whatever
  /// saved acerto was open — saving it later creates/updates the record for
  /// the month chosen then, not the one it was opened from.
  void replaceAll(List<Transaction> transactions) {
    _openRecordId = null;
    state = transactions;
  }

  /// Loads a saved acerto into the session, remembering which record it came
  /// from so saving again updates that one instead of asking to overwrite it.
  void openRecord(String recordId, List<Transaction> transactions) {
    _openRecordId = recordId;
    state = transactions;
  }

  /// The session was just saved as [recordId].
  void markSavedAs(String recordId) {
    _openRecordId = recordId;
    _scheduleSave();
  }

  void clear() {
    _openRecordId = null;
    state = [];
  }

  /// Writes the session now instead of waiting out the debounce. Used when the
  /// app goes to the background: both Android and iOS can kill a backgrounded
  /// process at any moment, and a pending timer would never fire — so this is
  /// deliberately synchronous, finishing before the lifecycle callback returns.
  void flushSave() {
    _saveTimer?.cancel();
    _saveTimer = null;
    ref.read(acertosStoreProvider)?.saveSessionSync(state, openRecordId: _openRecordId);
  }

  void _scheduleSave() {
    // No store means no persistence is configured (widget tests, or storage
    // that couldn't be resolved at startup) — then there is nothing to
    // schedule, and no stray timer left running for a test to trip over.
    final store = ref.read(acertosStoreProvider);
    if (store == null) return;

    _saveTimer?.cancel();
    _saveTimer = Timer(_saveDebounce, () => store.saveSession(state, openRecordId: _openRecordId));
  }
}

final transactionsProvider = NotifierProvider<TransactionsNotifier, List<Transaction>>(
  TransactionsNotifier.new,
);
