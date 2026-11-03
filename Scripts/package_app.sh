#!/bin/bash
# Builds MacroTic.app from the release binary and zips it for distribution.
# Expects `swift build -c release` to have already run.
# Env vars: APP_VERSION (required), APP_OWNER, APP_REPO (GitHub owner/repo for the Sparkle feed URL),
#           SPARKLE_PUBLIC_KEY (EdDSA public key for Sparkle update verification)
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"

APP_NAME="MacroTic"
VERSION="${APP_VERSION:?APP_VERSION must be set}"
OWNER="${APP_OWNER:-__OWNER__}"
REPO="${APP_REPO:-__REPO__}"
PUBLIC_KEY="${SPARKLE_PUBLIC_KEY:-__SPARKLE_PUBLIC_KEY__}"

BUILD_DIR="build"
DIST_DIR="dist"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"

rm -rf "$BUILD_DIR" "$DIST_DIR"
mkdir -p "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Resources" "$APP_BUNDLE/Contents/Frameworks" "$DIST_DIR"

cp ".build/release/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

SPARKLE_FRAMEWORK="$(find .build/release -maxdepth 1 -name "Sparkle.framework" | head -n1)"
if [ -z "$SPARKLE_FRAMEWORK" ]; then
    SPARKLE_FRAMEWORK="$(find .build/artifacts -type d -name "Sparkle.framework" | head -n1)"
fi
if [ -z "$SPARKLE_FRAMEWORK" ]; then
    echo "error: could not locate Sparkle.framework in .build" >&2
    exit 1
fi
cp -R "$SPARKLE_FRAMEWORK" "$APP_BUNDLE/Contents/Frameworks/Sparkle.framework"

sed \
    -e "s|__VERSION__|$VERSION|g" \
    -e "s|__OWNER__|$OWNER|g" \
    -e "s|__REPO__|$REPO|g" \
    -e "s|__SPARKLE_PUBLIC_KEY__|$PUBLIC_KEY|g" \
    Packaging/Info.plist > "$APP_BUNDLE/Contents/Info.plist"

find "$APP_BUNDLE/Contents/Frameworks/Sparkle.framework" \
    \( -name "*.xpc" -o -name "Autoupdate" -o -name "Updater.app" \) \
    -exec codesign --force --sign - {} \;
codesign --force --deep --sign - "$APP_BUNDLE/Contents/Frameworks/Sparkle.framework"
codesign --force --deep --sign - "$APP_BUNDLE"

(cd "$BUILD_DIR" && ditto -c -k --sequesterRsrc --keepParent "$APP_NAME.app" "../$DIST_DIR/$APP_NAME-$VERSION.zip")

echo "Packaged $APP_BUNDLE -> $DIST_DIR/$APP_NAME-$VERSION.zip"
