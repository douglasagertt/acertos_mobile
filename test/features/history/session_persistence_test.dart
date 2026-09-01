// The autosave loop end to end: a change to the transactions provider lands in
// session.json on its own, and a fresh container restored from that file comes
// back with the same list. What this can't cover is a real process kill —
// that one is verified on a device (see PLAN.md).
import 'dart:io';

import 'package:acertos_mobile/features/history/acertos_store.dart';
import 'package:acertos_mobile/features/history/providers/acertos_providers.dart';
import 'package:acertos_mobile/features/transactions/providers/transactions_provider.dart';
import 'package:acertos_mobile/shared/models/owner.dart';
import 'package:acertos_mobile/shared/models/transaction.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory dir;
  late AcertosStore store;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('session_persistence_test');
    store = AcertosStore(dir);
    addTearDown(() => dir.deleteSync(recursive: true));
  });

  ProviderContainer containerWith(SessionSnapshot session) {
    final container = ProviderContainer(
      overrides: [
        acertosStoreProvider.overrideWithValue(store),
        restoredSessionProvider.overrideWithValue(session),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  // The debounce plus a margin, so the timer has actually fired.
  Future<void> waitForAutosave() => Future<void>.delayed(const Duration(milliseconds: 600));

  test('adding a transaction is written to disk without anyone asking', () async {
    final container = containerWith(const SessionSnapshot());
    container.read(transactionsProvider.notifier).add(Transaction(expenseName: 'Mercado', value: 50.0));

    await waitForAutosave();

    expect((await store.loadSession()).transactions.single.expenseName, 'Mercado');
  });

  test('a restored session is the list the app starts with', () async {
    await store.saveSession([
      Transaction(expenseName: 'Escolinha', value: 90.0, owner: Owner.compartilhado, shared: true),
    ]);

    final container = containerWith(await store.loadSession());

    expect(container.read(transactionsProvider), hasLength(1));
    expect(container.read(transactionsProvider).single.owner, Owner.compartilhado);
  });

  test('editing and deleting are saved too, not just adding', () async {
    final container = containerWith(const SessionSnapshot());
    final notifier = container.read(transactionsProvider.notifier);
    final first = Transaction(expenseName: 'Mercado', value: 50.0);
    final second = Transaction(expenseName: 'Farmácia', value: 20.0);
    notifier.add(first);
    notifier.add(second);
    notifier.update(first.copyWith(owner: Owner.douglas));
    notifier.remove(second.id);

    await waitForAutosave();

    final saved = (await store.loadSession()).transactions;
    expect(saved, hasLength(1));
    expect(saved.single.owner, Owner.douglas);
  });

  test('flushSave writes immediately, without waiting out the debounce', () async {
    final container = containerWith(const SessionSnapshot());
    container.read(transactionsProvider.notifier).add(Transaction(expenseName: 'Padaria', value: 12.0));

    container.read(transactionsProvider.notifier).flushSave();

    // No delay: this is the app-backgrounded path, where there may be no time
    // left for the debounce to fire.
    expect((await store.loadSession()).transactions.single.expenseName, 'Padaria');
  });

  test('clearing the list clears the saved session, and forgets the open acerto', () async {
    final container = containerWith(
      SessionSnapshot(transactions: [Transaction(expenseName: 'Mercado', value: 50.0)], openRecordId: 'record-1'),
    );

    container.read(transactionsProvider.notifier).clear();
    container.read(transactionsProvider.notifier).flushSave();

    final saved = await store.loadSession();
    expect(saved.transactions, isEmpty);
    expect(saved.openRecordId, isNull);
  });

  test('opening a saved acerto remembers which record the session came from', () async {
    final container = containerWith(const SessionSnapshot());

    container.read(transactionsProvider.notifier).openRecord('record-9', [
      Transaction(expenseName: 'Agosto', value: 10.0),
    ]);
    container.read(transactionsProvider.notifier).flushSave();

    expect(container.read(transactionsProvider.notifier).openRecordId, 'record-9');
    expect((await store.loadSession()).openRecordId, 'record-9');
  });

  test('markSavedAs binds the session to the record it was just saved as', () async {
    final container = containerWith(const SessionSnapshot());
    container.read(transactionsProvider.notifier).add(Transaction(expenseName: 'Mercado', value: 50.0));

    container.read(transactionsProvider.notifier).markSavedAs('record-agosto');
    container.read(transactionsProvider.notifier).flushSave();

    expect(container.read(transactionsProvider.notifier).openRecordId, 'record-agosto');
    expect((await store.loadSession()).openRecordId, 'record-agosto');
  });

  test('importing a new invoice detaches the session from the opened acerto', () async {
    final container = containerWith(const SessionSnapshot(openRecordId: 'record-9'));

    container.read(transactionsProvider.notifier).replaceAll([Transaction(expenseName: 'Setembro', value: 10.0)]);

    expect(container.read(transactionsProvider.notifier).openRecordId, isNull);
  });

  test('without a store configured, nothing is written and nothing throws', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(transactionsProvider.notifier).add(Transaction(expenseName: 'Mercado', value: 50.0));
    container.read(transactionsProvider.notifier).flushSave();
    await waitForAutosave();

    expect(dir.listSync(), isEmpty);
  });
}
