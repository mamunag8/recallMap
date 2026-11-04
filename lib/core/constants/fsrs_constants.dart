/// Authentic FSRS-6 (21-parameter DSR memory model) constants, brand metadata,
/// vault paths, and monetization tier limits.
class FsrsConstants {
  FsrsConstants._();

  // --- Brand Identity & Store Metadata ---
  static const String appDisplayName = 'RecallMap';
  static const String storeTitle = 'RecallMap: FSRS & PDF Study';
  static const String storeSubtitle =
      'Visual Spaced Repetition, Image Occlusion & Exam Map';
  static const String bundleId = 'com.recallmap.app';

  // --- Local & Cloud Sync Vault Paths ---
  static const String vaultRootFolder = 'RecallMap_Vault';
  static const String vaultInternalFolder = 'RecallMap_Vault/.recallmap';
  static const String vaultSqliteFileName = 'recallmap.sqlite';
  static const String vaultSyncManifestFile =
      'RecallMap_Vault/.recallmap/sync_manifest.json';
  static const String vaultSourcesFolder = 'RecallMap_Vault/Sources';
  static const String vaultMediaFolder = 'RecallMap_Vault/Media';
  static const String vaultBackupsFolder = 'RecallMap_Vault/Backups';

  // --- Official FSRS-6 Default 21 Weights (w[0] .. w[20]) ---
  // Reference: open-spaced-repetition FSRS-6 benchmark parameters:
  // w[0..3]: Initial stability S_0(G) for Again(1), Hard(2), Good(3), Easy(4)
  // w[4..5]: Initial difficulty D_0(G) parameters
  // w[6..7]: Difficulty update delta_D and mean reversion weight
  // w[8..10]: Recall stability increase S_inc parameters
  // w[11..14]: Lapse stability S_lapse parameters
  // w[15]: Hard penalty factor
  // w[16]: Easy bonus factor
  // w[17..19]: Same-day / short-term review parameters
  // w[20]: Power-law forgetting curve trainable decay parameter
  static const List<double> defaultWeights = [
    0.2120, // w[0] S_0(Again)
    1.2931, // w[1] S_0(Hard)
    2.3065, // w[2] S_0(Good)
    8.2956, // w[3] S_0(Easy)
    6.4133, // w[4] D_0 base
    0.8334, // w[5] D_0 exponent
    3.0194, // w[6] delta_D slope
    0.0010, // w[7] D mean reversion weight
    1.8722, // w[8] S_inc exp base
    0.1666, // w[9] S_inc stability damping power
    0.7960, // w[10] S_inc retrievability bonus exponent
    1.4835, // w[11] S_lapse base multiplier
    0.0614, // w[12] S_lapse difficulty exponent
    0.2629, // w[13] S_lapse stability power
    1.6483, // w[14] S_lapse retrievability exponent
    0.6014, // w[15] Hard penalty factor
    1.8729, // w[16] Easy bonus factor
    0.5425, // w[17] Short-term stability exponent
    0.0912, // w[18] Short-term grade offset
    0.0658, // w[19] Short-term stability power damping
    0.1542, // w[20] Power-law forgetting curve decay parameter
  ];

  // --- Retention & Leech Thresholds ---
  static const double defaultTargetRetention = 0.90;
  static const double minTargetRetention = 0.75;
  static const double maxTargetRetention = 0.97;
  static const double examPeakRetention = 0.95;
  static const int leechLapseThreshold = 3;

  // --- Card States ---
  static const int stateNew = 0;
  static const int stateLearning = 1;
  static const int stateReview = 2;
  static const int stateRelearning = 3;

  // --- Review Ratings ---
  static const int ratingAgain = 1;
  static const int ratingHard = 2;
  static const int ratingGood = 3;
  static const int ratingEasy = 4;

  // --- Monetization Limits (100% Ad-Free + One-Time $7.99 Pro Unlock) ---
  static const int freeTierMaxPdfBooks = 2;
  static const int freeTierMaxOcclusionCards = 25;
  static const String proLifetimePriceDisplay = r'$7.99';
}
