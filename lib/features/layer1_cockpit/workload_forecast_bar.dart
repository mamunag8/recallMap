import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';
import '../../core/constants/fsrs_constants.dart';
import '../../core/database/app_database.dart';
import '../../core/database/tables.dart';
import '../../core/i18n/app_localizations.dart';
import '../../shared/widgets/adaptive_glass_card.dart';
import '../fsrs_engine/exam_countdown_planner.dart';
import '../fsrs_engine/vacation_backlog_smoother.dart';

/// Hero Visual 3 (Part B) — 7-Day Workload Forecast Bar Chart,
/// paired with the 1-Tap "Smooth Overdue Backlog" action and Exam Countdown Planner.
class WorkloadForecastBar extends ConsumerWidget {
  final List<DeckRecord> decks;
  final List<CardRecord> cards;

  const WorkloadForecastBar({
    super.key,
    required this.decks,
    required this.cards,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    final db = ref.read(appDatabaseProvider);
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    const dayMs = 86400 * 1000;

    // Bucket due cards across the next 7 days (Day 0 = Today + Overdue)
    final dailyCounts = List<int>.filled(7, 0);
    for (final c in cards) {
      if (c.isSuspended || c.state == FsrsConstants.stateNew) continue;
      final diffDays = ((c.dueDate - nowMs) / dayMs).floor();
      if (diffDays <= 0) {
        dailyCounts[0]++;
      } else if (diffDays < 7) {
        dailyCounts[diffDays]++;
      }
    }

    final maxCount = math.max(1, dailyCounts.reduce(math.max));
    const dayLabels = ['Today', '+1d', '+2d', '+3d', '+4d', '+5d', '+6d'];

    return AdaptiveGlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  l10n.t('workload_forecast'),
                  style: Theme.of(context).textTheme.titleMedium,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Wrap(
                spacing: 6,
                children: [
                  OutlinedButton.icon(
                    onPressed: () async {
                      final report =
                          await VacationBacklogSmoother.smoothOverdueBacklog(
                        db: db,
                        recoveryWindowDays: 5,
                      );
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              '${l10n.t('backlog_smoothed_toast')} (${report.totalOverdueCardsSmoothed} cards → ${report.cardsPerDay}/day)',
                            ),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.waves_rounded, size: 14),
                    label: Text(
                      l10n.t('smooth_backlog_btn'),
                      style: const TextStyle(fontSize: 11),
                    ),
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _showExamPlannerModal(context, decks, cards),
                    icon: const Icon(Icons.event_available_rounded, size: 14),
                    label: Text(
                      l10n.t('exam_planner_btn'),
                      style: const TextStyle(fontSize: 11),
                    ),
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 110,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(7, (idx) {
                final count = dailyCounts[idx];
                final heightFactor = (count / maxCount).clamp(0.08, 1.0);
                final barColor = idx == 0 && count > 0
                    ? AppColors.urgentCrimson
                    : (idx <= 2
                        ? AppColors.stabilizingAmber
                        : AppColors.sourceRoyalIndigo);

                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          l10n.formatNumber(count),
                          style: AppTypography.monoMetric(
                            fontSize: 11,
                            color: barColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          height: 64 * heightFactor,
                          decoration: BoxDecoration(
                            color: barColor.withValues(alpha: 0.85),
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          dayLabels[idx],
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  void _showExamPlannerModal(
    BuildContext context,
    List<DeckRecord> decks,
    List<CardRecord> allCards,
  ) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Smart Exam Deadline Back-Calculator',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 6),
                Text(
                  'Formula: recommended_daily_new = ceil(unseen / max(1, days_left - 7)) • Dynamic Target Retention scales 0.90 → 0.95 in final 14 days.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 14),
                ...decks.take(4).map((deck) {
                  final deckCards = allCards
                      .where((c) => c.deckId == deck.id || deck.parentId == null)
                      .toList();
                  final plan = ExamCountdownPlanner.computePlan(
                    deck: deck,
                    deckCards: deckCards,
                  );
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.sourceRoyalIndigo.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                plan.deckTitle,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                '${plan.daysLeft} days left • Target R: ${(plan.dynamicTargetRetention * 100).toStringAsFixed(1)}%',
                                style: Theme.of(context).textTheme.labelSmall,
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '${plan.recommendedDailyNew} new/d • ~${plan.estimatedDailyMinutes}m',
                          style: AppTypography.monoMetric(
                            fontSize: 12,
                            color: AppColors.masteredEmerald,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }
}
