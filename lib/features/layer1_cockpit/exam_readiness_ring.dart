import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';
import '../../core/i18n/app_localizations.dart';
import '../../shared/widgets/adaptive_glass_card.dart';

/// Hero Visual 1 — The Exam Readiness Ring (Top Center of Layer 1 Cockpit).
/// Hardware-accelerated 60fps [CustomPainter] circular gauge displaying live
/// Overall Memory Readiness % (weighted average of R(t, S) across all active cards),
/// flanked by `Due Today`, `New Cards`, and `Study Streak 🔥`.
class ExamReadinessRing extends ConsumerWidget {
  final double readinessPercent; // 0.0 .. 100.0
  final int daysLeftToExam;
  final int dueNowCount;
  final int newTodayCount;
  final int studyStreakDays;
  final int masteredCount;
  final int stabilizingCount;
  final int urgentCount;
  final VoidCallback? onRingTap;

  const ExamReadinessRing({
    super.key,
    required this.readinessPercent,
    required this.daysLeftToExam,
    required this.dueNowCount,
    required this.newTodayCount,
    required this.studyStreakDays,
    required this.masteredCount,
    required this.stabilizingCount,
    required this.urgentCount,
    this.onRingTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    final ringColor = readinessPercent >= 88.0
        ? AppColors.masteredEmerald
        : (readinessPercent >= 78.0
            ? AppColors.stabilizingAmber
            : AppColors.urgentCrimson);

    return AdaptiveGlassCard(
      onTap: onRingTap,
      accentBorderColor: ringColor.withValues(alpha: 0.4),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      child: Column(
        children: [
          Row(
            children: [
              // Left Flank: Due Now & New Today
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _MetricStatBadge(
                      label: l10n.t('due_today'),
                      value: l10n.formatNumber(dueNowCount),
                      accentColor: dueNowCount > 0
                          ? AppColors.urgentCrimson
                          : AppColors.masteredEmerald,
                      icon: Icons.bolt_rounded,
                    ),
                    const SizedBox(height: 12),
                    _MetricStatBadge(
                      label: l10n.t('new_cards'),
                      value: l10n.formatNumber(newTodayCount),
                      accentColor: AppColors.unseenElectricSky,
                      icon: Icons.auto_awesome_rounded,
                    ),
                  ],
                ),
              ),

              // Center Hero: Animated Circular Readiness Gauge
              SizedBox(
                width: 148,
                height: 148,
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(
                    begin: 0.0,
                    end: (readinessPercent / 100.0).clamp(0.0, 1.0),
                  ),
                  duration: const Duration(milliseconds: 900),
                  curve: Curves.easeOutCubic,
                  builder: (context, progress, _) {
                    return CustomPaint(
                      painter: _ExamReadinessRingPainter(
                        progress: progress,
                        primaryColor: ringColor,
                        masteredCount: masteredCount,
                        stabilizingCount: stabilizingCount,
                        urgentCount: urgentCount,
                      ),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${l10n.formatNumber((progress * 100).round())}%',
                              style: AppTypography.monoMetric(
                                fontSize: 28,
                                fontWeight: FontWeight.w700,
                                color: ringColor,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              l10n.t('exam_ready_suffix'),
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.sourceRoyalIndigo
                                    .withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                '${l10n.formatNumber(daysLeftToExam)} ${l10n.t('days_left')}',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.sourceRoyalIndigo,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Right Flank: Study Streak & Tier Breakdown
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _MetricStatBadge(
                      label: l10n.t('study_streak'),
                      value: '${l10n.formatNumber(studyStreakDays)}d',
                      accentColor: AppColors.stabilizingAmber,
                      icon: Icons.local_fire_department_rounded,
                      alignEnd: true,
                    ),
                    const SizedBox(height: 12),
                    _MetricStatBadge(
                      label: 'R(t, S) ≥ 90%',
                      value:
                          '${l10n.formatNumber(masteredCount)} / ${l10n.formatNumber(masteredCount + stabilizingCount + urgentCount)}',
                      accentColor: AppColors.masteredEmerald,
                      icon: Icons.verified_rounded,
                      alignEnd: true,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricStatBadge extends StatelessWidget {
  final String label;
  final String value;
  final Color accentColor;
  final IconData icon;
  final bool alignEnd;

  const _MetricStatBadge({
    required this.label,
    required this.value,
    required this.accentColor,
    required this.icon,
    this.alignEnd = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!alignEnd) ...[
              Icon(icon, size: 14, color: accentColor),
              const SizedBox(width: 4),
            ],
            Flexible(
              child: Text(
                label,
                style: Theme.of(context).textTheme.labelSmall,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (alignEnd) ...[
              const SizedBox(width: 4),
              Icon(icon, size: 14, color: accentColor),
            ],
          ],
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: AppTypography.monoMetric(
            fontSize: 19,
            fontWeight: FontWeight.w700,
            color: accentColor,
          ),
        ),
      ],
    );
  }
}

class _ExamReadinessRingPainter extends CustomPainter {
  final double progress;
  final Color primaryColor;
  final int masteredCount;
  final int stabilizingCount;
  final int urgentCount;

  const _ExamReadinessRingPainter({
    required this.progress,
    required this.primaryColor,
    required this.masteredCount,
    required this.stabilizingCount,
    required this.urgentCount,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outerRadius = (math.min(size.width, size.height) / 2) - 8;
    const strokeWidth = 11.0;

    // 1. Background Track
    final trackPaint = Paint()
      ..color = primaryColor.withValues(alpha: 0.14)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, outerRadius, trackPaint);

    // 2. Primary Readiness Arc
    final sweepAngle = 2 * math.pi * progress;
    final arcRect = Rect.fromCircle(center: center, radius: outerRadius);
    final fgPaint = Paint()
      ..shader = SweepGradient(
        startAngle: -math.pi / 2,
        endAngle: 3 * math.pi / 2,
        colors: [
          primaryColor.withValues(alpha: 0.75),
          primaryColor,
          AppColors.unseenElectricSky,
          primaryColor,
        ],
      ).createShader(arcRect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      arcRect,
      -math.pi / 2,
      sweepAngle,
      false,
      fgPaint,
    );

    // 3. Inner Segmented Memory Health Halo (Emerald / Amber / Crimson ratio)
    final total = math.max(1, masteredCount + stabilizingCount + urgentCount);
    final innerRadius = outerRadius - 14;
    final innerRect = Rect.fromCircle(center: center, radius: innerRadius);
    double startRad = -math.pi / 2;

    void drawTierSegment(int count, Color color) {
      if (count <= 0) return;
      final segSweep = (count / total) * 2 * math.pi;
      final paint = Paint()
        ..color = color.withValues(alpha: 0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.butt;
      canvas.drawArc(innerRect, startRad, segSweep - 0.04, false, paint);
      startRad += segSweep;
    }

    drawTierSegment(masteredCount, AppColors.masteredEmerald);
    drawTierSegment(stabilizingCount, AppColors.stabilizingAmber);
    drawTierSegment(urgentCount, AppColors.urgentCrimson);
  }

  @override
  bool shouldRepaint(covariant _ExamReadinessRingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.primaryColor != primaryColor ||
        oldDelegate.masteredCount != masteredCount;
  }
}
