#!/usr/bin/env bash
# Run on a Mac with Flutter, Xcode and CocoaPods installed.
set -e
cd "$(dirname "$0")"

# 1. Generate the iOS project (keeps existing lib/ and pubspec.yaml)
flutter create . --platforms=ios --project-name gemma_chat --org com.example
flutter pub get

# 2. Patch ios/Podfile: iOS 15 + static linking
PODFILE=ios/Podfile
if [ ! -f "$PODFILE" ]; then
  echo "ios/Podfile not found. Run 'flutter build ios --config-only' then re-run this script."; exit 1
fi
if grep -q "^platform :ios" "$PODFILE"; then
  perl -pi -e "s/^platform :ios.*/platform :ios, '15.0'/" "$PODFILE"
else
  perl -pi -e "s/^# platform :ios.*/platform :ios, '15.0'/" "$PODFILE"
fi
perl -pi -e "s/^\s*use_frameworks!\s*\$/  use_frameworks! :linkage => :static/" "$PODFILE"

# 3. Pods
(cd ios && pod install)

cat <<MSG

Done. Final manual steps (one time):
  1. open ios/Runner.xcworkspace
  2. Runner target > Signing & Capabilities:
       - choose your Team, set a unique Bundle Identifier
       - click "+ Capability" and add "Extended Virtual Addressing"
         and "Increased Memory Limit"
  3. Plug in your iPhone, then:  flutter run --release
     (if the model repo is gated: add --dart-define=HUGGINGFACE_TOKEN=hf_xxx)

To get an .ipa for TestFlight:  flutter build ipa
MSG
