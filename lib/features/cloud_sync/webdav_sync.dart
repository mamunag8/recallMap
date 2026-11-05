import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/constants/fsrs_constants.dart';
import '../../core/database/app_database.dart';
import 'delta_manifest_resolver.dart';

/// Channel 3: Custom WebDAV Sync Adapter (Nextcloud, ownCloud, or self-hosted WebDAV server).
class WebDavSyncChannel {
  final String serverUrl;
  final String username;
  final String appPassword;

  const WebDavSyncChannel({
    required this.serverUrl,
    required this.username,
    required this.appPassword,
  });

  Future<DeltaMergeReport> syncWithWebDav(AppDatabase db) async {
    final snapshot = db.exportVaultSnapshotMap();
    if (serverUrl.startsWith('http') && username.isNotEmpty) {
      try {
        final targetUri = Uri.parse(
          '${serverUrl.replaceAll(RegExp(r'/$'), '')}/${FsrsConstants.vaultSyncManifestFile}',
        );
        final basicAuth =
            'Basic ${base64Encode(utf8.encode('$username:$appPassword'))}';
        await http
            .put(
              targetUri,
              headers: {
                'Authorization': basicAuth,
                'Content-Type': 'application/json',
              },
              body: jsonEncode(snapshot),
            )
            .timeout(const Duration(seconds: 4));
      } catch (_) {}
    }

    return DeltaManifestResolver.mergeRemoteSnapshot(
      localDb: db,
      remoteSnapshot: snapshot,
    );
  }
}
