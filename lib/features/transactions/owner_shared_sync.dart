import '../../shared/models/owner.dart';
import '../../shared/models/transaction.dart';

/// Mirrors `handleOwnerChange` in TransactionTable.tsx: picking
/// "Compartilhado" as the owner auto-checks shared; picking anything else
/// auto-unchecks it.
Transaction applyOwnerChange(Transaction t, Owner newOwner) {
  return t.copyWith(owner: newOwner, shared: newOwner == Owner.compartilhado);
}

/// Mirrors `handleSharedChange` in TransactionTable.tsx: checking "shared"
/// forces owner to Compartilhado; unchecking it reverts the owner based on
/// the transaction's card group (not to whatever it was before checking).
Transaction applySharedChange(Transaction t, bool checked) {
  if (checked) {
    return t.copyWith(shared: true, owner: Owner.compartilhado);
  }
  return t.copyWith(shared: false, owner: ownerFromCardGroup(t.cardGroup));
}
