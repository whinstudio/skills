#!/usr/bin/env bash
# Checks the frontmatter rules of every <skill>/SKILL.md, that compass-kit/kit.json names
# existing skills, that the old cmpose domain is gone and cmp-new-project's MCP pin is shown.
# Usage: check-skills.sh [repo root]. Exit 0 ok, 1 violations (one "FAIL: <skill>: ..." each).
set -uo pipefail
ROOT="${1:-$(cd "$(dirname "$0")/.." && pwd)}"
fail=0
bad() { echo "FAIL: $1: $2"; fail=1; }
fm() { # $1 = SKILL.md, $2 = key → top-level value (unquoted), empty when absent
  awk -v k="$2" 'NR==1 && $0!="---"{exit} NR>1 && $0=="---"{exit}
    NR>1 && index($0, k": ")==1 {v=substr($0, length(k)+3); gsub(/^["'\'']|["'\'']$/, "", v); print v; exit}' "$1"
}
INLINE_OK=" cmp-commit cmp-new-project cmp-matrix-test "
CODE_SKILLS=" cmp-code-rules cmp-feature cmp-design-to-code "
for f in "$ROOT"/*/SKILL.md; do
  [ -f "$f" ] || continue
  d="$(basename "$(dirname "$f")")"
  name="$(fm "$f" name)" model="$(fm "$f" model)" ctx="$(fm "$f" context)" bg="$(fm "$f" background)"
  [ "$name" = "$d" ] || bad "$d" "name '$name' does not match the folder"
  case "$model" in ''|opus|sonnet|haiku|fable|inherit) ;; *) bad "$d" "model '$model' is not opus|sonnet|haiku|fable|inherit" ;; esac
  [ "$ctx" != fork ] || [ "$bg" = false ] || bad "$d" "background must be false with context: fork"
  if [ -n "$model" ] && [ "$ctx" != fork ] && [[ "$INLINE_OK" != *" $d "* ]]; then
    bad "$d" "inline model switches the caller's turn; use context: fork"
  fi
  if [[ "$CODE_SKILLS" == *" $d "* ]] && { [ -n "$model" ] || [ -n "$ctx" ]; }; then
    bad "$d" "code skill must run on the session model (no model:, no context:)"
  fi
done
KIT="$ROOT/compass-kit/kit.json"
if [ -f "$KIT" ]; then
  while IFS= read -r s; do
    [ -f "$ROOT/$s/SKILL.md" ] || bad "$s" "listed in kit.json but $s/SKILL.md is missing"
  done < <(jq -r '.skills[] | if type == "string" then . else .name end' "$KIT")
fi
# R9: unity-kit (Compass's game code step) ships its six files; Compass refuses the kit otherwise.
UK="$ROOT/unity-kit"
if [ -d "$UK" ]; then
  for f in kit.json CLAUDE.md settings.json compass-unity CompassAutoPlay.cs README.md; do
    [ -f "$UK/$f" ] || bad unity-kit "$f is missing"
  done
  [ -f "$UK/compass-unity" ] && { grep -qF '@UNITY@' "$UK/compass-unity" || bad unity-kit "compass-unity has no @UNITY@ placeholder"; }
  [ -f "$UK/CLAUDE.md" ] && { grep -qF '<!-- compass-unity-kit -->' "$UK/CLAUDE.md" || bad unity-kit "CLAUDE.md has no compass-unity-kit marker"; }
  [ -f "$UK/kit.json" ] && { [ "$(jq -r '.version' "$UK/kit.json")" = 1 ] || bad unity-kit "kit.json version must be 1"; }
  # settings.json denies python on purpose; every other file must not suggest it.
  grep -rqI --exclude=settings.json 'python' "$UK" 2>/dev/null && bad unity-kit "mentions python (the code step has no interpreter)"
fi
# R7: the old cmpose domain lapses and may go to someone else: it must not come back anywhere.
# This script and its test are excluded (the test assembles the literal from pieces).
while IFS= read -r hit; do
  [ -n "$hit" ] && bad "domain" "${hit#"$ROOT"/}"
done < <(grep -rnIE --exclude-dir=.git 'cmpose\.dev' "$ROOT" 2>/dev/null \
  | grep -vE '/scripts/(check-skills|test_check_skills)\.sh:')
# R8: cmp-new-project's README and SKILL.md show the exact MCP install command its contract pins
# (SKILL.md prints it when the MCP is missing, without having to read the contract)
C="$ROOT/cmp-new-project/reference/contract.json"
if [ -f "$C" ]; then
  install="$(jq -r '.mcp.install // empty' "$C")"
  if [ -z "$install" ]; then bad cmp-new-project "reference/contract.json has no mcp.install (run scripts/sync-contract.sh)"
  else
    for f in README.md SKILL.md; do
      grep -qF -- "$install" "$ROOT/cmp-new-project/$f" || bad cmp-new-project "$f does not show '$install'"
    done
  fi
fi
exit "$fail"
