import 'package:flutter/material.dart';

import '../../../core/constants/months_pt.dart';
import '../../../core/theme/app_theme.dart';

/// Result of the month/year picker — mirrors SaveDialog.tsx's `onSave(month, year)`.
class SavePdfResult {
  const SavePdfResult(this.month, this.year);

  final int month;
  final int year;
}

/// Shows the "generate settlement PDF" bottom sheet, mirroring
/// `showAddExpenseDialog`'s presentation and Douglas's bottom-sheet mockup.
Future<SavePdfResult?> showSavePdfDialog(BuildContext context) {
  return showModalBottomSheet<SavePdfResult>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: AppColors.brandCard,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (_) => const SavePdfDialog(),
  );
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
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Gerar PDF do acerto',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.onSurface),
              ),
              const SizedBox(height: 4),
              const Text(
                'Informe o mês e ano para nomear o arquivo.',
                style: TextStyle(fontSize: 13, color: AppColors.outline),
              ),
              const SizedBox(height: 20),
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
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.salvia,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: () => Navigator.of(context).pop(SavePdfResult(_month, _year)),
                    icon: const Icon(Icons.ios_share, size: 18),
                    label: const Text('Gerar e compartilhar'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
