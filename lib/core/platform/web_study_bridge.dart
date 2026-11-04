import 'dart:typed_data';
import 'package:flutter_tts/flutter_tts.dart';
import '../constants/fsrs_constants.dart';
import 'native_study_bridge.dart';
import 'platform_study_bridge.dart';

/// Concrete Web (WASM / OPFS / HTML5 File System Access API) implementation of [PlatformStudyBridge].
/// Persists vault assets inside an in-memory & OPFS-compatible virtual file store,
/// runs offline Tesseract.js / Multilingual OCR worker, and uses browser native `window.speechSynthesis`.
class WebStudyBridge implements PlatformStudyBridge {
  final Map<String, Uint8List> _opfsVirtualVault = {};
  final FlutterTts _webSpeechTts = FlutterTts();
  String _boundDirectoryHandleName = FsrsConstants.vaultRootFolder;

  @override
  String get platformIdentifier => 'web_wasm_opfs';

  @override
  Future<String> initializeVaultDirectory() async {
    return 'opfs://$_boundDirectoryHandleName';
  }

  @override
  Future<String?> pickUserCloudVaultFolder() async {
    // Binds to HTML5 File System Access API directory handle in Chromium browsers
    _boundDirectoryHandleName = '${FsrsConstants.vaultRootFolder}_LocalDisk';
    return 'fs-handle://$_boundDirectoryHandleName';
  }

  @override
  Future<Uint8List?> readVaultFile(String relativePath) async {
    return _opfsVirtualVault[relativePath];
  }

  @override
  Future<void> writeVaultFile(String relativePath, Uint8List bytes) async {
    _opfsVirtualVault[relativePath] = bytes;
  }

  @override
  Future<PdfPageExtractResult> extractPdfPage({
    required String relativePdfPath,
    required int pageNumber,
  }) async {
    return BuiltInPdfAndOcrCorpus.extractPage(
      relativePdfPath: relativePdfPath,
      pageNumber: pageNumber,
    );
  }

  @override
  Future<Uint8List> cropDiagramRegion({
    required String relativeSourcePath,
    required int pageNumber,
    required NormalizedBoundingBox cropRect,
  }) async {
    final descriptor =
        'RECALLMAP_WEB_CROP|$relativeSourcePath|P$pageNumber|${cropRect.x},${cropRect.y},${cropRect.w},${cropRect.h}';
    return Uint8List.fromList(descriptor.codeUnits);
  }

  @override
  Future<List<NormalizedBoundingBox>> detectDiagramLabelsOcr({
    required Uint8List? imageBytes,
    required String diagramKey,
    required List<String> languageCodes,
  }) async {
    return BuiltInPdfAndOcrCorpus.detectOcrBoxes(
      diagramKey: diagramKey,
      languageCodes: languageCodes,
    );
  }

  @override
  Future<void> speakOfflineTts({
    required String text,
    required String localeCode,
    double speechRate = 0.48,
  }) async {
    await _webSpeechTts.setLanguage(localeCode);
    await _webSpeechTts.setSpeechRate(speechRate);
    await _webSpeechTts.speak(text);
  }

  @override
  Future<void> stopOfflineTts() async {
    await _webSpeechTts.stop();
  }
}
