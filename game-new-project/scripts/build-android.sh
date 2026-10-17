#!/usr/bin/env bash
# Verify a generated Unity game: an Android APK through the template's BuildScript in batch mode.
# The editor version comes from ProjectSettings/ProjectVersion.txt, the build namespace
# (<companyName>.<projectName>) from Assets/Editor/Build/BuildScript.cs. Usage: build-android.sh <projectDir>
# Env: UNITY_EDITOR (the editor binary; default: the Unity Hub install of the project's version),
#      UNITY_BUILD_TIMEOUT (seconds, default 1800)
set -euo pipefail

DIR="${1:?project dir required}"
[ -d "$DIR" ] || { echo "FAIL: $DIR is not a directory"; exit 1; }
DIR="$(cd "$DIR" && pwd)"
LIMIT="${UNITY_BUILD_TIMEOUT:-1800}"
[[ "$LIMIT" =~ ^[0-9]+$ ]] || { echo "FAIL: UNITY_BUILD_TIMEOUT must be a number of seconds"; exit 1; }

VERSION="$(sed -nE 's/^m_EditorVersion: *([^ ]+).*/\1/p' "$DIR/ProjectSettings/ProjectVersion.txt" 2>/dev/null | head -n 1 || true)"
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+[abfp][0-9]+$ ]] \
  || { echo "FAIL: no Unity version in $DIR/ProjectSettings/ProjectVersion.txt (not a Unity project?)"; exit 1; }
UNITY_EDITOR="${UNITY_EDITOR:-/Applications/Unity/Hub/Editor/${VERSION}/Unity.app/Contents/MacOS/Unity}"
if [ ! -x "$UNITY_EDITOR" ]; then
  echo "SKIP: Unity ${VERSION} not found ($UNITY_EDITOR); install it in Unity Hub with Android Build Support (or set UNITY_EDITOR)."
  exit 0
fi
EDITOR_DIR="${UNITY_EDITOR%/Unity.app/*}"
if [ ! -d "$EDITOR_DIR/PlaybackEngines/AndroidPlayer" ]; then
  echo "SKIP: Unity ${VERSION} has no Android Build Support; add the module in Unity Hub and re-run."
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
PROJECT="${NS#*.}"

# Runs "$@" with a time limit (macOS has no timeout(1)); 124 when the limit killed it
run_limited() {
  local secs="$1"; shift
  local flag
  flag="$(mktemp "${TMPDIR:-/tmp}/unity-timeout.XXXXXX")"
  rm -f "$flag"
  "$@" >/dev/null 2>&1 &
  local pid=$!
  ( sleep "$secs"; kill "$pid" 2>/dev/null && : >"$flag" ) >/dev/null 2>&1 &
  local watchdog=$!
  local rc=0
  wait "$pid" || rc=$?
  { kill "$watchdog"; wait "$watchdog"; } 2>/dev/null || true
  if [ -e "$flag" ]; then rm -f "$flag"; return 124; fi
  return "$rc"
}

APK="$DIR/Builds/Android/${PROJECT}.apk"
LOG="$DIR/Builds/logs/android.log"
mkdir -p "$DIR/Builds/Android" "$DIR/Builds/logs"
rm -f "$APK"

echo "Building the Android APK with Unity ${VERSION} (log: ${LOG})…"
RC=0
run_limited "$LIMIT" "$UNITY_EDITOR" -batchmode -nographics -quit -projectPath "$DIR" -buildTarget Android \
  -executeMethod "${NS}.Editor.Build.BuildScript.BuildAndroid" -cmposeOut "$APK" -logFile "$LOG" || RC=$?
if [ "$RC" -eq 124 ]; then
  echo "FAIL: the Unity Android build did not finish within ${LIMIT}s (log: ${LOG})"
  exit 1
fi
if [ "$RC" -ne 0 ] || ! grep -qE 'CMPOSE_BUILD_RESULT .*result=Succeeded' "$LOG" 2>/dev/null || [ ! -f "$APK" ]; then
  echo "FAIL: the Unity Android build failed (exit ${RC}; log: ${LOG}); last error lines:"
  { grep -E 'error CS[0-9]+|CMPOSE_BUILD_RESULT|[Ee]rror|Exception' "$LOG" 2>/dev/null || tail -n 20 "$LOG" 2>/dev/null || true; } \
    | tail -n 20 | sed 's/^/  /'
  exit 1
fi
SIZE="$(du -h "$APK" | cut -f1 | tr -d ' ')"
echo "OK: APK $APK (${SIZE})"
