import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/database/tables.dart';
import '../../core/platform/native_study_bridge.dart';
import '../../shared/widgets/adaptive_glass_card.dart';

/// LAYER 3 (Visual 2): Contextual Source Split-View (Zero Orphaned Cards).
/// Displays the exact highlighted PDF textbook snippet or parent Concept Note
/// tethered to `(source_id, source_page, source_rect_json)` with a 1-tap
/// "Jump to Full PDF Page X" button.
class SourceContextPreview extends ConsumerWidget {
  final CardRecord card;
  final StudySourceRecord? source;
  final VoidCallback? onJumpToFullPdfPage;

  const SourceContextPreview({
    super.key,
    required this.card,
    required this.source,
    this.onJumpToFullPdfPage,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pageNum = card.sourcePage ?? 1;
    final pageExtract = BuiltInPdfAndOcrCorpus.extractPage(
      relativePdfPath: source?.relativeFilePath ?? '',
      pageNumber: pageNum,
    );

    return AdaptiveGlassCard(
      accentBorderColor: AppColors.sourceRoyalIndigo.withValues(alpha: 0.5),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.picture_as_pdf_rounded,
                size: 18,
                color: AppColors.sourceRoyalIndigo,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  source != null
                      ? '${source!.title} • Page $pageNum'
                      : 'Tethered Source Context • Page $pageNum',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.sourceRoyalIndigo,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (onJumpToFullPdfPage != null)
                FilledButton.tonalIcon(
                  onPressed: onJumpToFullPdfPage,
                  icon: const Icon(Icons.open_in_new_rounded, size: 14),
                  label: Text(
                    'Jump to Full PDF Page $pageNum',
                    style: const TextStyle(fontSize: 11),
                  ),
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.sourceRoyalIndigo.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: AppColors.sourceRoyalIndigo.withValues(alpha: 0.3),
              ),
            ),
            child: Text(
              source?.sourceType == 'CONCEPT_NOTE'
                  ? source!.markdownBody
                  : pageExtract.fullText,
              style: Theme.of(context).textTheme.bodyMedium,
              maxLines: 5,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
