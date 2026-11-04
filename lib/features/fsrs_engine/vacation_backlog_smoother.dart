import 'dart:math' as math;
import '../../core/constants/fsrs_constants.dart';
import '../../core/database/app_database.dart';
import '../../core/database/tables.dart';
import 'fsrs_v6_scheduler.dart';

class BacklogSmoothReport {
  final int totalOverdueCardsSmoothed;
  final int recoveryWindowDays;
  final int cardsPerDay;
  final double lowestRetrievabilityPrioritized;

  const BacklogSmoothReport({
    required this.totalOverdueCardsSmoothed,
    required this.recoveryWindowDays,
    required this.cardsPerDay,
    required this.lowestRetrievabilityPrioritized,
  });
}

/// Zero-Guilt Vacation / Sick-Day Backlog Smoother.
/// Takes all overdue cards, sorts them ascending by live Retrievability `R(t, S)`
/// (most fragile memories first), and distributes them evenly across the user's
/// chosen recovery window (3 to 14 days).
class VacationBacklogSmoother {
  VacationBacklogSmoother._();

  static Future<BacklogSmoothReport> smoothOverdueBacklog({
    required AppDatabase db,
    int recoveryWindowDays = 5,
    int? nowMs,
  }) async {
    final window = recoveryWindowDays.clamp(3, 14);
    final currentMs = nowMs ?? DateTime.now().millisecondsSinceEpoch;
    const dayMs = 86400 * 1000;
    const scheduler = FsrsV6Scheduler();

    final overdueEntries = <MapEntry<CardRecord, double>>[];
    for (final card in db.cards) {
      if (card.isSuspended || card.state == FsrsConstants.stateNew) continue;
      if (card.dueDate <= currentMs) {
        final r = scheduler.liveRetrievabilityForCard(card, nowMs: currentMs);
        overdueEntries.add(MapEntry(card, r));
      }
    }

    if (overdueEntries.isEmpty) {
      return BacklogSmoothReport(
        totalOverdueCardsSmoothed: 0,
        recoveryWindowDays: window,
        cardsPerDay: 0,
        lowestRetrievabilityPrioritized: 1.0,
      );
    }

    // Sort ascending by live Retrievability R(t, S) so the most fragile memories are reviewed Day 0 / Day 1
    overdueEntries.sort((a, b) => a.value.compareTo(b.value));

    final totalOverdue = overdueEntries.length;
    final perDay = math.max(1, (totalOverdue / window).ceil());
    final updatedBatch = <CardRecord>[];

    for (var i = 0; i < totalOverdue; i++) {
      final assignedDayOffset = (i ~/ perDay).clamp(0, window - 1);
      final card = overdueEntries[i].key;
      final newDueDate = currentMs + assignedDayOffset * dayMs;
      updatedBatch.add(
        card.copyWith(
          dueDate: newDueDate,
          updatedAt: currentMs,
        ),
      );
    }

    await db.upsertCardsBatch(updatedBatch);

    return BacklogSmoothReport(
      totalOverdueCardsSmoothed: totalOverdue,
      recoveryWindowDays: window,
      cardsPerDay: perDay,
      lowestRetrievabilityPrioritized: overdueEntries.first.value,
    );
  }
}
