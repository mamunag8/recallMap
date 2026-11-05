import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';
import '../../core/constants/fsrs_constants.dart';
import '../../core/database/tables.dart';
import '../../core/i18n/app_localizations.dart';
import '../fsrs_engine/fsrs_v6_scheduler.dart';

/// Per-page aggregated FSRS-6 retention state for the Visual PDF Page Mastery Strip.
class PdfPageMasteryStat {
  final int pageNumber;
  final int cardCount;
  final double avgRetrievability; // 0.0 .. 1.0
  final double avgStabilityDays;
  final int leechCount;
  final Color barColor;

  const PdfPageMasteryStat({
    required this.pageNumber,
    required this.cardCount,
    required this.avgRetrievability,
    required this.avgStabilityDays,
    required this.leechCount,
    required this.barColor,
  });

  bool get isWeakOrCrimson =>
      cardCount > 0 && (avgRetrievability < 0.80 || leechCount > 0);
}

/// LAYER 2 (Hero Feature 1): The Visual PDF Page Mastery Strip.
/// Renders a sleek Vertical Page Mastery Minimap along the right edge of the PDF reader.
/// Every single page in the PDF displays a color-coded retention bar
/// (Crimson / Amber / Emerald / Unstudied Slate) calculated live from the FSRS Retrievability R
/// of all flashcards extracted from that specific page.
class PdfPageMasteryStrip extends ConsumerWidget {
  final int totalPages;
  final int currentPage;
  final List<CardRecord> sourceCards;
  final ValueChanged<int> onSelectPage;
  final ValueChanged<List<int>>? onStudyWeakPages;

  const PdfPageMasteryStrip({
    super.key,
    required this.totalPages,
    required this.currentPage,
    required this.sourceCards,
    required this.onSelectPage,
    this.onStudyWeakPages,
  });

  static List<PdfPageMasteryStat> computePageStats({
    required int totalPages,
    required List<CardRecord> sourceCards,
    int? nowMs,
  }) {
    final currentMs = nowMs ?? DateTime.now().millisecondsSinceEpoch;
    const scheduler = FsrsV6Scheduler();
    final stats = <PdfPageMasteryStat>[];

    for (var page = 1; page <= totalPages; page++) {
      final pageCards =
          sourceCards.where((c) => (c.sourcePage ?? 1) == page).toList();
      if (pageCards.isEmpty) {
        stats.add(
          PdfPageMasteryStat(
            pageNumber: page,
            cardCount: 0,
            avgRetrievability: 0.0,
            avgStabilityDays: 0.0,
            leechCount: 0,
            barColor: AppColors.unstudiedSlate,
          ),
        );
        continue;
      }

      double sumR = 0.0;
      double sumS = 0.0;
      int reviewed = 0;
      int unseen = 0;
      int leeches = 0;

      for (final c in pageCards) {
        if (c.state == FsrsConstants.stateNew) {
          unseen++;
        } else {
          final r = scheduler.liveRetrievabilityForCard(c, nowMs: currentMs);
          sumR += r;
          sumS += c.stability;
          reviewed++;
          if (c.isLeech || c.lapses >= 3) leeches++;
        }
      }

      final avgR = reviewed == 0 ? 0.0 : (sumR / reviewed);
      final avgS = reviewed == 0 ? 0.0 : (sumS / reviewed);
      final color = leeches > 0
          ? AppColors.urgentCrimson
          : AppColors.colorForAggregateRetention(
              avgRetrievability: avgR,
              avgStability: avgS,
              totalCards: pageCards.length,
              unseenCards: unseen,
            );

      stats.add(
        PdfPageMasteryStat(
          pageNumber: page,
          cardCount: pageCards.length,
          avgRetrievability: avgR,
          avgStabilityDays: avgS,
          leechCount: leeches,
          barColor: color,
        ),
      );
    }

    return stats;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    final stats = computePageStats(
      totalPages: totalPages,
      sourceCards: sourceCards,
    );
    final weakPageNumbers =
        stats.where((s) => s.isWeakOrCrimson).map((s) => s.pageNumber).toList();

    return Container(
      width: 66,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        children: [
          const Tooltip(
            message: 'Live FSRS-6 PDF Page Mastery Minimap',
            child: Icon(
              Icons.view_week_rounded,
              size: 16,
              color: AppColors.sourceRoyalIndigo,
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: ListView.builder(
              itemCount: stats.length,
              itemBuilder: (context, index) {
                final stat = stats[index];
                final isCurrent = stat.pageNumber == currentPage;
                final pctText = stat.cardCount == 0
                    ? '—'
                    : '${l10n.formatNumber((stat.avgRetrievability * 100).round())}%';

                return GestureDetector(
                  onTap: () => onSelectPage(stat.pageNumber),
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding:
                        const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                    decoration: BoxDecoration(
                      color: stat.barColor
                          .withValues(alpha: isCurrent ? 0.28 : 0.14),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isCurrent
                            ? stat.barColor
                            : stat.barColor.withValues(alpha: 0.45),
                        width: isCurrent ? 2.0 : 1.0,
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 6,
                              height: 18,
                              decoration: BoxDecoration(
                                color: stat.barColor,
                                borderRadius: BorderRadius.circular(99),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'P${l10n.formatNumber(stat.pageNumber)}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: isCurrent
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          pctText,
                          style: AppTypography.monoMetric(
                            fontSize: 10,
                            color: stat.barColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          if (weakPageNumbers.isNotEmpty) ...[
            const SizedBox(height: 6),
            Tooltip(
              message:
                  '${l10n.t('study_weak_pages')} (P.${weakPageNumbers.join(",")})',
              child: InkWell(
                onTap: () => onStudyWeakPages?.call(weakPageNumbers),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.urgentCrimson.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.urgentCrimson),
                  ),
                  child: const Column(
                    children: [
                      Icon(
                        Icons.local_fire_department_rounded,
                        size: 16,
                        color: AppColors.urgentCrimson,
                      ),
                      Text(
                        'Weak',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.urgentCrimson,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
