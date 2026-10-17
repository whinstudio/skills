#!/usr/bin/env bash
# Build the generated backend's Docker image and check that it does not run as root.
# Usage: docker-build.sh <projectDir> <appName>
set -euo pipefail

DIR="${1:?project dir required}"
APP="${2:?appName required}"
[ -d "$DIR" ] || { echo "FAIL: $DIR is not a directory"; exit 1; }
# The generator's appName rule; it also keeps the image tag well-formed
if ! [[ "$APP" =~ ^[a-z][a-z0-9-]{1,30}$ ]]; then
  echo "FAIL: appName '$APP' must be 2-31 lowercase letters, digits or -, starting with a letter"
  exit 1
fi
cd "$DIR"
[ -f deploy/Dockerfile ] || { echo "FAIL: deploy/Dockerfile is missing"; exit 1; }

if ! command -v docker >/dev/null 2>&1; then
  echo "SKIP: docker not found; install Docker to build the image."
  exit 0
fi
# A stopped (or stuck) daemon must not hang the flow: probe it with a time limit
docker info >/dev/null 2>&1 &
PID=$!
( sleep 15; kill "$PID" 2>/dev/null ) >/dev/null 2>&1 &
WATCHDOG=$!
RC=0
wait "$PID" || RC=$?
{ kill "$WATCHDOG"; wait "$WATCHDOG"; } 2>/dev/null || true
if [ "$RC" -ne 0 ]; then
  echo "SKIP: the Docker daemon is not reachable; start Docker and re-run."
  exit 0
fi

TAG="$APP:local"
LOG="$(mktemp "${TMPDIR:-/tmp}/backend-docker.XXXXXX")"
trap 'rm -f "$LOG"' EXIT
echo "Building ${TAG}…"
if ! docker build -f deploy/Dockerfile --build-arg APP_VERSION=local -t "$TAG" . >"$LOG" 2>&1; then
  echo "FAIL: docker build failed:"
  tail -n 20 "$LOG" | sed 's/^/  /'
  exit 1
fi

U="$(docker image inspect -f '{{.Config.User}}' "$TAG")"
case "${U%%:*}" in
  ''|0|root)
    echo "FAIL: image $TAG runs as root (USER '$U'); the Dockerfile must set a non-root USER"
    exit 1
    ;;
esac
echo "OK: image $TAG (user $U)"
