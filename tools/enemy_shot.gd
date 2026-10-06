extends SceneTree
## Debug: render the surface hostiles through the player camera (HUD on): idle, the tripod's charge tell, the health
## bar after hits, the death burst, and the skate's wind-up.
##   tools\godot.cmd --script res://tools/enemy_shot.gd -- <out_dir>      (not headless)

var main: Node
var p
var out := ""
var n := 0

func _init() -> void:
	_run.call_deferred()

func _frames(k: int) -> void:
	for i in k:
		await process_frame

func _shot(label: String) -> void:
	get_root().get_texture().get_image().save_png(out.path_join("e_%02d_%s.png" % [n, label]))
	var cam := get_root().get_camera_3d()
	print("saved ", n, " ", label, " yaw=", p.rotation, " head=", p.get_node("Head").rotation, " cam=", cam.rotation, " fov=", cam.fov, " trauma=", p._trauma)
	n += 1

func _run() -> void:
	out = OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(out)
	main = load("res://scenes/surface.tscn").instantiate()
	main.get_node("ShotTour").free()
	root.add_child(main)
	p = main.get_node("Player")
	var sp = main.get_node("Enemies")
	sp.enabled = false
	await process_frame
	p.give_weapon(true)
	p.set_physics_process(false)
	p.input_enabled = false          # enemies ignore you until a view wants them to act
	p.global_position = Vector3(8, 34.32, -6)
	p.rotation = Vector3(0, PI, 0)
	p.get_node("Head").rotation = Vector3(deg_to_rad(6), 0, 0)
	var t = sp._spawn(0, Vector3(9.5, 34.3, 1.0))
	t.rotation.y = PI + 0.5
	await _frames(90)
	await _shot("tripod_idle")
	# the charge tell: aim line + eye flare
	p.input_enabled = true
	t._cd_bolt = 99.0
	t._cd_stomp = 99.0
	t._sees = true
	t._last_seen = p.global_position
	t._enter(t.S.CHARGE)
	t._t = 0.55
	t.charge_time = 99.0
	await _frames(20)
	await _shot("tripod_charge")
	t.state = t.S.ENGAGE
	t.set_physics_process(false)
	t._update_aim_line()
	var dir: Vector3 = (t.global_position - p.global_position).normalized()
	t.take_hit(p, dir)
	t.take_hit(p, dir)
	await _frames(25)
	await _shot("tripod_bar")
	t.take_hit(p, dir)
	t.take_hit(p, dir)
	await _frames(5)
	await _shot("tripod_burst")
	await _frames(30)
	await _shot("tripod_debris")
	await _frames(120)
	# skate: hovering, then winding up
	p.input_enabled = false
	var s = sp._spawn(1, Vector3(8.5, 36.4, -1.5))
	await _frames(60)
	s.global_position = Vector3(8.5, 36.4, -1.5)
	s.set_physics_process(false)
	s._yaw = PI * 0.85
	s._model.rotation = Vector3(0.1, s._yaw, 0.15)
	await _frames(10)
	await _shot("skate_idle")
	s.state = s.S.WINDUP
	s._t = 0.3
	for k in 12:
		s._animate(1.0 / 60.0, Vector3(0, 0, -1))
		await process_frame
	await _shot("skate_windup")
	s.take_hit(p, Vector3(0, 0, 1))
	await _frames(25)
	await _shot("skate_bar")
	s.take_hit(p, Vector3(0, 0, 1))
	s.take_hit(p, Vector3(0, 0, 1))
	await _frames(6)
	await _shot("skate_burst")
	quit()
