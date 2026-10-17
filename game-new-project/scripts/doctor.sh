#!/usr/bin/env bash
# Read-only environment probe → one capabilities JSON line, so the skill only runs the steps that
# can succeed: the MCP (Node.js 20+, git), the Unity editor of the template's version with its
# Android and iOS modules, and the iOS toolchain (full Xcode, the simulator SDK, CocoaPods).
# Usage: doctor.sh [<unityVersion>]   (game_describe → unityVersion, e.g. 6000.3.25f1)
# UNITY_EDITOR (the editor binary) wins over the version's Unity Hub path.
set -euo pipefail

VERSION="${1:-}"

have() { command -v "$1" >/dev/null 2>&1; }
bool() { if "$@"; then echo true; else echo false; fi; }

# Runs "$@" with a time limit (macOS has no timeout(1)): a stuck tool must not hang the probe
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

# The editor binary: UNITY_EDITOR, else the Unity Hub install of the given version; empty when missing
EDITOR_BIN=""
if [ -n "${UNITY_EDITOR:-}" ]; then
  [ -x "$UNITY_EDITOR" ] && EDITOR_BIN="$UNITY_EDITOR"
elif [[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+[abfp][0-9]+$ ]]; then
  CANDIDATE="/Applications/Unity/Hub/Editor/${VERSION}/Unity.app/Contents/MacOS/Unity"
  [ -x "$CANDIDATE" ] && EDITOR_BIN="$CANDIDATE"
fi
# <editor dir>/Unity.app/Contents/MacOS/Unity → <editor dir>
EDITOR_DIR="${EDITOR_BIN%/Unity.app/*}"

module() { [ -n "$EDITOR_BIN" ] && [ -d "$EDITOR_DIR/PlaybackEngines/$1" ]; }

# The Command Line Tools' xcodebuild is a shim that only says "requires Xcode"
xcode() { [ "$(uname)" = Darwin ] && have xcodebuild && with_timeout 20 xcodebuild -version; }

# The simulator SDK is a separate download since Xcode 26
ios_sim_sdk() {
  xcode || return 1
  local sdks
  sdks="$(xcodebuild -showsdks 2>/dev/null || true)"
  grep -q -- '-sdk iphonesimulator' <<<"$sdks"
}

# JSON string of the editor path (quotes and backslashes escaped), or null
unity_json() {
  if [ -z "$EDITOR_BIN" ]; then printf null; return; fi
  local s="${EDITOR_BIN//\\/\\\\}"
  printf '"%s"' "${s//\"/\\\"}"
}

printf '{"node20":%s,"git":%s,"unity":%s,"androidModule":%s,"iosModule":%s,"xcode":%s,"iosSimSdk":%s,"pod":%s}\n' \
  "$(bool node20)" "$(bool have git)" "$(unity_json)" "$(bool module AndroidPlayer)" "$(bool module iOSSupport)" \
  "$(bool xcode)" "$(bool ios_sim_sdk)" "$(bool have pod)"
