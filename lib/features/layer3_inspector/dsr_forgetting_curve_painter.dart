import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';
import '../../core/constants/fsrs_constants.dart';
import '../fsrs_engine/fsrs_v6_scheduler.dart';

/// LAYER 3 (Visual 1): Individual DSR Forgetting Curve Graph.
/// Plots the exact mathematical decay curve `R(t) = (1 + factor * (t / S))^(-w[20])`
/// over time, marking today's point on the curve, the `90%` target threshold line,
/// and the scheduled next review day.
class DsrForgettingCurvePainter extends CustomPainter {
  final double stabilityDays;
  final double elapsedDays;
  final double targetRetention;
  final bool isLightMode;

  const DsrForgettingCurvePainter({
    required this.stabilityDays,
    required this.elapsedDays,
    this.targetRetention = FsrsConstants.defaultTargetRetention,
    this.isLightMode = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const scheduler = FsrsV6Scheduler();
    final s = math.max(0.5, stabilityDays);
    final horizonDays = math.max(14.0, math.max(s * 1.6, elapsedDays * 1.3));

    const padLeft = 36.0;
    const padRight = 16.0;
    const padTop = 14.0;
    const padBottom = 24.0;
    final plotWidth = size.width - padLeft - padRight;
    final plotHeight = size.height - padTop - padBottom;

    double xForDay(double t) =>
        padLeft + (t / horizonDays).clamp(0.0, 1.0) * plotWidth;
    // Map R in [0.50 .. 1.00] to plotHeight for high visual resolution
    double yForR(double r) =>
        padTop + (1.0 - ((r - 0.50) / 0.50).clamp(0.0, 1.0)) * plotHeight;

    final axisColor = (isLightMode ? Colors.black : Colors.white)
        .withValues(alpha: 0.18);
    final axisPaint = Paint()
      ..color = axisColor
      ..strokeWidth = 1.0;

    // 1. Draw Horizontal Target Retention Threshold Line (90%)
    final targetY = yForR(targetRetention);
    canvas.drawLine(
      Offset(padLeft, targetY),
      Offset(size.width - padRight, targetY),
      Paint()
        ..color = AppColors.stabilizingAmber.withValues(alpha: 0.65)
        ..strokeWidth = 1.2,
    );

    // 2. Draw Axes
    canvas.drawLine(
      Offset(padLeft, padTop),
      Offset(padLeft, size.height - padBottom),
      axisPaint,
    );
    canvas.drawLine(
      Offset(padLeft, size.height - padBottom),
      Offset(size.width - padRight, size.height - padBottom),
      axisPaint,
    );

    // 3. Plot Exact Power-Law Forgetting Curve R(t, S) = (1 + factor * (t / S))^(-w[20])
    final curvePath = Path();
    final fillPath = Path();
    const samples = 80;
    for (var i = 0; i <= samples; i++) {
      final t = (i / samples) * horizonDays;
      final r = scheduler.computeRetrievability(
        elapsedDays: t,
        stability: s,
      );
      final px = xForDay(t);
      final py = yForR(r);
      if (i == 0) {
        curvePath.moveTo(px, py);
        fillPath.moveTo(px, size.height - padBottom);
        fillPath.lineTo(px, py);
      } else {
        curvePath.lineTo(px, py);
        fillPath.lineTo(px, py);
      }
    }
    fillPath.lineTo(size.width - padRight, size.height - padBottom);
    fillPath.close();

    final liveR = scheduler.computeRetrievability(
      elapsedDays: elapsedDays,
      stability: s,
    );
    final curveColor = liveR >= 0.90
        ? AppColors.masteredEmerald
        : (liveR >= 0.80 ? AppColors.stabilizingAmber : AppColors.urgentCrimson);

    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            curveColor.withValues(alpha: 0.28),
            curveColor.withValues(alpha: 0.02),
          ],
        ).createShader(Rect.fromLTWH(padLeft, padTop, plotWidth, plotHeight)),
    );

    canvas.drawPath(
      curvePath,
      Paint()
        ..color = curveColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.6,
    );

    // 4. Mark Today's Live Point (t = elapsedDays, R = liveR)
    final todayX = xForDay(elapsedDays);
    final todayY = yForR(liveR);
    canvas.drawCircle(
      Offset(todayX, todayY),
      6.0,
      Paint()..color = curveColor,
    );
    canvas.drawCircle(
      Offset(todayX, todayY),
      3.0,
      Paint()..color = Colors.white,
    );

    // 5. Axis Labels
    _drawLabel(canvas, '100%', Offset(4, padTop - 4));
    _drawLabel(
      canvas,
      '${(targetRetention * 100).round()}%',
      Offset(4, targetY - 6),
      color: AppColors.stabilizingAmber,
    );
    _drawLabel(canvas, '50%', Offset(8, size.height - padBottom - 8));
    _drawLabel(canvas, 't=0d', Offset(padLeft, size.height - 18));
    _drawLabel(
      canvas,
      'S=${s.toStringAsFixed(1)}d',
      Offset(xForDay(s) - 18, size.height - 18),
      color: AppColors.unseenElectricSky,
    );
    _drawLabel(
      canvas,
      '${horizonDays.round()}d',
      Offset(size.width - padRight - 24, size.height - 18),
    );
  }

  void _drawLabel(
    Canvas canvas,
    String text,
    Offset offset, {
    Color? color,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: AppTypography.monoMetric(
          fontSize: 9.5,
          color: color ?? AppColors.darkTextSecondary,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant DsrForgettingCurvePainter oldDelegate) {
    return oldDelegate.stabilityDays != stabilityDays ||
        oldDelegate.elapsedDays != elapsedDays;
  }
}
