extends SceneTree
## Debug: render through the PLAYER camera (HUD + held weapon visible), unlike peek.gd.
## godot --path . --script res://tools/hud_shot.gd -- <out_dir> scene=res://scenes/start.tscn [weapon] [drone] [hp=35] [shield=8] x,y,z,yaw,pitch ...
## Positions are Godot coords of the player's feet; yaw/pitch in degrees. `swing` as a view renders mid-swing.
## `drone` gives the warden drone (companion + shield arc); `shield=` sets its shield for every view.
## call:NodePath:method:arg1~arg2 calls a method (args via str_to_var, else plain strings), e.g.
##   call:Player:add_item:tokens~57   call:Player:start_dialogue:sentinel_09~SENTINEL-09   call:Player/HUD/Inventory:toggle

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0]
	var scene_path := "res://scenes/start.tscn"
	var weapon := false
	var hp := -1.0
	var drone := false
	var shield := -1.0
	var views := []
	for a in args.slice(1):
		if a.begins_with("scene="):
			scene_path = a.substr(6)
		elif a == "weapon":
			weapon = true
		elif a == "drone":
			drone = true
		elif a.begins_with("shield="):
			shield = float(a.substr(7))
		elif a.begins_with("hp="):
			hp = float(a.substr(3))
		elif a.begins_with("env:") or a.begins_with("set:") or a.begins_with("call:"):      # env:volumetric_fog_enabled=false, set:Sun:visible=false
			views.append(a)
		else:
			views.append(a)
	var main: Node = load(scene_path).instantiate()
	var sh := main.get_node_or_null("ShotTour")
	if sh:
		sh.free()
	root.add_child(main)
	var p = main.get_node("Player")
	await process_frame
	if weapon:
		p.give_weapon(true)
	if drone:
		p.give_drone()
	DirAccess.make_dir_recursive_absolute(out)
	var i := 0
	for v in views:
		if v.begins_with("set:"):         # set:NodePath:property=value (relative to the scene root)
			var parts: PackedStringArray = v.substr(4).split(":")
			var kv2: PackedStringArray = parts[1].split("=")
			main.get_node(parts[0]).set(kv2[0], str_to_var(kv2[1]))
			continue
		if v.begins_with("call:"):
			var cp: PackedStringArray = v.substr(5).split(":")
			var cargs := []
			if cp.size() > 2:
				for s in cp[2].split("~"):         # (not "|": cmd.exe eats it in godot.cmd)
					var val: Variant = str_to_var(s)
					cargs.append(s if val == null else val)
			main.get_node(cp[0]).callv(cp[1], cargs)
			continue
		if v.begins_with("env:"):
			var kv: PackedStringArray = v.substr(4).split("=")
			var env: Environment = (main.get_node("WorldEnvironment") as WorldEnvironment).environment
			env.set(kv[0], str_to_var(kv[1]))
			continue
		if v == "swing":
			p._attack_cd = 0.0
			p.input_enabled = true
			p.attack()
			for k in 8:
				await process_frame
		else:
			var f := Array(v.split(",")).map(func(s): return float(s))
			p.set_physics_process(false)
			p.global_position = Vector3(f[0], f[1], f[2])
			p.rotation = Vector3(0, deg_to_rad(f[3]), 0)
			p.get_node("Head").rotation = Vector3(deg_to_rad(f[4]), 0, 0)
			if hp >= 0.0:
				p._set_health(100.0)
				if drone:
					p._set_shield(0.0)       # (else the shield soaks the staged damage)
				p.take_damage(100.0 - hp)
			if drone and shield >= 0.0:
				p._set_shield(shield)
			for k in 50:
				await process_frame
		get_root().get_texture().get_image().save_png(out.path_join("h_%02d.png" % i))
		print("saved ", i)
		i += 1
	quit()
