extends SceneTree
## v13 checks: the Sphaeroid fight in the Peak hall (scripts/boss_arena.gd, creatures/sphaeroid.gd).
##   tools\godot.cmd --headless --script res://tools/boss_test.gd -- --noenemies
## Doors, the fight starting, each attack, phase 2, summons, the roll vs. the shield, the gallery heal cap, the reset
## on blacking out, the stun + unpower, the loot, and the husk on a reload. Prints PASS/FAIL per check and a total.

const GameState := preload("res://scripts/game_state.gd")

var fails := 0
var checks := 0
var S := {}

func _initialize() -> void:
	create_timer(240.0).timeout.connect(func():
		print("boss_test: TIMED OUT after %d checks" % checks)
		quit(1))
	_run()

func ok(label: String, cond: bool) -> void:
	checks += 1
	if not cond:
		fails += 1
	print("%s  %s" % ["PASS" if cond else "FAIL", label])

func frames(n: int) -> void:
	for i in n:
		await physics_frame

func secs(t: float) -> void:
	await create_timer(t).timeout

func load_scene(path: String) -> Node:
	var before := current_scene
	change_scene_to_file(path)
	for i in 600:
		await process_frame
		if current_scene and current_scene != before and get_first_node_in_group("player"):
			break
	await frames(8)
	return current_scene

## Stand the player at `at` (floor height y), facing `look`.
func put(p: CharacterBody3D, at: Vector3, look: Vector3) -> void:
	p.global_position = at
	p.velocity = Vector3.ZERO
	var d := look - at
	p.rotation.y = atan2(-d.x, -d.z)
	p.call("reset_fall")
	await frames(2)
	p.call("reset_fall")

func heal_full(p: Node) -> void:
	p.call("_set_health", float(p.get("max_health")))

## Middle of the first gallery quad, standing height.
func gallery_spot(fight: Node) -> Vector3:
	var q: PackedVector2Array = fight.get("gallery_quads")
	var c := (q[0] + q[1] + q[2] + q[3]) * 0.25
	return Vector3(c.x, 44.6, c.y)

func state_of(b: Node) -> int:
	return int(b.get("state"))

func wait_state(b: Node, s: int, limit: float) -> bool:
	var t := 0.0
	while t < limit:
		if not is_instance_valid(b):
			return false
		if state_of(b) == s:
			return true
		await physics_frame
		t += 1.0 / 60.0
	return false

func _run() -> void:
	var surf := await load_scene("res://scenes/surface.tscn")
	var p := get_first_node_in_group("player") as CharacterBody3D
	var fight := surf.get_node_or_null("PeakArena/BossFight")
	ok("surface has PeakArena/BossFight", fight != null)
	if fight == null:
		_finish()
		return
	await frames(4)
	var boss := fight.get("boss") as CharacterBody3D
	ok("a dormant Sphaeroid waits in the hall", boss != null and boss.get("state") == 0)
	S = boss.get_script().get_script_constant_map()["S"]
	var bgate := surf.get_node("PeakArena/BossGate")
	var egate := surf.get_node("PeakArena/ExitGate")
	var hdoor := surf.get_node("PeakArena/HiddenDoor")
	ok("BossGate starts open, ExitGate + HiddenDoor shut", bgate.get("is_open") and not egate.get("is_open") and not hdoor.get("is_open"))
	for n in ["_frame", "_shell", "_star", "_turret", "_cannon", "_muzzle", "_leg", "_skid", "_hatch", "_mouth"]:
		if boss.get(n) == null:
			ok("model part %s found" % n, false)
	ok("boss model parts found", boss.get("_frame") != null and boss.get("_muzzle") != null and boss.get("_mouth") != null)
	var floor_y := float(fight.get("floor_y"))
	var centre := boss.global_position
	var gate := fight.get("gate_point") as Vector3
	var into := Vector3(centre.x - gate.x, 0, centre.z - gate.z).normalized()

	# --- walking in starts it
	await put(p, gate + into * 2.0 + Vector3.UP * 0.1, centre)
	await frames(10)
	ok("standing in the doorway doesn't start it", not fight.get("fighting"))
	await put(p, centre - into * 9.0 + Vector3(0, floor_y - centre.y + 0.1, 0), centre)
	await frames(6)
	ok("walking in starts the fight", fight.get("fighting") and boss.get("state") != 0)
	ok("BossGate drops behind the player", not bgate.get("is_open"))
	var bar := p.get_node_or_null("HUD/BossBar")
	ok("boss bar on the HUD", bar != null and bar.get("shown"))
	ok("death goes to the checkpoint during the fight", p.get("death_to_checkpoint") == true)
	boss.set("hold_ai", true)
	await secs(0.6)

	# --- cannon volley
	heal_full(p)
	var h0 := float(p.get("health"))
	boss.call("_enter", S["CANNON"])
	await secs(0.25)
	var tracked := absf(float((boss.get("_turret") as Node3D).rotation.y)) + absf(float((boss.get("_cannon") as Node3D).rotation.x))
	await secs(1.6)
	var lost := h0 - float(p.get("health"))
	ok("cannon volley hits for 12s (lost %.0f)" % lost, lost >= 11.9 and lost <= 36.1 and fmod(lost + 0.01, 12.0) < 0.1)
	ok("turret/cannon tracked the player", tracked > 0.001 or lost > 0.0)
	await wait_state(boss, S["IDLE"], 2.0)

	# --- v13b: too close for the cannon -> hops back first, then fires
	heal_full(p)
	await put(p, boss.global_position - into * 4.5 + Vector3(0, floor_y - boss.global_position.y + 0.1, 0), boss.global_position)
	var d0 := Vector2(p.global_position.x - boss.global_position.x, p.global_position.z - boss.global_position.z).length()
	boss.call("_enter", S["CANNON"])
	ok("close up, the cannon starts with a hop back", state_of(boss) == S["HOP"])
	await secs(0.3)
	ok("airborne mid-hop", boss.global_position.y > floor_y + 0.5)
	var landed := await wait_state(boss, S["CANNON"], 1.5)
	var d1 := Vector2(p.global_position.x - boss.global_position.x, p.global_position.z - boss.global_position.z).length()
	ok("hop opened the distance (%.1f -> %.1f m)" % [d0, d1], landed and d1 > d0 + 2.5)
	h0 = float(p.get("health"))
	await secs(2.0)
	ok("then fires the volley (lost %.0f)" % (h0 - float(p.get("health"))), h0 - float(p.get("health")) >= 11.9)
	await wait_state(boss, S["IDLE"], 2.0)

	# --- v13b: its body blocks the player (drum + crown + pylon/skid boxes)
	var bp := boss.global_position
	var blocked := true
	for k in 4:
		var dir := into.rotated(Vector3.UP, k * PI * 0.5)
		bp = boss.global_position
		await put(p, bp - dir * 7.0 + Vector3(0, floor_y - bp.y + 0.1, 0), bp)
		var closest := 99.0
		for i in 90:
			var to := boss.global_position - p.global_position
			to.y = 0.0
			p.velocity.x = to.normalized().x * 5.0
			p.velocity.z = to.normalized().z * 5.0
			p.move_and_slide()
			await physics_frame
			closest = minf(closest, Vector2(p.global_position.x - boss.global_position.x, p.global_position.z - boss.global_position.z).length())
		if closest < 1.9:
			blocked = false
			print("   walked in to %.2f m from side %d" % [closest, k])
	ok("can't walk through it from any side", blocked)

	# --- v13b: it circles while sizing the player up
	bp = boss.global_position
	await put(p, bp - into * 8.0 + Vector3(0, floor_y - bp.y + 0.1, 0), bp)
	boss.call("_enter", S["IDLE"])
	boss.set("_idle_t", 99.0)
	var path := 0.0
	var last := boss.global_position
	for i in 90:
		await physics_frame
		path += last.distance_to(boss.global_position)
		last = boss.global_position
	ok("strafes in IDLE (moved %.1f m in 1.5 s)" % path, path > 1.5)
	boss.set("_idle_t", 0.5)

	# --- jump
	heal_full(p)
	await put(p, centre - into * 9.0 + Vector3(0, floor_y - centre.y + 0.1, 0), centre)
	h0 = float(p.get("health"))
	var b0 := boss.global_position
	boss.call("_enter", S["JUMP_WIND"])
	await secs(0.2)
	ok("jump wind-up crouches", float(boss.get("_squash")) > 0.2)
	await wait_state(boss, S["JUMP_AIR"], 1.0)
	await secs(0.45)
	ok("it leaps (airborne at mid-arc)", boss.global_position.y > floor_y + 2.0)
	await wait_state(boss, S["IDLE"], 1.5)
	lost = h0 - float(p.get("health"))
	ok("landing shockwave hits for 30 (lost %.0f)" % lost, absf(lost - 30.0) < 0.5)
	ok("it landed near the player", Vector2(boss.global_position.x - p.global_position.x, boss.global_position.z - p.global_position.z).length() < 6.0 \
		and boss.global_position.distance_to(b0) > 3.0)
	ok("landing spot is inside the hall", fight.call("landing_ok", boss.global_position, 2.5))
	await secs(0.5)

	# --- phase 2
	boss.set("health", 775.0)
	boss.call("take_hit", p, -p.global_basis.z)
	ok("half health -> phase 2", int(boss.get("phase")) == 2 and state_of(boss) == S["PHASE"])
	ok("phase 2 leaks sparks + smoke", (boss.get("_wounds") as Array).size() >= 4)
	ok("bar follows its health", absf(float(bar.get("_frac")) - 745.0 / 1500.0) < 0.01)
	await wait_state(boss, S["IDLE"], 2.5)

	# --- summon
	boss.call("_enter", S["SUMMON"])
	await secs(2.0)
	var alive := int(boss.call("skates_alive"))
	ok("summon launches 1-2 skates (%d)" % alive, alive >= 1 and alive <= 2)
	boss.call("_enter", S["SUMMON"])
	await secs(2.0)
	ok("never more than 2 skates (%d)" % int(boss.call("skates_alive")), int(boss.call("skates_alive")) <= 2)
	boss.call("clear_minions", false)
	await frames(2)

	# --- roll, no shield
	heal_full(p)
	p.set("has_drone", false)
	p.set("shield", 0.0)
	await put(p, centre - into * 9.0 + Vector3(0, floor_y - centre.y + 0.1, 0), centre)
	boss.global_position = Vector3(centre.x, floor_y, centre.z) + into * 3.0
	h0 = float(p.get("health"))
	boss.call("_enter", S["ROLL_WIND"])
	await secs(0.4)
	ok("roll wind-up folds the legs", float(boss.get("_fold")) > 0.4)
	var stunned := await wait_state(boss, S["ROLL_STUN"], 6.0)
	lost = h0 - float(p.get("health"))
	ok("the roll stops on the player (stunned)", stunned)
	ok("roll hit, shield down: 70 damage (lost %.0f)" % lost, absf(lost - 70.0) < 0.5)
	var t0 := Time.get_ticks_msec()
	await wait_state(boss, S["IDLE"], 3.5)
	var stun := (Time.get_ticks_msec() - t0) / 1000.0
	ok("stunned ~2 s after the roll (%.2f)" % stun, stun > 1.6 and stun < 2.6)

	# --- roll into a raised shield
	heal_full(p)
	p.set("has_drone", true)
	p.set("shield", 15.0)
	await put(p, centre - into * 9.0 + Vector3(0, floor_y - centre.y + 0.1, 0), centre)
	boss.global_position = Vector3(centre.x, floor_y, centre.z) + into * 3.0
	h0 = float(p.get("health"))
	boss.call("_enter", S["ROLL_WIND"])
	await wait_state(boss, S["ROLL_STUN"], 6.0)
	ok("a raised shield takes the roll (health %.0f -> %.0f, shield %.0f)" % [h0, float(p.get("health")), float(p.get("shield"))],
		absf(float(p.get("health")) - h0) < 0.5 and float(p.get("shield")) < 0.5)
	p.set("has_drone", false)
	p.set("shield", 0.0)
	await wait_state(boss, S["IDLE"], 3.5)

	# --- roll with the player out of the way (up on the gallery): two walls and it stops
	await put(p, gallery_spot(fight), centre)
	boss.global_position = Vector3(centre.x, floor_y, centre.z)
	boss.call("_enter", S["ROLL"])
	boss.set("_roll_dir", into.rotated(Vector3.UP, 1.3))
	boss.set("roll_turn", 0.0)
	await wait_state(boss, S["ROLL_STUN"], 7.5)
	ok("roll stops after two walls (%d)" % int(boss.get("_walls")), int(boss.get("_walls")) >= 2)
	boss.set("roll_turn", 0.9)
	await wait_state(boss, S["IDLE"], 3.5)

	# --- gallery heal: capped at three swings per retreat, then it shells the gallery
	boss.set("health", 1000.0)
	boss.set("_heal_budget", 90.0)
	boss.set("hold_ai", false)
	await put(p, gallery_spot(fight), centre)
	await frames(30)
	ok("player on the gallery counts as 'upper'", fight.call("player_upper", p, boss))
	var healed := await wait_state(boss, S["HEAL"], 4.0)
	ok("it heals while the player regens up top", healed)
	await secs(4.5)
	ok("heal capped at 3 swings (health %.0f)" % float(boss.get("health")), absf(float(boss.get("health")) - 1090.0) < 0.6)
	var shells := false
	for i in 120:
		if state_of(boss) == S["CANNON"]:
			shells = true
			break
		await physics_frame
	ok("then it shells the gallery", shells)
	await put(p, centre - into * 9.0 + Vector3(0, floor_y - centre.y + 0.1, 0), centre)
	boss.set("hold_ai", true)
	await wait_state(boss, S["IDLE"], 3.0)
	boss.call("take_hit", p, -p.global_basis.z)
	ok("a hit from the floor refills the heal cap", absf(float(boss.get("_heal_budget")) - 90.0) < 0.01)

	# --- blacking out resets the fight
	var cp := surf.get_node_or_null("Safety/CP_HallEntrance") as Node3D
	p.set("spawn_transform", Transform3D(Basis(Vector3.UP, cp.global_rotation.y), cp.global_position))
	p.call("take_damage", 500.0)
	await secs(1.6)
	ok("blacked out: back at the hall entrance, not the lift", p.global_position.distance_to(cp.global_position) < 2.0)
	var boss2 := fight.get("boss") as CharacterBody3D
	ok("fight reset: a fresh dormant boss at full health", not fight.get("fighting") and boss2 != boss and is_instance_valid(boss2) \
		and boss2.get("state") == 0 and float(boss2.get("health")) == float(boss2.get("max_health")))
	await frames(80)
	ok("gate lifts again after the reset", bgate.get("is_open"))
	ok("death goes to the lift again outside the fight", p.get("death_to_checkpoint") == false)
	boss = boss2

	# --- down under 2%, then unpower
	await put(p, centre - into * 9.0 + Vector3(0, floor_y - centre.y + 0.1, 0), centre)
	await frames(6)
	ok("fight starts again", fight.get("fighting"))
	boss.set("hold_ai", true)
	boss.set("health", 75.0)
	boss.set("phase", 2)
	boss.call("take_hit", p, -p.global_basis.z)
	ok("one swing above 2%: still fighting", state_of(boss) != S["DOWN"] and float(boss.get("health")) > 30.0)
	boss.call("take_hit", p, -p.global_basis.z)
	ok("under 2%: it seizes up (DOWN), not dead", state_of(boss) == S["DOWN"] and float(boss.get("health")) > 0.0 and is_instance_valid(boss))
	var hdown := float(boss.get("health"))
	boss.call("take_hit", p, -p.global_basis.z)
	ok("no more damage while down", float(boss.get("health")) == hdown)
	ok("bar shows it down", bar.get("down"))
	await secs(1.0)
	var tok0 := int(p.call("item_count", "tokens"))
	# face it from 2.4 m and use the ray
	var to_b := Vector3(boss.global_position.x - p.global_position.x, 0, boss.global_position.z - p.global_position.z).normalized()
	await put(p, Vector3(boss.global_position.x, floor_y + 0.1, boss.global_position.z) - to_b * 2.5, boss.global_position + Vector3.UP * 2.2)
	(p.get_node("Head") as Node3D).rotation.x = 0.35
	await frames(3)
	var hit: Node = p.call("_get_interactable")
	ok("the ray finds its Unpower area", hit != null and hit.name == "Unpower")
	if hit:
		ok("prompt names it", str(hit.call("get_prompt")).contains("Sphaeroid"))
		hit.call("interact", p)
	await secs(0.2)
	ok("unpowered (OFF)", state_of(boss) == S["OFF"])
	ok("GameState peak_boss_down set", GameState.get_value("peak_boss_down", false))
	await secs(3.5)
	ok("ExitGate + HiddenDoor open, BossGate open", egate.get("is_open") and hdoor.get("is_open") and bgate.get("is_open"))
	ok("loot paid out (+%d tokens)" % (int(p.call("item_count", "tokens")) - tok0), int(p.call("item_count", "tokens")) - tok0 == 150 \
		and int(p.call("item_count", "bars")) >= 4)
	ok("bar hidden", not bar.get("shown"))
	var hpos := boss.global_position

	# --- later visit: the husk
	surf = await load_scene("res://scenes/surface.tscn")
	p = get_first_node_in_group("player") as CharacterBody3D
	fight = surf.get_node("PeakArena/BossFight")
	await frames(4)
	var husk := fight.get("boss") as Node3D
	ok("reload: the husk lies where it fell", husk != null and husk.get("husk") and husk.global_position.distance_to(hpos) < 0.5)
	ok("reload: all three doors start open", surf.get_node("PeakArena/BossGate").get("is_open") and surf.get_node("PeakArena/ExitGate").get("is_open") \
		and surf.get_node("PeakArena/HiddenDoor").get("is_open"))
	await put(p, centre - into * 9.0 + Vector3(0, floor_y - centre.y + 0.1, 0), centre)
	await frames(10)
	ok("reload: walking in starts nothing", not fight.get("fighting"))
	_finish()

func _finish() -> void:
	print("boss_test: %d checks, %d fails" % [checks, fails])
	quit(1 if fails > 0 else 0)
