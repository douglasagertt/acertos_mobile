import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/owner.dart';
import '../../../../shared/models/transaction.dart';
import '../../../../shared/utils/money.dart';
import '../../../../shared/widgets/owner_pill.dart';
import '../../owner_shared_sync.dart';

/// A single transaction, editable inline via owner pills + an obs field.
/// Mirrors SortableRow in acertos/web/src/components/TransactionTable.tsx in
/// spirit, restyled 2026-07-07 per a UI mockup: white cards (no per-owner
/// tinted background), a segmented pill selector instead of a dropdown, and
/// a constant lavender value color (owner is conveyed by the pills alone).
///
/// StatefulWidget (not Stateless) so the `obs` TextEditingController is
/// created once in initState — obs is only ever mutated through this field,
/// so there's no external value to reactively resync against. A list rebuild
/// elsewhere (Riverpod watches the whole list) re-runs build() but preserves
/// this State as long as the ValueKey(transaction.id) doesn't change, so the
/// controller (and the user's cursor position) survives.
class TransactionRowCard extends StatefulWidget {
  const TransactionRowCard({
    super.key,
    required this.transaction,
    required this.index,
    required this.onUpdate,
    required this.onDelete,
  });

  final Transaction transaction;

  /// Position in the (unfiltered) list, used only for drag-to-reorder. Null
  /// when the row is rendered inside a filtered, non-reorderable list —
  /// reordering a filtered subset has no unambiguous mapping back onto the
  /// full list's order, so the drag handle is simply omitted then.
  final int? index;
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
    final ignored = t.owner == Owner.ignorar;
    final description = t.expenseName.isNotEmpty ? t.expenseName : t.originalDescription;
    final subtitle = [
      t.datetime,
      t.city,
      t.purchaseType,
      if (t.installment.isNotEmpty) 'Parcela ${t.installment}',
    ].where((s) => s.isNotEmpty).join(' · ');

    return Opacity(
      opacity: ignored ? 0.75 : 1,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.brandCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.surfaceVariant.withValues(alpha: 0.4)),
          boxShadow: const [BoxShadow(color: Color(0x0A655D56), blurRadius: 12, offset: Offset(0, 4))],
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
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: ignored ? AppColors.outline : AppColors.onSurface,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  displayValue(t.value),
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: ignored ? AppColors.outline : AppColors.lavender,
                    decoration: ignored ? TextDecoration.lineThrough : null,
                  ),
                ),
                if (widget.index != null)
                  ReorderableDragStartListener(
                    index: widget.index!,
                    child: const Padding(
                      padding: EdgeInsets.only(left: 8, top: 4),
                      child: Icon(Icons.drag_handle, size: 18, color: AppColors.outline),
                    ),
                  ),
              ],
            ),
            if (subtitle.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(subtitle, style: const TextStyle(fontSize: 13, color: AppColors.outline)),
              ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (final owner in Owner.values)
                  OwnerPill(
                    owner: owner,
                    active: t.owner == owner,
                    onTap: () => widget.onUpdate(applyOwnerChange(t, owner)),
                  ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20),
                  color: AppColors.outline,
                  tooltip: 'Remover',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => widget.onDelete(t.id),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                controller: _obsController,
                style: const TextStyle(
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                  color: AppColors.onSurfaceVariant,
                ),
                decoration: const InputDecoration(
                  isDense: true,
                  hintText: 'Adicionar observação...',
                  hintStyle: TextStyle(fontStyle: FontStyle.italic, color: AppColors.outline),
                  border: InputBorder.none,
                ),
                onChanged: (v) => widget.onUpdate(t.copyWith(obs: v)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
