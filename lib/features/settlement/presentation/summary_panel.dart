import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/models/totals.dart';
import '../../../shared/utils/money.dart';

/// Mirrors SummaryPanel.tsx's metrics, reflowed as a compact bottom panel
/// instead of a fixed 270px sidebar (there's no room for a side panel on a
/// phone-width screen).
class SummaryPanel extends StatelessWidget {
  const SummaryPanel({super.key, required this.totals});

  final Totals totals;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.cream50,
        border: Border(top: BorderSide(color: AppColors.cream300)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 20,
              runSpacing: 10,
              children: [
                _Metric(label: 'Cartão Bruna', value: totals.bruna, color: AppColors.lavender600),
                _Metric(label: 'Cartão Douglas', value: totals.douglas, color: AppColors.sage500),
                _SharedMetric(total: totals.sharedTotal, half: totals.sharedHalf),
                _Metric(label: 'Ignorados', value: totals.ignored, color: AppColors.charcoal400),
                _Metric(label: 'Total', value: totals.grandTotal, color: AppColors.sageAccent),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.charcoal800,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Douglas deve pagar',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.cream500),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    formatMoney(totals.douglasToPay),
                    key: const Key('summary-douglas-to-pay'),
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Gastos Douglas + 50% compartilhado',
                    style: TextStyle(fontSize: 10, color: AppColors.charcoal500),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, required this.color});

  final String label;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: AppColors.charcoal400,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 2),
        Text(formatMoney(value), style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }
}

class _SharedMetric extends StatelessWidget {
  const _SharedMetric({required this.total, required this.half});

  final double total;
  final double half;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'COMPARTILHADO',
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.charcoal400, letterSpacing: 0.4),
        ),
        const SizedBox(height: 2),
        Row(
          children: [
            _MiniStat(label: 'Total', value: total),
            const SizedBox(width: 14),
            _MiniStat(label: 'Cada um', value: half),
          ],
        ),
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value});

  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: const TextStyle(fontSize: 9, color: AppColors.charcoal400)),
        Text(formatMoney(value), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.charcoal500)),
      ],
    );
  }
}
