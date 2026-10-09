extends SceneTree
## v16 checks: the Ember rifle kit (scripts/ember_rifle.gd + player.gd v16). Surface, god mode, target boxes that
## record the damage take_hit() gets (as enemy.gd reads it: by.attack_damage).
##   tools\godot.cmd --headless --script res://tools/rifle_test.gd

const GameState := preload("res://scripts/game_state.gd")

var fails := 0
var checks := 0

class Target extends StaticBody3D:
	var got: Array = []
	func take_hit(by: Node3D, _dir: Vector3) -> void:
		got.append(float(by.get("attack_damage")))

func _initialize() -> void:
	create_timer(120.0).timeout.connect(func():
		print("rifle_test: TIMED OUT after %d checks" % checks)
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

func target(at: Vector3, size: Vector3) -> Target:
	var t := Target.new()
	var cs := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = size
	cs.shape = b
	t.add_child(cs)
	current_scene.add_child(t)
	t.global_position = at
	return t

func place(t: Target) -> void:
	await frames(2)         # (a new body only joins the physics space next step)

func _run() -> void:
	change_scene_to_file("res://scenes/surface.tscn")
	for i in 600:
		await process_frame
		if current_scene and get_first_node_in_group("player"):
			break
	await frames(10)
	var p := get_first_node_in_group("player") as CharacterBody3D
	p.set("god", true)
	p.call("set_rifle_kit", true)
	await frames(5)
	var rifle: Node3D = p.get("_rifle")
	ok("kit: rifle is in hand, shaft hidden", rifle != null and rifle.is_inside_tree())
	# stand high over the open plateau (nothing in the way of the test boxes), looking level along -Z
	p.global_position = Vector3(32, 120, 6)
	p.velocity = Vector3.ZERO
	p.rotation.y = 0.0
	(p.get_node("Head") as Node3D).rotation.x = 0.0
	p.set_physics_process(false)
	await frames(3)
	var eye: Vector3 = (p.get("camera") as Camera3D).global_position
	var base := float(p.get("attack_damage"))

	# hipfire: a wide box catches the whole fan; damage adds up to one shaft hit
	var wide := target(eye + Vector3(0, 0, -5), Vector3(4, 1.2, 0.4))
	await place(wide)
	ok("hipfire: fires when loaded", rifle.call("hipfire"))
	ok("hipfire: whole fan on one target = %s (got %s)" % [base, wide.got], wide.got.size() == 1 and absf(wide.got[0] - base) < 0.01)
	ok("hipfire: not loaded right after", not rifle.get("loaded"))
	ok("hipfire: can't fire again mid-reload", not rifle.call("hipfire"))
	ok("player damage restored after the shot", is_equal_approx(float(p.get("attack_damage")), base))
	wide.queue_free()
	await create_timer(0.95).timeout
	ok("reload: auto, done within 0.95 s", rifle.get("loaded"))

	# a narrow box: only the middle pellet hits
	var thin := target(eye + Vector3(0, 0, -5), Vector3(0.25, 1.2, 0.4))
	await place(thin)
	rifle.call("hipfire")
	ok("hipfire: one pellet = 1/5 (got %s)" % [thin.got], thin.got.size() == 1 and absf(thin.got[0] - base / 5.0) < 0.01)
	await create_timer(0.95).timeout

	# aim + charge: tap = 1x, full hold = 4x
	rifle.call("aim_press")
	await frames(2)
	thin.got.clear()
	rifle.call("aim_release")
	ok("charged: a tap does 1x (got %s)" % [thin.got], thin.got.size() == 1 and absf(thin.got[0] - base) < base * 0.08)
	await create_timer(1.2).timeout
	rifle.call("aim_press")
	await create_timer(0.7).timeout
	ok("aim: slows the player (move_mult %.2f)" % float(p.get("move_mult")), float(p.get("move_mult")) < 0.6)
	var mid := float(rifle.call("current_mult"))
	ok("charge: about half way at 0.7 s (x%.2f)" % mid, mid > 2.0 and mid < 3.0)
	await create_timer(1.0).timeout
	thin.got.clear()
	rifle.call("aim_release")
	ok("charged: full hold does 4x (got %s)" % [thin.got], thin.got.size() == 1 and absf(thin.got[0] - base * 4.0) < 0.01)
	await create_timer(0.3).timeout
	ok("aim: speed back after release (move_mult %.2f)" % float(p.get("move_mult")), float(p.get("move_mult")) > 0.95)
	thin.queue_free()

	# back leap on the plateau: lands far behind, stays low; finishes the reload; no dash in this kit.
	# From the lift landing, tried facing several ways (the first with room behind counts).
	p.set_physics_process(true)
	ok("dash: off in the rifle kit", true if (func(): p.call("dash"); return float(p.get("_dash_t")) <= 0.0).call() else false)
	var best := Vector2.ZERO
	var best_peak := 0.0
	var leapt := false
	var reloaded := false
	for yaw in [0.0, 90.0, 180.0, 270.0, 45.0, 135.0]:
		p.global_position = Vector3(24, 34.8, 2.9)
		p.velocity = Vector3.ZERO
		p.rotation.y = deg_to_rad(yaw)
		for i in 120:
			await physics_frame
			if p.is_on_floor():
				break
		await frames(40)          # past the leap cooldown
		rifle.call("finish_reload")
		rifle.call("hipfire")
		var start := p.global_position
		if not p.call("back_leap"):
			continue
		leapt = true
		reloaded = rifle.get("loaded")
		var peak := 0.0
		for i in 180:
			await physics_frame
			peak = maxf(peak, p.global_position.y - start.y)
			if i > 5 and p.is_on_floor():
				break
		var d := p.global_position - start
		var back := Vector3(sin(deg_to_rad(yaw)), 0, cos(deg_to_rad(yaw)))      # +Z rotated by yaw = behind the view
		var along := Vector2(d.x, d.z).dot(Vector2(back.x, back.z))
		print("  leap yaw %d: %.2f m back, peak %.2f m" % [yaw, along, peak])
		if along > best.x:
			best = Vector2(along, 0)
			best_peak = peak
		if along > 5.0:
			break
	ok("leap: Q leaps", leapt)
	ok("leap: finishes the reload", reloaded)
	ok("leap: long and low: %.1f m back, peak %.2f m" % [best.x, best_peak], best.x > 5.0 and best_peak < 1.2)

	p.call("set_rifle_kit", false)
	await frames(3)
	ok("kit off: rifle gone, mults reset", p.get("_rifle") == null and float(p.get("move_mult")) == 1.0)
	GameState.set_value("rifle_kit", false)
	print("rifle_test: %d checks, %d fails" % [checks, fails])
	quit(1 if fails > 0 else 0)
