# Repository Guidelines

## Project Structure & Module Organization

This is an offline 3D RPG prototype using Godot 4 standard edition, GDScript, and the Compatibility renderer. The entry scene is `scenes/world.tscn`.

- `scripts/`: gameplay, navigation, procedural geometry, and UI. `world.gd` coordinates the game; `world_builder.gd` generates the map. Keep health, cooldown, and quest rules in their dedicated modules.
- `scenes/`: reusable text scenes for actors, projectiles, effects, and HUD.
- `resources/balance.tres`: tunable gameplay values; defaults live in `scripts/balance.gd`.
- `assets/`: SVG icons; most geometry is generated at runtime.
- `tests/`: custom logic, integration, visual, and input-driven playthrough runners.
- `tools/`: engine setup, launch wrapper, and storage reporting. Generated evidence goes in ignored `artifacts/`.

## Build, Test, and Development Commands

The README records validation with Godot 4.7.2. Use `GODOT_BIN=/path/to/godot` to select an installed engine; macOS and Linux x86_64 setup is `python3 tools/install_godot.py`. Optional Blender setup is `python3 tools/install_blender.py`; use `./tools/blender.sh --background --python path/to/script.py` or override `BLENDER_BIN`.

- `./run.sh`: import resources and launch the game.
- `./tools/godot.sh --editor`: open the project in Godot.
- `./verify.sh`: import resources, syntax-check test scripts, and run headless tests; errors and warnings fail verification.
- `./tools/godot.sh --script res://tests/visual_runner.gd`: capture visual evidence in a real window.
- `./tools/godot.sh --script res://tests/playthrough.gd`: exercise the quest through mouse and keyboard events.
- `./benchmark.sh` or `./benchmark.sh --low`: measure real-time performance with normal or reduced effects.

There is no standalone application build/export workflow yet.

On this macOS host, Blender 4.5.3 can crash during Metal device detection inside the Codex filesystem sandbox, even with `--background` and CPU rendering. Run Blender background work with the tool's approved unsandboxed execution mode; do not repeat the known failing sandboxed launch. Validate with `./tools/blender.sh --background --python-exit-code 1 --python tests/blender_smoke.py`. This is a local environment observation, not a Linux requirement.

## Coding Style & Naming Conventions

Match existing GDScript: tabs for indentation, `snake_case` filenames/functions/variables, `PascalCase` class names, and leading underscores for internal helpers. Use typed parameters and return values where practical. Keep balance changes in the resource instead of scattering constants. No separate formatter or linter is configured.

## Testing Guidelines

Tests use a custom `SceneTree` runner, with `_test_*` functions and descriptive `check(condition, message)` assertions. Register new cases in `_run()`. Add regression checks for gameplay changes and run `./verify.sh`. No numerical coverage threshold is configured. For visual changes, inspect screenshots; fixed-step tests do not measure performance.

## Commit & Pull Request Guidelines

History contains only `initial commit`, so no established message convention exists. Use concise, imperative subjects. PRs should explain changed behavior, validation commands/results, and relevant issues; include screenshots for visual changes. Keep `.tools/`, `.godot/`, and `artifacts/` out of commits.
