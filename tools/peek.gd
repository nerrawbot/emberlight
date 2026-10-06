extends SceneTree
## Debug: render views of main.tscn from arbitrary cameras.
## godot --path . --script res://tools/peek.gd -- <out_dir> <bright 0|1> x,y,z,tx,ty,tz[,fov] ...   (Godot coords)
## Extra args: scene=res://... picks the scene; collide draws collision shapes.

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0]
	var bright := args[1] == "1"
	var scene_path := "res://scenes/main.tscn"
	var views := []
	for a in args.slice(2):
		if a.begins_with("scene="):
			scene_path = a.substr(6)
		elif a == "collide":        # draw collision shapes (hitbox review)
			debug_collisions_hint = true
		else:
			views.append(a)
	var main: Node = load(scene_path).instantiate()
	var sh := main.get_node_or_null("ShotTour")
	if sh:
		sh.free()
	root.add_child(main)
	var p := main.get_node_or_null("Player")
	if p:
		p.set_physics_process(false)
		p.input_enabled = false
		p.get_node("HUD").visible = false
	var grid := main.get_node_or_null("PowerGrid")
	if grid:
		grid.set_powered(true)
	if bright:
		var we: WorldEnvironment = main.get_node("WorldEnvironment")
		we.environment.ambient_light_energy = 6.0
		we.environment.volumetric_fog_enabled = false
	var cam := Camera3D.new()
	cam.far = 800
	root.add_child(cam)
	cam.current = true
	DirAccess.make_dir_recursive_absolute(out)
	var i := 0
	for v in views:
		var f: PackedFloat64Array = PackedFloat64Array(Array(v.split(",")).map(func(s): return float(s)))
		cam.fov = f[6] if f.size() > 6 else 70.0
		cam.global_position = Vector3(f[0], f[1], f[2])
		cam.look_at(Vector3(f[3], f[4], f[5]), Vector3.UP if absf(f[1] - f[4]) < 0.99 * Vector3(f[0], f[1], f[2]).distance_to(Vector3(f[3], f[4], f[5])) else Vector3.FORWARD)
		for k in 40:
			await process_frame
		get_root().get_texture().get_image().save_png(out.path_join("v_%02d.png" % i))
		print("saved ", i)
		i += 1
	quit()
