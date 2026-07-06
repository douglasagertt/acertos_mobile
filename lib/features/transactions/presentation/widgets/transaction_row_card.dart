import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/owner.dart';
import '../../../../shared/models/transaction.dart';
import '../../../../shared/utils/money.dart';
import '../../owner_shared_sync.dart';

/// A single transaction, editable inline: owner, shared flag and obs.
/// Mirrors SortableRow in acertos/web/src/components/TransactionTable.tsx,
/// adapted to a card layout for narrow mobile screens instead of a 12-column
/// table.
///
/// StatefulWidget (not Stateless) so the `obs` TextEditingController is
/// created once in initState — obs is only ever mutated through this field,
/// so there's no external value to reactively resync against. A dropdown-
/// list rebuild elsewhere (Riverpod watches the whole list) re-runs build()
/// but preserves this State as long as the ValueKey(transaction.id) doesn't
/// change, so the controller (and the user's cursor position) survives.
class TransactionRowCard extends StatefulWidget {
  const TransactionRowCard({
    super.key,
    required this.transaction,
    required this.index,
    required this.onUpdate,
    required this.onDelete,
  });

  final Transaction transaction;
  final int index;
  final ValueChanged<Transaction> onUpdate;
  final ValueChanged<String> onDelete;

  @override
  State<TransactionRowCard> createState() => _TransactionRowCardState();
}

class _TransactionRowCardState extends State<TransactionRowCard> {
  late final _obsController = TextEditingController(text: widget.transaction.obs);

  @override
  void dispose() {
    _obsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.transaction;
    final colors = ownerColors(t.owner);
    final description = t.expenseName.isNotEmpty ? t.expenseName : t.originalDescription;
    final subtitle = [
      t.datetime,
      t.city,
      t.purchaseType,
      if (t.installment.isNotEmpty) 'Parcela ${t.installment}',
    ].where((s) => s.isNotEmpty).join(' · ');

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.fromLTRB(12, 10, 4, 4),
      decoration: BoxDecoration(
        color: colors.bg,
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: colors.accent, width: 4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  description.isEmpty ? '—' : description,
                  style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.charcoal800),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                displayValue(t.value),
                style: TextStyle(fontWeight: FontWeight.w700, color: colors.text),
              ),
              ReorderableDragStartListener(
                index: widget.index,
                child: const Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: Icon(Icons.drag_handle, size: 18, color: AppColors.charcoal400),
                ),
              ),
            ],
          ),
          if (subtitle.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(subtitle, style: const TextStyle(fontSize: 11, color: AppColors.charcoal400)),
            ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: DropdownButtonFormField<Owner>(
                  key: ValueKey('owner-${t.id}'),
                  initialValue: t.owner,
                  isDense: true,
                  decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()),
                  items: [
                    for (final o in Owner.values)
                      DropdownMenuItem(value: o, child: Text(o.label, style: const TextStyle(fontSize: 12))),
                  ],
                  onChanged: (newOwner) {
                    if (newOwner == null) return;
                    widget.onUpdate(applyOwnerChange(t, newOwner));
                  },
                ),
              ),
              const SizedBox(width: 4),
              Checkbox(
                value: t.shared,
                visualDensity: VisualDensity.compact,
                onChanged: (checked) => widget.onUpdate(applySharedChange(t, checked ?? false)),
              ),
              const Text('Comp.', style: TextStyle(fontSize: 11, color: AppColors.charcoal400)),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 18),
                color: AppColors.charcoal400,
                tooltip: 'Remover',
                onPressed: () => widget.onDelete(t.id),
              ),
            ],
          ),
          TextField(
            controller: _obsController,
            style: const TextStyle(fontSize: 12),
            decoration: const InputDecoration(
              isDense: true,
              hintText: 'Obs...',
              border: InputBorder.none,
            ),
            onChanged: (v) => widget.onUpdate(t.copyWith(obs: v)),
          ),
        ],
      ),
    );
  }
}
