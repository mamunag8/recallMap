import 'dart:math' as math;
import '../../core/constants/fsrs_constants.dart';
import '../../core/database/tables.dart';
import 'fsrs_v6_scheduler.dart';

class ExamCountdownPlan {
  final String deckId;
  final String deckTitle;
  final int daysLeft;
  final int totalCards;
  final int unseenCardCount;
  final int dueTodayCount;
  final int recommendedDailyNew;
  final double dynamicTargetRetention;
  final double currentReadinessPercent;
  final int estimatedDailyMinutes;
  final bool isFinalSprintWindow;

  const ExamCountdownPlan({
    required this.deckId,
    required this.deckTitle,
    required this.daysLeft,
    required this.totalCards,
    required this.unseenCardCount,
    required this.dueTodayCount,
    required this.recommendedDailyNew,
    required this.dynamicTargetRetention,
    required this.currentReadinessPercent,
    required this.estimatedDailyMinutes,
    required this.isFinalSprintWindow,
  });
}

/// Smart Exam Deadline Back-Calculator.
/// - Automatically computes `recommended_daily_new = ceil(unseen_card_count / max(1, days_left - 7))`
///   so all material enters long-term review at least 1 week before the exam.
/// - Dynamically scales `target_retention` from `0.90` up to `0.95` during the final 14 days
///   so the student reaches peak recall on exam day.
class ExamCountdownPlanner {
  ExamCountdownPlanner._();

  static ExamCountdownPlan computePlan({
    required DeckRecord deck,
    required List<CardRecord> deckCards,
    int? nowMs,
  }) {
    final currentMs = nowMs ?? DateTime.now().millisecondsSinceEpoch;
    final examMs = deck.examDate ?? (currentMs + 14 * 86400 * 1000);
    final daysLeft =
        math.max(1, ((examMs - currentMs) / (86400.0 * 1000.0)).ceil());

    final unseenCount =
        deckCards.where((c) => c.state == FsrsConstants.stateNew).length;
    final dueTodayCount = deckCards
        .where(
          (c) => c.state != FsrsConstants.stateNew && c.dueDate <= currentMs,
        )
        .length;

    // Formula: recommended_daily_new = ceil(unseen_card_count / max(1, days_left - 7))
    final effectiveNewWindow = math.max(1, daysLeft - 7);
    final recommendedDailyNew = (unseenCount / effectiveNewWindow).ceil();

    // Dynamic target_retention scaling from base (0.90) up to 0.95 during the final 14 days
    final baseRetention = deck.targetRetention;
    double dynamicRetention = baseRetention;
    final isFinalSprint = daysLeft <= 14;
    if (isFinalSprint) {
      final sprintProgress = ((14 - daysLeft) / 14.0).clamp(0.0, 1.0);
      dynamicRetention = baseRetention +
          (FsrsConstants.examPeakRetention - baseRetention) * sprintProgress;
    }

    final scheduler = FsrsV6Scheduler.forDeck(
      deck,
      overrideRetention: dynamicRetention,
    );
    double sumRetrievability = 0.0;
    int activeReviewed = 0;
    for (final c in deckCards) {
      if (c.state != FsrsConstants.stateNew && c.stability > 0) {
        sumRetrievability +=
            scheduler.liveRetrievabilityForCard(c, nowMs: currentMs);
        activeReviewed++;
      }
    }

    final readinessPercent = activeReviewed == 0
        ? 0.0
        : ((sumRetrievability / activeReviewed) * 100.0).clamp(0.0, 100.0);

    final totalTodayCards = dueTodayCount + recommendedDailyNew;
    final estimatedDailyMinutes =
        math.max(1, ((totalTodayCards * 12.0) / 60.0).ceil());

    return ExamCountdownPlan(
      deckId: deck.id,
      deckTitle: deck.title,
      daysLeft: daysLeft,
      totalCards: deckCards.length,
      unseenCardCount: unseenCount,
      dueTodayCount: dueTodayCount,
      recommendedDailyNew: recommendedDailyNew,
      dynamicTargetRetention: dynamicRetention,
      currentReadinessPercent: readinessPercent,
      estimatedDailyMinutes: estimatedDailyMinutes,
      isFinalSprintWindow: isFinalSprint,
    );
  }
}
