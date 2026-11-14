#!/bin/bash
# Packages the already-built dist/Hexmorio Macleaner.app into a distributable,
# double-clickable .dmg with a drag-to-Applications shortcut. Run build.sh
# first - this script does not rebuild the app itself.
set -euo pipefail
cd "$(dirname "$0")"

APP_NAME="Hexmorio Macleaner"
APP_PATH="dist/${APP_NAME}.app"
DMG_PATH="dist/${APP_NAME}.dmg"
STAGING_DIR="dist/.dmg-staging"

if [ ! -d "${APP_PATH}" ]; then
    echo "error: ${APP_PATH} not found - run ./build.sh first" >&2
    exit 1
fi

echo "==> Staging dmg contents..."
rm -rf "${STAGING_DIR}" "${DMG_PATH}"
mkdir -p "${STAGING_DIR}"
cp -R "${APP_PATH}" "${STAGING_DIR}/"
ln -s /Applications "${STAGING_DIR}/Applications"

echo "==> Creating ${DMG_PATH}..."
hdiutil create -volname "${APP_NAME}" -srcfolder "${STAGING_DIR}" -ov -format UDZO "${DMG_PATH}"

rm -rf "${STAGING_DIR}"
echo "==> Done: ${DMG_PATH}"
