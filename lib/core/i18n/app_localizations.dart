import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/app_colors.dart';
import 'l10n_en.dart';
import 'l10n_bn.dart';
import 'l10n_tr.dart';
import 'l10n_ar.dart';
import 'l10n_extra.dart';

class SupportedLanguageInfo {
  final String code;
  final String nativeName;
  final String flagLabel;
  final bool isRtl;
  final String ttsLocale;

  const SupportedLanguageInfo({
    required this.code,
    required this.nativeName,
    required this.flagLabel,
    this.isRtl = false,
    required this.ttsLocale,
  });
}

class AppLocaleSettings {
  final String languageCode;
  final bool useBengaliNumerals;
  final RecallThemeMode themeMode;
  final bool hasCompletedOnboarding;
  final bool isProUnlocked;
  final String studyGoal;

  const AppLocaleSettings({
    this.languageCode = 'en',
    this.useBengaliNumerals = false,
    this.themeMode = RecallThemeMode.obsidianDark,
    this.hasCompletedOnboarding = false,
    this.isProUnlocked = false,
    this.studyGoal = 'goal_university',
  });

  bool get isRtl => languageCode == 'ar' || languageCode == 'ur';

  TextDirection get textDirection =>
      isRtl ? TextDirection.rtl : TextDirection.ltr;

  AppLocaleSettings copyWith({
    String? languageCode,
    bool? useBengaliNumerals,
    RecallThemeMode? themeMode,
    bool? hasCompletedOnboarding,
    bool? isProUnlocked,
    String? studyGoal,
  }) {
    return AppLocaleSettings(
      languageCode: languageCode ?? this.languageCode,
      useBengaliNumerals: useBengaliNumerals ?? this.useBengaliNumerals,
      themeMode: themeMode ?? this.themeMode,
      hasCompletedOnboarding:
          hasCompletedOnboarding ?? this.hasCompletedOnboarding,
      isProUnlocked: isProUnlocked ?? this.isProUnlocked,
      studyGoal: studyGoal ?? this.studyGoal,
    );
  }
}

class AppLocaleController extends StateNotifier<AppLocaleSettings> {
  AppLocaleController() : super(const AppLocaleSettings());

  void setLanguage(String code) {
    state = state.copyWith(
      languageCode: code,
      useBengaliNumerals: code == 'bn' ? true : state.useBengaliNumerals,
    );
  }

  void toggleBengaliNumerals() {
    state = state.copyWith(useBengaliNumerals: !state.useBengaliNumerals);
  }

  void setThemeMode(RecallThemeMode mode) {
    state = state.copyWith(themeMode: mode);
  }

  void setStudyGoal(String goal) {
    state = state.copyWith(studyGoal: goal);
  }

  void completeOnboarding() {
    state = state.copyWith(hasCompletedOnboarding: true);
  }

  void unlockProLifetime() {
    state = state.copyWith(isProUnlocked: true);
  }
}

final appLocaleProvider =
    StateNotifierProvider<AppLocaleController, AppLocaleSettings>(
  (ref) => AppLocaleController(),
);

/// Reactive Localization & Bengali Numerals Engine for RecallMap.
class AppLocalizations {
  final AppLocaleSettings settings;

  const AppLocalizations(this.settings);

  static const List<SupportedLanguageInfo> supportedLanguages = [
    SupportedLanguageInfo(
      code: 'en',
      nativeName: 'English',
      flagLabel: 'EN',
      ttsLocale: 'en-US',
    ),
    SupportedLanguageInfo(
      code: 'bn',
      nativeName: 'বাংলা (Bangla)',
      flagLabel: 'বাংলা',
      ttsLocale: 'bn-BD',
    ),
    SupportedLanguageInfo(
      code: 'tr',
      nativeName: 'Türkçe',
      flagLabel: 'TR',
      ttsLocale: 'tr-TR',
    ),
    SupportedLanguageInfo(
      code: 'ar',
      nativeName: 'العربية (Arabic)',
      flagLabel: 'عربي',
      isRtl: true,
      ttsLocale: 'ar-SA',
    ),
    SupportedLanguageInfo(
      code: 'hi',
      nativeName: 'हिन्दी (Hindi)',
      flagLabel: 'हिन्दी',
      ttsLocale: 'hi-IN',
    ),
    SupportedLanguageInfo(
      code: 'es',
      nativeName: 'Español',
      flagLabel: 'ES',
      ttsLocale: 'es-ES',
    ),
    SupportedLanguageInfo(
      code: 'fr',
      nativeName: 'Français',
      flagLabel: 'FR',
      ttsLocale: 'fr-FR',
    ),
    SupportedLanguageInfo(
      code: 'zh',
      nativeName: '中文 (Mandarin)',
      flagLabel: '中文',
      ttsLocale: 'zh-CN',
    ),
    SupportedLanguageInfo(
      code: 'id',
      nativeName: 'Bahasa Indonesia',
      flagLabel: 'ID',
      ttsLocale: 'id-ID',
    ),
    SupportedLanguageInfo(
      code: 'ur',
      nativeName: 'اردو (Urdu)',
      flagLabel: 'اردو',
      isRtl: true,
      ttsLocale: 'ur-PK',
    ),
  ];

  static SupportedLanguageInfo infoFor(String code) {
    return supportedLanguages.firstWhere(
      (l) => l.code == code,
      orElse: () => supportedLanguages.first,
    );
  }

  /// Translates a key into the active language, falling back to English.
  String t(String key) {
    final code = settings.languageCode;
    final Map<String, String> activeDict = switch (code) {
      'en' => l10nEn,
      'bn' => l10nBn,
      'tr' => l10nTr,
      'ar' => l10nAr,
      _ => l10nExtra[code] ?? l10nEn,
    };
    final raw = activeDict[key] ?? l10nEn[key] ?? key;
    return settings.useBengaliNumerals ? toBengaliDigits(raw) : raw;
  }

  /// Formats any number or interval string using Bengali digits (০ ১ ২ ৩ ৪ ৫ ৬ ৭ ৮ ৯)
  /// when the Bengali numeral toggle is enabled.
  String formatNumber(Object value) {
    final str = value.toString();
    return settings.useBengaliNumerals ? toBengaliDigits(str) : str;
  }

  /// Converts ASCII digits `0-9` into Bengali numerals `০-৯`.
  static String toBengaliDigits(String input) {
    const english = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    const bengali = ['০', '১', '২', '৩', '৪', '৫', '৬', '৭', '৮', '৯'];
    var output = input;
    for (var i = 0; i < 10; i++) {
      output = output.replaceAll(english[i], bengali[i]);
    }
    return output;
  }
}

final l10nProvider = Provider<AppLocalizations>((ref) {
  final settings = ref.watch(appLocaleProvider);
  return AppLocalizations(settings);
});
