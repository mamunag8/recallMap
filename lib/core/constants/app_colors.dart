import 'package:flutter/material.dart';

/// Semantic Memory Health Color System & Theme Tokens for RecallMap.
/// Supports Obsidian Dark (#0B0F19), Clean Light (#F8FAFC), and True OLED Black (#000000).
enum RecallThemeMode {
  obsidianDark,
  cleanLight,
  oledBlack,
}

enum MemoryHealthTier {
  unseenNew,
  urgentDecaying,
  stabilizingShortTerm,
  masteredLongTerm,
}

class AppColors {
  AppColors._();

  // --- Dark Theme Canvas (Obsidian Navy) ---
  static const Color darkCanvas = Color(0xFF0B0F19);
  static const Color darkElevatedCard = Color(0xFF111827);
  static const Color darkGlassDrawer = Color(0xFF1E293B);
  static const Color darkBorder = Color(0xFF334155);
  static const Color darkTextPrimary = Color(0xFFF8FAFC);
  static const Color darkTextSecondary = Color(0xFF94A3B8);

  // --- True OLED Black Canvas ---
  static const Color oledCanvas = Color(0xFF000000);
  static const Color oledElevatedCard = Color(0xFF090D16);
  static const Color oledGlassDrawer = Color(0xFF111827);
  static const Color oledBorder = Color(0xFF1E293B);

  // --- Light Theme Canvas (Alabaster) ---
  static const Color lightCanvas = Color(0xFFF8FAFC);
  static const Color lightPureSurface = Color(0xFFFFFFFF);
  static const Color lightGlassDrawer = Color(0xFFF1F5F9);
  static const Color lightBorder = Color(0xFFE2E8F0);
  static const Color lightTextPrimary = Color(0xFF0F172A);
  static const Color lightTextSecondary = Color(0xFF475569);

  // --- Semantic Memory Health Palette ---
  /// Mastered Memory (Retrievability R >= 90%, Stability S >= 30d): Emerald Green
  static const Color masteredEmerald = Color(0xFF10B981);

  /// Stabilizing / Short-Term Learning (Stability S < 7d or 80% <= R < 90%): Amber Gold
  static const Color stabilizingAmber = Color(0xFFF59E0B);

  /// Urgent / Decaying / Leech (Retrievability R < 80% or Lapses >= 3): Crimson Red
  static const Color urgentCrimson = Color(0xFFEF4444);

  /// Unseen / New Cards (state == 0): Electric Sky
  static const Color unseenElectricSky = Color(0xFF38BDF8);

  /// PDF Textbooks & Concept Notes: Royal Indigo
  static const Color sourceRoyalIndigo = Color(0xFF6366F1);

  /// Unstudied / Neutral PDF Page Strip: Slate Gray
  static const Color unstudiedSlate = Color(0xFF64748B);

  /// Determines the exact semantic memory tier from live FSRS-6 state.
  static MemoryHealthTier classifyMemoryHealth({
    required int state,
    required double retrievability,
    required double stability,
    required int lapses,
  }) {
    if (state == 0) {
      return MemoryHealthTier.unseenNew;
    }
    if (retrievability < 0.80 || lapses >= 3) {
      return MemoryHealthTier.urgentDecaying;
    }
    if (stability >= 30.0 && retrievability >= 0.90) {
      return MemoryHealthTier.masteredLongTerm;
    }
    return MemoryHealthTier.stabilizingShortTerm;
  }

  /// Resolves the exact semantic color for any card, bubble, graph node, or PDF page bar.
  static Color colorForMemoryHealth({
    required int state,
    required double retrievability,
    required double stability,
    required int lapses,
  }) {
    final tier = classifyMemoryHealth(
      state: state,
      retrievability: retrievability,
      stability: stability,
      lapses: lapses,
    );
    return switch (tier) {
      MemoryHealthTier.unseenNew => unseenElectricSky,
      MemoryHealthTier.urgentDecaying => urgentCrimson,
      MemoryHealthTier.stabilizingShortTerm => stabilizingAmber,
      MemoryHealthTier.masteredLongTerm => masteredEmerald,
    };
  }

  /// Maps raw average retrievability [0.0 .. 1.0] and average stability to a continuous or semantic color.
  static Color colorForAggregateRetention({
    required double avgRetrievability,
    required double avgStability,
    required int totalCards,
    required int unseenCards,
  }) {
    if (totalCards == 0 || unseenCards == totalCards) {
      return unseenElectricSky;
    }
    if (avgRetrievability < 0.80) {
      return urgentCrimson;
    }
    if (avgStability >= 30.0 && avgRetrievability >= 0.90) {
      return masteredEmerald;
    }
    if (avgStability < 7.0 || avgRetrievability < 0.90) {
      return stabilizingAmber;
    }
    return masteredEmerald;
  }

  /// Parses a hex string like '#6366F1' into a Flutter [Color].
  static Color fromHex(String hexString, {Color fallback = sourceRoyalIndigo}) {
    final cleaned = hexString.trim().replaceAll('#', '');
    if (cleaned.length == 6) {
      final parsed = int.tryParse('FF$cleaned', radix: 16);
      if (parsed != null) return Color(parsed);
    } else if (cleaned.length == 8) {
      final parsed = int.tryParse(cleaned, radix: 16);
      if (parsed != null) return Color(parsed);
    }
    return fallback;
  }
}
