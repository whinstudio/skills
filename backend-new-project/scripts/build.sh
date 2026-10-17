#!/usr/bin/env bash
# Verify a generated backend: ./gradlew build (compile + tests + detekt) with JDK 21+, then report
# the build result, the number of tests and the detekt result. Usage: build.sh <projectDir>
set -euo pipefail

DIR="${1:?project dir required}"
[ -d "$DIR" ] || { echo "FAIL: $DIR is not a directory"; exit 1; }
cd "$DIR"

JH=""
if [ "$(uname)" = Darwin ]; then JH="$(/usr/libexec/java_home -v21 2>/dev/null || true)"; fi
[ -n "$JH" ] || JH="${JAVA_HOME:-}"
JV=""
if [ -n "$JH" ] && [ -x "$JH/bin/java" ]; then
  # not line 1: JAVA_TOOL_OPTIONS prints a "Picked up …" line before the version
  JV="$("$JH/bin/java" -version 2>&1 | sed -nE 's/.* version "([0-9]+).*/\1/p' | head -n 1 || true)"
fi
if [ -z "$JV" ] || ! [ "$JV" -ge 21 ] 2>/dev/null; then
  echo "SKIP: JDK 21 or newer not found (JAVA_HOME=${JH:-unset}); install JDK 21 (e.g. Temurin 21) and re-run."
  exit 0
fi

GRADLEW=(./gradlew)
[ -x ./gradlew ] || GRADLEW=(sh ./gradlew)
LOG="$(mktemp "${TMPDIR:-/tmp}/backend-build.XXXXXX")"
trap 'rm -f "$LOG"' EXIT

echo "Running ./gradlew build (JDK $JV)…"
if ! JAVA_HOME="$JH" "${GRADLEW[@]}" build --console=plain >"$LOG" 2>&1; then
  echo "FAIL: ./gradlew build failed (first error lines):"
  { grep -E '^e: |FAILED' "$LOG" || tail -n 20 "$LOG"; } | head -n 20 | sed 's/^/  /'
  exit 1
fi
echo "OK: BUILD SUCCESSFUL"

TESTS=0
for f in build/test-results/test/*.xml; do
  [ -f "$f" ] || continue
  n="$(sed -nE 's/.*<testsuite [^>]*tests="([0-9]+)".*/\1/p' "$f" | head -n 1)"
  TESTS=$((TESTS + ${n:-0}))
done
echo "OK: tests $TESTS"

# build depends on check, and check on detekt when the project applies the plugin: the task ran and passed
if grep -qE '^> Task :detekt' "$LOG"; then
  echo "OK: DETEKT CLEAN"
else
  echo "SKIP: detekt is not configured in this project"
fi
