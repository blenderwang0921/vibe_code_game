#!/usr/bin/env bash
set -euo pipefail
PROJECT_ROOT="$(cd "$(dirname "$0")" && pwd)"
mkdir -p "$PROJECT_ROOT/artifacts"
"$PROJECT_ROOT/tools/godot.sh" --headless --editor --import --quit > "$PROJECT_ROOT/artifacts/import.log" 2>&1
for SCRIPT_FILE in "$PROJECT_ROOT"/tests/*.gd; do
  "$PROJECT_ROOT/tools/godot.sh" --headless --check-only --script "$SCRIPT_FILE" >> "$PROJECT_ROOT/artifacts/import.log" 2>&1
done
"$PROJECT_ROOT/tools/godot.sh" --headless --fixed-fps 60 --script res://tests/test_runner.gd > "$PROJECT_ROOT/artifacts/tests.log" 2>&1 || {
  cat "$PROJECT_ROOT/artifacts/tests.log"
  exit 1
}
python3 - "$PROJECT_ROOT" <<'PY'
import pathlib, re, sys
root = pathlib.Path(sys.argv[1])
for name in ("import.log", "tests.log"):
    contents = (root / "artifacts" / name).read_text()
    errors = [line for line in contents.splitlines() if re.search(r"\b(?:SCRIPT ERROR|ERROR|WARNING):", line)]
    if errors:
        print(name, *errors, sep="\n")
        raise SystemExit(1)
print((root / "artifacts/tests.log").read_text().splitlines()[-1])
PY

