#!/usr/bin/env bash
# Behavior test for lib/namespace.sh. Run: bash game-new-project/scripts/test_namespace.sh
HERE="$(cd "$(dirname "$0")" && pwd)"
fail=0
T="${TMPDIR:-/tmp}"; TMP="$(mktemp -d "${T%/}/namespace.XXXXXX")" && [ -d "$TMP" ] || { echo "FAIL: mktemp"; exit 1; }
trap 'rm -rf "$TMP"' EXIT
# shellcheck source=lib/namespace.sh
. "$HERE/lib/namespace.sh" 2>/dev/null || { echo "FAIL: lib/namespace.sh missing"; exit 1; }

proj() { # $1 = name, $2 = record json or "", $3 = BuildScript namespace or ""
  local d="$TMP/$1"; mkdir -p "$d"
  if [ -n "$2" ]; then mkdir -p "$d/.cmpose"; printf '%s\n' "$2" > "$d/.cmpose/generation.json"; fi
  if [ -n "$3" ]; then mkdir -p "$d/Assets/Editor/Build"; printf 'using System;\nnamespace %s\n{\n}\n' "$3" > "$d/Assets/Editor/Build/BuildScript.cs"; fi
  echo "$d"
}
expect() { # $1 = desc, $2 = expected output, $3 = expected status, $4 = stdout, $5 = status, $6 = stderr
  if [ "$4" = "$2" ] && [ "$5" -eq "$3" ] && [ -z "$6" ]; then echo "PASS: $1"; else echo "FAIL: $1 (out='$4' status=$5 err='$6')"; fail=1; fi
}
run() { # $1 = dir; sets OUT, CODE, ERR
  local ef="$TMP/err"
  OUT="$(game_namespace "$1" 2>"$ef")"; CODE=$?; ERR="$(cat "$ef")"
}

BS="Example.SkyHopper.Editor.Build"
d="$(proj a '{"companyName":"Example","projectName":"SkyHopper"}' 'Other.Thing.Editor.Build')"; run "$d"
expect "a) record wins over BuildScript.cs" "Example.SkyHopper" 0 "$OUT" "$CODE" "$ERR"
d="$(proj b '{"generator":"@cmpose/core"}' "$BS")"; run "$d"
expect "b) record without names falls back" "Example.SkyHopper" 0 "$OUT" "$CODE" "$ERR"
d="$(proj c '{not json' "$BS")"; run "$d"
expect "c) invalid json falls back silently" "Example.SkyHopper" 0 "$OUT" "$CODE" "$ERR"
d="$(proj d '{"companyName":"Ex ample","projectName":"Sky"}' "$BS")"; run "$d"
expect "d) invalid identifier falls back" "Example.SkyHopper" 0 "$OUT" "$CODE" "$ERR"
d="$(proj e '{"companyName":"Example","projectName":"SkyHopper"}' "$BS")"
node() { return 127; }
run "$d"
unset -f node
expect "e) no node falls back" "Example.SkyHopper" 0 "$OUT" "$CODE" "$ERR"
d="$(proj f '' '')"; run "$d"
expect "f) neither file" "" 1 "$OUT" "$CODE" "$ERR"

exit "$fail"
