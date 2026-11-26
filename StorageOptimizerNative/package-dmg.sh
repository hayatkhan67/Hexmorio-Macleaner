#!/bin/bash
# Packages the already-built dist/Hexmorio Macleaner.app into a distributable
# .dmg that opens as a classic installer window: the app on the left, an
# Applications shortcut on the right, and a "Drag to install" background.
# Run build.sh first - this script does not rebuild the app itself.
set -euo pipefail
cd "$(dirname "$0")"

APP_NAME="Hexmorio Macleaner"
APP_PATH="dist/${APP_NAME}.app"
DMG_PATH="dist/${APP_NAME}.dmg"
RW_DMG="dist/.${APP_NAME}-rw.dmg"
STAGING_DIR="dist/.dmg-staging"
BACKGROUND="Resources/dmg-background.tiff"
VOLUME="/Volumes/${APP_NAME}"

if [ ! -d "${APP_PATH}" ]; then
    echo "error: ${APP_PATH} not found - run ./build.sh first" >&2
    exit 1
fi

echo "==> Staging dmg contents..."
rm -rf "${STAGING_DIR}" "${DMG_PATH}" "${RW_DMG}"
mkdir -p "${STAGING_DIR}/.background"
cp -R "${APP_PATH}" "${STAGING_DIR}/"
ln -s /Applications "${STAGING_DIR}/Applications"
cp "${BACKGROUND}" "${STAGING_DIR}/.background/background.tiff"

# A volume with the same name already mounted would make Finder style the wrong window.
if [ -d "${VOLUME}" ]; then
    hdiutil detach "${VOLUME}" -force >/dev/null 2>&1 || true
fi

echo "==> Creating writable image..."
# -srcfolder sizes the image to fit exactly; leave room for the volume icon and
# Finder's layout file (the final compressed image drops the free space again).
SIZE_MB=$(( $(du -sm "${STAGING_DIR}" | cut -f1) + 20 ))
hdiutil create -volname "${APP_NAME}" -srcfolder "${STAGING_DIR}" -fs HFS+ -format UDRW \
    -size "${SIZE_MB}m" -ov "${RW_DMG}" >/dev/null
ATTACH=$(hdiutil attach -readwrite -noverify -noautoopen "${RW_DMG}")
DEVICE=$(echo "${ATTACH}" | awk '/Apple_HFS/ {print $1; exit}')
VOLUME=$(echo "${ATTACH}" | awk -F'\t' '/Apple_HFS/ {print $NF; exit}')

echo "==> Laying out the installer window (Finder may ask for permission once)..."
if ! osascript <<EOF
tell application "Finder"
    tell disk "${APP_NAME}"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {200, 120, 860, 548}
        set viewOptions to the icon view options of container window
        set arrangement of viewOptions to not arranged
        set icon size of viewOptions to 128
        set text size of viewOptions to 13
        set background picture of viewOptions to file ".background:background.tiff"
        set position of item "${APP_NAME}.app" of container window to {170, 190}
        set position of item "Applications" of container window to {490, 190}
        update without registering applications
        delay 1
        close
    end tell
end tell
EOF
then
    echo "    WARNING: Finder layout failed (Automation permission denied?)."
    echo "    The dmg still works, but opens as a plain folder window."
fi

# Show the app icon on the mounted disk. Done after the Finder step, which deletes
# .VolumeIcon.icns and clears the custom-icon flag; hdiutil -srcfolder skips it too.
cp AppIcon.icns "${VOLUME}/.VolumeIcon.icns"
if xcrun --find SetFile >/dev/null 2>&1; then
    xcrun SetFile -a C "${VOLUME}"
fi

# Open the window automatically when the dmg is mounted (Intel only; Apple Silicon
# Finder opens disk image windows on its own).
bless --folder "${VOLUME}" --openfolder "${VOLUME}" 2>/dev/null || true
chmod -Rf go-w "${VOLUME}" 2>/dev/null || true
sync
hdiutil detach "${DEVICE}" >/dev/null 2>&1 || hdiutil detach "${DEVICE}" -force >/dev/null

echo "==> Compressing ${DMG_PATH}..."
hdiutil convert "${RW_DMG}" -format UDZO -imagekey zlib-level=9 -o "${DMG_PATH}" >/dev/null
rm -rf "${STAGING_DIR}" "${RW_DMG}"
echo "==> Done: ${DMG_PATH}"
