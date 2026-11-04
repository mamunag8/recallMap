import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/i18n/app_localizations.dart';

/// Glassmorphic / elevated card container that adapts across Obsidian Dark (#0B0F19),
/// Clean Light (#F8FAFC), and True OLED Black (#000000).
class AdaptiveGlassCard extends ConsumerWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final Color? accentBorderColor;
  final double borderRadius;
  final VoidCallback? onTap;
  final VoidCallback? onDoubleTap;

  const AdaptiveGlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.accentBorderColor,
    this.borderRadius = 18,
    this.onTap,
    this.onDoubleTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appLocaleProvider);
    final isLight = settings.themeMode == RecallThemeMode.cleanLight;
    final isOled = settings.themeMode == RecallThemeMode.oledBlack;

    final surfaceColor = isLight
        ? AppColors.lightPureSurface
        : (isOled ? AppColors.oledElevatedCard : AppColors.darkElevatedCard);
    final defaultBorder = isLight
        ? AppColors.lightBorder
        : (isOled ? AppColors.oledBorder : AppColors.darkBorder);
    final borderColor = accentBorderColor ?? defaultBorder;

    Widget content = Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: borderColor,
          width: accentBorderColor != null ? 1.5 : 1.0,
        ),
        boxShadow: isLight
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : [
                if (accentBorderColor != null)
                  BoxShadow(
                    color: accentBorderColor!.withValues(alpha: 0.14),
                    blurRadius: 16,
                    spreadRadius: 1,
                  ),
              ],
      ),
      child: child,
    );

    if (onTap != null || onDoubleTap != null) {
      content = GestureDetector(
        onTap: onTap,
        onDoubleTap: onDoubleTap,
        behavior: HitTestBehavior.opaque,
        child: content,
      );
    }

    return content;
  }
}
