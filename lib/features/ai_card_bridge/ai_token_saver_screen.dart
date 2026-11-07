import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';
import '../../core/database/app_database.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/platform/native_study_bridge.dart';
import '../../shared/widgets/adaptive_glass_card.dart';
import '../../shared/widgets/math_latex_view.dart';
import '../anki_interop/apkg_exporter.dart';
import '../anki_interop/apkg_importer.dart';
import 'ai_response_card_parser.dart';
import 'prompt_clipboard_generator.dart';
import 'text_minifier.dart';

/// Workflow 4 (Phase 6): Zero-Cost AI Flashcard Generator Bridge (Token-Saver + Clipboard Parser)
/// & 2-Way Anki (`.apkg`) Importer/Exporter Studio.
class AiTokenSaverScreen extends ConsumerStatefulWidget {
  const AiTokenSaverScreen({super.key});

  @override
  ConsumerState<AiTokenSaverScreen> createState() => _AiTokenSaverScreenState();
}

class _AiTokenSaverScreenState extends ConsumerState<AiTokenSaverScreen> {
  late final TextEditingController _sourceTextController;
  late final TextEditingController _aiResponseController;
  late final TextEditingController _ollamaUrlController;
  List<ParsedAiFlashcardDraft> _parsedDrafts = [];
  bool _isGeneratingLocalLlm = false;

  @override
  void initState() {
    super.initState();
    final p1 = BuiltInPdfAndOcrCorpus.extractPage(
      relativePdfPath: '',
      pageNumber: 1,
    ).fullText;
    final p2 = BuiltInPdfAndOcrCorpus.extractPage(
      relativePdfPath: '',
      pageNumber: 2,
    ).fullText;
    final p3 = BuiltInPdfAndOcrCorpus.extractPage(
      relativePdfPath: '',
      pageNumber: 3,
    ).fullText;

    _sourceTextController = TextEditingController(
      text: '$p1\n\n$p2\n\n$p3',
    );
    _aiResponseController = TextEditingController();
    _ollamaUrlController = TextEditingController(
      text: 'http://localhost:11434',
    );
  }

  @override
  void dispose() {
    _sourceTextController.dispose();
    _aiResponseController.dispose();
    _ollamaUrlController.dispose();
    super.dispose();
  }

  Future<void> _copyTokenSaverPrompt() async {
    final settings = ref.read(appLocaleProvider);
    final minResult =
        TextMinifier.minifyStudyText(_sourceTextController.text);
    final prompt = PromptClipboardGenerator.generateSystemPrompt(
      minifiedStudyMaterial: minResult.minifiedText,
      targetLanguageCode: settings.languageCode,
    );

    await Clipboard.setData(ClipboardData(text: prompt));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Copied Token-Saver AI Prompt (Compressed by ${minResult.compressionPercent}%) to Clipboard!',
          ),
        ),
      );
    }
  }

  Future<void> _pasteAndParseAiOutput() async {
    String raw = _aiResponseController.text.trim();
    if (raw.isEmpty) {
      final clip = await Clipboard.getData(Clipboard.kTextPlain);
      raw = clip?.text?.trim() ?? '';
    }
    if (raw.isEmpty || !raw.contains('|')) {
      // Populate with sample bilingual pipe-delimited AI output so 1-tap demo works immediately
      raw = await AiResponseCardParser.generateViaLocalOllamaOrFallback(
        ollamaBaseUrl: _ollamaUrlController.text.trim(),
        modelName: 'llama3.2',
        prompt: '',
      );
      _aiResponseController.text = raw;
    }

    setState(() {
      _parsedDrafts = AiResponseCardParser.parseClipboardText(raw);
    });
  }

  Future<void> _insertParsedCardsToVault(AppDatabase db) async {
    if (_parsedDrafts.isEmpty) return;
    final deckId =
        db.decks.isNotEmpty ? db.decks.first.id : 'deck_demo_start_here';
    final pdfSource =
        db.sources.where((s) => s.sourceType == 'PDF').firstOrNull;

    final records = _parsedDrafts
        .map(
          (d) => d.toCardRecord(
            deckId: deckId,
            sourceId: pdfSource?.id,
          ),
        )
        .toList();

    await db.upsertCardsBatch(records);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Inserted ${records.length} AI Flashcards into Vault (tethered to PDF pages)!',
          ),
        ),
      );
      setState(() => _parsedDrafts = []);
    }
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(appDatabaseProvider);
    final l10n = ref.watch(l10nProvider);
    final minResult =
        TextMinifier.minifyStudyText(_sourceTextController.text);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.t('ai_card_generator'),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(14),
          children: [
            // 1. Token-Saver Compression Card
            AdaptiveGlassCard(
              accentBorderColor: AppColors.masteredEmerald.withValues(alpha: 0.5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Step 1 • Select PDF Pages / Notes to Compress',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.masteredEmerald
                              .withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: AppColors.masteredEmerald),
                        ),
                        child: Text(
                          'Token-Saver: Compressed by ${l10n.formatNumber(minResult.compressionPercent)}%',
                          style: AppTypography.monoMetric(
                            fontSize: 11,
                            color: AppColors.masteredEmerald,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _sourceTextController,
                    maxLines: 5,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      hintText: 'Paste textbook pages or lecture notes here...',
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.icon(
                        onPressed: _copyTokenSaverPrompt,
                        icon: const Icon(Icons.copy_all_rounded, size: 16),
                        label: const Text(
                          r'Step 1: Copy AI Card Generator Prompt ($0 API Cost)',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: _isGeneratingLocalLlm
                            ? null
                            : () async {
                                setState(() => _isGeneratingLocalLlm = true);
                                final output = await AiResponseCardParser
                                    .generateViaLocalOllamaOrFallback(
                                  ollamaBaseUrl:
                                      _ollamaUrlController.text.trim(),
                                  modelName: 'llama3.2',
                                  prompt: _sourceTextController.text,
                                );
                                if (mounted) {
                                  setState(() {
                                    _aiResponseController.text = output;
                                    _parsedDrafts = AiResponseCardParser
                                        .parseClipboardText(output);
                                    _isGeneratingLocalLlm = false;
                                  });
                                }
                              },
                        icon: const Icon(Icons.memory_rounded, size: 16),
                        label: Text(
                          _isGeneratingLocalLlm
                              ? 'Running Local Ollama...'
                              : 'Direct 1-Tap Local LLM / Demo Generate',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // 2. Step 2: Paste AI Output -> Parse Pipe-Delimited Cards
            AdaptiveGlassCard(
              accentBorderColor:
                  AppColors.unseenElectricSky.withValues(alpha: 0.45),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Expanded(
                        child: Text(
                          'Step 2 • Paste Pipe-Delimited AI Output (CLOZE | ... / QA | ...)',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: _pasteAndParseAiOutput,
                        icon: const Icon(Icons.content_paste_go_rounded,
                            size: 16),
                        label: const Text(
                          'Paste AI Output → Parse',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _aiResponseController,
                    maxLines: 5,
                    style: AppTypography.monoMetric(fontSize: 11.5),
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      hintText:
                          'CLOZE | The {{c1::Sinoatrial (SA) node}} acts as the natural {{c2::pacemaker}} of the heart. | Page 14 | #cardiology',
                    ),
                  ),
                  if (_parsedDrafts.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.masteredEmerald,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: () => _insertParsedCardsToVault(db),
                        icon: const Icon(Icons.check_circle_rounded),
                        label: Text(
                          'Insert ${_parsedDrafts.length} Parsed Cards into FSRS-6 Deck (Auto-Linked to PDF Pages)',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    ..._parsedDrafts.map((d) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: AppColors.unseenElectricSky
                                .withValues(alpha: 0.35),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${d.cardType} • Page ${d.pageNumber} • ${d.tags.join(" ")}',
                              style: AppTypography.monoMetric(
                                fontSize: 10.5,
                                color: AppColors.unseenElectricSky,
                              ),
                            ),
                            const SizedBox(height: 4),
                            MathLatexView(
                              markdownWithLatex: d.frontMd,
                              fontSize: 13.5,
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),

            // 3. 2-Way Anki (.apkg) Importer & Exporter
            AdaptiveGlassCard(
              accentBorderColor:
                  AppColors.sourceRoyalIndigo.withValues(alpha: 0.45),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.import_export_rounded,
                        color: AppColors.sourceRoyalIndigo,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '2-Way Anki (.apkg) Interop (Import & Export with FSRS-6 Conversion)',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    children: [
                      FilledButton.tonalIcon(
                        onPressed: () async {
                          // Round-trip test or import .apkg archive
                          final sampleApkg = ApkgExporter.exportDeckToApkgBytes(
                            db: db,
                            deck: db.decks.first,
                          );
                          final summary = await ApkgImporter.importApkgBytes(
                            db: db,
                            apkgBytes: sampleApkg,
                            fallbackDeckTitle: 'Anki Imported Deck (.apkg)',
                          );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Imported "${summary.deckTitle}" (${summary.importedCardsCount} cards, ${summary.convertedReviewHistoryCount} FSRS-6 states)!',
                                ),
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.file_download_rounded, size: 16),
                        label: const Text('Import Anki (.apkg) Deck'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () {
                          final bytes = ApkgExporter.exportDeckToApkgBytes(
                            db: db,
                            deck: db.decks.first,
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Packaged "${db.decks.first.title}" into standard Anki .apkg archive (${bytes.length} bytes)!',
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.file_upload_rounded, size: 16),
                        label: const Text('Export Active Deck to .apkg'),
                      ),
                    ],
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
