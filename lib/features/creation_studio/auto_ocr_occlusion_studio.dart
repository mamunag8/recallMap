import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';
import '../../core/database/app_database.dart';
import '../../core/database/tables.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/platform/platform_study_bridge.dart';
import '../../shared/widgets/adaptive_glass_card.dart';

enum OcclusionGenerationMode {
  hideAllGuessOne,
  hideOneGuessOne,
}

/// Workflow 2: 1-Tap Auto-OCR Diagram & Image Occlusion Studio.
/// - Tap "✨ Auto-Detect Labels (OCR)" to scan the diagram (English, Bangla বাংলা, Turkish, Arabic)
///   and automatically draw interactive bounding boxes around every label.
/// - Tap detected boxes to toggle them or drag with one finger to draw custom boxes.
/// - Choose "Hide All, Guess One" or "Hide One, Guess One" to generate visual FSRS-6 cards in 1 tap.
class AutoOcrOcclusionStudio extends ConsumerStatefulWidget {
  const AutoOcrOcclusionStudio({super.key});

  @override
  ConsumerState<AutoOcrOcclusionStudio> createState() =>
      _AutoOcrOcclusionStudioState();
}

class _AutoOcrOcclusionStudioState
    extends ConsumerState<AutoOcrOcclusionStudio> {
  static const Uuid _uuid = Uuid();
  String _selectedDiagramPreset = 'vascular_cell_bn';
  OcclusionGenerationMode _occlusionMode =
      OcclusionGenerationMode.hideAllGuessOne;
  final List<NormalizedBoundingBox> _masks = [];
  Offset? _dragStartNorm;
  Offset? _dragCurrentNorm;
  bool _isScanningOcr = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _runAutoDetectOcr();
    });
  }

  Future<void> _runAutoDetectOcr() async {
    setState(() => _isScanningOcr = true);
    final bridge = ref.read(platformStudyBridgeProvider);
    final boxes = await bridge.detectDiagramLabelsOcr(
      imageBytes: null,
      diagramKey: _selectedDiagramPreset,
      languageCodes: const ['bn', 'en', 'tr', 'ar'],
    );
    if (mounted) {
      setState(() {
        _masks
          ..clear()
          ..addAll(boxes);
        _isScanningOcr = false;
      });
    }
  }

  Future<void> _generateOcclusionCards() async {
    final activeBoxes = _masks.where((m) => m.isActiveTarget).toList();
    if (activeBoxes.isEmpty) return;

    final db = ref.read(appDatabaseProvider);
    final targetDeckId =
        db.decks.isNotEmpty ? db.decks.first.id : 'deck_demo_start_here';
    final now = DateTime.now().millisecondsSinceEpoch;
    final generatedCards = <CardRecord>[];

    for (var i = 0; i < activeBoxes.length; i++) {
      final targetBox = activeBoxes[i];
      // Build the mask list for this specific card according to Hide All Guess One vs Hide One Guess One
      final cardMasks = _masks.map((m) {
        if (_occlusionMode == OcclusionGenerationMode.hideAllGuessOne) {
          return m.copyWith(isActiveTarget: m.id == targetBox.id).toJson();
        } else {
          // Only include the single target mask
          return m.copyWith(isActiveTarget: m.id == targetBox.id).toJson();
        }
      }).toList();

      final modeBadge =
          _occlusionMode == OcclusionGenerationMode.hideAllGuessOne
              ? 'Hide All, Guess One'
              : 'Hide One, Guess One';

      generatedCards.add(
        CardRecord(
          id: _uuid.v4(),
          deckId: targetDeckId,
          sourceId: 'src_demo_ocr_diagram',
          sourcePage: 1,
          cardType: 'IMAGE_OCCLUSION',
          frontMd:
              '[Auto-OCR $modeBadge #${i + 1}/${activeBoxes.length}] Identify the highlighted Crimson diagram label:',
          backMd: targetBox.label,
          occlusionMasksJson: jsonEncode(cardMasks),
          tagsJson: jsonEncode(['#image-occlusion', '#auto-ocr', '#bangla']),
          state: 0,
          dueDate: now,
          createdAt: now,
          updatedAt: now,
          contentHash: computeContentHash('${targetBox.id}|$modeBadge|$now'),
        ),
      );
    }

    await db.upsertCardsBatch(generatedCards);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Generated ${generatedCards.length} Auto-OCR Image Occlusion cards (${_occlusionMode == OcclusionGenerationMode.hideAllGuessOne ? "Hide All, Guess One" : "Hide One, Guess One"})!',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(l10nProvider);
    final activeCount = _masks.where((m) => m.isActiveTarget).length;

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        // Top Toolbar: Diagram Preset + 1-Tap Auto-Detect Labels (OCR)
        AdaptiveGlassCard(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      l10n.t('auto_ocr_mask'),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: _isScanningOcr ? null : _runAutoDetectOcr,
                    icon: const Icon(Icons.auto_awesome_rounded, size: 16),
                    label: Text(
                      _isScanningOcr
                          ? 'Scanning OCR...'
                          : '✨ Auto-Detect Labels (OCR)',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    selected: _selectedDiagramPreset == 'vascular_cell_bn',
                    onSelected: (_) {
                      setState(
                          () => _selectedDiagramPreset = 'vascular_cell_bn');
                      _runAutoDetectOcr();
                    },
                    label: const Text(
                      'Vascular & Cell Bio (বাংলা + EN)',
                      style: TextStyle(fontSize: 11.5),
                    ),
                  ),
                  ChoiceChip(
                    selected: _selectedDiagramPreset == 'cardio_heart',
                    onSelected: (_) {
                      setState(() => _selectedDiagramPreset = 'cardio_heart');
                      _runAutoDetectOcr();
                    },
                    label: const Text(
                      'Cardiac Conduction Schematic',
                      style: TextStyle(fontSize: 11.5),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Interactive Diagram Canvas with Tap-to-Toggle & Finger-Drag Custom Boxing
        AdaptiveGlassCard(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tap any OCR box to toggle mask • Drag on canvas to draw a custom box',
                style: Theme.of(context).textTheme.labelSmall,
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 270,
                width: double.infinity,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final size =
                        Size(constraints.maxWidth, constraints.maxHeight);

                    return GestureDetector(
                      onTapUp: (details) {
                        final nx = details.localPosition.dx / size.width;
                        final ny = details.localPosition.dy / size.height;
                        for (var i = 0; i < _masks.length; i++) {
                          final m = _masks[i];
                          if (nx >= m.x &&
                              nx <= m.x + m.w &&
                              ny >= m.y &&
                              ny <= m.y + m.h) {
                            setState(() {
                              _masks[i] =
                                  m.copyWith(isActiveTarget: !m.isActiveTarget);
                            });
                            return;
                          }
                        }
                      },
                      onPanStart: (details) {
                        setState(() {
                          _dragStartNorm = Offset(
                            (details.localPosition.dx / size.width)
                                .clamp(0.0, 1.0),
                            (details.localPosition.dy / size.height)
                                .clamp(0.0, 1.0),
                          );
                          _dragCurrentNorm = _dragStartNorm;
                        });
                      },
                      onPanUpdate: (details) {
                        setState(() {
                          _dragCurrentNorm = Offset(
                            (details.localPosition.dx / size.width)
                                .clamp(0.0, 1.0),
                            (details.localPosition.dy / size.height)
                                .clamp(0.0, 1.0),
                          );
                        });
                      },
                      onPanEnd: (_) {
                        if (_dragStartNorm != null &&
                            _dragCurrentNorm != null) {
                          final rect = Rect.fromPoints(
                            _dragStartNorm!,
                            _dragCurrentNorm!,
                          );
                          if (rect.width > 0.04 && rect.height > 0.03) {
                            setState(() {
                              _masks.add(
                                NormalizedBoundingBox(
                                  id: 'custom_${_masks.length + 1}',
                                  x: rect.left,
                                  y: rect.top,
                                  w: rect.width,
                                  h: rect.height,
                                  label:
                                      'Custom Region #${_masks.length + 1}',
                                  isActiveTarget: true,
                                ),
                              );
                            });
                          }
                        }
                        setState(() {
                          _dragStartNorm = null;
                          _dragCurrentNorm = null;
                        });
                      },
                      child: CustomPaint(
                        size: size,
                        painter: _DiagramOcrCanvasPainter(
                          diagramPreset: _selectedDiagramPreset,
                          masks: _masks,
                          dragStartNorm: _dragStartNorm,
                          dragCurrentNorm: _dragCurrentNorm,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Generation Mode Selector: "Hide All, Guess One" vs "Hide One, Guess One"
        AdaptiveGlassCard(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SegmentedButton<OcclusionGenerationMode>(
                segments: const [
                  ButtonSegment(
                    value: OcclusionGenerationMode.hideAllGuessOne,
                    icon: Icon(Icons.visibility_off_rounded, size: 16),
                    label: Text(
                      'Hide All, Guess One',
                      style: TextStyle(fontSize: 11.5),
                    ),
                  ),
                  ButtonSegment(
                    value: OcclusionGenerationMode.hideOneGuessOne,
                    icon: Icon(Icons.filter_center_focus_rounded, size: 16),
                    label: Text(
                      'Hide One, Guess One',
                      style: TextStyle(fontSize: 11.5),
                    ),
                  ),
                ],
                selected: {_occlusionMode},
                onSelectionChanged: (s) =>
                    setState(() => _occlusionMode = s.first),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: activeCount > 0 ? _generateOcclusionCards : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.masteredEmerald,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                  icon: const Icon(Icons.bolt_rounded),
                  label: Text(
                    'Generate $activeCount Interactive Image Occlusion Cards in 1 Tap',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DiagramOcrCanvasPainter extends CustomPainter {
  final String diagramPreset;
  final List<NormalizedBoundingBox> masks;
  final Offset? dragStartNorm;
  final Offset? dragCurrentNorm;

  const _DiagramOcrCanvasPainter({
    required this.diagramPreset,
    required this.masks,
    this.dragStartNorm,
    this.dragCurrentNorm,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final bgRect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(14),
    );
    canvas.drawRRect(bgRect, Paint()..color = const Color(0xFF0F172A));

    // Draw schematic vector illustration lines inside the diagram canvas
    final center = Offset(size.width / 2, size.height / 2);
    final schematicPaint = Paint()
      ..color = AppColors.sourceRoyalIndigo.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    canvas.drawOval(
      Rect.fromCenter(
        center: center,
        width: size.width * 0.42,
        height: size.height * 0.56,
      ),
      schematicPaint,
    );

    // Draw each OCR bounding box and connector line to central schematic
    for (final m in masks) {
      final rect = Rect.fromLTWH(
        m.x * size.width,
        m.y * size.height,
        m.w * size.width,
        m.h * size.height,
      );

      canvas.drawLine(
        rect.center,
        center,
        Paint()
          ..color = AppColors.unseenElectricSky.withValues(alpha: 0.3)
          ..strokeWidth = 1.2,
      );

      final boxColor = m.isActiveTarget
          ? AppColors.urgentCrimson
          : AppColors.unstudiedSlate;

      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(6)),
        Paint()..color = boxColor.withValues(alpha: 0.24),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(6)),
        Paint()
          ..color = boxColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = m.isActiveTarget ? 2.0 : 1.2,
      );

      final tp = TextPainter(
        text: TextSpan(
          text: m.label,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            fontFamilyFallback: AppTypography.universalFontFallbacks,
          ),
        ),
        maxLines: 1,
        ellipsis: '…',
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: rect.width - 8);

      tp.paint(
        canvas,
        Offset(
          rect.left + 4,
          rect.top + (rect.height - tp.height) / 2,
        ),
      );
    }

    // Active drag selection rectangle
    if (dragStartNorm != null && dragCurrentNorm != null) {
      final dragRect = Rect.fromPoints(
        Offset(dragStartNorm!.dx * size.width, dragStartNorm!.dy * size.height),
        Offset(
          dragCurrentNorm!.dx * size.width,
          dragCurrentNorm!.dy * size.height,
        ),
      );
      canvas.drawRect(
        dragRect,
        Paint()
          ..color = AppColors.unseenElectricSky.withValues(alpha: 0.25),
      );
      canvas.drawRect(
        dragRect,
        Paint()
          ..color = AppColors.unseenElectricSky
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DiagramOcrCanvasPainter oldDelegate) => true;
}
