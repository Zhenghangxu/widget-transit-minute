#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIGURATION="${CONFIGURATION:-debug}"
PRODUCT_NAME="Transit Minute"
EXECUTABLE_NAME="TransitMinute"
APP_DIR="$ROOT_DIR/.build/app/$PRODUCT_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
PLIST_SOURCE="$ROOT_DIR/Packaging/Info.plist"
ENTITLEMENTS_SOURCE="$ROOT_DIR/Packaging/TransitMinute.entitlements"
SIGN_IDENTITY="${SIGN_IDENTITY:--}"

cd "$ROOT_DIR"

validate_sign_identity() {
    if [[ "$SIGN_IDENTITY" == "-" ]]; then
        return
    fi

    if ! security find-identity -v -p codesigning | grep -F -- "$SIGN_IDENTITY" >/dev/null; then
        echo "Signing identity not found: $SIGN_IDENTITY" >&2
        echo "Available code signing identities:" >&2
        security find-identity -v -p codesigning >&2
        exit 1
    fi
}

validate_sign_identity

swift build -c "$CONFIGURATION" --product "$EXECUTABLE_NAME"

BUILD_BINARY="$ROOT_DIR/.build/$CONFIGURATION/$EXECUTABLE_NAME"
if [[ ! -x "$BUILD_BINARY" ]]; then
    echo "Expected executable not found: $BUILD_BINARY" >&2
    exit 1
fi

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

cp "$BUILD_BINARY" "$MACOS_DIR/$EXECUTABLE_NAME"
cp "$PLIST_SOURCE" "$CONTENTS_DIR/Info.plist"
printf 'APPL????' > "$CONTENTS_DIR/PkgInfo"

plutil -lint "$CONTENTS_DIR/Info.plist" >/dev/null

if command -v codesign >/dev/null; then
    codesign --force --sign "$SIGN_IDENTITY" --entitlements "$ENTITLEMENTS_SOURCE" "$APP_DIR" >/dev/null
fi

echo "$APP_DIR"
