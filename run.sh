#!/usr/bin/env bash
set -euo pipefail
PROJECT_ROOT="$(cd "$(dirname "$0")" && pwd)"
mkdir -p "$PROJECT_ROOT/artifacts"
"$PROJECT_ROOT/tools/godot.sh" --headless --editor --import --quit > "$PROJECT_ROOT/artifacts/import.log" 2>&1
exec "$PROJECT_ROOT/tools/godot.sh" "$@"

