#!/usr/bin/env bash
# Every new-project setup.sh starts the project's repository on develop. Run: bash scripts/test-setup-branch.sh
HERE="$(cd "$(dirname "$0")/.." && pwd)"
T="${TMPDIR:-/tmp}"
fail=0
for skill in cmp-new-project backend-new-project game-new-project; do
  dir="$(mktemp -d "${T%/}/setup-branch.XXXXXX")" || { echo "FAIL: $skill mktemp"; fail=1; continue; }
  echo "# test" > "$dir/README.md"
  # cmp-new-project skips local.properties when no Android SDK is found; that is not a failure here
  (cd "$dir" && bash "$HERE/$skill/scripts/setup.sh" "$dir") > /dev/null 2>&1
  head="$(git -C "$dir" symbolic-ref --short HEAD 2>/dev/null)"
  if [ "$head" = "develop" ]; then echo "OK: $skill develop"; else echo "FAIL: $skill HEAD is '${head:-none}'"; fail=1; fi
  rm -rf "${dir:?}"
done
exit "$fail"
