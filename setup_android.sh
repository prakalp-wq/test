#!/usr/bin/env bash
# Generates the Android project, applies required settings, builds a release APK.
# Needs Flutter + Android SDK + JDK 17 (or run it via the GitHub Action).
set -e
cd "$(dirname "$0")"

flutter create . --platforms=android --project-name gemma_chat --org com.example
flutter pub get

# minSdk 30 is required by LiteRT-LM (works with both Groovy and Kotlin DSL templates)
GRADLE=$(ls android/app/build.gradle.kts android/app/build.gradle 2>/dev/null | head -1)
perl -pi -e 's/minSdk\s*=\s*flutter\.minSdkVersion/minSdk = 30/; s/minSdkVersion\s+flutter\.minSdkVersion/minSdkVersion 30/' "$GRADLE"
grep -n "minSdk" "$GRADLE"

# INTERNET permission is needed in release builds to download the model
MANIFEST=android/app/src/main/AndroidManifest.xml
if ! grep -q "android.permission.INTERNET" "$MANIFEST"; then
  perl -0pi -e 's/<manifest([^>]*)>/<manifest$1>\n    <uses-permission android:name="android.permission.INTERNET"\/>/' "$MANIFEST"
fi

# LiteRT-LM is arm64-v8a only
flutter build apk --release --target-platform android-arm64
echo "APK: build/app/outputs/flutter-apk/app-release.apk"
