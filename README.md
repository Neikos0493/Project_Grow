# Project Grow

A Godot 4.7 exploration prototype with independently authored maps, in-place spaceship travel, farming, combat, and a single automatic save slot.

## Run

Open `project.godot` with Godot 4.7 and run the project, or use:

```bash
godot --path .
```

The main menu offers:

- **Continue** — restores the current map, player position, health, inventory, coins, quest progress, and each map's independent mutable state.
- **Start New Game** — resets the single automatic save after confirmation when an existing save is present.

The save is written to `user://autosave.json`. An internal `autosave.json.bak` is retained for recovery; game settings remain in `user://settings.cfg` and are not erased by New Game.

## Map architecture

`Main.tscn` is a persistent gameplay shell containing the player and shared UI. `MapHost` loads exactly one allowlisted map scene at a time:

- `greenmeadow` → `maps/Greenmeadow.tscn`
- `sunset_shore` → `maps/SunsetShore.tscn`

Each map owns its terrain, scenery, props, collisions, optional shop, and runtime entity containers. Per-map snapshots are stored under the map's stable ID, preventing farm tiles, drops, enemies, interactions, or Greenmeadow props from leaking into Sunset Shore.

## Headless smoke tests

With Godot 4.7 available on `PATH`:

```bash
godot --headless --path . --script res://tests/run_tests.gd
godot --headless --path . --script res://tests/smoke_main_scene.gd
godot --headless --path . --script res://tests/smoke_travel.gd
```

The suites check independent map content, one-map-at-a-time hosting, deep-copied per-map state, JSON and disk-save recovery, gameplay initialization, in-place round-trip travel, destination-map arrival, and health/state preservation.
