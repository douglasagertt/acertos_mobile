import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/months_pt.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/utils/money.dart';
import '../../pdf_export/generate_and_share_flow.dart';
import '../../transactions/providers/transactions_provider.dart';
import '../totals_provider.dart';

/// The "Resumo" tab — a dedicated settlement summary screen, added
/// 2026-07-07 alongside bottom navigation. Reuses the same `totalsProvider`/
/// `transactionsProvider` as the Home tab (both tabs watch the same
/// in-memory session state) and the same generate-and-share PDF flow.
///
/// Deliberately does *not* include a "+12% vs mês anterior" trend badge the
/// source mockup had — there's no month-over-month history to back that
/// number (Phase 1 has no persisted history yet, see PLAN.md's Phase 1 step
/// 8). Also dropped the mockup's "pending transfer" status line — nothing
/// in this app tracks payment status, so it was removed rather than kept
/// as a permanently-true label.
class ResumoScreen extends ConsumerStatefulWidget {
  const ResumoScreen({super.key});

  @override
  ConsumerState<ResumoScreen> createState() => _ResumoScreenState();
}

class _ResumoScreenState extends ConsumerState<ResumoScreen> {
  bool _generatingPdf = false;

  @override
  Widget build(BuildContext context) {
    final totals = ref.watch(totalsProvider);
    final monthName = monthsPt[DateTime.now().month];

    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Resumo do Acerto',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: AppColors.onSurface),
              ),
              const SizedBox(height: 4),
              Text(
                'Fechamento do mês de $monthName',
                style: const TextStyle(fontSize: 13, color: AppColors.onSurfaceVariant),
              ),
              const SizedBox(height: 20),
              _TotalGeralCard(value: totals.grandTotal),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _PersonCard(name: 'Bruna', value: totals.bruna, color: AppColors.lavender)),
                  const SizedBox(width: 16),
                  Expanded(child: _PersonCard(name: 'Douglas', value: totals.douglas, color: AppColors.salvia)),
                ],
              ),
              const SizedBox(height: 16),
              _SharedCard(total: totals.sharedTotal, half: totals.sharedHalf, ignored: totals.ignored),
              const SizedBox(height: 16),
              _ResultCard(douglasToPay: totals.douglasToPay),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.lavender,
                    side: const BorderSide(color: AppColors.lavender, width: 2),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                  ),
                  onPressed: _generatingPdf
                      ? null
                      : () => generateAndShareSettlementPdf(
                          context: context,
                          transactions: ref.read(transactionsProvider),
                          totals: ref.read(totalsProvider),
                          onLoadingChanged: (loading) => setState(() => _generatingPdf = loading),
                        ),
                  icon: _generatingPdf
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.lavender),
                        )
                      : const Icon(Icons.picture_as_pdf_outlined),
                  label: const Text('Gerar PDF do Acerto', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TotalGeralCard extends StatelessWidget {
  const _TotalGeralCard({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.brandCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.surfaceVariant.withValues(alpha: 0.3)),
        boxShadow: const [BoxShadow(color: Color(0x0A655D56), blurRadius: 12, offset: Offset(0, 4))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Text(
              'TOTAL GERAL DO MÊS',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.onSurfaceVariant,
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              formatMoney(value),
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppColors.primary),
            ),
          ],
        ),
      ),
    );
  }
}

class _PersonCard extends StatelessWidget {
  const _PersonCard({required this.name, required this.value, required this.color});

  final String name;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.brandCard,
        borderRadius: BorderRadius.circular(20),
        border: Border(left: BorderSide(color: color, width: 4)),
        boxShadow: const [BoxShadow(color: Color(0x0A655D56), blurRadius: 12, offset: Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
                alignment: Alignment.center,
                child: Icon(Icons.person, size: 18, color: color),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.onSurface),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text('Gastos Individuais', style: TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant)),
          const SizedBox(height: 4),
          Text(formatMoney(value), style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}

class _SharedCard extends StatelessWidget {
  const _SharedCard({required this.total, required this.half, required this.ignored});

  final double total;
  final double half;
  final double ignored;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.brandCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.surfaceVariant.withValues(alpha: 0.3)),
        boxShadow: const [BoxShadow(color: Color(0x0A655D56), blurRadius: 12, offset: Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(color: AppColors.salvia.withValues(alpha: 0.12), shape: BoxShape.circle),
                alignment: Alignment.center,
                child: const Icon(Icons.group, size: 18, color: AppColors.salvia),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Compartilhado',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.onSurface),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                formatMoney(total),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.onSurface),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: AppColors.surfaceVariant),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _SmallStat(label: 'Cada um', value: half)),
              Expanded(child: _SmallStat(label: 'Ignorados', value: ignored)),
            ],
          ),
        ],
      ),
    );
  }
}

class _SmallStat extends StatelessWidget {
  const _SmallStat({required this.label, required this.value});

  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: AppColors.outline,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          formatMoney(value),
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.douglasToPay});

  final double douglasToPay;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: AppColors.inverseSurface, borderRadius: BorderRadius.circular(24)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'RESULTADO FINAL',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.outlineVariant,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Douglas deve pagar',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.white),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.lavender.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.lavender.withValues(alpha: 0.3)),
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.payments, color: AppColors.lavender, size: 24),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            formatMoney(douglasToPay),
            key: const Key('resumo-douglas-to-pay'),
            style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 12),
          Text(
            'Calculado com base em Gastos Individuais Douglas + 50% dos Gastos Compartilhados.',
            style: TextStyle(fontSize: 13, color: AppColors.outlineVariant),
          ),
        ],
      ),
    );
  }
}
