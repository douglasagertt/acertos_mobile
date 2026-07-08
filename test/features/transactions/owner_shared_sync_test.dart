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
}
