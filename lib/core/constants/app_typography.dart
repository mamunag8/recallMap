import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Typography & Theme Engine supporting:
/// - Global / Latin UI: Plus Jakarta Sans (UI & cards), JetBrains Mono (code, formulas, FSRS metrics)
/// - Bangla (`bn` - বাংলা) First-Class Typography: Hind Siliguri & Noto Sans Bengali for razor-sharp
///   Bengali conjuncts (যুক্তবর্ণ) across flashcards, PDF annotations, and charts.
/// - RTL Scripts (`ar` Arabic, `ur` Urdu): Noto Sans Arabic with automatic RTL mirroring.
class AppTypography {
  AppTypography._();

  static const String latinFont = 'PlusJakartaSans';
  static const String monoFont = 'JetBrainsMono';
  static const String banglaPrimaryFont = 'HindSiliguri';
  static const String banglaSecondaryFont = 'NotoSansBengali';
  static const String arabicRtlFont = 'NotoSansArabic';

  /// Returns the optimal primary font family for the given ISO language code.
  static String primaryFontForLocale(String languageCode) {
    return switch (languageCode) {
      'bn' => banglaPrimaryFont,
      'ar' || 'ur' => arabicRtlFont,
      _ => latinFont,
    };
  }

  /// Fallback font list ensuring Bengali conjuncts (যুক্তবর্ণ), Arabic glyphs, and math symbols
  /// render cleanly even in mixed-language cards.
  static const List<String> universalFontFallbacks = [
    latinFont,
    banglaPrimaryFont,
    banglaSecondaryFont,
    arabicRtlFont,
    'Inter',
    'sans-serif',
  ];

  static TextStyle monoMetric({
    double fontSize = 13,
    FontWeight fontWeight = FontWeight.w600,
    Color? color,
  }) {
    return TextStyle(
      fontFamily: monoFont,
      fontFamilyFallback: universalFontFallbacks,
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: -0.2,
    );
  }

  static TextTheme buildTextTheme({
    required String languageCode,
    required Color primaryTextColor,
    required Color secondaryTextColor,
  }) {
    final fontFamily = primaryFontForLocale(languageCode);
    final heightMultiplier = languageCode == 'bn' ? 1.45 : 1.32;

    return TextTheme(
      displayLarge: TextStyle(
        fontFamily: fontFamily,
        fontFamilyFallback: universalFontFallbacks,
        fontSize: 32,
        fontWeight: FontWeight.w700,
        color: primaryTextColor,
        height: heightMultiplier,
        letterSpacing: -0.6,
      ),
      displayMedium: TextStyle(
        fontFamily: fontFamily,
        fontFamilyFallback: universalFontFallbacks,
        fontSize: 26,
        fontWeight: FontWeight.w700,
        color: primaryTextColor,
        height: heightMultiplier,
        letterSpacing: -0.4,
      ),
      headlineMedium: TextStyle(
        fontFamily: fontFamily,
        fontFamilyFallback: universalFontFallbacks,
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: primaryTextColor,
        height: heightMultiplier,
      ),
      titleLarge: TextStyle(
        fontFamily: fontFamily,
        fontFamilyFallback: universalFontFallbacks,
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: primaryTextColor,
        height: heightMultiplier,
      ),
      titleMedium: TextStyle(
        fontFamily: fontFamily,
        fontFamilyFallback: universalFontFallbacks,
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: primaryTextColor,
        height: heightMultiplier,
      ),
      bodyLarge: TextStyle(
        fontFamily: fontFamily,
        fontFamilyFallback: universalFontFallbacks,
        fontSize: 15,
        fontWeight: FontWeight.w400,
        color: primaryTextColor,
        height: heightMultiplier,
      ),
      bodyMedium: TextStyle(
        fontFamily: fontFamily,
        fontFamilyFallback: universalFontFallbacks,
        fontSize: 13.5,
        fontWeight: FontWeight.w400,
        color: secondaryTextColor,
        height: heightMultiplier,
      ),
      labelLarge: TextStyle(
        fontFamily: fontFamily,
        fontFamilyFallback: universalFontFallbacks,
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: primaryTextColor,
      ),
      labelSmall: TextStyle(
        fontFamily: fontFamily,
        fontFamilyFallback: universalFontFallbacks,
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: secondaryTextColor,
      ),
    );
  }

  /// Builds complete ThemeData for Obsidian Dark, Clean Light, or True OLED Black (#000000).
  static ThemeData buildTheme({
    required RecallThemeMode mode,
    required String languageCode,
  }) {
    final isLight = mode == RecallThemeMode.cleanLight;
    final isOled = mode == RecallThemeMode.oledBlack;

    final canvasColor = isLight
        ? AppColors.lightCanvas
        : (isOled ? AppColors.oledCanvas : AppColors.darkCanvas);
    final cardColor = isLight
        ? AppColors.lightPureSurface
        : (isOled ? AppColors.oledElevatedCard : AppColors.darkElevatedCard);
    final drawerColor = isLight
        ? AppColors.lightGlassDrawer
        : (isOled ? AppColors.oledGlassDrawer : AppColors.darkGlassDrawer);
    final borderColor = isLight
        ? AppColors.lightBorder
        : (isOled ? AppColors.oledBorder : AppColors.darkBorder);
    final primaryText =
        isLight ? AppColors.lightTextPrimary : AppColors.darkTextPrimary;
    final secondaryText =
        isLight ? AppColors.lightTextSecondary : AppColors.darkTextSecondary;

    final textTheme = buildTextTheme(
      languageCode: languageCode,
      primaryTextColor: primaryText,
      secondaryTextColor: secondaryText,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: isLight ? Brightness.light : Brightness.dark,
      scaffoldBackgroundColor: canvasColor,
      canvasColor: canvasColor,
      cardColor: cardColor,
      dividerColor: borderColor,
      fontFamily: primaryFontForLocale(languageCode),
      textTheme: textTheme,
      colorScheme: ColorScheme(
        brightness: isLight ? Brightness.light : Brightness.dark,
        primary: AppColors.sourceRoyalIndigo,
        onPrimary: Colors.white,
        secondary: AppColors.masteredEmerald,
        onSecondary: Colors.white,
        error: AppColors.urgentCrimson,
        onError: Colors.white,
        surface: cardColor,
        onSurface: primaryText,
        surfaceContainerHighest: drawerColor,
        outline: borderColor,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: canvasColor,
        foregroundColor: primaryText,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: cardColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: borderColor, width: 1),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: drawerColor,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
    );
  }
}
