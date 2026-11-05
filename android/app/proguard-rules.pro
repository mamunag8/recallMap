# RecallMap ProGuard / R8 Rules for Google Play Store Release (.aab)
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Keep SQLite3 FFI & Drift native bindings
-keep class com.simolus3.sqlite3.** { *; }
-dontwarn com.google.errorprone.annotations.**
