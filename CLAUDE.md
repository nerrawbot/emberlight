# Underworks Cavern

First-person Godot 4.7 scene: a dark, foggy, blue/purple industrial cavern, recreated from a 2D painting. Art is built in Blender 5.2 from Python and exported as GLB; Godot assembles the scene from a script. The goal is atmosphere ("vibe") plus a walkable route that loops in both directions. It is not a full game.

## Paths
- Godot binary: `D:\Godot\Godot_v4.7.2-stable_win64_console.exe`
- Blender source file: `art_src/cavern.blend`. This is the source of truth for the level meshes; older parts were built interactively and have no script.
- Blender generators: `art_src/gen_lib.py` (helpers: boxmm, member, ibeam, cyl, truss, railing, stairs, rockslab, rockblob, fern, vine, remove_islands, join_into, pbr_mat, flat_mat); `v2_layout.py`, `v2_detail.py`, `v2_creatures.py`, `v2_props.py`
- Graded textures: `art_src/tex/` (Poly Haven CC0, recoloured to the palette). `art_src/` has a `.gdignore`, so Godot cannot load from it. Copy any texture Godot needs into `assets/tex/`.
- `art_src/lights.json`: light, puddle and lamp positions plus floor heights, all in Blender coordinates. `tools/build_main.gd` reads it.
- `art_src/runner.py`: `godot_bg()` runs Godot from Blender on a background thread and writes output to a log file.

Shortcut: `tools\godot.cmd <args>` runs the Godot console binary with `--path` already set to the project, e.g. `tools\godot.cmd --headless res://scenes/main.tscn -- --walktest`.

## Coordinates
Blender is Z-up and Godot is Y-up: Blender (x, y, z) becomes Godot (x, z, -y). `b2g()` in build_main.gd does this. Creatures and props are modelled facing Blender +Y, which is Godot -Z (forward).

## Pipeline
1. Edit in Blender, then join each collection into one object with `join_into()`. The name suffix sets collision: `-col` gives a mesh plus trimesh StaticBody, `-colonly` gives collision only and no mesh. Remove materials from `-colonly` objects.
2. Export `assets/level/cavern.glb` with these objects: Rock-col, Concrete-col, Steel-col, Detail, Background, Framing, Foliage, Lamps, Surface-col, SurfaceDeco-col, StairRamps-colonly, Struct2-col, Detail2, Proxies-colonly, Ramps2-colonly, Lamps2, Water. Props are in `assets/props/*.glb` and creatures in `assets/creatures/*.glb`. Moving parts are separate named nodes: Handle, Wheel, Button, Lamp, Leg_L0..R2, Wing_L/R, Neck/Head/Lens.
3. `godot --headless --path . --import`
4. `godot --headless --path . --script res://tools/build_main.gd` regenerates `scenes/main.tscn` and `scenes/player.tscn`. **It overwrites main.tscn.** Make scene changes in build_main.gd, or stop using it once you start editing main.tscn by hand.
5. Test with `godot --headless --path . res://scenes/main.tscn -- --walktest`. It runs `tools/walk_test.gd`, which covers 30 checks: every route both ways, ladder, bridge, powered lift, gate, valve and crate. The last run had 0 fails.
6. Render with `godot --path . res://scenes/main.tscn -- --shots` (not headless). It writes `shots/shot_XX.png`. Renders freeze on one frame if the window is covered or minimised.

## Level layout (Blender coords; deck heights are Z)
- Start deck at Z18, X -1..19. The player spawns at (3, 1.5, 18) facing +X, towards the shaft.
- Mezzanine at Z23.5, Y 6.4..8.8, reached by a ladder at X12, Y6.2. The ladder Area3D needs the `climb_normal` setting and the thin `ladder_back` collision wall to work.
- Catwalk bridge from the mezzanine to C deck: (18.3, 7.5, 23.5) to (27.5, 7.0, 23.25) to (36.4, 6.6, 25).
- Central shaft X 19..26. The mid deck is at Z13, X 26..44, and the shaft can be jumped from the catwalk stub at Y 0.6..2.6.
- Right structure: A deck Z13 (X 44..67), B decks Z19, C deck Z25 (X 36..61). Stairs: floor to A (Y9.55), A to B (Y-2.2), B to C (Y6.1), C to surface exit (Y3.2, top Z34.3).
- Lift: car footprint X 19.2..22.2, Y -4.4..-1.4, running from 0.2 to 18.0. It needs power from the breaker lever on B2 at (71.6, 2, 19). There is a boom gate at the top landing.
- Low ledge at Z1.6, X 0..13, Y -10..-5, with a stair from the floor at Y -7.5.
- Exit trigger at (25.6, 3.2, 35.6). `ExitToSurface.next_scene` is still empty.

## Godot scripts (`scripts/`)
- `player.gd`: CharacterBody3D first-person controller with ladders, step-up, coyote time, rigid-body pushing, `show_toast` and `show_banner`. Input actions are registered at runtime.
- `interactable.gd`: base Area3D. Subclasses extend it by path (`extends "res://scripts/interactable.gd"`) and use `get_prompt()` and `_on_interact()`. Subclasses: breaker_lever, steam_valve (group `steam_vents`), crate_handle (child Area3D of a RigidBody3D), call_box.
- `power_grid.gd`: node in group `power_grid` with a `power_changed` signal. The level starts unpowered.
- `powered_light.gd`, `flicker_light.gd`, `lift.gd` (AnimatableBody3D), `boom_gate.gd`, `ladder.gd`, `exit_zone.gd`
- `creatures/`: scuttler.gd (CharacterBody3D on collision layer 8 so it doesn't block the player; uses edge raycasts), moth.gd, watcher.gd (SpotLight beam that tracks the player when it has line of sight)

## Pitfalls already hit
- **Never run Godot synchronously from Blender's Python, and never `time.sleep()` there.** Both freeze Blender's UI. Run Godot from a shell (preferred in Claude Code) or with `godot_bg()`.
- New Blender collections link to `bpy.context.scene`. If the active scene is "Preview" (the screenshot helper scene), objects end up outside the main scene. Switch to the "Scene" scene first.
- `part()` in v2_creatures.py deletes any existing object with the same name, so keep object names unique.
- In headless SceneTree scripts, `root` is a reserved name; build_main.gd uses `main_root`.
- Use `str()` or explicit types where `:=` would infer Variant; GDScript treats that as an error.
- **glTF export walks every scene in the .blend** (Preview, Scene, StartRoom) unless you pass `use_active_scene=True`, and objects stay selected in other scenes' view layers. Always export with `use_selection=True, use_active_scene=True`. `temp_override(scene=...)` around the exporter crashes Blender.
- Inside an MCP script, `bpy.context.scene` can still be "Scene" after you set `bpy.context.window.scene`.
- Blender fallback when the MCP connection drops: `D:\Blender\blender.exe --background art_src\cavern.blend --python <script>`. A background run doesn't save unless the script calls `bpy.ops.wm.save_mainfile()`. If it does save, reload the file in the open Blender (File > Revert) before working there.
- Moving geometry inside a shadowed lamp's range forces that lamp to redraw its shadow map **every frame, even if the mesh has `cast_shadow` off**. Moving things (moths, watchers, distant scuttlers) therefore live on render layer 2, and shadowed lights use `shadow_caster_mask = 1`.
- `stairs()` in gen_lib must be called bottom → top. Called top → bottom it silently builds only 2 steps.
- Stair treads that collide make the player hop down stairs. For rooms with `max_safe_fall`, use v4's `flight()`: visual treads with a smooth ramp and invisible rails.

## v3 changes (2026-10-03)
- The lift has 3 stops (0.2 floor, 18.0 deck, 34.3 surface). It runs up a shaft cut through the rock and surface to a headframe with a turning sheave (`assets/props/sheave.glb`). The car has CarUp/CarDown buttons; landing boxes are CallBottom, CallDeck and CallSurface. Safety booms are DeckGate and SurfaceGate.
- The stair 3 exit is closed by `StairGate` (`stair_gate.gd`, `assets/props/stair_gate.glb`). It is bolted from the surface side, and invisible `StairGuard` walls stop players jumping round it. `ExitToSurface` (the "to be continued" banner) is now at the surface lift landing.
- A tunnel behind the low-ledge walkway (Blender `Tunnel-col`) leads to `Tunnel/ExitToStart`, which loads `scenes/start.tscn`, now the project's main scene. Exit zones set `target_spawn`, and the player lands on the matching `Spawns/*` marker (group `spawn_point`).
- Blender script: `art_src/v3_lift_tunnel.py` (carve, build_lift3, build_tunnel, build_props3, export_level, export_prop). The level export now also includes `Lift3-col` and `Tunnel-col`. Backups of the pre-v3 files are in `art_src/backup/`.
- Debug tools: `tools/peek.gd` renders arbitrary camera views (`scene=res://...` picks the scene). `tools/bench.gd` measures performance: `tools\godot.cmd --disable-vsync --script res://tools/bench.gd [-- power] [start] [quick] [exp=a,b]`, not headless. The `exp=` flags switch features off to measure what they cost.

## v4: starting room + optimization (2026-10-03)
- **Start room** (`scenes/start.tscn`, built by `tools/build_start.gd` from `assets/level/start.glb` + `assets/props/drawbridge.glb`). The geometry comes from `art_src/v4_start_room.py` in the Blender scene **"StartRoom"**: call `build_all()` then `export_all()`. Its layout numbers live in the `L` dict, which is also written to `art_src/start_room.json` for Godot. It's a ~50 m tall irregular rock shaft. Route: spawn platform Z38 → catwalk → shelf with boiler → stairs along the back wall → landing L1 Z31 → pipe-machinery ledge Z24. There, the **HydraulicValve** (`bridge_valve.gd`) lowers the **Drawbridge** (`drawbridge.gd`) to the left landing. Then the ladder → broken-arch ledge Z13 → stairs → lit bottom bridge Z5 → tunnel → `ExitToCavern` (main.tscn spawn `FromStart`).
- The player has `max_safe_fall` (6 m in the start room, off in the cavern), `die()`, `reset_fall()`, and a HUD `Fade`. `checkpoint.gd` sets the respawn point and `kill_zone.gd` covers the water. Invisible `Safety/Guards` stop players jumping the drawbridge gap.
- Walk test: `tools\godot.cmd --headless res://scenes/start.tscn -- --walktest` covers the start room, then the cavern: **50 checks, 0 fails**.
- **Optimization results** (Arc A380, 1600x900): cavern mean GPU time went from 25.4 to 12.9 ms, CPU from 3.6 to 1.3 ms, VRAM from 854 to 578 MB, and every benchmark view is now ≤16.6 ms. The start room averages 11.8 ms. Changes:
  - no shadows on the haze fill lights;
  - shadows on the other lamps cut off beyond 28 m from the camera (`distance_fade_shadow`; the lights stay on);
  - shadow atlases at 4096;
  - fog volume at 80;
  - moths, watchers and distant scuttlers moved to render layer 2, with shadowed lights using `shadow_caster_mask = 1`;
  - scuttlers more than 35 m away think at a quarter rate.

- **Player moves:**
  - **Dash:** Shift replaces sprint. It's a 0.16 s burst at 15 m/s, with a 0.55 s cooldown and one dash in the air.
  - **Stick:** left mouse button or Q swings it. A body-height box about 1.7 m in front of you calls `take_hit(by, dir)` on whatever it hits (scuttlers stagger, then flee) or shoves rigid bodies.
  - **Jump:** hold Space for full height, tap for a short hop. You fall faster than you rise, with a short hang at the top, and the view dips on landing.
  - Walk test: 53 checks.

## v5: weapon, health, the mesa surface (2026-10-04)
- **Weapon:** `art_src/v5_weapon.py` (Blender scene "Props5") builds a steel shaft and exports `assets/props/shaft.glb`. The origin is at the grip and the shaft runs along +Z (Godot +Y). It has a leather wrap, a hex collar, weld bands and a bolted coupling head. Texture: `art_src/tex/shaft_*` (Poly Haven metal_plate_02, graded). In the start room it leans on a crate at the west end of the bottom bridge (`Pickup/SteelShaft`, `weapon_pickup.gd`) under a spot beam. `player.give_weapon()` adds it; `attack()` does nothing without it. View-model pose: `SHAFT_REST_POS/ROT` in player.gd.
- **Cross-scene state:** `scripts/game_state.gd` (preload it; it's not an autoload) stores state as root metadata. Keys: `has_weapon`, `health`, `powered@<scene path>`, `stair_gate_open`, `car_ride`, `fade_in`. `exit_zone.gd` has a `set_flags` dict. Exit, checkpoint and kill zones use `collision_layer = 0` so they never block the interact ray.
- **Health:** `player.take_damage()/heal()` with regen after 6 s. Falls longer than `hurt_fall` (4.5 m) do 9 damage per extra metre, in every scene. Falls longer than `max_safe_fall + 3` are fatal where `max_safe_fall` is set (start room, surface). HUD `HealthArc` (`health_arc.gd`) is a segmented semicircle at the bottom centre with a damage trail and a low-health pulse; `HurtFlash` flashes red. Prompt and Toast moved up to make room.
- **Surface = `scenes/surface.tscn`** (built by `tools/build_surface.gd` from `assets/level/surface.glb`). Geometry is from `art_src/v5_surface.py` in Blender scene **"Surface5"**: run `build_all()` then `export_all()`. Layout lives in `L5`, also written to `art_src/surface.json`. It uses main's coordinate frame and reuses `Lift3-col`.
  - The scene: a dark-blue mesa (Poly Haven rocks_ground_04 and marble_cliff_04 graded into `mesa_*` textures), a low gold sun in the ESE, cream depth and height fog, and 44 slender spires (no shadows).
  - Route: lift landing → stair 1 → gallery Z40 → link deck → K-braced tower with stair 2 → Z46 → gantry → block C roof, the lookout (end banner). Falling off the edge hits the kill zone at y 12.
  - Look: the ground's sky specular is lowered in build_surface.gd (it turned the blue rock brown). Volumetric fog stays thin (0.002), since sunlit near-haze tans everything.
- **Transitions:**
  - **Lift:** the swap happens mid-ride inside the shaft. main's `lift.gd` (`handoff_scene`, `handoff_y` 30.4) calls `player.change_scene_by_lift()`, a 0.22 s dip that records height, offset, yaw and pitch in `car_ride`. In surface.tscn, `LiftRig/Car` (`surface_car.gd`) carries on up to 34.3. CarDown → `ride_down()` → hands back to main's lift at 30.6, which carries on down to the deck.
  - **Fallback and stairs:** main's `ExitToSurface` (landing) is a fallback. Stair 3 links both ways: `ExitStairsToSurface` ↔ surface `ExitDownStairs`, with spawns `FromStairs` and `FromSurfaceStairs`. The gate's open state is shared between the two scenes.
- Walk test: **70 checks, 0 fails** from start.tscn (52 cavern-only). It now covers the pickup, fall damage and a full surface trip. Debug tools: `tools/hud_shot.gd` renders through the player camera with the HUD (`env:prop=val`, `set:Node:prop=val`, `weapon`, `hp=`). `bench.gd -- surface` → mean 7.8 ms GPU.

## v6: bigger, rugged mesa + the route past the lookout (2026-10-04)
- `art_src/v5_surface.py` was edited in place (pre-v6 copies in `art_src/backup/pre_v6/`). Same entry points: `build_all()`, `export_all()`.
  - **Terrain:** rim ~96 m. `ground_h()` adds ridged, terraced rises; the `FLAT` pads (x0, x1, y0, y1, falloff) keep the route and every building flat. A deep cove in the SE sits right below block C.
  - **Route extension:** block C → bridge 1 (south) → pinnacle deck Z46 (a rock stack in the cove, with a hut and a jib crane) → bridge 2 (east) → silo landing Z46 (cantilevered) → flight A → flight B → silo roof Z56. The end banner `Lookout` is on the silo roof; checkpoints `CP_Pinnacle` and `CP_Silo` cover the new stretch. Layout numbers are in `L5`.
  - **Scenery (solid):** `frame_ruin`, `water_tower`, `pump_house` (its pipe runs to bunker A), `tower_block`, two `lattice` pylons and a power line, plus detail on the existing works: windows, string courses, roof clutter, downpipes, crates.
  - **Hitboxes:** every reachable railing goes through `rail()`, `guard()` or `gflight()`: an invisible box 1.8 m tall (the jump apex is ~1.4 m; the old 1.2 m guards could be jumped). Braces at walking height are now in the `-col` mesh. Fixed open edges at the gallery east edge and block C north (x 54..57).
- **Textures:** `art_src/v6_textures.py` grades Poly Haven CC0 sets (downloaded via the Blender MCP) into the palette: mesa_gravel/dirt/moss/cliff2, concrete2 (precast panels), concrete3 (pale painted) and rustsheet. ORM red channel = height.
  - The mesa uses `scripts/mesa_terrain.gdshader`, which blends layers by the `TerrainMask` vertex colour (R gravel, G moss, B dirt, A strata), with triplanar rock above ~23° slope. The mesa_* textures are copied to `assets/tex/`.
  - The export passes `export_vertex_color='NAME'`.
- **Pitfall fixed:** `build_surface.gd` changed nodes inside the instanced glb (material overrides, `cast_shadow`), but `PackedScene.pack()` silently dropped those changes until `set_editable_instance(level, true)`. Check build_main/build_start for the same pattern if their glb tweaks seem not to apply.
- **Palette:** cream-grey sky and fog, a less saturated sun, ambient light with a hint of blue, saturation 0.92. The banner em-dashes are fixed (they were double-encoded).
- **Walk test:** 100 checks, including the new route both ways and 21 `_rail()` checks (run, jump and dash at each railing). The only failure is the start room's "fatal drop": `player.gd:261` uses `max_safe_fall + 200`, which turns off fatal falls.
- **Debug:** `peek.gd ... collide` draws collision shapes. `bench.gd -- surface`: mean 10.5 ms GPU (max 13.3 ms at the landing).

## v7: minimap, area names, banner font (2026-10-04)
- **Names:** the region is **Forsaken Debris**; The Heretic is the mountain. start.tscn = *The Heretic – Upper Subterranean*, main.tscn = *The Heretic – Lower Subterranean*, surface.tscn = *The Complex* (formerly "the mesa"). The intro/lookout banners were renamed in the build scripts and patched directly into start.tscn/surface.tscn (no rebuild).
- **Minimap** (`scripts/minimap.gd` + `minimap.gdshader`): `player.gd` adds it to the HUD at runtime (`_add_minimap()`, so player.tscn wasn't rebuilt). A round corner map turns with the player; **M** (`toggle_map`) opens a north-up map of the whole scene. It shows exits (every `exit_zone.gd`: amber, pinned to the rim when out of range, ▲/▼ when >3 m above or below) and the `enemies` group (red). Scuttlers aren't shown.
  - The data is baked: `tools\godot.cmd --headless --script res://tools/bake_map.gd [-- start main surface]` writes `assets/map/<scene>.res` (`scripts/map_info.gd`: an RGBA8 texture with up to 4 walkable floor heights per texel, highest first, 0 = none) plus a preview at `shots/map_<scene>.png`. **Re-bake after changing a level's collision.** Scene titles, caps and texel sizes are in `SCENES`.
  - The bake raycasts down per texel. A floor needs normal.y > 0.64, support under 3 of 4 points 0.35 m out (this drops guard tops and rails), and 1.7 m headroom (this drops rock lumps buried in the ceiling). It then flood-fills from known standing spots (spawns, both ends of every Area3D, creatures) with a 0.5 m step limit and crops to what's reachable. Moving bodies (lift car, drawbridge, crates) are left out.
  - The shader draws the highest floor at or below the player's last standing height + 1.1 m, darkening with depth, with outlines at drops and hatching under decks overhead. In `hud_shot.gd`, player physics is off, so pass `set:Player/HUD/Minimap:_ref_y=100.0` before a view (and `set:Player/HUD/Minimap:big=true` for the M map).
- **Banner font:** Cinzel (`assets/fonts/Cinzel-Variable.ttf`, SIL OFL, licence beside it). `show_banner()` draws the first line bold (wght 700) and the rest in regular weight in `Banner/Sub`. The M map title uses it too.

## v8: stair 3 collapsed, lift collar, plants on the surface (2026-10-05)
- **main.tscn is now hand-edited — don't regenerate it with build_main.gd.** It already had editor tweaks the script doesn't make (SurfaceSun colour (1, 0.906, 0.6), `FogVolumes/SurfaceClear` hidden, some particle settings), and build_main also overwrites player.tscn. build_main.gd mirrors the v8 changes, but treat it as reference only. surface.tscn still comes from build_surface.gd (its one hand tweak, the sun colour, was carried into the script). Backups: `art_src/backup/pre_v8/`.
- **Stair 3 is gone as a route; the lift is the only way between the cavern and the surface.** `art_src/v8_collapse.py` (it execs v5_surface.py; Blender scene "Surface5", collection `S8_CollapseC`): `build_collapse()`, then `export_collapse()` with Surface5 active → `assets/level/collapse.glb`. That holds `Collapse-col` and `CollapseBlock-colonly`, and both scenes instance it as `Collapse`.
  - It's one plug shared by both scenes, which use the same coordinate frame here. A heightfield slab (top ~G-0.6, underside ~G-2.35) covers main's whole opening (x 31.6..47.4, y -0.1..8.1). A rubble talus buries main's upper flight from x 41.3 (toe) upward, and a rubble heap sits on top for the surface view. Its top stays below G everywhere, so in surface.tscn everything outside the well is hidden under the terrain.
  - The pinholes (`C8["holes"]`) are tilted down-east, in line with the view from main's stair, so they show sky from below. main.tscn adds `CollapseBeams`: 5 thin unshadowed spots down the hole axes with fog energy 6, which give the light shafts. If you move the holes, `build_collapse()` prints new positions for them. surface.tscn has a dim blue `CollapseGlow` under the plug.
  - `StairGate` stays in both scenes with `collapsed = true` (new export in stair_gate.gd: it never opens and shows a toast). `ExitStairsToSurface`, `ExitDownStairs` and the `FromStairs`/`FromSurfaceStairs` spawns are removed. The surface well now has a full floor and an end wall (the black `pit_door` card is gone).
- **Lift collar (surface only):** `lift_collar()` in v5_surface.py adds steel plates at G-0.004 (just under the curb and sill, to avoid z-fighting) filling the hole round the parked car. The car *model* is wider than its collision box (x ±1.68 vs ±1.5), so the opening follows the model: x 18.99..22.42, y -4.49..-1.31. What's left round the car is ≤0.22 m, too narrow for the player (radius 0.35).
- **Plants** (v5_surface.py `plants()`, called from `build_structures()`; tune materials in `mats8()`):
  - **Ivy:** `ivy_wall()` (sheets hanging from parapets or climbing from the ground, with a ragged edge and stems) and `ivy_post()` (wound round legs and poles) → `S5_Ivy`.
  - **Shrubs:** `shrub()` leaf clouds with twigs, at building feet, beside boulders, round the frame ruin and scattered → `S5_Shrubs`.
  - **Trees:** `gnarled_tree()`, about 12 of them leaning with `WIND`, every 4th one dead → `S5_Trees`. Their trunks get 0.42 m collision posts in `S5_Ramps-colonly`.
  - **Placement:** `clear_spot()` keeps plants off the main route lines and building footprints (`KEEP_CLEAR_SEGS/BOXES`).
  - **Look:** all plants are flat-colour double-sided leaf cards, kept darker and cooler than they look in Blender because the gold sun yellows them. Ivy and shrubs don't cast shadows (build_surface.gd); the trees do.
- `enemy_spawner.gd` `min_ground_y` is now 34.1, so nothing spawns on the heap in the well.
- Minimaps re-baked (main, surface). The walk test's stair-3 checks are now "collapse blocks stair 3" / "gate stays shut", and three `surface: collar ...` checks were added. The walk test wasn't run this session (the user runs it).
- Bench: surface mean 10.7 ms GPU (max 13.7 at the landing; ivy ~200k verts); cavern (power) 13.5 ms, the same as before the change (13.46).

## v9: the warden drone + shield (2026-10-05)
- **Model:** `art_src/v9_drone.py` (Blender scene "Props9", collection DRONE9): `build_drone()`, then `export_drone()` with Props9 active → `assets/props/drone.glb`.
  - It's branched from the moth (v2_creatures.py) at about 60% of the size.
  - Parts: `DBody`, `DCore` (core + lens, new emissive `M_DroneCore`), `DRing` (emitter halo, spins around Y), `DWing_L/R` (hinged at the body, flap on rotation.z like the moth).
- **Pickup:** `DronePickup` (`drone_pickup.gd`, built by build_surface.gd) lies broken on the K-tower's top deck at Blender (60.0, -9.9, 46.0), east of the stair 2 → gantry walk.
  - [E] calls `player.use_item("repair_kit")`. Items are a placeholder: GameState `items`, which defaults to `{"repair_kit": 1}`.
  - On a successful repair the drone rights itself and lifts off, then `player.give_drone(transform)` hands it over. GameState `has_drone` removes the pickup for good.
- **Companion:** `drone_companion.gd` runs as `WardenDrone`, a sibling of the player that player.gd spawns in every scene while `has_drone` is set.
  - It orbits about 2.4 m out and 0.75 m above head height, and pulls in when a wall is in the way.
  - It sits on render layer 2 and casts no shadow.
  - When the shield is hit, the core flares and a bubble flashes round the player. While the shield is down it sinks, flaps slowly and splutters.
- **Shield (player.gd):**
  - Settings: `shield_max` 15 (1 block of `shield_block` 15), `shield_regen_delay` 4 s, `shield_regen_rate` 6/s. Health is 10 s / 2/s.
  - `take_damage()` drains the shield first. Any damage resets the shield's regen timer, but a hit the shield fully soaks doesn't reset the health regen timer.
  - New signal: `shield_changed(value, max, block, has)`. The shield refills on `die()` and is persisted as GameState `shield`.
- **HUD:** `HUD/ShieldArc` (`shield_arc.gd`, added at runtime by `_add_shield_arc()`; player.tscn is not rebuilt) is a thin neutral-grey arc at radius 110 over the health dome, one segment per block. It's hidden until you have the drone, and its track blinks while the shield is down.
- **hud_shot.gd:** new `drone` and `shield=N` options.
- **Walk test:** it doesn't cover the drone yet. Picking it up mid-run would change the fall-damage checks that come after it.

## v10: the Peak (boss arena) + radio mast — model only (2026-10-05)
- **Separate Blender file:** `art_src/peak.blend`, scene "Peak10". `REF_Mesa` holds copies of the mesa objects for reference only (never exported). Script `art_src/v10_peak.py` (it execs v5_surface.py for the helpers and `ground_h`/`rim_radius`): `build_all()` then `export_all()` → `assets/level/peak.glb` + `art_src/peak.json` (layout, mast ladders with climb normals, checkpoints, lamp positions, gate bottoms + lift heights; Blender coords). Numbers live in `P10`.
- **Placement:** off the SW rim, plateau centre 185 m from the mesa centre on bearing -130°. Same coordinate frame as surface.tscn.
- **Approach (~59 m):** arch stub → fallen slab → trestle A + sagging bridge span → trestle B → girder on a pylon → arch stub 2 → plateau. Six jumps, 2.3–2.6 m, each ≤0.6 m up.
- **Plateau:** ~40 m radius, top 38 (`G2`). Flat pads round the hall, the landing and the path between; terraced rises with boulders, a survey lattice and a shed elsewhere. `TerrainMask` vertex colours are painted for `mesa_terrain.gdshader`.
- **Hall (arena):** a ruined concrete building on an irregular 11-sided outline (`BV`, hall-local, +X towards the mast), with no roof (two trusses span it, one hangs loose).
  - Floor 38.12, deliberately clear for the boss's rolling attack.
  - Gallery at 44.5 round segments 9, 10, 0, 1, 2, with stairs along s3 and s8.
  - Separate objects: `BossGate` (entrance shutter on s7), `ExitGate` (gallery door on s0), `HiddenDoor` (patched wall on s6 into the windowless annex = hidden room). All are modelled closed, with the origin at the bottom centre.
- **Mast:** A-frame legs (half-spread 15 at the foot Z22 → 3.6 at the neck Z88), the crossed tubes, two core pipes, bands at 44.5 / 61 / 76 / 90 (full floors = checkpoints), cabin at 104 (enterable, door on the east), antenna tip 162 (the tallest spire is ~154).
  - Route: ExitGate → landing → 12 m gantry → band 1 → square spiral outside the lattice (`mast_route()`: stairs, broken stairs, hops ≤2.6 m, an inclined girder, 5 ladders) → cabin.
  - Ladders follow the ladder.gd convention: the climber stands outside facing in, and the upper landing is in front at the top.
- **Hall details** (`hall_details()`, old radio station):
  - Inside: pipe runs, cable trays, caged wall lamps, junction boxes, a waveguide in from the mast, the control booth on the gallery (segment 10), signage, a hazard stripe on the gallery edge.
  - Outside: rain streaks, downpipes, vents, a lean-to (s3), a two-lift scaffold (s9, kept too low to reach the wall tops), a dish on the NE pilaster, rubble.
  - The arena floor stays empty.
- **Floating-part check:** `build_all(check_floaters=True)` lists every part not connected (through contact) to the ground or rock. It's at 0. Mast supports end on the nearest girder ring (`face_point()`, `mast_levels()`).
- **In surface.tscn** (`build_surface.gd` `build_peak()`; surface.tscn was confirmed script-generated, backups in `art_src/backup/pre_v10/`):
  - `Peak` glb instance (editable), with the ramps on layer 16 and `mesa_material()` on the rock.
  - `PeakArena/BossGate|ExitGate|HiddenDoor` (`scripts/peak_door.gd`: tween the glb node by `open_offset`, plus `open_flag` "peak_boss_down"). There's no boss yet, so both shutters start open.
  - `PeakArena/BossSpawn` marker; `MastLadders/Ladder_0..4`.
  - Checkpoints: CP_PeakLanding, CP_Bridge, CP_HallEntrance, CP_Band1..4, CP_Cabin.
  - `MastCabin` end banner; `PeakLights` (no shadows); spawn markers AtPeakBridge and AtMast.
  - `enemy_spawner.gd` `no_spawn` circles keep random enemies off the Peak, the bridge and the mast.
- **Minimap:** `bake_map.gd` surface clip is [-165, -100, 160, 200] and the cap is 110 (for the cabin). It has been re-baked.
- **Bench:** surface mean 10.88 ms GPU (max 13.6 at the landing), the same as before. None of the bench views is on the Peak.
- **Not done:** walk test coverage of the Peak; the boss itself (close BossGate on entry, set `peak_boss_down` when it dies).

## Ideas for next steps
- Remaining frame cost (~13 ms) is mostly fixed: the sun's shadow (~3 ms, needed for the light shafts), MSAA 2x (~1.6 ms), SSR (~1 ms) and fog (~0.8 ms). A Low/Medium quality preset could switch these off.
- The sheave's hanger blocks on the headframe look bulky. Make them thinner in `build_lift3`.
- The cavern floor is very dark and hazy when unpowered. Tune the `LowMist` density and the `off_energy` values in build_main.gd.
- The main scene's own surface plate (cream block-out) is now only seen briefly through the shaft or stairwell. The mesa is in surface.tscn.
- Nothing hurts the player except falls yet (steam vents or creatures could use `take_damage`).
- There is no audio yet.
