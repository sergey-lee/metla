#!/usr/bin/env python3
"""Checks Resources/Localizable.xcstrings: every string must be translated into every language,
and every translation must use the same placeholders as the source string."""
import json
import re
import sys

LANGUAGES = ["en", "es", "de", "fr", "pt-BR", "it", "zh-Hans", "ja", "ko", "hi", "ar"]
PLACEHOLDER = re.compile(r"%(?:\d+\$)?(lld|@)")


def texts(localization):
    """All texts of one localization: a single string or every plural form."""
    if "stringUnit" in localization:
        return [localization["stringUnit"]["value"]]
    return [form["stringUnit"]["value"] for form in localization["variations"]["plural"].values()]


def main():
    catalog = json.load(open("Resources/Localizable.xcstrings", encoding="utf-8"))
    problems = []
    for key, entry in catalog["strings"].items():
        if entry.get("extractionState") == "stale":
            problems.append(f"no longer used in code: {key!r}")
        expected = sorted(PLACEHOLDER.findall(key))
        localizations = entry.get("localizations", {})
        for language in LANGUAGES:
            if language not in localizations:
                problems.append(f"[{language}] missing: {key!r}")
                continue
            for text in texts(localizations[language]):
                if sorted(PLACEHOLDER.findall(text)) != expected:
                    problems.append(f"[{language}] placeholders differ: {key!r} -> {text!r}")
    for problem in problems:
        print(problem)
    print(f"{len(catalog['strings'])} strings, {len(LANGUAGES) + 1} languages, {len(problems)} problems")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
