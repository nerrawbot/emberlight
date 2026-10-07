# Emberlight

First-person Godot 4.7 game: dark, foggy, blue/purple industrial caverns, recreated from a 2D painting. Art is built in Blender 5.2 from Python and exported as GLB; Godot assembles scenes from scripts. Atmosphere ("vibe") first, with walkable routes that loop both ways.

## Paths
- Godot: `D:\Godot\Godot_v4.7.2-stable_win64_console.exe`. Shortcut: `tools\godot.cmd <args>` (sets `--path`).
- Blender source: `art_src/cavern.blend` (level meshes' source of truth); `art_src/peak.blend` (Peak). Generators in `art_src/`: `gen_lib.py` (helpers), `v2_*.py`, `v3_lift_tunnel.py`, `v4_start_room.py`, `v5_surface.py` (+`v8_collapse.py`, `v12_floaters.py`), `v5_weapon.py`, `v9_drone.py`, `v10_peak.py`, `v11_crates.py`, `v12_station.py`, `v13_sphaeroid.py`, `v15_cable_station.py` (cable car station; run with `--background art_src\peak.blend`, exports `assets/level/cable_station.glb` + `assets/props/cable_car.glb`, no save), `v14_pennon.py` (the glider wing; standalone, `--background --factory-startup` exports `assets/props/pennon.glb`), `v13_paint.py` (Sphaeroid's painted maps; `blender --background --factory-startup --python art_src\v13_paint.py`).
- Textures: `art_src/tex/` (Poly Haven CC0, graded to the palette). `art_src/` has `.gdignore`; copy anything Godot needs into `assets/tex/`.
- `art_src/lights.json`, `start_room.json`, `surface.json`, `peak.json`, `station.json`: layout data in Blender coords, read by `tools/build_*.gd`.
- Scenes: `scenes/start.tscn` (main scene), `main.tscn`, `surface.tscn`, `player.tscn`. Scripts: `scripts/`, `scripts/creatures/`, `scripts/dialogue/`. Tools: `tools/`.

## Coordinates
Blender is Z-up, Godot is Y-up: Blender (x, y, z) -> Godot (x, z, -y) (`b2g()` in build_main.gd). Models face Blender +Y = Godot -Z.

## Pipeline
1. Edit in Blender; join each collection with `join_into()`. Name suffix sets collision: `-col` = mesh + trimesh StaticBody, `-colonly` = collision only (remove its materials).
2. Export GLB with `use_selection=True, use_active_scene=True` (glTF export otherwise walks every scene in the .blend). Level: `assets/level/*.glb`; props `assets/props/`; creatures `assets/creatures/`. Moving parts are separate named nodes.
3. `godot --headless --path . --import`
4. Regenerate scenes with `tools/build_<scene>.gd` (`godot --headless --path . --script res://tools/build_surface.gd`). **main.tscn is hand-edited now: don't run build_main.gd** (it also overwrites player.tscn). build_start.gd, build_surface.gd still generate their scenes.
5. Tests (headless): `tools\godot.cmd --headless res://scenes/start.tscn -- --walktest` (routes both ways, rails, fall damage), `--script res://tools/story_test.gd` (dialogue, crates, drops, inventory), `--script res://tools/boss_test.gd -- --noenemies`, `--script res://tools/check_compile.gd` (script compile errors).
6. Playtest: `tools\godot.cmd res://scenes/start.tscn -- --boss` starts outside the Peak hall with everything. In game, ` or F1 opens the debug console (`scripts/debug_console.gd`, pauses; `help`: boss, annex, station, pennon, god, heal, give, tp, bosshp, fight, kill, scene).
7. Render: `godot --path . res://scenes/main.tscn -- --shots` (not headless; freezes if window is covered). `tools/peek.gd` (arbitrary camera views, `collide` draws collision), `tools/hud_shot.gd` (player camera + HUD), `tools/bench.gd` (GPU/CPU timing, `-- surface`), `tools/probe_points.gd` (floor heights at x,y).
8. After changing a level's collision, re-bake minimap: `tools\godot.cmd --headless --script res://tools/bake_map.gd [-- start main surface]`.

## Pitfalls
- Never run Godot synchronously from Blender Python or `time.sleep()` there (freezes the UI). Run from a shell, or `godot_bg()` in `art_src/runner.py`. Fallback if the Blender MCP drops: `D:\Blender\blender.exe --background art_src\cavern.blend --python <script>` (call `bpy.ops.wm.save_mainfile()` to save, then File > Revert in the open Blender).
- New Blender collections link to `bpy.context.scene`; switch to the right scene first (Scene, StartRoom, Surface5, Props5/9/11/12/13, Peak10). In MCP scripts `bpy.context.scene` can lag behind `window.scene`. `temp_override(scene=...)` around the exporter crashes Blender.
- `part()` in v2_creatures.py deletes same-named objects; keep names unique. `stairs()` in gen_lib must be called bottom -> top.
- GDScript: use `main_root` (not `root`) in SceneTree scripts; avoid `:=` where it infers Variant.
- `PackedScene.pack()` drops changes to nodes inside an instanced glb unless `set_editable_instance(level, true)`.
- Moving geometry inside a shadowed lamp's range redraws its shadow map every frame. Moving things (moths, watchers, distant scuttlers, drone) go on render layer 2; shadowed lights use `shadow_caster_mask = 1`.
- Colliding stair treads make the player hop; use `flight()` (visual treads + smooth ramp + invisible rails). Reachable railings use invisible 1.8 m guards (jump apex ~1.4 m).
- Exit/checkpoint/kill zones use `collision_layer = 0` so they never block the interact ray. Scuttlers are on layer 8 so they don't block the player.
- Project root is `D:\Emberlight` (formerly UnderworksCavern); the generators' `PROJ` paths use it. Old backups in `art_src/backup/` may still reference the old path.

## World
Region: Forsaken Debris. The Heretic is the mountain.
- **start.tscn** (The Heretic - Upper Subterranean): ~50 m rock shaft. Route: spawn platform -> catwalk -> boiler shelf -> stairs -> landing -> HydraulicValve lowers the Drawbridge -> ladder -> arch ledge -> bottom bridge (steel shaft pickup) -> tunnel -> `ExitToCavern`. Fatal falls via `max_safe_fall`.
- **main.tscn** (Lower Subterranean): start deck Z18, mezzanine + ladder, catwalk bridge, central shaft, right structure (decks A/B/C, stairs), low ledge + tunnel back to start. Level starts unpowered; breaker lever on B2 powers it. 3-stop lift (floor/deck/surface) needs power; stair 3 to the surface is collapsed (`Collapse` plug), so the lift is the only way up.
- **surface.tscn** (The Complex): mesa with works, plants, ruins, loot crates, SiloWatcher (SENTINEL-09), WardenDrone pickup on the K-tower, Patrol Station 4 on the bridge to the Peak. Terrain via `scripts/mesa_terrain.gdshader` and `TerrainMask` vertex colours. Painted sky `scripts/surface_sky.gdshader` (static, sun disk follows `Sun`). Buildings/props get the painterly look at runtime: `PainterlyWorld` node (`scripts/painterly_world.gd` + `.gdshader`, per-material `TUNE`; skips emissive/transparent, the mesa, player and creatures). The lift swap happens mid-ride (`lift.gd` handoff, `surface_car.gd`).
- **Peak** (in surface.tscn, `build_peak()`): ~59 m approach bridge, ruined hall = boss arena (BossGate/ExitGate/HiddenDoor via `peak_door.gd`), radio mast with 5 ladders and checkpoints, cabin at the top. The annex behind HiddenDoor holds the Pennon (`PeakArena/PennonPickup`, `AnnexLamp`; hand-added to surface.tscn and in build_surface.gd).
- **Cable car station** (in surface.tscn, `CableStation` node, `scripts/cable_station.gd`): a deck built out off the plateau's south-east rim, bullwheel, docked car (AnimatableBody you can stand in), one pylon, ropes running off into the void (the far terminal lives in the next area). The far side is broken: the call panel only makes the car lurch and clunk. GameState `cable_far_fixed` (future repair quest) makes the far terminal answer; the return ride isn't wired up yet. Spawn marker `FromCableCar` (in the car) is ready for it.

## Systems
- **Player** (`player.gd`): first-person controller (ladders, step-up, coyote time). Shift = dash; LMB/Q = swing the shaft (`take_hit(by, dir)`); Space hold = full jump. Health (regen 6 s delay) and shield (needs drone). Falls > `hurt_fall` hurt; `max_safe_fall` kills. HUD built at runtime: health/shield arcs, minimap (M = full map), toasts/banners (Cinzel font), pickup feed, boss bar, inventory (I).
- **Pennon** (glider): `pennon_pickup.gd`, `pennon_model.gd` (glb + painterly flat colours), `player.gd` v14 section. Space mid-air with `glide_min_height` (3 m) of air below opens it, Space again folds it; look to steer, down dives, up slows; accelerates to `dash_speed`, FOV + `glide_fov`; no fall damage while gliding; folds on landing, ladders, head-on walls. GameState `has_pennon`.
- **State** (`game_state.gd`, preload, not autoload; root metadata): `has_weapon`, `health`, `shield`, `has_drone`, `items`, `powered@<scene>`, `opened_crates`, `station_gate_open`, `peak_boss_down`, `mob_kills`, etc. Zones use `exit_zone.gd` (`target_spawn`, `set_flags`); player lands on `Spawns/*` (group `spawn_point`).
- **Interactables**: base `interactable.gd` (`get_prompt()`, `_on_interact()`): breaker_lever, steam_valve, crate_handle, call_box, bridge_valve, weapon_pickup, drone_pickup, supply_crate, station_reader, boss_unpower. Also `power_grid.gd`, `powered_light.gd`, `flicker_light.gd`, `lift.gd`, `boom_gate.gd`, `stair_gate.gd`, `ladder.gd` (needs `climb_normal` + thin `ladder_back` wall), `checkpoint.gd`, `kill_zone.gd`, `drawbridge.gd`.
- **Items** (`items.gd`): tokens, scrap, bars, voltaic_core, station passes; `kind` + `abbr`; real icons are picked up from `assets/icons/<id>.png`. Inventory pauses the tree.
- **Dialogue**: `watcher_talk.gd` -> `player.start_dialogue()` -> `dialogue_box.gd`; lines in `scripts/dialogue/watcher_lines.gd` (`need`/`need_not` test GameState; `{braces}` = corrupted text). SENTINEL-07 in main (hand-added Talk node), SENTINEL-09 in surface.
- **Drone**: repairing needs 3 voltaic cores (`drone_pickup.gd`); `drone_companion.gd` orbits the player and powers the shield.
- **Enemies**: `scuttler.gd`, `moth.gd`, `watcher.gd`, `enemy_spawner.gd` (counts kills; kill #6 drops the sealed station pass, later kills 7.5% for plain passes; `no_spawn` circles, `min_ground_y`). Boss `creatures/sphaeroid.gd` (1500 HP, strafes, hops back before cannon volleys, leap/roll/skates, phase 2 at 50%, `boss_arena.gd` runs the fight; arena resets on death). Painterly look: `creatures/painterly.gdshader` + `assets/creatures/sph_paint_*.png`, swapped in at runtime (`_paint_model()`), not in the glb. Player-blocking body = `Solid` AnimatableBody (layer 16) with `sync_to_physics = false` (with it on, it doesn't follow the moving parent).
- **Perf**: shadows on haze fills off, shadow distance fade 28 m, shadow atlas 4096, fog volume 80, distant scuttlers think at 1/4 rate. Cavern ~13 ms, surface ~11 ms GPU (Arc A380, 1600x900).

## Ideas / not done
- Low/Medium quality preset (sun shadow, MSAA, SSR, fog are the remaining cost).
- Unpowered cavern floor is very dark; tune `LowMist` and `off_energy` in build_main.gd (hand-edit main.tscn).
- Sheave hanger blocks on the headframe look bulky (`build_lift3`).
- Nothing but falls hurts the player yet (steam vents, creatures could use `take_damage`). No audio yet.
- Walk test doesn't cover the drone, Peak or station; passes aren't spendable yet.
