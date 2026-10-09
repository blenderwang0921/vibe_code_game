#!/usr/bin/env bash
set -euo pipefail
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT_EXECUTABLE="${GODOT_BIN:-$PROJECT_ROOT/.tools/Godot.app/Contents/MacOS/Godot}"
if [[ ! -x "$GODOT_EXECUTABLE" ]]; then
  if command -v godot >/dev/null 2>&1; then
    GODOT_EXECUTABLE="$(command -v godot)"
  else
    echo "找不到 Godot。請先執行 python3 tools/install_godot.py，或設定 GODOT_BIN。" >&2
    exit 1
  fi
fi
exec "$GODOT_EXECUTABLE" --path "$PROJECT_ROOT" "$@"

