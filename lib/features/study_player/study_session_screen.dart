import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/fsrs_constants.dart';
import '../../core/database/app_database.dart';
import '../../core/database/tables.dart';
import '../../core/i18n/app_localizations.dart';
import '../fsrs_engine/fsrs_v6_scheduler.dart';
import '../fsrs_engine/memory_doctor_analyzer.dart';
import '../layer3_inspector/card_deep_inspector_sheet.dart';
import 'audio_commute_player.dart';
import 'boss_battle_quiz_mode.dart';
import 'gesture_card_stack.dart';
import 'transparent_scratchpad.dart';

enum StudyPlayerMode {
  standardFsrs,
  bossBattleBlitz,
  audioCommuteTts,
}

/// Unified Multi-Sensory Active Recall Study Player Screen (Phase 5).
/// Prioritizes lowest Retrievability `R(t, S)` cards first and supports:
/// 1. One-handed 4-way thumb gestures + live FSRS-6 interval bar
/// 2. Transparent Stylus & Finger Scratchpad Overlay (`✏️ Scratchpad`)
/// 3. Native Offline LaTeX (`$$...$$`) & Cloze rendering
/// 4. 5-Minute "Boss Battle" Speed Quiz Mode
/// 5. Hands-Free Commute Audio Mode (100% Offline TTS in `bn-BD`, `en-US`, `tr-TR`, `ar-SA`)
class StudySessionScreen extends ConsumerStatefulWidget {
  const StudySessionScreen({super.key});

  @override
  ConsumerState<StudySessionScreen> createState() => _StudySessionScreenState();
}

class _StudySessionScreenState extends ConsumerState<StudySessionScreen> {
  StudyPlayerMode _mode = StudyPlayerMode.standardFsrs;
  bool _showScratchpadOverlay = false;
  int _sessionIndex = 0;

  List<CardRecord> _buildHighYieldQueue(AppDatabase db) {
    const scheduler = FsrsV6Scheduler();
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final candidates = db.cards.where((c) => !c.isSuspended).toList();

    // Sort ascending by live Retrievability R(t, S) so fragile memories are studied first
    candidates.sort((a, b) {
      final rA = a.state == FsrsConstants.stateNew
          ? 0.75
          : scheduler.liveRetrievabilityForCard(a, nowMs: nowMs);
      final rB = b.state == FsrsConstants.stateNew
          ? 0.75
          : scheduler.liveRetrievabilityForCard(b, nowMs: nowMs);
      return rA.compareTo(rB);
    });
    return candidates;
  }

  Future<void> _gradeCard(
    AppDatabase db,
    CardRecord card,
    int rating,
  ) async {
    final deck = db.getDeckById(card.deckId);
    final scheduler = FsrsV6Scheduler.forDeck(deck);
    final outcome = scheduler.reviewCard(
      card: card,
      rating: rating,
    );

    await db.upsertCard(outcome.updatedCard);
    await db.insertReviewLog(outcome.reviewLog);

    if (mounted) {
      setState(() {
        _sessionIndex++;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(appDatabaseProvider);
    final l10n = ref.watch(l10nProvider);
    final queue = _buildHighYieldQueue(db);

    if (queue.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.t('nav_study'))),
        body: const Center(
          child: Text('All cards reviewed! Your memory vault is 100% synced.'),
        ),
      );
    }

    final activeCard = queue[_sessionIndex % queue.length];
    final deck = db.getDeckById(activeCard.deckId);
    final scheduler = FsrsV6Scheduler.forDeck(deck);
    final ratingPreviews = scheduler.previewAllRatings(activeCard);

    return Scaffold(
      appBar: AppBar(
        title: SegmentedButton<StudyPlayerMode>(
          segments: const [
            ButtonSegment(
              value: StudyPlayerMode.standardFsrs,
              icon: Icon(Icons.style_rounded, size: 15),
              label: Text('FSRS-6', style: TextStyle(fontSize: 11)),
            ),
            ButtonSegment(
              value: StudyPlayerMode.bossBattleBlitz,
              icon: Icon(Icons.bolt_rounded, size: 15),
              label: Text('Boss Battle', style: TextStyle(fontSize: 11)),
            ),
            ButtonSegment(
              value: StudyPlayerMode.audioCommuteTts,
              icon: Icon(Icons.headphones_rounded, size: 15),
              label: Text('Commute TTS', style: TextStyle(fontSize: 11)),
            ),
          ],
          selected: {_mode},
          onSelectionChanged: (s) => setState(() => _mode = s.first),
        ),
        actions: [
          IconButton(
            tooltip: '✏️ Toggle Transparent Scratchpad Overlay',
            onPressed: () => setState(
              () => _showScratchpadOverlay = !_showScratchpadOverlay,
            ),
            icon: Icon(
              Icons.draw_rounded,
              color: _showScratchpadOverlay
                  ? AppColors.masteredEmerald
                  : AppColors.unseenElectricSky,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(14),
              child: switch (_mode) {
                StudyPlayerMode.standardFsrs => GestureCardStack(
                    card: activeCard,
                    ratingPreviews: ratingPreviews,
                    onGradeSelected: (rating) =>
                        _gradeCard(db, activeCard, rating),
                    onInspectLayer3: () => CardDeepInspectorSheet.show(
                      context,
                      card: activeCard,
                    ),
                  ),
                StudyPlayerMode.bossBattleBlitz => BossBattleQuizMode(
                    cards: queue,
                    onCardGraded: (card, rating) =>
                        _gradeCard(db, card, rating),
                  ),
                StudyPlayerMode.audioCommuteTts => AudioCommutePlayer(
                    card: activeCard,
                    onGradeSelected: (rating) =>
                        _gradeCard(db, activeCard, rating),
                  ),
              },
            ),

            // Transparent Stylus & Finger Scratchpad Overlay
            if (_showScratchpadOverlay)
              Positioned.fill(
                child: TransparentScratchpad(
                  onClose: () =>
                      setState(() => _showScratchpadOverlay = false),
                  onSaveMnemonicSketch: (strokes) async {
                    await MemoryDoctorAnalyzer.attachMnemonicSketch(
                      db: db,
                      card: activeCard,
                      strokes: strokes,
                    );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Pinned visual mnemonic sketch to card!',
                          ),
                        ),
                      );
                    }
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
