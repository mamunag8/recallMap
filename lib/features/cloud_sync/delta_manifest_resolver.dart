import '../../core/database/app_database.dart';
import '../../core/database/tables.dart';
import '../fsrs_engine/fsrs_v6_scheduler.dart';

class DeltaMergeReport {
  final int cardsMerged;
  final int reviewLogsUnionAdded;
  final int chronologicalRecomputations;
  final String manifestHash;

  const DeltaMergeReport({
    required this.cardsMerged,
    required this.reviewLogsUnionAdded,
    required this.chronologicalRecomputations,
    required this.manifestHash,
  });
}

/// Non-Destructive Delta Sync & Union Review Merge Resolver (`RecallMap_Vault/.recallmap/sync_manifest.json`).
/// - Compares SHA-256 `content_hash` and `updated_at` timestamps to transfer only modified records.
/// - If a user studies offline on both Phone and PC, `review_logs` are merged by union
///   and FSRS-6 states recompute chronologically so zero study reps or streaks are ever lost.
class DeltaManifestResolver {
  DeltaManifestResolver._();

  static Future<DeltaMergeReport> mergeRemoteSnapshot({
    required AppDatabase localDb,
    required Map<String, dynamic> remoteSnapshot,
  }) async {
    int cardsMerged = 0;
    int logsAdded = 0;
    int recomputedCount = 0;

    final localCardMap = {for (final c in localDb.cards) c.id: c};
    final localLogIds = localDb.reviewLogs.map((r) => r.id).toSet();

    // 1. Union merge immutable `review_logs`
    final remoteLogsRaw = (remoteSnapshot['review_logs'] as List?) ?? const [];
    final affectedCardIds = <String>{};

    for (final raw in remoteLogsRaw) {
      final remoteLog =
          ReviewLogRecord.fromMap(Map<String, dynamic>.from(raw as Map));
      if (!localLogIds.contains(remoteLog.id)) {
        await localDb.insertReviewLog(remoteLog);
        localLogIds.add(remoteLog.id);
        affectedCardIds.add(remoteLog.cardId);
        logsAdded++;
      }
    }

    // 2. Compare SHA-256 `content_hash` & `updated_at` for `cards`
    final remoteCardsRaw = (remoteSnapshot['cards'] as List?) ?? const [];
    for (final raw in remoteCardsRaw) {
      final remoteCard =
          CardRecord.fromMap(Map<String, dynamic>.from(raw as Map));
      final localCard = localCardMap[remoteCard.id];
      if (localCard == null) {
        await localDb.upsertCard(remoteCard);
        cardsMerged++;
      } else if (localCard.contentHash != remoteCard.contentHash &&
          remoteCard.updatedAt > localCard.updatedAt) {
        await localDb.upsertCard(remoteCard);
        cardsMerged++;
      }
    }

    // 3. Chronological FSRS-6 Replay for any card that received unioned offline review_logs
    const scheduler = FsrsV6Scheduler();
    for (final cardId in affectedCardIds) {
      final card = localDb.getCardById(cardId);
      if (card == null) continue;

      final cardLogs = localDb.reviewLogs
          .where((r) => r.cardId == cardId)
          .toList()
        ..sort((a, b) => a.reviewedAt.compareTo(b.reviewedAt));

      var replayed = card.copyWith(
        state: 0,
        stability: 0.0,
        difficulty: 0.0,
        reps: 0,
        lapses: 0,
        lastReview: null,
      );

      for (final log in cardLogs) {
        final outcome = scheduler.reviewCard(
          card: replayed,
          rating: log.rating,
          nowMs: log.reviewedAt,
          reviewDurationMs: log.reviewDurationMs,
        );
        replayed = outcome.updatedCard;
      }

      await localDb.upsertCard(replayed);
      recomputedCount++;
    }

    final finalHash = computeContentHash(
      '${localDb.cards.length}|${localDb.reviewLogs.length}|${DateTime.now().millisecondsSinceEpoch}',
    );

    return DeltaMergeReport(
      cardsMerged: cardsMerged,
      reviewLogsUnionAdded: logsAdded,
      chronologicalRecomputations: recomputedCount,
      manifestHash: finalHash.substring(0, 16),
    );
  }
}
