# Privacy Policy for RecallMap: FSRS & PDF Study (`com.recallmap.app`)

**Effective Date:** November 5, 2026  
**Package / Bundle Identifier:** `com.recallmap.app`  
**Developer:** RecallMap Studio / Kasb LLC

---

## 1. Zero-Server, 100% On-Device Architecture
**RecallMap** operates on a strict **100% User-Owned Resource & Zero-Telemetry** architecture:
- We do **not** operate any proprietary tracking servers, analytics SDKs, or advertising networks.
- We do **not** collect, sell, rent, or transmit your personal identity, study decks, PDFs, flashcards, or review logs to our servers.

## 2. Local Data Storage (`RecallMap_Vault/`)
All decks, imported PDFs, concept notes, OCR image occlusion masks, and FSRS-6 review history (`review_logs`) are stored locally on your device inside your portable `RecallMap_Vault/` folder (or inside the browser's Origin-Private File System on Web).

## 3. Bring Your Own Cloud (BYOC) Sync
When you optionally enable cross-device synchronization:
- **Google Drive Direct Sync (`drive.file` / `appDataFolder`):** RecallMap connects directly from your device to your personal Google Drive account using OAuth 2.0 scoped exclusively to files created by RecallMap (`RecallMap_Vault/.recallmap/sync_manifest.json`). No third-party server ever intercepts or stores your Google Drive files or tokens.
- **Local Cloud Folder / WebDAV:** Sync transfers occur directly between your device and your chosen folder (iCloud Drive, OneDrive, Dropbox, Local Disk) or self-hosted WebDAV server.

## 4. Camera, Photos & Microphone/TTS Permissions
- **Camera & Photo Library (`android.permission.CAMERA`):** Used strictly on-device when you import or scan a textbook diagram for 1-Tap Auto-OCR Image Occlusion. Images are processed locally on your device's CPU/GPU and are never uploaded to any external OCR server.
- **Text-to-Speech (TTS):** Uses your operating system's built-in offline speech synthesizer (`android.speech.tts.TextToSpeech` / iOS `AVSpeechSynthesizer`).

## 5. Contact Us
If you have any questions regarding this Privacy Policy, please open an issue or contact us via our official repository: `https://github.com/mamunag8/recallMap`.
