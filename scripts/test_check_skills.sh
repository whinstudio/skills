#!/usr/bin/env bash
# Behavior test for check-skills.sh. Run: bash scripts/test_check_skills.sh
HERE="$(cd "$(dirname "$0")" && pwd)"
CHECK="$HERE/check-skills.sh"
fail=0
check() { local d="$1"; shift; if "$@"; then echo "ok: $d"; else echo "FAIL: $d"; fail=1; fi; }
T="${TMPDIR:-/tmp}"; TMP="$(mktemp -d "${T%/}/check-skills.XXXXXX")" && [ -d "$TMP" ] || { echo "FAIL: mktemp"; exit 1; }
skill() { # $1 = dir, rest = frontmatter lines
  local d="$TMP/$1"; shift; mkdir -p "$d"
  { echo ---; printf '%s\n' "$@"; echo ---; echo; echo "# x"; } > "$d/SKILL.md"
}
reset() { rm -rf "${TMP:?}"/*; mkdir -p "$TMP/compass-kit"; echo '{"skills":["a",{"name":"b","requires":"detekt"}]}' > "$TMP/compass-kit/kit.json"; skill a "name: a"; skill b "name: b"; }
runc() { OUT="$(bash "$CHECK" "$TMP" 2>&1)"; CODE=$?; }

reset; runc; check "clean tree passes" test "$CODE" -eq 0
check "real repo passes" bash "$CHECK"

reset; skill c "name: other"; runc
check "R1 name mismatch fails" bash -c '[ "$1" -eq 1 ] && grep -q "FAIL: c: name" <<<"$2"' _ "$CODE" "$OUT"
reset; skill c "name: c" "model: gpt" "context: fork" "background: false"; runc
check "R2 unknown model fails" bash -c '[ "$1" -eq 1 ] && grep -q "FAIL: c: model" <<<"$2"' _ "$CODE" "$OUT"
reset; skill c "name: c" "model: sonnet" "context: fork"; runc
check "R3 fork without background false fails" bash -c '[ "$1" -eq 1 ] && grep -q "FAIL: c: background" <<<"$2"' _ "$CODE" "$OUT"
reset; skill c "name: c" "model: sonnet"; runc
check "R4 inline model outside allowlist fails" bash -c '[ "$1" -eq 1 ] && grep -q "FAIL: c: inline model" <<<"$2"' _ "$CODE" "$OUT"
reset; skill cmp-commit "name: cmp-commit" "model: sonnet"; runc
check "R4 inline model in cmp-commit passes" test "$CODE" -eq 0
reset; skill cmp-feature "name: cmp-feature" "context: fork" "background: false"; runc
check "R5 code skill with context fails" bash -c '[ "$1" -eq 1 ] && grep -q "FAIL: cmp-feature: code skill" <<<"$2"' _ "$CODE" "$OUT"
reset; rm -rf "${TMP:?}/b"; runc
check "R6 kit skill without folder fails" bash -c '[ "$1" -eq 1 ] && grep -q "FAIL: b: listed in kit.json" <<<"$2"' _ "$CODE" "$OUT"
reset; skill c "name: c" "description: >-" "  model: opus in text" "context: fork" "background: false"; runc
check "indented text inside a folded value is not a key" test "$CODE" -eq 0

DOMAIN="cmpose"".dev"   # assembled: this file must not hold the literal
reset; printf 'see %s\n' "$DOMAIN" > "$TMP/a/notes.md"; runc
check "R7 the old domain anywhere fails" bash -c '[ "$1" -eq 1 ] && grep -q "FAIL: domain: a/notes.md:1:" <<<"$2"' _ "$CODE" "$OUT"
reset; mkdir -p "$TMP/cmp-new-project/reference"; skill cmp-new-project "name: cmp-new-project"
echo 'install: claude mcp add cmpose -- npx -y @cmpose/mcp@9.9.9' >> "$TMP/cmp-new-project/SKILL.md"
echo '{"mcp":{"install":"claude mcp add cmpose -- npx -y @cmpose/mcp@9.9.9"}}' > "$TMP/cmp-new-project/reference/contract.json"
echo 'install: claude mcp add cmpose -- npx -y @cmpose/mcp@1.0.0' > "$TMP/cmp-new-project/README.md"; runc
check "R8 README with another MCP version fails" bash -c '[ "$1" -eq 1 ] && grep -q "FAIL: cmp-new-project: README.md does not show" <<<"$2"' _ "$CODE" "$OUT"
echo 'install: claude mcp add cmpose -- npx -y @cmpose/mcp@9.9.9' > "$TMP/cmp-new-project/README.md"; runc
check "R8 README and SKILL.md with the pinned MCP command pass" test "$CODE" -eq 0
skill cmp-new-project "name: cmp-new-project"; runc
check "R8 SKILL.md without the MCP command fails" bash -c '[ "$1" -eq 1 ] && grep -q "FAIL: cmp-new-project: SKILL.md does not show" <<<"$2"' _ "$CODE" "$OUT"

INSTALL='claude mcp add cmpose -- npx -y @cmpose/mcp@9.9.9'
npskill() { # $1 = *-new-project folder; SKILL.md and README.md show the pinned MCP command
  skill "$1" "name: $1" "model: sonnet" "effort: medium"
  echo "install: $INSTALL" >> "$TMP/$1/SKILL.md"; echo "install: $INSTALL" > "$TMP/$1/README.md"
}
reset; mkdir -p "$TMP/cmp-new-project/reference"; npskill cmp-new-project
echo "{\"mcp\":{\"install\":\"$INSTALL\"}}" > "$TMP/cmp-new-project/reference/contract.json"
npskill game-new-project; npskill backend-new-project; runc
check "R8 *-new-project skills with the pinned MCP command pass" test "$CODE" -eq 0
echo 'install: claude mcp add cmpose -- npx -y @cmpose/mcp@1.0.0' > "$TMP/game-new-project/README.md"; runc
check "R8 game-new-project README with another MCP version fails" bash -c '[ "$1" -eq 1 ] && grep -q "FAIL: game-new-project: README.md does not show '"'"'$3'"'"'" <<<"$2"' _ "$CODE" "$OUT" "$INSTALL"
rm "$TMP/game-new-project/README.md"; runc
check "R8 *-new-project skill without a README fails" bash -c '[ "$1" -eq 1 ] && grep -q "FAIL: game-new-project: README.md is missing" <<<"$2"' _ "$CODE" "$OUT"
npskill game-new-project; skill backend-new-project "name: backend-new-project" "model: sonnet" "effort: medium"; runc
check "R8 backend-new-project SKILL.md without the MCP command fails" bash -c '[ "$1" -eq 1 ] && grep -q "FAIL: backend-new-project: SKILL.md does not show" <<<"$2"' _ "$CODE" "$OUT"
reset; npskill game-new-project; runc
check "R8 *-new-project skill without cmp-new-project's contract fails" bash -c '[ "$1" -eq 1 ] && grep -q "FAIL: game-new-project: cannot check the MCP install command" <<<"$2"' _ "$CODE" "$OUT"

ukit() { # a complete unity-kit/
  local d="$TMP/unity-kit"; mkdir -p "$d"
  echo '{ "version": 8 }' > "$d/kit.json"; echo '{}' > "$d/settings.json"; echo '# unity-kit' > "$d/README.md"
  echo '<!-- compass-unity-kit -->' > "$d/CLAUDE.md"; echo "UNITY='@UNITY@'" > "$d/compass-unity"
  echo 'public static class CompassAutoPlay {}' > "$d/CompassAutoPlay.cs"; echo 'public class CompassArtImporter {}' > "$d/CompassArtImporter.cs"
  echo 'public static class CompassBranding {}' > "$d/CompassBranding.cs"; echo 'public class CompassMenuShotTests {}' > "$d/CompassMenuShotTests.cs"
}
reset; ukit; rm "$TMP/unity-kit/compass-unity"; runc
check "R9 unity-kit without compass-unity fails" bash -c '[ "$1" -eq 1 ] && grep -q "FAIL: unity-kit: compass-unity is missing" <<<"$2"' _ "$CODE" "$OUT"
reset; ukit; rm "$TMP/unity-kit/CompassMenuShotTests.cs"; runc
check "R9 unity-kit without the menu shot test fails" bash -c '[ "$1" -eq 1 ] && grep -q "FAIL: unity-kit: CompassMenuShotTests.cs is missing" <<<"$2"' _ "$CODE" "$OUT"
reset; ukit; echo '{ "version": 7 }' > "$TMP/unity-kit/kit.json"; runc
check "R9 unity-kit still at version 7 fails" bash -c '[ "$1" -eq 1 ] && grep -q "FAIL: unity-kit: kit.json version must be 8" <<<"$2"' _ "$CODE" "$OUT"
reset; ukit; runc
check "R9 complete unity-kit passes" bash -c '[ "$1" -eq 0 ] && ! grep -q "FAIL: unity-kit" <<<"$2"' _ "$CODE" "$OUT"

reset; head -c 18001 /dev/zero | tr '\0' 'x' >> "$TMP/a/SKILL.md"; runc
check "R10 SKILL.md over the compaction budget fails" bash -c '[ "$1" -eq 1 ] && grep -q "FAIL: a: SKILL.md is" <<<"$2"' _ "$CODE" "$OUT"
reset; echo 'Read [references/1-x.md](references/1-x.md) now.' >> "$TMP/a/SKILL.md"; runc
check "R11 a missing linked reference fails" bash -c '[ "$1" -eq 1 ] && grep -q "FAIL: a: links references/1-x.md" <<<"$2"' _ "$CODE" "$OUT"
mkdir -p "$TMP/a/references"; echo x > "$TMP/a/references/1-x.md"; runc
check "R11 an existing linked reference passes" test "$CODE" -eq 0

rm -rf "${TMP:?}"
exit "$fail"
