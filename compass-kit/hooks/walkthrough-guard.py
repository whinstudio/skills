#!/usr/bin/env python3
"""Checks that a Maestro flow closes the keyboard after typing, before it taps anything else.

PostToolUse hook for .maestro/*.yaml. The open keyboard covers the lower part of the screen, so a tap
on a control after inputText can miss and stall the walkthrough video (cmp-maestro: tap the screen's
TITLE tag to close it; never hideKeyboard). Exit 2 + stderr sends the reason back to the model.
Anything unexpected (bad input, unreadable file) exits 0: this guard must never block work.
"""
from __future__ import annotations

import json
import re
import sys

STEP = re.compile(r"^- ")
COMMAND = re.compile(r"^- ([A-Za-z]+)")
ID = re.compile(r"""\bid:\s*["']?([A-Za-z0-9_.\-]+)""")

ADVICE = (
    "After inputText, close the keyboard by tapping the screen's non-interactive TITLE tag "
    "(an id ending in _title, e.g. `- tapOn:\\n    id: \"recipe_detail_title\"`) before the next tap. "
    "Clearing a search field keeps the focus, so the keyboard stays open. Never use hideKeyboard. "
    "See the cmp-maestro skill, section 3."
)


def steps(text: str) -> list[tuple[int, str, str]]:
    """Top-level steps as (line number, command, step text); comments and nested lines join their step."""
    result: list[tuple[int, str, list[str]]] = []
    for number, line in enumerate(text.splitlines(), start=1):
        if STEP.match(line):
            match = COMMAND.match(line)
            result.append((number, match.group(1) if match else "", [line]))
        elif result and line.startswith((" ", "\t")):
            result[-1][2].append(line)
    return [(number, command, "\n".join(lines)) for number, command, lines in result]


def check(text: str) -> str | None:
    problems = []
    typed_at = None
    for number, command, body in steps(text):
        if command == "hideKeyboard":
            problems.append(f"line {number}: hideKeyboard fails on iOS number keyboards")
        elif command.startswith("input"):
            typed_at = typed_at or number
        elif command == "tapOn" and typed_at is not None:
            match = ID.search(body)
            if not (match and match.group(1).endswith("_title")):
                target = match.group(1) if match else body.split(":", 1)[-1].strip()
                problems.append(
                    f"line {number}: taps {target} while the keyboard from line {typed_at} is still open"
                )
            typed_at = None
    if not problems:
        return None
    return "Walkthrough flow: " + "; ".join(problems) + ". " + ADVICE


def main() -> int:
    try:
        event = json.load(sys.stdin)
        path = (event.get("tool_input", {}) or {}).get("file_path", "") or ""
        if "/.maestro/" not in path or not path.endswith((".yaml", ".yml")):
            return 0
        with open(path, encoding="utf-8") as flow:
            reason = check(flow.read())
    except Exception:
        return 0
    if reason:
        print(reason, file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
