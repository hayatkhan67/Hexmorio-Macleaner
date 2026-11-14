#!/bin/bash
# Builds StorageOptimizer in release mode and assembles it into a real
# double-clickable .app bundle (no Xcode project needed - this is Swift
# Package Manager's executable output wrapped in a standard bundle layout).
set -euo pipefail
cd "$(dirname "$0")"

APP_NAME="Hexmorio Macleaner"
BUNDLE_ID="com.hexmorio.macleaner"
APP_DIR="dist/${APP_NAME}.app"

echo "==> Building release binary..."
swift build -c release

BIN_PATH=$(swift build -c release --show-bin-path)/StorageOptimizer

echo "==> Assembling ${APP_DIR}..."
rm -rf "dist"
mkdir -p "${APP_DIR}/Contents/MacOS"
mkdir -p "${APP_DIR}/Contents/Resources"

cp "${BIN_PATH}" "${APP_DIR}/Contents/MacOS/StorageOptimizer"
cp "Info.plist" "${APP_DIR}/Contents/Info.plist"

if [ -f "AppIcon.icns" ]; then
    cp "AppIcon.icns" "${APP_DIR}/Contents/Resources/AppIcon.icns"
fi

echo "==> Ad-hoc code signing..."
codesign --force --deep --sign - "${APP_DIR}"

echo "==> Done: ${APP_DIR}"
echo "    Launch with: open \"${APP_DIR}\""
