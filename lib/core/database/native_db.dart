import '../constants/fsrs_constants.dart';

/// Native ARM64 SQLite FFI database descriptor for iOS, Android, macOS, Windows, and Linux.
/// Stores database inside `RecallMap_Vault/.recallmap/recallmap.sqlite` with FTS5 (`unicode61`) enabled.
class NativeDatabaseConfig {
  NativeDatabaseConfig._();

  static String resolveSqliteVaultPath(String vaultRootPath) {
    final normalized = vaultRootPath.replaceAll('\\', '/');
    return '$normalized/.recallmap/${FsrsConstants.vaultSqliteFileName}';
  }

  /// Complete SQLite + FTS5 DDL schema executed on native SQLite connection open.
  static const List<String> schemaStatements = [
    '''
    CREATE TABLE IF NOT EXISTS decks (
      id TEXT PRIMARY KEY NOT NULL,
      parent_id TEXT REFERENCES decks(id) ON DELETE SET NULL,
      title TEXT NOT NULL,
      description TEXT NOT NULL DEFAULT '',
      language_code TEXT NOT NULL DEFAULT 'en',
      color_hex TEXT NOT NULL DEFAULT '#6366F1',
      icon_name TEXT NOT NULL DEFAULT 'school',
      exam_date INTEGER,
      target_retention REAL NOT NULL DEFAULT 0.90,
      daily_new_limit INTEGER NOT NULL DEFAULT 25,
      custom_fsrs_weights_json TEXT,
      is_demo_data INTEGER NOT NULL DEFAULT 0,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL,
      content_hash TEXT NOT NULL,
      is_deleted INTEGER NOT NULL DEFAULT 0
    );
    ''',
    '''
    CREATE TABLE IF NOT EXISTS study_sources (
      id TEXT PRIMARY KEY NOT NULL,
      deck_id TEXT NOT NULL REFERENCES decks(id) ON DELETE CASCADE,
      source_type TEXT NOT NULL,
      title TEXT NOT NULL,
      markdown_body TEXT NOT NULL DEFAULT '',
      relative_file_path TEXT,
      page_count INTEGER NOT NULL DEFAULT 1,
      last_read_page INTEGER NOT NULL DEFAULT 1,
      tags_json TEXT NOT NULL DEFAULT '[]',
      graph_x REAL,
      graph_y REAL,
      is_demo_data INTEGER NOT NULL DEFAULT 0,
      updated_at INTEGER NOT NULL,
      content_hash TEXT NOT NULL,
      is_deleted INTEGER NOT NULL DEFAULT 0
    );
    ''',
    '''
    CREATE TABLE IF NOT EXISTS cards (
      id TEXT PRIMARY KEY NOT NULL,
      deck_id TEXT NOT NULL REFERENCES decks(id) ON DELETE CASCADE,
      source_id TEXT REFERENCES study_sources(id) ON DELETE SET NULL,
      source_page INTEGER,
      source_rect_json TEXT,
      card_type TEXT NOT NULL,
      front_md TEXT NOT NULL,
      back_md TEXT NOT NULL,
      occlusion_masks_json TEXT,
      mnemonic_sketch_json TEXT,
      tags_json TEXT NOT NULL DEFAULT '[]',
      state INTEGER NOT NULL DEFAULT 0,
      due_date INTEGER NOT NULL,
      stability REAL NOT NULL DEFAULT 0.0,
      difficulty REAL NOT NULL DEFAULT 0.0,
      elapsed_days REAL NOT NULL DEFAULT 0.0,
      scheduled_days REAL NOT NULL DEFAULT 0.0,
      reps INTEGER NOT NULL DEFAULT 0,
      lapses INTEGER NOT NULL DEFAULT 0,
      last_review INTEGER,
      is_leech INTEGER NOT NULL DEFAULT 0,
      is_suspended INTEGER NOT NULL DEFAULT 0,
      is_demo_data INTEGER NOT NULL DEFAULT 0,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL,
      content_hash TEXT NOT NULL,
      is_deleted INTEGER NOT NULL DEFAULT 0
    );
    ''',
    '''
    CREATE TABLE IF NOT EXISTS concept_edges (
      id TEXT PRIMARY KEY NOT NULL,
      from_id TEXT NOT NULL,
      to_id TEXT NOT NULL,
      edge_type TEXT NOT NULL,
      strength REAL NOT NULL DEFAULT 1.0,
      created_at INTEGER NOT NULL
    );
    ''',
    '''
    CREATE TABLE IF NOT EXISTS review_logs (
      id TEXT PRIMARY KEY NOT NULL,
      card_id TEXT NOT NULL REFERENCES cards(id) ON DELETE CASCADE,
      rating INTEGER NOT NULL,
      state_before INTEGER NOT NULL,
      stability_before REAL NOT NULL,
      difficulty_before REAL NOT NULL,
      stability_after REAL NOT NULL,
      difficulty_after REAL NOT NULL,
      elapsed_days REAL NOT NULL,
      scheduled_days REAL NOT NULL,
      review_duration_ms INTEGER NOT NULL,
      reviewed_at INTEGER NOT NULL
    );
    ''',
    '''
    CREATE VIRTUAL TABLE IF NOT EXISTS fts_study_search USING fts5(
      entity_id UNINDEXED,
      entity_type UNINDEXED,
      deck_id UNINDEXED,
      title_or_front,
      body_or_back,
      tags_json,
      tokenize = 'unicode61'
    );
    ''',
  ];
}
