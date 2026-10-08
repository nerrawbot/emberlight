extends SceneTree
## Performance benchmark: average GPU/CPU frame time, draw calls and primitives at fixed views.
## godot --path . --disable-vsync --script res://tools/bench.gd [-- power] [exp=a,b,...] [quick]
## (not headless; keep the window visible and uncovered while it runs)
## Experiments switch features off at runtime to measure what they cost (see _experiment()).

const VIEWS := [
	["spawn tunnel", Vector3(-9.4, 1.65, 8.7), -90.0, 0.0],
	["walkway", Vector3(9.0, 1.65, 9.6), 80.0, 4.0],
	["old deck", Vector3(3, 18.05, -1.5), -90.0, -4.0],
	["mezz bridge", Vector3(24, 23.45, -7.3), -92.0, -4.0],
	["floor mid", Vector3(36.5, 0.3, -1.0), -61.0, -6.0],
	["floor wide", Vector3(31, 0.2, 2.0), -75.0, 3.0],
	["B2 breaker", Vector3(68.8, 19.05, -1.0), -80.0, 4.0],
	["surface", Vector3(29.5, 34.35, 5.5), 55.0, 10.0],
]
const QUICK := [2, 4, 5, 6]
const START_VIEWS := [
	["sr spawn", Vector3(-7.6, 38.05, 1.5), -90.0, -4.0],
	["sr L1", Vector3(-6.0, 31.05, -4.0), -120.0, -25.0],
	["sr valve", Vector3(5.2, 24.05, 1.2), 90.0, 0.0],
	["sr arch", Vector3(-3.5, 13.05, 1.5), 100.0, 5.0],
	["sr bridge", Vector3(-8.0, 5.05, 1.0), -90.0, 0.0],
	["sr look up", Vector3(1.0, 5.05, 1.0), 0.0, 60.0],
]
const SURFACE_VIEWS := [
	["mesa landing", Vector3(24.0, 34.32, 2.9), -90.0, 4.0],
	["mesa plateau", Vector3(10.0, 36.0, -30.0), 150.0, -3.0],
	["mesa gallery", Vector3(56.0, 40.05, -20.0), 120.0, -2.0],
	["mesa lookout", Vector3(60.5, 46.05, 36.0), 200.0, -10.0],
	["mesa tower", Vector3(58.0, 46.05, 10.0), 0.0, -5.0],
]

func _init() -> void:
	_run.call_deferred()

func _all(n: Node, cls: String, out: Array) -> Array:
	if n.is_class(cls):
		out.append(n)
	for c in n.get_children():
		_all(c, cls, out)
	return out

func _experiment(main: Node, e: String) -> void:
	var env: Environment = main.get_node("WorldEnvironment").environment
	var vp := root.get_viewport_rid()
	match e:
		"fog": env.volumetric_fog_enabled = false
		"fog64": RenderingServer.environment_set_volumetric_fog_volume_size(64, 64)
		"ssr": env.ssr_enabled = false
		"crshadow":
			for g in _all(main.get_node("Creatures"), "GeometryInstance3D", []): g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		"mothshadow":
			for g in _all(main.get_node("Creatures/Moths"), "GeometryInstance3D", []): g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		"mothlayer":
			for g in _all(main.get_node("Creatures/Moths"), "GeometryInstance3D", []):
				g.layers = 2
				g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			for l in _all(main, "Light3D", []): l.shadow_caster_mask = 1
		"mothlight":
			for c in main.get_node("Creatures/Moths").get_children(): c.get_node("Glow").visible = false
		"mothmodel":
			for c in main.get_node("Creatures/Moths").get_children(): c.get_node("Model").visible = false
		"scfreeze":
			for c in main.get_node("Creatures/Scuttlers").get_children(): c.process_mode = Node.PROCESS_MODE_DISABLED
		"wfreeze":
			for c in main.get_node("Creatures/Watchers").get_children(): c.process_mode = Node.PROCESS_MODE_DISABLED
		"mfreeze":
			for c in main.get_node("Creatures/Moths").get_children(): c.process_mode = Node.PROCESS_MODE_DISABLED
		"crfreeze":
			for c in _all(main.get_node("Creatures"), "Node3D", []): c.process_mode = Node.PROCESS_MODE_DISABLED
		"ssr32":env.ssr_max_steps = 32
		"fog80": RenderingServer.environment_set_volumetric_fog_volume_size(80, 80)
		"ssao": env.ssao_enabled = false
		"noclutter": main.get_node("Clutter").visible = false        # v17 ground clutter (surface)
		"nodecals": main.get_node("Decals").visible = false          # v18 wall decals (surface)
		"clutternoshadow":
			for g in _all(main.get_node("Clutter"), "GeometryInstance3D", []): g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		"glow": env.glow_enabled = false
		"omnishadow":
			for l in _all(main, "OmniLight3D", []): l.shadow_enabled = false
		"spotshadow":
			for l in _all(main, "SpotLight3D", []): l.shadow_enabled = false
		"sunshadow": main.get_node("SurfaceSun").shadow_enabled = false
		"particles":
			for p in _all(main, "GPUParticles3D", []): p.visible = false
		"atlas4k": RenderingServer.viewport_set_positional_shadow_atlas_size(vp, 4096)
		"atlas2k": RenderingServer.viewport_set_positional_shadow_atlas_size(vp, 2048)
		"msaa": root.msaa_3d = Viewport.MSAA_DISABLED
		"fxaa": root.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
		"lights":
			for l in _all(main, "Light3D", []): if not l is DirectionalLight3D: l.visible = false
		"lod": root.mesh_lod_threshold = 4.0
		"foliage": main.get_node("Level/Foliage").visible = false
		"creatures": main.get_node("Creatures").visible = false
		"hazeshadow":
			for l in main.get_node("Lights/BackgroundHaze").get_children(): l.shadow_enabled = false
		"shadowfade":
			for l in _all(main, "OmniLight3D", []) + _all(main, "SpotLight3D", []):
				if l.shadow_enabled:
					l.distance_fade_enabled = true
					l.distance_fade_begin = 90.0
					l.distance_fade_length = 10.0
					l.distance_fade_shadow = 28.0
		"sunmask":
			for n in ["Level/Foliage", "Level/Detail", "Level/Detail2", "Level/Lamps", "Level/Lamps2", "Level/Background", "Level/Framing", "Level/Water", "Creatures", "Particles", "Interactables"]:
				var nd := main.get_node_or_null(n)
				if nd == null:
					print("[BENCH] missing ", n)
					continue
				for g in _all(nd, "VisualInstance3D", []): g.layers = 2
			main.get_node("SurfaceSun").shadow_caster_mask = 1
		"sun4k":RenderingServer.directional_shadow_atlas_set_size(4096, true)
		"sundist": main.get_node("SurfaceSun").directional_shadow_max_distance = 90.0
		"sun2split": main.get_node("SurfaceSun").directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
		"softq2":
			RenderingServer.positional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM)
			RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM)
		_: print("[BENCH] unknown experiment ", e)

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var start := "start" in args
	var surface := "surface" in args
	var main: Node = load("res://scenes/start.tscn" if start else ("res://scenes/surface.tscn" if surface else "res://scenes/main.tscn")).instantiate()
	main.get_node("ShotTour").free()
	root.add_child(main)
	var p = main.get_node("Player")
	p.input_enabled = false
	p.set_physics_process(false)
	if "power" in args:
		main.get_node("PowerGrid").set_powered(true)
	var label := "baseline"
	for a in args:
		if a.begins_with("exp="):
			label = a.substr(4)
			for e in label.split(","):
				_experiment(main, e)
	var vp := root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp, true)
	var tot_gpu := 0.0
	var tot_cpu := 0.0
	var views := []
	if start:
		views = START_VIEWS.duplicate()
	elif surface:
		views = SURFACE_VIEWS.duplicate()
	else:
		for i in VIEWS.size():
			if not "quick" in args or i in QUICK:
				views.append(VIEWS[i])
	for v in views:
		p.global_position = v[1]
		p.rotation = Vector3(0, deg_to_rad(v[2]), 0)
		p.get_node("Head").rotation = Vector3(deg_to_rad(v[3]), 0, 0)
		for i in 90:
			await process_frame
		var gpu := 0.0
		var cpu := 0.0
		var n := 120
		var t0 := Time.get_ticks_usec()
		for i in n:
			await process_frame
			gpu += RenderingServer.viewport_get_measured_render_time_gpu(vp)
			cpu += RenderingServer.viewport_get_measured_render_time_cpu(vp) + RenderingServer.get_frame_setup_time_cpu()
		var wall := (Time.get_ticks_usec() - t0) / 1000.0 / n
		var dc := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
		var prim := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
		var objs := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME)
		print("[BENCH] %-13s gpu %6.2f ms  cpu %5.2f ms  frame %6.2f ms  draws %5d  objs %5d  prims %8d" % [v[0], gpu / n, cpu / n, wall, dc, objs, prim])
		tot_gpu += gpu / n
		tot_cpu += cpu / n
	print("[BENCH] MEAN[%s] gpu %.2f ms  cpu %.2f ms  vram %.0f MB" % [label, tot_gpu / views.size(), tot_cpu / views.size(), RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED) / 1048576.0])
	quit()
