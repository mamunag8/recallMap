import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'native_study_bridge.dart';
import 'web_study_bridge.dart';

/// Normalized bounding box [0.0 .. 1.0] for PDF highlights, region crops,
/// and 1-Tap Auto-OCR Diagram Occlusion masks.
class NormalizedBoundingBox {
  final String id;
  final double x;
  final double y;
  final double w;
  final double h;
  final String label;
  final String languageCode;
  final double confidence;
  final bool isActiveTarget;

  const NormalizedBoundingBox({
    required this.id,
    required this.x,
    required this.y,
    required this.w,
    required this.h,
    required this.label,
    this.languageCode = 'en',
    this.confidence = 0.98,
    this.isActiveTarget = true,
  });

  NormalizedBoundingBox copyWith({
    String? id,
    double? x,
    double? y,
    double? w,
    double? h,
    String? label,
    String? languageCode,
    double? confidence,
    bool? isActiveTarget,
  }) {
    return NormalizedBoundingBox(
      id: id ?? this.id,
      x: x ?? this.x,
      y: y ?? this.y,
      w: w ?? this.w,
      h: h ?? this.h,
      label: label ?? this.label,
      languageCode: languageCode ?? this.languageCode,
      confidence: confidence ?? this.confidence,
      isActiveTarget: isActiveTarget ?? this.isActiveTarget,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'x': x,
        'y': y,
        'w': w,
        'h': h,
        'label': label,
        'languageCode': languageCode,
        'confidence': confidence,
        'isActiveTarget': isActiveTarget,
      };

  factory NormalizedBoundingBox.fromJson(Map<String, dynamic> json) {
    return NormalizedBoundingBox(
      id: (json['id'] ?? 'm1').toString(),
      x: (json['x'] as num?)?.toDouble() ?? 0.1,
      y: (json['y'] as num?)?.toDouble() ?? 0.1,
      w: (json['w'] as num?)?.toDouble() ?? 0.2,
      h: (json['h'] as num?)?.toDouble() ?? 0.06,
      label: (json['label'] ?? '').toString(),
      languageCode: (json['languageCode'] ?? 'en').toString(),
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.95,
      isActiveTarget: json['isActiveTarget'] as bool? ?? true,
    );
  }
}

/// Extracted text and paragraph coordinate metadata from a PDF page.
class PdfPageExtractResult {
  final int pageNumber;
  final String fullText;
  final List<NormalizedBoundingBox> sentenceBlocks;

  const PdfPageExtractResult({
    required this.pageNumber,
    required this.fullText,
    required this.sentenceBlocks,
  });
}

/// Unified Platform Study Bridge interface abstracting Native (iOS/Android)
/// and Web (WASM / OPFS / HTML5 File System Access API) capabilities.
abstract class PlatformStudyBridge {
  /// Returns the platform identifier ('native_mobile_desktop' or 'web_wasm_opfs').
  String get platformIdentifier;

  /// Initializes the local `RecallMap_Vault/` and `.recallmap/` folders.
  Future<String> initializeVaultDirectory();

  /// Opens native SAF / UIDocumentPicker or Web `window.showDirectoryPicker()`
  /// to bind a user-owned cloud sync folder (iCloud, OneDrive, Dropbox, Local Disk).
  Future<String?> pickUserCloudVaultFolder();

  /// Reads raw bytes from a relative path inside `RecallMap_Vault/`.
  Future<Uint8List?> readVaultFile(String relativePath);

  /// Writes raw bytes to a relative path inside `RecallMap_Vault/`.
  Future<void> writeVaultFile(String relativePath, Uint8List bytes);

  /// Extracts text and normalized sentence coordinates from a PDF page.
  Future<PdfPageExtractResult> extractPdfPage({
    required String relativePdfPath,
    required int pageNumber,
  });

  /// Crops a rectangular region [cropRect] from a PDF page or diagram image.
  Future<Uint8List> cropDiagramRegion({
    required String relativeSourcePath,
    required int pageNumber,
    required NormalizedBoundingBox cropRect,
  });

  /// Runs on-device Multilingual Diagram OCR (supporting Bangla `ben`, English `eng`,
  /// Turkish `tur`, Arabic `ara`, Hindi `hin`) to auto-detect diagram text labels.
  Future<List<NormalizedBoundingBox>> detectDiagramLabelsOcr({
    required Uint8List? imageBytes,
    required String diagramKey,
    required List<String> languageCodes,
  });

  /// Speaks [text] offline using native iOS AVSpeechSynthesizer, Android TextToSpeech,
  /// or Web `window.speechSynthesis` in the card's native language (`bn-BD`, `en-US`, etc.).
  Future<void> speakOfflineTts({
    required String text,
    required String localeCode,
    double speechRate = 0.48,
  });

  /// Stops active offline TTS playback.
  Future<void> stopOfflineTts();
}

final platformStudyBridgeProvider = Provider<PlatformStudyBridge>((ref) {
  if (kIsWeb) {
    return WebStudyBridge();
  }
  return NativeStudyBridge();
});
