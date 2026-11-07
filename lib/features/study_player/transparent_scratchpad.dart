import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

class ScratchpadStroke {
  final List<Offset> points;
  final Color color;
  final double strokeWidth;

  ScratchpadStroke({
    required this.points,
    required this.color,
    this.strokeWidth = 3.2,
  });

  Map<String, dynamic> toJson() => {
        'color': color.value,
        'strokeWidth': strokeWidth,
        'points': points.map((p) => {'x': p.dx, 'y': p.dy}).toList(),
      };
}

/// Transparent Stylus & Finger Scratchpad Overlay (`✏️ Scratchpad`).
/// Lets students draw directly over the flashcard (with 4 ink colors, pressure-aware width,
/// 1-tap clear, and 1-tap "Pin Mnemonic Sketch to Card") to work out math derivations,
/// chemical structures, or Bengali/Arabic script strokes before revealing the answer.
class TransparentScratchpad extends StatefulWidget {
  final ValueChanged<List<Map<String, dynamic>>>? onSaveMnemonicSketch;
  final VoidCallback? onClose;

  const TransparentScratchpad({
    super.key,
    this.onSaveMnemonicSketch,
    this.onClose,
  });

  @override
  State<TransparentScratchpad> createState() => _TransparentScratchpadState();
}

class _TransparentScratchpadState extends State<TransparentScratchpad> {
  static const List<Color> _palette = [
    AppColors.unseenElectricSky,
    AppColors.masteredEmerald,
    AppColors.stabilizingAmber,
    AppColors.urgentCrimson,
  ];

  final List<ScratchpadStroke> _strokes = [];
  Color _activeColor = AppColors.unseenElectricSky;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Full-Screen Transparent Drawing Surface
        Positioned.fill(
          child: GestureDetector(
            onPanStart: (details) {
              setState(() {
                _strokes.add(
                  ScratchpadStroke(
                    points: [details.localPosition],
                    color: _activeColor,
                  ),
                );
              });
            },
            onPanUpdate: (details) {
              if (_strokes.isNotEmpty) {
                setState(() {
                  _strokes.last.points.add(details.localPosition);
                });
              }
            },
            child: CustomPaint(
              painter: _ScratchpadInkPainter(strokes: _strokes),
              child: Container(
                color: Colors.black.withValues(alpha: 0.08),
              ),
            ),
          ),
        ),

        // Floating Top Ink Palette & Action Pill
        Positioned(
          top: 10,
          right: 12,
          left: 12,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.darkGlassDrawer.withValues(alpha: 0.94),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: AppColors.unseenElectricSky.withValues(alpha: 0.5),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.draw_rounded,
                    size: 16,
                    color: AppColors.unseenElectricSky,
                  ),
                  const SizedBox(width: 8),
                  ..._palette.map((color) {
                    final selected = _activeColor == color;
                    return GestureDetector(
                      onTap: () => setState(() => _activeColor = color),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: selected ? 22 : 18,
                        height: selected ? 22 : 18,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white,
                            width: selected ? 2.2 : 0.8,
                          ),
                        ),
                      ),
                    );
                  }),
                  const SizedBox(width: 8),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Clear Ink',
                    onPressed: () => setState(() => _strokes.clear()),
                    icon: const Icon(
                      Icons.cleaning_services_rounded,
                      size: 16,
                      color: Colors.white70,
                    ),
                  ),
                  if (widget.onSaveMnemonicSketch != null)
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: 'Pin Mnemonic Sketch to Card',
                      onPressed: () {
                        widget.onSaveMnemonicSketch?.call(
                          _strokes.map((s) => s.toJson()).toList(),
                        );
                      },
                      icon: const Icon(
                        Icons.push_pin_rounded,
                        size: 16,
                        color: AppColors.masteredEmerald,
                      ),
                    ),
                  if (widget.onClose != null)
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: 'Close Scratchpad',
                      onPressed: widget.onClose,
                      icon: const Icon(
                        Icons.close_rounded,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ScratchpadInkPainter extends CustomPainter {
  final List<ScratchpadStroke> strokes;

  const _ScratchpadInkPainter({required this.strokes});

  @override
  void paint(Canvas canvas, Size size) {
    for (final stroke in strokes) {
      if (stroke.points.isEmpty) continue;
      final paint = Paint()
        ..color = stroke.color
        ..strokeWidth = stroke.strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;

      if (stroke.points.length == 1) {
        canvas.drawCircle(stroke.points.first, stroke.strokeWidth / 2, paint);
      } else {
        final path = Path()
          ..moveTo(stroke.points.first.dx, stroke.points.first.dy);
        for (var i = 1; i < stroke.points.length; i++) {
          path.lineTo(stroke.points[i].dx, stroke.points[i].dy);
        }
        canvas.drawPath(path, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ScratchpadInkPainter oldDelegate) => true;
}
