import 'dart:convert';
import 'package:uuid/uuid.dart';
import '../../core/constants/fsrs_constants.dart';
import '../../core/database/app_database.dart';
import '../../core/database/tables.dart';
import 'fsrs_v6_scheduler.dart';

/// Word-level token diff item for the Memory Doctor "Compare Twins" side-by-side view.
class TwinWordToken {
  final String text;
  final bool isDifferingTerm;

  const TwinWordToken({
    required this.text,
    required this.isDifferingTerm,
  });
}

/// Diagnostic report for a single Leech / fragile card surfaced in the Memory Doctor Clinic.
class LeechDiagnosisReport {
  final CardRecord leechCard;
  final double liveRetrievability;
  final List<CardRecord> confusableTwins;
  final List<TwinWordToken> primaryDiffTokens;
  final List<TwinWordToken> twinDiffTokens;
  final StudySourceRecord? linkedSource;

  const LeechDiagnosisReport({
    required this.leechCard,
    required this.liveRetrievability,
    required this.confusableTwins,
    required this.primaryDiffTokens,
    required this.twinDiffTokens,
    this.linkedSource,
  });
}

/// Built-In "Memory Doctor" (Leech & Confusable Twin Radar + 1-Tap Card Surgery).
/// 1. Flags any card with `lapses >= 3` or `R < 75%` as a clinical candidate.
/// 2. Queries `fts_study_search` via BM25 similarity to find the top 2 Confusable Twin cards
///    with overlapping terminology that the student is mixing up.
/// 3. Computes word-level diff tokens so differing terms (e.g., `Xylem` vs `Phloem`,
///    `unidirectionally` vs `bidirectionally`) are highlighted side-by-side.
/// 4. Executes 1-Tap Card Surgery:
///    (a) Split a long card into 2 atomic Cloze cards
///    (b) Pin a visual mnemonic sketch on the card
///    (c) Jump straight to the source PDF paragraph
class MemoryDoctorAnalyzer {
  static const Uuid _uuid = Uuid();

  MemoryDoctorAnalyzer._();

  static List<LeechDiagnosisReport> diagnoseVault(
    AppDatabase db, {
    int? nowMs,
  }) {
    final currentMs = nowMs ?? DateTime.now().millisecondsSinceEpoch;
    const scheduler = FsrsV6Scheduler();
    final reports = <LeechDiagnosisReport>[];

    for (final card in db.cards) {
      if (card.isDeleted || card.isSuspended) continue;
      final r = scheduler.liveRetrievabilityForCard(card, nowMs: currentMs);
      final isFragile = card.isLeech ||
          card.lapses >= FsrsConstants.leechLapseThreshold ||
          (card.state != FsrsConstants.stateNew && r < 0.78);
      if (!isFragile) continue;

      final twins = db.studyDao.findConfusableTwins(card, maxTwins: 2);
      final firstTwin = twins.isNotEmpty ? twins.first : null;

      final primaryTokens = firstTwin != null
          ? computeDiffTokens(card.frontMd, firstTwin.frontMd)
          : [TwinWordToken(text: card.frontMd, isDifferingTerm: false)];

      final twinTokens = firstTwin != null
          ? computeDiffTokens(firstTwin.frontMd, card.frontMd)
          : const <TwinWordToken>[];

      reports.add(
        LeechDiagnosisReport(
          leechCard: card,
          liveRetrievability: r,
          confusableTwins: twins,
          primaryDiffTokens: primaryTokens,
          twinDiffTokens: twinTokens,
          linkedSource: db.getSourceById(card.sourceId),
        ),
      );
    }

    reports.sort(
      (a, b) => a.liveRetrievability.compareTo(b.liveRetrievability),
    );
    return reports;
  }

  /// Computes word-by-word comparison tokens between [textA] and [textB],
  /// marking words present in [textA] but absent in [textB] as `isDifferingTerm: true`.
  static List<TwinWordToken> computeDiffTokens(String textA, String textB) {
    final otherWords = textB
        .toLowerCase()
        .replaceAll(RegExp(r'[\{\}\:\;\,\.\!\?]'), '')
        .split(RegExp(r'\s+'))
        .toSet();

    final wordsA = textA.split(RegExp(r'\s+'));
    return wordsA.map((word) {
      final normalized =
          word.toLowerCase().replaceAll(RegExp(r'[\{\}\:\;\,\.\!\?]'), '');
      final differs = normalized.isNotEmpty && !otherWords.contains(normalized);
      return TwinWordToken(text: word, isDifferingTerm: differs);
    }).toList();
  }

  /// 1-Tap Card Surgery (a): Splits a complex or multi-cloze leech card into 2 atomic Cloze cards.
  static Future<List<CardRecord>> splitIntoTwoAtomicClozeCards({
    required AppDatabase db,
    required CardRecord leechCard,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final cleanFront = leechCard.frontMd;

    String part1Front;
    String part2Front;

    if (cleanFront.contains('{{c2::')) {
      // Keep {{c1::...}} active in Card A and convert {{c2::...}} to plain text, and vice versa in Card B
      part1Front = cleanFront.replaceAllMapped(
        RegExp(r'\{\{c2::([^:}]+)(?:::[^}]+)?\}\}'),
        (m) => m.group(1) ?? '',
      );
      part2Front = cleanFront
          .replaceAllMapped(
            RegExp(r'\{\{c1::([^:}]+)(?:::[^}]+)?\}\}'),
            (m) => m.group(1) ?? '',
          )
          .replaceAll('{{c2::', '{{c1::');
    } else {
      final words = cleanFront.split(' ');
      final mid = (words.length / 2).ceil();
      final firstHalf = words.take(mid).join(' ');
      final secondHalf = words.skip(mid).join(' ');
      part1Front = '$firstHalf {{c1::${secondHalf.isEmpty ? leechCard.backMd : secondHalf}}}';
      part2Front = '{{c1::$firstHalf}} $secondHalf';
    }

    final atomicA = leechCard.copyWith(
      id: _uuid.v4(),
      cardType: 'CLOZE',
      frontMd: '[Atomic 1/2] $part1Front',
      state: FsrsConstants.stateLearning,
      stability: 2.3,
      difficulty: 4.5,
      lapses: 0,
      isLeech: false,
      dueDate: now,
      createdAt: now,
      updatedAt: now,
    );

    final atomicB = leechCard.copyWith(
      id: _uuid.v4(),
      cardType: 'CLOZE',
      frontMd: '[Atomic 2/2] $part2Front',
      state: FsrsConstants.stateLearning,
      stability: 2.3,
      difficulty: 4.5,
      lapses: 0,
      isLeech: false,
      dueDate: now + 3600 * 1000,
      createdAt: now,
      updatedAt: now,
    );

    // Suspend the old leech card and insert the 2 new atomic cards
    await db.upsertCard(
      leechCard.copyWith(isSuspended: true, isLeech: false, updatedAt: now),
    );
    await db.upsertCardsBatch([atomicA, atomicB]);
    return [atomicA, atomicB];
  }

  /// 1-Tap Card Surgery (b): Attaches a visual mnemonic sketch to a card and resets its leech flag.
  static Future<CardRecord> attachMnemonicSketch({
    required AppDatabase db,
    required CardRecord card,
    required List<Map<String, dynamic>> strokes,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final updated = card.copyWith(
      mnemonicSketchJson: jsonEncode(strokes),
      isLeech: false,
      updatedAt: now,
    );
    await db.upsertCard(updated);
    return updated;
  }
}
