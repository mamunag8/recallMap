import 'dart:convert';
import 'package:uuid/uuid.dart';
import '../../core/database/app_database.dart';
import '../../core/database/tables.dart';
import '../../core/platform/platform_study_bridge.dart';

/// Workflow 1: Split-Screen PDF-to-Flashcard Extractor.
/// - Swipe Highlight -> Instant Cloze (`[Auto-Cloze]`): Automatically wraps key scientific
///   terms, numbers, equations, or Bengali technical phrases in `{{c1::...}}` and saves
///   `(source_id, page_number, bounding_rect)` automatically.
/// - Drag Box -> Crop Region to Card: Captures a rectangular diagram/equation region from a PDF page.
class PdfHighlightToCard {
  static const Uuid _uuid = Uuid();

  PdfHighlightToCard._();

  /// Converts a highlighted sentence into an atomic Cloze string by detecting high-yield
  /// scientific terms, equations, numbers, or capitalized concepts.
  static String generateSmartClozeSyntax(String rawSentence) {
    final trimmed = rawSentence.trim();
    if (trimmed.contains('{{c1::')) return trimmed;

    // 1. If sentence contains a colon "Concept: Definition", cloze the key definition phrase
    if (trimmed.contains(':')) {
      final parts = trimmed.split(':');
      final head = parts.first.trim();
      final tail = parts.sublist(1).join(':').trim();
      if (head.isNotEmpty && tail.isNotEmpty) {
        final words = tail.split(' ');
        if (words.length > 4) {
          final targetPhrase = words.take(4).join(' ');
          final rest = words.skip(4).join(' ');
          return '$head: {{c1::$targetPhrase}} $rest';
        }
        return '$head: {{c1::$tail}}';
      }
    }

    // 2. Wrap numbers/inequalities/formulas (e.g., "Re < 2300", "A₁v₁ = A₂v₂")
    final formulaRegex = RegExp(
      r'([A-Za-z₀-₉₁₂]+\s*[<>≤≥=]\s*[0-9A-Za-z₀-₉₁₂\.]+)',
    );
    if (formulaRegex.hasMatch(trimmed)) {
      var idx = 1;
      return trimmed.replaceAllMapped(formulaRegex, (m) {
        final token = m.group(0)!;
        final out = '{{c$idx::$token}}';
        idx = idx == 1 ? 2 : 1;
        return out;
      });
    }

    // 3. Fallback: Cloze the highest-information longest word/phrase
    final words = trimmed.split(RegExp(r'\s+'));
    if (words.length >= 3) {
      int bestIdx = words.length ~/ 2;
      int maxLen = 0;
      for (var i = 0; i < words.length; i++) {
        final clean = words[i].replaceAll(RegExp(r'[^\w\u0980-\u09FF]'), '');
        if (clean.length > maxLen) {
          maxLen = clean.length;
          bestIdx = i;
        }
      }
      final updated = List<String>.from(words);
      updated[bestIdx] = '{{c1::${updated[bestIdx]}}}';
      return updated.join(' ');
    }

    return '{{c1::$trimmed}}';
  }

  /// Creates and persists a new FSRS-6 Cloze flashcard tethered to the exact PDF page & bounding box.
  static Future<CardRecord> createAutoClozeFromHighlight({
    required AppDatabase db,
    required String deckId,
    required String? sourceId,
    required int pageNumber,
    required String highlightedSentence,
    required NormalizedBoundingBox boundingRect,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final clozeFront = generateSmartClozeSyntax(highlightedSentence);
    final card = CardRecord(
      id: _uuid.v4(),
      deckId: deckId,
      sourceId: sourceId,
      sourcePage: pageNumber,
      sourceRectJson: jsonEncode(boundingRect.toJson()),
      cardType: 'CLOZE',
      frontMd: clozeFront,
      backMd: 'Extracted from Page $pageNumber: $highlightedSentence',
      tagsJson: jsonEncode(['#pdf-extract', '#page$pageNumber']),
      state: 0,
      dueDate: now,
      stability: 0.0,
      difficulty: 0.0,
      createdAt: now,
      updatedAt: now,
      contentHash: computeContentHash('$clozeFront|$pageNumber|$now'),
    );

    await db.upsertCard(card);
    if (sourceId != null) {
      await db.upsertConceptEdge(
        ConceptEdgeRecord(
          id: _uuid.v4(),
          fromId: sourceId,
          toId: card.id,
          edgeType: 'PDF_EXTRACTION',
          strength: 0.95,
          createdAt: now,
        ),
      );
    }
    return card;
  }

  /// Creates a visual region-crop card tethered to a rectangular drag selection on a PDF page.
  static Future<CardRecord> createRegionCropCard({
    required AppDatabase db,
    required String deckId,
    required String? sourceId,
    required int pageNumber,
    required NormalizedBoundingBox cropRect,
    required String captionPrompt,
    required String explanationBack,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final card = CardRecord(
      id: _uuid.v4(),
      deckId: deckId,
      sourceId: sourceId,
      sourcePage: pageNumber,
      sourceRectJson: jsonEncode(cropRect.toJson()),
      cardType: 'IMAGE_OCCLUSION',
      frontMd: captionPrompt,
      backMd: explanationBack,
      occlusionMasksJson: jsonEncode([cropRect.toJson()]),
      tagsJson: jsonEncode(['#pdf-crop', '#page$pageNumber']),
      state: 0,
      dueDate: now,
      createdAt: now,
      updatedAt: now,
      contentHash: computeContentHash('$captionPrompt|$pageNumber|$now'),
    );
    await db.upsertCard(card);
    return card;
  }
}
