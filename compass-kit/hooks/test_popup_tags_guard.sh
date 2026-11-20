#!/bin/sh
# Behavior test for popup-tags-guard.py. Run: sh compass-kit/hooks/test_popup_tags_guard.sh
HOOK="$(dirname "$0")/popup-tags-guard.py"
DIR="$(mktemp -d)"; mkdir -p "$DIR/src/commonMain"
FILE="$DIR/src/commonMain/Screen.kt"
fail=0
expect() { # $1 = expected exit code, $2 = description, $3 = file content
  printf '%s' "$3" > "$FILE"
  printf '{"tool_name":"Write","tool_input":{"file_path":"%s"}}' "$FILE" | python3 "$HOOK" >/dev/null 2>&1; code=$?
  if [ "$code" != "$1" ]; then echo "FAIL ($code != $1): $2"; fail=1; else echo "ok: $2"; fi
}

expect 2 "tagged dropdown items without the modifier are blocked" '
DropdownMenu(
    expanded = expanded,
    onDismissRequest = { expanded = false }
) {
    IngredientUnit.entries.forEach { option ->
        DropdownMenuItem(
            text = { Text(option.name) },
            onClick = { onSelect(option) },
            modifier = Modifier.testTag(EditTestTags.unitOption(option))
        )
    }
}
'
expect 0 "dropdown with the modifier is allowed" '
DropdownMenu(
    expanded = expanded,
    onDismissRequest = { expanded = false },
    modifier = Modifier.testTagsAsResourceId()
) {
    DropdownMenuItem(text = { Text("g") }, onClick = {}, modifier = Modifier.testTag("edit_unit_g"))
}
'
expect 0 "a tagged opener next to an untagged dropdown is allowed" '
Box {
    OutlinedButton(onClick = { expanded = true }, modifier = Modifier.testTag("edit_unit")) { Text("g") }
    DropdownMenu(expanded = expanded, onDismissRequest = { expanded = false }) {
        DropdownMenuItem(text = { Text("g") }, onClick = {})
    }
}
'
expect 2 "tagged alert dialog buttons without the modifier are blocked" '
AlertDialog(
    onDismissRequest = onDismiss,
    confirmButton = {
        TextButton(onClick = onDelete, modifier = Modifier.testTag("delete_confirm")) { Text("Delete") }
    },
    title = { Text("Delete recipe?") }
)
'
expect 0 "alert dialog with the modifier is allowed" '
AlertDialog(
    onDismissRequest = onDismiss,
    modifier = Modifier.testTagsAsResourceId(),
    confirmButton = {
        TextButton(onClick = onDelete, modifier = Modifier.testTag("delete_confirm")) { Text("Delete") }
    }
)
'
expect 2 "tagged bottom sheet content without the modifier is blocked" '
ModalBottomSheet(onDismissRequest = onDismiss) {
    Column(Modifier.testTag("progress_sheet")) { Text("Pages") }
}
'
expect 0 "bottom sheet content root with the modifier is allowed" '
ModalBottomSheet(onDismissRequest = onDismiss) {
    Column(Modifier.testTagsAsResourceId().testTag("progress_sheet")) { Text("Pages") }
}
'
expect 0 "a function declaration named Dialog is not a call" '
@Composable
fun Dialog(onDismiss: () -> Unit, content: @Composable () -> Unit) {
    Box(Modifier.testTag("custom_dialog")) { content() }
}
'
expect 0 "parentheses and testTag in strings and comments are ignored" '
// DropdownMenu( with Modifier.testTag("x") in a comment
val label = "Dialog(" + ")"
DropdownMenu(expanded = true, onDismissRequest = {}) {
    DropdownMenuItem(text = { Text("testTag(") }, onClick = {})
}
'
expect 0 "a file without popups is allowed" '
Column(Modifier.testTag("recipes_root")) { Text("Recipes") }
'

printf '{"tool_name":"Write","tool_input":{"file_path":"%s/README.md"}}' "$DIR" | python3 "$HOOK" >/dev/null 2>&1
[ $? = 0 ] && echo "ok: other files are ignored" || { echo "FAIL: other files are ignored"; fail=1; }
mkdir -p "$DIR/src/commonTest"; printf 'DropdownMenu(expanded = true) { Box(Modifier.testTag("a")) }' > "$DIR/src/commonTest/T.kt"
printf '{"tool_name":"Write","tool_input":{"file_path":"%s/src/commonTest/T.kt"}}' "$DIR" | python3 "$HOOK" >/dev/null 2>&1
[ $? = 0 ] && echo "ok: test sources are ignored" || { echo "FAIL: test sources are ignored"; fail=1; }
printf '{"tool_name":"Write","tool_input":{"file_path":"%s/missing.kt"}}' "$DIR" | python3 "$HOOK" >/dev/null 2>&1
[ $? = 0 ] && echo "ok: a missing file fails open" || { echo "FAIL: a missing file fails open"; fail=1; }
printf 'bozuk json' | python3 "$HOOK" >/dev/null 2>&1
[ $? = 0 ] && echo "ok: broken input fails open" || { echo "FAIL: broken input fails open"; fail=1; }

# The settings.json command: a missing script must not block every tool.
COMMAND="$(python3 -c 'import json,sys
for entry in json.load(open(sys.argv[1]))["hooks"]["PostToolUse"]:
    for hook in entry["hooks"]:
        if "popup-tags-guard" in hook["command"]: print(hook["command"])' "$(dirname "$0")/../settings.json")"
[ -n "$COMMAND" ] && echo "ok: settings.json registers the hook" || { echo "FAIL: settings.json registers the hook"; fail=1; }
PROJECT="$(mktemp -d)"; mkdir -p "$PROJECT/.claude/hooks"
printf 'DropdownMenu(expanded = true) { Box(Modifier.testTag("a")) }' > "$FILE"
printf '{"tool_name":"Write","tool_input":{"file_path":"%s"}}' "$FILE" | CLAUDE_PROJECT_DIR="$PROJECT" /bin/sh -c "$COMMAND" >/dev/null 2>&1
[ $? = 0 ] && echo "ok: missing script passes" || { echo "FAIL: missing script passes"; fail=1; }
cp "$HOOK" "$PROJECT/.claude/hooks/popup-tags-guard.py"
printf '{"tool_name":"Write","tool_input":{"file_path":"%s"}}' "$FILE" | CLAUDE_PROJECT_DIR="$PROJECT" /bin/sh -c "$COMMAND" >/dev/null 2>&1
[ $? = 2 ] && echo "ok: installed script blocks a bad popup" || { echo "FAIL: installed script blocks a bad popup"; fail=1; }

rm -rf "$DIR" "$PROJECT"
exit $fail
