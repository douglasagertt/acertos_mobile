import 'package:flutter/material.dart';

import '../../../core/constants/months_pt.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/owner.dart';
import '../../../shared/models/transaction.dart';
import '../../../shared/widgets/owner_pill.dart';

/// Shows the "add expense" bottom sheet and returns the created
/// [Transaction], or null if the user cancelled. Mirrors AddExpenseDialog.tsx
/// and Douglas's "Adicionar despesa" bottom-sheet mockup.
Future<Transaction?> showAddExpenseDialog(BuildContext context) {
  return showModalBottomSheet<Transaction>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: AppColors.brandCard,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (_) => const AddExpenseDialog(),
  );
}

class AddExpenseDialog extends StatefulWidget {
  const AddExpenseDialog({super.key});

  @override
  State<AddExpenseDialog> createState() => _AddExpenseDialogState();
}

class _AddExpenseDialogState extends State<AddExpenseDialog> {
  final _expenseNameController = TextEditingController();
  final _valueController = TextEditingController();
  final _obsController = TextEditingController();
  Owner _owner = Owner.bruna;
  late int _month = DateTime.now().month;
  late int _year = DateTime.now().year;

  @override
  void dispose() {
    _expenseNameController.dispose();
    _valueController.dispose();
    _obsController.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _expenseNameController.text.trim();
    final numVal = double.tryParse(_valueController.text.replaceAll(',', '.'));
    if (name.isEmpty || numVal == null || numVal <= 0) return;

    final datetime = '${_month.toString().padLeft(2, '0')}/$_year';
    Navigator.of(context).pop(
      Transaction(
        datetime: datetime,
        purchaseType: 'Manual',
        originalDescription: name,
        expenseName: name,
        value: numVal,
        owner: _owner,
        shared: _owner == Owner.compartilhado,
        obs: _obsController.text,
        source: 'manual',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Adicionar despesa',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.onSurface),
                ),
                const SizedBox(height: 20),
                TextField(
                  key: const Key('expenseNameField'),
                  controller: _expenseNameController,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Descrição',
                    hintText: 'Ex: Mercado, Farmácia...',
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        key: const Key('valueField'),
                        controller: _valueController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Valor (R\$)', hintText: '0,00'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        initialValue: _month,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Mês'),
                        items: [
                          for (final entry in monthsPt.entries)
                            DropdownMenuItem(value: entry.key, child: Text(entry.value)),
                        ],
                        onChanged: (m) => setState(() => _month = m ?? _month),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: 120,
                  child: TextFormField(
                    initialValue: _year.toString(),
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Ano'),
                    onChanged: (v) => _year = int.tryParse(v) ?? _year,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Responsável',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.onSurfaceVariant),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final owner in Owner.values)
                      OwnerPill(owner: owner, active: _owner == owner, onTap: () => setState(() => _owner = owner)),
                  ],
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _obsController,
                  decoration: const InputDecoration(
                    labelText: 'Observação (opcional)',
                    hintText: 'Nota adicional...',
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
                    const SizedBox(width: 8),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.lavender,
                        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: _submit,
                      child: const Text('Adicionar'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
