#!/usr/bin/env bash
set -euo pipefail
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
if [[ "$(uname -s)" == "Darwin" ]]; then
  BLENDER_DEFAULT="$PROJECT_ROOT/.tools/blender/Blender.app/Contents/MacOS/Blender"
else
  BLENDER_DEFAULT="$PROJECT_ROOT/.tools/blender/blender"
fi
BLENDER_EXECUTABLE="${BLENDER_BIN:-$BLENDER_DEFAULT}"
if [[ -n "${BLENDER_BIN:-}" && ! -x "$BLENDER_EXECUTABLE" ]]; then
  echo "BLENDER_BIN 不是可執行檔：$BLENDER_EXECUTABLE" >&2
  exit 1
fi
if [[ ! -x "$BLENDER_EXECUTABLE" ]]; then
  if command -v blender >/dev/null 2>&1; then
    BLENDER_EXECUTABLE="$(command -v blender)"
  else
    echo "找不到 Blender。請執行 python3 tools/install_blender.py，或設定 BLENDER_BIN。" >&2
    exit 1
  fi
fi
exec "$BLENDER_EXECUTABLE" "$@"
