import 'package:flutter/material.dart';

import '../../../core/constants/months_pt.dart';
import '../../../core/theme/app_theme.dart';

/// Result of the month/year picker — mirrors SaveDialog.tsx's `onSave(month, year)`.
class SavePdfResult {
  const SavePdfResult(this.month, this.year);

  final int month;
  final int year;
}

Future<SavePdfResult?> showSavePdfDialog(BuildContext context) {
  return showDialog<SavePdfResult>(context: context, builder: (_) => const SavePdfDialog());
}

class SavePdfDialog extends StatefulWidget {
  const SavePdfDialog({super.key});

  @override
  State<SavePdfDialog> createState() => _SavePdfDialogState();
}

class _SavePdfDialogState extends State<SavePdfDialog> {
  late int _month = DateTime.now().month;
  late int _year = DateTime.now().year;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.cream50,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: const Text('Gerar PDF do acerto'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Informe o mês e ano para nomear o arquivo.',
            style: TextStyle(fontSize: 12, color: AppColors.charcoal400),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
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
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.sage500),
          onPressed: () => Navigator.of(context).pop(SavePdfResult(_month, _year)),
          child: const Text('Gerar e compartilhar'),
        ),
      ],
    );
  }
}
