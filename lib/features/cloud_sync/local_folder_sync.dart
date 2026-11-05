import 'dart:convert';
import 'dart:typed_data';
import '../../core/constants/fsrs_constants.dart';
import '../../core/database/app_database.dart';
import '../../core/platform/platform_study_bridge.dart';
import 'delta_manifest_resolver.dart';

/// Channel 2: Local Cloud Folder Bridge (iCloud Drive / OneDrive / Dropbox / Local PC Disk).
/// Uses Android SAF, iOS `UIDocumentPickerViewController`, or Web `window.showDirectoryPicker()`.
class LocalFolderSyncChannel {
  final PlatformStudyBridge bridge;

  const LocalFolderSyncChannel(this.bridge);

  Future<String?> selectAndBindCloudFolder() {
    return bridge.pickUserCloudVaultFolder();
  }

  Future<DeltaMergeReport> syncToBoundFolder(AppDatabase db) async {
    final snapshot = db.exportVaultSnapshotMap();
    final jsonBytes = Uint8List.fromList(
      utf8.encode(const JsonEncoder.withIndent('  ').convert(snapshot)),
    );
    await bridge.writeVaultFile(
      '.recallmap/sync_manifest.json',
      jsonBytes,
    );
    return DeltaManifestResolver.mergeRemoteSnapshot(
      localDb: db,
      remoteSnapshot: snapshot,
    );
  }

  String get defaultVaultStructureSummary =>
      '${FsrsConstants.vaultRootFolder}/ (Sources/, Media/, Backups/, .recallmap/sync_manifest.json)';
}
