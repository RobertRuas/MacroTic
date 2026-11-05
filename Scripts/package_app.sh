#!/bin/bash
# Builds MacroTic.app from the release binary and zips it for distribution.
# Expects `swift build -c release` to have already run.
# Env vars: APP_VERSION (required), APP_OWNER, APP_REPO (GitHub owner/repo for the Sparkle feed URL),
#           SPARKLE_PUBLIC_KEY (EdDSA public key for Sparkle update verification),
#           CODESIGN_IDENTITY (optional: a stable code signing identity's common name, e.g. "MacroTic Code Signing".
#           Falls back to ad-hoc ("-") when unset, but ad-hoc signatures are unique per build, which makes macOS
#           reset TCC grants (Accessibility, etc.) on every update. Release builds must set this.)
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"

APP_NAME="MacroTic"
VERSION="${APP_VERSION:?APP_VERSION must be set}"
OWNER="${APP_OWNER:-__OWNER__}"
REPO="${APP_REPO:-__REPO__}"
PUBLIC_KEY="${SPARKLE_PUBLIC_KEY:-__SPARKLE_PUBLIC_KEY__}"
SIGN_IDENTITY="${CODESIGN_IDENTITY:--}"

BUILD_DIR="build"
DIST_DIR="dist"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"

rm -rf "$BUILD_DIR" "$DIST_DIR"
mkdir -p "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Resources" "$APP_BUNDLE/Contents/Frameworks" "$DIST_DIR"

cp ".build/release/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
cp "Packaging/AppIcon.icns" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"

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
    -exec codesign --force --sign "$SIGN_IDENTITY" {} \;
codesign --force --deep --sign "$SIGN_IDENTITY" "$APP_BUNDLE/Contents/Frameworks/Sparkle.framework"
codesign --force --deep --sign "$SIGN_IDENTITY" "$APP_BUNDLE"

(cd "$BUILD_DIR" && ditto -c -k --sequesterRsrc --keepParent "$APP_NAME.app" "../$DIST_DIR/$APP_NAME-$VERSION.zip")

echo "Packaged $APP_BUNDLE -> $DIST_DIR/$APP_NAME-$VERSION.zip"
