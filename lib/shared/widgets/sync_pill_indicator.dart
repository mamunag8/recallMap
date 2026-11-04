import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/i18n/app_localizations.dart';

enum VaultSyncState {
  synced,
  syncing,
  offlineLocal,
}

final vaultSyncStateProvider = StateProvider<VaultSyncState>(
  (ref) => VaultSyncState.synced,
);

/// Top Global Bar Cloud Sync Pill displaying live status (`Synced ✓`, `Syncing...`, `Offline Local`).
class SyncPillIndicator extends ConsumerWidget {
  final VoidCallback? onTap;

  const SyncPillIndicator({super.key, this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncState = ref.watch(vaultSyncStateProvider);
    final l10n = ref.watch(l10nProvider);

    final (label, color, icon) = switch (syncState) {
      VaultSyncState.synced => (
          l10n.t('sync_synced'),
          AppColors.masteredEmerald,
          Icons.cloud_done_rounded,
        ),
      VaultSyncState.syncing => (
          l10n.t('sync_syncing'),
          AppColors.stabilizingAmber,
          Icons.sync_rounded,
        ),
      VaultSyncState.offlineLocal => (
          l10n.t('sync_offline'),
          AppColors.unseenElectricSky,
          Icons.offline_pin_rounded,
        ),
    };

    return InkWell(
      onTap: onTap ??
          () {
            // Cycle or trigger instant delta sync check
            final notifier = ref.read(vaultSyncStateProvider.notifier);
            notifier.state = VaultSyncState.syncing;
            Future.delayed(const Duration(milliseconds: 650), () {
              notifier.state = VaultSyncState.synced;
            });
          },
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: 0.45)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
