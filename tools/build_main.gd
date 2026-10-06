extends SceneTree
## Builds res://scenes/player.tscn and res://scenes/main.tscn from the imported assets.
## Run headless:  godot --headless --path . --script res://tools/build_main.gd
## NOTE: overwrites scenes/main.tscn.

var main_root: Node3D
var data: Dictionary
var _radial: GradientTexture2D
var _ring: GradientTexture2D

func b2g(v) -> Vector3:
	# Blender (Z-up) -> Godot (Y-up)
	return Vector3(v[0], v[2], -v[1])

func add(parent: Node, child: Node, owner_node: Node = null) -> Node:
	parent.add_child(child)
	child.owner = owner_node if owner_node else main_root
	return child

func group(parent: Node, n: String) -> Node3D:
	var g := Node3D.new()
	g.name = n
	add(parent, g)
	return g

func inst(path: String, n: String) -> Node3D:
	var s: Node3D = load(path).instantiate()
	s.name = n
	return s

func box_shape(parent: Node, size: Vector3, pos: Vector3, n := "CollisionShape3D") -> CollisionShape3D:
	var cs := CollisionShape3D.new()
	cs.name = n
	var b := BoxShape3D.new()
	b.size = size
	cs.shape = b
	cs.position = pos
	add(parent, cs)
	return cs

func _init() -> void:
	data = JSON.parse_string(FileAccess.get_file_as_string("res://art_src/lights.json"))
	var err := ResourceSaver.save(build_player(), "res://scenes/player.tscn")
	print("player saved: ", err)
	var pscene: PackedScene = load("res://scenes/player.tscn")

	main_root = Node3D.new()
	main_root.name = "Main"

	var grid := Node.new()
	grid.name = "PowerGrid"
	grid.set_script(load("res://scripts/power_grid.gd"))
	add(main_root, grid)

	var level := inst("res://assets/level/cavern.glb", "Level")
	add(main_root, level)

	build_environment()
	build_lights()
	build_fog_volumes()
	build_lift()
	build_interactables()
	build_ladder()
	build_creatures()
	build_particles()
	build_stair_gate()
	build_tunnel()

	# the surface is its own scene (surface.tscn, the mesa): stepping off the lift landing, or out through the
	# open stair-3 gate, takes you there. Both line up with the same spots up top.
	var exit := Area3D.new()
	exit.name = "ExitToSurface"
	exit.set_script(load("res://scripts/exit_zone.gd"))
	exit.set("next_scene", "res://scenes/surface.tscn")
	exit.set("target_spawn", "FromLift")
	exit.set("once", false)
	exit.position = b2g([26.0, -2.9, 35.9])
	add(main_root, exit)
	box_shape(exit, Vector3(2.0, 3.2, 4.4), Vector3.ZERO)
	# (v8: stair 3 has caved in - no more stair exit; see build_stair_gate)

	# arrival points (group spawn_point; exit zones in other scenes name them)
	var spawns := group(main_root, "Spawns")
	var start := spawn_marker(spawns, "FromStart", b2g([-9.4, -8.7, 1.62]), -90.0)
	spawn_marker(spawns, "OldDeckStart", Vector3(3, 18.05, -1.5), -90.0)
	var player := pscene.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	player.name = "Player"
	player.transform = start.transform
	add(main_root, player)

	var tour := Node.new()
	tour.name = "ShotTour"
	tour.set_script(load("res://scripts/shot_tour.gd"))
	add(main_root, tour)

	var ps := PackedScene.new()
	ps.pack(main_root)
	err = ResourceSaver.save(ps, "res://scenes/main.tscn")
	print("main saved: ", err)
	main_root.free()
	quit()

# ------------------------------------------------------------------ environment
func build_environment() -> void:
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.80, 0.81, 0.82)
	sm.sky_horizon_color = Color(0.96, 0.93, 0.85)
	sm.ground_horizon_color = Color(0.96, 0.93, 0.85)
	sm.ground_bottom_color = Color(0.7, 0.68, 0.64)
	sky.sky_material = sm
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.14, 0.13, 0.26)
	env.ambient_light_energy = 1.05
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.25
	env.ssr_enabled = true
	env.ssr_max_steps = 48
	env.ssr_fade_in = 0.1
	env.ssr_fade_out = 1.5
	env.ssao_enabled = true
	env.ssao_radius = 1.6
	env.ssao_intensity = 2.2
	env.ssao_power = 1.6
	env.glow_enabled = true
	env.glow_intensity = 0.65
	env.glow_strength = 1.1
	env.glow_bloom = 0.06
	env.glow_hdr_threshold = 1.1
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.013
	env.volumetric_fog_albedo = Color(0.62, 0.68, 0.9)
	env.volumetric_fog_emission = Color(0.035, 0.04, 0.08)
	env.volumetric_fog_emission_energy = 1.0
	env.volumetric_fog_anisotropy = 0.45
	env.volumetric_fog_length = 90.0
	env.volumetric_fog_ambient_inject = 0.22
	env.volumetric_fog_sky_affect = 0.0
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.12
	env.adjustment_saturation = 0.95
	we.environment = env
	add(main_root, we)

	var sun := DirectionalLight3D.new()
	sun.name = "SurfaceSun"
	sun.rotation_degrees = Vector3(-62, 70, 0)
	sun.light_color = Color(1.0, 0.97, 0.9)
	sun.light_energy = 1.8
	sun.light_volumetric_fog_energy = 1.5   # was 4.0: daylight through the stair hole + lift shaft washed the fog out white
	sun.light_angular_distance = 1.2
	sun.shadow_enabled = true
	sun.shadow_blur = 1.5
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 160.0
	sun.shadow_caster_mask = 1
	add(main_root, sun)

func omni(parent: Node, n: String, pos: Vector3, color: Color, energy: float, rng: float, shadow := false, fog := 2.0) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.name = n
	l.position = pos
	l.light_color = color
	l.light_energy = energy
	l.omni_range = rng
	l.omni_attenuation = 1.6
	l.light_volumetric_fog_energy = fog
	l.shadow_enabled = shadow
	l.light_size = 0.15 if shadow else 0.0
	if shadow:
		shadow_fade(l)
	add(parent, l)
	return l

func shadow_fade(l: Light3D) -> void:
	# shadows are the main GPU cost: drop them for lights far from the camera (the light itself stays)
	l.distance_fade_enabled = true
	l.distance_fade_begin = 90.0
	l.distance_fade_length = 10.0
	l.distance_fade_shadow = 28.0
	# moving creatures live on render layer 2 so they don't force shadow-map redraws every frame
	l.shadow_caster_mask = 1

func powered(l: Light3D, on_e: float, off_e: float) -> void:
	l.set_script(load("res://scripts/powered_light.gd"))
	l.set("on_energy", on_e)
	l.set("off_energy", off_e)
	l.light_energy = off_e

func build_lights() -> void:
	var g := group(main_root, "Lights")
	var fol := group(g, "FoliageGlow")
	var i := 0
	for d in data["foliage_lights"]:
		var e: float = d["energy"]
		omni(fol, "Glow_%02d" % i, b2g(d["pos"]), Color(0.3, 0.46, 1.0), 2.2 * e, d["range"], e >= 1.3, 2.0)
		i += 1
	var lamps := group(g, "CageLamps")
	i = 0
	for p in data["lamps"]:
		var l := omni(lamps, "Lamp_%02d" % i, b2g(p) + Vector3(0, -0.15, 0), Color(0.62, 0.74, 1.0), 2.6, 11.0, true, 3.0)
		powered(l, 2.8, 1.3)
		i += 1
	# extra lamps (some broken + sparking)
	var bulb_mesh := SphereMesh.new()
	bulb_mesh.radius = 0.1
	bulb_mesh.height = 0.26
	i = 0
	for d in data["lamps2"]:
		var pos := b2g(d["pos"])
		if d["kind"] == "flicker":
			var l := omni(lamps, "Flicker_%02d" % i, pos + Vector3(0, 0.1, 0), Color(0.6, 0.75, 1.0), 2.2, 9.0, false, 3.0)
			var bulb := MeshInstance3D.new()
			bulb.name = "Bulb_%02d" % i
			bulb.mesh = bulb_mesh
			var bm := StandardMaterial3D.new()
			bm.albedo_color = Color(0.6, 0.7, 0.9)
			bm.emission_enabled = true
			bm.emission = Color(0.6, 0.78, 1.0)
			bm.emission_energy_multiplier = 6.0
			bulb.material_override = bm
			bulb.position = pos + Vector3(0, 0.17, 0)
			add(lamps, bulb)
			var sp := sparks(lamps, "Sparks_%02d" % i, pos + Vector3(0, 0.1, 0))
			l.set_script(load("res://scripts/flicker_light.gd"))
			l.set("base_energy", 2.2)
			l.set("bulb_path", NodePath("../" + bulb.name))
			l.set("sparks_path", NodePath("../" + sp.name))
		else:
			var l2 := omni(lamps, "Lamp2_%02d" % i, pos + Vector3(0, -0.15, 0), Color(0.62, 0.74, 1.0), 2.2, 10.0, true, 3.0)
			powered(l2, 2.4, 1.0)
		i += 1
	var bg := group(g, "BackgroundHaze")
	i = 0
	for p in [[30, 16, 9], [47, 16, 22], [63, 16, 11], [10, 15, 24], [72, 15, 24]]:
		omni(bg, "Haze_%02d" % i, b2g(p), Color(0.45, 0.52, 0.78), 1.6, 20.0, false, 3.5)   # fill light: shadows cost ~5 ms for no visible gain
		i += 1
	omni(bg, "ShaftDepth", b2g([23, 3, 4]), Color(0.4, 0.55, 0.95), 1.2, 14.0, false, 3.0)

	# floodlights that only come on with power
	var fl := group(g, "Floodlights")
	var housing := BoxMesh.new()
	housing.size = Vector3(0.5, 0.4, 0.45)
	var hm := StandardMaterial3D.new()
	hm.albedo_color = Color(0.05, 0.045, 0.07)
	hm.roughness = 0.8
	housing.material = hm
	i = 0
	for f in [[[50, -3.9, 23.6], [42, -2, 0]], [[66, -4.3, 20.4], [62, -6, 0]], [[29, -4.1, 14.3], [22, -2.5, 0]], [[44, 7.2, 26.2], [27, 7, 23.5]]]:
		var s := SpotLight3D.new()
		s.name = "Flood_%02d" % i
		s.transform = Transform3D(Basis(), b2g(f[0])).looking_at(b2g(f[1]), Vector3.UP)
		s.light_color = Color(0.82, 0.88, 1.0)
		s.spot_range = 38.0
		s.spot_angle = 28.0
		s.spot_attenuation = 0.8
		s.shadow_enabled = true
		shadow_fade(s)
		s.light_volumetric_fog_energy = 2.0
		add(fl, s)
		powered(s, 9.0, 0.0)
		var h := MeshInstance3D.new()
		h.name = "Housing"
		h.mesh = housing
		h.position = Vector3(0, 0, 0.25)
		add(s, h)
		i += 1
	# breaker cabinet glow: violet when dead, cyan when live
	var off_l := omni(g, "BreakerGlowOff", b2g([71.9, 2.0, 21.6]), Color(0.42, 0.3, 0.95), 0.5, 3.0, false, 1.0)
	powered(off_l, 0.0, 0.5)
	var on_l := omni(g, "BreakerGlowOn", b2g([71.9, 2.0, 21.6]), Color(0.4, 0.85, 1.0), 0.0, 4.5, false, 1.5)
	powered(on_l, 1.4, 0.0)

func build_fog_volumes() -> void:
	var g := group(main_root, "FogVolumes")
	var low := FogVolume.new()
	low.name = "LowMist"
	low.size = Vector3(84, 7, 30)
	low.position = Vector3(36, 2.0, -2)
	var m1 := FogMaterial.new()
	m1.density = 0.032
	m1.albedo = Color(0.6, 0.66, 0.9)
	m1.height_falloff = 0.35
	m1.edge_fade = 0.4
	low.material = m1
	add(g, low)
	var shaft := FogVolume.new()
	shaft.name = "ShaftHaze"
	shaft.size = Vector3(10, 30, 16)
	shaft.position = Vector3(22.5, 15, -3)
	var m2 := FogMaterial.new()
	m2.density = 0.022
	m2.albedo = Color(0.6, 0.68, 0.95)
	m2.emission = Color(0.02, 0.03, 0.07)
	m2.edge_fade = 0.6
	shaft.material = m2
	add(g, shaft)
	var clear := FogVolume.new()
	clear.name = "SurfaceClear"
	clear.size = Vector3(400, 60, 400)
	clear.position = Vector3(36, 65.2, -2)
	var m3 := FogMaterial.new()
	m3.density = -0.03
	m3.edge_fade = 0.05
	clear.material = m3
	add(g, clear)

# ------------------------------------------------------------------ lift
func cable_mesh(r := 0.035) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r
	c.height = 1.0
	c.radial_segments = 6
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.03, 0.03, 0.04)
	m.roughness = 0.6
	m.metallic = 0.4
	c.material = m
	return c

func hazard_mat() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = load("res://assets/tex/hazard_albedo.jpg")
	m.roughness = 0.85
	m.uv1_scale = Vector3(1, 6, 1)
	return m

const LIFT_STOPS := [0.2, 18.0, 34.3]   # cavern floor, upper (start) deck, surface

func boom_gate(parent: Node, n: String, pos: Vector3) -> Node3D:
	# safety boom: the bar runs along +Z from the post; solid while the car is elsewhere
	var gate := Node3D.new()
	gate.name = n
	gate.set_script(load("res://scripts/boom_gate.gd"))
	gate.position = pos
	add(parent, gate)
	var post := MeshInstance3D.new()
	post.name = "Post"
	var pm := BoxMesh.new()
	pm.size = Vector3(0.18, 1.1, 0.18)
	pm.material = hazard_mat()
	post.mesh = pm
	post.position = Vector3(0, -0.45, -0.1)
	add(gate, post)
	var pivot := Node3D.new()
	pivot.name = "Pivot"
	add(gate, pivot)
	var bar := MeshInstance3D.new()
	bar.name = "Bar"
	var bmesh := BoxMesh.new()
	bmesh.size = Vector3(0.09, 0.12, 3.1)
	bmesh.material = hazard_mat()
	bar.mesh = bmesh
	bar.position = Vector3(0, 0, 1.55)
	add(pivot, bar)
	var block := StaticBody3D.new()
	block.name = "Block"
	block.position = Vector3(0.0, -0.4, 1.6)
	add(gate, block)
	box_shape(block, Vector3(0.15, 1.3, 3.1), Vector3.ZERO)
	return gate

func build_lift() -> void:
	var rig := group(main_root, "LiftRig")
	var cx := 20.7
	var cz := 2.9
	var sheave_pos := b2g([20.7, -4.05, 41.6])   # headframe sheave on the surface (cable tangents at z 2.9 / 5.2)

	var cable := MeshInstance3D.new()
	cable.name = "LiftCable"
	cable.mesh = cable_mesh()
	cable.position = Vector3(cx, 20, cz)
	add(rig, cable)
	var cw := inst("res://assets/props/counterweight.glb", "Counterweight")
	cw.position = Vector3(cx, 10, 5.2)
	add(rig, cw)
	var cwc := MeshInstance3D.new()
	cwc.name = "CounterweightCable"
	cwc.mesh = cable_mesh(0.03)
	cwc.position = Vector3(cx, 20, 5.2)
	add(rig, cwc)
	var sheave := inst("res://assets/props/sheave.glb", "Sheave")
	sheave.position = sheave_pos
	add(rig, sheave)

	boom_gate(rig, "DeckGate", Vector3(18.72, 19.0, 1.3))
	boom_gate(rig, "SurfaceGate", Vector3(23.25, LIFT_STOPS[2] + 1.0, 1.25))

	var lift := AnimatableBody3D.new()
	lift.name = "Lift"
	lift.set_script(load("res://scripts/lift.gd"))
	lift.position = Vector3(cx, LIFT_STOPS[1], cz)
	lift.set("stops", PackedFloat32Array(LIFT_STOPS))
	lift.set("start_stop", 1)
	lift.set("pulley_y", sheave_pos.y)
	lift.set("cw_top", sheave_pos.y - 1.6)
	lift.set("cable_path", NodePath("../LiftCable"))
	lift.set("counterweight_path", NodePath("../Counterweight"))
	lift.set("cw_cable_path", NodePath("../CounterweightCable"))
	lift.set("sheave_path", NodePath("../Sheave"))
	var gates: Array[NodePath] = [NodePath(""), NodePath("../DeckGate"), NodePath("../SurfaceGate")]
	lift.set("gate_paths", gates)
	# riding up, the surface scene takes over inside the shaft and its car carries on into the daylight
	lift.set("handoff_scene", "res://scenes/surface.tscn")
	add(rig, lift)
	add(lift, inst("res://assets/props/lift_car.glb", "Model"))
	box_shape(lift, Vector3(3.0, 0.18, 3.0), Vector3(0, -0.09, 0), "Floor")
	box_shape(lift, Vector3(3.0, 1.1, 0.1), Vector3(0, 0.55, -1.45), "RailN")
	box_shape(lift, Vector3(3.0, 1.1, 0.1), Vector3(0, 0.55, 1.45), "RailS")
	box_shape(lift, Vector3(0.6, 1.0, 0.35), Vector3(1.05, 0.5, -1.225), "Ctrl")
	call_box(lift, "CarUp", Vector3(-1.05, 0, -1.15), 0.0, NodePath(".."), 0, 1)
	call_box(lift, "CarDown", Vector3(-0.42, 0, -1.15), 0.0, NodePath(".."), 0, -1)

	call_box(rig, "CallBottom", Vector3(23.7, data["floorz"]["callbox_bottom"], 0.25), 90.0, NodePath("../Lift"), 0, 0)
	call_box(rig, "CallDeck", Vector3(18.2, 18.0, 0.7), -90.0, NodePath("../Lift"), 1, 0)
	call_box(rig, "CallSurface", Vector3(24.3, LIFT_STOPS[2], 0.75), 90.0, NodePath("../Lift"), 2, 0)

	var lamp := omni(rig, "HeadframeLamp", b2g([23.25, -2.9, 38.0]), Color(0.75, 0.85, 1.0), 0.0, 9.0, false, 1.0)
	powered(lamp, 2.2, 0.0)

func call_box(parent: Node, n: String, pos: Vector3, yaw: float, lift_path: NodePath, stop: int, car_dir: int) -> void:
	var car := car_dir != 0
	var a := Area3D.new()
	a.name = n
	a.set_script(load("res://scripts/call_box.gd"))
	a.position = pos
	a.rotation_degrees = Vector3(0, yaw, 0)
	a.set("lift_path", lift_path)
	a.set("stop", stop)
	a.set("car_dir", car_dir)
	a.set("prompt_text", "Lift control")
	add(parent, a)
	add(a, inst("res://assets/props/call_box.glb", "Model"))
	box_shape(a, Vector3(0.55 if car else 0.6, 0.8, 0.6), Vector3(0, 1.15, 0))
	if not car:
		var sb := StaticBody3D.new()
		sb.name = "SolidBody"
		add(a, sb)
		box_shape(sb, Vector3(0.4, 1.45, 0.3), Vector3(0, 0.72, 0))

# ------------------------------------------------------------------ interactables
func build_interactables() -> void:
	var g := group(main_root, "Interactables")
	var lever := Area3D.new()
	lever.name = "BreakerLever"
	lever.set_script(load("res://scripts/breaker_lever.gd"))
	lever.position = b2g([71.6, 2.0, 19.0])
	lever.rotation_degrees = Vector3(0, -90, 0)
	add(g, lever)
	add(lever, inst("res://assets/props/lever.glb", "Model"))
	box_shape(lever, Vector3(1.0, 1.9, 1.0), Vector3(0, 0.95, 0))
	var lb := StaticBody3D.new()
	lb.name = "SolidBody"
	add(lever, lb)
	box_shape(lb, Vector3(0.5, 0.95, 0.4), Vector3(0, 0.47, 0))

	var valve := Area3D.new()
	valve.name = "SteamValve"
	valve.set_script(load("res://scripts/steam_valve.gd"))
	valve.position = b2g([55.0, 7.15, 19.0])
	add(g, valve)
	add(valve, inst("res://assets/props/steam_valve.glb", "Model"))
	box_shape(valve, Vector3(1.0, 1.4, 1.2), Vector3(0, 1.1, 0.2))
	var vb := StaticBody3D.new()
	vb.name = "SolidBody"
	add(valve, vb)
	box_shape(vb, Vector3(0.45, 2.1, 0.45), Vector3(0, 1.05, 0))

	var crates := [["LooseCrate", [58.0, 4.2, 13.02], 17.0], ["LooseCrate2", [33.0, 0.5, 13.02], -25.0], ["LooseCrate3", [24.5, -7.0, data["floorz"]["crate_floor"] + 0.02], 40.0]]
	var phys := PhysicsMaterial.new()
	phys.friction = 0.8
	phys.rough = true
	for c in crates:
		var rb := RigidBody3D.new()
		rb.name = c[0]
		rb.mass = 40.0
		rb.physics_material_override = phys
		rb.position = b2g(c[1])
		rb.rotation_degrees = Vector3(0, c[2], 0)
		rb.can_sleep = true
		add(g, rb)
		add(rb, inst("res://assets/props/loose_crate.glb", "Model"))
		box_shape(rb, Vector3(1.24, 1.24, 1.24), Vector3(0, 0.62, 0))
		var h := Area3D.new()
		h.name = "Handle"
		h.set_script(load("res://scripts/crate_handle.gd"))
		add(rb, h)
		box_shape(h, Vector3(1.6, 1.6, 1.6), Vector3(0, 0.62, 0))

func build_ladder() -> void:
	var l := Area3D.new()
	l.name = "MezzanineLadder"
	l.set_script(load("res://scripts/ladder.gd"))
	l.position = Vector3(12.0, 21.15, -5.975)
	l.set("climb_normal", Vector3(0, 0, 1))
	add(main_root, l)
	box_shape(l, Vector3(1.4, 6.3, 0.95), Vector3.ZERO)

func spawn_marker(parent: Node, n: String, pos: Vector3, yaw: float) -> Marker3D:
	var m := Marker3D.new()
	m.name = n
	m.position = pos
	m.rotation_degrees = Vector3(0, yaw, 0)
	m.add_to_group("spawn_point", true)
	add(parent, m)
	return m

# ------------------------------------------------------------------ surface stair gate
func build_stair_gate() -> void:
	# bolted double gate where stair 3 comes out on the surface; opens only from the surface side (-X)
	var g := Area3D.new()
	g.name = "StairGate"
	g.set_script(load("res://scripts/stair_gate.gd"))
	g.set("collapsed", true)          # v8: shut for good - the flight below has caved in
	g.position = b2g([34.25, 3.2, 34.3])
	add(main_root, g)
	add(g, inst("res://assets/props/stair_gate.glb", "Model"))
	box_shape(g, Vector3(0.7, 2.4, 3.4), Vector3(0, 1.3, 0))
	var block := StaticBody3D.new()
	block.name = "Block"
	add(g, block)
	box_shape(block, Vector3(0.24, 3.0, 3.36), Vector3(0, 1.5, 0))
	# the stairwell beside the gate posts and along its edges is closed off by invisible walls,
	# so the gate can't be jumped round from the stairs
	var guard := StaticBody3D.new()
	guard.name = "StairGuard"
	add(main_root, guard)
	box_shape(guard, Vector3(0.24, 3.0, 1.75), b2g([34.25, 0.68, 35.8]), "SideS")
	box_shape(guard, Vector3(0.24, 3.0, 1.75), b2g([34.25, 5.72, 35.8]), "SideN")
	box_shape(guard, Vector3(10.0, 2.6, 0.2), b2g([35.0, 0.15, 35.6]), "EdgeS")
	box_shape(guard, Vector3(10.0, 2.6, 0.2), b2g([35.0, 6.3, 35.6]), "EdgeN")
	# v8: fallen slabs + rubble choke the top of the flight (shared with surface.tscn; art_src/v8_collapse.py)
	add(main_root, inst("res://assets/level/collapse.glb", "Collapse"))
	# daylight down its pinholes: thin unshadowed spots along each hole's axis (they run down-east; v8_collapse.py prints them)
	var beams := group(main_root, "CollapseBeams")
	var axis := b2g([0.684, 0.0, -0.73])
	var k := 0
	for h in [[40.1, 1.8, 33.58, 3.5], [41.59, 4.585, 33.8, 4.5], [43.38, 2.39, 33.6, 3.5], [40.99, 3.27, 33.74, 3.5], [44.27, 4.73, 33.7, 3.5]]:
		var s := SpotLight3D.new()
		s.name = "Beam_%d" % k
		add(beams, s)
		s.position = b2g([h[0], h[1], h[2] + 0.4])
		s.look_at(s.position + axis, Vector3.FORWARD)
		s.light_color = Color(1.0, 0.88, 0.62)
		s.light_energy = 3.0
		s.light_volumetric_fog_energy = 6.0
		s.spot_range = 12.0
		s.spot_attenuation = 1.2
		s.spot_angle = h[3]
		k += 1

# ------------------------------------------------------------------ tunnel behind the low walkway
func build_tunnel() -> void:
	var g := group(main_root, "Tunnel")
	# emergency lamps on their own circuit: dim when the grid is dead, normal when it's live
	for p in [[0.0, -8.7, 4.0], [-8.0, -8.7, 4.0]]:
		var l := omni(g, "TunnelLamp_%d" % g.get_child_count(), b2g(p), Color(0.62, 0.74, 1.0), 1.2, 7.5, false, 1.5)
		powered(l, 1.8, 1.1)
	var exit := Area3D.new()
	exit.name = "ExitToStart"
	exit.set_script(load("res://scripts/exit_zone.gd"))
	exit.set("next_scene", "res://scenes/start.tscn")
	exit.set("target_spawn", "FromCavern")
	exit.set("once", false)
	exit.position = b2g([-10.75, -8.7, 2.8])
	add(g, exit)
	box_shape(exit, Vector3(0.8, 2.4, 1.1), Vector3.ZERO)

# ------------------------------------------------------------------ creatures
func build_creatures() -> void:
	var g := group(main_root, "Creatures")
	var sc := group(g, "Scuttlers")
	var homes := [
		[[30, -4, 0], 6.0], [[42, 4, 0], 6.0], [[56, -6, 0], 6.0], [[68, 3, 0], 6.0], [[25, 10, 0], 4.0],
		[[48, 11, 0], 4.0], [[72, -8, 0], 4.0], [[36, -9, 0], 4.0], [[6, -7.5, 1.6], 3.0], [[8, 3, 18], 4.0],
		[[32, 2, 13], 4.0], [[57, 1, 13], 4.0], [[67, 2, 19], 3.0], [[52, 4.5, 25], 4.0], [[8, 7.6, 23.5], 3.0],
		[[45, -2, 0], 5.0], [[62, -2, 13], 3.0]]
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234
	var i := 0
	for h in homes:
		var c := CharacterBody3D.new()
		c.name = "Scuttler_%02d" % i
		c.set_script(load("res://scripts/creatures/scuttler.gd"))
		var s := rng.randf_range(0.7, 1.25)
		c.set("home", b2g(h[0]))
		c.set("roam_radius", h[1])
		c.set("model_scale", s)
		c.set("walk_speed", rng.randf_range(0.9, 1.4))
		c.position = b2g(h[0]) + Vector3(rng.randf_range(-1, 1), 0.35, rng.randf_range(-1, 1))
		add(sc, c)
		add(c, inst("res://assets/creatures/scuttler.glb", "Model"))
		var cs := CollisionShape3D.new()
		cs.name = "CollisionShape3D"
		var sph := SphereShape3D.new()
		sph.radius = 0.3 * s
		cs.shape = sph
		cs.position = Vector3(0, 0.3 * s, 0)
		add(c, cs)
		i += 1

	var mg := group(g, "Moths")
	i = 0
	for a in [[5, 4, 21], [21, 6, 9], [34, -2, 8], [48, -6, 6], [62, 10, 8], [73, -3, 10], [28, 12, 19], [56, 3, 28], [10, -7, 5], [40, 5, 17]]:
		var m := Node3D.new()
		m.name = "Moth_%02d" % i
		m.set_script(load("res://scripts/creatures/moth.gd"))
		m.set("anchor", b2g(a))
		m.set("radius", rng.randf_range(2.0, 4.0))
		m.set("speed", rng.randf_range(0.25, 0.45))
		m.position = b2g(a)
		add(mg, m)
		var model := inst("res://assets/creatures/moth.glb", "Model")
		model.scale = Vector3.ONE * 1.4
		add(m, model)
		omni(m, "Glow", Vector3.ZERO, Color(0.45, 0.75, 1.0), 0.9, 4.5, false, 2.5)
		i += 1

	var wg := group(g, "Watchers")
	i = 0
	var mounts := [[[37.2, 2.4, 25.0], false, 60.0], [[35, -0.8, 12.2], true, 0.0], [[2.5, 8.3, 23.5], false, -40.0],
		[[72.45, 2.0, 21.3], false, 90.0], [[60, 5, 12.85], true, 30.0], [[56, -7.5, data["floorz"]["w6"]], false, 150.0],
		[[50, 4.5, 24.2], true, -60.0]]
	for mnt in mounts:
		var w := Node3D.new()
		w.name = "Watcher_%02d" % i
		w.set_script(load("res://scripts/creatures/watcher.gd"))
		w.position = b2g(mnt[0])
		w.rotation_degrees = Vector3(0, mnt[2], 180.0 if mnt[1] else 0.0)
		add(wg, w)
		add(w, inst("res://assets/creatures/watcher.glb", "Model"))
		i += 1

# ------------------------------------------------------------------ particles
func radial_tex() -> GradientTexture2D:
	if _radial:
		return _radial
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.3, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.45), Color(1, 1, 1, 0)])
	_radial = GradientTexture2D.new()
	_radial.gradient = g
	_radial.fill = GradientTexture2D.FILL_RADIAL
	_radial.fill_from = Vector2(0.5, 0.5)
	_radial.fill_to = Vector2(1.0, 0.5)
	_radial.width = 64
	_radial.height = 64
	return _radial

func ring_tex() -> GradientTexture2D:
	if _ring:
		return _ring
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.6, 0.78, 0.95, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 0), Color(1, 1, 1, 0)])
	_ring = GradientTexture2D.new()
	_ring.gradient = g
	_ring.fill = GradientTexture2D.FILL_RADIAL
	_ring.fill_from = Vector2(0.5, 0.5)
	_ring.fill_to = Vector2(1.0, 0.5)
	_ring.width = 64
	_ring.height = 64
	return _ring

func fade_ramp(peak := 1.0) -> GradientTexture1D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.2, 0.7, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, peak), Color(1, 1, 1, peak), Color(1, 1, 1, 0)])
	var t := GradientTexture1D.new()
	t.gradient = g
	return t

func scale_curve(a: float, b: float) -> CurveTexture:
	var c := Curve.new()
	c.max_value = maxf(1.0, maxf(a, b))
	c.add_point(Vector2(0, a))
	c.add_point(Vector2(1, b))
	var t := CurveTexture.new()
	t.curve = c
	return t

func pmat(color: Color, emission: float, additive := false, tex: Texture2D = null, bb := BaseMaterial3D.BILLBOARD_PARTICLES) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if additive:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = bb
	m.billboard_keep_scale = true
	m.vertex_color_use_as_albedo = true
	m.albedo_color = color
	m.albedo_texture = tex if tex else radial_tex()
	m.roughness = 1.0
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if emission > 0.0:
		m.emission_enabled = true
		m.emission = Color(color.r, color.g, color.b)
		m.emission_energy_multiplier = emission
	return m

func quad(size: Vector2, mat: Material) -> QuadMesh:
	var q := QuadMesh.new()
	q.size = size
	q.material = mat
	return q

func emitter(parent: Node, n: String, pos: Vector3, amount: int, lifetime: float, pm: ParticleProcessMaterial, mesh: Mesh, aabb_min: Vector3, aabb_size: Vector3) -> GPUParticles3D:
	var e := GPUParticles3D.new()
	e.name = n
	e.position = pos
	e.amount = amount
	e.lifetime = lifetime
	e.preprocess = lifetime
	e.process_material = pm
	e.draw_pass_1 = mesh
	e.visibility_aabb = AABB(aabb_min, aabb_size)
	e.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add(parent, e)
	return e

func sparks(parent: Node, n: String, pos: Vector3) -> GPUParticles3D:
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, -1, 0)
	pm.spread = 75.0
	pm.initial_velocity_min = 1.2
	pm.initial_velocity_max = 3.5
	pm.gravity = Vector3(0, -9.8, 0)
	pm.scale_min = 0.6
	pm.scale_max = 1.2
	pm.particle_flag_align_y = true
	pm.color_ramp = fade_ramp(1.0)
	var e := emitter(parent, n, pos, 26, 0.8, pm, quad(Vector2(0.015, 0.08), pmat(Color(0.75, 0.9, 1.0, 1.0), 9.0, true)), Vector3(-3, -6, -3), Vector3(6, 7, 6))
	e.one_shot = true
	e.explosiveness = 0.95
	e.emitting = false
	e.preprocess = 0.0
	return e

func build_particles() -> void:
	var g := group(main_root, "Particles")
	# ---- floating dust through the cavern
	var dust_mat := pmat(Color(0.72, 0.78, 1.0, 0.5), 0.12)
	var dg := group(g, "Dust")
	var k := 0
	for cxz in [[10.0, -2.0], [30.0, -2.0], [50.0, -2.0], [68.0, -2.0]]:
		var pm := ParticleProcessMaterial.new()
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		pm.emission_box_extents = Vector3(10, 14, 13)
		pm.direction = Vector3(0, 1, 0)
		pm.spread = 180.0
		pm.initial_velocity_min = 0.0
		pm.initial_velocity_max = 0.06
		pm.gravity = Vector3(0, -0.015, 0)
		pm.turbulence_enabled = true
		pm.turbulence_noise_strength = 1.0
		pm.turbulence_noise_scale = 6.0
		pm.turbulence_influence_min = 0.02
		pm.turbulence_influence_max = 0.07
		pm.scale_min = 0.5
		pm.scale_max = 1.5
		pm.color_ramp = fade_ramp(1.0)
		emitter(dg, "Dust_%d" % k, Vector3(cxz[0], 14.5, cxz[1]), 900, 16.0, pm, quad(Vector2(0.04, 0.04), dust_mat), Vector3(-11, -15, -14), Vector3(22, 30, 28))
		k += 1
	# ---- motes hanging in the daylight shaft under the exit
	var spm := ParticleProcessMaterial.new()
	spm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	spm.emission_box_extents = Vector3(8.5, 5.5, 4.5)
	spm.spread = 180.0
	spm.initial_velocity_max = 0.05
	spm.gravity = Vector3(0, -0.01, 0)
	spm.turbulence_enabled = true
	spm.turbulence_influence_max = 0.06
	spm.scale_min = 0.4
	spm.scale_max = 1.3
	spm.color_ramp = fade_ramp(1.0)
	emitter(g, "SunShaftMotes", b2g([38.5, 4, 28.0]), 700, 14.0, spm, quad(Vector2(0.03, 0.03), pmat(Color(1.0, 0.97, 0.9, 0.7), 0.03)), Vector3(-10, -7, -6), Vector3(20, 14, 12))
	# ---- glowing spores rising from the foliage
	var sg := group(g, "Spores")
	var spore_mesh := quad(Vector2(0.05, 0.05), pmat(Color(0.35, 0.6, 1.0, 0.9), 5.0, true))
	k = 0
	for d in data["foliage_lights"]:
		var pm2 := ParticleProcessMaterial.new()
		pm2.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		pm2.emission_sphere_radius = 1.1
		pm2.direction = Vector3(0, 1, 0)
		pm2.spread = 60.0
		pm2.initial_velocity_min = 0.05
		pm2.initial_velocity_max = 0.2
		pm2.gravity = Vector3(0, 0.02, 0)
		pm2.turbulence_enabled = true
		pm2.turbulence_noise_strength = 0.8
		pm2.turbulence_influence_max = 0.1
		pm2.scale_min = 0.5
		pm2.scale_max = 1.3
		pm2.color_ramp = fade_ramp(1.0)
		emitter(sg, "Spores_%02d" % k, b2g(d["pos"]), 16, 7.0, pm2, spore_mesh, Vector3(-3, -2, -3), Vector3(6, 6, 6))
		k += 1
	# ---- drips into the puddles + ripples
	var wg := group(g, "Drips")
	var drip_mesh := quad(Vector2(0.012, 0.16), pmat(Color(0.6, 0.75, 1.0, 0.7), 1.2, false, null, BaseMaterial3D.BILLBOARD_FIXED_Y))
	var ring_mesh := PlaneMesh.new()
	ring_mesh.size = Vector2(1, 1)
	ring_mesh.material = pmat(Color(0.6, 0.75, 1.0, 0.55), 0.5, false, ring_tex(), BaseMaterial3D.BILLBOARD_DISABLED)
	k = 0
	for p in data["puddles"]:
		var surf := b2g(p)
		var top := 27.5
		var fall := top - surf.y
		var life := sqrt(2.0 * fall / 9.8)
		var pm3 := ParticleProcessMaterial.new()
		pm3.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		pm3.emission_box_extents = Vector3(0.3, 0.05, 0.3)
		pm3.direction = Vector3(0, -1, 0)
		pm3.spread = 0.0
		pm3.initial_velocity_min = 0.0
		pm3.initial_velocity_max = 0.1
		pm3.gravity = Vector3(0, -9.8, 0)
		var e := emitter(wg, "Drip_%02d" % k, Vector3(surf.x, top, surf.z), 3, life, pm3, drip_mesh, Vector3(-1, -fall - 1, -1), Vector3(2, fall + 2, 2))
		e.randomness = 0.6
		var pm4 := ParticleProcessMaterial.new()
		pm4.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		pm4.emission_box_extents = Vector3(0.35, 0.0, 0.35)
		pm4.gravity = Vector3.ZERO
		pm4.initial_velocity_max = 0.0
		pm4.scale_curve = scale_curve(0.05, 1.1)
		pm4.color_ramp = fade_ramp(1.0)
		var r := emitter(wg, "Ripple_%02d" % k, surf + Vector3(0, 0.012, 0), 3, 1.4, pm4, ring_mesh, Vector3(-1.5, -0.2, -1.5), Vector3(3, 0.4, 3))
		r.randomness = 0.6
		k += 1
	# ---- grit trickling from ceiling cracks
	var tg := group(g, "Trickles")
	var grit := quad(Vector2(0.02, 0.02), pmat(Color(0.8, 0.76, 0.7, 0.85), 0.1))
	k = 0
	for p in [[30.6, 2.5, 29.3], [46.4, 5.5, 30.2], [9, -1, 26.3], [61, 9.5, 30], [70, -6, 29]]:
		var pm5 := ParticleProcessMaterial.new()
		pm5.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		pm5.emission_box_extents = Vector3(0.15, 0.02, 0.15)
		pm5.direction = Vector3(0, -1, 0)
		pm5.spread = 4.0
		pm5.initial_velocity_max = 0.3
		pm5.gravity = Vector3(0, -9.8, 0)
		pm5.scale_min = 0.5
		pm5.scale_max = 1.2
		emitter(tg, "Trickle_%d" % k, b2g(p), 55, 2.6, pm5, grit, Vector3(-1, -34, -1), Vector3(2, 35, 2))
		k += 1
	# ---- steam vents (toggled by the valve)
	var vg := group(g, "SteamVents")
	var steam_mesh := quad(Vector2(0.95, 0.95), pmat(Color(0.74, 0.8, 0.97, 0.75), 0.45))
	k = 0
	for v in [[[48, 8.68, 20.6], [0, -1, 0.25]], [[61, 8.9, 21.65], [0.2, 0, 1]], [[33, 8.35, 14.4], [0, -1, 0.1]],
			[[40, 15.85, 2.6], [0, -1, 0.3]], [[66, 15.95, 3.3], [0, -1, 0.2]], [[55, 8.6, 21.05], [0, -0.3, 1]]]:
		var pm6 := ParticleProcessMaterial.new()
		pm6.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		pm6.emission_sphere_radius = 0.05
		pm6.direction = b2g(v[1]).normalized()
		pm6.spread = 12.0
		pm6.initial_velocity_min = 1.8
		pm6.initial_velocity_max = 2.8
		pm6.gravity = Vector3(0, 0.5, 0)
		pm6.damping_min = 1.0
		pm6.damping_max = 1.6
		pm6.angle_min = -180.0
		pm6.angle_max = 180.0
		pm6.scale_min = 0.5
		pm6.scale_max = 0.9
		pm6.scale_curve = scale_curve(0.25, 2.4)
		pm6.color_ramp = fade_ramp(0.55)
		pm6.turbulence_enabled = true
		pm6.turbulence_noise_strength = 0.6
		pm6.turbulence_influence_max = 0.08
		var e2 := emitter(vg, "Steam_%d" % k, b2g(v[0]), 52, 2.4, pm6, steam_mesh, Vector3(-4, -3, -4), Vector3(8, 8, 8))
		e2.add_to_group("steam_vents", true)
		k += 1

# ------------------------------------------------------------------ player scene
func build_player() -> PackedScene:
	var p := CharacterBody3D.new()
	p.name = "Player"
	p.set_script(load("res://scripts/player.gd"))
	p.add_to_group("player", true)
	p.floor_snap_length = 0.45
	p.floor_max_angle = deg_to_rad(46.0)
	var col := CollisionShape3D.new()
	col.name = "CollisionShape3D"
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.8
	col.shape = cap
	col.position = Vector3(0, 0.9, 0)
	add(p, col, p)
	var head := Node3D.new()
	head.name = "Head"
	head.position = Vector3(0, 1.62, 0)
	add(p, head, p)
	var cam := Camera3D.new()
	cam.name = "Camera3D"
	cam.fov = 75.0
	cam.near = 0.05
	cam.far = 500.0
	cam.current = true
	var attrs := CameraAttributesPractical.new()
	attrs.dof_blur_near_enabled = true
	attrs.dof_blur_near_distance = 0.35     # (was 0.9: that blurred the held shaft)
	attrs.dof_blur_near_transition = 0.3
	attrs.dof_blur_amount = 0.08
	cam.attributes = attrs
	add(head, cam, p)
	var ray := RayCast3D.new()
	ray.name = "InteractRay"
	ray.target_position = Vector3(0, 0, -2.6)
	ray.collide_with_areas = true
	ray.collide_with_bodies = true
	add(cam, ray, p)
	var lantern := OmniLight3D.new()
	lantern.name = "Lantern"
	lantern.position = Vector3(0.25, -0.25, -0.1)
	lantern.light_color = Color(0.62, 0.72, 1.0)
	lantern.light_energy = 0.6
	lantern.omni_range = 7.0
	lantern.visible = false
	lantern.light_volumetric_fog_energy = 0.4
	add(head, lantern, p)

	var hud := CanvasLayer.new()
	hud.name = "HUD"
	add(p, hud, p)
	var vig := ColorRect.new()
	vig.name = "Vignette"
	vig.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = load("res://scripts/vignette.gdshader")
	vig.material = mat
	add(hud, vig, p)
	var cross := ColorRect.new()
	cross.name = "Crosshair"
	cross.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	cross.offset_left = -2
	cross.offset_right = 2
	cross.offset_top = -2
	cross.offset_bottom = 2
	cross.color = Color(0.75, 0.8, 1.0, 0.45)
	cross.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add(hud, cross, p)
	var prompt := Label.new()
	prompt.name = "Prompt"
	prompt.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	prompt.offset_left = -400
	prompt.offset_right = 400
	prompt.offset_top = -205
	prompt.offset_bottom = -165
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.add_theme_color_override("font_color", Color(0.78, 0.84, 1.0))
	prompt.add_theme_font_size_override("font_size", 22)
	add(hud, prompt, p)
	var toast := Label.new()
	toast.name = "Toast"
	toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	toast.offset_left = -500
	toast.offset_right = 500
	toast.offset_top = -158
	toast.offset_bottom = -123
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.add_theme_color_override("font_color", Color(0.9, 0.9, 0.95))
	toast.add_theme_font_size_override("font_size", 19)
	add(hud, toast, p)
	var banner := Label.new()
	banner.name = "Banner"
	banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	banner.offset_left = -500
	banner.offset_right = 500
	banner.offset_top = -120
	banner.offset_bottom = 0
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.add_theme_color_override("font_color", Color(0.95, 0.92, 0.85))
	banner.add_theme_font_size_override("font_size", 42)
	add(hud, banner, p)
	# health: segmented semicircle at the bottom centre (scripts/health_arc.gd)
	var hp := Control.new()
	hp.name = "HealthArc"
	hp.set_script(load("res://scripts/health_arc.gd"))
	hp.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	hp.offset_left = -120
	hp.offset_right = 120
	hp.offset_top = -126
	hp.offset_bottom = -14
	hp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add(hud, hp, p)
	var hurt := ColorRect.new()   # red flash when hurt (player.gd take_damage)
	hurt.name = "HurtFlash"
	hurt.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hurt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hurt.color = Color(0.55, 0.05, 0.08, 0.0)
	add(hud, hurt, p)
	var fade := ColorRect.new()   # scene transitions / death fades (player.gd fade_in/fade_out)
	fade.name = "Fade"
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade.color = Color(0, 0, 0, 0)
	add(hud, fade, p)

	var ps := PackedScene.new()
	ps.pack(p)
	p.free()
	return ps
