/// Builds the deterministic, zero-hallucination pipe-delimited system prompt
/// for the Zero-Cost AI Flashcard Generator Bridge.
/// Instructs free ChatGPT, Claude, Gemini, or local Ollama to output atomic Cloze
/// and Q&A flashcards in the user's chosen language (`bn` বাংলা, `en` English, `tr` Turkish, `ar` Arabic).
class PromptClipboardGenerator {
  PromptClipboardGenerator._();

  static String generateSystemPrompt({
    required String minifiedStudyMaterial,
    required String targetLanguageCode,
    int targetCardCount = 12,
  }) {
    final langInstruction = switch (targetLanguageCode) {
      'bn' => 'Bangla (বাংলা - with accurate scientific terms and LaTeX)',
      'tr' => 'Turkish (Türkçe)',
      'ar' => 'Arabic (العربية)',
      _ => 'English',
    };

    return '''
You are an expert Cognitive Learning Scientist & FSRS-6 Flashcard Architect.
Convert the compressed study material below into $targetCardCount high-yield, atomic flashcards in $langInstruction.

STRICT OUTPUT FORMAT (One flashcard per line, pipe-delimited, NO markdown code fences or extra commentary):
CLOZE | <Sentence with {{c1::key term}} or {{c2::second term}}> | Page <number> | #<tag>
QA | <Concise Question> | <Exact Answer or \$\$LaTeX\$\$ Formula> | Page <number> | #<tag>

EXAMPLES:
CLOZE | The {{c1::Sinoatrial (SA) node}} acts as the natural {{c2::pacemaker}} of the heart. | Page 1 | #cardiology
QA | What is the Reynolds number threshold for turbulent pipe flow? | Re > 4000 | Page 2 | #hydraulics
CLOZE | {{c1::মাইটোকন্ড্রিয়া}} কোষের পাওয়ার হাউস যা {{c2::এটিপি (ATP)}} উৎপাদন করে। | Page 3 | #cell-bio

COMPRESSED SOURCE MATERIAL:
$minifiedStudyMaterial
''';
  }
}
