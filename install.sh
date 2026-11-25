#!/bin/zsh
# Builds a Release copy of Portfolio Allocation and installs it in /Applications.
# Run it again after any change to update the installed app. Your data is not touched:
# it lives in the app's sandbox folder, which every copy with this bundle ID shares.
#
#   ./install.sh         build and install
#   ./install.sh --dmg   build a disk image in dist/ to attach to a GitHub release
set -euo pipefail
cd "$(dirname "$0")"

APP_NAME="Portfolio Allocation"
DESTINATION="/Applications/$APP_NAME.app"
MAKE_DMG=false
[[ "${1:-}" == "--dmg" ]] && MAKE_DMG=true

if ! $MAKE_DMG && pgrep -f "$DESTINATION/" >/dev/null; then
    echo "Quit the installed $APP_NAME first, then run this again."
    exit 1
fi

# Use full Xcode even when the command line tools are selected.
DEVELOPER_DIR="$(xcode-select -p)"
if [[ "$DEVELOPER_DIR" == *CommandLineTools* ]]; then
    for xcode in /Applications/Xcode.app /Applications/Xcode-beta.app; do
        if [[ -d "$xcode" ]]; then DEVELOPER_DIR="$xcode/Contents/Developer"; break; fi
    done
fi
export DEVELOPER_DIR

BUILD_DIR="$(mktemp -d)"
trap 'rm -rf "$BUILD_DIR"' EXIT

echo "Building $APP_NAME (Release)…"
# Ad-hoc signing ("Sign to Run Locally") keeps the sandbox entitlement, so the installed
# app uses the same data folder as the copy you run from Xcode.
xcodebuild -quiet \
    -project "$APP_NAME.xcodeproj" \
    -scheme "$APP_NAME" \
    -configuration Release \
    -destination "platform=macOS" \
    -derivedDataPath "$BUILD_DIR" \
    CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY=- DEVELOPMENT_TEAM= \
    build 2>&1 | grep -v -e "Supported platforms for the buildables" -e "appintentsmetadataprocessor" || true

BUILT_APP="$BUILD_DIR/Build/Products/Release/$APP_NAME.app"

# Re-sign with the same entitlements minus get-task-allow, which Xcode adds so its debugger
# can attach. A shipped copy shouldn't let other programs read its decrypted data.
ENTITLEMENTS="$BUILD_DIR/entitlements.plist"
codesign -d --entitlements - --xml "$BUILT_APP" > "$ENTITLEMENTS" 2>/dev/null
/usr/libexec/PlistBuddy -c "Delete :com.apple.security.get-task-allow" "$ENTITLEMENTS" 2>/dev/null || true
codesign --force --sign - --entitlements "$ENTITLEMENTS" "$BUILT_APP" 2>/dev/null
codesign --verify --strict "$BUILT_APP"

# Without the sandbox the app would look for its data in the wrong place.
if ! codesign -d --entitlements - --xml "$BUILT_APP" 2>/dev/null | grep -q "com.apple.security.app-sandbox"; then
    echo "The build is missing the sandbox entitlement; stopping."
    exit 1
fi

if $MAKE_DMG; then
    # The app next to a link to Applications: the standard drag-to-install window.
    VERSION="$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$BUILT_APP/Contents/Info.plist")"
    STAGE="$BUILD_DIR/dmg"
    DMG="dist/${APP_NAME// /-}-$VERSION.dmg"
    mkdir -p "$STAGE" dist
    ditto "$BUILT_APP" "$STAGE/$APP_NAME.app"
    ln -s /Applications "$STAGE/Applications"
    rm -f "$DMG"
    diskutil image create from --format ULFO --volumeName "$APP_NAME" "$STAGE" "$DMG" >/dev/null
    echo # end diskutil's progress line
    echo "Created $DMG"
else
    rm -rf "$DESTINATION"
    ditto "$BUILT_APP" "$DESTINATION"
    echo "Installed $DESTINATION"
fi
