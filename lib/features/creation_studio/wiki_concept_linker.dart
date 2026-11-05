import 'package:uuid/uuid.dart';
import '../../core/database/app_database.dart';
import '../../core/database/tables.dart';

/// Bidirectional `[[Concept Links]]` parser, autocomplete resolver, and
/// Connected Backlinks analyzer for the RemNote/Obsidian-Style Inline Outliner.
class WikiConceptLinker {
  static const Uuid _uuid = Uuid();

  WikiConceptLinker._();

  /// Extracts all `[[Concept Title]]` references inside a Markdown body.
  static List<String> extractWikiLinkTitles(String markdown) {
    final regex = RegExp(r'\[\[([^\[\]]+)\]\]');
    return regex
        .allMatches(markdown)
        .map((m) => (m.group(1) ?? '').trim())
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList();
  }

  /// Returns autocomplete candidates (Notes, PDFs, and Decks) matching [prefix].
  static List<String> suggestConceptTargets(AppDatabase db, String prefix) {
    final q = prefix.trim().toLowerCase();
    final titles = <String>{
      ...db.sources.map((s) => s.title),
      ...db.decks.map((d) => d.title),
    };
    if (q.isEmpty) return titles.take(8).toList();
    return titles
        .where((t) => t.toLowerCase().contains(q))
        .take(8)
        .toList();
  }

  /// Synchronizes `WIKI_LINK` edges in `concept_edges` from [source] to any linked Notes/PDFs/Decks.
  static Future<int> syncWikiEdges({
    required AppDatabase db,
    required StudySourceRecord source,
  }) async {
    final linkedTitles = extractWikiLinkTitles(source.markdownBody);
    final now = DateTime.now().millisecondsSinceEpoch;
    var count = 0;

    for (final title in linkedTitles) {
      final targetSource = db.sources
          .where((s) => s.title.toLowerCase() == title.toLowerCase())
          .firstOrNull;
      if (targetSource != null && targetSource.id != source.id) {
        await db.upsertConceptEdge(
          ConceptEdgeRecord(
            id: _uuid.v4(),
            fromId: source.id,
            toId: targetSource.id,
            edgeType: 'WIKI_LINK',
            strength: 1.0,
            createdAt: now,
          ),
        );
        count++;
      }
    }
    return count;
  }

  /// Finds all backlinks pointing to [targetTitle] or [targetSourceId].
  static List<StudySourceRecord> findBacklinks({
    required AppDatabase db,
    required String targetTitle,
    required String targetSourceId,
  }) {
    final token = '[[${targetTitle.toLowerCase()}]]';
    return db.sources
        .where(
          (s) =>
              s.id != targetSourceId &&
              s.markdownBody.toLowerCase().contains(token),
        )
        .toList();
  }
}
