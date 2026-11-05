import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';
import '../../core/constants/fsrs_constants.dart';
import '../../core/database/tables.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/platform/platform_study_bridge.dart';
import '../../shared/widgets/adaptive_glass_card.dart';
import '../../shared/widgets/math_latex_view.dart';
import '../fsrs_engine/fsrs_v6_scheduler.dart';

/// Multi-Sensory One-Handed Gesture Card Stack & Live FSRS-6 Interval Bar.
/// - Tap card to flip / reveal Cloze or Image Occlusion masks.
/// - Grade via 4-way directional swipes (Left = Again, Down = Hard, Right = Good, Up = Easy)
///   OR bottom color-coded buttons displaying exact FSRS-6 intervals (`Again 10m`, `Hard 3d`, `Good 8d`, `Easy 21d`).
class GestureCardStack extends ConsumerStatefulWidget {
  final CardRecord card;
  final Map<int, FsrsScheduleOutcome> ratingPreviews;
  final ValueChanged<int> onGradeSelected;
  final VoidCallback? onInspectLayer3;

  const GestureCardStack({
    super.key,
    required this.card,
    required this.ratingPreviews,
    required this.onGradeSelected,
    this.onInspectLayer3,
  });

  @override
  ConsumerState<GestureCardStack> createState() => _GestureCardStackState();
}

class _GestureCardStackState extends ConsumerState<GestureCardStack> {
  bool _isRevealed = false;
  Offset _dragOffset = Offset.zero;

  @override
  void didUpdateWidget(covariant GestureCardStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.card.id != widget.card.id) {
      _isRevealed = false;
      _dragOffset = Offset.zero;
    }
  }

  void _triggerGrade(int rating) {
    HapticFeedback.lightImpact();
    widget.onGradeSelected(rating);
  }

  int? _detectSwipeRating(Offset offset) {
    if (offset.distance < 70) return null;
    if (offset.dx.abs() > offset.dy.abs()) {
      // Horizontal swipe: Left = Again (1), Right = Good (3)
      return offset.dx < 0
          ? FsrsConstants.ratingAgain
          : FsrsConstants.ratingGood;
    } else {
      // Vertical swipe: Down = Hard (2), Up = Easy (4)
      return offset.dy > 0
          ? FsrsConstants.ratingHard
          : FsrsConstants.ratingEasy;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(l10nProvider);
    const scheduler = FsrsV6Scheduler();
    final liveR = scheduler.liveRetrievabilityForCard(widget.card);
    final swipeRating = _detectSwipeRating(_dragOffset);

    return Column(
      children: [
        // Interactive Flashcard with 4-Way Swipe Physics
        Expanded(
          child: GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _isRevealed = !_isRevealed);
            },
            onPanUpdate: (details) {
              setState(() => _dragOffset += details.delta);
            },
            onPanEnd: (_) {
              final rating = _detectSwipeRating(_dragOffset);
              setState(() => _dragOffset = Offset.zero);
              if (rating != null) {
                _triggerGrade(rating);
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              transform: Matrix4.translationValues(
                _dragOffset.dx * 0.45,
                _dragOffset.dy * 0.45,
                0,
              ),
              child: AdaptiveGlassCard(
                accentBorderColor: swipeRating != null
                    ? _colorForRating(swipeRating)
                    : AppColors.sourceRoyalIndigo.withValues(alpha: 0.45),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Card Metadata Top Strip
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.sourceRoyalIndigo
                                    .withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                widget.card.cardType,
                                style: AppTypography.monoMetric(
                                  fontSize: 11,
                                  color: AppColors.sourceRoyalIndigo,
                                ),
                              ),
                            ),
                            if (widget.card.sourcePage != null) ...[
                              const SizedBox(width: 8),
                              Text(
                                'PDF P.${l10n.formatNumber(widget.card.sourcePage!)}',
                                style: AppTypography.monoMetric(
                                  fontSize: 11,
                                  color: AppColors.unseenElectricSky,
                                ),
                              ),
                            ],
                          ],
                        ),
                        Row(
                          children: [
                            Text(
                              'R: ${l10n.formatNumber((liveR * 100).round())}% • S: ${l10n.formatNumber(widget.card.stability.toStringAsFixed(1))}d',
                              style: AppTypography.monoMetric(
                                fontSize: 11.5,
                                color: AppColors.masteredEmerald,
                              ),
                            ),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              tooltip: 'Open Layer 3 DSR Curve Inspector',
                              onPressed: widget.onInspectLayer3,
                              icon: const Icon(
                                Icons.insights_rounded,
                                size: 18,
                                color: AppColors.unseenElectricSky,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const Divider(height: 20),

                    // Main Card Content (Front Prompt, Cloze, or Image Occlusion Diagram)
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            MathLatexView(
                              markdownWithLatex: widget.card.frontMd,
                              revealCloze: _isRevealed,
                              fontSize: 17.5,
                            ),
                            if (widget.card.cardType == 'IMAGE_OCCLUSION' &&
                                widget.card.occlusionMasksJson != null) ...[
                              const SizedBox(height: 14),
                              _InteractiveOcclusionPreview(
                                masksJson: widget.card.occlusionMasksJson!,
                                isRevealed: _isRevealed,
                              ),
                            ],
                            if (_isRevealed) ...[
                              const SizedBox(height: 18),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: AppColors.masteredEmerald
                                      .withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: AppColors.masteredEmerald
                                        .withValues(alpha: 0.45),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'ANSWER & EXPLANATION',
                                      style: AppTypography.monoMetric(
                                        fontSize: 10.5,
                                        color: AppColors.masteredEmerald,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    MathLatexView(
                                      markdownWithLatex: widget.card.backMd,
                                      revealCloze: true,
                                      fontSize: 15.5,
                                    ),
                                  ],
                                ),
                              ),
                            ] else ...[
                              const SizedBox(height: 28),
                              Center(
                                child: Text(
                                  'Tap card to reveal answer • Or swipe ← Again | ↓ Hard | → Good | ↑ Easy',
                                  style: Theme.of(context).textTheme.labelSmall,
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Bottom Live FSRS-6 Interval Grading Bar
        Row(
          children: [
            _FsrsGradeButton(
              label: l10n.t('grade_again'),
              interval: l10n.formatNumber(
                widget.ratingPreviews[FsrsConstants.ratingAgain]
                        ?.formattedIntervalLabel ??
                    '10m',
              ),
              color: AppColors.urgentCrimson,
              swipeHint: '←',
              onTap: () => _triggerGrade(FsrsConstants.ratingAgain),
            ),
            const SizedBox(width: 8),
            _FsrsGradeButton(
              label: l10n.t('grade_hard'),
              interval: l10n.formatNumber(
                widget.ratingPreviews[FsrsConstants.ratingHard]
                        ?.formattedIntervalLabel ??
                    '2d',
              ),
              color: AppColors.stabilizingAmber,
              swipeHint: '↓',
              onTap: () => _triggerGrade(FsrsConstants.ratingHard),
            ),
            const SizedBox(width: 8),
            _FsrsGradeButton(
              label: l10n.t('grade_good'),
              interval: l10n.formatNumber(
                widget.ratingPreviews[FsrsConstants.ratingGood]
                        ?.formattedIntervalLabel ??
                    '7d',
              ),
              color: AppColors.masteredEmerald,
              swipeHint: '→',
              onTap: () => _triggerGrade(FsrsConstants.ratingGood),
            ),
            const SizedBox(width: 8),
            _FsrsGradeButton(
              label: l10n.t('grade_easy'),
              interval: l10n.formatNumber(
                widget.ratingPreviews[FsrsConstants.ratingEasy]
                        ?.formattedIntervalLabel ??
                    '19d',
              ),
              color: AppColors.unseenElectricSky,
              swipeHint: '↑',
              onTap: () => _triggerGrade(FsrsConstants.ratingEasy),
            ),
          ],
        ),
      ],
    );
  }

  Color _colorForRating(int rating) {
    return switch (rating) {
      FsrsConstants.ratingAgain => AppColors.urgentCrimson,
      FsrsConstants.ratingHard => AppColors.stabilizingAmber,
      FsrsConstants.ratingGood => AppColors.masteredEmerald,
      _ => AppColors.unseenElectricSky,
    };
  }
}

class _FsrsGradeButton extends StatelessWidget {
  final String label;
  final String interval;
  final Color color;
  final String swipeHint;
  final VoidCallback onTap;

  const _FsrsGradeButton({
    required this.label,
    required this.interval,
    required this.color,
    required this.swipeHint,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.6), width: 1.4),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$swipeHint $interval',
                style: AppTypography.monoMetric(
                  fontSize: 12.5,
                  color: color,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InteractiveOcclusionPreview extends StatelessWidget {
  final String masksJson;
  final bool isRevealed;

  const _InteractiveOcclusionPreview({
    required this.masksJson,
    required this.isRevealed,
  });

  @override
  Widget build(BuildContext context) {
    final masks = <NormalizedBoundingBox>[];
    try {
      final list = jsonDecode(masksJson) as List;
      for (final item in list) {
        masks.add(
          NormalizedBoundingBox.fromJson(
              Map<String, dynamic>.from(item as Map)),
        );
      }
    } catch (_) {}

    return Container(
      height: 170,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.sourceRoyalIndigo.withValues(alpha: 0.4),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            children: masks.map((m) {
              final showLabel = !m.isActiveTarget || isRevealed;
              final boxColor = m.isActiveTarget
                  ? (isRevealed
                      ? AppColors.masteredEmerald
                      : AppColors.urgentCrimson)
                  : AppColors.unstudiedSlate;

              return Positioned(
                left: m.x * constraints.maxWidth,
                top: m.y * constraints.maxHeight,
                width: m.w * constraints.maxWidth,
                height: m.h * constraints.maxHeight + 12,
                child: Container(
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: boxColor.withValues(alpha: showLabel ? 0.25 : 0.92),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: boxColor, width: 1.6),
                  ),
                  child: Text(
                    showLabel ? m.label : '❓ [Occluded Target]',
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}
