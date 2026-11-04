import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';

/// High-speed 60fps Offline LaTeX (`$$...$$`), Cloze (`{{c1::answer::hint}}`),
/// and Bangla/Multilingual scientific formula renderer.
class MathLatexView extends StatelessWidget {
  final String markdownWithLatex;
  final bool revealCloze;
  final double fontSize;
  final Color? textColor;

  const MathLatexView({
    super.key,
    required this.markdownWithLatex,
    this.revealCloze = true,
    this.fontSize = 15.0,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final defaultColor =
        textColor ?? Theme.of(context).textTheme.bodyLarge?.color ?? Colors.white;
    final spans = _parseRichSpans(
      raw: markdownWithLatex,
      revealCloze: revealCloze,
      baseColor: defaultColor,
      fontSize: fontSize,
    );

    return RichText(
      text: TextSpan(
        style: TextStyle(
          fontSize: fontSize,
          color: defaultColor,
          height: 1.45,
          fontFamilyFallback: AppTypography.universalFontFallbacks,
        ),
        children: spans,
      ),
    );
  }

  static List<InlineSpan> _parseRichSpans({
    required String raw,
    required bool revealCloze,
    required Color baseColor,
    required double fontSize,
  }) {
    // Tokenize Cloze `{{c1::answer::hint}}` and LaTeX `$$...$$`
    final pattern = RegExp(
      r'(\{\{c\d+::[^}]+\}\}|\$\$[^$]+\$\$)',
      multiLine: true,
    );

    final spans = <InlineSpan>[];
    int cursor = 0;

    for (final match in pattern.allMatches(raw)) {
      if (match.start > cursor) {
        spans.add(TextSpan(text: raw.substring(cursor, match.start)));
      }
      final token = match.group(0)!;
      if (token.startsWith('{{')) {
        // Parse Cloze deletion {{c1::answer::hint}}
        final inner = token.substring(2, token.length - 2);
        final parts = inner.split('::');
        final answer = parts.length > 1 ? parts[1] : inner;
        final hint = parts.length > 2 ? parts[2] : '...';

        final display = revealCloze ? answer : '[$hint]';
        final pillColor = revealCloze
            ? AppColors.masteredEmerald
            : AppColors.unseenElectricSky;

        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: pillColor.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: pillColor.withValues(alpha: 0.6)),
              ),
              child: Text(
                _prettifyLatexSymbols(display),
                style: TextStyle(
                  fontSize: fontSize - 0.5,
                  fontWeight: FontWeight.w700,
                  color: pillColor,
                  fontFamilyFallback: AppTypography.universalFontFallbacks,
                ),
              ),
            ),
          ),
        );
      } else if (token.startsWith(r'$$')) {
        final rawMath = token.substring(2, token.length - 2).trim();
        final prettyMath = _prettifyLatexSymbols(rawMath);
        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.sourceRoyalIndigo.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: AppColors.sourceRoyalIndigo.withValues(alpha: 0.45),
                ),
              ),
              child: Text(
                prettyMath,
                style: AppTypography.monoMetric(
                  fontSize: fontSize - 0.5,
                  color: AppColors.unseenElectricSky,
                ),
              ),
            ),
          ),
        );
      }
      cursor = match.end;
    }

    if (cursor < raw.length) {
      spans.add(
        TextSpan(text: _prettifyLatexSymbols(raw.substring(cursor))),
      );
    }

    return spans;
  }

  /// Converts common LaTeX control sequences into crisp Unicode mathematical notation
  /// for instant 60fps offline rendering.
  static String _prettifyLatexSymbols(String input) {
    var out = input;
    out = out.replaceAllMapped(
      RegExp(r'\\frac\{([^}]+)\}\{([^}]+)\}'),
      (m) => '(${m.group(1)} / ${m.group(2)})',
    );
    out = out.replaceAllMapped(
      RegExp(r'\\text\{([^}]+)\}'),
      (m) => m.group(1) ?? '',
    );
    return out
        .replaceAll(r'\Delta', 'Δ')
        .replaceAll(r'\rho', 'ρ')
        .replaceAll(r'\mu', 'μ')
        .replaceAll(r'\cdot', '·')
        .replaceAll(r'\times', '×')
        .replaceAll(r'\geq', '≥')
        .replaceAll(r'\leq', '≤')
        .replaceAll('_1', '₁')
        .replaceAll('_2', '₂')
        .replaceAll('_f', '𝒻')
        .replaceAll('_k', 'ₖ')
        .replaceAll('^2', '²')
        .replaceAll('^{2+}', '²⁺');
  }
}
