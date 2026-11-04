import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/i18n/app_localizations.dart';
import '../../shared/widgets/adaptive_glass_card.dart';

/// 60-Second Interactive Onboarding & 4-Step Spotlight Coach-Marks Overlay:
/// 1. 10-Second Welcome Modal: Pick UI Language (English, বাংলা, Türkçe, العربية, etc.),
///    Visual Theme (Obsidian Dark, Clean Light, OLED Pitch Black), and Target Goal.
/// 2. 4-Step Interactive Spotlight Coach-Marks highlighting:
///    - Step 1: At-a-Glance Cockpit (Readiness Ring & Mastery Bubbles)
///    - Step 2: PDF Page Mastery Strip
///    - Step 3: 1-Tap Auto-OCR Diagram Occlusion
///    - Step 4: Free AI Card Bridge & BYOC Cloud Sync
class SpotlightTutorialOverlay extends ConsumerStatefulWidget {
  final VoidCallback onFinished;

  const SpotlightTutorialOverlay({
    super.key,
    required this.onFinished,
  });

  @override
  ConsumerState<SpotlightTutorialOverlay> createState() =>
      _SpotlightTutorialOverlayState();
}

class _SpotlightTutorialOverlayState
    extends ConsumerState<SpotlightTutorialOverlay> {
  // stage 0 = Welcome Modal, stage 1..4 = 4-Step Spotlight Coach-Marks
  int _stage = 0;

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appLocaleProvider);
    final l10n = ref.watch(l10nProvider);
    final controller = ref.read(appLocaleProvider.notifier);

    return Material(
      color: Colors.black.withValues(alpha: 0.78),
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: _stage == 0
                  ? _buildWelcomeModal(context, settings, l10n, controller)
                  : _buildSpotlightStepCard(context, l10n, controller),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeModal(
    BuildContext context,
    AppLocaleSettings settings,
    AppLocalizations l10n,
    AppLocaleController controller,
  ) {
    return AdaptiveGlassCard(
      accentBorderColor: AppColors.sourceRoyalIndigo,
      padding: const EdgeInsets.all(22),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.sourceRoyalIndigo.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.psychology_alt_rounded,
                    color: AppColors.sourceRoyalIndigo,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.t('app_name'),
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      Text(
                        l10n.t('welcome_title'),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // 1. Pick UI Language
            Text(
              l10n.t('welcome_pick_lang'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: AppLocalizations.supportedLanguages.take(6).map((lang) {
                final selected = settings.languageCode == lang.code;
                return ChoiceChip(
                  selected: selected,
                  onSelected: (_) => controller.setLanguage(lang.code),
                  label: Text('${lang.flagLabel} • ${lang.nativeName}'),
                  selectedColor:
                      AppColors.sourceRoyalIndigo.withValues(alpha: 0.28),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // 2. Pick Visual Theme
            Text(
              l10n.t('welcome_pick_theme'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  selected: settings.themeMode == RecallThemeMode.obsidianDark,
                  onSelected: (_) =>
                      controller.setThemeMode(RecallThemeMode.obsidianDark),
                  label: Text(l10n.t('theme_obsidian')),
                ),
                ChoiceChip(
                  selected: settings.themeMode == RecallThemeMode.cleanLight,
                  onSelected: (_) =>
                      controller.setThemeMode(RecallThemeMode.cleanLight),
                  label: Text(l10n.t('theme_light')),
                ),
                ChoiceChip(
                  selected: settings.themeMode == RecallThemeMode.oledBlack,
                  onSelected: (_) =>
                      controller.setThemeMode(RecallThemeMode.oledBlack),
                  label: Text(l10n.t('theme_oled')),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 3. Pick Target Goal
            Text(
              l10n.t('welcome_pick_goal'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                'goal_university',
                'goal_medical',
                'goal_language',
              ].map((goalKey) {
                final selected = settings.studyGoal == goalKey;
                return ChoiceChip(
                  selected: selected,
                  onSelected: (_) => controller.setStudyGoal(goalKey),
                  label: Text(l10n.t(goalKey)),
                  selectedColor:
                      AppColors.masteredEmerald.withValues(alpha: 0.25),
                );
              }).toList(),
            ),
            const SizedBox(height: 22),

            Row(
              children: [
                TextButton(
                  onPressed: () {
                    controller.completeOnboarding();
                    widget.onFinished();
                  },
                  child: const Text('Skip Tour'),
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: () => setState(() => _stage = 1),
                  icon: const Icon(Icons.rocket_launch_rounded, size: 18),
                  label: Text(l10n.t('launch_cockpit_btn')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSpotlightStepCard(
    BuildContext context,
    AppLocalizations l10n,
    AppLocaleController controller,
  ) {
    final (titleKey, descKey, icon, color) = switch (_stage) {
      1 => (
          'spotlight_step1_title',
          'spotlight_step1_desc',
          Icons.donut_large_rounded,
          AppColors.masteredEmerald,
        ),
      2 => (
          'spotlight_step2_title',
          'spotlight_step2_desc',
          Icons.menu_book_rounded,
          AppColors.urgentCrimson,
        ),
      3 => (
          'spotlight_step3_title',
          'spotlight_step3_desc',
          Icons.document_scanner_rounded,
          AppColors.stabilizingAmber,
        ),
      _ => (
          'spotlight_step4_title',
          'spotlight_step4_desc',
          Icons.auto_awesome_rounded,
          AppColors.unseenElectricSky,
        ),
    };

    return AdaptiveGlassCard(
      accentBorderColor: color,
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: color.withValues(alpha: 0.2),
                foregroundColor: color,
                child: Icon(icon),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  l10n.t(titleKey),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            l10n.t(descKey),
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: List.generate(4, (i) {
                  final active = (i + 1) == _stage;
                  return Container(
                    margin: const EdgeInsets.only(right: 6),
                    width: active ? 22 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: active ? color : color.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  );
                }),
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: color),
                onPressed: () {
                  if (_stage < 4) {
                    setState(() => _stage++);
                  } else {
                    controller.completeOnboarding();
                    widget.onFinished();
                  }
                },
                child: Text(
                  _stage < 4
                      ? l10n.t('spotlight_next')
                      : l10n.t('spotlight_finish'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
