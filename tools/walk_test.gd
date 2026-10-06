extends Node
## Automated route test (forward AND reverse) incl. tunnel, ladder, bridge, 3-stop powered lift,
## surface stair gate and interactables. Lives on the scene-tree root (added by shot_tour.gd) so it
## survives the scene change when started from start.tscn.
##   godot --headless --path . res://scenes/start.tscn -- --walktest   (start scene -> cavern, then everything)
##   godot --headless --path . res://scenes/main.tscn -- --walktest    (cavern only)

var p
var fails := 0
var checks := 0

func _ready() -> void:
	_run.call_deferred()

func _release() -> void:
	for a in ["move_forward", "move_back", "dash", "jump"]:
		Input.action_release(a)

func _place(pos: Vector3, yaw: float, pitch := 0.0) -> void:
	p.global_position = pos
	p.rotation = Vector3(0, deg_to_rad(yaw), 0)
	p.get_node("Head").rotation = Vector3(deg_to_rad(pitch), 0, 0)
	p.velocity = Vector3.ZERO
	p.reset_fall()

func _wait(sec: float) -> void:
	for i in int(sec * Engine.physics_ticks_per_second):
		await get_tree().physics_frame

func _walk(label: String, pos: Vector3, yaw: float, secs: float, check: Callable, pitch := 0.0, sprint := false, jump_after := -1.0) -> void:
	_place(pos, yaw, pitch)
	await _hold(label, secs, check, sprint, jump_after)

## Walk forward from wherever the player is now.
func _hold(label: String, secs: float, check: Callable, sprint := false, jump_after := -1.0) -> void:
	_release()
	await _wait(0.4)
	Input.action_press("move_forward")
	if sprint and jump_after < 0.0:
		p.dash()
	if jump_after >= 0.0:
		await _wait(jump_after)
		Input.action_press("jump")      # held: full-height jump
		await _wait(0.3)
		if sprint:
			p.dash()                     # mid-air dash replaces the old sprint jump
		await _wait(0.15)
		Input.action_release("jump")
		await _wait(maxf(0.0, secs - jump_after - 0.45))
	else:
		await _wait(secs)
	_release()
	await _wait(0.6)
	_report(label, check.call(p.global_position))

func _report(label: String, ok: bool) -> void:
	if OS.get_cmdline_user_args().has("--debug"):
		print("   dbg fall_top=%.1f airborne=%s dying=%s input=%s ladders=%d safe=%.1f" % [p._fall_top, p._airborne, p._dying, p.input_enabled, p._ladders.size(), p.max_safe_fall])
	checks += 1
	if not ok:
		fails += 1
	print("[WALK] %s %s -> %s floor=%s" % ["PASS" if ok else "FAIL", label, str(p.global_position.snapped(Vector3(0.1, 0.1, 0.1))), str(p.is_on_floor())])

func _wait_lift(lift) -> void:
	await get_tree().physics_frame
	for i in 40 * 60:
		if not lift.moving:
			return
		await get_tree().physics_frame

func _scene() -> Node:
	return get_tree().current_scene

func _run() -> void:
	await get_tree().process_frame
	p = get_tree().get_first_node_in_group("player")
	if _scene().name == "Start":
		await _run_start()
	await _run_main()
	await _run_surface_trip()
	print("[WALK] DONE checks=%d fails=%d" % [checks, fails])
	get_tree().quit()

# ------------------------------------------------------------------ start.tscn -> main.tscn
func b(x: float, y: float, z: float) -> Vector3:   # Blender coords -> Godot
	return Vector3(x, z, -y)

func _run_start() -> void:
	await _wait(0.6)
	var s := _scene()
	var begin: Node3D = s.get_node("Spawns/Begin")
	var bridge = s.get_node("Puzzle/Drawbridge")
	var valve = s.get_node("Puzzle/HydraulicValve")
	_report("start: spawned on the top platform", p.global_position.distance_to(begin.global_position) < 0.5)
	await _hold("start: catwalk to the shelf", 3.0, func(v): return v.x > 3.0 and absf(v.y - 38.0) < 0.3)
	await _walk("start: flight1 down to L1", b(4.5, 5.5, 38.05), 90.0, 4.0, func(v): return v.x < -4.4 and absf(v.y - 31.0) < 0.3)
	await _walk("start: flight2 down to the pipe ledge", b(-6.0, 2.5, 31.05), -90.0, 4.0, func(v): return v.x > 4.2 and absf(v.y - 24.0) < 0.3)
	await _walk("start: guard stops jumping the gap", b(6.5, -0.5, 24.05), 90.0, 2.0, func(v): return v.x > 3.7 and absf(v.y - 24.0) < 0.3, 0.0, true, 0.5)
	await _walk("start: raised bridge blocks the way", b(6.5, -4.0, 24.05), 90.0, 2.0, func(v): return v.x > 3.7 and absf(v.y - 24.0) < 0.3)
	_place(b(5.4, valve.global_position.z * -1.0, 24.05), -90.0, -10.0)
	await _wait(0.3)
	var hit: bool = p.try_interact()
	await _wait(8.0)
	_report("start: valve lowers the drawbridge", hit and valve.is_open and absf(bridge.rotation.z) < 0.02)
	await _walk("start: cross the drawbridge", b(6.5, -4.0, 24.05), 90.0, 3.0, func(v): return v.x < -3.2 and absf(v.y - 24.0) < 0.3)
	var cp: Node3D = s.get_node("Safety/CP_LeftLanding")
	_report("start: checkpoint on the left landing", p.spawn_transform.origin.distance_to(cp.global_position) < 0.3)
	# ladder down: hold forward (looking down) only until the feet reach the arch ledge
	_place(b(-6.0, -3.4, 24.05), 0.0, -50.0)
	_release()
	await _wait(0.4)
	Input.action_press("move_forward")
	for i in 8 * 60:
		await get_tree().physics_frame
		if p.global_position.y < 13.2 and p.is_on_floor():
			break
	_release()
	await _wait(0.6)
	_report("start: ladder down to the arch ledge", absf(p.global_position.y - 13.0) < 0.3)
	await _walk("start: flight4 down to the bridge", b(-4.0, -3.6, 13.05), -90.0, 3.0, func(v): return v.x > 6.4 and absf(v.y - 5.0) < 0.3)
	_place(b(3.0, -1.0, 15.0), 0.0)    # lands on the bridge away from the bottom checkpoint
	await _wait(2.0)
	_report("start: fatal drop -> back to checkpoint", p.global_position.distance_to(cp.global_position) < 0.6)
	_place(b(-6.0, 4.0, 3.0), 0.0)
	await _wait(2.0)
	_report("start: deep water -> back to checkpoint", p.global_position.distance_to(cp.global_position) < 0.6)
	await _walk("start: ladder up from the arch ledge", b(-6.0, -1.5, 13.05), 180.0, 6.0, func(v): return absf(v.y - 24.0) < 0.3 and v.z > 2.4, 10.0)
	# the weapon: steel shaft leaning on a crate at the west end of the bottom bridge
	var swung0: bool = await p.attack()
	_report("start: no weapon before the pickup", not p.has_weapon and not swung0)
	_place(b(-4.8, -1.0, 5.05), 90.0, -25.0)
	await _wait(0.4)
	var took: bool = p.try_interact()
	await _wait(0.8)
	_report("start: pick up the steel shaft", took and p.has_weapon and s.get_node_or_null("Pickup/SteelShaft") == null)
	_place(b(8.0, -1.0, 5.05), -90.0)
	# walk east through the tunnel until the bulkhead trigger swaps the scene
	Input.action_press("move_forward")
	for i in 12 * 60:
		await get_tree().physics_frame
		if _scene() == null or _scene().name == "Main":
			break
	_release()
	for i in 120:
		if _scene() and _scene().name == "Main":
			break
		await get_tree().process_frame
	p = get_tree().get_first_node_in_group("player")
	_report("start -> cavern scene change", _scene() != null and _scene().name == "Main")
	await _wait(0.5)
	p = get_tree().get_first_node_in_group("player")
	var m: Node3D = _scene().get_node("Spawns/FromStart")
	_report("arrived at FromStart in the tunnel", p.global_position.distance_to(m.global_position) < 0.6)

# ------------------------------------------------------------------ main.tscn
func _run_main() -> void:
	var root := _scene()
	var grid = get_tree().get_first_node_in_group("power_grid")
	var lift = root.get_node("LiftRig/Lift")
	# the cavern checks stay in this scene: no hand-overs to the surface until _run_surface_trip()
	var exit = root.get_node("ExitToSurface")
	exit.next_scene = ""
	lift.handoff_scene = ""
	if not p.has_weapon:          # (cavern-only run)
		p.give_weapon(true)
	await _wait(0.6)
	# --- fall damage: a 10 m drop hurts but doesn't kill
	_place(Vector3(31, 10.2, 2.0), -90.0)
	await _wait(2.0)
	_report("10 m fall hurts (health %.0f)" % p.health, p.health < 70.0 and p.health > 20.0 and not p._dying)
	# --- tunnel <-> walkway
	await _walk("tunnel -> walkway", Vector3(-9.4, 1.65, 8.7), -90.0, 3.5, func(v): return v.x > 4.0 and absf(v.y - 1.6) < 0.25)
	var tex = root.get_node("Tunnel/ExitToStart")
	tex.next_scene = ""       # don't actually leave during the test
	await _walk("walkway -> tunnel exit", Vector3(8.0, 1.65, 8.7), 90.0, 5.0, func(v): return tex.get("_triggered"))
	# --- upper loop: start deck -> ladder -> mezzanine -> bridge -> C deck, and back
	await _walk("ladder up (start->mezz)", Vector3(12, 18.05, -4.6), 0.0, 3.5, func(v): return v.y > 23.3 and v.z < -6.4)
	await _walk("bridge mezz->C", Vector3(16, 23.55, -7.45), -92.6, 6.5, func(v): return v.x > 36.0 and absf(v.y - 25.0) < 0.3)
	await _walk("bridge C->mezz", Vector3(38, 25.05, -6.6), 90.0, 6.5, func(v): return v.x < 18.7 and absf(v.y - 23.5) < 0.3)
	await _walk("ladder down (mezz->start)", Vector3(12, 23.55, -7.0), 180.0, 4.0, func(v): return absf(v.y - 18.0) < 0.3, -50.0)
	# --- right structure, downwards
	await _walk("stair2 C->B2", Vector3(58, 25.05, -6.1), -90.0, 4.0, func(v): return v.x > 69.0 and absf(v.y - 19.0) < 0.3)
	await _walk("stair1 B2->A", Vector3(64.5, 19.05, 2.2), 90.0, 4.0, func(v): return v.x < 52.0 and absf(v.y - 13.0) < 0.3)
	await _walk("stair0 A->floor", Vector3(64.5, 13.05, -9.55), 90.0, 5.5, func(v): return v.x < 46.0 and v.y < 0.6)
	# --- upwards again
	await _walk("stair0 floor->A", Vector3(44.6, 0.4, -9.55), -90.0, 8.0, func(v): return absf(v.y - 13.0) < 0.3)
	await _walk("stair1 A->B2", Vector3(50.8, 13.1, 2.2), -90.0, 3.6, func(v): return absf(v.y - 19.0) < 0.3)
	await _walk("stair2 B2->C", Vector3(71.3, 19.1, -6.1), 90.0, 4.0, func(v): return absf(v.y - 25.0) < 0.3)
	# --- low ledge
	await _walk("floor->low ledge", Vector3(19.5, 0.2, 7.5), 90.0, 3.0, func(v): return absf(v.y - 1.6) < 0.25 and v.x < 13.0)
	await _walk("low ledge->floor", Vector3(10, 1.65, 7.5), -90.0, 3.5, func(v): return v.y < 0.5 and v.x > 18.0)
	# --- v8: stair 3 has caved in a few metres below the surface (assets/level/collapse.glb)
	var gate = root.get_node("StairGate")
	await _walk("collapse blocks stair3 from below", Vector3(48.4, 25.1, -3.2), 90.0, 8.0, func(v): return v.x > 39.0 and v.y < 32.0)
	# --- lift (needs power): floor -> deck -> surface
	var callb = root.get_node("LiftRig/CallBottom")
	callb.interact(p)
	await _wait(0.5)
	_report("lift refuses without power", not lift.moving)
	var lever = root.get_node("Interactables/BreakerLever")
	lever.interact(p)
	_report("breaker powers grid", grid.powered)
	callb.interact(p)
	await _wait_lift(lift)
	_report("lift arrives at bottom", lift.is_at(0))
	await _walk("walk into car (bottom)", Vector3(24.4, 0.15, 2.9), 90.0, 0.6, func(v): return v.x < 22.3 and v.x > 19.3)
	root.get_node("LiftRig/Lift/CarUp").interact(p)
	await _wait_lift(lift)
	await _wait(0.3)
	_report("ride up to the deck", absf(p.global_position.y - 18.0) < 0.35 and lift.is_at(1))
	root.get_node("LiftRig/Lift/CarUp").interact(p)
	await _wait_lift(lift)
	await _wait(0.3)
	_report("ride up to the surface", absf(p.global_position.y - 34.3) < 0.35 and lift.is_at(2))
	await _walk("lift -> surface landing", Vector3(21.2, 34.35, 2.9), -90.0, 2.0, func(v): return v.x > 23.6 and absf(v.y - 34.3) < 0.3)
	_report("surface exit triggered", exit.get("_triggered"))
	root.get_node("LiftRig/CallDeck").interact(p)   # send the car away
	await _wait(1.0)
	await _walk("surface gate blocks open shaft", Vector3(26.0, 34.35, 2.9), 90.0, 2.5, func(v): return v.x > 23.2 and absf(v.y - 34.3) < 0.3)
	await _wait_lift(lift)
	# --- the stair gate stays shut for good (the stairwell behind it has caved in)
	_place(Vector3(32.8, 34.35, -3.2), -90.0, 0.0)
	await _wait(0.4)
	var hit: bool = p.try_interact()
	await _wait(1.0)
	_report("stair gate stays shut (collapsed)", hit and not gate.is_open)
	# --- deck landing: gate + car
	root.get_node("LiftRig/CallBottom").interact(p)
	await _wait(1.0)
	await _walk("deck gate blocks open shaft", Vector3(16, 18.05, 2.9), -90.0, 2.0, func(v): return v.x < 18.7 and absf(v.y - 18.0) < 0.3)
	await _wait_lift(lift)
	root.get_node("LiftRig/CallDeck").interact(p)
	await _wait_lift(lift)
	await _walk("deck -> car (deck)", Vector3(16, 18.05, 2.9), -90.0, 1.2, func(v): return v.x > 19.3 and absf(v.y - 18.0) < 0.3)
	root.get_node("LiftRig/Lift/CarDown").interact(p)
	await _wait_lift(lift)
	await _wait(0.3)
	_report("ride down to the floor", p.global_position.y < 0.6 and lift.is_at(0))
	# --- jump
	await _walk("jump shaft (catwalk->mid deck)", Vector3(20.0, 18.05, -1.6), -90.0, 2.2, func(v): return v.x > 26.0 and absf(v.y - 13.0) < 0.3, 0.0, true, 0.28)
	# --- interactables
	var valve = root.get_node("Interactables/SteamValve")
	valve.interact(p)
	var vents := get_tree().get_nodes_in_group("steam_vents")
	_report("valve shuts %d steam vents" % vents.size(), vents.size() > 0 and not vents[0].emitting)
	var crate = root.get_node("Interactables/LooseCrate")
	var c0: Vector3 = crate.global_position
	_place(c0 + Vector3(-2.2, 0.05, 0), -90.0, -15.0)
	await _wait(0.3)
	var ok_hit: bool = p.try_interact()
	await _wait(1.5)
	_report("shove crate (moved %.2f m)" % crate.global_position.distance_to(c0), ok_hit and crate.global_position.distance_to(c0) > 0.4)
	# --- stick + dash
	var sc0 = root.get_node("Creatures/Scuttlers/Scuttler_00")
	sc0.set_physics_process(false)   # (disabling process_mode would pull it out of the physics space)
	var sp: Vector3 = sc0.global_position
	_place(sp + Vector3(0, 0.05, 1.1), 0.0, -25.0)
	await _wait(0.1)
	var swung: bool = await p.attack()      # frozen until hit, otherwise it bolts before the swing lands
	sc0.set_physics_process(true)
	await _wait(0.4)
	_report("stick knocks a scuttler away (moved %.2f m, hit=%s state=%d)" % [sc0.global_position.distance_to(sp), str(swung), sc0.state], swung and sc0.state == 2 and sc0.global_position.distance_to(sp) > 0.8)
	var c1 = root.get_node("Interactables/LooseCrate2")
	var c1p: Vector3 = c1.global_position
	_place(c1p + Vector3(0, 0.05, 1.5), 0.0, -20.0)
	await _wait(0.6)
	var swung2: bool = await p.attack()
	await _wait(1.0)
	_report("stick shoves a crate (moved %.2f m)" % c1.global_position.distance_to(c1p), swung2 and c1.global_position.distance_to(c1p) > 0.3)
	_place(Vector3(31, 0.2, 2.0), -90.0)
	await _wait(0.5)
	var x0: float = p.global_position.x
	p.dash()
	await _wait(0.5)
	_report("dash covers ground (%.2f m)" % (p.global_position.x - x0), p.global_position.x - x0 > 2.0)
	print("[WALK] creatures: ", get_tree().get_nodes_in_group("player").size(), " player; scuttlers=", root.get_node("Creatures/Scuttlers").get_child_count())

# ------------------------------------------------------------------ main.tscn <-> surface.tscn (the mesa)
## Wait (physics frames) until the current scene is called `scene_name`, then re-fetch the player.
func _wait_scene(scene_name: String, secs: float) -> bool:
	for i in int(secs * 60):
		if _scene() and _scene().name == scene_name:
			break
		await get_tree().physics_frame
	await _wait(0.3)
	p = get_tree().get_first_node_in_group("player")
	return _scene() != null and _scene().name == scene_name

## Rail hitboxes: run, jump and dash straight at a railing; the player must still be on the deck, inside the edge.
func _rail(label: String, pos: Vector3, yaw: float, inside: Callable) -> void:
	_place(pos, yaw)
	_release()
	await _wait(0.3)
	Input.action_press("move_forward")
	for k in 3:
		Input.action_press("jump")
		await _wait(0.12)
		p.dash()
		await _wait(0.3)
		Input.action_release("jump")
		await _wait(0.35)
	_release()
	await _wait(0.8)
	var v: Vector3 = p.global_position
	_report("rail holds: " + label, absf(v.y - pos.y) < 1.0 and inside.call(v))

func _run_surface_rails() -> void:
	await _rail("gallery east edge", b(60.5, 18.0, 40.05), -90.0, func(v): return v.x < 62.0)
	await _rail("gallery north edge", b(56.0, 22.0, 40.05), 0.0, func(v): return v.z > -24.0)
	await _rail("stair 1 side", b(46.5, 12.0, 37.2), 0.0, func(v): return v.z > -13.1 and v.y > 35.5)
	await _rail("tower deck Z40 west", b(56.0, -5.0, 40.05), 90.0, func(v): return v.x > 55.0)
	await _rail("top deck west", b(56.0, -9.7, 46.05), 90.0, func(v): return v.x > 55.0)
	await _rail("gantry west", b(58.0, -19.0, 46.05), 90.0, func(v): return v.x > 57.0)
	await _rail("gantry east", b(58.0, -19.0, 46.05), -90.0, func(v): return v.x < 59.0)
	await _rail("block C north (54..57)", b(55.5, -29.0, 46.05), 0.0, func(v): return v.z > 27.0)
	await _rail("block C east", b(65.5, -33.0, 46.05), -90.0, func(v): return v.x < 67.0)
	await _rail("block C south", b(60.0, -36.5, 46.05), 180.0, func(v): return v.z < 38.0)
	await _rail("bridge 1 west", b(65.5, -46.0, 46.05), 90.0, func(v): return v.x > 64.6)
	await _rail("bridge 1 east", b(65.5, -46.0, 46.05), -90.0, func(v): return v.x < 66.4)
	await _rail("pinnacle south", b(70.0, -62.0, 46.05), 180.0, func(v): return v.z < 64.5)
	await _rail("bridge 2 south", b(79.0, -58.0, 46.05), 180.0, func(v): return v.z < 59.0)
	await _rail("bridge 2 north", b(79.0, -58.0, 46.05), 0.0, func(v): return v.z > 57.0)
	await _rail("silo landing south", b(92.0, -57.5, 46.05), 180.0, func(v): return v.z < 60.0)
	await _rail("silo landing west", b(87.5, -53.0, 46.05), 90.0, func(v): return v.x > 86.0)
	await _rail("silo flight A side", b(89.0, -44.0, 49.1), 90.0, func(v): return v.x > 88.0 and v.y > 47.5)
	await _rail("silo flight B side", b(93.0, -37.0, 54.1), 0.0, func(v): return v.z > 36.0 and v.y > 52.5)
	await _rail("silo roof east", b(96.5, -45.0, 56.05), -90.0, func(v): return v.x < 98.0)
	await _rail("silo roof south", b(93.0, -48.5, 56.05), 180.0, func(v): return v.z < 50.0)

func _run_surface_trip() -> void:
	var root := _scene()
	var lift = root.get_node("LiftRig/Lift")
	lift.handoff_scene = "res://scenes/surface.tscn"
	# --- up by lift: the surface takes over inside the shaft, its car carries on to the landing
	lift.send_to(1)
	await _wait_lift(lift)
	_place(Vector3(20.7, 18.05, 3.4), 0.0, 5.0)
	await _wait(0.3)
	root.get_node("LiftRig/Lift/CarUp").interact(p)
	var ok := await _wait_scene("Surface", 20.0)
	_report("lift up hands over to the surface mid-shaft", ok)
	if not ok:
		return
	var car = _scene().get_node("LiftRig/Car")
	await _wait(3.0)
	var d: Vector3 = p.global_position - car.global_position
	_report("surface car carries you up to the landing", not car.moving and absf(car.position.y - 34.3) < 0.02 and absf(d.x) < 1.5 and absf(d.z) < 1.5 and absf(d.y) < 0.3)
	await _walk("surface: step off the car", p.global_position, -90.0, 1.4, func(v): return v.x > 23.0 and absf(v.y - 34.3) < 0.3)
	# --- the route through the works to the lookout, and back
	await _walk("surface: stair 1 up to the gallery", b(41.0, 12.0, 34.35), -90.0, 4.5, func(v): return v.x > 50.0 and absf(v.y - 40.0) < 0.3)
	var look = _scene().get_node("Lookout")
	await _walk("surface: gallery -> tower -> gantry -> block C", b(58.0, 14.0, 40.05), 180.0, 13.0, func(v): return absf(v.y - 46.0) < 0.3 and v.z > 28.0)
	# v6: on past the old lookout - bridge 1, the pinnacle, bridge 2, the silo stair, the roof (the end) - and back
	await _walk("surface: bridge 1 -> pinnacle", b(65.5, -35.0, 46.05), 180.0, 6.5, func(v): return absf(v.y - 46.0) < 0.3 and v.z > 57.0)
	await _walk("surface: bridge 2 -> silo landing", b(66.5, -58.0, 46.05), -90.0, 5.5, func(v): return absf(v.y - 46.0) < 0.3 and v.x > 87.5)
	await _walk("surface: silo flight A up", b(89.0, -51.5, 46.05), 0.0, 4.5, func(v): return absf(v.y - 52.0) < 0.3 and v.z < 37.5)
	await _walk("surface: silo flight B up -> roof", b(89.0, -37.0, 52.05), -90.0, 3.0, func(v): return absf(v.y - 56.0) < 0.3 and v.x > 96.0)
	await _walk("surface: silo roof -> the end", b(97.0, -37.0, 56.05), 180.0, 3.5, func(v): return absf(v.y - 56.0) < 0.3 and look.get("_triggered"))
	await _walk("surface: silo flight B down", b(97.0, -37.0, 56.05), 90.0, 3.0, func(v): return absf(v.y - 52.0) < 0.3 and v.x < 90.0)
	await _walk("surface: silo flight A down", b(89.0, -37.0, 52.05), 180.0, 4.5, func(v): return absf(v.y - 46.0) < 0.3 and v.z > 55.0)
	await _walk("surface: bridge 2 back", b(88.0, -58.0, 46.05), 90.0, 5.0, func(v): return absf(v.y - 46.0) < 0.3 and v.x < 72.0)
	await _walk("surface: bridge 1 back", b(65.5, -57.0, 46.05), 0.0, 6.0, func(v): return absf(v.y - 46.0) < 0.3 and v.z < 38.0)
	await _run_surface_rails()
	await _walk("surface: block C -> gantry -> tower -> gallery", b(58.0, -30.0, 46.05), 0.0, 13.0, func(v): return absf(v.y - 40.0) < 0.3 and v.z < -9.0)
	await _walk("surface: stair 1 down", b(51.5, 12.0, 40.05), 90.0, 4.0, func(v): return v.x < 43.5 and absf(v.y - 34.3) < 0.4)
	# --- off the edge of the mesa: back to the last checkpoint
	var cp: Transform3D = p.spawn_transform
	_place(b(32.0, -100.0, 40.0), 0.0)
	await _wait(3.0)
	_report("surface: off the edge -> back to the checkpoint", p.global_position.distance_to(cp.origin) < 0.6 and p.health >= 99.0)
	# --- v8: stair 3 has caved in - the gate stays shut
	var gate = _scene().get_node("StairGate")
	_place(b(32.8, 3.2, 34.35), -90.0, -5.0)
	await _wait(0.4)
	var hit: bool = p.try_interact()
	await _wait(1.0)
	_report("surface: stair gate stays shut (collapsed)", hit and not gate.is_open)
	# --- v8: the lift collar - walking round the parked car on any side never drops into the shaft
	await _walk("surface: collar south of the car", b(22.2, -5.2, 34.35), 90.0, 2.0, func(v): return v.y > 34.0)
	await _walk("surface: collar west of the car", b(18.85, -5.3, 34.35), 0.0, 2.5, func(v): return v.y > 34.0)
	await _walk("surface: collar north of the car", b(19.0, -1.05, 34.35), -90.0, 2.0, func(v): return v.y > 34.0)
	# --- down by lift: the car sinks into the shaft and the cavern's lift takes over, down to the deck
	car = _scene().get_node("LiftRig/Car")
	_place(car.global_position + Vector3(0.0, 0.05, 0.4), 0.0, 5.0)
	await _wait(0.3)
	_scene().get_node("LiftRig/Car/CarDown").interact(p)
	ok = await _wait_scene("Main", 10.0)
	_report("lift down hands over to the cavern mid-shaft", ok)
	if not ok:
		return
	lift = _scene().get_node("LiftRig/Lift")
	await _wait_lift(lift)
	await _wait(0.4)
	_report("cavern lift carries you down to the deck", lift.is_at(1) and absf(p.global_position.y - 18.0) < 0.35)
