#!/usr/bin/env python3
"""Writes the Localizable.strings table for the catalog's source language.

The string catalog stores the source text only as keys, so the compiler emits no table for it.
Without a table, macOS falls back to the development language of the bundle and the source
language would show up in English. Usage: source_strings.py <Resources folder of the app>"""
import json
import subprocess
import sys


def main(resources):
    catalog = json.load(open("Resources/Localizable.xcstrings", encoding="utf-8"))
    language = catalog["sourceLanguage"]
    table = {}
    for key, entry in catalog["strings"].items():
        own = entry.get("localizations", {}).get(language, {})
        if "variations" in own:
            continue  # plural forms live in Localizable.stringsdict
        table[key] = own.get("stringUnit", {}).get("value", key)
    target = f"{resources}/{language}.lproj/Localizable.strings"
    subprocess.run(
        ["plutil", "-convert", "binary1", "-o", target, "-"],
        input=json.dumps(table, ensure_ascii=False).encode("utf-8"),
        check=True,
    )


if __name__ == "__main__":
    main(sys.argv[1])
