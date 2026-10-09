#!/bin/bash
# Builds build/Metla.app. Usage: Scripts/build.sh
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release

# The icon is rebuilt whenever the logo changes.
if [ ! -f Resources/AppIcon.icns ] || [ Resources/Logo.png -nt Resources/AppIcon.icns ]; then
    rm -rf build/AppIcon.iconset
    swift Scripts/make_icon.swift Resources/Logo.png build/AppIcon.iconset
    iconutil -c icns build/AppIcon.iconset -o Resources/AppIcon.icns
fi

APP="build/Metla.app"
RESOURCES="$APP/Contents/Resources"
mkdir -p "$APP/Contents/MacOS" "$RESOURCES"
cp "$(swift build -c release --show-bin-path)/Metla" "$APP/Contents/MacOS/Metla"
strip -x "$APP/Contents/MacOS/Metla"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp Resources/AppIcon.icns "$RESOURCES/AppIcon.icns"

# Translations: one .lproj folder per language, compiled from the string catalogs.
find "$RESOURCES" -maxdepth 1 -name "*.lproj" -exec rm -rf {} +
xcrun xcstringstool compile Resources/Localizable.xcstrings --output-directory "$RESOURCES"
xcrun xcstringstool compile Resources/InfoPlist.xcstrings --output-directory "$RESOURCES"
python3 Scripts/source_strings.py "$RESOURCES"

codesign --force --sign - "$APP" >/dev/null 2>&1

echo "Готово: $(pwd)/$APP ($(du -sh "$APP" | cut -f1))"
