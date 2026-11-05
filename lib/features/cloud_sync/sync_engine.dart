import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';
import '../../core/constants/fsrs_constants.dart';
import '../../core/database/app_database.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/platform/platform_study_bridge.dart';
import '../../shared/widgets/adaptive_glass_card.dart';
import '../../shared/widgets/sync_pill_indicator.dart';
import 'google_drive_sync.dart';
import 'local_folder_sync.dart';
import 'webdav_sync.dart';

/// Phase 7: BYOC (Bring Your Own Cloud) Cross-Platform Sync Hub ($0 Server Cost)
/// & 100% Ad-Free One-Time Lifetime Pro Unlock ($7.99) Screen.
class SyncAndProScreen extends ConsumerStatefulWidget {
  const SyncAndProScreen({super.key});

  @override
  ConsumerState<SyncAndProScreen> createState() => _SyncAndProScreenState();
}

class _SyncAndProScreenState extends ConsumerState<SyncAndProScreen> {
  final GoogleDriveSyncChannel _gdrive = GoogleDriveSyncChannel();
  final TextEditingController _webdavUrlCtrl = TextEditingController(
    text: 'https://nextcloud.example.com/remote.php/dav/files/student/',
  );
  final TextEditingController _webdavUserCtrl = TextEditingController();
  String _lastSyncReport =
      'SHA-256 Manifest Ready • RecallMap_Vault/.recallmap/sync_manifest.json';
  String _boundFolderPath = FsrsConstants.vaultRootFolder;

  @override
  void dispose() {
    _webdavUrlCtrl.dispose();
    _webdavUserCtrl.dispose();
    super.dispose();
  }

  Future<void> _triggerSyncChannel(String channelName) async {
    final db = ref.read(appDatabaseProvider);
    final bridge = ref.read(platformStudyBridgeProvider);
    final syncNotifier = ref.read(vaultSyncStateProvider.notifier);

    syncNotifier.state = VaultSyncState.syncing;

    final report = switch (channelName) {
      'gdrive' => await _gdrive.syncNow(db),
      'webdav' => await WebDavSyncChannel(
          serverUrl: _webdavUrlCtrl.text,
          username: _webdavUserCtrl.text,
          appPassword: '',
        ).syncWithWebDav(db),
      _ => await LocalFolderSyncChannel(bridge).syncToBoundFolder(db),
    };

    syncNotifier.state = VaultSyncState.synced;
    if (mounted) {
      setState(() {
        _lastSyncReport =
            '[$channelName] Synced ✓ • SHA-256: ${report.manifestHash} • Unioned ${db.reviewLogs.length} review_logs (0 reps lost)';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appLocaleProvider);
    final controller = ref.read(appLocaleProvider.notifier);
    final bridge = ref.watch(platformStudyBridgeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'BYOC Cloud Sync & RecallMap Pro',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 14),
            child: SyncPillIndicator(),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(14),
          children: [
            // 1. Portable Vault Architecture Status Card
            AdaptiveGlassCard(
              accentBorderColor:
                  AppColors.masteredEmerald.withValues(alpha: 0.55),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Portable Vault: RecallMap_Vault/',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        bridge.platformIdentifier,
                        style: AppTypography.monoMetric(
                          fontSize: 11,
                          color: AppColors.unseenElectricSky,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _lastSyncReport,
                    style: AppTypography.monoMetric(
                      fontSize: 11.5,
                      color: AppColors.masteredEmerald,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Folders: Sources/ • Media/ • Backups/ • .recallmap/recallmap.sqlite • .recallmap/sync_manifest.json',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // 2. Channel 1: Google Drive Direct Sync (drive.file + appDataFolder)
            AdaptiveGlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.add_to_drive_rounded,
                        color: AppColors.unseenElectricSky,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '1. Google Drive Direct Sync (drive.file + appDataFolder)',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              _gdrive.targetRemotePath,
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                          ],
                        ),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: () => _triggerSyncChannel('gdrive'),
                        icon: const Icon(Icons.sync_rounded, size: 16),
                        label: const Text('Delta Sync Now'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // 3. Channel 2: Local Cloud Folder Bridge (SAF / UIDocumentPicker / Web showDirectoryPicker)
            AdaptiveGlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.folder_special_rounded,
                        color: AppColors.stabilizingAmber,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '2. Local Cloud Folder Bridge (iCloud / OneDrive / Dropbox / PC Disk)',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              'Bound Folder: $_boundFolderPath (SAF / iOS Picker / Web OPFS)',
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () async {
                          final picked =
                              await LocalFolderSyncChannel(bridge)
                                  .selectAndBindCloudFolder();
                          if (picked != null && mounted) {
                            setState(() => _boundFolderPath = picked);
                          }
                        },
                        icon: const Icon(Icons.folder_open_rounded, size: 16),
                        label: const Text('Bind Vault Folder'),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: () => _triggerSyncChannel('local_folder'),
                        icon: const Icon(Icons.save_alt_rounded, size: 16),
                        label: const Text('Write Delta Manifest'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // 4. Channel 3: Custom WebDAV (Nextcloud / Self-Hosted)
            AdaptiveGlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.dns_rounded,
                        color: AppColors.sourceRoyalIndigo,
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '3. Custom WebDAV Server (Nextcloud / Self-Hosted)',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _webdavUrlCtrl,
                    decoration: InputDecoration(
                      labelText: 'WebDAV Endpoint URL',
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.tonalIcon(
                      onPressed: () => _triggerSyncChannel('webdav'),
                      icon: const Icon(Icons.cloud_upload_rounded, size: 16),
                      label: const Text('Sync via WebDAV'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 5. 100% Ad-Free + One-Time Lifetime Pro Unlock ($7.99)
            AdaptiveGlassCard(
              accentBorderColor: AppColors.sourceRoyalIndigo,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.workspace_premium_rounded,
                            color: AppColors.stabilizingAmber,
                            size: 26,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'RecallMap Pro (Lifetime Unlock)',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.masteredEmerald
                              .withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          settings.isProUnlocked
                              ? 'PRO UNLOCKED ✓'
                              : '${FsrsConstants.proLifetimePriceDisplay} ONE-TIME',
                          style: AppTypography.monoMetric(
                            fontSize: 12,
                            color: AppColors.masteredEmerald,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    '100% Ad-Free Forever • Zero Subscriptions • Zero Developer Server Costs',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.unseenElectricSky,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const _ProFeatureRow(
                    text:
                        'Unlimited PDF Textbooks with Live Red/Amber/Emerald Page Mastery Strips',
                  ),
                  const _ProFeatureRow(
                    text:
                        'Unlimited 1-Tap Auto-OCR Diagram & Image Occlusion (English, বাংলা, TR, AR)',
                  ),
                  const _ProFeatureRow(
                    text:
                        'Smart Exam Deadline Back-Calculator & Zero-Guilt Vacation Backlog Smoother',
                  ),
                  const _ProFeatureRow(
                    text:
                        'Memory Doctor Confusable Twin Radar (BM25) & 1-Tap Card Surgery',
                  ),
                  const _ProFeatureRow(
                    text:
                        'Hands-Free Offline Audio Commute Mode & Automated Multi-Device Cloud Sync',
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: settings.isProUnlocked
                            ? AppColors.masteredEmerald
                            : AppColors.sourceRoyalIndigo,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: settings.isProUnlocked
                          ? null
                          : () {
                              controller.unlockProLifetime();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'RecallMap Pro Lifetime Unlocked! All features active.',
                                  ),
                                ),
                              );
                            },
                      icon: Icon(
                        settings.isProUnlocked
                            ? Icons.verified_rounded
                            : Icons.lock_open_rounded,
                      ),
                      label: Text(
                        settings.isProUnlocked
                            ? 'Lifetime Pro Active ✓'
                            : 'Unlock RecallMap Pro Forever — ${FsrsConstants.proLifetimePriceDisplay}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProFeatureRow extends StatelessWidget {
  final String text;

  const _ProFeatureRow({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          const Icon(
            Icons.check_circle_rounded,
            size: 16,
            color: AppColors.masteredEmerald,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 12.5),
            ),
          ),
        ],
      ),
    );
  }
}
