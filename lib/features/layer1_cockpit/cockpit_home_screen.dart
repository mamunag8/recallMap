import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';
import '../../core/constants/fsrs_constants.dart';
import '../../core/database/app_database.dart';
import '../../core/database/tables.dart';
import '../../core/i18n/app_localizations.dart';
import '../../shared/widgets/adaptive_glass_card.dart';
import '../../shared/widgets/language_selector_pill.dart';
import '../../shared/widgets/math_latex_view.dart';
import '../../shared/widgets/sync_pill_indicator.dart';
import '../fsrs_engine/fsrs_v6_scheduler.dart';
import '../fsrs_engine/memory_doctor_analyzer.dart';
import 'exam_readiness_ring.dart';
import 'mastery_sunburst_bubble_map.dart';
import 'spotlight_tutorial_overlay.dart';
import 'study_heatmap_365.dart';
import 'workload_forecast_bar.dart';

/// LAYER 1: The Macro "At-a-Glance" Cockpit (Home Screen — Tab 1).
/// Designed so the student understands their complete memory state visually in under 2 seconds:
/// 1. Top Global Bar: Instant FTS5 Search Bar, Language Switcher Pill (`🌐 EN / বাংলা / TR...`), Cloud Sync Pill.
/// 2. Interactive Demo Deck Banner (`[✨ Exploring Interactive Demo Deck — Tap to Clear Demo Data Anytime]`).
/// 3. Hero Visual 1: Exam Readiness Ring (Overall Memory Readiness %, Due Now, New Today, Study Streak 🔥).
/// 4. Hero Visual 2: Interactive Mastery Sunburst / Bubble Map (Single-tap stats, Double-tap zoom to Layer 2).
/// 5. Built-In Memory Doctor Clinic (Leech & BM25 Confusable Twin Radar + 1-Tap Card Surgery).
/// 6. Hero Visual 3: 365-Day Study Heatmap & 7-Day Workload Forecast.
/// 7. Primary Floating Action Pill: `"▶ Start High-Yield Session"`.
class CockpitHomeScreen extends ConsumerStatefulWidget {
  final ValueChanged<String>? onNavigateToXRayForDeck;
  final ValueChanged<CardRecord>? onInspectCardLayer3;
  final VoidCallback? onStartHighYieldSession;
  final ValueChanged<CardRecord>? onJumpToPdfSource;

  const CockpitHomeScreen({
    super.key,
    this.onNavigateToXRayForDeck,
    this.onInspectCardLayer3,
    this.onStartHighYieldSession,
    this.onJumpToPdfSource,
  });

  @override
  ConsumerState<CockpitHomeScreen> createState() => _CockpitHomeScreenState();
}

class _CockpitHomeScreenState extends ConsumerState<CockpitHomeScreen> {
  bool _showSpotlightTour = false;

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(appDatabaseProvider);
    final l10n = ref.watch(l10nProvider);
    final localeSettings = ref.watch(appLocaleProvider);

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    const scheduler = FsrsV6Scheduler();

    final allCards = db.cards.where((c) => !c.isSuspended).toList();
    final allDecks = db.decks;
    final allLogs = db.reviewLogs;

    // Compute live macro FSRS-6 metrics across all cards
    int dueNowCount = 0;
    int newTodayCount = 0;
    int masteredCount = 0;
    int stabilizingCount = 0;
    int urgentCount = 0;
    double weightedRetrievabilitySum = 0.0;
    int activeReviewedCount = 0;

    for (final c in allCards) {
      if (c.state == FsrsConstants.stateNew) {
        newTodayCount++;
        continue;
      }
      final r = scheduler.liveRetrievabilityForCard(c, nowMs: nowMs);
      weightedRetrievabilitySum += r;
      activeReviewedCount++;

      if (c.dueDate <= nowMs) {
        dueNowCount++;
      }

      final tier = AppColors.classifyMemoryHealth(
        state: c.state,
        retrievability: r,
        stability: c.stability,
        lapses: c.lapses,
      );
      switch (tier) {
        case MemoryHealthTier.masteredLongTerm:
          masteredCount++;
        case MemoryHealthTier.stabilizingShortTerm:
          stabilizingCount++;
        case MemoryHealthTier.urgentDecaying:
          urgentCount++;
        case MemoryHealthTier.unseenNew:
          break;
      }
    }

    final overallReadinessPct = activeReviewedCount == 0
        ? 0.0
        : ((weightedRetrievabilitySum / activeReviewedCount) * 100.0)
            .clamp(0.0, 100.0);

    // Closest exam date countdown
    int daysLeftToExam = 14;
    final examDates = allDecks
        .where((d) => d.examDate != null && d.examDate! > nowMs)
        .map((d) => d.examDate!)
        .toList();
    if (examDates.isNotEmpty) {
      examDates.sort();
      daysLeftToExam =
          ((examDates.first - nowMs) / (86400.0 * 1000.0)).ceil().clamp(1, 365);
    }

    final studyStreakDays =
        StudyHeatmap365.computeCurrentStreak(allLogs, nowMs: nowMs);

    // Build DeckMasteryVisualNode list for the Mastery Sunburst / Bubble Map
    final visualNodes = allDecks.map((deck) {
      final deckCards = allCards
          .where((c) => c.deckId == deck.id || (deck.parentId == null))
          .toList();
      var sumR = 0.0;
      var sumS = 0.0;
      var reviewed = 0;
      var due = 0;
      var unseen = 0;
      var leeches = 0;

      for (final c in deckCards) {
        if (c.state == FsrsConstants.stateNew) {
          unseen++;
        } else {
          final r = scheduler.liveRetrievabilityForCard(c, nowMs: nowMs);
          sumR += r;
          sumS += c.stability;
          reviewed++;
          if (c.dueDate <= nowMs) due++;
          if (c.isLeech || c.lapses >= 3) leeches++;
        }
      }

      final avgR = reviewed == 0 ? 0.90 : (sumR / reviewed);
      final avgS = reviewed == 0 ? 0.0 : (sumS / reviewed);
      final healthColor = AppColors.colorForAggregateRetention(
        avgRetrievability: avgR,
        avgStability: avgS,
        totalCards: deckCards.length,
        unseenCards: unseen,
      );

      return DeckMasteryVisualNode(
        deckId: deck.id,
        parentId: deck.parentId,
        title: deck.title,
        totalCards: deckCards.length,
        dueCards: due,
        unseenCards: unseen,
        avgRetrievability: avgR,
        avgStabilityDays: avgS,
        leechCount: leeches,
        healthColor: healthColor,
      );
    }).toList();

    // Memory Doctor Clinic diagnostics
    final leechReports = MemoryDoctorAnalyzer.diagnoseVault(db, nowMs: nowMs);
    final highYieldSessionCount = dueNowCount + newTodayCount;
    final estimatedSessionMins =
        ((highYieldSessionCount * 15) / 60).ceil().clamp(1, 45);

    return Stack(
      children: [
        Scaffold(
          body: SafeArea(
            child: CustomScrollView(
              slivers: [
                // 1. Top Global Bar: Instant Search + Language Pill + Cloud Sync Pill
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => _openUniversalFts5SearchModal(context),
                            borderRadius: BorderRadius.circular(999),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: Theme.of(context).cardColor,
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: Theme.of(context).dividerColor,
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.search_rounded,
                                    size: 18,
                                    color: AppColors.unseenElectricSky,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      l10n.t('search_placeholder'),
                                      style:
                                          Theme.of(context).textTheme.bodyMedium,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const LanguageSelectorPill(),
                        const SizedBox(width: 8),
                        const SyncPillIndicator(),
                        const SizedBox(width: 4),
                        IconButton(
                          tooltip: '60-Second Interactive Spotlight Tour',
                          onPressed: () =>
                              setState(() => _showSpotlightTour = true),
                          icon: const Icon(
                            Icons.help_outline_rounded,
                            size: 20,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // 2. Pre-Loaded Interactive Demo Deck 1-Tap Banner
                if (db.hasDemoData)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      child: InkWell(
                        onTap: () async {
                          await db.clearDemoData();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(l10n.t('demo_clear_confirm')),
                                action: SnackBarAction(
                                  label: 'Restore Demo',
                                  onPressed: () => db.reseedDemoData(),
                                ),
                              ),
                            );
                          }
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 9,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppColors.sourceRoyalIndigo
                                    .withValues(alpha: 0.22),
                                AppColors.masteredEmerald
                                    .withValues(alpha: 0.18),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.sourceRoyalIndigo
                                  .withValues(alpha: 0.5),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.auto_awesome_rounded,
                                size: 16,
                                color: AppColors.unseenElectricSky,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  l10n.t('demo_banner_text'),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const Icon(
                                Icons.delete_sweep_rounded,
                                size: 18,
                                color: AppColors.stabilizingAmber,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                // 3. Hero Visual 1 — The Exam Readiness Ring
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: ExamReadinessRing(
                      readinessPercent: overallReadinessPct,
                      daysLeftToExam: daysLeftToExam,
                      dueNowCount: dueNowCount,
                      newTodayCount: newTodayCount,
                      studyStreakDays: studyStreakDays,
                      masteredCount: masteredCount,
                      stabilizingCount: stabilizingCount,
                      urgentCount: urgentCount,
                      onRingTap: widget.onStartHighYieldSession,
                    ),
                  ),
                ),

                // 4. Hero Visual 2 — Interactive Mastery Sunburst / Bubble Map
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: MasterySunburstBubbleMap(
                      nodes: visualNodes,
                      onNodeDoubleTap: (node) {
                        widget.onNavigateToXRayForDeck?.call(node.deckId);
                      },
                    ),
                  ),
                ),

                // 5. Built-In "Memory Doctor" Clinic (Leech & Confusable Twin Radar)
                if (leechReports.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: _MemoryDoctorClinicCard(
                        reports: leechReports,
                        onInspectCard: widget.onInspectCardLayer3,
                        onJumpToPdf: widget.onJumpToPdfSource,
                      ),
                    ),
                  ),

                // 6. Hero Visual 3 — 365-Day Study Heatmap & 7-Day Workload Forecast
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: StudyHeatmap365(reviewLogs: allLogs),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                    child: WorkloadForecastBar(
                      decks: allDecks,
                      cards: allCards,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 7. Primary Floating Action Pill: "▶ Start High-Yield Session"
          floatingActionButtonLocation:
              FloatingActionButtonLocation.centerFloat,
          floatingActionButton: FloatingActionButton.extended(
            onPressed: widget.onStartHighYieldSession,
            backgroundColor: AppColors.masteredEmerald,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.play_arrow_rounded),
            label: Text(
              '${l10n.t('start_high_yield_cta')} (${l10n.formatNumber(highYieldSessionCount)} ${l10n.t('cards_unit')} • ~${l10n.formatNumber(estimatedSessionMins)} ${l10n.t('mins_unit')})',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ),

        // 60-Second Interactive Onboarding & Spotlight Coach-Marks
        if (!localeSettings.hasCompletedOnboarding || _showSpotlightTour)
          Positioned.fill(
            child: SpotlightTutorialOverlay(
              onFinished: () => setState(() => _showSpotlightTour = false),
            ),
          ),
      ],
    );
  }

  void _openUniversalFts5SearchModal(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        String query = '';
        return StatefulBuilder(
          builder: (context, setModalState) {
            final db = ref.watch(appDatabaseProvider);
            final l10n = ref.watch(l10nProvider);
            final hits = query.isEmpty
                ? db.studyDao.searchAll('Bernoulli মাইটোকন্ড্রিয়া Xylem')
                : db.studyDao.searchAll(query);

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 16,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      autofocus: true,
                      onChanged: (v) => setModalState(() => query = v),
                      decoration: InputDecoration(
                        hintText: l10n.t('search_placeholder'),
                        prefixIcon: const Icon(Icons.search_rounded),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 340),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: hits.length,
                        itemBuilder: (context, index) {
                          final hit = hits[index];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: hit.entityType == 'CARD'
                                  ? AppColors.unseenElectricSky
                                      .withValues(alpha: 0.2)
                                  : AppColors.sourceRoyalIndigo
                                      .withValues(alpha: 0.2),
                              child: Icon(
                                hit.entityType == 'CARD'
                                    ? Icons.style_rounded
                                    : Icons.picture_as_pdf_rounded,
                                size: 18,
                              ),
                            ),
                            title: Text(
                              hit.titleOrFront,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              hit.bodyOrBack,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: Text(
                              'BM25 ${hit.bm25Score.toStringAsFixed(1)}',
                              style: AppTypography.monoMetric(
                                fontSize: 11,
                                color: AppColors.masteredEmerald,
                              ),
                            ),
                            onTap: () {
                              Navigator.of(context).pop();
                              if (hit.entityType == 'CARD') {
                                final card = db.getCardById(hit.entityId);
                                if (card != null) {
                                  widget.onInspectCardLayer3?.call(card);
                                }
                              }
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _MemoryDoctorClinicCard extends ConsumerWidget {
  final List<LeechDiagnosisReport> reports;
  final ValueChanged<CardRecord>? onInspectCard;
  final ValueChanged<CardRecord>? onJumpToPdf;

  const _MemoryDoctorClinicCard({
    required this.reports,
    this.onInspectCard,
    this.onJumpToPdf,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    final db = ref.read(appDatabaseProvider);
    final primaryReport = reports.first;
    final leech = primaryReport.leechCard;
    final twin = primaryReport.confusableTwins.isNotEmpty
        ? primaryReport.confusableTwins.first
        : null;

    return AdaptiveGlassCard(
      accentBorderColor: AppColors.urgentCrimson.withValues(alpha: 0.6),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.medical_services_rounded,
                color: AppColors.urgentCrimson,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.t('memory_doctor_title'),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.urgentCrimson,
                      ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.urgentCrimson.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'Lapses: ${l10n.formatNumber(leech.lapses)} • R: ${l10n.formatNumber((primaryReport.liveRetrievability * 100).round())}%',
                  style: AppTypography.monoMetric(
                    fontSize: 11,
                    color: AppColors.urgentCrimson,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Side-by-Side "Compare Twins" Diff View
          if (twin != null) ...[
            Text(
              '⚡ ${l10n.t('confusable_twins_badge')}: Differing terms highlighted below',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.stabilizingAmber,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _TwinComparisonBox(
                    badge: 'Leech Card (Page ${leech.sourcePage ?? 1})',
                    tokens: primaryReport.primaryDiffTokens,
                    highlightColor: AppColors.urgentCrimson,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _TwinComparisonBox(
                    badge: 'Confusable Twin (BM25 Match)',
                    tokens: primaryReport.twinDiffTokens,
                    highlightColor: AppColors.stabilizingAmber,
                  ),
                ),
              ],
            ),
          ] else
            MathLatexView(markdownWithLatex: leech.frontMd),

          const SizedBox(height: 12),

          // 1-Tap Card Surgery Actions
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonalIcon(
                onPressed: () async {
                  final created =
                      await MemoryDoctorAnalyzer.splitIntoTwoAtomicClozeCards(
                    db: db,
                    leechCard: leech,
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Split leech into ${created.length} atomic Cloze cards!',
                        ),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.call_split_rounded, size: 15),
                label: Text(
                  l10n.t('surgery_split_cloze'),
                  style: const TextStyle(fontSize: 11.5),
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => onInspectCard?.call(leech),
                icon: const Icon(Icons.show_chart_rounded, size: 15),
                label: const Text(
                  'Inspect DSR Curve',
                  style: TextStyle(fontSize: 11.5),
                ),
              ),
              if (leech.sourceId != null)
                OutlinedButton.icon(
                  onPressed: () => onJumpToPdf?.call(leech),
                  icon: const Icon(Icons.picture_as_pdf_rounded, size: 15),
                  label: Text(
                    '${l10n.t('surgery_jump_pdf')} (P.${leech.sourcePage ?? 1})',
                    style: const TextStyle(fontSize: 11.5),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TwinComparisonBox extends StatelessWidget {
  final String badge;
  final List<TwinWordToken> tokens;
  final Color highlightColor;

  const _TwinComparisonBox({
    required this.badge,
    required this.tokens,
    required this.highlightColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: highlightColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: highlightColor.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            badge,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: highlightColor,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 4,
            runSpacing: 3,
            children: tokens.map((token) {
              return Container(
                padding: token.isDifferingTerm
                    ? const EdgeInsets.symmetric(horizontal: 4, vertical: 1)
                    : EdgeInsets.zero,
                decoration: token.isDifferingTerm
                    ? BoxDecoration(
                        color: highlightColor.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(4),
                      )
                    : null,
                child: Text(
                  token.text,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: token.isDifferingTerm
                        ? FontWeight.w700
                        : FontWeight.w400,
                    color: token.isDifferingTerm ? highlightColor : null,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
