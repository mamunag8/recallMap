import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';
import '../../core/database/app_database.dart';
import '../../core/database/tables.dart';
import '../../core/i18n/app_localizations.dart';
import '../../shared/widgets/adaptive_glass_card.dart';
import '../../shared/widgets/math_latex_view.dart';
import 'auto_ocr_occlusion_studio.dart';
import 'wiki_concept_linker.dart';

/// Parsed inline flashcard descriptor from a `Concept :: Definition` or `Question ?? Answer` line.
class ParsedInlineDescriptor {
  final String front;
  final String back;
  final String delimiter; // '::' or '??'

  const ParsedInlineDescriptor({
    required this.front,
    required this.back,
    required this.delimiter,
  });
}

/// Workflow 3: RemNote/Obsidian-Style Inline `::` Concept Outliner +
/// Unified Creation Studio Screen (combining Auto-OCR Diagram Studio & Inline Outliner).
class InlineOutlinerEditor extends ConsumerStatefulWidget {
  const InlineOutlinerEditor({super.key});

  /// Parses all `Concept :: Definition` and `Question ?? Answer` lines in a Markdown document.
  static List<ParsedInlineDescriptor> parseInlineCards(String markdown) {
    final results = <ParsedInlineDescriptor>[];
    for (final rawLine in markdown.split('\n')) {
      final line = rawLine.trim();
      if (line.isEmpty || line.startsWith('#')) continue;

      if (line.contains(' :: ')) {
        final parts = line.split(' :: ');
        final front = parts.first.replaceFirst(RegExp(r'^[-*•]\s*'), '').trim();
        final back = parts.sublist(1).join(' :: ').trim();
        if (front.isNotEmpty && back.isNotEmpty) {
          results.add(
            ParsedInlineDescriptor(
              front: front,
              back: back,
              delimiter: '::',
            ),
          );
        }
      } else if (line.contains(' ?? ')) {
        final parts = line.split(' ?? ');
        final front = parts.first.replaceFirst(RegExp(r'^[-*•]\s*'), '').trim();
        final back = parts.sublist(1).join(' ?? ').trim();
        if (front.isNotEmpty && back.isNotEmpty) {
          results.add(
            ParsedInlineDescriptor(
              front: front,
              back: back,
              delimiter: '??',
            ),
          );
        }
      }
    }
    return results;
  }

  @override
  ConsumerState<InlineOutlinerEditor> createState() =>
      _InlineOutlinerEditorState();
}

class _InlineOutlinerEditorState extends ConsumerState<InlineOutlinerEditor> {
  static const Uuid _uuid = Uuid();
  int _activeCreationTab = 0; // 0 = Auto-OCR Diagram Studio, 1 = Inline :: Outliner
  late final TextEditingController _noteController;
  bool _showWikiAutocomplete = false;

  @override
  void initState() {
    super.initState();
    _noteController = TextEditingController(
      text:
          '# Hydraulics & Bioenergetics Outliner\n'
          'Linked to [[Fluid Mechanics & Cellular Biology Crash Guide.pdf]] and [[Vascular & Cellular Auto-OCR Diagram]]\n\n'
          '- Bernoulli Principle :: Increase in fluid speed occurs simultaneously with a decrease in static pressure\n'
          '- Darcy-Weisbach Equation :: \$\$\\Delta h_f = f \\cdot \\frac{L}{D} \\cdot \\frac{v^2}{2g}\$\$\n'
          '- গতিশক্তি :: \$\$E_k = \\frac{1}{2}mv^2\$\$\n'
          '- মাইটোকন্ড্রিয়া :: কোষের পাওয়ার হাউস যা এটিপি (ATP) উৎপাদন করে\n'
          '- What is the Reynolds number threshold for turbulent pipe flow? ?? \$\$Re > 4000\$\$\n',
    );
    _noteController.addListener(() {
      final text = _noteController.text;
      final shouldShow = text.endsWith('[[');
      if (shouldShow != _showWikiAutocomplete) {
        setState(() => _showWikiAutocomplete = shouldShow);
      } else {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  void _insertToken(String token) {
    final text = _noteController.text;
    final selection = _noteController.selection;
    final pos = selection.isValid ? selection.baseOffset : text.length;
    final updated = text.substring(0, pos) + token + text.substring(pos);
    _noteController.value = TextEditingValue(
      text: updated,
      selection: TextSelection.collapsed(offset: pos + token.length),
    );
  }

  Future<void> _compileInlineCardsToVault(AppDatabase db) async {
    final descriptors =
        InlineOutlinerEditor.parseInlineCards(_noteController.text);
    if (descriptors.isEmpty) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    final deckId =
        db.decks.isNotEmpty ? db.decks.first.id : 'deck_demo_start_here';

    final noteSource = StudySourceRecord(
      id: 'src_demo_concept_note',
      deckId: deckId,
      sourceType: 'CONCEPT_NOTE',
      title: 'Hydraulics & Bioenergetics Synthesis Note',
      markdownBody: _noteController.text,
      updatedAt: now,
      contentHash: computeContentHash(_noteController.text),
    );
    await db.upsertStudySource(noteSource);
    await WikiConceptLinker.syncWikiEdges(db: db, source: noteSource);

    final batch = descriptors.map((d) {
      return CardRecord(
        id: _uuid.v4(),
        deckId: deckId,
        sourceId: noteSource.id,
        sourcePage: 1,
        cardType: 'INLINE_NOTE',
        frontMd: d.front,
        backMd: d.back,
        tagsJson: jsonEncode(['#inline-outliner', '#bangla']),
        state: 0,
        dueDate: now,
        createdAt: now,
        updatedAt: now,
        contentHash: computeContentHash('${d.front}|${d.back}|$now'),
      );
    }).toList();

    await db.upsertCardsBatch(batch);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Compiled ${batch.length} live :: flashcards & [[Wiki-Links]] into FSRS-6 Vault!',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(appDatabaseProvider);
    final l10n = ref.watch(l10nProvider);
    final parsedCards =
        InlineOutlinerEditor.parseInlineCards(_noteController.text);
    final wikiLinks =
        WikiConceptLinker.extractWikiLinkTitles(_noteController.text);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.t('nav_create'),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        actions: [
          SegmentedButton<int>(
            segments: [
              ButtonSegment(
                value: 0,
                icon: const Icon(Icons.document_scanner_rounded, size: 16),
                label: Text(
                  l10n.t('auto_ocr_mask'),
                  style: const TextStyle(fontSize: 11),
                ),
              ),
              ButtonSegment(
                value: 1,
                icon: const Icon(Icons.notes_rounded, size: 16),
                label: Text(
                  l10n.t('inline_outliner'),
                  style: const TextStyle(fontSize: 11),
                ),
              ),
            ],
            selected: {_activeCreationTab},
            onSelectionChanged: (s) =>
                setState(() => _activeCreationTab = s.first),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: SafeArea(
        child: _activeCreationTab == 0
            ? const AutoOcrOcclusionStudio()
            : ListView(
                padding: const EdgeInsets.all(14),
                children: [
                  // Floating Outliner Syntax Toolbar
                  AdaptiveGlassCard(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        ActionChip(
                          onPressed: () => _insertToken('[[Concept]]'),
                          label: const Text('[[Concept Link]]'),
                        ),
                        ActionChip(
                          onPressed: () => _insertToken(' :: '),
                          label: const Text(':: Flashcard'),
                        ),
                        ActionChip(
                          onPressed: () => _insertToken(' ?? '),
                          label: const Text('?? Q&A'),
                        ),
                        ActionChip(
                          onPressed: () => _insertToken('{{c1::answer}}'),
                          label: const Text('{{Cloze}}'),
                        ),
                        ActionChip(
                          onPressed: () => _insertToken(r'$$\Delta h_f$$'),
                          label: const Text(r'LaTeX $$'),
                        ),
                        FilledButton.icon(
                          onPressed: () => _compileInlineCardsToVault(db),
                          icon: const Icon(Icons.bolt_rounded, size: 16),
                          label: Text(
                            'Compile ${parsedCards.length} Live :: Cards',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Autocomplete Popup when typing `[[`
                  if (_showWikiAutocomplete)
                    AdaptiveGlassCard(
                      accentBorderColor: AppColors.sourceRoyalIndigo,
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(10),
                      child: Wrap(
                        spacing: 8,
                        children: WikiConceptLinker.suggestConceptTargets(
                                db, '')
                            .map((target) {
                          return ActionChip(
                            label: Text('[[$target]]'),
                            onPressed: () {
                              _insertToken('$target]]');
                              setState(() => _showWikiAutocomplete = false);
                            },
                          );
                        }).toList(),
                      ),
                    ),

                  // Distraction-Free Markdown Outliner Editor
                  AdaptiveGlassCard(
                    child: TextField(
                      controller: _noteController,
                      maxLines: 10,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.5,
                        fontFamilyFallback:
                            AppTypography.universalFontFallbacks,
                      ),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText:
                            'Type Concept :: Definition or Question ?? Answer...',
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Live Compiled `::` & `??` Flashcards Preview
                  Text(
                    'Live Compiled FSRS-6 Cards (${parsedCards.length})',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  ...parsedCards.map((item) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: AdaptiveGlassCard(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.masteredEmerald
                                    .withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                item.delimiter,
                                style: AppTypography.monoMetric(
                                  fontSize: 12,
                                  color: AppColors.masteredEmerald,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  MathLatexView(
                                    markdownWithLatex: item.front,
                                    fontSize: 13.5,
                                  ),
                                  const SizedBox(height: 4),
                                  MathLatexView(
                                    markdownWithLatex: item.back,
                                    fontSize: 13,
                                    textColor: AppColors.unseenElectricSky,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),

                  // Collapsible Connected Backlinks Tray
                  const SizedBox(height: 8),
                  AdaptiveGlassCard(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.link_rounded,
                              size: 16,
                              color: AppColors.sourceRoyalIndigo,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Bidirectional [[Concept Links]] & Connected Backlinks (${wikiLinks.length})',
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.sourceRoyalIndigo,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: wikiLinks.map((link) {
                            return Chip(
                              visualDensity: VisualDensity.compact,
                              label: Text(
                                '[[$link]]',
                                style: const TextStyle(fontSize: 11.5),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
