# Google Play Console — Step-by-Step Publishing & Data Safety Guide for `RecallMap` (`com.recallmap.app`)

Your repository (`https://github.com/mamunag8/recallMap`) now includes the complete 7-Phase production codebase and an automated GitHub Actions release pipeline (`.github/workflows/play_store_release.yml`) that compiles your signed **`app-release.aab`** (Android App Bundle) for Google Play Store.

---

## Step 1: Download Your Signed `app-release.aab` (Or Auto-Upload via Service Account)
1. Open your GitHub repository Actions tab: **`https://github.com/mamunag8/recallMap/actions`**
2. Click the latest **"Build & Publish RecallMap to Google Play Store (.aab & .apk)"** workflow run.
3. Under **Artifacts**, download **`RecallMap-PlayStore-Release-Bundle`**, which contains:
   - `app-release.aab` (Signed production Android App Bundle for Google Play Console)
   - `app-release.apk` (Signed universal APK for direct device installation)
   - `recallmap-upload-keystore.jks` (Keep this upload keystore backed up safely for future updates; or save its Base64 string as the `UPLOAD_KEYSTORE_BASE64` secret in GitHub Settings → Secrets → Actions).

---

## Step 2: Create the App in Google Play Console
1. Sign in to **[Google Play Console](https://play.google.com/console/)** and click **Create app**.
2. Fill in the initial details:
   - **App name:** `RecallMap: FSRS & PDF Study`
   - **Default language:** `English (United States) – en-US` (You can also add `Bangla (Bangladesh) – bn-BD` from `play_store/store_listing_en_bn.json`)
   - **App or game:** `App`
   - **Free or paid:** `Free`
   - **Declarations:** Check Developer Program Policies and US export laws, then click **Create app**.

---

## Step 3: Complete the Mandatory Google Play Dashboard Policies (Takes ~3 Minutes)
Use these exact answers in **App content**:

1. **Privacy Policy URL:**
   - Paste: `https://raw.githubusercontent.com/mamunag8/recallMap/main/play_store/PRIVACY_POLICY.md` (or enable GitHub Pages on `main` and use `https://mamunag8.github.io/recallMap/play_store/PRIVACY_POLICY.html`).
2. **Ads Declaration:**
   - Select: **"No, my app does not contain ads"** (RecallMap has a strict 100% Zero-Ad policy).
3. **App Access:**
   - Select: **"All functionality is available without special access"** (RecallMap launches straight into the pre-loaded interactive demo deck `"📌 Start Here / শুরু করুন"` with zero login wall).
4. **Data Safety Questionnaire:**
   - *Does your app collect or share any of the required user data types?* → Select **No** (All FSRS-6 scheduling, SQLite storage, and OCR execute 100% locally on the user's device; optional BYOC sync goes directly to the user's own folder/Google Drive).
5. **Content Rating (IARC):**
   - Category: **Reference, News, or Educational** → Answer **No** to all violence/mature content questions → Receives **Everyone (PEGI 3 / ESRB E)** rating.
6. **Target Audience:**
   - Select age groups **13–15, 16–17, 18 and over**.

---

## Step 4: Upload `app-release.aab` & Publish
1. In Google Play Console, go to **Test and release → Production** (or **Internal testing / Closed testing**).
2. Click **Create new release**.
3. Upload **`app-release.aab`**.
4. Under **Release notes**, paste:
   ```text
   <en-US>
   Initial 1.0.0 release of RecallMap: The Visual FSRS-6 Exam & PDF Flashcard Studio!
   • Layer 1 Cockpit with 91% Exam Readiness Ring, Mastery Bubble/Sunburst Map & 365-Day Heatmap
   • Layer 2 Split-Screen PDF Reader with live Red/Amber/Emerald Page Mastery Strip & 2D Concept RecallMap
   • 1-Tap Auto-OCR Diagram Image Occlusion (English, বাংলা, Turkish, Arabic)
   • Authentic 21-Parameter FSRS-6 Scheduler, Memory Doctor Confusable Twin Radar & $0 AI Token-Saver Bridge
   </en-US>
   ```
5. Click **Next → Save and publish**!

*(Optional Automated Continuous Deployment)*: If you add a Google Play Service Account JSON key to your GitHub repository secrets under `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON`, every future push to `main` will automatically upload the new `.aab` directly to Google Play Console!
