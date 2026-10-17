#!/usr/bin/env bash
# Read-only environment probe → one capabilities JSON line, so the skill only runs the steps that
# can succeed: the MCP (Node.js 20+, git), the Gradle build (JDK 21+) and the Docker image (a
# reachable daemon). Usage: doctor.sh [preferred IDE app name, default "IntelliJ IDEA"]
set -euo pipefail

have() { command -v "$1" >/dev/null 2>&1; }
bool() { if "$@"; then echo true; else echo false; fi; }

# Runs "$@" with a time limit (macOS has no timeout(1)): a stuck daemon must not hang the probe
with_timeout() {
  local secs="$1"; shift
  "$@" >/dev/null 2>&1 &
  local pid=$!
  ( sleep "$secs"; kill "$pid" 2>/dev/null ) >/dev/null 2>&1 &
  local watchdog=$!
  local rc=0
  wait "$pid" || rc=$?
  { kill "$watchdog"; wait "$watchdog"; } 2>/dev/null || true
  return "$rc"
}

node20() {
  have node || return 1
  local major
  major="$(node -p 'process.versions.node.split(".")[0]' 2>/dev/null || echo 0)"
  [ "$major" -ge 20 ] 2>/dev/null
}

# The key is "jdk21"; it means "JDK 21 or newer" (the template targets JVM 21)
jdk21() {
  local home="" major
  if [ "$(uname)" = Darwin ]; then home="$(/usr/libexec/java_home -v21 2>/dev/null || true)"; fi
  [ -n "$home" ] || home="${JAVA_HOME:-}"
  [ -n "$home" ] && [ -x "$home/bin/java" ] || return 1
  # not line 1: JAVA_TOOL_OPTIONS prints a "Picked up …" line before the version
  major="$("$home/bin/java" -version 2>&1 | sed -nE 's/.* version "([0-9]+).*/\1/p' | head -n 1)"
  [ "${major:-0}" -ge 21 ] 2>/dev/null
}

docker_ok() { have docker && with_timeout 15 docker info; }

ide() {
  local name
  for name in "${1:-IntelliJ IDEA}" "IntelliJ IDEA" "IntelliJ IDEA Ultimate" "IntelliJ IDEA CE" "Android Studio"; do
    if [ -d "/Applications/$name.app" ] || [ -d "$HOME/Applications/$name.app" ]; then
      printf '"%s"' "$name"
      return
    fi
  done
  printf null
}

printf '{"node20":%s,"git":%s,"jdk21":%s,"docker":%s,"ide":%s}\n' \
  "$(bool node20)" "$(bool have git)" "$(bool jdk21)" "$(bool docker_ok)" "$(ide "${1:-}")"
