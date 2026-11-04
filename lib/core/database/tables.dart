import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Computes deterministic SHA-256 content hash for non-destructive BYOC delta sync.
String computeContentHash(String payload) {
  return sha256.convert(utf8.encode(payload)).toString();
}

/// Table 1: `decks` (Hierarchical Decks & Exam Targets)
class DeckRecord {
  final String id;
  final String? parentId;
  final String title;
  final String description;
  final String languageCode;
  final String colorHex;
  final String iconName;
  final int? examDate;
  final double targetRetention;
  final int dailyNewLimit;
  final String? customFsrsWeightsJson;
  final bool isDemoData;
  final int createdAt;
  final int updatedAt;
  final String contentHash;
  final bool isDeleted;

  const DeckRecord({
    required this.id,
    this.parentId,
    required this.title,
    this.description = '',
    this.languageCode = 'en',
    this.colorHex = '#6366F1',
    this.iconName = 'school',
    this.examDate,
    this.targetRetention = 0.90,
    this.dailyNewLimit = 25,
    this.customFsrsWeightsJson,
    this.isDemoData = false,
    required this.createdAt,
    required this.updatedAt,
    required this.contentHash,
    this.isDeleted = false,
  });

  DeckRecord copyWith({
    String? id,
    String? parentId,
    String? title,
    String? description,
    String? languageCode,
    String? colorHex,
    String? iconName,
    int? examDate,
    double? targetRetention,
    int? dailyNewLimit,
    String? customFsrsWeightsJson,
    bool? isDemoData,
    int? createdAt,
    int? updatedAt,
    String? contentHash,
    bool? isDeleted,
  }) {
    final nextTitle = title ?? this.title;
    final nextDesc = description ?? this.description;
    final nextExam = examDate ?? this.examDate;
    final nextRet = targetRetention ?? this.targetRetention;
    final nextUpdated = updatedAt ?? DateTime.now().millisecondsSinceEpoch;
    return DeckRecord(
      id: id ?? this.id,
      parentId: parentId ?? this.parentId,
      title: nextTitle,
      description: nextDesc,
      languageCode: languageCode ?? this.languageCode,
      colorHex: colorHex ?? this.colorHex,
      iconName: iconName ?? this.iconName,
      examDate: nextExam,
      targetRetention: nextRet,
      dailyNewLimit: dailyNewLimit ?? this.dailyNewLimit,
      customFsrsWeightsJson:
          customFsrsWeightsJson ?? this.customFsrsWeightsJson,
      isDemoData: isDemoData ?? this.isDemoData,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: nextUpdated,
      contentHash: contentHash ??
          computeContentHash('$nextTitle|$nextDesc|$nextExam|$nextRet'),
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'parent_id': parentId,
        'title': title,
        'description': description,
        'language_code': languageCode,
        'color_hex': colorHex,
        'icon_name': iconName,
        'exam_date': examDate,
        'target_retention': targetRetention,
        'daily_new_limit': dailyNewLimit,
        'custom_fsrs_weights_json': customFsrsWeightsJson,
        'is_demo_data': isDemoData ? 1 : 0,
        'created_at': createdAt,
        'updated_at': updatedAt,
        'content_hash': contentHash,
        'is_deleted': isDeleted ? 1 : 0,
      };

  factory DeckRecord.fromMap(Map<String, dynamic> map) => DeckRecord(
        id: map['id'] as String,
        parentId: map['parent_id'] as String?,
        title: map['title'] as String,
        description: (map['description'] as String?) ?? '',
        languageCode: (map['language_code'] as String?) ?? 'en',
        colorHex: (map['color_hex'] as String?) ?? '#6366F1',
        iconName: (map['icon_name'] as String?) ?? 'school',
        examDate: (map['exam_date'] as num?)?.toInt(),
        targetRetention:
            (map['target_retention'] as num?)?.toDouble() ?? 0.90,
        dailyNewLimit: (map['daily_new_limit'] as num?)?.toInt() ?? 25,
        customFsrsWeightsJson: map['custom_fsrs_weights_json'] as String?,
        isDemoData: ((map['is_demo_data'] as num?)?.toInt() ?? 0) == 1,
        createdAt: (map['created_at'] as num).toInt(),
        updatedAt: (map['updated_at'] as num).toInt(),
        contentHash: (map['content_hash'] as String?) ?? '',
        isDeleted: ((map['is_deleted'] as num?)?.toInt() ?? 0) == 1,
      );
}

/// Table 2: `study_sources` (Imported PDFs, Lecture Slides & Concept Notes)
class StudySourceRecord {
  final String id;
  final String deckId;
  final String sourceType; // 'PDF' | 'CONCEPT_NOTE' | 'DIAGRAM_IMAGE'
  final String title;
  final String markdownBody;
  final String? relativeFilePath;
  final int pageCount;
  final int lastReadPage;
  final String tagsJson;
  final double? graphX;
  final double? graphY;
  final bool isDemoData;
  final int updatedAt;
  final String contentHash;
  final bool isDeleted;

  const StudySourceRecord({
    required this.id,
    required this.deckId,
    required this.sourceType,
    required this.title,
    this.markdownBody = '',
    this.relativeFilePath,
    this.pageCount = 1,
    this.lastReadPage = 1,
    this.tagsJson = '[]',
    this.graphX,
    this.graphY,
    this.isDemoData = false,
    required this.updatedAt,
    required this.contentHash,
    this.isDeleted = false,
  });

  StudySourceRecord copyWith({
    String? id,
    String? deckId,
    String? sourceType,
    String? title,
    String? markdownBody,
    String? relativeFilePath,
    int? pageCount,
    int? lastReadPage,
    String? tagsJson,
    double? graphX,
    double? graphY,
    bool? isDemoData,
    int? updatedAt,
    String? contentHash,
    bool? isDeleted,
  }) {
    final nextTitle = title ?? this.title;
    final nextBody = markdownBody ?? this.markdownBody;
    return StudySourceRecord(
      id: id ?? this.id,
      deckId: deckId ?? this.deckId,
      sourceType: sourceType ?? this.sourceType,
      title: nextTitle,
      markdownBody: nextBody,
      relativeFilePath: relativeFilePath ?? this.relativeFilePath,
      pageCount: pageCount ?? this.pageCount,
      lastReadPage: lastReadPage ?? this.lastReadPage,
      tagsJson: tagsJson ?? this.tagsJson,
      graphX: graphX ?? this.graphX,
      graphY: graphY ?? this.graphY,
      isDemoData: isDemoData ?? this.isDemoData,
      updatedAt: updatedAt ?? DateTime.now().millisecondsSinceEpoch,
      contentHash: contentHash ?? computeContentHash('$nextTitle|$nextBody'),
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'deck_id': deckId,
        'source_type': sourceType,
        'title': title,
        'markdown_body': markdownBody,
        'relative_file_path': relativeFilePath,
        'page_count': pageCount,
        'last_read_page': lastReadPage,
        'tags_json': tagsJson,
        'graph_x': graphX,
        'graph_y': graphY,
        'is_demo_data': isDemoData ? 1 : 0,
        'updated_at': updatedAt,
        'content_hash': contentHash,
        'is_deleted': isDeleted ? 1 : 0,
      };

  factory StudySourceRecord.fromMap(Map<String, dynamic> map) =>
      StudySourceRecord(
        id: map['id'] as String,
        deckId: map['deck_id'] as String,
        sourceType: map['source_type'] as String,
        title: map['title'] as String,
        markdownBody: (map['markdown_body'] as String?) ?? '',
        relativeFilePath: map['relative_file_path'] as String?,
        pageCount: (map['page_count'] as num?)?.toInt() ?? 1,
        lastReadPage: (map['last_read_page'] as num?)?.toInt() ?? 1,
        tagsJson: (map['tags_json'] as String?) ?? '[]',
        graphX: (map['graph_x'] as num?)?.toDouble(),
        graphY: (map['graph_y'] as num?)?.toDouble(),
        isDemoData: ((map['is_demo_data'] as num?)?.toInt() ?? 0) == 1,
        updatedAt: (map['updated_at'] as num).toInt(),
        contentHash: (map['content_hash'] as String?) ?? '',
        isDeleted: ((map['is_deleted'] as num?)?.toInt() ?? 0) == 1,
      );
}

/// Table 3: `cards` (FSRS-6 Flashcards Tethered to Exact Source Coordinates)
class CardRecord {
  final String id;
  final String deckId;
  final String? sourceId;
  final int? sourcePage;
  final String? sourceRectJson;
  final String cardType; // 'BASIC' | 'CLOZE' | 'IMAGE_OCCLUSION' | 'INLINE_NOTE'
  final String frontMd;
  final String backMd;
  final String? occlusionMasksJson;
  final String? mnemonicSketchJson;
  final String tagsJson;
  final int state; // 0 = New, 1 = Learning, 2 = Review, 3 = Relearning
  final int dueDate;
  final double stability;
  final double difficulty;
  final double elapsedDays;
  final double scheduledDays;
  final int reps;
  final int lapses;
  final int? lastReview;
  final bool isLeech;
  final bool isSuspended;
  final bool isDemoData;
  final int createdAt;
  final int updatedAt;
  final String contentHash;
  final bool isDeleted;

  const CardRecord({
    required this.id,
    required this.deckId,
    this.sourceId,
    this.sourcePage,
    this.sourceRectJson,
    this.cardType = 'BASIC',
    required this.frontMd,
    required this.backMd,
    this.occlusionMasksJson,
    this.mnemonicSketchJson,
    this.tagsJson = '[]',
    this.state = 0,
    required this.dueDate,
    this.stability = 0.0,
    this.difficulty = 0.0,
    this.elapsedDays = 0.0,
    this.scheduledDays = 0.0,
    this.reps = 0,
    this.lapses = 0,
    this.lastReview,
    this.isLeech = false,
    this.isSuspended = false,
    this.isDemoData = false,
    required this.createdAt,
    required this.updatedAt,
    required this.contentHash,
    this.isDeleted = false,
  });

  List<String> get tagsList {
    try {
      final decoded = jsonDecode(tagsJson);
      if (decoded is List) {
        return decoded.map((e) => e.toString()).toList();
      }
    } catch (_) {}
    return const [];
  }

  CardRecord copyWith({
    String? id,
    String? deckId,
    String? sourceId,
    int? sourcePage,
    String? sourceRectJson,
    String? cardType,
    String? frontMd,
    String? backMd,
    String? occlusionMasksJson,
    String? mnemonicSketchJson,
    String? tagsJson,
    int? state,
    int? dueDate,
    double? stability,
    double? difficulty,
    double? elapsedDays,
    double? scheduledDays,
    int? reps,
    int? lapses,
    int? lastReview,
    bool? isLeech,
    bool? isSuspended,
    bool? isDemoData,
    int? createdAt,
    int? updatedAt,
    String? contentHash,
    bool? isDeleted,
  }) {
    final nextFront = frontMd ?? this.frontMd;
    final nextBack = backMd ?? this.backMd;
    final nextStability = stability ?? this.stability;
    final nextDifficulty = difficulty ?? this.difficulty;
    final nextDue = dueDate ?? this.dueDate;
    return CardRecord(
      id: id ?? this.id,
      deckId: deckId ?? this.deckId,
      sourceId: sourceId ?? this.sourceId,
      sourcePage: sourcePage ?? this.sourcePage,
      sourceRectJson: sourceRectJson ?? this.sourceRectJson,
      cardType: cardType ?? this.cardType,
      frontMd: nextFront,
      backMd: nextBack,
      occlusionMasksJson: occlusionMasksJson ?? this.occlusionMasksJson,
      mnemonicSketchJson: mnemonicSketchJson ?? this.mnemonicSketchJson,
      tagsJson: tagsJson ?? this.tagsJson,
      state: state ?? this.state,
      dueDate: nextDue,
      stability: nextStability,
      difficulty: nextDifficulty,
      elapsedDays: elapsedDays ?? this.elapsedDays,
      scheduledDays: scheduledDays ?? this.scheduledDays,
      reps: reps ?? this.reps,
      lapses: lapses ?? this.lapses,
      lastReview: lastReview ?? this.lastReview,
      isLeech: isLeech ?? this.isLeech,
      isSuspended: isSuspended ?? this.isSuspended,
      isDemoData: isDemoData ?? this.isDemoData,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now().millisecondsSinceEpoch,
      contentHash: contentHash ??
          computeContentHash(
              '$nextFront|$nextBack|$nextStability|$nextDifficulty|$nextDue'),
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'deck_id': deckId,
        'source_id': sourceId,
        'source_page': sourcePage,
        'source_rect_json': sourceRectJson,
        'card_type': cardType,
        'front_md': frontMd,
        'back_md': backMd,
        'occlusion_masks_json': occlusionMasksJson,
        'mnemonic_sketch_json': mnemonicSketchJson,
        'tags_json': tagsJson,
        'state': state,
        'due_date': dueDate,
        'stability': stability,
        'difficulty': difficulty,
        'elapsed_days': elapsedDays,
        'scheduled_days': scheduledDays,
        'reps': reps,
        'lapses': lapses,
        'last_review': lastReview,
        'is_leech': isLeech ? 1 : 0,
        'is_suspended': isSuspended ? 1 : 0,
        'is_demo_data': isDemoData ? 1 : 0,
        'created_at': createdAt,
        'updated_at': updatedAt,
        'content_hash': contentHash,
        'is_deleted': isDeleted ? 1 : 0,
      };

  factory CardRecord.fromMap(Map<String, dynamic> map) => CardRecord(
        id: map['id'] as String,
        deckId: map['deck_id'] as String,
        sourceId: map['source_id'] as String?,
        sourcePage: (map['source_page'] as num?)?.toInt(),
        sourceRectJson: map['source_rect_json'] as String?,
        cardType: (map['card_type'] as String?) ?? 'BASIC',
        frontMd: map['front_md'] as String,
        backMd: map['back_md'] as String,
        occlusionMasksJson: map['occlusion_masks_json'] as String?,
        mnemonicSketchJson: map['mnemonic_sketch_json'] as String?,
        tagsJson: (map['tags_json'] as String?) ?? '[]',
        state: (map['state'] as num?)?.toInt() ?? 0,
        dueDate: (map['due_date'] as num).toInt(),
        stability: (map['stability'] as num?)?.toDouble() ?? 0.0,
        difficulty: (map['difficulty'] as num?)?.toDouble() ?? 0.0,
        elapsedDays: (map['elapsed_days'] as num?)?.toDouble() ?? 0.0,
        scheduledDays: (map['scheduled_days'] as num?)?.toDouble() ?? 0.0,
        reps: (map['reps'] as num?)?.toInt() ?? 0,
        lapses: (map['lapses'] as num?)?.toInt() ?? 0,
        lastReview: (map['last_review'] as num?)?.toInt(),
        isLeech: ((map['is_leech'] as num?)?.toInt() ?? 0) == 1,
        isSuspended: ((map['is_suspended'] as num?)?.toInt() ?? 0) == 1,
        isDemoData: ((map['is_demo_data'] as num?)?.toInt() ?? 0) == 1,
        createdAt: (map['created_at'] as num).toInt(),
        updatedAt: (map['updated_at'] as num).toInt(),
        contentHash: (map['content_hash'] as String?) ?? '',
        isDeleted: ((map['is_deleted'] as num?)?.toInt() ?? 0) == 1,
      );
}

/// Table 4: `concept_edges` (2D Concept RecallMap Connections)
class ConceptEdgeRecord {
  final String id;
  final String fromId;
  final String toId;
  final String edgeType; // 'WIKI_LINK' | 'PDF_EXTRACTION' | 'SHARED_TAG' | 'CONFUSABLE_TWIN'
  final double strength;
  final int createdAt;

  const ConceptEdgeRecord({
    required this.id,
    required this.fromId,
    required this.toId,
    required this.edgeType,
    this.strength = 1.0,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'from_id': fromId,
        'to_id': toId,
        'edge_type': edgeType,
        'strength': strength,
        'created_at': createdAt,
      };

  factory ConceptEdgeRecord.fromMap(Map<String, dynamic> map) =>
      ConceptEdgeRecord(
        id: map['id'] as String,
        fromId: map['from_id'] as String,
        toId: map['to_id'] as String,
        edgeType: map['edge_type'] as String,
        strength: (map['strength'] as num?)?.toDouble() ?? 1.0,
        createdAt: (map['created_at'] as num).toInt(),
      );
}

/// Table 5: `review_logs` (Immutable Study History for Heatmap & Analytics)
class ReviewLogRecord {
  final String id;
  final String cardId;
  final int rating; // 1 = Again, 2 = Hard, 3 = Good, 4 = Easy
  final int stateBefore;
  final double stabilityBefore;
  final double difficultyBefore;
  final double stabilityAfter;
  final double difficultyAfter;
  final double elapsedDays;
  final double scheduledDays;
  final int reviewDurationMs;
  final int reviewedAt;

  const ReviewLogRecord({
    required this.id,
    required this.cardId,
    required this.rating,
    required this.stateBefore,
    required this.stabilityBefore,
    required this.difficultyBefore,
    required this.stabilityAfter,
    required this.difficultyAfter,
    required this.elapsedDays,
    required this.scheduledDays,
    required this.reviewDurationMs,
    required this.reviewedAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'card_id': cardId,
        'rating': rating,
        'state_before': stateBefore,
        'stability_before': stabilityBefore,
        'difficulty_before': difficultyBefore,
        'stability_after': stabilityAfter,
        'difficulty_after': difficultyAfter,
        'elapsed_days': elapsedDays,
        'scheduled_days': scheduledDays,
        'review_duration_ms': reviewDurationMs,
        'reviewed_at': reviewedAt,
      };

  factory ReviewLogRecord.fromMap(Map<String, dynamic> map) => ReviewLogRecord(
        id: map['id'] as String,
        cardId: map['card_id'] as String,
        rating: (map['rating'] as num).toInt(),
        stateBefore: (map['state_before'] as num).toInt(),
        stabilityBefore: (map['stability_before'] as num).toDouble(),
        difficultyBefore: (map['difficulty_before'] as num).toDouble(),
        stabilityAfter: (map['stability_after'] as num).toDouble(),
        difficultyAfter: (map['difficulty_after'] as num).toDouble(),
        elapsedDays: (map['elapsed_days'] as num).toDouble(),
        scheduledDays: (map['scheduled_days'] as num).toDouble(),
        reviewDurationMs: (map['review_duration_ms'] as num).toInt(),
        reviewedAt: (map['reviewed_at'] as num).toInt(),
      );
}

/// Table 6: `fts_study_search` Hit result with BM25 relevance score.
class FtsSearchResult {
  final String entityId;
  final String entityType; // 'CARD' | 'SOURCE'
  final String deckId;
  final String titleOrFront;
  final String bodyOrBack;
  final String tagsJson;
  final double bm25Score;

  const FtsSearchResult({
    required this.entityId,
    required this.entityType,
    required this.deckId,
    required this.titleOrFront,
    required this.bodyOrBack,
    required this.tagsJson,
    required this.bm25Score,
  });
}
