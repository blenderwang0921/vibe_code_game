#!/usr/bin/env python3
"""Measure project, downloaded engine, and Godot-created caches, without overlap."""
import json
import os
import pathlib

ROOT = pathlib.Path(__file__).resolve().parent.parent


def measure(root, excluded=()):
    apparent = allocated = 0
    if not root.exists():
        return {"bytes": 0, "allocated_bytes": 0}
    for directory, subdirs, filenames in os.walk(root):
        subdirs[:] = [d for d in subdirs if d not in excluded]
        for filename in filenames:
            path = pathlib.Path(directory) / filename
            stat = path.lstat()
            apparent += stat.st_size
            allocated += stat.st_blocks * 512
    return {"bytes": apparent, "allocated_bytes": allocated}


def main():
    report = {
        "project_and_evidence": measure(ROOT, (".tools", ".godot", ".git")),
        "engine": measure(ROOT / ".tools"),
        "project_cache": measure(ROOT / ".godot"),
        "godot_application_data": measure(pathlib.Path.home() / "Library/Application Support/Godot"),
        "godot_editor_cache": measure(pathlib.Path.home() / "Library/Caches/Godot"),
    }
    report["total_bytes"] = sum(value["bytes"] for value in report.values())
    report["total_MiB"] = round(report["total_bytes"] / 2**20, 2)
    report["below_1_GB"] = report["total_bytes"] < 1_000_000_000
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
