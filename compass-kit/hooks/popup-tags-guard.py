#!/usr/bin/env python3
"""Checks that a dropdown menu, dialog or bottom sheet with test tags also turns on testTagsAsResourceId.

PostToolUse hook for .kt files. A DropdownMenu, Dialog, AlertDialog, ModalBottomSheet or Popup opens in
its own window, which does not inherit testTagsAsResourceId from the root Scaffold, so on Android the
walkthrough's `id:` selectors match none of its tags and the video stops (cmp-maestro, section 1).
Exit 2 + stderr sends the reason back to the model.
Anything unexpected (bad input, unreadable file) exits 0: this guard must never block work.
"""
from __future__ import annotations

import json
import re
import sys

POPUP = re.compile(
    r"(?<![\w.])(DropdownMenu|ExposedDropdownMenu|AlertDialog|BasicAlertDialog|Dialog|ModalBottomSheet|Popup)\s*\("
)
DECLARATION = re.compile(r"\bfun\s+(<[^>]*>\s*)?$")

ADVICE = (
    "A popup opens in its own window, so the root Scaffold's testTagsAsResourceId does not reach it and "
    "Maestro's `id:` matches none of its tags on Android. Apply `Modifier.testTagsAsResourceId()` "
    "(core/presentation) to the popup: `DropdownMenu(modifier = Modifier.testTagsAsResourceId(), ...)`, "
    "`AlertDialog(modifier = ...)`, or the content root of a Dialog/ModalBottomSheet. "
    "See the cmp-maestro skill, section 1."
)


def code_only(text: str) -> str:
    """The text with comments and string/char literals blanked (same length, newlines kept)."""
    out = list(text)
    i, n = 0, len(text)

    def blank(start: int, end: int) -> None:
        for k in range(start, min(end, n)):
            if out[k] != "\n":
                out[k] = " "

    while i < n:
        if text.startswith("//", i):
            end = text.find("\n", i)
            end = n if end == -1 else end
            blank(i, end)
            i = end
        elif text.startswith("/*", i):
            end = text.find("*/", i + 2)
            end = n if end == -1 else end + 2
            blank(i, end)
            i = end
        elif text.startswith('"""', i):
            end = text.find('"""', i + 3)
            end = n if end == -1 else end + 3
            blank(i + 3, end - 3)
            i = end
        elif text[i] in "\"'":
            quote, j = text[i], i + 1
            while j < n and text[j] != quote and text[j] != "\n":
                j += 2 if text[j] == "\\" else 1
            blank(i + 1, j)
            i = j + 1
        else:
            i += 1
    return "".join(out)


def matching(code: str, start: int, open_char: str, close_char: str) -> int:
    """Index just past the bracket that closes the one at [start], or len(code)."""
    depth = 0
    for k in range(start, len(code)):
        if code[k] == open_char:
            depth += 1
        elif code[k] == close_char:
            depth -= 1
            if depth == 0:
                return k + 1
    return len(code)


def check(text: str) -> str | None:
    code = code_only(text)
    problems = []
    for match in POPUP.finditer(code):
        line_start = code.rfind("\n", 0, match.start()) + 1
        if DECLARATION.search(code[line_start:match.start()]):
            continue
        end = matching(code, match.end() - 1, "(", ")")
        rest = code[end:]
        stripped = rest.lstrip()
        if stripped.startswith("{"):
            brace = end + (len(rest) - len(stripped))
            end = matching(code, brace, "{", "}")
        span = code[match.start():end]
        if "testTag(" in span and "testTagsAsResourceId" not in span:
            number = code.count("\n", 0, match.start()) + 1
            problems.append(f"line {number}: {match.group(1)} has testTags but no testTagsAsResourceId")
    if not problems:
        return None
    return "Popup test tags: " + "; ".join(problems) + ". " + ADVICE


def main() -> int:
    try:
        event = json.load(sys.stdin)
        path = (event.get("tool_input", {}) or {}).get("file_path", "") or ""
        if not path.endswith(".kt") or "/src/test" in path or "Test/" in path:
            return 0
        with open(path, encoding="utf-8") as source:
            reason = check(source.read())
    except Exception:
        return 0
    if reason:
        print(reason, file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
