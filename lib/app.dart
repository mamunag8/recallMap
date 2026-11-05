import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'core/constants/app_typography.dart';
import 'core/constants/fsrs_constants.dart';
import 'core/i18n/app_localizations.dart';
import 'features/ai_card_bridge/ai_token_saver_screen.dart';
import 'features/cloud_sync/sync_engine.dart';
import 'features/creation_studio/inline_outliner_editor.dart';
import 'features/layer1_cockpit/cockpit_home_screen.dart';
import 'features/layer2_xray/pdf_split_studio_screen.dart';
import 'features/layer3_inspector/card_deep_inspector_sheet.dart';
import 'features/study_player/study_session_screen.dart';

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

/// Unified Multi-Layer Adaptive Navigation Shell for RecallMap (All 7 Phases Active).
class RecallMapShell extends ConsumerWidget {
  const RecallMapShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentTab = ref.watch(activeShellTabProvider);
    final focusedPage = ref.watch(focusedPdfPageProvider);
    final l10n = ref.watch(l10nProvider);

    return Scaffold(
      body: IndexedStack(
        index: currentTab,
        children: [
          // Tab 0: Layer 1 "At-a-Glance" Cockpit
          CockpitHomeScreen(
            onNavigateToXRayForDeck: (deckId) {
              ref.read(focusedDeckIdProvider.notifier).state = deckId;
              ref.read(activeShellTabProvider.notifier).state = 1;
            },
            onInspectCardLayer3: (card) {
              CardDeepInspectorSheet.show(
                context,
                card: card,
                onJumpToFullPdfPage: () {
                  ref.read(focusedPdfPageProvider.notifier).state =
                      card.sourcePage ?? 1;
                  ref.read(activeShellTabProvider.notifier).state = 1;
                },
              );
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

          // Tab 1: Layer 2 & Layer 3 Visual Zoom — Split-Screen PDF Studio with Page Mastery Strip & 2D Concept RecallMap
          PdfSplitStudioScreen(
            initialPage: focusedPage,
            onStartTargetedStudy: (_) {
              ref.read(activeShellTabProvider.notifier).state = 3;
            },
          ),

          // Tab 2: Zero-Typing Creation Studio — 1-Tap Auto-OCR Diagram Occlusion & Inline :: Outliner
          const InlineOutlinerEditor(),

          // Tab 3: Multi-Sensory Active Recall Study Player (Gestures, Scratchpad, Boss Battle & Commute TTS)
          const StudySessionScreen(),

          // Tab 4: Zero-Cost AI Flashcard Generator Bridge (Token-Saver + Clipboard Parser) & 2-Way Anki (.apkg) Interop
          const AiTokenSaverScreen(),

          // Tab 5: BYOC Cross-Platform Cloud Sync (Google Drive, SAF/OPFS, WebDAV) & One-Time Pro Unlock
          const SyncAndProScreen(),
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
