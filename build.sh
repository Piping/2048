#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GODOT_BIN="${GODOT_BIN:-/Applications/Godot.app/Contents/MacOS/Godot}"
BUILD_DIR="${ROOT_DIR}/build"

usage() {
  cat <<'EOF'
Usage:
  ./build.sh              Build desktop and android artifacts
  ./build.sh desktop      Build desktop artifact only
  ./build.sh android      Build android artifact only
  ./build.sh all          Build desktop and android artifacts

Optional environment variables:
  GODOT_BIN=/path/to/Godot
EOF
}

if [[ ! -x "${GODOT_BIN}" ]]; then
  echo "Godot binary not found or not executable: ${GODOT_BIN}" >&2
  exit 1
fi

target="${1:-all}"
case "${target}" in
  all|desktop|android)
    ;;
  -h|--help|help)
    usage
    exit 0
    ;;
  *)
    echo "Unknown target: ${target}" >&2
    usage >&2
    exit 1
    ;;
esac

mkdir -p "${BUILD_DIR}"

build_desktop() {
  echo "[build] Exporting macOS app..."
  "${GODOT_BIN}" \
    --headless \
    --path "${ROOT_DIR}" \
    --export-release macOS "${BUILD_DIR}/2048.app"
}

build_android() {
  echo "[build] Exporting Android APK..."
  "${GODOT_BIN}" \
    --headless \
    --path "${ROOT_DIR}" \
    --export-debug Android "${BUILD_DIR}/2048.apk"
}

case "${target}" in
  all)
    build_desktop
    build_android
    ;;
  desktop)
    build_desktop
    ;;
  android)
    build_android
    ;;
esac

echo "[build] Done."
