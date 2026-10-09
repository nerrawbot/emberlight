extends SceneTree
## v19 checks: the mast's signal climb (scripts/mast_signal.gd). Gated route pieces start closed (not standable where
## the route needs them), tune(stage) opens them (standable again), tuned stages start open after a reload, and
## SENTINEL-11 stands on band 1 and talks.
##   tools\godot.cmd --headless --script res://tools/mast_test.gd
## Prints PASS/FAIL per check and a total.

const GameState := preload("res://scripts/game_state.gd")
const KEYS := ["mast_power", "mast_freq", "mast_bearing", "mast_gain", "mast_final"]

var fails := 0
var summit_done := false
var checks := 0

func _initialize() -> void:
	create_timer(300.0).timeout.connect(func():
		print("mast_test: TIMED OUT after %d checks" % checks)
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

func load_scene(path: String) -> Node:
	var before := current_scene
	change_scene_to_file(path)
	for i in 600:
		await process_frame
		if current_scene and current_scene != before and get_first_node_in_group("player"):
			break
	await frames(6)
	return current_scene

## Is the part standable where the route needs it? A ray down through the middle of its open (walkable) pose must hit
## the part's own collision near that height.
func standable(sig: Node, stage: int) -> Array:
	var res := []
	var space := (current_scene as Node3D).get_world_3d().direct_space_state if current_scene is Node3D else null
	for p: Dictionary in sig.get("_parts").get(stage, []):
		var n: Node3D = p["node"]
		var mi := n as MeshInstance3D
		var c: Vector3 = (p["open"] as Transform3D) * (mi.get_aabb().get_center() if mi else Vector3.ZERO)
		var q := PhysicsRayQueryParameters3D.create(c + Vector3.UP * 8.0, c + Vector3.DOWN * 3.0, 0xFFFFFFFF)
		var hit := space.intersect_ray(q) if space else {}
		var mine: bool = not hit.is_empty() and n.is_ancestor_of(hit["collider"]) and absf(hit["position"].y - c.y) < 1.5
		res.append(mine)
	return res

func _run() -> void:
	GameState.merge({"has_weapon": true, "peak_boss_down": true, "station_gate_open": true, "has_pennon": false})
	for k in KEYS:
		GameState.set_value(k, false)
	GameState.set_value("debug_goto", "CP_Band1")
	var sc := await load_scene("res://scenes/surface.tscn")
	var sig := sc.find_child("MastSignal", false, false)
	ok("MastSignal in surface.tscn", sig != null)
	if sig == null:
		_done()
		return
	var parts: Dictionary = sig.get("_parts")
	for st in [1, 2, 3, 4]:
		ok("stage %d has gate parts (%d)" % [st, parts.get(st, []).size()], parts.get(st, []).size() > 0)
	await frames(4)
	for st in [1, 2, 3, 4]:
		var s := standable(sig, st)
		ok("stage %d closed: not standable %s" % [st, str(s)], not s.has(true))

	# SENTINEL-11 on band 1, and it talks (the Pennon hint when there's no Pennon)
	var sen := sig.get("sentinel") as Node3D
	ok("SENTINEL-11 built", sen != null)
	var p := get_first_node_in_group("player") as Node3D
	if sen and p:
		ok("SENTINEL-11 is on band 1 (%.1f m from CP_Band1)" % sen.global_position.distance_to(p.global_position),
			sen.global_position.distance_to(p.global_position) < 20.0)
		var talk := sen.get_node("Talk")
		talk.call("interact", p)
		await frames(3)
		var box: Node = p.get("_dialogue")
		ok("talking to SENTINEL-11 opens the dialogue", box != null and bool(box.get("active")))
		ok("met_watcher_11 set", bool(GameState.get_value("met_watcher_11", false)))
		if box:
			box.call("stop")         # walk away from the talk
		await create_timer(0.3).timeout

	# band 1 (POWER): carry the couplers to the right sockets, then throw the breaker
	var b1 := sig.get_node_or_null("Band1Power")
	ok("band 1 puzzle built", b1 != null and b1.get("plugs").size() == 3)
	if b1 and p:
		var plugs: Dictionary = b1.get("plugs")
		var socks: Array = b1.get("sockets")
		var lever: Node3D = b1.get("lever")
		var use := func(n: Node) -> void:
			n.get_node("Use").call("interact", p)
			await create_timer(0.9).timeout
		await use.call(socks[0])
		ok("empty socket: nothing seats", (b1.get("seated") as Dictionary).is_empty())
		await use.call(plugs["red"])
		ok("took the red coupler", b1.get("carrying") == "red" and not (plugs["red"] as Node3D).visible)
		await use.call(plugs["teal"])
		ok("taking teal swaps it for red", b1.get("carrying") == "teal" and (plugs["red"] as Node3D).visible)
		await use.call(socks[0])
		ok("teal in the circle socket is spat out", (b1.get("seated") as Dictionary).is_empty() and b1.get("carrying") == ""
			and (plugs["teal"] as Node3D).visible)
		var lv0 := lever.transform
		await use.call(lever)
		ok("breaker won't latch with no couplers", not sig.call("is_tuned", 1) and lever.transform.is_equal_approx(lv0))
		for c in ["red", "amber", "teal"]:
			await use.call(plugs[c])
			await use.call(socks[{"red": 2, "amber": 0, "teal": 1}[c]])
		ok("all three couplers seated", (b1.get("seated") as Dictionary).size() == 3)
		await use.call(lever)
		ok("breaker latches: band 1 tuned", sig.call("is_tuned", 1))
		await create_timer(5.0).timeout
		ok("stage 1 open after the breaker %s" % str(standable(sig, 1)), not standable(sig, 1).has(false))

	# band 2 (FREQUENCY): wrong channels are rejected, the call sign's step tunes it
	var b2 := sig.get_node_or_null("Band2Freq")
	ok("band 2 puzzle built", b2 != null and b2.get("_knob") != null)
	if b2 and p:
		var knob: Node3D = b2.get("_knob")
		var key: Node3D = b2.get("_key")
		knob.get_node("Use").call("interact", p)
		await create_timer(0.4).timeout
		ok("the dial turns a step", int(b2.get("dial")) == 1)
		key.get_node("Use").call("interact", p)
		await create_timer(0.5).timeout
		ok("a wrong channel is rejected", not sig.call("is_tuned", 2) and float(b2.get("_stutter")) > 0.0)
		while int(b2.get("dial")) != int(b2.get("TARGET")):
			knob.get_node("Use").call("interact", p)
			await create_timer(0.3).timeout
		key.get_node("Use").call("interact", p)
		await create_timer(0.5).timeout
		ok("the call sign's channel tunes band 2", sig.call("is_tuned", 2))
		var on := 0
		var same := 0
		for i in 40:      # the station lamp now blinks in step with the beacon
			await create_timer(0.11).timeout
			var a := (b2.get("_beacon_light") as OmniLight3D).light_energy > 0.0
			var bb := (b2.get("_lamp_light") as OmniLight3D).light_energy > 0.0
			on += int(a)
			same += int(a == bb)
		ok("the beacon blinks (%d/40 lit) and the lamp keeps step (%d/40)" % [on, same], on > 5 and on < 35 and same >= 38)
		await create_timer(5.5).timeout
		ok("stage 2 open after sending %s" % str(standable(sig, 2)), not standable(sig, 2).has(false))

	# band 3 (BEARING): through the sight, a wrong bearing locks nothing; Ember's does
	var b3 := sig.get_node_or_null("Band3Bearing")
	ok("band 3 puzzle built", b3 != null and b3.get("_tilt") != null)
	if b3 and p:
		var eye: Node3D = b3.get("_eye")
		eye.get_node("Use").call("interact", p)
		await frames(3)
		ok("the sight takes over the view", bool(b3.get("scoped")) and p.get_viewport().get_camera_3d() == b3.get("_cam")
			and not bool(p.get("input_enabled")))
		b3.call("_turn", deg_to_rad(60.0), deg_to_rad(10.0))
		b3.call("_lock")
		ok("a wrong bearing locks nothing (%.1f° off)" % rad_to_deg(float(b3.call("off_angle"))), not sig.call("is_tuned", 3))
		# sweep the dish like a player would, coarse then fine, for the least angle to Ember
		var best := [1e9, 0.0, 0.0]
		for step: float in [2.0, 0.25, 0.05]:
			var y0: float = best[1] if best[0] < 1e9 else 0.0
			var p0: float = best[2] if best[0] < 1e9 else 0.0
			var span := 120.0 if step == 2.0 else step * 16.0
			var pspan := 30.0 if step == 2.0 else step * 16.0
			var yy := -span
			while yy <= span:
				var pp := -pspan
				while pp <= pspan:
					b3.set("yaw", 0.0)
					b3.set("pitch", 0.0)
					b3.call("_turn", y0 + deg_to_rad(yy), p0 + deg_to_rad(pp))
					var a := float(b3.call("off_angle"))
					if a < best[0]:
						best = [a, float(b3.get("yaw")), float(b3.get("pitch"))]
					pp += step
				yy += step
		b3.set("yaw", 0.0)
		b3.set("pitch", 0.0)
		b3.call("_turn", best[1], best[2])
		ok("Ember can be sighted (best %.2f°, bearing found at yaw %.1f° pitch %.1f°)" % [rad_to_deg(best[0]), rad_to_deg(best[1]), rad_to_deg(best[2])],
			best[0] < deg_to_rad(1.0))
		await frames(40)
		ok("the signal bar rises on Ember (%.2f)" % float(b3.get("_signal")), float(b3.get("_signal")) > 0.6)
		b3.call("_lock")
		ok("locking on Ember tunes band 3", sig.call("is_tuned", 3))
		await create_timer(2.2).timeout
		ok("the sight hands the view back", not bool(b3.get("scoped")) and p.get_viewport().get_camera_3d() != b3.get("_cam")
			and bool(p.get("input_enabled")))
		await create_timer(4.0).timeout
		ok("stage 3 open after the lock %s" % str(standable(sig, 3)), not standable(sig, 3).has(false))

	# band 4 (GAIN): the valves are linked; a pinned needle jams a wheel; the lever only latches in the green
	var b4 := sig.get_node_or_null("Band4Gain")
	ok("band 4 puzzle built", b4 != null and (b4.get("_wheels") as Dictionary).size() == 3)
	if b4 and p:
		var wheels: Dictionary = b4.get("_wheels")
		var use4 := func(n: Node3D, child: String) -> void:
			n.get_node(child).call("interact", p)
			await create_timer(0.75).timeout
		ok("needles start out of the green %s" % str(b4.get("needles_val")), not b4.call("in_green"))
		await use4.call(wheels["red"], "UseCW")          # would push needle 2 below 0
		ok("a needle at its stop jams the valve %s" % str(b4.get("needles_val")), b4.get("needles_val") == [7, 0, 1])
		await use4.call(wheels["amber"], "UseCW")
		ok("the amber valve moves needles 2 and 3 %s" % str(b4.get("needles_val")), b4.get("needles_val") == [7, 1, 2])
		var lever4: Node3D = b4.get("_lever")
		await use4.call(lever4, "Use")
		await create_timer(0.6).timeout
		ok("the lever won't latch out of the green", not sig.call("is_tuned", 4))
		for step in [["red", "UseCCW"], ["red", "UseCCW"], ["amber", "UseCW"], ["teal", "UseCCW"]]:
			await use4.call(wheels[step[0]], step[1])
		ok("all three needles in the green %s" % str(b4.get("needles_val")), b4.call("in_green"))
		var mn: Array = (b4.get("_needles") as Dictionary)["master"]
		var up := true
		for n: Node3D in mn:
			up = up and n.transform.is_equal_approx(b4.call("_needle_xf", n, 4.0))
		ok("the master board's needles point at the green", up)
		await use4.call(lever4, "Use")
		await create_timer(0.3).timeout
		ok("the gain lever latches: band 4 tuned", sig.call("is_tuned", 4))
		await create_timer(4.5).timeout
		ok("stage 4 open after the lever %s" % str(standable(sig, 4)), not standable(sig, 4).has(false))

	# the cabin: the console's final tuning (bands 1-4 are tuned by now)
	var cc := sig.get_node_or_null("CabinConsole")
	ok("cabin console built", cc != null and cc.get("_screen_mat") != null)
	if cc and p:
		ok("the console has power once all four bands are tuned", bool(cc.call("_powered")))
		cc.call("enter", p)
		await frames(3)
		ok("the console panel opens (player frozen, mouse free)", bool(cc.get("open")) and not bool(p.get("input_enabled"))
			and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE)
		var q0 := float(cc.get("quality"))
		ok("the traces start apart (agreement %.2f)" % q0, q0 < 0.2)
		var txt := String((cc.get("_text") as Label).text)
		ok("the broadcast starts scrambled", txt != String(cc.get("CARRIER")))
		var em: Dictionary = cc.get("EMBER")
		cc.call("set_knob", "freq", float(em["freq"]) + 0.3)
		cc.call("set_knob", "phase", float(em["phase"]))
		cc.call("set_knob", "amp", float(em["amp"]))
		await create_timer(1.6).timeout
		ok("near isn't enough: no lock off-frequency", not sig.call("is_final"))
		ok("but the panel says it's close (agreement %.2f)" % float(cc.get("agreement")), float(cc.get("agreement")) > 0.8)
		cc.call("set_knob", "freq", float(em["freq"]) + 0.02)
		await create_timer(1.6).timeout
		ok("traces agree: the relay locks on Ember", sig.call("is_final") and bool(GameState.get_value("mast_final", false)))
		await create_timer(3.0).timeout
		var box: Node = p.get("_dialogue")
		ok("the lamplighter speaks", box != null and bool(box.get("active"))
			and String((box.get("_speaker") as Label).text).begins_with("EMBERLIGHT"))
		ok("the panel has closed", not bool(cc.get("open")))
		var guard := 0
		while box and bool(box.get("active")) and guard < 40:
			guard += 1
			box.call("_advance")
			await create_timer(0.15).timeout
		ok("the lamplighter's broadcast plays to its end", box and not bool(box.get("active")))

	# tune each band: its stage opens
	for st in [1, 2, 3, 4]:
		sig.call("tune", st)
		ok("tune(%d) sets %s" % [st, KEYS[st - 1]], bool(GameState.get_value(KEYS[st - 1], false)))
	await create_timer(7.0).timeout
	for st in [1, 2, 3, 4]:
		var s := standable(sig, st)
		ok("stage %d open: standable %s" % [st, str(s)], not s.has(false))

	# tuned stays tuned: a reload starts open
	GameState.set_value("debug_goto", "CP_Band2")
	sc = await load_scene("res://scenes/surface.tscn")
	sig = sc.find_child("MastSignal", false, false)
	await frames(4)
	for st in [1, 2, 3, 4]:
		var s := standable(sig, st)
		ok("after reload stage %d open %s" % [st, str(s)], not s.has(false))
	# the summit (mast_final is set from the cabin above: start it unset again)
	GameState.set_value("mast_final", false)
	GameState.set_value("debug_goto", "CP_Cabin")
	sc = await load_scene("res://scenes/surface.tscn")
	sig = sc.find_child("MastSignal", false, false)
	await summit_checks(sig, get_first_node_in_group("player") as CharacterBody3D)
	ok("the summit checks ran to the end (no script error)", summit_done)
	_done()

## Climb a ladder for real: stand at its foot facing it, hold forward until it's done or `limit` s pass.
func climb(p: CharacterBody3D, lad: Area3D, limit: float) -> float:
	var n: Vector3 = lad.get("climb_normal")
	var sh := (lad.get_node("CollisionShape3D") as CollisionShape3D).shape as BoxShape3D
	var foot := lad.global_position - n * 0.22 + Vector3(0, -sh.size.y * 0.5 + 0.05, 0) + n * 0.45
	p.global_position = foot
	p.velocity = Vector3.ZERO
	p.rotation.y = atan2(n.x, n.z)            # facing -n: into the ladder
	(p.get_node("Head") as Node3D).rotation.x = 0.0
	await frames(3)
	Input.action_press("move_forward")
	var t := 0.0
	var top := lad.global_position.y + sh.size.y * 0.5 - 0.8
	while t < limit:
		await physics_frame
		t += 1.0 / 60.0
		if p.global_position.y > top - 0.05 and p.is_on_floor():
			break
	for i in 30:
		await physics_frame
	Input.action_release("move_forward")
	await frames(20)
	return p.global_position.y - top

func summit_checks(sig: Node, p: CharacterBody3D) -> void:
	var su := sig.get_node_or_null("Summit")
	ok("summit built (5 ladders)", su != null and su.find_children("Ladder_*", "Area3D", false, false).size() == 5)
	if su == null:
		return
	var cage: Node3D = su.get("_cage")
	ok("the cage starts shut", (cage.transform as Transform3D).is_equal_approx(su.get("_cage_rest")))
	var l1 := su.get_node("Ladder_1") as Area3D
	ok("ladder 1 is out of reach while shut", (l1.get_node("CollisionShape3D") as CollisionShape3D).disabled)
	sig.call("final_tune")
	await create_timer(4.0).timeout
	ok("the final tuning lifts the cage", cage.position.y > (su.get("_cage_rest") as Transform3D).origin.y + 2.0)
	ok("and frees ladder 1", not (l1.get_node("CollisionShape3D") as CollisionShape3D).disabled)
	ok("the high wind blows", (su.get("_wind") as CPUParticles3D).emitting)
	p.set("god", true)
	for k in range(1, 6):
		var d := float(await climb(p, su.get_node("Ladder_%d" % k) as Area3D, 30.0))
		ok("climbs ladder %d to its landing (%+.2f m)" % [k, d], absf(d) < 0.35 and p.is_on_floor())
	var perch: Node3D = su.get("perch")
	var em: Node3D = su.get("ember")
	var to := (em.global_position - perch.global_position)
	to.y = 0.0
	to = to.normalized()
	ok("gliding at the lamps is into the wind", su.call("into_the_wind", perch.global_position + to * 4.0, to * 8.0))
	ok("gliding away is not", not su.call("into_the_wind", perch.global_position - to * 4.0, -to * 8.0))
	ok("too far off the top is not", not su.call("into_the_wind", perch.global_position + to * 150.0, to * 8.0))
	# leave: off the perch towards Ember with the Pennon open
	p.set("has_pennon", true)
	p.global_position = perch.global_position + to * 3.0 + Vector3(0, 0.5, 0)
	p.velocity = to * 7.0
	p.call("_start_glide")
	await frames(10)
	ok("the wind takes you", bool(su.get("_leaving")))
	for i in 600:
		await process_frame
		if current_scene and current_scene.scene_file_path == "res://scenes/ember.tscn" and get_first_node_in_group("player"):
			break
	await frames(10)
	ok("you land in Ember (stub)", current_scene != null and current_scene.scene_file_path == "res://scenes/ember.tscn")
	var pl := get_first_node_in_group("player") as Node3D
	var sp := current_scene.find_child("FromHighWind", true, false) as Node3D if current_scene else null
	ok("at FromHighWind", pl != null and sp != null and pl.global_position.distance_to(sp.global_position) < 1.5)
	summit_done = true

func _done() -> void:
	print("mast_test: %d/%d passed" % [checks - fails, checks])
	quit(0 if fails == 0 else 1)
