import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'core/constants/app_typography.dart';
import 'core/constants/fsrs_constants.dart';
import 'core/i18n/app_localizations.dart';
import 'features/layer1_cockpit/cockpit_home_screen.dart';

/// Active tab index provider for the unified RecallMap navigation shell.
final activeShellTabProvider = StateProvider<int>((ref) => 0);

/// Focused deck / source / card context when zooming from Layer 1 Cockpit into Layer 2 or Layer 3.
final focusedDeckIdProvider = StateProvider<String?>((ref) => null);
final focusedPdfPageProvider = StateProvider<int?>((ref) => null);

final recallRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const RecallMapShell(),
      ),
    ],
  );
});

class RecallMapApp extends ConsumerWidget {
  const RecallMapApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localeSettings = ref.watch(appLocaleProvider);
    final router = ref.watch(recallRouterProvider);

    final theme = AppTypography.buildTheme(
      mode: localeSettings.themeMode,
      languageCode: localeSettings.languageCode,
    );

    return MaterialApp.router(
      title: FsrsConstants.storeTitle,
      debugShowCheckedModeBanner: false,
      theme: theme,
      routerConfig: router,
      builder: (context, child) {
        return Directionality(
          textDirection: localeSettings.textDirection,
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}

/// Unified Multi-Layer Adaptive Navigation Shell for RecallMap.
/// Connects Layer 1 Cockpit with Layer 2 X-Ray, Creation Studio, Study Player,
/// AI Card Bridge, and BYOC Cloud Sync.
class RecallMapShell extends ConsumerWidget {
  const RecallMapShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentTab = ref.watch(activeShellTabProvider);
    final l10n = ref.watch(l10nProvider);

    return Scaffold(
      body: IndexedStack(
        index: currentTab,
        children: [
          // Tab 0: Layer 1 "At-a-Glance" Cockpit (Completed in Phase 1 & 2)
          CockpitHomeScreen(
            onNavigateToXRayForDeck: (deckId) {
              ref.read(focusedDeckIdProvider.notifier).state = deckId;
              ref.read(activeShellTabProvider.notifier).state = 1;
            },
            onStartHighYieldSession: () {
              ref.read(activeShellTabProvider.notifier).state = 3;
            },
            onJumpToPdfSource: (card) {
              ref.read(focusedDeckIdProvider.notifier).state = card.deckId;
              ref.read(focusedPdfPageProvider.notifier).state =
                  card.sourcePage ?? 1;
              ref.read(activeShellTabProvider.notifier).state = 1;
            },
          ),
          // Tabs 1..5 will be wired with full implementations in Phases 3–7
          _PhaseReadyView(
            title: l10n.t('nav_xray'),
            subtitle:
                'Layer 2 & Layer 3: Split-Screen PDF Studio with Page Mastery Strip, 2D Concept RecallMap & DSR Curve Inspector (Phase 3)',
            icon: Icons.hub_rounded,
          ),
          _PhaseReadyView(
            title: l10n.t('nav_create'),
            subtitle:
                'Zero-Typing Creation Studio: 1-Tap Auto-OCR Diagram Occlusion, PDF Highlight/Crop & Inline :: Outliner (Phase 4)',
            icon: Icons.auto_fix_high_rounded,
          ),
          _PhaseReadyView(
            title: l10n.t('nav_study'),
            subtitle:
                'Multi-Sensory Study Player: 4-Way Swipe Gestures, Transparent Scratchpad, LaTeX, Boss Battle & Offline TTS (Phase 5)',
            icon: Icons.style_rounded,
          ),
          _PhaseReadyView(
            title: l10n.t('nav_ai_bridge'),
            subtitle:
                'Zero-Cost AI Flashcard Bridge (Token-Saver + Clipboard Parser) & 2-Way Anki (.apkg) Interop (Phase 6)',
            icon: Icons.bolt_rounded,
          ),
          _PhaseReadyView(
            title: l10n.t('nav_sync_pro'),
            subtitle:
                'BYOC Cloud Sync (Google Drive, SAF/OPFS, WebDAV) & One-Time Pro Unlock (Phase 7)',
            icon: Icons.cloud_sync_rounded,
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentTab,
        onDestinationSelected: (idx) =>
            ref.read(activeShellTabProvider.notifier).state = idx,
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.space_dashboard_outlined),
            selectedIcon: const Icon(Icons.space_dashboard_rounded),
            label: l10n.t('nav_cockpit'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.hub_outlined),
            selectedIcon: const Icon(Icons.hub_rounded),
            label: l10n.t('nav_xray'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.add_box_outlined),
            selectedIcon: const Icon(Icons.add_box_rounded),
            label: l10n.t('nav_create'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.play_circle_outline_rounded),
            selectedIcon: const Icon(Icons.play_circle_rounded),
            label: l10n.t('nav_study'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.auto_awesome_outlined),
            selectedIcon: const Icon(Icons.auto_awesome_rounded),
            label: l10n.t('nav_ai_bridge'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.cloud_done_outlined),
            selectedIcon: const Icon(Icons.cloud_done_rounded),
            label: l10n.t('nav_sync_pro'),
          ),
        ],
      ),
    );
  }
}

class _PhaseReadyView extends ConsumerWidget {
  final String title;
  final String subtitle;
  final IconData icon;

  const _PhaseReadyView({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 54, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 16),
              Text(
                title,
                style: Theme.of(context).textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () =>
                    ref.read(activeShellTabProvider.notifier).state = 0,
                icon: const Icon(Icons.arrow_back_rounded),
                label: const Text('Return to Layer 1 Cockpit'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
