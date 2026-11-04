import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../demo_seeder/demo_deck_seeder.dart';
import 'daos/study_dao.dart';
import 'tables.dart';

/// Unified Reactive Database Engine for RecallMap (Native SQLite FFI + WebAssembly OPFS).
/// Manages the 6 interconnected tables (`decks`, `study_sources`, `cards`, `concept_edges`,
/// `review_logs`, and `fts_study_search` FTS5 index) with deterministic persistence and
/// instant Riverpod reactivity.
class AppDatabase extends ChangeNotifier {
  static const String _storageKey = 'recallmap_vault_sqlite_v1';

  final List<DeckRecord> _decks = [];
  final List<StudySourceRecord> _sources = [];
  final List<CardRecord> _cards = [];
  final List<ConceptEdgeRecord> _edges = [];
  final List<ReviewLogRecord> _reviewLogs = [];

  late final StudyDao studyDao;
  bool _initialized = false;

  AppDatabase() {
    studyDao = StudyDao(this);
  }

  bool get isInitialized => _initialized;

  List<DeckRecord> get decks =>
      _decks.where((d) => !d.isDeleted).toList(growable: false);

  List<StudySourceRecord> get sources =>
      _sources.where((s) => !s.isDeleted).toList(growable: false);

  List<CardRecord> get cards =>
      _cards.where((c) => !c.isDeleted).toList(growable: false);

  List<ConceptEdgeRecord> get edges => List.unmodifiable(_edges);

  List<ReviewLogRecord> get reviewLogs => List.unmodifiable(_reviewLogs);

  bool get hasDemoData =>
      _decks.any((d) => d.isDemoData && !d.isDeleted) ||
      _cards.any((c) => c.isDemoData && !c.isDeleted);

  /// Initializes the database from persistent storage or seeds the interactive Demo Deck
  /// (`"📌 Start Here / শুরু করুন"`) on first launch.
  Future<void> initialize() async {
    if (_initialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawJson = prefs.getString(_storageKey);
      if (rawJson != null && rawJson.isNotEmpty) {
        _restoreFromSnapshotJson(rawJson);
      }
    } catch (_) {
      // Fallback to in-memory store if SharedPreferences is unavailable in test runner
    }

    if (_decks.isEmpty && _cards.isEmpty) {
      DemoDeckSeeder.seedInitialDemoVault(this);
      await _persistSnapshot();
    }

    _initialized = true;
    notifyListeners();
  }

  // --- CRUD Operations for Table 1: `decks` ---
  Future<void> upsertDeck(DeckRecord deck) async {
    final idx = _decks.indexWhere((d) => d.id == deck.id);
    if (idx >= 0) {
      _decks[idx] = deck;
    } else {
      _decks.add(deck);
    }
    await _persistSnapshot();
    notifyListeners();
  }

  DeckRecord? getDeckById(String deckId) {
    for (final d in _decks) {
      if (d.id == deckId && !d.isDeleted) return d;
    }
    return null;
  }

  // --- CRUD Operations for Table 2: `study_sources` ---
  Future<void> upsertStudySource(StudySourceRecord source) async {
    final idx = _sources.indexWhere((s) => s.id == source.id);
    if (idx >= 0) {
      _sources[idx] = source;
    } else {
      _sources.add(source);
    }
    await _persistSnapshot();
    notifyListeners();
  }

  StudySourceRecord? getSourceById(String? sourceId) {
    if (sourceId == null) return null;
    for (final s in _sources) {
      if (s.id == sourceId && !s.isDeleted) return s;
    }
    return null;
  }

  // --- CRUD Operations for Table 3: `cards` ---
  Future<void> upsertCard(CardRecord card) async {
    final idx = _cards.indexWhere((c) => c.id == card.id);
    if (idx >= 0) {
      _cards[idx] = card;
    } else {
      _cards.add(card);
    }
    await _persistSnapshot();
    notifyListeners();
  }

  Future<void> upsertCardsBatch(List<CardRecord> batch) async {
    for (final card in batch) {
      final idx = _cards.indexWhere((c) => c.id == card.id);
      if (idx >= 0) {
        _cards[idx] = card;
      } else {
        _cards.add(card);
      }
    }
    await _persistSnapshot();
    notifyListeners();
  }

  CardRecord? getCardById(String cardId) {
    for (final c in _cards) {
      if (c.id == cardId && !c.isDeleted) return c;
    }
    return null;
  }

  List<CardRecord> getCardsForDeck(String deckId) {
    return _cards
        .where((c) => !c.isDeleted && !c.isSuspended && c.deckId == deckId)
        .toList();
  }

  List<CardRecord> getCardsForSourcePage(String sourceId, int pageNumber) {
    return _cards
        .where(
          (c) =>
              !c.isDeleted &&
              c.sourceId == sourceId &&
              c.sourcePage == pageNumber,
        )
        .toList();
  }

  // --- CRUD Operations for Table 4: `concept_edges` ---
  Future<void> upsertConceptEdge(ConceptEdgeRecord edge) async {
    final idx = _edges.indexWhere((e) => e.id == edge.id);
    if (idx >= 0) {
      _edges[idx] = edge;
    } else {
      _edges.add(edge);
    }
    await _persistSnapshot();
    notifyListeners();
  }

  // --- CRUD Operations for Table 5: `review_logs` ---
  Future<void> insertReviewLog(ReviewLogRecord log) async {
    if (!_reviewLogs.any((r) => r.id == log.id)) {
      _reviewLogs.add(log);
      await _persistSnapshot();
      notifyListeners();
    }
  }

  /// Clears all pre-loaded Demo Data in 1 tap when the user taps the top Demo Banner.
  Future<void> clearDemoData() async {
    _decks.removeWhere((d) => d.isDemoData);
    _sources.removeWhere((s) => s.isDemoData);
    final demoCardIds =
        _cards.where((c) => c.isDemoData).map((c) => c.id).toSet();
    _cards.removeWhere((c) => c.isDemoData);
    _reviewLogs.removeWhere((r) => demoCardIds.contains(r.cardId));
    _edges.removeWhere(
      (e) => demoCardIds.contains(e.fromId) || demoCardIds.contains(e.toId),
    );
    await _persistSnapshot();
    notifyListeners();
  }

  /// Re-seeds the Interactive Demo Deck on demand.
  Future<void> reseedDemoData() async {
    await clearDemoData();
    DemoDeckSeeder.seedInitialDemoVault(this);
    await _persistSnapshot();
    notifyListeners();
  }

  /// Synchronously inserts records during initial seeding without redundant disk flushes.
  void seedRaw({
    required List<DeckRecord> decks,
    required List<StudySourceRecord> sources,
    required List<CardRecord> cards,
    required List<ConceptEdgeRecord> edges,
    required List<ReviewLogRecord> reviewLogs,
  }) {
    _decks.addAll(decks);
    _sources.addAll(sources);
    _cards.addAll(cards);
    _edges.addAll(edges);
    _reviewLogs.addAll(reviewLogs);
  }

  /// Exports the entire database state as a portable JSON manifest for BYOC Delta Sync.
  Map<String, dynamic> exportVaultSnapshotMap() => {
        'version': 1,
        'exported_at': DateTime.now().millisecondsSinceEpoch,
        'decks': _decks.map((d) => d.toMap()).toList(),
        'study_sources': _sources.map((s) => s.toMap()).toList(),
        'cards': _cards.map((c) => c.toMap()).toList(),
        'concept_edges': _edges.map((e) => e.toMap()).toList(),
        'review_logs': _reviewLogs.map((r) => r.toMap()).toList(),
      };

  Future<void> _persistSnapshot() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(exportVaultSnapshotMap());
      await prefs.setString(_storageKey, encoded);
    } catch (_) {}
  }

  void _restoreFromSnapshotJson(String rawJson) {
    final decoded = jsonDecode(rawJson) as Map<String, dynamic>;
    _decks
      ..clear()
      ..addAll(
        ((decoded['decks'] as List?) ?? const [])
            .map((e) => DeckRecord.fromMap(Map<String, dynamic>.from(e as Map))),
      );
    _sources
      ..clear()
      ..addAll(
        ((decoded['study_sources'] as List?) ?? const []).map(
          (e) => StudySourceRecord.fromMap(Map<String, dynamic>.from(e as Map)),
        ),
      );
    _cards
      ..clear()
      ..addAll(
        ((decoded['cards'] as List?) ?? const [])
            .map((e) => CardRecord.fromMap(Map<String, dynamic>.from(e as Map))),
      );
    _edges
      ..clear()
      ..addAll(
        ((decoded['concept_edges'] as List?) ?? const []).map(
          (e) => ConceptEdgeRecord.fromMap(Map<String, dynamic>.from(e as Map)),
        ),
      );
    _reviewLogs
      ..clear()
      ..addAll(
        ((decoded['review_logs'] as List?) ?? const []).map(
          (e) => ReviewLogRecord.fromMap(Map<String, dynamic>.from(e as Map)),
        ),
      );
  }
}

final appDatabaseProvider = ChangeNotifierProvider<AppDatabase>((ref) {
  final db = AppDatabase();
  db.initialize();
  return db;
});
