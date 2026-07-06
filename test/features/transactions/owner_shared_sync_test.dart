import 'package:acertos_mobile/features/transactions/owner_shared_sync.dart';
import 'package:acertos_mobile/shared/models/owner.dart';
import 'package:acertos_mobile/shared/models/transaction.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('applyOwnerChange', () {
    test('picking Compartilhado auto-checks shared', () {
      final t = Transaction(owner: Owner.bruna);
      final result = applyOwnerChange(t, Owner.compartilhado);
      expect(result.owner, Owner.compartilhado);
      expect(result.shared, isTrue);
    });

    test('picking Douglas auto-unchecks shared', () {
      final t = Transaction(owner: Owner.compartilhado, shared: true);
      final result = applyOwnerChange(t, Owner.douglas);
      expect(result.owner, Owner.douglas);
      expect(result.shared, isFalse);
    });
  });

  group('applySharedChange', () {
    test('checking shared forces owner to Compartilhado', () {
      final t = Transaction(owner: Owner.bruna, cardGroup: 'Cartão Bruna Hentschel');
      final result = applySharedChange(t, true);
      expect(result.shared, isTrue);
      expect(result.owner, Owner.compartilhado);
    });

    test('unchecking shared reverts owner based on card group, not prior owner', () {
      final t = Transaction(
        owner: Owner.compartilhado,
        shared: true,
        cardGroup: 'Cartão adicional Douglas A Pereira',
      );
      final result = applySharedChange(t, false);
      expect(result.shared, isFalse);
      expect(result.owner, Owner.douglas);
    });

    test('unchecking shared with no card group (manual expense) reverts to Bruna', () {
      final t = Transaction(owner: Owner.compartilhado, shared: true, cardGroup: '');
      final result = applySharedChange(t, false);
      expect(result.owner, Owner.bruna);
    });
  });
}
