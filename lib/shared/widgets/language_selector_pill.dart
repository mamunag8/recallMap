import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/i18n/app_localizations.dart';

/// Instant UI Localization Switcher Pill (`🌐 EN / বাংলা / TR / عربي...`) +
/// Bengali Numerals Toggle (`০-৯` vs `0-9`) and Theme Switcher.
class LanguageSelectorPill extends ConsumerWidget {
  const LanguageSelectorPill({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appLocaleProvider);
    final currentInfo = AppLocalizations.infoFor(settings.languageCode);

    return InkWell(
      onTap: () => _showLanguageAndThemeSheet(context, ref),
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.sourceRoyalIndigo.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: AppColors.sourceRoyalIndigo.withValues(alpha: 0.45),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.language_rounded,
              size: 14,
              color: AppColors.sourceRoyalIndigo,
            ),
            const SizedBox(width: 5),
            Text(
              currentInfo.flagLabel,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.sourceRoyalIndigo,
              ),
            ),
            const SizedBox(width: 2),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 14,
              color: AppColors.sourceRoyalIndigo,
            ),
          ],
        ),
      ),
    );
  }

  void _showLanguageAndThemeSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return Consumer(
          builder: (context, ref, _) {
            final settings = ref.watch(appLocaleProvider);
            final l10n = ref.watch(l10nProvider);
            final controller = ref.read(appLocaleProvider.notifier);

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          l10n.t('welcome_pick_lang'),
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        FilterChip(
                          selected: settings.useBengaliNumerals,
                          onSelected: (_) => controller.toggleBengaliNumerals(),
                          label: const Text('বাংলা সংখ্যা (০-৯)'),
                          selectedColor:
                              AppColors.masteredEmerald.withValues(alpha: 0.25),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: AppLocalizations.supportedLanguages.map((lang) {
                        final isSelected = settings.languageCode == lang.code;
                        return ChoiceChip(
                          selected: isSelected,
                          onSelected: (_) => controller.setLanguage(lang.code),
                          label: Text('${lang.flagLabel} • ${lang.nativeName}'),
                          selectedColor: AppColors.sourceRoyalIndigo
                              .withValues(alpha: 0.25),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      l10n.t('welcome_pick_theme'),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      children: [
                        ChoiceChip(
                          selected: settings.themeMode ==
                              RecallThemeMode.obsidianDark,
                          onSelected: (_) => controller
                              .setThemeMode(RecallThemeMode.obsidianDark),
                          label: Text(l10n.t('theme_obsidian')),
                        ),
                        ChoiceChip(
                          selected:
                              settings.themeMode == RecallThemeMode.cleanLight,
                          onSelected: (_) => controller
                              .setThemeMode(RecallThemeMode.cleanLight),
                          label: Text(l10n.t('theme_light')),
                        ),
                        ChoiceChip(
                          selected:
                              settings.themeMode == RecallThemeMode.oledBlack,
                          onSelected: (_) => controller
                              .setThemeMode(RecallThemeMode.oledBlack),
                          label: Text(l10n.t('theme_oled')),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
