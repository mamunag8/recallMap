import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';
import '../../core/constants/fsrs_constants.dart';
import '../../core/database/tables.dart';
import '../../shared/widgets/adaptive_glass_card.dart';
import '../../shared/widgets/math_latex_view.dart';

/// 5-Minute "Boss Battle" Speed Quiz Mode.
/// Gamified pre-exam blitz mode that turns due cards into a timed multiple-choice
/// & rapid-recall challenge with streak multipliers, haptic effects, and a post-round
/// accuracy breakdown.
class BossBattleQuizMode extends StatefulWidget {
  final List<CardRecord> cards;
  final void Function(CardRecord card, int rating) onCardGraded;

  const BossBattleQuizMode({
    super.key,
    required this.cards,
    required this.onCardGraded,
  });

  @override
  State<BossBattleQuizMode> createState() => _BossBattleQuizModeState();
}

class _BossBattleQuizModeState extends State<BossBattleQuizMode> {
  int _currentIndex = 0;
  int _comboStreak = 0;
  int _totalScore = 0;
  int _correctCount = 0;
  int _secondsRemaining = 300; // 5-minute blitz
  Timer? _timer;
  late List<String> _currentChoices;
  String? _selectedAnswer;

  @override
  void initState() {
    super.initState();
    _buildChoicesForCurrentCard();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_secondsRemaining > 0) {
        setState(() => _secondsRemaining--);
      } else {
        t.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _buildChoicesForCurrentCard() {
    if (widget.cards.isEmpty) {
      _currentChoices = const [];
      return;
    }
    final active = widget.cards[_currentIndex % widget.cards.length];
    final correct = active.backMd;
    final distractors = widget.cards
        .where((c) => c.id != active.id)
        .map((c) => c.backMd)
        .take(3)
        .toList();

    while (distractors.length < 3) {
      distractors.add(
        'Alternative Hypothesis #${distractors.length + 1}: Check static pressure equilibrium',
      );
    }

    final options = [correct, ...distractors];
    options.shuffle(math.Random(_currentIndex + 42));
    _currentChoices = options;
    _selectedAnswer = null;
  }

  void _submitChoice(String choice) {
    if (_selectedAnswer != null || widget.cards.isEmpty) return;
    final active = widget.cards[_currentIndex % widget.cards.length];
    final isCorrect = choice == active.backMd;
    HapticFeedback.mediumImpact();

    setState(() {
      _selectedAnswer = choice;
      if (isCorrect) {
        _comboStreak++;
        _correctCount++;
        _totalScore += 100 * math.min(5, _comboStreak);
      } else {
        _comboStreak = 0;
      }
    });

    widget.onCardGraded(
      active,
      isCorrect ? FsrsConstants.ratingGood : FsrsConstants.ratingAgain,
    );

    Future.delayed(const Duration(milliseconds: 650), () {
      if (!mounted) return;
      setState(() {
        _currentIndex++;
        _buildChoicesForCurrentCard();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.cards.isEmpty) {
      return const Center(child: Text('No cards available for Boss Battle.'));
    }

    if (_currentIndex >= widget.cards.length || _secondsRemaining <= 0) {
      final accuracy =
          ((_correctCount / math.max(1, _currentIndex)) * 100).round();
      return Center(
        child: AdaptiveGlassCard(
          accentBorderColor: AppColors.masteredEmerald,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.emoji_events_rounded,
                size: 52,
                color: AppColors.stabilizingAmber,
              ),
              const SizedBox(height: 12),
              Text(
                'Boss Battle Victory! • $accuracy% Accuracy',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Total Score: $_totalScore XP • $_correctCount / $_currentIndex Cards Mastered',
                style: AppTypography.monoMetric(
                  fontSize: 14,
                  color: AppColors.masteredEmerald,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () {
                  setState(() {
                    _currentIndex = 0;
                    _comboStreak = 0;
                    _totalScore = 0;
                    _correctCount = 0;
                    _secondsRemaining = 300;
                    _buildChoicesForCurrentCard();
                  });
                },
                icon: const Icon(Icons.replay_rounded),
                label: const Text('Play Another 5-Min Blitz Round'),
              ),
            ],
          ),
        ),
      );
    }

    final activeCard = widget.cards[_currentIndex];
    final mins = (_secondsRemaining ~/ 60).toString().padLeft(2, '0');
    final secs = (_secondsRemaining % 60).toString().padLeft(2, '0');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Top Gamified HUD Bar
        AdaptiveGlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '⏱ $mins:$secs',
                style: AppTypography.monoMetric(
                  fontSize: 14,
                  color: AppColors.urgentCrimson,
                ),
              ),
              Text(
                '🔥 ${math.max(1, _comboStreak)}x Combo',
                style: AppTypography.monoMetric(
                  fontSize: 14,
                  color: AppColors.stabilizingAmber,
                ),
              ),
              Text(
                '⭐ $_totalScore XP',
                style: AppTypography.monoMetric(
                  fontSize: 14,
                  color: AppColors.masteredEmerald,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Question Prompt Card
        AdaptiveGlassCard(
          accentBorderColor: AppColors.sourceRoyalIndigo,
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'BOSS QUESTION ${_currentIndex + 1} / ${widget.cards.length}',
                style: AppTypography.monoMetric(
                  fontSize: 11,
                  color: AppColors.unseenElectricSky,
                ),
              ),
              const SizedBox(height: 8),
              MathLatexView(
                markdownWithLatex: activeCard.frontMd,
                revealCloze: false,
                fontSize: 16.5,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // 4 Multiple-Choice Options
        Expanded(
          child: ListView.builder(
            itemCount: _currentChoices.length,
            itemBuilder: (context, idx) {
              final option = _currentChoices[idx];
              final isSelected = _selectedAnswer == option;
              final isCorrect = option == activeCard.backMd;

              Color? borderColor;
              if (_selectedAnswer != null) {
                if (isCorrect) {
                  borderColor = AppColors.masteredEmerald;
                } else if (isSelected) {
                  borderColor = AppColors.urgentCrimson;
                }
              }

              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: AdaptiveGlassCard(
                  accentBorderColor: borderColor,
                  onTap: () => _submitChoice(option),
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 13,
                        backgroundColor: AppColors.sourceRoyalIndigo
                            .withValues(alpha: 0.2),
                        child: Text(
                          String.fromCharCode(65 + idx),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: MathLatexView(
                          markdownWithLatex: option,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
