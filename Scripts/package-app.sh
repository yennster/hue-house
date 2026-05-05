#!/bin/sh

set -eu

ROOT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
APP_DIR="$ROOT_DIR/.build/HueHouse.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
BUNDLE_IDENTIFIER="local.huehouse.mac"
APP_VERSION="$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$ROOT_DIR/Packaging/Info.plist")"
ZIP_PATH="$ROOT_DIR/.build/HueHouse-v$APP_VERSION.zip"

cd "$ROOT_DIR"
swift build -c release

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"
cp "$ROOT_DIR/.build/release/HueHouse" "$MACOS_DIR/HueHouse"
cp "$ROOT_DIR/Packaging/Info.plist" "$CONTENTS_DIR/Info.plist"

if [ ! -f "$ROOT_DIR/Packaging/AppIcon.icns" ]; then
    swift "$ROOT_DIR/Scripts/generate-icon.swift" >/dev/null
fi
cp "$ROOT_DIR/Packaging/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"

# Ad-hoc sign the bundle. Without any signature, recent macOS rejects the app
# outright with a misleading "damaged" Gatekeeper warning when downloaded.
# Ad-hoc signing (`-` as the identity) satisfies the unsigned-binary check;
# users still see the "unidentified developer" prompt and need right-click →
# Open the first time, but the bundle launches.
codesign --force --deep --sign - "$APP_DIR"

echo "Created $APP_DIR"

ditto -c -k --keepParent --norsrc "$APP_DIR" "$ZIP_PATH"

echo "Created $ZIP_PATH"
