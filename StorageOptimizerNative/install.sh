#!/bin/bash
# Installs or updates Hexmorio Macleaner from the latest GitHub release:
#   curl -fsSL https://github.com/hayatkhan67/Hexmorio-Macleaner/releases/latest/download/install.sh | bash
set -euo pipefail

REPO="hayatkhan67/Hexmorio-Macleaner"
APP_NAME="Hexmorio Macleaner"
BUNDLE_ID="com.hexmorio.macleaner"
ZIP_URL="https://github.com/${REPO}/releases/latest/download/Hexmorio-Macleaner.zip"
DEST_DIR="/Applications"
DEST="${DEST_DIR}/${APP_NAME}.app"

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

echo "==> Downloading the latest ${APP_NAME}..."
curl -fL --progress-bar "$ZIP_URL" -o "$TMP/app.zip"
/usr/bin/ditto -x -k "$TMP/app.zip" "$TMP"
if [ ! -d "$TMP/${APP_NAME}.app" ]; then
    echo "error: the download did not contain ${APP_NAME}.app" >&2
    exit 1
fi

if pgrep -xq StorageOptimizer; then
    echo "==> Quitting the running app..."
    osascript -e "quit app id \"${BUNDLE_ID}\"" >/dev/null 2>&1 || true
    sleep 2
    pkill -x StorageOptimizer 2>/dev/null || true
fi

SUDO=""
if [ ! -w "$DEST_DIR" ]; then
    echo "==> ${DEST_DIR} needs administrator rights - you may be asked for your password."
    SUDO="sudo"
fi

echo "==> Installing to ${DEST}..."
$SUDO rm -rf "$DEST"
$SUDO /usr/bin/ditto "$TMP/${APP_NAME}.app" "$DEST"
$SUDO /usr/bin/xattr -dr com.apple.quarantine "$DEST" 2>/dev/null || true

VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$DEST/Contents/Info.plist" 2>/dev/null || echo "?")
echo "==> Installed ${APP_NAME} ${VERSION}"
open "$DEST"
