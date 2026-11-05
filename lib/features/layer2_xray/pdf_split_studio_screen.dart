import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/database/app_database.dart';
import '../../core/database/tables.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/platform/native_study_bridge.dart';
import '../../shared/widgets/adaptive_glass_card.dart';
import '../../shared/widgets/math_latex_view.dart';
import '../creation_studio/pdf_highlight_to_card.dart';
import '../layer3_inspector/card_deep_inspector_sheet.dart';
import 'concept_recall_graph.dart';
import 'pdf_page_mastery_strip.dart';

/// LAYER 2: The Meso "X-Ray" View (PDF Textbook Studio with Vertical Page Mastery Strip
/// & Interactive 2D Concept RecallMap Graph).
class PdfSplitStudioScreen extends ConsumerStatefulWidget {
  final int? initialPage;
  final ValueChanged<List<CardRecord>>? onStartTargetedStudy;

  const PdfSplitStudioScreen({
    super.key,
    this.initialPage,
    this.onStartTargetedStudy,
  });

  @override
  ConsumerState<PdfSplitStudioScreen> createState() =>
      _PdfSplitStudioScreenState();
}

class _PdfSplitStudioScreenState extends ConsumerState<PdfSplitStudioScreen> {
  int _activePage = 1;
  bool _showConceptGraphView = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialPage != null) {
      _activePage = widget.initialPage!;
    }
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(appDatabaseProvider);
    final l10n = ref.watch(l10nProvider);

    final pdfSources =
        db.sources.where((s) => s.sourceType == 'PDF').toList();
    final activePdf = pdfSources.isNotEmpty
        ? pdfSources.first
        : (db.sources.isNotEmpty ? db.sources.first : null);
    final totalPages = activePdf?.pageCount ?? 3;
    final currentPage = _activePage.clamp(1, totalPages);

    final sourceCards = activePdf == null
        ? db.cards
        : db.cards.where((c) => c.sourceId == activePdf.id).toList();
    final pageCards = sourceCards
        .where((c) => (c.sourcePage ?? 1) == currentPage)
        .toList();

    final pageExtract = BuiltInPdfAndOcrCorpus.extractPage(
      relativePdfPath: activePdf?.relativeFilePath ?? '',
      pageNumber: currentPage,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _showConceptGraphView
              ? l10n.t('visual_map_title')
              : (activePdf?.title ?? l10n.t('page_mastery_strip')),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        actions: [
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(
                value: false,
                icon: Icon(Icons.picture_as_pdf_rounded, size: 16),
                label: Text('PDF + Strip', style: TextStyle(fontSize: 11.5)),
              ),
              ButtonSegment(
                value: true,
                icon: Icon(Icons.hub_rounded, size: 16),
                label: Text('2D Graph', style: TextStyle(fontSize: 11.5)),
              ),
            ],
            selected: {_showConceptGraphView},
            onSelectionChanged: (s) =>
                setState(() => _showConceptGraphView = s.first),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: SafeArea(
        child: _showConceptGraphView
            ? _build2DConceptGraphCanvas(context, db)
            : Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Left / Main Pane: Interactive PDF Reader + 1-Tap Sentence Highlight to Auto-Cloze
                    Expanded(
                      child: ListView(
                        children: [
                          AdaptiveGlassCard(
                            accentBorderColor: AppColors.sourceRoyalIndigo
                                .withValues(alpha: 0.45),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Page $currentPage of $totalPages • Tap any sentence to [Auto-Cloze]',
                                      style: const TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.sourceRoyalIndigo,
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        IconButton(
                                          onPressed: currentPage > 1
                                              ? () => setState(
                                                    () => _activePage--,
                                                  )
                                              : null,
                                          icon: const Icon(
                                            Icons.chevron_left_rounded,
                                          ),
                                        ),
                                        IconButton(
                                          onPressed: currentPage < totalPages
                                              ? () => setState(
                                                    () => _activePage++,
                                                  )
                                              : null,
                                          icon: const Icon(
                                            Icons.chevron_right_rounded,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const Divider(),
                                // Interactive PDF Sentence Blocks with 1-Tap [Auto-Cloze]
                                ...pageExtract.sentenceBlocks.map((block) {
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 10),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: AppColors.sourceRoyalIndigo
                                          .withValues(alpha: 0.07),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: AppColors.sourceRoyalIndigo
                                            .withValues(alpha: 0.25),
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          block.label,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyLarge,
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.end,
                                          children: [
                                            FilledButton.tonalIcon(
                                              onPressed: () async {
                                                final card =
                                                    await PdfHighlightToCard
                                                        .createAutoClozeFromHighlight(
                                                  db: db,
                                                  deckId: activePdf?.deckId ??
                                                      db.decks.first.id,
                                                  sourceId: activePdf?.id,
                                                  pageNumber: currentPage,
                                                  highlightedSentence:
                                                      block.label,
                                                  boundingRect: block,
                                                );
                                                if (context.mounted) {
                                                  ScaffoldMessenger.of(context)
                                                      .showSnackBar(
                                                    SnackBar(
                                                      content: Text(
                                                        'Created Auto-Cloze card tethered to Page $currentPage!',
                                                      ),
                                                      action: SnackBarAction(
                                                        label: 'Inspect DSR',
                                                        onPressed: () {
                                                          CardDeepInspectorSheet
                                                              .show(
                                                            context,
                                                            card: card,
                                                          );
                                                        },
                                                      ),
                                                    ),
                                                  );
                                                }
                                              },
                                              icon: const Icon(
                                                Icons.auto_fix_high_rounded,
                                                size: 14,
                                              ),
                                              label: const Text(
                                                '[Auto-Cloze]',
                                                style:
                                                    TextStyle(fontSize: 11.5),
                                              ),
                                              style: FilledButton.styleFrom(
                                                visualDensity:
                                                    VisualDensity.compact,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),

                          // Tethered Cards Extracted from This Page
                          Text(
                            'Cards Tethered to Page $currentPage (${pageCards.length})',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          ...pageCards.map((card) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: AdaptiveGlassCard(
                                onTap: () => CardDeepInspectorSheet.show(
                                  context,
                                  card: card,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          '${card.cardType} • S: ${card.stability.toStringAsFixed(1)}d • D: ${card.difficulty.toStringAsFixed(1)}',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.unseenElectricSky,
                                          ),
                                        ),
                                        const Icon(
                                          Icons.insights_rounded,
                                          size: 16,
                                          color: AppColors.masteredEmerald,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    MathLatexView(
                                      markdownWithLatex: card.frontMd,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Right Edge: The Visual PDF Page Mastery Strip
                    PdfPageMasteryStrip(
                      totalPages: totalPages,
                      currentPage: currentPage,
                      sourceCards: sourceCards,
                      onSelectPage: (page) =>
                          setState(() => _activePage = page),
                      onStudyWeakPages: (weakPages) {
                        final weakCards = sourceCards
                            .where(
                              (c) => weakPages.contains(c.sourcePage ?? 1),
                            )
                            .toList();
                        setState(() => _activePage = weakPages.first);
                        widget.onStartTargetedStudy?.call(weakCards);
                      },
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _build2DConceptGraphCanvas(BuildContext context, AppDatabase db) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          AdaptiveGlassCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: AppColors.urgentCrimson,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    '60fps Force-Directed Concept RecallMap • Crimson Pulsing Nodes = Bottleneck Concepts (R < 80%). Drag or tap any node to inspect DSR curve.',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: AdaptiveGlassCard(
              padding: EdgeInsets.zero,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: ConceptRecallGraph(
                  sources: db.sources,
                  cards: db.cards,
                  edges: db.edges,
                  onCardNodeTap: (card) {
                    CardDeepInspectorSheet.show(
                      context,
                      card: card,
                      onJumpToFullPdfPage: () {
                        setState(() {
                          _showConceptGraphView = false;
                          _activePage = card.sourcePage ?? 1;
                        });
                      },
                    );
                  },
                  onSourceNodeTap: (src) {
                    if (src.sourceType == 'PDF') {
                      setState(() => _showConceptGraphView = false);
                    }
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
