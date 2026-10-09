#!/usr/bin/env bash
set -euo pipefail
PROJECT_ROOT="$(cd "$(dirname "$0")" && pwd)"
mkdir -p "$PROJECT_ROOT/artifacts"
exec "$PROJECT_ROOT/tools/godot.sh" --script res://tests/visual_runner.gd -- --benchmark "$@"

