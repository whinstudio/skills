#!/usr/bin/env bash
# Read-only environment probe → capabilities JSON, so the skill only offers
# verifications that can actually succeed (Android build, iOS simulator run).
# Usage: doctor.sh
set -uo pipefail

OS="$(uname 2>/dev/null || echo unknown)"
MACOS=false; [ "$OS" = "Darwin" ] && MACOS=true

# NOTE: the JSON key "jdk21" is a public contract and is kept; its meaning is "JDK 21 or newer is available".
JDK21_HOME=""
if [ "$MACOS" = true ]; then
  JDK21_HOME="$(/usr/libexec/java_home -v21 2>/dev/null || true)"
fi
[ -z "$JDK21_HOME" ] && [ -n "${JAVA_HOME:-}" ] && JDK21_HOME="$JAVA_HOME"
# Any JAVA_HOME is not enough: the build needs JDK ≥ 21 (AGP 9, the Gradle daemon criteria)
jdk_major() { "$1/bin/java" -version 2>&1 | sed -nE '1s/.*version "([0-9]+).*/\1/p'; }
JDK21=false
if [ -n "$JDK21_HOME" ] && [ "$(jdk_major "$JDK21_HOME")" -ge 21 ] 2>/dev/null; then JDK21=true; else JDK21_HOME=""; fi

SDK="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-$HOME/Library/Android/sdk}}"
ANDROID_SDK=null; [ -d "$SDK" ] && ANDROID_SDK="\"$SDK\""

have() { command -v "$1" >/dev/null 2>&1 && echo true || echo false; }
XCODE="$( { [ "$MACOS" = true ] && command -v xcodebuild >/dev/null 2>&1; } && echo true || echo false)"
CURL="$(have curl)"; UNZIP="$(have unzip)"; NODE="$(have node)"; GIT="$(have git)"
# The cmpose MCP server (npx @cmpose/mcp) needs Node.js 20 or newer
NODE20=false
if [ "$NODE" = true ]; then
  NODE_MAJOR="$(node -p 'process.versions.node.split(".")[0]' 2>/dev/null || echo 0)"
  [ "$NODE_MAJOR" -ge 20 ] 2>/dev/null && NODE20=true
fi

CAN_ANDROID=false; { [ "$JDK21" = true ] && [ "$ANDROID_SDK" != null ]; } && CAN_ANDROID=true
CAN_IOS=false;     { [ "$MACOS" = true ] && [ "$XCODE" = true ]; } && CAN_IOS=true

printf '{"os":"%s","macos":%s,"jdk21":%s,"jdk21Home":%s,"androidSdk":%s,"xcode":%s,"curl":%s,"unzip":%s,"node":%s,"node20":%s,"git":%s,"canBuildAndroid":%s,"canRunIos":%s}\n' \
  "$OS" "$MACOS" "$JDK21" "$([ -n "$JDK21_HOME" ] && echo "\"$JDK21_HOME\"" || echo null)" \
  "$ANDROID_SDK" "$XCODE" "$CURL" "$UNZIP" "$NODE" "$NODE20" "$GIT" "$CAN_ANDROID" "$CAN_IOS"
