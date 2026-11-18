#!/bin/bash
# Builds StorageOptimizer in release mode and assembles it into a real
# double-clickable .app bundle (no Xcode project needed - this is Swift
# Package Manager's executable output wrapped in a standard bundle layout).
# Usage: ./build.sh [--universal]
set -euo pipefail
cd "$(dirname "$0")"

APP_NAME="Hexmorio Macleaner"
BUNDLE_ID="com.hexmorio.macleaner"
APP_DIR="dist/${APP_NAME}.app"

# Pass --universal to build a fat (arm64 + x86_64) binary that runs natively
# on both Apple Silicon and Intel Macs, regardless of which Mac built it.
# Local dev builds default to the host's single architecture (faster).
# (Plain string, not a bash array: macOS ships bash 3.2, where `"${arr[@]}"`
# on an empty array trips `set -u`'s unbound-variable check.)
ARCH_FLAGS=""
if [ "${1:-}" = "--universal" ]; then
    ARCH_FLAGS="--arch arm64 --arch x86_64"
fi

echo "==> Building release binary..."
swift build -c release $ARCH_FLAGS

BIN_PATH=$(swift build -c release $ARCH_FLAGS --show-bin-path)/StorageOptimizer

echo "==> Assembling ${APP_DIR}..."
rm -rf "dist"
mkdir -p "${APP_DIR}/Contents/MacOS"
mkdir -p "${APP_DIR}/Contents/Resources"

cp "${BIN_PATH}" "${APP_DIR}/Contents/MacOS/StorageOptimizer"
cp "Info.plist" "${APP_DIR}/Contents/Info.plist"

if [ -f "AppIcon.icns" ]; then
    cp "AppIcon.icns" "${APP_DIR}/Contents/Resources/AppIcon.icns"
fi

# Sign with a real certificate so the app keeps the same code identity across
# builds: macOS ties granted permissions (Full Disk Access, Desktop/Documents/
# Downloads) to that identity. Ad-hoc signing makes every build look like a
# brand-new app, so users get re-prompted after every update.
# Override with: SIGN_IDENTITY="Apple Development: Name (TEAMID)" ./build.sh
pick_identity() {
    security find-identity -v -p codesigning | grep "\"$1:" | head -1 | sed -E 's/^[^"]*"(.*)"$/\1/' || true
}
SIGN_IDENTITY="${SIGN_IDENTITY:-$(pick_identity 'Developer ID Application')}"
SIGN_IDENTITY="${SIGN_IDENTITY:-$(pick_identity 'Apple Development')}"

if [ -n "${SIGN_IDENTITY}" ]; then
    echo "==> Code signing with: ${SIGN_IDENTITY}"
    echo "    (always release with this same identity, or users lose granted permissions)"
    codesign --force --deep --sign "${SIGN_IDENTITY}" "${APP_DIR}"
else
    echo "==> WARNING: no signing certificate found - falling back to ad-hoc signing."
    echo "    Users will be re-asked for permissions after every update."
    codesign --force --deep --sign - "${APP_DIR}"
fi

echo "==> Done: ${APP_DIR}"
echo "    Launch with: open \"${APP_DIR}\""
