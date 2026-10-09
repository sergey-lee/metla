#!/usr/bin/env python3
"""Adds translations to Resources/Localizable.xcstrings from a JSON file:
{"<source key>": {"en": "...", "es": "...", ...}}. Existing translations are replaced.
usage: add_translations.py <translations.json>"""
import json
import sys

path = "Resources/Localizable.xcstrings"
catalog = json.load(open(path, encoding="utf-8"))
additions = json.load(open(sys.argv[1], encoding="utf-8"))
for key, languages in additions.items():
    if key not in catalog["strings"]:
        sys.exit(f"not in the catalog (run Scripts/sync_strings.sh first): {key!r}")
    entry = catalog["strings"][key]
    localizations = entry.setdefault("localizations", {})
    for language, text in languages.items():
        localizations[language] = {"stringUnit": {"state": "translated", "value": text}}
json.dump(catalog, open(path, "w", encoding="utf-8"), ensure_ascii=False, indent=2, sort_keys=True)
print(f"added {len(additions)} strings")
