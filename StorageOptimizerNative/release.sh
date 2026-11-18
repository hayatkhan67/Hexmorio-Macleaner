#!/bin/bash
# Builds a universal, signed release and publishes it to GitHub Releases.
# Installed apps pick it up through their built-in updater, and anyone can
# install/update with the install.sh one-liner.
# Usage: ./release.sh <version> ["release notes"]     e.g. ./release.sh 1.1.0
set -euo pipefail
cd "$(dirname "$0")"

VERSION="${1:?usage: ./release.sh <version> [\"release notes\"]}"
NOTES="${2:-Hexmorio Macleaner ${VERSION}}"
APP_NAME="Hexmorio Macleaner"
APP_PATH="dist/${APP_NAME}.app"
ZIP="dist/Hexmorio-Macleaner.zip"
DMG="dist/Hexmorio-Macleaner.dmg"
REPO=$(/usr/libexec/PlistBuddy -c "Print HexmorioUpdateRepo" Info.plist)

if ! command -v gh >/dev/null; then
    echo "error: GitHub CLI not found - install it with: brew install gh" >&2
    exit 1
fi

echo "==> Setting version ${VERSION}"
/usr/libexec/PlistBuddy -c "Set CFBundleShortVersionString ${VERSION}" Info.plist
/usr/libexec/PlistBuddy -c "Set CFBundleVersion ${VERSION}" Info.plist

./build.sh --universal

# Ad-hoc builds change identity every time: users would be re-asked for every
# permission, and the in-app updater rejects builds from a different signer.
if codesign -dv "${APP_PATH}" 2>&1 | grep -q "Signature=adhoc"; then
    echo "error: refusing to release an ad-hoc signed build - install a signing certificate first" >&2
    exit 1
fi

./package-dmg.sh
mv "dist/${APP_NAME}.dmg" "${DMG}"
/usr/bin/ditto -c -k --keepParent "${APP_PATH}" "${ZIP}"

echo "==> Publishing v${VERSION} to ${REPO}..."
gh release create "v${VERSION}" "${ZIP}" "${DMG}" install.sh \
    --repo "${REPO}" --title "v${VERSION}" --notes "${NOTES}"

echo "==> Released v${VERSION}. Remember to commit the version bump in Info.plist."
echo "    Users can install or update with:"
echo "    curl -fsSL https://github.com/${REPO}/releases/latest/download/install.sh | bash"
