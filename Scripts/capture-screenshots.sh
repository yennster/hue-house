#!/bin/sh
#
# Headless screenshot regeneration for the Mac and iOS apps in demo mode.
#
# Usage:
#   sh Scripts/capture-screenshots.sh [--mac] [--ios]
#
# With no flags, captures both. Outputs land in docs/ (and docs/ios/), ready
# to commit. Both apps must support the `-Demo YES` launch argument that
# seeds HueStore with HueDemoData before the first view body pass.
#
# What this script does NOT capture:
#   * docs/menubar.png — the macOS MenuBarExtra dropdown can't be opened
#     reliably from a script. Refresh that one manually.

set -eu

ROOT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
DOCS_DIR="$ROOT_DIR/docs"
DEVELOPER_DIR_PATH="/Applications/Xcode.app/Contents/Developer"
BUNDLE_ID="local.huehouse.ios"

want_mac=0
want_ios=0
case "${1:-}" in
    --mac) want_mac=1 ;;
    --ios) want_ios=1 ;;
    "")    want_mac=1; want_ios=1 ;;
    *)     echo "Usage: $0 [--mac|--ios]" >&2; exit 2 ;;
esac
case "${2:-}" in
    --mac) want_mac=1 ;;
    --ios) want_ios=1 ;;
    "")    ;;
    *)     echo "Usage: $0 [--mac|--ios]" >&2; exit 2 ;;
esac

mkdir -p "$DOCS_DIR/ios"

if [ "$want_mac" -eq 1 ]; then
    echo "==> Building macOS app (release)"
    cd "$ROOT_DIR"
    swift build -c release >/dev/null

    BIN="$ROOT_DIR/.build/release/HueHouse"
    OUTPUT="$DOCS_DIR/hue-house-light-controls.png"

    # NSUserDefaults reads `-key value` argument pairs as transient defaults,
    # so `-HueAppearanceMode dark` flips the appearance for this run only
    # without touching the user's saved preference.
    "$BIN" -Demo YES -HueAppearanceMode dark &
    APP_PID=$!
    # Make sure we don't leave a screenshot helper running if the script aborts.
    trap 'kill $APP_PID 2>/dev/null || true' EXIT INT TERM

    # SwiftUI window appearance and demo state need a beat to settle.
    sleep 3

    # Resolve the window ID via CoreGraphics (no Accessibility permission needed).
    if ! WIN_ID="$(DEVELOPER_DIR="$DEVELOPER_DIR_PATH" swift "$ROOT_DIR/Scripts/find-window-id.swift" "$APP_PID")"; then
        echo "Could not find HueHouse window for pid $APP_PID. Aborting." >&2
        exit 1
    fi

    echo "==> Capturing window $WIN_ID -> $OUTPUT"
    screencapture -l "$WIN_ID" -o -t png "$OUTPUT"

    kill "$APP_PID" 2>/dev/null || true
    wait "$APP_PID" 2>/dev/null || true
    trap - EXIT INT TERM
    echo "==> Mac screenshot saved."
fi

if [ "$want_ios" -eq 1 ]; then
    echo "==> Generating iOS Xcode project"
    cd "$ROOT_DIR/iOS"
    if ! command -v xcodegen >/dev/null 2>&1; then
        echo "xcodegen is required (brew install xcodegen)" >&2
        exit 1
    fi
    xcodegen generate >/dev/null

    echo "==> Building HueHouseiOS for iOS Simulator"
    DEVELOPER_DIR="$DEVELOPER_DIR_PATH" xcodebuild build \
        -project HueHouseiOS.xcodeproj \
        -scheme HueHouseiOS \
        -destination 'generic/platform=iOS Simulator' \
        -derivedDataPath build \
        CODE_SIGNING_ALLOWED=NO \
        CODE_SIGNING_REQUIRED=NO \
        DEVELOPMENT_TEAM='' \
        >/dev/null

    APP_PATH="$ROOT_DIR/iOS/build/Build/Products/Debug-iphonesimulator/HueHouseiOS.app"

    UDID="$(DEVELOPER_DIR=$DEVELOPER_DIR_PATH xcrun simctl list devices available -j | \
        python3 -c '
import json, sys
data = json.load(sys.stdin)["devices"]
keys = sorted([k for k in data if "iOS" in k], reverse=True)
for k in keys:
    for d in data[k]:
        if "iPhone" in d["name"]:
            print(d["udid"])
            sys.exit(0)
')"
    if [ -z "$UDID" ]; then
        echo "No available iPhone simulator found." >&2
        exit 1
    fi
    echo "==> Using simulator $UDID"

    DEVELOPER_DIR="$DEVELOPER_DIR_PATH" xcrun simctl boot "$UDID" 2>/dev/null || true
    # Cleanup hook: shutdown sim and clear status bar overrides on exit.
    trap 'DEVELOPER_DIR="$DEVELOPER_DIR_PATH" xcrun simctl status_bar "$UDID" clear 2>/dev/null || true; \
          DEVELOPER_DIR="$DEVELOPER_DIR_PATH" xcrun simctl shutdown "$UDID" 2>/dev/null || true' EXIT INT TERM

    sleep 2
    DEVELOPER_DIR="$DEVELOPER_DIR_PATH" xcrun simctl install "$UDID" "$APP_PATH"
    DEVELOPER_DIR="$DEVELOPER_DIR_PATH" xcrun simctl ui "$UDID" appearance dark
    DEVELOPER_DIR="$DEVELOPER_DIR_PATH" xcrun simctl status_bar "$UDID" override \
        --time "9:41" --batteryState charged --batteryLevel 100 \
        --cellularBars 4 --wifiBars 3

    for tab in Lights Gradients Bridge; do
        DEVELOPER_DIR="$DEVELOPER_DIR_PATH" xcrun simctl terminate "$UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true
        sleep 0.5
        DEVELOPER_DIR="$DEVELOPER_DIR_PATH" xcrun simctl launch "$UDID" "$BUNDLE_ID" -Demo YES -Tab "$tab" >/dev/null
        sleep 3
        out="$(echo "$tab" | tr '[:upper:]' '[:lower:]')"
        OUTPUT="$DOCS_DIR/ios/${out}.png"
        echo "==> Capturing $tab -> $OUTPUT"
        DEVELOPER_DIR="$DEVELOPER_DIR_PATH" xcrun simctl io "$UDID" screenshot "$OUTPUT"
    done

    DEVELOPER_DIR="$DEVELOPER_DIR_PATH" xcrun simctl terminate "$UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true
    DEVELOPER_DIR="$DEVELOPER_DIR_PATH" xcrun simctl status_bar "$UDID" clear
    DEVELOPER_DIR="$DEVELOPER_DIR_PATH" xcrun simctl shutdown "$UDID"
    trap - EXIT INT TERM
    echo "==> iOS screenshots saved."
fi

echo
echo "Done."
git -C "$ROOT_DIR" status --short docs/ || true
