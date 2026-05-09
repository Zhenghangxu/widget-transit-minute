#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PRODUCT_NAME="Transit Minute"
APP_DIR="$ROOT_DIR/.build/app/$PRODUCT_NAME.app"
DIST_DIR="$ROOT_DIR/.build/dist"
PLIST_SOURCE="$ROOT_DIR/Packaging/Info.plist"
CONFIGURATION="${CONFIGURATION:-release}"
SIGN_IDENTITY="${SIGN_IDENTITY:-}"
NOTARY_PROFILE="${NOTARY_PROFILE:-}"

if [[ -z "$SIGN_IDENTITY" ]]; then
    echo "SIGN_IDENTITY is required for Developer ID DMG builds." >&2
    echo "Example: SIGN_IDENTITY=\"Developer ID Application: Your Name (TEAMID)\" ./Scripts/build_dmg.sh" >&2
    echo "Available code signing identities:" >&2
    security find-identity -v -p codesigning >&2
    exit 1
fi

if ! security find-identity -v -p codesigning | grep -F -- "$SIGN_IDENTITY" >/dev/null; then
    echo "Signing identity not found: $SIGN_IDENTITY" >&2
    echo "Install a Developer ID Application certificate, then rerun with SIGN_IDENTITY set to its exact name." >&2
    echo "Available code signing identities:" >&2
    security find-identity -v -p codesigning >&2
    exit 1
fi

VERSION="$(plutil -extract CFBundleShortVersionString raw -o - "$PLIST_SOURCE" 2>/dev/null || echo "0.1.0")"
DMG_PATH="$DIST_DIR/$PRODUCT_NAME $VERSION.dmg"

cd "$ROOT_DIR"

echo "Building signed release app..."
CONFIGURATION="$CONFIGURATION" SIGN_IDENTITY="$SIGN_IDENTITY" "$ROOT_DIR/Scripts/build_app.sh" >/dev/null

rm -rf "$DIST_DIR"
mkdir -p "$DIST_DIR"

echo "Creating DMG..."
hdiutil create \
    -volname "$PRODUCT_NAME" \
    -srcfolder "$APP_DIR" \
    -ov \
    -format UDZO \
    "$DMG_PATH" >/dev/null

echo "Signing DMG..."
codesign --force --sign "$SIGN_IDENTITY" "$DMG_PATH" >/dev/null

if [[ -n "$NOTARY_PROFILE" ]]; then
    echo "Submitting DMG for notarization with keychain profile '$NOTARY_PROFILE'..."
    xcrun notarytool submit "$DMG_PATH" --keychain-profile "$NOTARY_PROFILE" --wait
    echo "Stapling notarization ticket..."
    xcrun stapler staple "$DMG_PATH"
else
    echo "DMG created without notarization: $DMG_PATH"
    echo "To notarize, rerun with: SIGN_IDENTITY=\"$SIGN_IDENTITY\" NOTARY_PROFILE=\"your-notarytool-profile\" ./Scripts/build_dmg.sh"
fi

echo "$DMG_PATH"
