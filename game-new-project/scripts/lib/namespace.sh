#!/usr/bin/env bash
# Sourced by build-android.sh and build-ios.sh.
# game_namespace <projectDir>: prints <Company>.<Project> and returns 0, or prints nothing and returns 1.
# Source 1: companyName/projectName in <projectDir>/.cmpose/generation.json (needs node).
# Source 2 (older projects): the "namespace <Company>.<Project>.Editor.Build" line of Assets/Editor/Build/BuildScript.cs.
game_namespace() {
  local dir="$1" ns=""
  if command -v node >/dev/null 2>&1 && [ -f "$dir/.cmpose/generation.json" ]; then
    ns="$(node -e '
      const r = JSON.parse(require("fs").readFileSync(process.argv[1], "utf8"));
      const ok = /^[A-Za-z_][A-Za-z0-9_]*$/;
      if (r && typeof r.companyName === "string" && typeof r.projectName === "string" && ok.test(r.companyName) && ok.test(r.projectName)) process.stdout.write(r.companyName + "." + r.projectName);
    ' "$dir/.cmpose/generation.json" 2>/dev/null || true)"
  fi
  if [ -z "$ns" ]; then
    ns="$(sed -nE 's/^namespace ([A-Za-z_][A-Za-z0-9_]*\.[A-Za-z_][A-Za-z0-9_]*)\.Editor\.Build[[:space:]]*$/\1/p' \
      "$dir/Assets/Editor/Build/BuildScript.cs" 2>/dev/null | head -n 1 || true)"
  fi
  [ -n "$ns" ] || return 1
  printf '%s\n' "$ns"
}
