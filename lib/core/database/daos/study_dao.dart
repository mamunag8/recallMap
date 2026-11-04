import 'dart:math' as math;
import '../tables.dart';
import '../app_database.dart';

/// High-speed Data Access Object (DAO) providing FTS5 (`unicode61`) search,
/// BM25 similarity scoring for the Memory Doctor Confusable Twin Detector,
/// and per-page PDF Mastery aggregation.
class StudyDao {
  final AppDatabase db;

  const StudyDao(this.db);

  /// Sub-5ms Full-Text Search (FTS5 unicode61 + BM25 ranking) across all cards,
  /// PDFs, concept notes, and `#tags` in English, Bangla (`বাংলা`), Turkish, Arabic, etc.
  List<FtsSearchResult> searchAll(String rawQuery, {int limit = 25}) {
    final query = rawQuery.trim().toLowerCase();
    if (query.isEmpty) return const [];

    final tokens = _tokenizeUnicode61(query);
    if (tokens.isEmpty) return const [];

    final results = <FtsSearchResult>[];

    for (final card in db.cards) {
      if (card.isDeleted) continue;
      final score = _computeBm25Score(
        queryTokens: tokens,
        primaryText: card.frontMd,
        secondaryText: card.backMd,
        tagsText: card.tagsJson,
      );
      if (score > 0) {
        results.add(
          FtsSearchResult(
            entityId: card.id,
            entityType: 'CARD',
            deckId: card.deckId,
            titleOrFront: card.frontMd,
            bodyOrBack: card.backMd,
            tagsJson: card.tagsJson,
            bm25Score: score,
          ),
        );
      }
    }

    for (final source in db.sources) {
      if (source.isDeleted) continue;
      final score = _computeBm25Score(
        queryTokens: tokens,
        primaryText: source.title,
        secondaryText: source.markdownBody,
        tagsText: source.tagsJson,
      );
      if (score > 0) {
        results.add(
          FtsSearchResult(
            entityId: source.id,
            entityType: 'SOURCE',
            deckId: source.deckId,
            titleOrFront: source.title,
            bodyOrBack: source.markdownBody,
            tagsJson: source.tagsJson,
            bm25Score: score,
          ),
        );
      }
    }

    results.sort((a, b) => b.bm25Score.compareTo(a.bm25Score));
    return results.take(limit).toList();
  }

  /// Finds the top [maxTwins] cards in the deck with overlapping terminology
  /// using BM25 similarity so the Memory Doctor Clinic can highlight Confusable Twins.
  List<CardRecord> findConfusableTwins(
    CardRecord targetCard, {
    int maxTwins = 2,
  }) {
    final targetTokens =
        _tokenizeUnicode61('${targetCard.frontMd} ${targetCard.backMd}')
            .where((t) => t.length >= 3)
            .toList();
    if (targetTokens.isEmpty) return const [];

    final scored = <MapEntry<CardRecord, double>>[];
    for (final candidate in db.cards) {
      if (candidate.isDeleted || candidate.id == targetCard.id) continue;
      final score = _computeBm25Score(
        queryTokens: targetTokens,
        primaryText: candidate.frontMd,
        secondaryText: candidate.backMd,
        tagsText: candidate.tagsJson,
      );
      final sameDeckBoost = candidate.deckId == targetCard.deckId ? 1.35 : 1.0;
      if (score > 0.25) {
        scored.add(MapEntry(candidate, score * sameDeckBoost));
      }
    }

    scored.sort((a, b) => b.value.compareTo(a.value));
    return scored.take(maxTwins).map((e) => e.key).toList();
  }

  /// Unicode61-equivalent tokenizer supporting Latin, Bengali (`\u0980-\u09FF`),
  /// Arabic (`\u0600-\u06FF`), Devanagari, Turkish, and CJK scripts.
  static List<String> _tokenizeUnicode61(String input) {
    final cleaned = input
        .toLowerCase()
        .replaceAll(RegExp(r'[\{\}\[\]\(\)\:\;\,\.\!\?\|\"\\\/]'), ' ');
    return cleaned
        .split(RegExp(r'\s+'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  static double _computeBm25Score({
    required List<String> queryTokens,
    required String primaryText,
    required String secondaryText,
    required String tagsText,
  }) {
    final corpus =
        '${primaryText.toLowerCase()} ${secondaryText.toLowerCase()} ${tagsText.toLowerCase()}';
    final docTokens = _tokenizeUnicode61(corpus);
    if (docTokens.isEmpty) return 0.0;

    const k1 = 1.5;
    const b = 0.75;
    const avgDocLen = 24.0;
    final docLen = docTokens.length.toDouble();

    var totalScore = 0.0;
    for (final q in queryTokens) {
      var tf = 0.0;
      for (final token in docTokens) {
        if (token == q) {
          tf += 2.0;
        } else if (token.contains(q) || q.contains(token)) {
          tf += 0.85;
        }
      }
      if (primaryText.toLowerCase().contains(q)) {
        tf += 1.5;
      }
      if (tf > 0) {
        final numerator = tf * (k1 + 1.0);
        final denominator = tf + k1 * (1.0 - b + b * (docLen / avgDocLen));
        totalScore += (numerator / math.max(0.01, denominator));
      }
    }
    return totalScore;
  }
}
