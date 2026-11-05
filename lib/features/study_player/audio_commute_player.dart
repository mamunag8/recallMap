import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';
import '../../core/constants/fsrs_constants.dart';
import '../../core/database/tables.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/platform/platform_study_bridge.dart';
import '../../shared/widgets/adaptive_glass_card.dart';

/// Hands-Free Commute Audio Mode (100% Offline TTS).
/// Reads the question aloud in the card's native language (`bn-BD`, `en-US`, `tr-TR`, `ar-SA`)
/// -> plays a gentle 4-second thinking cadence -> reads the answer aloud ->
/// accepts grading via large full-screen eyes-free touch zones.
class AudioCommutePlayer extends ConsumerStatefulWidget {
  final CardRecord card;
  final ValueChanged<int> onGradeSelected;

  const AudioCommutePlayer({
    super.key,
    required this.card,
    required this.onGradeSelected,
  });

  @override
  ConsumerState<AudioCommutePlayer> createState() => _AudioCommutePlayerState();
}

class _AudioCommutePlayerState extends ConsumerState<AudioCommutePlayer> {
  String _stageStatus = 'Ready for Hands-Free Audio Loop';
  int _thinkingCountdown = 4;
  bool _isLoopActive = false;
  Timer? _cadenceTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startCommuteAudioCycle();
    });
  }

  @override
  void didUpdateWidget(covariant AudioCommutePlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.card.id != widget.card.id && _isLoopActive) {
      _startCommuteAudioCycle();
    }
  }

  @override
  void dispose() {
    _cadenceTimer?.cancel();
    super.dispose();
  }

  String _detectCardTtsLocale(String text) {
    // Auto-detect Bengali script (\u0980-\u09FF) or Arabic script (\u0600-\u06FF)
    if (RegExp(r'[\u0980-\u09FF]').hasMatch(text)) {
      return 'bn-BD';
    }
    if (RegExp(r'[\u0600-\u06FF]').hasMatch(text)) {
      return 'ar-SA';
    }
    final settings = ref.read(appLocaleProvider);
    return AppLocalizations.infoFor(settings.languageCode).ttsLocale;
  }

  Future<void> _startCommuteAudioCycle() async {
    _cadenceTimer?.cancel();
    final bridge = ref.read(platformStudyBridgeProvider);
    final locale = _detectCardTtsLocale(widget.card.frontMd);

    setState(() {
      _isLoopActive = true;
      _stageStatus = '🔊 Reading Prompt ($locale)...';
      _thinkingCountdown = 4;
    });

    await bridge.speakOfflineTts(
      text: widget.card.frontMd,
      localeCode: locale,
    );

    if (!mounted) return;
    setState(() => _stageStatus = '🧠 Thinking Cadence (4s)...');

    _cadenceTimer = Timer.periodic(const Duration(seconds: 1), (t) async {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_thinkingCountdown > 1) {
        setState(() => _thinkingCountdown--);
      } else {
        t.cancel();
        setState(() => _stageStatus = '🔊 Speaking Answer ($locale)...');
        await bridge.speakOfflineTts(
          text: widget.card.backMd,
          localeCode: _detectCardTtsLocale(widget.card.backMd),
        );
        if (mounted) {
          setState(
            () => _stageStatus = 'Tap Eyes-Free Zone Below to Grade Card',
          );
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(l10nProvider);

    return Column(
      children: [
        AdaptiveGlassCard(
          accentBorderColor: AppColors.unseenElectricSky,
          padding: const EdgeInsets.all(18),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.headphones_rounded,
                        color: AppColors.unseenElectricSky,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '100% Offline Commute Audio TTS',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                  FilledButton.tonalIcon(
                    onPressed: _startCommuteAudioCycle,
                    icon: const Icon(Icons.replay_rounded, size: 16),
                    label: const Text('Replay Audio'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                _stageStatus,
                style: AppTypography.monoMetric(
                  fontSize: 13.5,
                  color: AppColors.unseenElectricSky,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Large Full-Screen Eyes-Free Touch Zones for Commute Grading
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => widget.onGradeSelected(FsrsConstants.ratingAgain),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.urgentCrimson.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppColors.urgentCrimson,
                        width: 2,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.refresh_rounded,
                          size: 46,
                          color: AppColors.urgentCrimson,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          l10n.t('grade_again'),
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: AppColors.urgentCrimson,
                          ),
                        ),
                        const Text(
                          'Eyes-Free Left Zone',
                          style: TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: InkWell(
                  onTap: () => widget.onGradeSelected(FsrsConstants.ratingGood),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.masteredEmerald.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppColors.masteredEmerald,
                        width: 2,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.check_circle_rounded,
                          size: 46,
                          color: AppColors.masteredEmerald,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          l10n.t('grade_good'),
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: AppColors.masteredEmerald,
                          ),
                        ),
                        const Text(
                          'Eyes-Free Right Zone',
                          style: TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
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
