import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';
import '../../core/database/app_database.dart';
import '../../core/database/tables.dart';
import '../../core/i18n/app_localizations.dart';
import '../../shared/widgets/adaptive_glass_card.dart';
import '../../shared/widgets/math_latex_view.dart';
import '../fsrs_engine/fsrs_v6_scheduler.dart';
import 'dsr_forgetting_curve_painter.dart';
import 'source_context_preview.dart';

/// LAYER 3: The Micro "Deep Detail" Inspector Sheet.
/// Slides up a glassmorphic drawer when tapping any Card, Bubble, or Graph Node:
/// 1. Individual DSR Forgetting Curve Graph (`R(t) = (1 + factor * (t / S))^(-w[20])`)
///    with badges for Difficulty (`D: 4.2/10`), Stability (`S: 18.5 days`), and Retrievability (`R: 91.4%`).
/// 2. Contextual Source Split-View (Zero Orphaned Cards) with 1-tap `"Jump to Full PDF Page X"`.
class CardDeepInspectorSheet extends ConsumerWidget {
  final CardRecord card;
  final VoidCallback? onJumpToFullPdfPage;

  const CardDeepInspectorSheet({
    super.key,
    required this.card,
    this.onJumpToFullPdfPage,
  });

  static Future<void> show(
    BuildContext context, {
    required CardRecord card,
    VoidCallback? onJumpToFullPdfPage,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.86,
        child: CardDeepInspectorSheet(
          card: card,
          onJumpToFullPdfPage: onJumpToFullPdfPage,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(appDatabaseProvider);
    final l10n = ref.watch(l10nProvider);
    const scheduler = FsrsV6Scheduler();
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final liveR = scheduler.liveRetrievabilityForCard(card, nowMs: nowMs);
    final elapsedDays = card.lastReview == null
        ? 0.0
        : ((nowMs - card.lastReview!) / (86400.0 * 1000.0)).clamp(0.0, 365.0);
    final source = db.getSourceById(card.sourceId);

    final healthColor = AppColors.colorForMemoryHealth(
      state: card.state,
      retrievability: liveR,
      stability: card.stability,
      lapses: card.lapses,
    );

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag Handle & Header
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).dividerColor,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Layer 3 • Deep DSR Memory Inspector',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: healthColor.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: healthColor),
                  ),
                  child: Text(
                    card.cardType,
                    style: AppTypography.monoMetric(
                      fontSize: 11,
                      color: healthColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // DSR Metric Badges Row: Difficulty (D), Stability (S), Retrievability (R)
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                _DsrPillBadge(
                  label: l10n.t('metric_difficulty'),
                  value: 'D: ${card.difficulty.toStringAsFixed(1)}/10',
                  color: AppColors.stabilizingAmber,
                ),
                _DsrPillBadge(
                  label: l10n.t('metric_stability'),
                  value: 'S: ${card.stability.toStringAsFixed(1)} days',
                  color: AppColors.unseenElectricSky,
                ),
                _DsrPillBadge(
                  label: l10n.t('metric_retrievability'),
                  value: 'R: ${(liveR * 100).toStringAsFixed(1)}%',
                  color: healthColor,
                ),
                _DsrPillBadge(
                  label: l10n.t('metric_lapses'),
                  value: '${card.lapses}',
                  color: card.lapses >= 3
                      ? AppColors.urgentCrimson
                      : AppColors.masteredEmerald,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 1. Individual DSR Forgetting Curve Graph
            AdaptiveGlassCard(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Power-Law Forgetting Curve: R(t) = (1 + factor · (t / S))^(-w₂₀)',
                    style: AppTypography.monoMetric(
                      fontSize: 11.5,
                      color: AppColors.unseenElectricSky,
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 155,
                    width: double.infinity,
                    child: CustomPaint(
                      painter: DsrForgettingCurvePainter(
                        stabilityDays: card.stability,
                        elapsedDays: elapsedDays,
                        isLightMode:
                            Theme.of(context).brightness == Brightness.light,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // 2. Top Half of Split-View: Flashcard Front & Back with LaTeX & Cloze
            AdaptiveGlassCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'PROMPT / FRONT',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                  const SizedBox(height: 6),
                  MathLatexView(
                    markdownWithLatex: card.frontMd,
                    revealCloze: true,
                  ),
                  const Divider(height: 22),
                  Text(
                    'ANSWER & EXPLANATION / BACK',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                  const SizedBox(height: 6),
                  MathLatexView(
                    markdownWithLatex: card.backMd,
                    revealCloze: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // 3. Bottom Half of Split-View: Contextual Source Preview
            SourceContextPreview(
              card: card,
              source: source,
              onJumpToFullPdfPage: () {
                Navigator.of(context).pop();
                onJumpToFullPdfPage?.call();
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _DsrPillBadge extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _DsrPillBadge({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 2),
          Text(
            value,
            style: AppTypography.monoMetric(fontSize: 12.5, color: color),
          ),
        ],
      ),
    );
  }
}
