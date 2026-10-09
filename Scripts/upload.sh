#!/bin/bash
# Archives the Mac App Store build and uploads it to App Store Connect through the Xcode account.
# Raise CURRENT_PROJECT_VERSION in project.yml before every new upload.
set -euo pipefail
cd "$(dirname "$0")/.."
xcodegen generate >/dev/null
ARCHIVE="build/Metla.xcarchive"
rm -rf "$ARCHIVE" build/export
xcodebuild -project Metla.xcodeproj -scheme Metla -configuration Release \
    -archivePath "$ARCHIVE" -allowProvisioningUpdates archive
xcodebuild -exportArchive -archivePath "$ARCHIVE" -exportOptionsPlist Store/ExportOptions.plist \
    -exportPath build/export -allowProvisioningUpdates
