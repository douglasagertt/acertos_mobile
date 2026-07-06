import 'package:acertos_mobile/features/transactions/providers/transactions_provider.dart';
import 'package:acertos_mobile/shared/models/owner.dart';
import 'package:acertos_mobile/shared/models/transaction.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late ProviderContainer container;

  setUp(() => container = ProviderContainer());
  tearDown(() => container.dispose());

  test('starts empty', () {
    expect(container.read(transactionsProvider), isEmpty);
  });

  test('add appends a transaction', () {
    final t = Transaction(owner: Owner.bruna, value: 10);
    container.read(transactionsProvider.notifier).add(t);
    expect(container.read(transactionsProvider), [t]);
  });

  test('update replaces the transaction with matching id', () {
    final t = Transaction(owner: Owner.bruna, value: 10);
    final notifier = container.read(transactionsProvider.notifier);
    notifier.add(t);
    final updated = t.copyWith(value: 20);
    notifier.update(updated);
    expect(container.read(transactionsProvider).single.value, 20);
  });

  test('remove drops the transaction with matching id', () {
    final t1 = Transaction(owner: Owner.bruna, value: 10);
    final t2 = Transaction(owner: Owner.douglas, value: 20);
    final notifier = container.read(transactionsProvider.notifier);
    notifier.add(t1);
    notifier.add(t2);
    notifier.remove(t1.id);
    expect(container.read(transactionsProvider), [t2]);
  });

  test('reorder moves an item to the new index', () {
    final t1 = Transaction(owner: Owner.bruna, value: 1);
    final t2 = Transaction(owner: Owner.bruna, value: 2);
    final t3 = Transaction(owner: Owner.bruna, value: 3);
    final notifier = container.read(transactionsProvider.notifier);
    notifier.replaceAll([t1, t2, t3]);
    notifier.reorder(0, 2);
    expect(container.read(transactionsProvider), [t2, t3, t1]);
  });

  test('clear empties the list', () {
    final notifier = container.read(transactionsProvider.notifier);
    notifier.add(Transaction(owner: Owner.bruna, value: 1));
    notifier.clear();
    expect(container.read(transactionsProvider), isEmpty);
  });
}
