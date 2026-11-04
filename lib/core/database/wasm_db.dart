import '../constants/fsrs_constants.dart';

/// WebAssembly (WASM) + Origin-Private File System (OPFS) SQLite configuration
/// for 100% offline PWA execution (`sqlite3.wasm` + `drift_worker.js` with IndexedDB fallback).
class WasmDatabaseConfig {
  WasmDatabaseConfig._();

  static const String sqlite3WasmUri = 'sqlite3.wasm';
  static const String driftWorkerUri = 'drift_worker.js';
  static const String opfsDatabaseName = 'recallmap_opfs_vault';

  static Map<String, String> get opfsHeaders => const {
        'Cross-Origin-Opener-Policy': 'same-origin',
        'Cross-Origin-Embedder-Policy': 'require-corp',
        'X-RecallMap-Vault': FsrsConstants.vaultInternalFolder,
      };
}
