#!/bin/sh

set -eu

ROOT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
APP_DIR="$ROOT_DIR/.build/HueHouse.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
XCODE_DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"
XCODEBUILD="/usr/bin/xcodebuild"
APPINTENTS_PROCESSOR="$XCODE_DEVELOPER_DIR/Toolchains/XcodeDefault.xctoolchain/usr/bin/appintentsmetadataprocessor"
APPINTENTS_TRAINING_PROCESSOR="$XCODE_DEVELOPER_DIR/Toolchains/XcodeDefault.xctoolchain/usr/bin/appintentsnltrainingprocessor"
BUNDLE_IDENTIFIER="local.huehouse.mac"

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

if [ -x "$APPINTENTS_PROCESSOR" ] && [ -x "$XCODEBUILD" ]; then
    DERIVED_DATA_DIR="$ROOT_DIR/.build/xcode-derived"
    APPINTENTS_DIR="$ROOT_DIR/.build/appintents"
    ARCH="$(uname -m)"
    OBJECTS_DIR="$DERIVED_DATA_DIR/Build/Intermediates.noindex/HueHouse.build/Debug/HueHouse.build/Objects-normal/$ARCH"
    SOURCE_FILE_LIST="$OBJECTS_DIR/HueHouse.SwiftFileList"
    CONST_VALUES_LIST="$APPINTENTS_DIR/HueHouse.SwiftConstValuesFileList"
    DEPENDENCY_METADATA_FILE_LIST="$DERIVED_DATA_DIR/Build/Intermediates.noindex/HueHouse.build/Debug/HueHouse.build/HueHouse.DependencyMetadataFileList"
    STATIC_METADATA_FILE_LIST="$DERIVED_DATA_DIR/Build/Intermediates.noindex/HueHouse.build/Debug/HueHouse.build/HueHouse.DependencyStaticMetadataFileList"
    DEPENDENCY_INFO="$OBJECTS_DIR/HueHouse_dependency_info.dat"
    STRINGS_DATA_FILE="$APPINTENTS_DIR/ExtractedAppShortcutsMetadata.stringsdata"
    SDK_ROOT="$XCODE_DEVELOPER_DIR/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk"
    XCODE_BUILD_VERSION="$(DEVELOPER_DIR="$XCODE_DEVELOPER_DIR" "$XCODEBUILD" -version | awk '/Build version/ {print $3}')"
    TARGET_TRIPLE="$ARCH-apple-macos14.0"

    mkdir -p "$APPINTENTS_DIR"
    DEVELOPER_DIR="$XCODE_DEVELOPER_DIR" "$XCODEBUILD" \
        -scheme HueHouse \
        -destination "platform=macOS" \
        -derivedDataPath "$DERIVED_DATA_DIR" \
        build >/dev/null

    find "$OBJECTS_DIR" -name "*.swiftconstvalues" -print > "$CONST_VALUES_LIST"

    if [ -s "$CONST_VALUES_LIST" ] && [ -f "$SOURCE_FILE_LIST" ]; then
        "$APPINTENTS_PROCESSOR" \
            --toolchain-dir "$XCODE_DEVELOPER_DIR/Toolchains/XcodeDefault.xctoolchain" \
            --module-name HueHouse \
            --sdk-root "$SDK_ROOT" \
            --xcode-version "$XCODE_BUILD_VERSION" \
            --platform-family macOS \
            --deployment-target 14.0 \
            --bundle-identifier "$BUNDLE_IDENTIFIER" \
            --output "$RESOURCES_DIR" \
            --target-triple "$TARGET_TRIPLE" \
            --binary-file "$MACOS_DIR/HueHouse" \
            --dependency-file "$DEPENDENCY_INFO" \
            --stringsdata-file "$STRINGS_DATA_FILE" \
            --source-file-list "$SOURCE_FILE_LIST" \
            --metadata-file-list "$DEPENDENCY_METADATA_FILE_LIST" \
            --static-metadata-file-list "$STATIC_METADATA_FILE_LIST" \
            --swift-const-vals-list "$CONST_VALUES_LIST" \
            --force \
            --compile-time-extraction \
            --deployment-aware-processing \
            --validate-assistant-intents \
            --no-app-shortcuts-localization

        SSU_CLI="$(DEVELOPER_DIR="$XCODE_DEVELOPER_DIR" /usr/bin/xcrun --find ssu-cli 2>/dev/null || true)"
        if [ -x "$APPINTENTS_TRAINING_PROCESSOR" ] && [ -n "$SSU_CLI" ] && [ -d "$RESOURCES_DIR/Metadata.appintents" ]; then
            DEVELOPER_DIR="$XCODE_DEVELOPER_DIR" "$APPINTENTS_TRAINING_PROCESSOR" \
                --infoplist-path "$CONTENTS_DIR/Info.plist" \
                --temp-dir-path "$APPINTENTS_DIR/ssu" \
                --bundle-id "$BUNDLE_IDENTIFIER" \
                --product-path "$RESOURCES_DIR" \
                --extracted-metadata-path "$RESOURCES_DIR/Metadata.appintents" \
                --metadata-file-list "$DEPENDENCY_METADATA_FILE_LIST" \
                --archive-ssu-assets
        fi
    else
        echo "Skipped App Intents metadata generation; Xcode const values were not produced."
    fi
else
    echo "Skipped App Intents metadata generation; full Xcode was not found."
fi

echo "Created $APP_DIR"
