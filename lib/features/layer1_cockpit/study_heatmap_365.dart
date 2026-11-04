import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';
import '../../core/database/tables.dart';
import '../../core/i18n/app_localizations.dart';
import '../../shared/widgets/adaptive_glass_card.dart';

/// Hero Visual 3 (Part A) — 365-Day GitHub-Style Study Heatmap.
/// Renders 52 weeks × 7 days of immutable `review_logs` activity with
/// interactive day inspection and live streak calculation.
class StudyHeatmap365 extends ConsumerStatefulWidget {
  final List<ReviewLogRecord> reviewLogs;

  const StudyHeatmap365({
    super.key,
    required this.reviewLogs,
  });

  /// Computes the active consecutive day streak from `review_logs`.
  static int computeCurrentStreak(List<ReviewLogRecord> logs, {int? nowMs}) {
    if (logs.isEmpty) return 0;
    final currentMs = nowMs ?? DateTime.now().millisecondsSinceEpoch;
    const dayMs = 86400 * 1000;
    final activeDayIndices = <int>{};
    for (final log in logs) {
      final daysAgo = ((currentMs - log.reviewedAt) / dayMs).floor();
      if (daysAgo >= 0 && daysAgo <= 365) {
        activeDayIndices.add(daysAgo);
      }
    }
    var streak = 0;
    var cursor = activeDayIndices.contains(0) ? 0 : 1;
    while (activeDayIndices.contains(cursor)) {
      streak++;
      cursor++;
    }
    return streak;
  }

  @override
  ConsumerState<StudyHeatmap365> createState() => _StudyHeatmap365State();
}

class _StudyHeatmap365State extends ConsumerState<StudyHeatmap365> {
  int _selectedDaysAgo = 0;

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(l10nProvider);
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    const dayMs = 86400 * 1000;

    final countsByDaysAgo = <int, int>{};
    for (final log in widget.reviewLogs) {
      final daysAgo = ((nowMs - log.reviewedAt) / dayMs).floor();
      if (daysAgo >= 0 && daysAgo < 365) {
        countsByDaysAgo[daysAgo] = (countsByDaysAgo[daysAgo] ?? 0) + 1;
      }
    }

    final selectedCount = countsByDaysAgo[_selectedDaysAgo] ?? 0;
    final selectedDate =
        DateTime.now().subtract(Duration(days: _selectedDaysAgo));
    final dateStr =
        '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}';

    return AdaptiveGlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n.t('study_heatmap'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Text(
                '$dateStr: ${l10n.formatNumber(selectedCount)} reviews',
                style: AppTypography.monoMetric(
                  fontSize: 11.5,
                  color: AppColors.masteredEmerald,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            reverse: true,
            child: SizedBox(
              width: 53 * 13.0,
              height: 7 * 13.0,
              child: GestureDetector(
                onTapDown: (details) {
                  final col = (details.localPosition.dx ~/ 13.0).clamp(0, 52);
                  final row = (details.localPosition.dy ~/ 13.0).clamp(0, 6);
                  final weekFromRight = 52 - col;
                  final daysAgo = (weekFromRight * 7 + (6 - row)).clamp(0, 364);
                  setState(() => _selectedDaysAgo = daysAgo);
                },
                child: CustomPaint(
                  painter: _Heatmap365GridPainter(
                    countsByDaysAgo: countsByDaysAgo,
                    selectedDaysAgo: _selectedDaysAgo,
                    isLightMode:
                        Theme.of(context).brightness == Brightness.light,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Heatmap365GridPainter extends CustomPainter {
  final Map<int, int> countsByDaysAgo;
  final int selectedDaysAgo;
  final bool isLightMode;

  const _Heatmap365GridPainter({
    required this.countsByDaysAgo,
    required this.selectedDaysAgo,
    required this.isLightMode,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const cellSize = 10.0;
    const step = 13.0;
    final emptyColor = isLightMode
        ? const Color(0xFFE2E8F0)
        : const Color(0xFF1E293B);

    for (var col = 0; col <= 52; col++) {
      final weekFromRight = 52 - col;
      for (var row = 0; row < 7; row++) {
        final daysAgo = weekFromRight * 7 + (6 - row);
        if (daysAgo >= 365) continue;

        final count = countsByDaysAgo[daysAgo] ?? 0;
        Color cellColor;
        if (count == 0) {
          cellColor = emptyColor;
        } else {
          final intensity = (math.min(count, 16) / 16.0).clamp(0.25, 1.0);
          cellColor = AppColors.masteredEmerald.withValues(alpha: intensity);
        }

        final rect = RRect.fromRectAndRadius(
          Rect.fromLTWH(col * step, row * step, cellSize, cellSize),
          const Radius.circular(2.5),
        );
        canvas.drawRRect(rect, Paint()..color = cellColor);

        if (daysAgo == selectedDaysAgo) {
          canvas.drawRRect(
            rect,
            Paint()
              ..color = AppColors.unseenElectricSky
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.5,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _Heatmap365GridPainter oldDelegate) {
    return oldDelegate.selectedDaysAgo != selectedDaysAgo ||
        oldDelegate.countsByDaysAgo.length != countsByDaysAgo.length;
  }
}
