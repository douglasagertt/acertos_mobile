import 'package:flutter/material.dart';

import '../../../core/constants/months_pt.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/owner.dart';
import '../../../shared/models/transaction.dart';

/// Shows the "add expense" dialog and returns the created [Transaction], or
/// null if the user cancelled. Mirrors AddExpenseDialog.tsx.
Future<Transaction?> showAddExpenseDialog(BuildContext context) {
  return showDialog<Transaction>(context: context, builder: (_) => const AddExpenseDialog());
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
    return AlertDialog(
      backgroundColor: AppColors.cream50,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: const Text('Adicionar despesa'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                  child: DropdownButtonFormField<Owner>(
                    key: const Key('ownerField'),
                    initialValue: _owner,
                    decoration: const InputDecoration(labelText: 'Responsável'),
                    items: [
                      for (final o in Owner.values) DropdownMenuItem(value: o, child: Text(o.label)),
                    ],
                    onChanged: (o) => setState(() => _owner = o ?? _owner),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: _month,
                    decoration: const InputDecoration(labelText: 'Mês'),
                    items: [
                      for (final entry in monthsPt.entries)
                        DropdownMenuItem(value: entry.key, child: Text(entry.value)),
                    ],
                    onChanged: (m) => setState(() => _month = m ?? _month),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 96,
                  child: TextFormField(
                    initialValue: _year.toString(),
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Ano'),
                    onChanged: (v) => _year = int.tryParse(v) ?? _year,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _obsController,
              decoration: const InputDecoration(
                labelText: 'Observação (opcional)',
                hintText: 'Nota adicional...',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.lavender600),
          onPressed: _submit,
          child: const Text('Adicionar'),
        ),
      ],
    );
  }
}
