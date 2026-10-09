#!/bin/bash
# Run after changing interface text in the code. Re-reads every string from the sources into
# Resources/Localizable.xcstrings, keeps existing translations and reports what is missing.
set -euo pipefail
cd "$(dirname "$0")/.."

DATA="$PWD/build/stringsdata"
rm -rf "$DATA" build/strings-build
mkdir -p "$DATA"
swift build -c release --build-path build/strings-build \
    -Xswiftc -emit-localized-strings -Xswiftc -emit-localized-strings-path -Xswiftc "$DATA" >/dev/null
xcrun xcstringstool sync Resources/Localizable.xcstrings --stringsdata "$DATA"/*.stringsdata
python3 Scripts/check_strings.py
