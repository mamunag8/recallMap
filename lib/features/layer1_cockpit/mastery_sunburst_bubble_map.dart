import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';
import '../../core/i18n/app_localizations.dart';
import '../../shared/widgets/adaptive_glass_card.dart';

/// Aggregated visual node for a Deck or Sub-Deck in the Mastery Bubble Map / Sunburst Ring.
class DeckMasteryVisualNode {
  final String deckId;
  final String? parentId;
  final String title;
  final int totalCards;
  final int dueCards;
  final int unseenCards;
  final double avgRetrievability; // 0.0 .. 1.0
  final double avgStabilityDays;
  final int leechCount;
  final Color healthColor;

  const DeckMasteryVisualNode({
    required this.deckId,
    this.parentId,
    required this.title,
    required this.totalCards,
    required this.dueCards,
    required this.unseenCards,
    required this.avgRetrievability,
    required this.avgStabilityDays,
    required this.leechCount,
    required this.healthColor,
  });
}

enum MasteryVisualizationMode {
  bubbleMap,
  sunburstRing,
}

/// Hero Visual 2 — Interactive Mastery Sunburst / Bubble Map.
/// - Toggle between a Force-Clustered Bubble Map and a Concentric Sunburst Ring.
/// - Size = Total Cards, Color = Live Memory Health (Crimson R < 80%, Amber S < 7d, Emerald S >= 30d, Sky Blue New).
/// - Single-tapping any node reveals its instant stats pill; double-tapping zooms straight into Layer 2 X-Ray.
class MasterySunburstBubbleMap extends ConsumerStatefulWidget {
  final List<DeckMasteryVisualNode> nodes;
  final ValueChanged<DeckMasteryVisualNode>? onNodeSingleTap;
  final ValueChanged<DeckMasteryVisualNode>? onNodeDoubleTap;

  const MasterySunburstBubbleMap({
    super.key,
    required this.nodes,
    this.onNodeSingleTap,
    this.onNodeDoubleTap,
  });

  @override
  ConsumerState<MasterySunburstBubbleMap> createState() =>
      _MasterySunburstBubbleMapState();
}

class _MasterySunburstBubbleMapState
    extends ConsumerState<MasterySunburstBubbleMap> {
  MasteryVisualizationMode _mode = MasteryVisualizationMode.bubbleMap;
  DeckMasteryVisualNode? _selectedNode;
  final List<_PlacedNodeHitRegion> _hitRegions = [];

  @override
  void initState() {
    super.initState();
    if (widget.nodes.isNotEmpty) {
      _selectedNode = widget.nodes.first;
    }
  }

  @override
  void didUpdateWidget(covariant MasterySunburstBubbleMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_selectedNode == null && widget.nodes.isNotEmpty) {
      _selectedNode = widget.nodes.first;
    }
  }

  void _handleCanvasTap(Offset localPosition, {required bool isDoubleTap}) {
    for (final region in _hitRegions) {
      if ((localPosition - region.center).distance <= region.radius) {
        setState(() {
          _selectedNode = region.node;
        });
        if (isDoubleTap) {
          widget.onNodeDoubleTap?.call(region.node);
        } else {
          widget.onNodeSingleTap?.call(region.node);
        }
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(l10nProvider);
    final selected =
        _selectedNode ?? (widget.nodes.isNotEmpty ? widget.nodes.first : null);

    return AdaptiveGlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row with Bubble Map / Sunburst Ring Toggle
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  l10n.t('visual_map_title'),
                  style: Theme.of(context).textTheme.titleMedium,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              SegmentedButton<MasteryVisualizationMode>(
                segments: [
                  ButtonSegment(
                    value: MasteryVisualizationMode.bubbleMap,
                    icon: const Icon(Icons.bubble_chart_rounded, size: 16),
                    label: Text(
                      l10n.t('mode_bubble_map'),
                      style: const TextStyle(fontSize: 11.5),
                    ),
                  ),
                  ButtonSegment(
                    value: MasteryVisualizationMode.sunburstRing,
                    icon: const Icon(Icons.donut_large_rounded, size: 16),
                    label: Text(
                      l10n.t('mode_sunburst_ring'),
                      style: const TextStyle(fontSize: 11.5),
                    ),
                  ),
                ],
                selected: {_mode},
                onSelectionChanged: (s) {
                  setState(() => _mode = s.first);
                },
                style: const ButtonStyle(
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Semantic Legend Strip
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              _LegendDot(
                color: AppColors.masteredEmerald,
                label: l10n.t('tier_mastered'),
              ),
              _LegendDot(
                color: AppColors.stabilizingAmber,
                label: l10n.t('tier_stabilizing'),
              ),
              _LegendDot(
                color: AppColors.urgentCrimson,
                label: l10n.t('tier_urgent'),
              ),
              _LegendDot(
                color: AppColors.unseenElectricSky,
                label: l10n.t('tier_unseen'),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Interactive 60fps Canvas
          SizedBox(
            height: 225,
            width: double.infinity,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final canvasSize =
                    Size(constraints.maxWidth, constraints.maxHeight);
                _computeHitRegions(canvasSize);

                return GestureDetector(
                  onTapUp: (details) => _handleCanvasTap(
                    details.localPosition,
                    isDoubleTap: false,
                  ),
                  onDoubleTapDown: (details) => _handleCanvasTap(
                    details.localPosition,
                    isDoubleTap: true,
                  ),
                  child: CustomPaint(
                    size: canvasSize,
                    painter: _MasteryMapPainter(
                      mode: _mode,
                      placedRegions: List.unmodifiable(_hitRegions),
                      selectedDeckId: selected?.deckId,
                      isLightMode:
                          Theme.of(context).brightness == Brightness.light,
                    ),
                  ),
                );
              },
            ),
          ),

          // Instant Stats Pill for the Tapped Node
          if (selected != null) ...[
            const SizedBox(height: 8),
            InkWell(
              onTap: () => widget.onNodeDoubleTap?.call(selected),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: selected.healthColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: selected.healthColor.withValues(alpha: 0.45),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: selected.healthColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            selected.title,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            l10n.t('double_tap_hint'),
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        ],
                      ),
                    ),
                    Text(
                      'R: ${l10n.formatNumber((selected.avgRetrievability * 100).round())}% • S: ${l10n.formatNumber(selected.avgStabilityDays.toStringAsFixed(1))}d',
                      style: AppTypography.monoMetric(
                        fontSize: 12,
                        color: selected.healthColor,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      Icons.zoom_in_map_rounded,
                      size: 16,
                      color: selected.healthColor,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _computeHitRegions(Size size) {
    _hitRegions.clear();
    final nodes = widget.nodes;
    if (nodes.isEmpty) return;

    final center = Offset(size.width / 2, size.height / 2);

    if (_mode == MasteryVisualizationMode.bubbleMap) {
      // Force-clustered radial layout around root/primary bubble
      final count = nodes.length;
      for (var i = 0; i < count; i++) {
        final node = nodes[i];
        final baseRadius = (26.0 + math.sqrt(node.totalCards + 1) * 9.0)
            .clamp(28.0, 46.0);
        Offset pos;
        if (i == 0) {
          pos = center;
        } else {
          final angle =
              (2 * math.pi * (i - 1) / math.max(1, count - 1)) - math.pi / 6;
          final orbitX = math.min(size.width * 0.31, 120.0);
          final orbitY = math.min(size.height * 0.31, 66.0);
          pos = Offset(
            center.dx + orbitX * math.cos(angle),
            center.dy + orbitY * math.sin(angle),
          );
        }
        _hitRegions.add(
          _PlacedNodeHitRegion(
            node: node,
            center: pos,
            radius: baseRadius,
            startAngle: 0,
            sweepAngle: 0,
          ),
        );
      }
    } else {
      // Concentric Sunburst Ring layout: compute sector centroids for hit testing
      final totalCardsSum =
          math.max(1, nodes.fold<int>(0, (acc, n) => acc + n.totalCards + 1));
      double currentAngle = -math.pi / 2;
      final ringRadius = math.min(size.width, size.height) * 0.34;

      for (final node in nodes) {
        final weight = (node.totalCards + 1) / totalCardsSum;
        final sweep = weight * 2 * math.pi;
        final midAngle = currentAngle + sweep / 2;
        final sectorCenter = Offset(
          center.dx + ringRadius * math.cos(midAngle),
          center.dy + ringRadius * math.sin(midAngle),
        );
        _hitRegions.add(
          _PlacedNodeHitRegion(
            node: node,
            center: sectorCenter,
            radius: 34.0,
            startAngle: currentAngle,
            sweepAngle: sweep,
          ),
        );
        currentAngle += sweep;
      }
    }
  }
}

class _PlacedNodeHitRegion {
  final DeckMasteryVisualNode node;
  final Offset center;
  final double radius;
  final double startAngle;
  final double sweepAngle;

  const _PlacedNodeHitRegion({
    required this.node,
    required this.center,
    required this.radius,
    required this.startAngle,
    required this.sweepAngle,
  });
}

class _MasteryMapPainter extends CustomPainter {
  final MasteryVisualizationMode mode;
  final List<_PlacedNodeHitRegion> placedRegions;
  final String? selectedDeckId;
  final bool isLightMode;

  const _MasteryMapPainter({
    required this.mode,
    required this.placedRegions,
    required this.selectedDeckId,
    required this.isLightMode,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (placedRegions.isEmpty) return;
    final canvasCenter = Offset(size.width / 2, size.height / 2);

    if (mode == MasteryVisualizationMode.bubbleMap) {
      // Draw subtle hierarchy tether lines from center node to satellite sub-decks
      final rootCenter = placedRegions.first.center;
      final linePaint = Paint()
        ..color = (isLightMode ? Colors.black : Colors.white)
            .withValues(alpha: 0.12)
        ..strokeWidth = 1.5;

      for (var i = 1; i < placedRegions.length; i++) {
        canvas.drawLine(rootCenter, placedRegions[i].center, linePaint);
      }

      // Draw each Force-Clustered Bubble
      for (final reg in placedRegions) {
        final isSelected = reg.node.deckId == selectedDeckId;
        final color = reg.node.healthColor;

        if (isSelected) {
          final haloPaint = Paint()
            ..color = color.withValues(alpha: 0.25)
            ..style = PaintingStyle.fill;
          canvas.drawCircle(reg.center, reg.radius + 7, haloPaint);
        }

        final fillPaint = Paint()
          ..shader = RadialGradient(
            colors: [
              color.withValues(alpha: 0.35),
              color.withValues(alpha: 0.18),
            ],
          ).createShader(
              Rect.fromCircle(center: reg.center, radius: reg.radius));
        canvas.drawCircle(reg.center, reg.radius, fillPaint);

        final borderPaint = Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = isSelected ? 2.6 : 1.6;
        canvas.drawCircle(reg.center, reg.radius, borderPaint);

        // Label inside bubble
        final shortTitle = reg.node.title.contains('::')
            ? reg.node.title.split('::').last
            : reg.node.title;
        final rPct = '${(reg.node.avgRetrievability * 100).round()}%';

        _drawCenteredText(
          canvas: canvas,
          center: reg.center,
          title: shortTitle,
          subtitle: '$rPct (${reg.node.totalCards})',
          maxWidth: reg.radius * 1.8,
          textColor: isLightMode ? AppColors.lightTextPrimary : Colors.white,
          accentColor: color,
        );
      }
    } else {
      // Concentric Sunburst Ring Mode
      final ringRadius = math.min(size.width, size.height) * 0.34;
      final rect = Rect.fromCircle(center: canvasCenter, radius: ringRadius);

      for (final reg in placedRegions) {
        final isSelected = reg.node.deckId == selectedDeckId;
        final color = reg.node.healthColor;
        final arcPaint = Paint()
          ..color = color.withValues(alpha: isSelected ? 0.92 : 0.68)
          ..style = PaintingStyle.stroke
          ..strokeWidth = isSelected ? 34.0 : 28.0
          ..strokeCap = StrokeCap.butt;

        canvas.drawArc(
          rect,
          reg.startAngle,
          math.max(0.05, reg.sweepAngle - 0.04),
          false,
          arcPaint,
        );

        final shortTitle = reg.node.title.contains('::')
            ? reg.node.title.split('::').last
            : reg.node.title;
        _drawCenteredText(
          canvas: canvas,
          center: reg.center,
          title: shortTitle,
          subtitle: '${(reg.node.avgRetrievability * 100).round()}%',
          maxWidth: 85,
          textColor: isLightMode ? AppColors.lightTextPrimary : Colors.white,
          accentColor: color,
        );
      }
    }
  }

  void _drawCenteredText({
    required Canvas canvas,
    required Offset center,
    required String title,
    required String subtitle,
    required double maxWidth,
    required Color textColor,
    required Color accentColor,
  }) {
    final titlePainter = TextPainter(
      text: TextSpan(
        text: title,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: textColor,
          fontFamilyFallback: AppTypography.universalFontFallbacks,
        ),
      ),
      textAlign: TextAlign.center,
      maxLines: 1,
      ellipsis: '…',
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: maxWidth);

    final subPainter = TextPainter(
      text: TextSpan(
        text: subtitle,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: accentColor,
          fontFamily: AppTypography.monoFont,
        ),
      ),
      textAlign: TextAlign.center,
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: maxWidth);

    titlePainter.paint(
      canvas,
      Offset(center.dx - titlePainter.width / 2, center.dy - 11),
    );
    subPainter.paint(
      canvas,
      Offset(center.dx - subPainter.width / 2, center.dy + 2),
    );
  }

  @override
  bool shouldRepaint(covariant _MasteryMapPainter oldDelegate) {
    return oldDelegate.mode != mode ||
        oldDelegate.selectedDeckId != selectedDeckId ||
        oldDelegate.placedRegions.length != placedRegions.length;
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall,
        ),
      ],
    );
  }
}
