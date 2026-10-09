#!/bin/bash
# Builds, Developer-ID signs, packages a DMG, and notarizes Metla for
# distribution outside the App Store.
#
# Prerequisites (one-time):
#   • Apple ID added in Xcode → Settings → Accounts (Team 4GZ4AH8Z6M).
#   • A "Developer ID Application" certificate in your login keychain.
#   • Notary credentials stored once:
#       xcrun notarytool store-credentials redline-notary \
#         --apple-id "you@example.com" --team-id 4GZ4AH8Z6M \
#         --password "app-specific-password"
#
# Usage:
#   ./release.sh                      # archive → Developer-ID export → DMG → notarize → staple
#   SKIP_NOTARIZE=1 ./release.sh      # everything except notarization (local validation)
#   NOTARY_PROFILE=myprofile ./release.sh

set -euo pipefail
cd "$(dirname "$0")"

APP_NAME="Metla"
SCHEME="MetlaDirect"
ARCHIVE="build/MetlaDirect.xcarchive"
EXPORT_DIR="build/export-direct"
APP="$EXPORT_DIR/$APP_NAME.app"
DMG="dist/$APP_NAME.dmg"
NOTARY_PROFILE="${NOTARY_PROFILE:-redline-notary}"

echo "▸ Regenerating project…"
xcodegen generate >/dev/null

echo "▸ Archiving…"
rm -rf "$ARCHIVE" "$EXPORT_DIR"
xcodebuild archive \
  -project Metla.xcodeproj -scheme "$SCHEME" -configuration Release \
  -destination 'generic/platform=macOS' \
  -archivePath "$ARCHIVE" \
  -allowProvisioningUpdates >/dev/null

echo "▸ Exporting (Developer ID)…"
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE" \
  -exportOptionsPlist Store/ExportOptions-direct.plist \
  -exportPath "$EXPORT_DIR" \
  -allowProvisioningUpdates >/dev/null

echo "▸ Verifying signature…"
codesign --verify --deep --strict --verbose=2 "$APP"

echo "▸ Building DMG…"
mkdir -p dist
STAGING="$(mktemp -d)"
cp -R "$APP" "$STAGING/"
ln -s /Applications "$STAGING/Applications"
rm -f "$DMG"
hdiutil create -volname "$APP_NAME" -srcfolder "$STAGING" -ov -format UDZO "$DMG" >/dev/null
rm -rf "$STAGING"

# Sign the DMG itself with Developer ID so Gatekeeper accepts it on open.
DEV_ID_APP="$(security find-identity -v -p codesigning \
  | grep 'Developer ID Application' | head -1 | sed -E 's/.*"(Developer ID Application: .*)"/\1/')"
codesign --force --timestamp --sign "$DEV_ID_APP" "$DMG"
echo "✓ $DMG (signed)"

if [ "${SKIP_NOTARIZE:-}" = "1" ]; then
  echo "▸ SKIP_NOTARIZE=1 — signed DMG built, not notarized."
  exit 0
fi

echo "▸ Notarizing…"
xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait

echo "▸ Stapling…"
xcrun stapler staple "$DMG"
xcrun stapler validate "$DMG"
echo "✓ Notarized & stapled: $DMG — upload this to GitHub Releases."
