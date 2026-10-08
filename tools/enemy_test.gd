extends Node
## Automated test of the surface hostiles (tripod + skate), the spawner and the player's health/respawn.
##   tools\godot.cmd --headless res://scenes/surface.tscn -- --enemytest
## Added to the root by shot_tour.gd. The spawner's own timer is off under --enemytest; this drives it directly.

const Tripod := preload("res://scripts/creatures/tripod.gd")
const Skate := preload("res://scripts/creatures/skate.gd")

var p
var sp
var fails := 0
var checks := 0

func _ready() -> void:
	_run.call_deferred()

func _wait(sec: float) -> void:
	for i in int(sec * Engine.physics_ticks_per_second):
		await get_tree().physics_frame

func _report(label: String, ok: bool, extra := "") -> void:
	checks += 1
	if not ok:
		fails += 1
	print("[ENEMY] %s %s %s" % ["PASS" if ok else "FAIL", label, extra])

func _place(pos: Vector3, yaw: float) -> void:
	p.global_position = pos
	p.rotation = Vector3(0, deg_to_rad(yaw), 0)
	p.get_node("Head").rotation = Vector3.ZERO
	p.velocity = Vector3.ZERO
	p.reset_fall()

func _heal() -> void:
	p._set_health(p.max_health)

func _clear() -> void:
	for e in sp.get_children():
		e.free()

## Wait until the player's health drops (or `secs` pass). Returns the drop.
func _wait_hurt(secs: float) -> float:
	var h0: float = p.health
	for i in int(secs * 60):
		await get_tree().physics_frame
		if p.health < h0 - 0.01:
			return h0 - p.health
	return 0.0

## Swing until `e` dies; returns the number of swings that landed (-1 if a swing missed).
func _swings_to_kill(e: Node, limit := 8) -> int:
	var n := 0
	while is_instance_valid(e) and not e.dead and n < limit:
		var hit: bool = await p.attack()
		if not hit:
			return -1
		n += 1
		await _wait(p.combo_cooldown + 0.05)      # (the 2nd, 4th.. swing is the combo backhand)
	return n

func _run() -> void:
	await get_tree().process_frame
	p = get_tree().get_first_node_in_group("player")
	sp = get_tree().current_scene.get_node("Enemies")
	p.give_weapon(true)
	p.max_safe_fall = 0.0
	await _wait(0.5)
	var lift: Node3D = get_tree().current_scene.get_node("Spawns/FromLift")
	_report("lift landing is a respawn point", lift.is_in_group("respawn_point"))
	_report("spawner idle under the test", not sp.enabled)

	# ---------------------------------------------------------------- spawner: valid spots, never near the lift
	_place(Vector3(56, 40.05, -16), 0.0)      # the gallery
	await _wait(0.3)
	var ok_spots := 0
	var tried := 0
	var bad := []
	for kind in [0, 1]:
		for i in 6:
			tried += 1
			var e: Node3D = sp.try_spawn(kind)
			if e == null:
				bad.append("none")
				continue
			var d_lift := e.global_position.distance_to(lift.global_position)
			var flat := Vector2(e.global_position.x - p.global_position.x, e.global_position.z - p.global_position.z).length()
			if d_lift >= sp.safe_radius and e.global_position.y >= sp.min_ground_y and flat >= 21.9 and flat <= 48.1:
				ok_spots += 1
			else:
				bad.append(str(e.global_position.snapped(Vector3.ONE * 0.1)))
	_report("spawner finds valid spots (%d/%d)" % [ok_spots, tried], ok_spots == tried, str(bad))
	_report("spawn caps: 2 tripods + 2 skates by the timer", sp.max_tripods == 2 and sp.max_skates == 2)
	await _wait(1.0)
	var settled := 0
	for e in sp.get_children():
		if e.get_script() == Tripod and e.is_on_floor():
			settled += 1
	_report("spawned tripods stand on the ground", settled == 6, "(%d/6)" % settled)
	_clear()

	# ---------------------------------------------------------------- tripod: bolt, dodge, stomp, four swings
	_heal()
	_place(Vector3(8, 34.35, -6), 0.0)
	var t: CharacterBody3D = sp._spawn(0, Vector3(8, 34.3, 4))
	var dmg := await _wait_hurt(10.0)
	_report("tripod spots you and lands a bolt (-15)", absf(dmg - 15.0) < 0.01, "dmg=%.1f" % dmg)
	_report("hit shakes the screen", p._trauma > 0.0)
	# dodge: wait for the lock, then dash sideways
	_heal()
	await _wait(0.6)
	var dodged := false
	for i in 8 * 60:
		await get_tree().physics_frame
		if t.state == Tripod.S.CHARGE and t._t < 0.22:
			Input.action_press("move_right")
			p.dash()
			await _wait(0.3)
			Input.action_release("move_right")
			dodged = await _wait_hurt(1.5) == 0.0
			break
	_report("a late dash dodges the bolt", dodged)
	# stomp
	_heal()
	t._cd_bolt = 99.0
	_place(t.global_position + Vector3(0, 0.05, -2.3), 0.0)
	dmg = await _wait_hurt(5.0)
	_report("tripod stomps you when close (-15)", absf(dmg - 15.0) < 0.01, "dmg=%.1f" % dmg)
	# four swings (frozen so the fight is repeatable)
	_heal()
	await _wait(0.5)
	t.set_physics_process(false)
	_place(t.global_position + Vector3(0, 0.05, -2.0), 180.0)
	await _wait(0.2)
	var hit1: bool = await p.attack()
	await get_tree().process_frame
	await get_tree().process_frame
	_report("health bar shows once hit", hit1 and t._bar.visible and t.health < t.max_health)
	await _wait(p.combo_cooldown + 0.05)      # (the 2nd, 4th.. swing is the combo backhand)
	var n := 1 + await _swings_to_kill(t)
	_report("tripod dies to 4 swings", n == 4, "swings=%d" % n)
	await get_tree().process_frame
	var scene := get_tree().current_scene
	var debris := get_tree().get_nodes_in_group("debris").size()
	_report("death burst: particles + flung debris", scene.find_child("DeathFx", false, false) != null and debris >= 4, "debris=%d" % debris)

	# ---------------------------------------------------------------- skate: dive, three swings
	_heal()
	_place(Vector3(8, 34.35, -4), 0.0)
	var s: CharacterBody3D = sp._spawn(1, Vector3(8, 38.5, 5))
	dmg = 0.0
	var face_min := 1.0
	var dive_frames := 0
	var phase := 0           # frames since this wind-up began
	var measured := 0
	for i in 14 * 60:
		await get_tree().physics_frame
		if s.state == Skate.S.WINDUP or s.state == Skate.S.DIVE:
			phase += 1
			var to_p: Vector3 = (p.global_position + Vector3.UP * 1.1 - s.global_position).normalized()
			var ahead: bool = s.state == Skate.S.WINDUP or to_p.dot(s._dive_dir) > 0.3
			var far := s.global_position.distance_to(p.global_position + Vector3.UP * 1.1) > 1.2
			if phase > 15 and ahead and far:      # settled after the snap-turn, the player still ahead (and not on top of it)
				measured += 1
				face_min = minf(face_min, (-s._model.global_basis.z).dot(to_p))
		else:
			phase = 0
		dive_frames = measured
		if p.health < 99.99:
			dmg = 100.0 - p.health
			break
	_report("skate circles, dives and hits (-15)", absf(dmg - 15.0) < 0.01, "dmg=%.1f state=%d" % [dmg, s.state])
	_report("skate faces you through the wind-up and dive", dive_frames > 12 and face_min > 0.9, "min dot=%.2f" % face_min)
	_heal()
	s.set_physics_process(false)
	_place(Vector3(8, 34.35, -4), 180.0)
	s.global_position = p.global_position + Vector3(0, 1.2, 1.7)
	s.velocity = Vector3.ZERO
	await _wait(0.2)
	n = await _swings_to_kill(s)
	_report("skate dies to 3 swings", n == 3, "swings=%d" % n)
	await _wait(0.5)

	# ---------------------------------------------------------------- player: 6 hits survived, the 7th -> the lift
	_heal()
	_place(Vector3(8, 34.35, -6), 0.0)
	var near: Node3D = sp._spawn(0, Vector3(24, 34.3, -5))
	var far: Node3D = sp._spawn(1, Vector3(60, 50, 25))
	await _wait(0.3)
	for i in 6:
		p.take_damage(15.0, "", Vector3.ZERO)
		await _wait(0.3)
	_report("player survives 6 hits", p.is_alive() and absf(p.health - 10.0) < 0.01, "hp=%.1f" % p.health)
	p.take_damage(15.0, "", Vector3.ZERO)
	await _wait(1.5)
	var at_lift: bool = p.global_position.distance_to(lift.global_position) < 0.6
	_report("7th hit: black out, back at the lift, full health", at_lift and p.health >= 99.9 and p.is_alive(), str(p.global_position.snapped(Vector3.ONE * 0.1)))
	_report("lift becomes the checkpoint", p.spawn_transform.origin.distance_to(lift.global_position) < 0.1)
	_report("enemies near the lift are cleared; far ones stay", not is_instance_valid(near) and is_instance_valid(far))
	_clear()

	# ---------------------------------------------------------------- free play: the spawner's own timer, 60 s on block C (the lookout)
	_heal()
	_place(Vector3(58, 46.05, 30), 0.0)      # CP_Lookout
	sp.first_delay = 1.0
	sp.interval = Vector2(2.0, 4.0)
	sp._timer = 1.0
	sp.enabled = true
	var seen := {}
	var engaged := {}
	var fell := 0
	var hurt := 0.0
	var lowest := 999.0
	for e0 in sp.get_children():
		e0.free()
	for i in 60 * 60:
		await get_tree().physics_frame
		if p.health < 99.0:
			hurt += 100.0 - p.health
			_heal()
		if not p.is_alive():
			continue
		for e in sp.get_children():
			if e.dead:
				continue
			seen[e] = e.get_script()
			if e.state != 0:
				engaged[e] = true
			lowest = minf(lowest, e.global_position.y)
			if e.global_position.y < 30.0 and not e.is_queued_for_deletion():
				fell += 1
				print("   fell: ", e.name, " state=", e.state, " at ", e.global_position.snapped(Vector3.ONE * 0.1), " home ", e.home.snapped(Vector3.ONE * 0.1))
				e.queue_free()
	sp.enabled = false
	var nt := seen.values().filter(func(s): return s == Tripod).size()
	var ns := seen.values().filter(func(s): return s == Skate).size()
	_report("free play: both kinds turn up", nt >= 1 and ns >= 1, "tripods=%d skates=%d" % [nt, ns])
	_report("free play: they find and attack you", engaged.size() >= 2 and hurt > 0.0, "engaged=%d damage taken=%.0f" % [engaged.size(), hurt])
	_report("free play: nobody falls off the mesa", fell == 0, "lowest y=%.1f" % lowest)
	_clear()

	print("[ENEMY] DONE checks=%d fails=%d" % [checks, fails])
	get_tree().quit()
