import '../../shared/models/owner.dart';
import '../../shared/models/transaction.dart';

/// Mirrors `handleOwnerChange` in TransactionTable.tsx: picking
/// "Compartilhado" as the owner auto-checks shared; picking anything else
/// auto-unchecks it. The row UI (owner pills) is the only way to change
/// owner, so this is the single entry point — there's no separate "shared"
/// toggle anymore (it never reached a state `handleSharedChange` in the web
/// app couldn't already reach via owner alone).
Transaction applyOwnerChange(Transaction t, Owner newOwner) {
  return t.copyWith(owner: newOwner, shared: newOwner == Owner.compartilhado);
}
