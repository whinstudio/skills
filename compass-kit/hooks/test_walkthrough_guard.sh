#!/bin/sh
# Behavior test for walkthrough-guard.py. Run: sh compass-kit/hooks/test_walkthrough_guard.sh
HOOK="$(dirname "$0")/walkthrough-guard.py"
DIR="$(mktemp -d)"; mkdir -p "$DIR/.maestro"
FLOW="$DIR/.maestro/walkthrough.yaml"
fail=0
expect() { # $1 = expected exit code, $2 = description, $3 = flow content (or "" to skip writing)
  printf '%s' "$3" > "$FLOW"
  printf '{"tool_name":"Write","tool_input":{"file_path":"%s"}}' "$FLOW" | python3 "$HOOK" >/dev/null 2>&1; code=$?
  if [ "$code" != "$1" ]; then echo "FAIL ($code != $1): $2"; fail=1; else echo "ok: $2"; fi
}

expect 0 "title tap after input is allowed" 'appId: a
---
- tapOn:
    id: "recipe_detail_note_field"
- inputText: "Less salt"
# Close the keyboard on both platforms: tap the non-interactive title.
- tapOn:
    id: "recipe_detail_title"
- tapOn:
    id: "recipe_detail_save"
'
expect 2 "tap on a control right after input is blocked" 'appId: a
---
- tapOn:
    id: "notelist_search"
- inputText: "milk"
- tapOn:
    id: "notelist_clear_search"
- tapOn:
    id: "notelist_new_note"
'
expect 0 "waits and comments between input and title tap are allowed" 'appId: a
---
- inputText: "milk"
- extendedWaitUntil:
    visible:
      id: "walkthrough_pause"
    timeout: 1500
    optional: true
# pause
- tapOn:
    id: notelist_title
- tapOn:
    id: "notelist_new_note"
'
expect 2 "second field tapped without closing the keyboard is blocked" 'appId: a
---
- tapOn:
    id: "newnote_title_field"
- inputText: "Groceries"
- tapOn:
    id: "newnote_body_field"
- inputText: "Milk"
- tapOn:
    id: "newnote_title"
'
expect 0 "flow ending after input is allowed" 'appId: a
---
- inputText: "milk"
'
expect 2 "inline tap selector after input is blocked" 'appId: a
---
- inputRandomEmail
- tapOn: {id: "signup_submit"}
'
expect 2 "hideKeyboard is blocked" 'appId: a
---
- inputText: "milk"
- hideKeyboard
'
expect 0 "flow without input is allowed" 'appId: a
---
- launchApp:
    clearState: true
- tapOn:
    id: "home_start"
'
printf '{"tool_name":"Write","tool_input":{"file_path":"%s/README.md"}}' "$DIR" | python3 "$HOOK" >/dev/null 2>&1
[ $? = 0 ] && echo "ok: other files are ignored" || { echo "FAIL: other files are ignored"; fail=1; }
printf '{"tool_name":"Write","tool_input":{"file_path":"%s/.maestro/missing.yaml"}}' "$DIR" | python3 "$HOOK" >/dev/null 2>&1
[ $? = 0 ] && echo "ok: a missing file fails open" || { echo "FAIL: a missing file fails open"; fail=1; }
printf 'bozuk json' | python3 "$HOOK" >/dev/null 2>&1
[ $? = 0 ] && echo "ok: broken input fails open" || { echo "FAIL: broken input fails open"; fail=1; }

# The settings.json command: a missing script must not block every tool.
COMMAND="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["hooks"]["PostToolUse"][0]["hooks"][0]["command"])' "$(dirname "$0")/../settings.json")"
PROJECT="$(mktemp -d)"; mkdir -p "$PROJECT/.claude/hooks"
printf -- '- inputText: "milk"\n- tapOn:\n    id: "notelist_new_note"\n' > "$FLOW"
printf '{"tool_name":"Write","tool_input":{"file_path":"%s"}}' "$FLOW" | CLAUDE_PROJECT_DIR="$PROJECT" /bin/sh -c "$COMMAND" >/dev/null 2>&1
[ $? = 0 ] && echo "ok: missing script passes" || { echo "FAIL: missing script passes"; fail=1; }
cp "$HOOK" "$PROJECT/.claude/hooks/walkthrough-guard.py"
printf '{"tool_name":"Write","tool_input":{"file_path":"%s"}}' "$FLOW" | CLAUDE_PROJECT_DIR="$PROJECT" /bin/sh -c "$COMMAND" >/dev/null 2>&1
[ $? = 2 ] && echo "ok: installed script blocks a bad flow" || { echo "FAIL: installed script blocks a bad flow"; fail=1; }

rm -rf "$DIR" "$PROJECT"
exit $fail
