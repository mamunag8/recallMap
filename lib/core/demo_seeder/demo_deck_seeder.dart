import 'dart:convert';
import '../database/app_database.dart';
import '../database/tables.dart';

/// Pre-loads the Interactive Starter Demo Deck (`"📌 Start Here / শুরু করুন"`)
/// on first launch so every visualization (91% Exam Readiness Ring, Mastery Bubble/Sunburst Map,
/// PDF Page Mastery Strip, 2D Concept RecallMap, DSR Forgetting Curve, and Memory Doctor Clinic)
/// is populated immediately.
class DemoDeckSeeder {
  DemoDeckSeeder._();

  static const String rootDeckId = 'deck_demo_start_here';
  static const String subDeckHydraulicsId = 'deck_demo_hydraulics';
  static const String subDeckCellBioId = 'deck_demo_cell_bio';
  static const String subDeckCardioId = 'deck_demo_cardio';

  static const String samplePdfSourceId = 'src_demo_pdf_crash_guide';
  static const String sampleConceptNoteSourceId = 'src_demo_concept_note';
  static const String sampleDiagramSourceId = 'src_demo_ocr_diagram';

  static void seedInitialDemoVault(AppDatabase db) {
    final now = DateTime.now().millisecondsSinceEpoch;
    const dayMs = 86400 * 1000;

    // 1. Hierarchical Decks with Exam Target 14 Days Ahead
    final decks = <DeckRecord>[
      DeckRecord(
        id: rootDeckId,
        parentId: null,
        title: '📌 Start Here / শুরু করুন',
        description:
            'Interactive bilingual FSRS-6 demo vault (English & বাংলা) with PDF Page Mastery Strip & Auto-OCR.',
        languageCode: 'bn',
        colorHex: '#6366F1',
        iconName: 'auto_awesome',
        examDate: now + 14 * dayMs,
        targetRetention: 0.90,
        dailyNewLimit: 25,
        isDemoData: true,
        createdAt: now - 45 * dayMs,
        updatedAt: now,
        contentHash: computeContentHash('demo_root_deck'),
      ),
      DeckRecord(
        id: subDeckHydraulicsId,
        parentId: rootDeckId,
        title: 'Engineering::Hydraulics::Pipe_Flow',
        description: 'Bernoulli, Continuity, Reynolds Number & Darcy-Weisbach Head Loss',
        languageCode: 'en',
        colorHex: '#10B981', // Mastered Emerald cluster
        iconName: 'water_drop',
        examDate: now + 14 * dayMs,
        targetRetention: 0.92,
        dailyNewLimit: 20,
        isDemoData: true,
        createdAt: now - 40 * dayMs,
        updatedAt: now,
        contentHash: computeContentHash('demo_hydraulics_deck'),
      ),
      DeckRecord(
        id: subDeckCellBioId,
        parentId: rootDeckId,
        title: 'Biology::কোষীয় জীববিজ্ঞান (Cell Bio)',
        description: 'মাইটোকন্ড্রিয়া, এটিপি (ATP), জাইলেম ও ফ্লোয়েম পরিবহন',
        languageCode: 'bn',
        colorHex: '#EF4444', // Contains Urgent / Leech + Confusable Twin
        iconName: 'biotech',
        examDate: now + 10 * dayMs,
        targetRetention: 0.91,
        dailyNewLimit: 20,
        isDemoData: true,
        createdAt: now - 35 * dayMs,
        updatedAt: now,
        contentHash: computeContentHash('demo_cell_bio_deck'),
      ),
      DeckRecord(
        id: subDeckCardioId,
        parentId: rootDeckId,
        title: 'Medical::Cardiac_Electrophysiology',
        description: 'SA Node, AV Node & Action Potential Stabilization',
        languageCode: 'en',
        colorHex: '#F59E0B', // Stabilizing Amber cluster
        iconName: 'favorite',
        examDate: now + 18 * dayMs,
        targetRetention: 0.90,
        dailyNewLimit: 15,
        isDemoData: true,
        createdAt: now - 20 * dayMs,
        updatedAt: now,
        contentHash: computeContentHash('demo_cardio_deck'),
      ),
    ];

    // 2. Study Sources: 3-Page Study PDF, Concept Note with [[Wiki-Links]] & `::` cards, and Diagram Image
    final sources = <StudySourceRecord>[
      StudySourceRecord(
        id: samplePdfSourceId,
        deckId: rootDeckId,
        sourceType: 'PDF',
        title: 'Fluid Mechanics & Cellular Biology Crash Guide.pdf',
        markdownBody:
            'Page 1 (Emerald R=95%): Continuity Equation A₁v₁ = A₂v₂ & Bernoulli Principle.\n'
            'Page 2 (Amber R=85%): Reynolds Number turbulent threshold Re > 4000 & Darcy-Weisbach Head Loss.\n'
            'Page 3 (Crimson R=68%): Mitochondria ATP oxidative phosphorylation & Xylem (জাইলেম) vs Phloem (ফ্লোয়েম) vascular transport.',
        relativeFilePath:
            'RecallMap_Vault/Sources/Fluid_Mechanics_Cellular_Biology_Crash_Guide.pdf',
        pageCount: 3,
        lastReadPage: 1,
        tagsJson: jsonEncode(['#hydraulics', '#cell-bio', '#crash-guide']),
        graphX: 0.28,
        graphY: 0.35,
        isDemoData: true,
        updatedAt: now,
        contentHash: computeContentHash('demo_pdf_crash_guide'),
      ),
      StudySourceRecord(
        id: sampleConceptNoteSourceId,
        deckId: rootDeckId,
        sourceType: 'CONCEPT_NOTE',
        title: 'Hydraulics & Bioenergetics Synthesis Note',
        markdownBody:
            '# Core Equations & Bilingual Synthesis\n'
            'Connected to [[Fluid Mechanics & Cellular Biology Crash Guide.pdf]] and [[Vascular & Cellular Auto-OCR Diagram]].\n\n'
            'Darcy-Weisbach Equation :: \\Delta h_f = f \\cdot \\frac{L}{D} \\cdot \\frac{v^2}{2g}\n'
            'মাইটোকন্ড্রিয়া :: কোষের পাওয়ার হাউস যা এটিপি (ATP) উৎপাদন করে\n'
            'গতিশক্তি :: E_k = \\frac{1}{2}mv^2\n\n'
            'Tags: #hydraulics #bioenergetics #bangla',
        relativeFilePath: 'RecallMap_Vault/Sources/Hydraulics_Bio_Note.md',
        pageCount: 1,
        lastReadPage: 1,
        tagsJson: jsonEncode(['#hydraulics', '#bioenergetics', '#bangla']),
        graphX: 0.65,
        graphY: 0.30,
        isDemoData: true,
        updatedAt: now,
        contentHash: computeContentHash('demo_concept_note'),
      ),
      StudySourceRecord(
        id: sampleDiagramSourceId,
        deckId: subDeckCellBioId,
        sourceType: 'DIAGRAM_IMAGE',
        title: 'Vascular & Cellular Auto-OCR Diagram',
        markdownBody:
            '4 interactive Auto-OCR bounding masks: Xylem (জাইলেম), Phloem (ফ্লোয়েম), Mitochondrial Cristae, ATP Synthase.',
        relativeFilePath:
            'RecallMap_Vault/Media/vascular_cellular_diagram.png',
        pageCount: 1,
        lastReadPage: 1,
        tagsJson: jsonEncode(['#diagram', '#ocr', '#cell-bio']),
        graphX: 0.48,
        graphY: 0.68,
        isDemoData: true,
        updatedAt: now,
        contentHash: computeContentHash('demo_ocr_diagram'),
      ),
    ];

    // 4 interactive OCR masks for the Sample Auto-OCR Image Occlusion card
    final occlusionMasksJson = jsonEncode([
      {
        'id': 'm1',
        'x': 0.12,
        'y': 0.20,
        'w': 0.26,
        'h': 0.08,
        'label': 'Xylem Vessel (জাইলেম বাহিকা)',
        'languageCode': 'bn',
        'isActiveTarget': true,
      },
      {
        'id': 'm2',
        'x': 0.58,
        'y': 0.22,
        'w': 0.28,
        'h': 0.08,
        'label': 'Phloem Sieve Tube (ফ্লোয়েম সিভনল)',
        'languageCode': 'bn',
        'isActiveTarget': false,
      },
      {
        'id': 'm3',
        'x': 0.14,
        'y': 0.64,
        'w': 0.28,
        'h': 0.08,
        'label': 'Mitochondrial Cristae (ক্রিস্টি)',
        'languageCode': 'bn',
        'isActiveTarget': false,
      },
      {
        'id': 'm4',
        'x': 0.56,
        'y': 0.66,
        'w': 0.30,
        'h': 0.08,
        'label': 'ATP Synthase Rotor (এটিপি সিন্থেস)',
        'languageCode': 'bn',
        'isActiveTarget': false,
      },
    ]);

    // 3. 8 Scheduled FSRS-6 Cards anchored to PDF Pages 1, 2, 3 & Concept Note
    final cards = <CardRecord>[
      // Card 1: PDF Page 1 — Mastered Emerald (S = 44d, reviewed 2 days ago => R ~ 99%)
      CardRecord(
        id: 'card_demo_1_bernoulli',
        deckId: subDeckHydraulicsId,
        sourceId: samplePdfSourceId,
        sourcePage: 1,
        sourceRectJson: jsonEncode({'x': 0.08, 'y': 0.36, 'w': 0.84, 'h': 0.22}),
        cardType: 'CLOZE',
        frontMd:
            r'Bernoulli Principle: An increase in fluid speed occurs simultaneously with a {{c1::decrease in static pressure::pressure change}} ($$P + \frac{1}{2}\rho v^2 + \rho gh = \text{const}$$).',
        backMd:
            'Conservation of mechanical energy along a streamline in steady, incompressible, inviscid flow. বার্নুলির নীতি অনুযায়ী প্রবাহের বেগ বাড়লে স্থির চাপ হ্রাস পায়।',
        tagsJson: jsonEncode(['#hydraulics', '#bernoulli', '#page1']),
        state: 2,
        dueDate: now + 42 * dayMs,
        stability: 44.0,
        difficulty: 3.4,
        elapsedDays: 2.0,
        scheduledDays: 44.0,
        reps: 7,
        lapses: 0,
        lastReview: now - 2 * dayMs,
        isLeech: false,
        isDemoData: true,
        createdAt: now - 42 * dayMs,
        updatedAt: now - 2 * dayMs,
        contentHash: computeContentHash('card_demo_1_bernoulli'),
      ),

      // Card 2: PDF Page 1 — Mastered Emerald (S = 36d, reviewed 3 days ago => R ~ 99%)
      CardRecord(
        id: 'card_demo_2_continuity',
        deckId: subDeckHydraulicsId,
        sourceId: samplePdfSourceId,
        sourcePage: 1,
        sourceRectJson: jsonEncode({'x': 0.08, 'y': 0.14, 'w': 0.84, 'h': 0.16}),
        cardType: 'BASIC',
        frontMd:
            'অসংকোচনীয় প্রবাহীর ধারাবাহিকতার সমীকরণটি (Continuity Equation) কী?',
        backMd:
            r'$$A_1 v_1 = A_2 v_2$$ — নলের প্রস্থচ্ছেদের ক্ষেত্রফল হ্রাস পেলে প্রবাহের বেগ সমানুপাতিক হারে বৃদ্ধি পায়।',
        tagsJson: jsonEncode(['#hydraulics', '#continuity', '#bangla']),
        state: 2,
        dueDate: now + 33 * dayMs,
        stability: 36.0,
        difficulty: 2.9,
        elapsedDays: 3.0,
        scheduledDays: 36.0,
        reps: 6,
        lapses: 0,
        lastReview: now - 3 * dayMs,
        isLeech: false,
        isDemoData: true,
        createdAt: now - 38 * dayMs,
        updatedAt: now - 3 * dayMs,
        contentHash: computeContentHash('card_demo_2_continuity'),
      ),

      // Card 3: PDF Page 2 — Stabilizing Amber (S = 5.4d, reviewed 3 days ago => R ~ 94%, S < 7d)
      CardRecord(
        id: 'card_demo_3_reynolds',
        deckId: subDeckHydraulicsId,
        sourceId: samplePdfSourceId,
        sourcePage: 2,
        sourceRectJson: jsonEncode({'x': 0.08, 'y': 0.18, 'w': 0.84, 'h': 0.22}),
        cardType: 'CLOZE',
        frontMd:
            'In circular pipe flow, laminar flow occurs when Reynolds Number {{c1::Re < 2300}}, and fully turbulent flow occurs when {{c2::Re > 4000}}.',
        backMd:
            r'$$Re = \frac{\rho v D}{\mu}$$ — Ratio of inertial forces to viscous forces.',
        tagsJson: jsonEncode(['#hydraulics', '#reynolds', '#page2']),
        state: 2,
        dueDate: now + 2 * dayMs,
        stability: 5.4,
        difficulty: 5.1,
        elapsedDays: 3.0,
        scheduledDays: 5.0,
        reps: 3,
        lapses: 0,
        lastReview: now - 3 * dayMs,
        isLeech: false,
        isDemoData: true,
        createdAt: now - 16 * dayMs,
        updatedAt: now - 3 * dayMs,
        contentHash: computeContentHash('card_demo_3_reynolds'),
      ),

      // Card 4: Inline `::` Concept Note + PDF Page 2 — Mastered Emerald (S = 32d)
      CardRecord(
        id: 'card_demo_4_darcy',
        deckId: subDeckHydraulicsId,
        sourceId: samplePdfSourceId,
        sourcePage: 2,
        sourceRectJson: jsonEncode({'x': 0.08, 'y': 0.48, 'w': 0.84, 'h': 0.24}),
        cardType: 'INLINE_NOTE',
        frontMd: 'Darcy-Weisbach Equation (Frictional Head Loss)',
        backMd:
            r'$$\Delta h_f = f \cdot \frac{L}{D} \cdot \frac{v^2}{2g}$$ where $$f$$ is the Darcy-Moody friction factor.',
        tagsJson: jsonEncode(['#hydraulics', '#darcy-weisbach', '#inline']),
        state: 2,
        dueDate: now + 28 * dayMs,
        stability: 32.0,
        difficulty: 4.5,
        elapsedDays: 4.0,
        scheduledDays: 32.0,
        reps: 5,
        lapses: 0,
        lastReview: now - 4 * dayMs,
        isLeech: false,
        isDemoData: true,
        createdAt: now - 30 * dayMs,
        updatedAt: now - 4 * dayMs,
        contentHash: computeContentHash('card_demo_4_darcy'),
      ),

      // Card 5: Inline `::` Concept Note (Bangla) — Mastered Emerald (S = 34d)
      CardRecord(
        id: 'card_demo_5_mitochondria_bn',
        deckId: subDeckCellBioId,
        sourceId: sampleConceptNoteSourceId,
        sourcePage: 1,
        cardType: 'INLINE_NOTE',
        frontMd: 'মাইটোকন্ড্রিয়া (Mitochondria) কী?',
        backMd:
            'কোষের পাওয়ার হাউস যা ক্রেবস চক্র ও অক্সিডেটিভ ফসফোরাইলেশনের মাধ্যমে এটিপি (ATP) উৎপাদন করে।',
        tagsJson: jsonEncode(['#cell-bio', '#bangla', '#inline']),
        state: 2,
        dueDate: now + 31 * dayMs,
        stability: 34.0,
        difficulty: 3.1,
        elapsedDays: 3.0,
        scheduledDays: 34.0,
        reps: 6,
        lapses: 0,
        lastReview: now - 3 * dayMs,
        isLeech: false,
        isDemoData: true,
        createdAt: now - 32 * dayMs,
        updatedAt: now - 3 * dayMs,
        contentHash: computeContentHash('card_demo_5_mitochondria_bn'),
      ),

      // Card 6: Auto-OCR Image Occlusion Card (PDF Page 3 & Diagram) — Due Today (Amber S = 6.2d)
      CardRecord(
        id: 'card_demo_6_ocr_occlusion',
        deckId: subDeckCellBioId,
        sourceId: sampleDiagramSourceId,
        sourcePage: 1,
        cardType: 'IMAGE_OCCLUSION',
        frontMd:
            '[Auto-OCR Diagram Mask #1] Identify the occluded vascular tissue transporting water & minerals upward:',
        backMd:
            'Xylem Vessel (জাইলেম বাহিকা) — Unidirectional upward transport of water and dissolved minerals from roots to leaves.',
        occlusionMasksJson: occlusionMasksJson,
        tagsJson: jsonEncode(['#diagram', '#ocr', '#vascular', '#bangla']),
        state: 2,
        dueDate: now - 1 * 3600 * 1000, // Due right now!
        stability: 6.2,
        difficulty: 4.8,
        elapsedDays: 6.2,
        scheduledDays: 6.0,
        reps: 4,
        lapses: 0,
        lastReview: now - 6 * dayMs,
        isLeech: false,
        isDemoData: true,
        createdAt: now - 22 * dayMs,
        updatedAt: now - 6 * dayMs,
        contentHash: computeContentHash('card_demo_6_ocr_occlusion'),
      ),

      // Card 7: PDF Page 3 — Urgent Crimson Leech Card (Lapses = 3, R = 64%)
      // Paired with Card 8 as a BM25 Confusable Twin (Xylem vs Phloem)!
      CardRecord(
        id: 'card_demo_7_xylem_leech',
        deckId: subDeckCellBioId,
        sourceId: samplePdfSourceId,
        sourcePage: 3,
        sourceRectJson: jsonEncode({'x': 0.08, 'y': 0.65, 'w': 0.84, 'h': 0.22}),
        cardType: 'CLOZE',
        frontMd:
            'Vascular Transport: {{c1::Xylem (জাইলেম)}} transports water and dissolved inorganic minerals {{c2::unidirectionally upward}} through tracheids and vessel elements.',
        backMd:
            'Driven by transpirational pull and root pressure; cell walls are lignified and dead at maturity.',
        tagsJson: jsonEncode(['#cell-bio', '#vascular', '#page3', '#leech']),
        state: 3,
        dueDate: now - 5 * dayMs, // Overdue -> Low R (~64%) -> Crimson PDF Page 3 bar!
        stability: 2.1,
        difficulty: 8.2,
        elapsedDays: 7.1,
        scheduledDays: 2.0,
        reps: 8,
        lapses: 3,
        lastReview: now - 7 * dayMs,
        isLeech: true,
        isDemoData: true,
        createdAt: now - 28 * dayMs,
        updatedAt: now - 7 * dayMs,
        contentHash: computeContentHash('card_demo_7_xylem_leech'),
      ),

      // Card 8: PDF Page 3 — Confusable Twin of Card 7 (Phloem vs Xylem) + Cardiology Stabilizing Card
      CardRecord(
        id: 'card_demo_8_phloem_twin',
        deckId: subDeckCellBioId,
        sourceId: samplePdfSourceId,
        sourcePage: 3,
        sourceRectJson: jsonEncode({'x': 0.08, 'y': 0.65, 'w': 0.84, 'h': 0.22}),
        cardType: 'CLOZE',
        frontMd:
            'Vascular Transport: {{c1::Phloem (ফ্লোয়েম)}} transports organic sucrose and amino acids {{c2::bidirectionally}} through living sieve-tube elements and companion cells.',
        backMd:
            'Driven by pressure-flow hypothesis (source-to-sink translocation); cells remain living at maturity.',
        tagsJson: jsonEncode(['#cell-bio', '#vascular', '#page3']),
        state: 2,
        dueDate: now - 2 * 3600 * 1000, // Due Today
        stability: 4.8,
        difficulty: 6.4,
        elapsedDays: 4.8,
        scheduledDays: 5.0,
        reps: 4,
        lapses: 1,
        lastReview: now - 5 * dayMs,
        isLeech: false,
        isDemoData: true,
        createdAt: now - 25 * dayMs,
        updatedAt: now - 5 * dayMs,
        contentHash: computeContentHash('card_demo_8_phloem_twin'),
      ),

      // Card 9: Cardiology Stabilizing Card (Due Today)
      CardRecord(
        id: 'card_demo_9_sa_node',
        deckId: subDeckCardioId,
        sourceId: sampleConceptNoteSourceId,
        sourcePage: 1,
        cardType: 'CLOZE',
        frontMd:
            'The {{c1::Sinoatrial (SA) node}} in the right atrium acts as the natural {{c2::pacemaker}} of the heart (60–100 bpm).',
        backMd:
            r'Spontaneous Phase 4 depolarization via funny current ($$I_f$$) and T-type $$\text{Ca}^{2+}$$ channels.',
        tagsJson: jsonEncode(['#cardiology', '#electrophysiology']),
        state: 2,
        dueDate: now + 1 * dayMs,
        stability: 6.5,
        difficulty: 4.1,
        elapsedDays: 2.0,
        scheduledDays: 6.5,
        reps: 3,
        lapses: 0,
        lastReview: now - 2 * dayMs,
        isLeech: false,
        isDemoData: true,
        createdAt: now - 15 * dayMs,
        updatedAt: now - 2 * dayMs,
        contentHash: computeContentHash('card_demo_9_sa_node'),
      ),
    ];

    // 4. Concept Edges for the 2D Concept RecallMap Graph
    final edges = <ConceptEdgeRecord>[
      ConceptEdgeRecord(
        id: 'edge_demo_1',
        fromId: sampleConceptNoteSourceId,
        toId: samplePdfSourceId,
        edgeType: 'WIKI_LINK',
        strength: 1.0,
        createdAt: now - 30 * dayMs,
      ),
      ConceptEdgeRecord(
        id: 'edge_demo_2',
        fromId: sampleConceptNoteSourceId,
        toId: sampleDiagramSourceId,
        edgeType: 'WIKI_LINK',
        strength: 0.95,
        createdAt: now - 25 * dayMs,
      ),
      ConceptEdgeRecord(
        id: 'edge_demo_3',
        fromId: samplePdfSourceId,
        toId: 'card_demo_1_bernoulli',
        edgeType: 'PDF_EXTRACTION',
        strength: 0.9,
        createdAt: now - 40 * dayMs,
      ),
      ConceptEdgeRecord(
        id: 'edge_demo_4',
        fromId: samplePdfSourceId,
        toId: 'card_demo_3_reynolds',
        edgeType: 'PDF_EXTRACTION',
        strength: 0.9,
        createdAt: now - 16 * dayMs,
      ),
      ConceptEdgeRecord(
        id: 'edge_demo_5',
        fromId: samplePdfSourceId,
        toId: 'card_demo_7_xylem_leech',
        edgeType: 'PDF_EXTRACTION',
        strength: 1.0,
        createdAt: now - 28 * dayMs,
      ),
      ConceptEdgeRecord(
        id: 'edge_demo_6_twin',
        fromId: 'card_demo_7_xylem_leech',
        toId: 'card_demo_8_phloem_twin',
        edgeType: 'CONFUSABLE_TWIN',
        strength: 0.98,
        createdAt: now - 7 * dayMs,
      ),
    ];

    // 5. 45 Days of Sample Heatmap History (`review_logs`)
    final reviewLogs = <ReviewLogRecord>[];
    for (var dayOffset = 44; dayOffset >= 0; dayOffset--) {
      // Skip 2 rest days 28 and 19 days ago so current streak is 18 days 🔥
      if (dayOffset == 28 || dayOffset == 19) continue;

      final dayTimestamp = now - dayOffset * dayMs;
      final reviewsThatDay = 4 + ((dayOffset * 7) % 11);
      for (var r = 0; r < reviewsThatDay; r++) {
        final card = cards[(dayOffset + r) % cards.length];
        final rating = (r % 5 == 0) ? 4 : ((r % 7 == 0) ? 2 : 3);
        reviewLogs.add(
          ReviewLogRecord(
            id: 'rev_demo_d${dayOffset}_r$r',
            cardId: card.id,
            rating: rating,
            stateBefore: 2,
            stabilityBefore: 4.0 + (dayOffset % 15),
            difficultyBefore: card.difficulty,
            stabilityAfter: 6.5 + (dayOffset % 20),
            difficultyAfter: card.difficulty,
            elapsedDays: 2.0,
            scheduledDays: 6.0,
            reviewDurationMs: 4200 + (r * 310),
            reviewedAt: dayTimestamp - (r * 60000),
          ),
        );
      }
    }

    db.seedRaw(
      decks: decks,
      sources: sources,
      cards: cards,
      edges: edges,
      reviewLogs: reviewLogs,
    );
  }
}
