import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Node in the 2D Concept RecallMap force-directed physics simulation.
class GraphPhysicsNode {
  final String id;
  final String label;
  final String nodeType; // 'DECK' | 'PDF' | 'CONCEPT_NOTE' | 'CARD'
  final double retrievability; // 0.0 .. 1.0
  final double stability;
  final bool isBottleneckCrimson; // R < 80%
  final Color color;
  final double radius;
  Offset position;
  Offset velocity;

  GraphPhysicsNode({
    required this.id,
    required this.label,
    required this.nodeType,
    required this.retrievability,
    required this.stability,
    required this.isBottleneckCrimson,
    required this.color,
    this.radius = 26.0,
    required this.position,
    this.velocity = Offset.zero,
  });
}

/// Directed or undirected edge between two [GraphPhysicsNode] instances.
class GraphPhysicsEdge {
  final String id;
  final String fromId;
  final String toId;
  final String edgeType; // 'WIKI_LINK' | 'PDF_EXTRACTION' | 'SHARED_TAG' | 'CONFUSABLE_TWIN'
  final double strength;

  const GraphPhysicsEdge({
    required this.id,
    required this.fromId,
    required this.toId,
    required this.edgeType,
    this.strength = 1.0,
  });
}

/// 60fps Force-Directed Graph Physics Solver (Coulomb node repulsion + Hooke spring edges
/// + center gravity + velocity damping).
class GraphPhysicsSolver {
  GraphPhysicsSolver._();

  static void stepSimulation({
    required List<GraphPhysicsNode> nodes,
    required List<GraphPhysicsEdge> edges,
    required Size canvasSize,
    String? draggedNodeId,
  }) {
    if (nodes.isEmpty || canvasSize.width <= 0 || canvasSize.height <= 0) {
      return;
    }

    const repulsionStrength = 4800.0;
    const springRestLength = 125.0;
    const springK = 0.035;
    const centerGravity = 0.008;
    const damping = 0.80;

    final center = Offset(canvasSize.width / 2, canvasSize.height / 2);
    final nodeMap = {for (final n in nodes) n.id: n};

    // 1. All-pairs Coulomb repulsion + gentle pull toward canvas center
    for (var i = 0; i < nodes.length; i++) {
      final a = nodes[i];
      if (a.id == draggedNodeId) continue;

      var force = (center - a.position) * centerGravity;

      for (var j = 0; j < nodes.length; j++) {
        if (i == j) continue;
        final b = nodes[j];
        final delta = a.position - b.position;
        final distSq = math.max(144.0, delta.distanceSquared);
        final dist = math.sqrt(distSq);
        final unit = delta / dist;
        force += unit * (repulsionStrength / distSq);
      }

      a.velocity = (a.velocity + force) * damping;
    }

    // 2. Hooke's Law spring attraction along connected edges
    for (final edge in edges) {
      final from = nodeMap[edge.fromId];
      final to = nodeMap[edge.toId];
      if (from == null || to == null) continue;

      final delta = to.position - from.position;
      final dist = math.max(1.0, delta.distance);
      final displacement = dist - springRestLength;
      final springForce = (delta / dist) * (displacement * springK * edge.strength);

      if (from.id != draggedNodeId) {
        from.velocity += springForce;
      }
      if (to.id != draggedNodeId) {
        to.velocity -= springForce;
      }
    }

    // 3. Integrate positions & clamp inside canvas padding
    const pad = 42.0;
    for (final node in nodes) {
      if (node.id == draggedNodeId) continue;
      if (node.velocity.distance > 12.0) {
        node.velocity = (node.velocity / node.velocity.distance) * 12.0;
      }
      final nextPos = node.position + node.velocity;
      node.position = Offset(
        nextPos.dx.clamp(pad, math.max(pad + 10, canvasSize.width - pad)),
        nextPos.dy.clamp(pad, math.max(pad + 10, canvasSize.height - pad)),
      );
    }
  }
}
