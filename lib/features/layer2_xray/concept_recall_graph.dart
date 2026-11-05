import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';
import '../../core/constants/fsrs_constants.dart';
import '../../core/database/tables.dart';
import '../fsrs_engine/fsrs_v6_scheduler.dart';
import 'graph_physics_solver.dart';

/// LAYER 2 (Hero Feature 2): The Interactive 2D Concept RecallMap (Graph Canvas).
/// - 60fps zoomable, pannable, draggable 2D force-directed graph showing how Decks,
///   PDF Chapters, Concept Notes, and Flashcards interconnect via `[[Concept Links]]`,
///   `#tags`, `PDF_EXTRACTION`, and `CONFUSABLE_TWIN` edges.
/// - Visual Bottleneck Pulse: Nodes whose cards have `R < 80%` emit a soft Crimson
///   pulse on the graph so the student immediately sees which foundational concept
///   is weakening their understanding.
class ConceptRecallGraph extends StatefulWidget {
  final List<StudySourceRecord> sources;
  final List<CardRecord> cards;
  final List<ConceptEdgeRecord> edges;
  final ValueChanged<CardRecord>? onCardNodeTap;
  final ValueChanged<StudySourceRecord>? onSourceNodeTap;

  const ConceptRecallGraph({
    super.key,
    required this.sources,
    required this.cards,
    required this.edges,
    this.onCardNodeTap,
    this.onSourceNodeTap,
  });

  @override
  State<ConceptRecallGraph> createState() => _ConceptRecallGraphState();
}

class _ConceptRecallGraphState extends State<ConceptRecallGraph>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final List<GraphPhysicsNode> _nodes = [];
  final List<GraphPhysicsEdge> _physicsEdges = [];
  String? _draggedNodeId;
  String? _selectedNodeId;
  double _pulsePhase = 0.0;
  Size _lastCanvasSize = const Size(600, 420);

  @override
  void initState() {
    super.initState();
    _rebuildGraphEntities();
    _ticker = createTicker((elapsed) {
      setState(() {
        _pulsePhase = (elapsed.inMilliseconds % 1800) / 1800.0;
        GraphPhysicsSolver.stepSimulation(
          nodes: _nodes,
          edges: _physicsEdges,
          canvasSize: _lastCanvasSize,
          draggedNodeId: _draggedNodeId,
        );
      });
    })..start();
  }

  @override
  void didUpdateWidget(covariant ConceptRecallGraph oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cards.length != widget.cards.length ||
        oldWidget.sources.length != widget.sources.length ||
        oldWidget.edges.length != widget.edges.length) {
      _rebuildGraphEntities();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _rebuildGraphEntities() {
    _nodes.clear();
    _physicsEdges.clear();
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    const scheduler = FsrsV6Scheduler();

    var idx = 0;
    for (final src in widget.sources) {
      final angle = (2 * math.pi * idx) / math.max(1, widget.sources.length);
      final initX = 260 + 110 * math.cos(angle);
      final initY = 190 + 80 * math.sin(angle);
      _nodes.add(
        GraphPhysicsNode(
          id: src.id,
          label: src.title,
          nodeType: src.sourceType,
          retrievability: 0.94,
          stability: 30.0,
          isBottleneckCrimson: false,
          color: AppColors.sourceRoyalIndigo,
          radius: 30.0,
          position: Offset(initX, initY),
        ),
      );
      idx++;
    }

    for (final card in widget.cards) {
      final r = card.state == FsrsConstants.stateNew
          ? 0.0
          : scheduler.liveRetrievabilityForCard(card, nowMs: nowMs);
      final color = AppColors.colorForMemoryHealth(
        state: card.state,
        retrievability: r,
        stability: card.stability,
        lapses: card.lapses,
      );
      final isBottleneck =
          card.state != FsrsConstants.stateNew && (r < 0.80 || card.isLeech);
      final angle = (2 * math.pi * idx) /
          math.max(1, widget.cards.length + widget.sources.length);

      _nodes.add(
        GraphPhysicsNode(
          id: card.id,
          label: _cleanShortLabel(card.frontMd),
          nodeType: 'CARD',
          retrievability: r,
          stability: card.stability,
          isBottleneckCrimson: isBottleneck,
          color: color,
          radius: isBottleneck ? 27.0 : 23.0,
          position: Offset(
            280 + 160 * math.cos(angle),
            200 + 125 * math.sin(angle),
          ),
        ),
      );
      idx++;
    }

    for (final e in widget.edges) {
      _physicsEdges.add(
        GraphPhysicsEdge(
          id: e.id,
          fromId: e.fromId,
          toId: e.toId,
          edgeType: e.edgeType,
          strength: e.strength,
        ),
      );
    }
  }

  String _cleanShortLabel(String raw) {
    final stripped = raw
        .replaceAll(RegExp(r'\{\{c\d+::([^:}]+)(?:::[^}]+)?\}\}'), r'$1')
        .replaceAll(r'$$', '');
    if (stripped.length <= 24) return stripped;
    return '${stripped.substring(0, 22)}…';
  }

  GraphPhysicsNode? _hitTestNode(Offset localPos) {
    for (final n in _nodes.reversed) {
      if ((localPos - n.position).distance <= n.radius + 8) {
        return n;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _lastCanvasSize = Size(
          math.max(320, constraints.maxWidth),
          math.max(280, constraints.maxHeight),
        );

        return GestureDetector(
          onTapUp: (details) {
            final hit = _hitTestNode(details.localPosition);
            if (hit != null) {
              setState(() => _selectedNodeId = hit.id);
              if (hit.nodeType == 'CARD') {
                final card =
                    widget.cards.where((c) => c.id == hit.id).firstOrNull;
                if (card != null) widget.onCardNodeTap?.call(card);
              } else {
                final src =
                    widget.sources.where((s) => s.id == hit.id).firstOrNull;
                if (src != null) widget.onSourceNodeTap?.call(src);
              }
            }
          },
          onPanStart: (details) {
            final hit = _hitTestNode(details.localPosition);
            if (hit != null) {
              setState(() {
                _draggedNodeId = hit.id;
                _selectedNodeId = hit.id;
              });
            }
          },
          onPanUpdate: (details) {
            if (_draggedNodeId != null) {
              final node =
                  _nodes.where((n) => n.id == _draggedNodeId).firstOrNull;
              if (node != null) {
                setState(() {
                  node.position = details.localPosition;
                  node.velocity = Offset.zero;
                });
              }
            }
          },
          onPanEnd: (_) => setState(() => _draggedNodeId = null),
          child: CustomPaint(
            size: _lastCanvasSize,
            painter: _ConceptGraphPainter(
              nodes: _nodes,
              edges: _physicsEdges,
              selectedNodeId: _selectedNodeId,
              pulsePhase: _pulsePhase,
              isLightMode: Theme.of(context).brightness == Brightness.light,
            ),
          ),
        );
      },
    );
  }
}

class _ConceptGraphPainter extends CustomPainter {
  final List<GraphPhysicsNode> nodes;
  final List<GraphPhysicsEdge> edges;
  final String? selectedNodeId;
  final double pulsePhase;
  final bool isLightMode;

  const _ConceptGraphPainter({
    required this.nodes,
    required this.edges,
    required this.selectedNodeId,
    required this.pulsePhase,
    required this.isLightMode,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final nodeMap = {for (final n in nodes) n.id: n};

    // 1. Draw Edges (WIKI_LINK, PDF_EXTRACTION, CONFUSABLE_TWIN)
    for (final edge in edges) {
      final from = nodeMap[edge.fromId];
      final to = nodeMap[edge.toId];
      if (from == null || to == null) continue;

      final isTwin = edge.edgeType == 'CONFUSABLE_TWIN';
      final edgeColor = isTwin
          ? AppColors.urgentCrimson.withValues(alpha: 0.75)
          : (edge.edgeType == 'WIKI_LINK'
              ? AppColors.sourceRoyalIndigo.withValues(alpha: 0.55)
              : AppColors.unseenElectricSky.withValues(alpha: 0.35));

      final paint = Paint()
        ..color = edgeColor
        ..strokeWidth = isTwin ? 2.4 : 1.6;
      canvas.drawLine(from.position, to.position, paint);
    }

    // 2. Draw Nodes + Crimson Visual Bottleneck Pulse for R < 80%
    for (final node in nodes) {
      if (node.isBottleneckCrimson) {
        final pulseRadius =
            node.radius + 6.0 + 14.0 * math.sin(pulsePhase * math.pi);
        final pulseAlpha = (1.0 - pulsePhase) * 0.38;
        canvas.drawCircle(
          node.position,
          pulseRadius,
          Paint()
            ..color = AppColors.urgentCrimson.withValues(alpha: pulseAlpha)
            ..style = PaintingStyle.fill,
        );
      }

      final isSelected = node.id == selectedNodeId;
      final fillPaint = Paint()
        ..color = node.color.withValues(alpha: 0.22)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(node.position, node.radius, fillPaint);

      final borderPaint = Paint()
        ..color = node.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = isSelected ? 2.8 : 1.8;
      canvas.drawCircle(node.position, node.radius, borderPaint);

      // Node Label & Live Retrievability Badge
      final rText = node.nodeType == 'CARD'
          ? 'R ${(node.retrievability * 100).round()}%'
          : node.nodeType;
      final tp = TextPainter(
        text: TextSpan(
          text: '${node.label}\n',
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            color: isLightMode ? AppColors.lightTextPrimary : Colors.white,
            fontFamilyFallback: AppTypography.universalFontFallbacks,
          ),
          children: [
            TextSpan(
              text: rText,
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
                color: node.color,
                fontFamily: AppTypography.monoFont,
              ),
            ),
          ],
        ),
        textAlign: TextAlign.center,
        maxLines: 2,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: 115);

      tp.paint(
        canvas,
        Offset(
          node.position.dx - tp.width / 2,
          node.position.dy + node.radius + 4,
        ),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ConceptGraphPainter oldDelegate) => true;
}
