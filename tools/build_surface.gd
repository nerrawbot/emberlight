extends SceneTree
## Builds res://scenes/surface.tscn: the mesa above the cavern, in warm yellow haze.
## Geometry: assets/level/surface.glb (art_src/v5_surface.py, Blender scene "Surface5"); layout numbers come from
## art_src/surface.json (Blender coords, converted with b2g()). Shares main.tscn's frame around the lift + stair gate.
## Run headless:  godot --headless --path . --script res://tools/build_surface.gd
## NOTE: overwrites scenes/surface.tscn.

var main_root: Node3D
var L: Dictionary
var _radial: GradientTexture2D

const G := 34.3
const LIFT_X := 20.7
const LIFT_Z := 2.9          # Godot z of the car centre (Blender y -2.9)

func b2g(v) -> Vector3:
	return Vector3(v[0], v[2], -v[1])

func add(parent: Node, child: Node) -> Node:
	parent.add_child(child)
	child.owner = main_root
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
	L = JSON.parse_string(FileAccess.get_file_as_string("res://art_src/surface.json"))["layout"]
	main_root = Node3D.new()
	main_root.name = "Surface"

	var intro := Node.new()          # power_grid.gd doubles as the arrival banner (nothing here needs power)
	intro.name = "PowerGrid"
	intro.set_script(load("res://scripts/power_grid.gd"))
	intro.set("intro_text", "THE COMPLEX\nthe old works on the mesa")
	add(main_root, intro)

	var level := inst("res://assets/level/surface.glb", "Level")
	add(main_root, level)
	# without this, pack() drops every change made to nodes inside the glb (material overrides, cast_shadow below)
	main_root.set_editable_instance(level, true)
	build_environment()
	build_lift()
	build_stairs()
	build_safety()
	build_particles()
	build_exits_and_spawns()
	build_peak()

	var ps := PackedScene.new()
	ps.pack(main_root)
	print("surface saved: ", ResourceSaver.save(ps, "res://scenes/surface.tscn"))
	main_root.free()
	quit()

# ------------------------------------------------------------------ warm haze, low sun, cool shadows
func build_environment() -> void:
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.82, 0.80, 0.74)
	sm.sky_horizon_color = Color(0.96, 0.93, 0.84)
	sm.sky_curve = 0.12
	sm.ground_horizon_color = Color(0.93, 0.9, 0.82)
	sm.ground_bottom_color = Color(0.66, 0.63, 0.57)
	sm.sun_angle_max = 40.0
	sm.sun_curve = 0.08
	sky.sky_material = sm
	env.sky = sky
	# shadows stay dark blue (the mesa's own colour); everything the sun touches goes gold
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.27, 0.3, 0.46)
	env.ambient_light_energy = 1.25
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.05
	env.tonemap_white = 6.0
	env.ssao_enabled = true
	env.ssao_radius = 2.0
	env.ssao_intensity = 2.0
	env.glow_enabled = true
	env.glow_intensity = 0.5
	env.glow_strength = 1.0
	env.glow_bloom = 0.08
	env.glow_hdr_threshold = 1.2
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	# distance haze: layers the spires into paler and paler silhouettes; the valley below is a sea of it
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.fog_light_color = Color(0.93, 0.9, 0.81)
	env.fog_light_energy = 1.0
	env.fog_sun_scatter = 0.15
	env.fog_density = 0.0032
	env.fog_aerial_perspective = 0.2
	env.fog_sky_affect = 0.55
	env.fog_height = 26.0
	env.fog_height_density = 0.06
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.002      # thin: near haze lit by the sun turned the blue rock tan
	env.volumetric_fog_albedo = Color(0.94, 0.92, 0.85)
	env.volumetric_fog_emission = Color(0.026, 0.025, 0.021)
	env.volumetric_fog_emission_energy = 1.0
	env.volumetric_fog_anisotropy = 0.35
	env.volumetric_fog_length = 110.0
	env.volumetric_fog_ambient_inject = 0.15
	env.volumetric_fog_sky_affect = 0.0
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.1
	env.adjustment_saturation = 0.92
	we.environment = env
	add(main_root, we)

	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-24, 55, 0)       # low in the east-south-east, behind the works from the landing
	sun.light_color = Color(1.0, 0.703, 0.19)          # deep gold (tuned by hand in the editor)
	sun.light_energy = 2.3
	sun.light_volumetric_fog_energy = 2.0
	sun.light_angular_distance = 1.0
	sun.shadow_enabled = true
	sun.shadow_blur = 1.2
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 150.0
	sun.shadow_caster_mask = 1
	add(main_root, sun)
	# warm bounce from the sunlit haze on the side away from the sun (keeps the shadow side from going flat)
	var bounce := DirectionalLight3D.new()
	bounce.name = "HazeBounce"
	bounce.rotation_degrees = Vector3(-10, -125, 0)
	bounce.light_color = Color(0.6, 0.64, 0.82)
	bounce.light_energy = 0.3
	bounce.light_volumetric_fog_energy = 0.0
	bounce.shadow_enabled = false
	bounce.light_specular = 0.1
	add(main_root, bounce)

	var lvl := main_root.get_node("Level")
	# invisible stair ramps + 1.8 m edge guards: layer 16 only. The player and tripods collide with it (mask 1|16), but
	# enemy sight lines and bolts (mask 1) pass through walls nobody can see.
	for b in lvl.find_children("S5_Ramps*", "StaticBody3D", true, false):
		(b as StaticBody3D).collision_layer = 16
	# spires and grass: far or tiny, so no shadow casting (the sun's shadow is the main frame cost)
	for n in ["S5_Spires", "S5_Grass", "S5_Ivy", "S5_Shrubs"]:      # (v8: ivy + shrubs too; the trees keep theirs)
		var mi := lvl.find_child(n, true, false) as GeometryInstance3D
		if mi:
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# the mesa rock: one terrain shader for every surface (ground, cliffs, the pinnacle, outcrops). It blends six graded
	# layers by the TerrainMask vertex colour + slope, and keeps specular low (a dark, rough surface mostly reflects the
	# bright cream sky at grazing angles, which turned the blue ground brown).
	var mesa := lvl.find_child("S5_Mesa*", true, false) as MeshInstance3D
	if mesa:
		var tm := mesa_material()
		for s in mesa.mesh.get_surface_count():
			mesa.set_surface_override_material(s, tm)

var _mesa_mat: ShaderMaterial

func mesa_material() -> ShaderMaterial:
	if _mesa_mat:
		return _mesa_mat
	_mesa_mat = ShaderMaterial.new()
	_mesa_mat.shader = load("res://scripts/mesa_terrain.gdshader")
	for layer in ["ground", "gravel", "dirt", "moss", "cliff", "cliff2"]:
		for k in [["alb", "albedo"], ["nrm", "normal"], ["orm", "orm"]]:
			_mesa_mat.set_shader_parameter("%s_%s" % [layer, k[0]], load("res://assets/tex/mesa_%s_%s.jpg" % [layer, k[1]]))
	return _mesa_mat

# ------------------------------------------------------------------ lift car parked at the top + headframe sheave
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

func build_lift() -> void:
	var rig := group(main_root, "LiftRig")
	var sheave_pos := b2g([20.7, -4.05, 41.6])
	var sheave := inst("res://assets/props/sheave.glb", "Sheave")
	sheave.position = sheave_pos
	add(rig, sheave)
	var cable := MeshInstance3D.new()
	cable.name = "LiftCable"
	cable.mesh = cable_mesh()
	var bottom := G + 3.25
	cable.position = Vector3(LIFT_X, (sheave_pos.y + bottom) * 0.5, LIFT_Z)
	cable.scale = Vector3(1, sheave_pos.y - bottom, 1)
	add(rig, cable)
	var car := AnimatableBody3D.new()
	car.name = "Car"
	car.set_script(load("res://scripts/surface_car.gd"))
	car.position = Vector3(LIFT_X, G, LIFT_Z)
	car.set("cable_path", NodePath("../LiftCable"))
	car.set("pulley_y", sheave_pos.y)
	add(rig, car)
	add(car, inst("res://assets/props/lift_car.glb", "Model"))
	box_shape(car, Vector3(3.0, 0.18, 3.0), Vector3(0, -0.09, 0), "Floor")
	box_shape(car, Vector3(3.0, 1.1, 0.1), Vector3(0, 0.55, -1.45), "RailN")
	box_shape(car, Vector3(3.0, 1.1, 0.1), Vector3(0, 0.55, 1.45), "RailS")
	box_shape(car, Vector3(0.6, 1.0, 0.35), Vector3(1.05, 0.5, -1.225), "Ctrl")
	for d in [[1, "CarUp", Vector3(-1.05, 0, -1.15)], [-1, "CarDown", Vector3(-0.42, 0, -1.15)]]:
		var a := Area3D.new()
		a.name = d[1]
		a.set_script(load("res://scripts/surface_lift.gd"))
		a.position = d[2]
		a.set("car_dir", d[0])
		a.set("car_path", NodePath(".."))
		add(car, a)
		add(a, inst("res://assets/props/call_box.glb", "Model"))
		box_shape(a, Vector3(0.55, 0.8, 0.6), Vector3(0, 1.15, 0))
	var lamp := OmniLight3D.new()
	lamp.name = "CarLamp"
	lamp.position = Vector3(0, 2.6, 0)
	lamp.light_color = Color(0.75, 0.85, 1.0)
	lamp.light_energy = 0.8
	lamp.omni_range = 4.0
	add(car, lamp)
	# the landing boom stands open (the car is here)
	var gate := Node3D.new()
	gate.name = "SurfaceGateOpen"
	gate.position = Vector3(23.25, G + 1.0, 1.25)
	add(rig, gate)
	var hz := StandardMaterial3D.new()
	hz.albedo_texture = load("res://assets/tex/hazard_albedo.jpg")
	hz.roughness = 0.85
	hz.uv1_scale = Vector3(1, 6, 1)
	var post := MeshInstance3D.new()
	post.name = "Post"
	var pm := BoxMesh.new()
	pm.size = Vector3(0.18, 1.1, 0.18)
	pm.material = hz
	post.mesh = pm
	post.position = Vector3(0, -0.45, -0.1)
	add(gate, post)
	var bar := MeshInstance3D.new()
	bar.name = "Bar"
	var bm := BoxMesh.new()
	bm.size = Vector3(0.09, 0.12, 3.1)
	bm.material = hz
	bar.mesh = bm
	bar.rotation.x = -1.35
	bar.position = Vector3(0, 1.55 * sin(1.35), 1.55 * cos(1.35))
	add(gate, bar)

# ------------------------------------------------------------------ stair 3 head: the gate (shut for good) + guards round the well
func build_stairs() -> void:
	# v8: the well is choked by the collapse a metre below grade (shared with main.tscn; art_src/v8_collapse.py)
	add(main_root, inst("res://assets/level/collapse.glb", "Collapse"))
	var glow := OmniLight3D.new()        # the dark stairwell under it, faintly lit, seen through the pinholes
	glow.name = "CollapseGlow"
	glow.position = b2g([42.0, 3.2, 29.0])
	glow.light_color = Color(0.45, 0.58, 1.0)
	glow.light_energy = 0.7
	glow.omni_range = 7.5
	glow.light_volumetric_fog_energy = 0.0
	glow.shadow_enabled = false
	add(main_root, glow)
	var g := Area3D.new()
	g.name = "StairGate"
	g.set_script(load("res://scripts/stair_gate.gd"))
	g.set("collapsed", true)
	g.position = b2g([34.25, 3.2, G])
	add(main_root, g)
	add(g, inst("res://assets/props/stair_gate.glb", "Model"))
	box_shape(g, Vector3(0.7, 2.4, 3.4), Vector3(0, 1.3, 0))
	var block := StaticBody3D.new()
	block.name = "Block"
	add(g, block)
	box_shape(block, Vector3(0.24, 3.0, 3.36), Vector3(0, 1.5, 0))
	var pit: Array = L["pit"]
	var guard := StaticBody3D.new()
	guard.name = "StairGuard"
	add(main_root, guard)
	box_shape(guard, Vector3(0.24, 3.0, 1.75), b2g([34.25, pit[2], G + 1.5]), "SideS")
	box_shape(guard, Vector3(0.24, 3.0, 1.75), b2g([34.25, pit[3], G + 1.5]), "SideN")
	var ln: float = pit[1] - pit[0] + 0.6
	box_shape(guard, Vector3(ln, 1.6, 0.2), b2g([(pit[0] + pit[1]) * 0.5 + 0.3, pit[2] - 0.3, G + 0.8]), "EdgeS")
	box_shape(guard, Vector3(ln, 1.6, 0.2), b2g([(pit[0] + pit[1]) * 0.5 + 0.3, pit[3] + 0.3, G + 0.8]), "EdgeN")
	box_shape(guard, Vector3(0.2, 1.6, pit[3] - pit[2] + 0.6), b2g([pit[1] + 0.3, (pit[2] + pit[3]) * 0.5, G + 0.8]), "EdgeE")

# ------------------------------------------------------------------ the edge: haze below, checkpoints
func build_safety() -> void:
	var g := group(main_root, "Safety")
	var k := Area3D.new()
	k.name = "TheDrop"
	k.set_script(load("res://scripts/kill_zone.gd"))
	k.set("message", "The haze swallows you...")
	k.position = Vector3(32, 12.0, 6)
	add(g, k)
	box_shape(k, Vector3(600, 4.0, 600), Vector3.ZERO)
	var cps := [["CP_Gallery", [56.0, 16.0, 40.0], 180.0, Vector3(5.0, 2.5, 4.0)],
		["CP_Lookout", [58.0, -30.0, 46.0], 0.0, Vector3(4.0, 2.5, 3.0)],
		["CP_Pinnacle", [68.0, -59.5, 46.0], -90.0, Vector3(6.0, 2.5, 6.0)],      # facing bridge 2
		["CP_Silo", [92.0, -55.0, 46.0], 0.0, Vector3(8.0, 2.5, 6.0)]]            # facing the silo stair
	for c in cps:
		var a := Area3D.new()
		a.name = c[0]
		a.set_script(load("res://scripts/checkpoint.gd"))
		a.position = b2g(c[1]) + Vector3(0, 0.05, 0)
		a.rotation_degrees = Vector3(0, c[2], 0)
		add(g, a)
		box_shape(a, c[3], Vector3(0, 1.25, 0))

# ------------------------------------------------------------------ particles: warm motes drifting in the sun
func radial_tex() -> GradientTexture2D:
	if _radial:
		return _radial
	var gr := Gradient.new()
	gr.offsets = PackedFloat32Array([0.0, 0.3, 1.0])
	gr.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.45), Color(1, 1, 1, 0)])
	_radial = GradientTexture2D.new()
	_radial.gradient = gr
	_radial.fill = GradientTexture2D.FILL_RADIAL
	_radial.fill_from = Vector2(0.5, 0.5)
	_radial.fill_to = Vector2(1.0, 0.5)
	_radial.width = 64
	_radial.height = 64
	return _radial

func build_particles() -> void:
	var g := group(main_root, "Particles")
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.billboard_keep_scale = true
	m.vertex_color_use_as_albedo = true
	m.albedo_color = Color(1.0, 0.92, 0.72, 0.6)
	m.albedo_texture = radial_tex()
	m.emission_enabled = true
	m.emission = Color(1.0, 0.85, 0.6)
	m.emission_energy_multiplier = 0.3
	var q := QuadMesh.new()
	q.size = Vector2(0.05, 0.05)
	q.material = m
	var gr := Gradient.new()
	gr.offsets = PackedFloat32Array([0.0, 0.2, 0.7, 1.0])
	gr.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	var ramp := GradientTexture1D.new()
	ramp.gradient = gr
	var k := 0
	for c in [[30.0, -3.0], [55.0, 5.0], [58.0, -22.0], [80.0, -50.0]]:
		var pm := ParticleProcessMaterial.new()
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		pm.emission_box_extents = Vector3(14, 6, 14)
		pm.direction = Vector3(-1, 0.2, 0)
		pm.spread = 40.0
		pm.initial_velocity_min = 0.2
		pm.initial_velocity_max = 0.6
		pm.gravity = Vector3(0, -0.01, 0)
		pm.turbulence_enabled = true
		pm.turbulence_influence_max = 0.08
		pm.scale_min = 0.5
		pm.scale_max = 1.6
		pm.color_ramp = ramp
		var e := GPUParticles3D.new()
		e.name = "Motes_%d" % k
		e.position = b2g([c[0], c[1], G + 4.0])
		e.amount = 700
		e.lifetime = 14.0
		e.preprocess = 14.0
		e.process_material = pm
		e.draw_pass_1 = q
		e.visibility_aabb = AABB(Vector3(-20, -8, -20), Vector3(40, 16, 40))
		e.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		e.layers = 2
		add(g, e)
		k += 1

# ------------------------------------------------------------------ exits, spawns, player
func spawn_marker(parent: Node, n: String, pos: Vector3, yaw: float) -> Marker3D:
	var m := Marker3D.new()
	m.name = n
	m.position = pos
	m.rotation_degrees = Vector3(0, yaw, 0)
	m.add_to_group("spawn_point", true)
	add(parent, m)
	return m

func build_exits_and_spawns() -> void:
	# (v8: stair 3 no longer links to the cavern - it has caved in; the lift is the only way)
	# the silo roof, past the cove and the pinnacle: end of the line (for now)
	var end := Area3D.new()
	end.name = "Lookout"
	end.set_script(load("res://scripts/exit_zone.gd"))
	end.set("message", "THE COMPLEX\n— to be continued —")
	var lk: Array = L["lookout"]
	end.position = b2g([lk[0], lk[1], lk[2] + 1.2])
	add(main_root, end)
	box_shape(end, Vector3(8.0, 2.4, 4.0), Vector3.ZERO)

	# v9: the broken warden drone on the K-tower's top deck, east of the stair 2 -> gantry walk (x 57..59)
	var drone := Area3D.new()
	drone.name = "DronePickup"
	drone.set_script(load("res://scripts/drone_pickup.gd"))
	drone.position = b2g([60.0, -9.9, 46.0])
	drone.rotation_degrees = Vector3(0, 35.0, 0)
	add(main_root, drone)
	add(drone, inst("res://assets/props/drone.glb", "Model"))
	box_shape(drone, Vector3(0.9, 0.6, 0.9), Vector3(0, 0.25, 0))

	var spawns := group(main_root, "Spawns")
	var from_lift := spawn_marker(spawns, "FromLift", b2g([24.0, -2.9, G + 0.02]), -90.0)    # stepping off the car, facing east
	from_lift.add_to_group("respawn_point", true)       # blacking out (health 0) brings you round here
	# hostiles: tripods + skates turn up at random round the player (none near the lift)
	var enemies := Node3D.new()
	enemies.name = "Enemies"
	enemies.set_script(load("res://scripts/enemy_spawner.gd"))
	add(main_root, enemies)
	var player: Node3D = load("res://scenes/player.tscn").instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	player.name = "Player"
	player.transform = from_lift.transform
	player.set("max_safe_fall", 6.0)
	add(main_root, player)
	var cam := player.get_node("Head/Camera3D") as Camera3D
	cam.far = 1600.0          # the spires stand up to ~550 m out

	var tour := Node.new()
	tour.name = "ShotTour"
	tour.set_script(load("res://scripts/shot_tour.gd"))
	add(main_root, tour)

# ------------------------------------------------------------------ v10: the Peak (the boss hall) + the radio mast
## Geometry: assets/level/peak.glb (art_src/v10_peak.py, art_src/peak.blend); positions: art_src/peak.json.
func yaw_of(d: Array) -> float:
	# Blender direction (x, y) -> Godot yaw that faces it (forward is -Z)
	return atan2(-float(d[0]), float(d[1]))

func omni(parent: Node, n: String, pos: Vector3, col: Color, energy: float, rng: float) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.name = n
	l.position = pos
	l.light_color = col
	l.light_energy = energy
	l.omni_range = rng
	l.light_volumetric_fog_energy = 0.4
	l.shadow_enabled = false
	add(parent, l)
	return l

func build_peak() -> void:
	var P: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://art_src/peak.json"))
	var peak := inst("res://assets/level/peak.glb", "Peak")
	add(main_root, peak)
	main_root.set_editable_instance(peak, true)
	# invisible stair ramps + guards: layer 16, like the mesa's
	for b in peak.find_children("*Ramps*", "StaticBody3D", true, false):
		(b as StaticBody3D).collision_layer = 16
	# the plateau, the arch stubs and the mast's foot rock: the same terrain shader as the mesa (TerrainMask is painted)
	var rock := peak.find_child("Peak", true, false) as MeshInstance3D
	if rock:
		for s in rock.mesh.get_surface_count():
			rock.set_surface_override_material(s, mesa_material())

	# the hall's moving parts (modelled closed). No boss yet: both shutters stand open. The fight should close
	# BossGate behind the player, then set GameState "peak_boss_down" and open ExitGate + HiddenDoor.
	var arena := group(main_root, "PeakArena")
	var gates: Dictionary = P["hall"]["gates"]
	for d in [["BossGate", Vector3(0, gates["BossGate-col"]["lift"], 0), true],
			["ExitGate", Vector3(0, gates["ExitGate-col"]["lift"], 0), true],
			["HiddenDoor", Vector3(0, -2.75, 0), false]]:
		var c := Node.new()
		c.name = d[0]
		c.set_script(load("res://scripts/peak_door.gd"))
		c.set("target", NodePath("../../Peak/" + d[0]))
		c.set("open_offset", d[1])
		c.set("start_open", d[2])
		c.set("open_flag", "peak_boss_down")
		add(arena, c)
	var centre: Array = P["hall"]["centre"]
	var boss := Marker3D.new()
	boss.name = "BossSpawn"
	boss.position = b2g(centre) + Vector3(0, 0.15, 0)
	boss.add_to_group("boss_spawn", true)
	add(arena, boss)

	# ladders on the mast: the climber stands outside (climb_normal), the upper landing is in front at the top
	var lads := group(main_root, "MastLadders")
	var k := 0
	for l in P["mast"]["ladders"]:
		var b: Array = l["bottom"]
		var nrm: Array = l["normal"]
		var g := Vector3(nrm[0], 0, -float(nrm[1]))
		var z0: float = b[2]
		var z1: float = float(l["top"]) + 0.8
		var a := Area3D.new()
		a.name = "Ladder_%d" % k
		a.set_script(load("res://scripts/ladder.gd"))
		a.position = b2g([b[0], b[1], (z0 + z1) * 0.5]) + g * 0.22
		a.rotation.y = atan2(g.x, g.z)
		a.set("climb_normal", g)
		add(lads, a)
		box_shape(a, Vector3(1.2, z1 - z0, 0.95), Vector3.ZERO)
		k += 1

	# checkpoints: the landing off the bridge, outside the hall entrance, each band's departure corner, the cabin
	var safety := main_root.get_node("Safety")
	var app: Dictionary = P["approach"]
	var cps := [["CP_PeakLanding", app["end"], app["dir"], Vector3(5.0, 2.5, 5.0)]]
	# halfway across the bridge, on trestle A's cap (falls there are fatal; also seeds the minimap bake out there)
	var ca: Array = app["pieces"]["capA"]
	var s_mid := (float(ca[0]) + float(ca[1])) * 0.5
	var st: Array = app["start"]
	var ad: Array = app["dir"]
	cps.append(["CP_Bridge", [st[0] + ad[0] * s_mid, st[1] + ad[1] * s_mid, app["heights"]["capA"]], ad, Vector3(2.8, 2.5, 2.8)])
	var gb: Array = gates["BossGate-col"]["bottom"]
	var out := Vector2(gb[0] - centre[0], gb[1] - centre[1]).normalized()
	cps.append(["CP_HallEntrance", [gb[0] + out.x * 3.5, gb[1] + out.y * 3.5, P["P10"]["ground"]], [-out.x, -out.y], Vector3(5.0, 2.5, 3.0)])
	var bands := ["CP_Band1", "CP_Band2", "CP_Band3", "CP_Band4", "CP_Cabin"]
	for i in P["mast"]["checkpoints"].size():
		var c: Dictionary = P["mast"]["checkpoints"][i]
		cps.append([bands[i], c["pos"], c["dir"], Vector3(2.6, 2.5, 2.6)])
	for c in cps:
		var a := Area3D.new()
		a.name = c[0]
		a.set_script(load("res://scripts/checkpoint.gd"))
		a.position = b2g(c[1]) + Vector3(0, 0.05, 0)
		a.rotation.y = yaw_of(c[2])
		add(safety, a)
		box_shape(a, c[3], Vector3(0, 1.25, 0))

	# the end of the climb (for now): stepping into the radio cabin
	var cab: Dictionary = P["mast"]["cabin"]
	var top := Area3D.new()
	top.name = "MastCabin"
	top.set_script(load("res://scripts/exit_zone.gd"))
	top.set("message", "THE MAST\n— to be continued —")
	top.position = b2g(cab["door_inside"]) + Vector3(0, 1.2, 0)
	top.rotation.y = yaw_of(cab["yaw_dir"])          # box Z runs across the doorway, X along the east wall
	add(main_root, top)
	box_shape(top, Vector3(10.0, 2.4, 3.0), Vector3.ZERO)

	# lamps: hanging + caged wall lamps in the hall, floods on the wall tops, the landing lamp, the mast's beacons
	var lights := group(main_root, "PeakLights")
	var warm := Color(1.0, 0.76, 0.48)
	k = 0
	for p in P["hall"]["lamps"]:
		omni(lights, "HallLamp_%d" % k, b2g(p), warm, 1.3, 11.0)
		k += 1
	k = 0
	for p in P["hall"]["wall_lamps"]:
		omni(lights, "WallLamp_%d" % k, b2g(p), warm, 0.6, 5.0)
		k += 1
	k = 0
	for f in P["hall"]["floods"]:
		var s := SpotLight3D.new()
		s.name = "Flood_%d" % k
		var dir := b2g(f[1])
		s.transform = Transform3D(Basis.looking_at(dir, Vector3.UP if absf(dir.y) < 0.95 else Vector3.FORWARD), b2g(f[0]))
		s.light_color = Color(1.0, 0.9, 0.75)
		s.light_energy = 2.5
		s.spot_range = 34.0
		s.spot_angle = 32.0
		s.light_volumetric_fog_energy = 0.6
		s.shadow_enabled = false
		add(lights, s)
		k += 1
	omni(lights, "LandingLamp", b2g(P["scenery"]["landing_lamp"]) - Vector3(0, 0.3, 0), warm, 1.0, 7.0)
	var ml: Array = P["mast"]["lamps"]
	omni(lights, "BeaconTip", b2g(ml[0]), Color(1.0, 0.18, 0.1), 4.0, 12.0)
	omni(lights, "BeaconTop", b2g(ml[1]), Color(1.0, 0.18, 0.1), 2.5, 8.0)
	omni(lights, "CabinLamp", b2g(ml[2]), warm, 1.2, 9.0)

	# nothing random spawns on the Peak, its bridge or the mast (they're their own encounter)
	var spawner := main_root.get_node("Enemies")
	var pk: Array = P["P10"]["peak"]
	var mst: Array = P["P10"]["mast"]
	var a0: Array = app["start"]
	var a1: Array = app["end"]
	var mid := Vector2((a0[0] + a1[0]) * 0.5, -(a0[1] + a1[1]) * 0.5)
	var zones: Array[Vector3] = [Vector3(pk[0], -float(pk[1]), float(P["P10"]["rim"]) + 14.0),
		Vector3(mst[0], -float(mst[1]), 32.0), Vector3(mid.x, mid.y, float(app["length"]) * 0.5 + 6.0)]
	spawner.set("no_spawn", zones)

	# spawn markers for the debug tools (peek / hud_shot / bench) at the bridge and the mast
	var spawns := main_root.get_node("Spawns")
	spawn_marker(spawns, "AtPeakBridge", b2g(app["start"]) + Vector3(0, 0.05, 0), rad_to_deg(yaw_of(app["dir"])))
	var c1: Dictionary = P["mast"]["checkpoints"][0]
	spawn_marker(spawns, "AtMast", b2g(c1["pos"]) + Vector3(0, 0.05, 0), rad_to_deg(yaw_of(c1["dir"])))
