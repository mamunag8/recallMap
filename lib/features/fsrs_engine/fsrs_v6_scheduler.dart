import 'dart:convert';
import 'dart:math' as math;
import 'package:uuid/uuid.dart';
import '../../core/constants/fsrs_constants.dart';
import '../../core/database/tables.dart';

/// Result of scheduling a single FSRS-6 rating (`1=Again`, `2=Hard`, `3=Good`, `4=Easy`).
class FsrsScheduleOutcome {
  final CardRecord updatedCard;
  final ReviewLogRecord reviewLog;
  final double liveRetrievabilityBefore;
  final double scheduledIntervalDays;
  final String formattedIntervalLabel;

  const FsrsScheduleOutcome({
    required this.updatedCard,
    required this.reviewLog,
    required this.liveRetrievabilityBefore,
    required this.scheduledIntervalDays,
    required this.formattedIntervalLabel,
  });
}

/// Authentic, unsimplified FSRS-6 (21-parameter DSR memory model) mathematical scheduler.
/// Implements the exact equations for Power-Law Retrievability R(t, S), Next Interval I(r, S),
/// Initial State S_0(G) & D_0(G), Mean-Reverting Difficulty Update, Recall Stability Growth,
/// Lapse Stability Reset, and Short-Term Same-Day Review (t < 1.0 day).
class FsrsV6Scheduler {
  final List<double> w;
  final double desiredRetention;
  static const Uuid _uuid = Uuid();

  const FsrsV6Scheduler({
    this.w = FsrsConstants.defaultWeights,
    this.desiredRetention = FsrsConstants.defaultTargetRetention,
  });

  /// Creates a scheduler instance from a deck's custom JSON weights and target retention.
  factory FsrsV6Scheduler.forDeck(DeckRecord? deck, {double? overrideRetention}) {
    List<double> weights = FsrsConstants.defaultWeights;
    if (deck?.customFsrsWeightsJson != null &&
        deck!.customFsrsWeightsJson!.isNotEmpty) {
      try {
        final parsed = (jsonDecode(deck.customFsrsWeightsJson!) as List)
            .map((e) => (e as num).toDouble())
            .toList();
        if (parsed.length == 21) {
          weights = parsed;
        }
      } catch (_) {}
    }
    return FsrsV6Scheduler(
      w: weights,
      desiredRetention: overrideRetention ??
          deck?.targetRetention ??
          FsrsConstants.defaultTargetRetention,
    );
  }

  /// Equation 1: Power-Law Forgetting Curve & Live Retrievability `R(t, S)`
  /// - `decay = -w[20]`
  /// - `factor = pow(0.9, 1.0 / decay) - 1.0`
  /// - `R(t, S) = pow(1.0 + factor * (t / max(S, 0.01)), decay)`
  double computeRetrievability({
    required double elapsedDays,
    required double stability,
  }) {
    if (stability <= 0.0) return 0.0;
    final t = math.max(0.0, elapsedDays);
    final decay = -w[20];
    final factor = math.pow(0.9, 1.0 / decay) - 1.0;
    final s = math.max(stability, 0.01);
    final r = math.pow(1.0 + factor * (t / s), decay).toDouble();
    return r.clamp(0.0, 1.0);
  }

  /// Computes live Retrievability `R(t, S)` of a [CardRecord] at [nowMs].
  double liveRetrievabilityForCard(CardRecord card, {int? nowMs}) {
    if (card.state == FsrsConstants.stateNew || card.stability <= 0.0) {
      return 0.0;
    }
    final currentMs = nowMs ?? DateTime.now().millisecondsSinceEpoch;
    final lastMs = card.lastReview ?? card.updatedAt;
    final elapsedDays =
        math.max(0.0, (currentMs - lastMs) / (86400.0 * 1000.0));
    return computeRetrievability(
      elapsedDays: elapsedDays,
      stability: card.stability,
    );
  }

  /// Equation 2: Next Interval `I(r, S)` for Desired Retention `r` (default `0.90`)
  /// `I(r, S) = max(1, ((S / factor) * (pow(r, 1.0 / decay) - 1.0)).round())`
  int nextIntervalDays({
    required double stability,
    double? targetRetention,
  }) {
    final r = (targetRetention ?? desiredRetention).clamp(
      FsrsConstants.minTargetRetention,
      FsrsConstants.maxTargetRetention,
    );
    final decay = -w[20];
    final factor = math.pow(0.9, 1.0 / decay) - 1.0;
    final rawInterval =
        (math.max(0.01, stability) / factor) * (math.pow(r, 1.0 / decay) - 1.0);
    return math.max(1, rawInterval.round());
  }

  /// Equation 3: First Rating of an Unseen Card (`state == 0`)
  /// - `S_0(G) = w[G - 1]`
  /// - `D_0(G) = (w[4] - exp(w[5] * (G - 1)) + 1.0).clamp(1.0, 10.0)`
  double initialStability(int rating) {
    final g = rating.clamp(1, 4);
    return math.max(0.01, w[g - 1]);
  }

  double initialDifficulty(int rating) {
    final g = rating.clamp(1, 4);
    final d0 = w[4] - math.exp(w[5] * (g - 1)) + 1.0;
    return d0.clamp(1.0, 10.0);
  }

  /// Equation 4: Difficulty Update on Subsequent Reviews
  /// - `delta_D = -w[6] * (G - 3.0)`
  /// - `D_damped = D + delta_D * ((10.0 - D) / 9.0)`
  /// - `D_next = (w[7] * D_0(4) + (1.0 - w[7]) * D_damped).clamp(1.0, 10.0)`
  double nextDifficulty({
    required double currentDifficulty,
    required int rating,
  }) {
    final g = rating.clamp(1, 4).toDouble();
    final deltaD = -w[6] * (g - 3.0);
    final dDamped =
        currentDifficulty + deltaD * ((10.0 - currentDifficulty) / 9.0);
    final d0Easy = initialDifficulty(FsrsConstants.ratingEasy);
    final dNext = w[7] * d0Easy + (1.0 - w[7]) * dDamped;
    return dNext.clamp(1.0, 10.0);
  }

  /// Equation 5: Stability Update on Successful Recall (`G == 2, 3, or 4`)
  /// - `hardPenalty = (G == 2) ? w[15] : 1.0`
  /// - `easyBonus = (G == 4) ? w[16] : 1.0`
  /// - `S_inc = exp(w[8]) * (11.0 - D) * pow(S, -w[9]) * (exp(w[10] * (1.0 - R)) - 1.0) * hardPenalty * easyBonus`
  /// - `S_next = S * (1.0 + S_inc)`
  double nextRecallStability({
    required double currentStability,
    required double currentDifficulty,
    required double retrievability,
    required int rating,
  }) {
    final s = math.max(0.01, currentStability);
    final d = currentDifficulty.clamp(1.0, 10.0);
    final r = retrievability.clamp(0.0, 1.0);
    final hardPenalty = (rating == FsrsConstants.ratingHard) ? w[15] : 1.0;
    final easyBonus = (rating == FsrsConstants.ratingEasy) ? w[16] : 1.0;

    final sInc = math.exp(w[8]) *
        (11.0 - d) *
        math.pow(s, -w[9]) *
        (math.exp(w[10] * (1.0 - r)) - 1.0) *
        hardPenalty *
        easyBonus;
    return math.max(0.01, s * (1.0 + sInc));
  }

  /// Equation 6: Stability Update on Lapse / Forgetting (`G == 1`)
  /// - `S_lapse = w[11] * pow(D, -w[12]) * (pow(S + 1.0, w[13]) - 1.0) * exp(w[14] * (1.0 - R))`
  /// - `S_next = min(S, max(0.01, S_lapse))`
  double nextLapseStability({
    required double currentStability,
    required double currentDifficulty,
    required double retrievability,
  }) {
    final s = math.max(0.01, currentStability);
    final d = currentDifficulty.clamp(1.0, 10.0);
    final r = retrievability.clamp(0.0, 1.0);

    final sLapse = w[11] *
        math.pow(d, -w[12]) *
        (math.pow(s + 1.0, w[13]) - 1.0) *
        math.exp(w[14] * (1.0 - r));
    return math.min(s, math.max(0.01, sLapse));
  }

  /// Equation 7: Same-Day / Short-Term Review (`t < 1.0` day)
  /// - `S_next = S * exp(w[17] * (G - 3.0 + w[18])) * pow(S, -w[19])`
  double nextShortTermStability({
    required double currentStability,
    required int rating,
  }) {
    final s = math.max(0.01, currentStability);
    final g = rating.clamp(1, 4).toDouble();
    final sNext = s * math.exp(w[17] * (g - 3.0 + w[18])) * math.pow(s, -w[19]);
    return math.max(0.01, sNext);
  }

  /// Evaluates a review of [card] with [rating] (`1=Again, 2=Hard, 3=Good, 4=Easy`)
  /// at [nowMs] and returns the updated card, immutable review log, and formatted interval.
  FsrsScheduleOutcome reviewCard({
    required CardRecord card,
    required int rating,
    int? nowMs,
    int reviewDurationMs = 4500,
    double? overrideTargetRetention,
  }) {
    final g = rating.clamp(1, 4);
    final currentMs = nowMs ?? DateTime.now().millisecondsSinceEpoch;
    final lastMs = card.lastReview;
    final elapsedDays = (lastMs == null || card.state == FsrsConstants.stateNew)
        ? 0.0
        : math.max(0.0, (currentMs - lastMs) / (86400.0 * 1000.0));

    final rBefore = (card.state == FsrsConstants.stateNew)
        ? 0.0
        : computeRetrievability(
            elapsedDays: elapsedDays,
            stability: card.stability,
          );

    double sAfter;
    double dAfter;
    int nextState;
    int nextLapses = card.lapses;

    if (card.state == FsrsConstants.stateNew) {
      sAfter = initialStability(g);
      dAfter = initialDifficulty(g);
      nextState = (g == FsrsConstants.ratingAgain)
          ? FsrsConstants.stateLearning
          : FsrsConstants.stateReview;
    } else if (elapsedDays < 1.0) {
      dAfter = nextDifficulty(currentDifficulty: card.difficulty, rating: g);
      sAfter = nextShortTermStability(
        currentStability: card.stability,
        rating: g,
      );
      if (g == FsrsConstants.ratingAgain) {
        nextState = FsrsConstants.stateRelearning;
        nextLapses += 1;
      } else {
        nextState = FsrsConstants.stateReview;
      }
    } else {
      dAfter = nextDifficulty(currentDifficulty: card.difficulty, rating: g);
      if (g == FsrsConstants.ratingAgain) {
        sAfter = nextLapseStability(
          currentStability: card.stability,
          currentDifficulty: card.difficulty,
          retrievability: rBefore,
        );
        nextState = FsrsConstants.stateRelearning;
        nextLapses += 1;
      } else {
        sAfter = nextRecallStability(
          currentStability: card.stability,
          currentDifficulty: card.difficulty,
          retrievability: rBefore,
          rating: g,
        );
        nextState = FsrsConstants.stateReview;
      }
    }

    double scheduledDays;
    int nextDueMs;
    String intervalLabel;

    if (g == FsrsConstants.ratingAgain) {
      // Short 10-minute re-learning step on lapse while preserving exact FSRS stability S_next
      scheduledDays = 10.0 / (24.0 * 60.0);
      nextDueMs = currentMs + 10 * 60 * 1000;
      intervalLabel = '10m';
    } else {
      final intervalInt = nextIntervalDays(
        stability: sAfter,
        targetRetention: overrideTargetRetention ?? desiredRetention,
      );
      scheduledDays = intervalInt.toDouble();
      nextDueMs = currentMs + intervalInt * 86400 * 1000;
      intervalLabel = formatIntervalDays(scheduledDays);
    }

    final isLeech = nextLapses >= FsrsConstants.leechLapseThreshold;

    final updatedCard = card.copyWith(
      state: nextState,
      dueDate: nextDueMs,
      stability: sAfter,
      difficulty: dAfter,
      elapsedDays: elapsedDays,
      scheduledDays: scheduledDays,
      reps: card.reps + 1,
      lapses: nextLapses,
      lastReview: currentMs,
      isLeech: isLeech,
      updatedAt: currentMs,
    );

    final log = ReviewLogRecord(
      id: _uuid.v4(),
      cardId: card.id,
      rating: g,
      stateBefore: card.state,
      stabilityBefore: card.stability,
      difficultyBefore: card.difficulty,
      stabilityAfter: sAfter,
      difficultyAfter: dAfter,
      elapsedDays: elapsedDays,
      scheduledDays: scheduledDays,
      reviewDurationMs: reviewDurationMs,
      reviewedAt: currentMs,
    );

    return FsrsScheduleOutcome(
      updatedCard: updatedCard,
      reviewLog: log,
      liveRetrievabilityBefore: rBefore,
      scheduledIntervalDays: scheduledDays,
      formattedIntervalLabel: intervalLabel,
    );
  }

  /// Previews all 4 rating outcomes (`1=Again, 2=Hard, 3=Good, 4=Easy`) for the live Study Player bar.
  Map<int, FsrsScheduleOutcome> previewAllRatings(
    CardRecord card, {
    int? nowMs,
    double? overrideTargetRetention,
  }) {
    final ts = nowMs ?? DateTime.now().millisecondsSinceEpoch;
    return {
      FsrsConstants.ratingAgain: reviewCard(
        card: card,
        rating: FsrsConstants.ratingAgain,
        nowMs: ts,
        overrideTargetRetention: overrideTargetRetention,
      ),
      FsrsConstants.ratingHard: reviewCard(
        card: card,
        rating: FsrsConstants.ratingHard,
        nowMs: ts,
        overrideTargetRetention: overrideTargetRetention,
      ),
      FsrsConstants.ratingGood: reviewCard(
        card: card,
        rating: FsrsConstants.ratingGood,
        nowMs: ts,
        overrideTargetRetention: overrideTargetRetention,
      ),
      FsrsConstants.ratingEasy: reviewCard(
        card: card,
        rating: FsrsConstants.ratingEasy,
        nowMs: ts,
        overrideTargetRetention: overrideTargetRetention,
      ),
    };
  }

  /// Formats an interval in days into a compact human-readable badge (`10m`, `3d`, `2.4mo`, `1.2y`).
  static String formatIntervalDays(double days) {
    if (days < 1.0) {
      final mins = math.max(1, (days * 24.0 * 60.0).round());
      return '${mins}m';
    }
    final rounded = days.round();
    if (rounded < 31) {
      return '${rounded}d';
    }
    if (rounded < 365) {
      return '${(rounded / 30.0).toStringAsFixed(1)}mo';
    }
    return '${(rounded / 365.0).toStringAsFixed(1)}y';
  }
}
