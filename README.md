# Gemma Chat (iOS, on-device Gemma 4)

Requirements: Mac, Xcode, Flutter, CocoaPods, a physical iPhone (iOS 15+), Apple ID.

    ./setup_ios.sh
    flutter run --release

Before running, check `_modelUrl` in lib/main.dart against the exact file name
on huggingface.co/litert-community/gemma-4-E2B-it-litert-lm (Files tab).
First launch downloads ~2.4 GB; after that the app works offline.

## Android (APK)

Local:   ./setup_android.sh   -> build/app/outputs/flutter-apk/app-release.apk
Cloud:   push this folder to a GitHub repo, open Actions > "Build Android APK" > Run workflow,
         then download the "gemma-chat-apk" artifact.
Requires an arm64 Android phone, Android 11+ (API 30+).
