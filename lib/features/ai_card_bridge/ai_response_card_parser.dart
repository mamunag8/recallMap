import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import '../../core/database/tables.dart';

class ParsedAiFlashcardDraft {
  final String cardType; // 'CLOZE' | 'BASIC'
  final String frontMd;
  final String backMd;
  final int pageNumber;
  final List<String> tags;

  const ParsedAiFlashcardDraft({
    required this.cardType,
    required this.frontMd,
    required this.backMd,
    required this.pageNumber,
    required this.tags,
  });

  CardRecord toCardRecord({
    required String deckId,
    required String? sourceId,
  }) {
    const uuid = Uuid();
    final now = DateTime.now().millisecondsSinceEpoch;
    return CardRecord(
      id: uuid.v4(),
      deckId: deckId,
      sourceId: sourceId,
      sourcePage: pageNumber,
      cardType: cardType,
      frontMd: frontMd,
      backMd: backMd,
      tagsJson: jsonEncode(tags),
      state: 0,
      dueDate: now,
      createdAt: now,
      updatedAt: now,
      contentHash: computeContentHash('$frontMd|$backMd|$pageNumber|$now'),
    );
  }
}

/// Deterministic Pipe-Delimited AI Output Parser + Optional Local Ollama / BYOK Connector.
/// Parses lines formatted as:
/// - `CLOZE | The {{c1::Sinoatrial (SA) node}} acts as the natural {{c2::pacemaker}} of the heart. | Page 14 | #cardiology`
/// - `QA | What is the Reynolds number threshold for turbulent pipe flow? | Re > 4000 | Page 22 | #hydraulics`
class AiResponseCardParser {
  AiResponseCardParser._();

  static List<ParsedAiFlashcardDraft> parseClipboardText(String rawOutput) {
    final drafts = <ParsedAiFlashcardDraft>[];

    for (final rawLine in rawOutput.split('\n')) {
      final line = rawLine.trim();
      if (line.isEmpty || !line.contains('|')) continue;

      final parts = line.split('|').map((s) => s.trim()).toList();
      final prefix = parts.first.toUpperCase();

      if (prefix.contains('CLOZE') && parts.length >= 2) {
        final clozeText = parts[1];
        final pageNum = parts.length >= 3 ? _parsePageNum(parts[2]) : 1;
        final tags = parts.length >= 4 ? _parseTags(parts[3]) : ['#ai-cloze'];
        drafts.add(
          ParsedAiFlashcardDraft(
            cardType: 'CLOZE',
            frontMd: clozeText,
            backMd: 'AI Atomic Cloze (Page $pageNum)',
            pageNumber: pageNum,
            tags: tags,
          ),
        );
      } else if ((prefix.contains('QA') || prefix.contains('BASIC')) &&
          parts.length >= 3) {
        final question = parts[1];
        final answer = parts[2];
        final pageNum = parts.length >= 4 ? _parsePageNum(parts[3]) : 1;
        final tags = parts.length >= 5 ? _parseTags(parts[4]) : ['#ai-qa'];
        drafts.add(
          ParsedAiFlashcardDraft(
            cardType: 'BASIC',
            frontMd: question,
            backMd: answer,
            pageNumber: pageNum,
            tags: tags,
          ),
        );
      }
    }

    return drafts;
  }

  /// Optional Direct Local LLM (Ollama `http://localhost:11434`) generator.
  /// Falls back to a deterministic offline bilingual flashcard batch if local Ollama isn't running.
  static Future<String> generateViaLocalOllamaOrFallback({
    required String ollamaBaseUrl,
    required String modelName,
    required String prompt,
  }) async {
    try {
      final uri = Uri.parse('$ollamaBaseUrl/api/generate');
      final response = await http
          .post(
            uri,
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({
              'model': modelName,
              'prompt': prompt,
              'stream': false,
            }),
          )
          .timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final output = (body['response'] ?? '').toString();
        if (output.contains('|')) return output;
      }
    } catch (_) {}

    // Instant deterministic fallback batch so users can test 1-Tap AI parsing offline
    return '''
CLOZE | The {{c1::Sinoatrial (SA) node}} acts as the natural {{c2::pacemaker}} of the heart. | Page 1 | #cardiology
QA | What is the Reynolds number threshold for turbulent pipe flow? | \$\$Re > 4000\$\$ | Page 2 | #hydraulics
CLOZE | {{c1::বার্নুলির নীতি}} অনুযায়ী প্রবাহীর বেগ বৃদ্ধি পেলে {{c2::স্থির চাপ (Static Pressure)}} হ্রাস পায়। | Page 1 | #hydraulics #bangla
QA | উদ্ভিদের জাইলেম (Xylem) এবং ফ্লোয়েম (Phloem) কলার প্রধান পার্থক্য কী? | জাইলেম মূল থেকে পাতায় একমুখীভাবে পানি ও খনিজ লবণ পরিবহন করে, আর ফ্লোয়েম পাতায় তৈরি খাদ্য উভমুখীভাবে পরিবহন করে। | Page 3 | #cell-bio #bangla
CLOZE | Frictional head loss in a pipe is given by the {{c1::Darcy-Weisbach}} equation: \$\$\\Delta h_f = f \\cdot \\frac{L}{D} \\cdot \\frac{v^2}{2g}\$\$. | Page 2 | #hydraulics
''';
  }

  static int _parsePageNum(String raw) {
    final match = RegExp(r'\d+').firstMatch(raw);
    if (match != null) {
      return int.tryParse(match.group(0)!) ?? 1;
    }
    return 1;
  }

  static List<String> _parseTags(String raw) {
    final tokens = raw
        .split(RegExp(r'[\s,]+'))
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .map((t) => t.startsWith('#') ? t : '#$t')
        .toList();
    return tokens.isEmpty ? const ['#ai-bridge'] : tokens;
  }
}
