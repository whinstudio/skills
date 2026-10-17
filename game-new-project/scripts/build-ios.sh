#!/usr/bin/env bash
# Verify a generated Unity game: an iOS simulator build. Unity exports the Xcode project through the
# template's BuildScript (-cmposeSimulator), pod install runs when there is a Podfile, then xcodebuild
# builds Debug for the simulator SDK without signing. The editor version comes from
# ProjectSettings/ProjectVersion.txt, the build namespace (<companyName>.<projectName>) from
# Assets/Editor/Build/BuildScript.cs. Usage: build-ios.sh <projectDir>
# Env: UNITY_EDITOR (the editor binary; default: the Unity Hub install of the project's version),
#      UNITY_BUILD_TIMEOUT (seconds per step, default 1800)
set -euo pipefail

DIR="${1:?project dir required}"
[ -d "$DIR" ] || { echo "FAIL: $DIR is not a directory"; exit 1; }
DIR="$(cd "$DIR" && pwd)"
LIMIT="${UNITY_BUILD_TIMEOUT:-1800}"
[[ "$LIMIT" =~ ^[0-9]+$ ]] || { echo "FAIL: UNITY_BUILD_TIMEOUT must be a number of seconds"; exit 1; }

if [ "$(uname)" != Darwin ]; then
  echo "SKIP: an iOS build needs macOS with Xcode."
  exit 0
fi
# The Command Line Tools' xcodebuild is a shim that only says "requires Xcode"; the simulator SDK is a
# separate download since Xcode 26
if ! command -v xcodebuild >/dev/null 2>&1 || ! xcodebuild -version >/dev/null 2>&1; then
  echo "SKIP: no full Xcode; install Xcode and select it (sudo xcode-select -s /Applications/Xcode.app), then re-run."
  exit 0
fi
SDKS="$(xcodebuild -showsdks 2>/dev/null || true)"
if ! grep -q -- '-sdk iphonesimulator' <<<"$SDKS"; then
  echo "SKIP: no iOS Simulator SDK (Xcode > Settings > Components: iOS); install it and re-run."
  exit 0
fi

VERSION="$(sed -nE 's/^m_EditorVersion: *([^ ]+).*/\1/p' "$DIR/ProjectSettings/ProjectVersion.txt" 2>/dev/null | head -n 1 || true)"
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+[abfp][0-9]+$ ]] \
  || { echo "FAIL: no Unity version in $DIR/ProjectSettings/ProjectVersion.txt (not a Unity project?)"; exit 1; }
UNITY_EDITOR="${UNITY_EDITOR:-/Applications/Unity/Hub/Editor/${VERSION}/Unity.app/Contents/MacOS/Unity}"
if [ ! -x "$UNITY_EDITOR" ]; then
  echo "SKIP: Unity ${VERSION} not found ($UNITY_EDITOR); install it in Unity Hub with iOS Build Support (or set UNITY_EDITOR)."
  exit 0
fi
EDITOR_DIR="${UNITY_EDITOR%/Unity.app/*}"
if [ ! -d "$EDITOR_DIR/PlaybackEngines/iOSSupport" ]; then
  echo "SKIP: Unity ${VERSION} has no iOS Build Support; add the module in Unity Hub and re-run."
  exit 0
fi
# An editor that has the project open holds this lock; a batch build would fail on it
if [ -e "$DIR/Temp/UnityLockfile" ]; then
  echo "SKIP: the project is open in Unity (Temp/UnityLockfile); close Unity first and re-run."
  exit 0
fi

NS="$(sed -nE 's/^namespace ([A-Za-z_][A-Za-z0-9_]*\.[A-Za-z_][A-Za-z0-9_]*)\.Editor\.Build[[:space:]]*$/\1/p' \
  "$DIR/Assets/Editor/Build/BuildScript.cs" 2>/dev/null | head -n 1 || true)"
[ -n "$NS" ] || { echo "FAIL: no <Company>.<Project>.Editor.Build namespace in Assets/Editor/Build/BuildScript.cs"; exit 1; }

# Runs "$@" with a time limit (macOS has no timeout(1)), its output appended to the log $1; 124 when
# the limit killed it
run_limited() {
  local log="$1" secs="$2"; shift 2
  local flag
  flag="$(mktemp "${TMPDIR:-/tmp}/ios-timeout.XXXXXX")"
  rm -f "$flag"
  "$@" >>"$log" 2>&1 </dev/null &
  local pid=$!
  ( sleep "$secs"; kill "$pid" 2>/dev/null && : >"$flag" ) >/dev/null 2>&1 &
  local watchdog=$!
  local rc=0
  wait "$pid" || rc=$?
  { kill "$watchdog"; wait "$watchdog"; } 2>/dev/null || true
  if [ -e "$flag" ]; then rm -f "$flag"; return 124; fi
  return "$rc"
}

# $1 what failed, $2 exit code, $3 log, $4 the pattern of its error lines
fail_with_log() {
  if [ "$2" -eq 124 ]; then
    echo "FAIL: $1 did not finish within ${LIMIT}s (log: $3)"
  else
    echo "FAIL: $1 failed (exit $2; log: $3); last error lines:"
    { grep -E "$4" "$3" 2>/dev/null || tail -n 20 "$3" 2>/dev/null || true; } | tail -n 20 | sed 's/^/  /'
  fi
  exit 1
}

OUT="$DIR/Builds/ios"
DD="$DIR/Builds/ios-dd"
ULOG="$DIR/Builds/logs/ios-unity.log"
XLOG="$DIR/Builds/logs/ios-xcodebuild.log"
mkdir -p "$DIR/Builds/logs"
rm -f "$ULOG" "$XLOG"

echo "Exporting the iOS Xcode project with Unity ${VERSION} (log: ${ULOG})…"
RC=0
run_limited /dev/null "$LIMIT" "$UNITY_EDITOR" -batchmode -nographics -quit -projectPath "$DIR" -buildTarget iOS \
  -executeMethod "${NS}.Editor.Build.BuildScript.BuildIOS" -cmposeOut "$OUT" -cmposeSimulator -logFile "$ULOG" || RC=$?
if [ "$RC" -ne 0 ] || ! grep -qE 'CMPOSE_BUILD_RESULT .*result=Succeeded' "$ULOG" 2>/dev/null; then
  [ "$RC" -ne 0 ] || RC=1
  fail_with_log "the Unity iOS export" "$RC" "$ULOG" 'error CS[0-9]+|CMPOSE_BUILD_RESULT|[Ee]rror|Exception'
fi

cd "$OUT"
if [ -f Podfile ]; then
  if ! command -v pod >/dev/null 2>&1; then
    echo "SKIP: the Xcode project has a Podfile but CocoaPods (pod) is not installed; install CocoaPods and re-run."
    exit 0
  fi
  echo "Running pod install…"
  RC=0
  run_limited "$XLOG" "$LIMIT" pod install || RC=$?
  [ "$RC" -eq 0 ] || fail_with_log "pod install" "$RC" "$XLOG" '[Ee]rror|\[!\]'
  TARGET=(-workspace Unity-iPhone.xcworkspace)
else
  TARGET=(-project Unity-iPhone.xcodeproj)
fi

echo "Building for the iOS simulator with xcodebuild (log: ${XLOG})…"
RC=0
run_limited "$XLOG" "$LIMIT" xcodebuild "${TARGET[@]}" -scheme Unity-iPhone -configuration Debug -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' -derivedDataPath "$DD" CODE_SIGNING_ALLOWED=NO build || RC=$?
if [ "$RC" -ne 0 ] || ! grep -q '\*\* BUILD SUCCEEDED \*\*' "$XLOG"; then
  [ "$RC" -ne 0 ] || RC=1
  fail_with_log "xcodebuild" "$RC" "$XLOG" 'error:|\*\* BUILD FAILED \*\*'
fi
echo "OK: iOS simulator build ($DD/Build/Products/Debug-iphonesimulator)"
