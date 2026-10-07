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
	build_station()
	build_story()
	var paint := Node.new()        # last, so it repaints after everything else is in (painterly_world.gd)
	paint.name = "PainterlyWorld"
	paint.set_script(load("res://scripts/painterly_world.gd"))
	add(main_root, paint)

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
	# painted late-afternoon sky (warm horizon, lilac zenith, gold halo, brushy cloud strata); the sun disk follows Sun
	var sm := ShaderMaterial.new()
	sm.shader = load("res://scripts/surface_sky.gdshader")
	sm.set_shader_parameter("brush", load("res://assets/creatures/sph_paint_brush.png"))
	sky.sky_material = sm
	sky.radiance_size = Sky.RADIANCE_SIZE_128
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
	env.fog_light_color = Color(0.94, 0.87, 0.76)      # the sky's horizon, so far shapes sink into it
	env.fog_light_energy = 1.0
	env.fog_sun_scatter = 0.3                         # a gold bloom of haze round the sun
	env.fog_density = 0.0032
	env.fog_aerial_perspective = 0.2
	env.fog_sky_affect = 0.15                         # the sky paints its own horizon haze
	env.fog_height = 26.0
	env.fog_height_density = 0.045
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.0016     # thin: near haze lit by the sun turned the blue rock tan (and veiled the yard)
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
	sun.light_volumetric_fog_energy = 1.6
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
			mesa.lod_bias = 128.0

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
	# (v11: the silo roof's "to be continued" Lookout banner is gone - SENTINEL-09 stands there now, see build_story())

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

## v13: the Sphaeroid fight (scripts/boss_arena.gd + creatures/sphaeroid.gd). The arena needs the hall's floor
## outline and the floor band under the gallery in Godot XZ; they come from v10_peak.py's BV / GAL / inset(),
## mirrored here (hall-local, +X towards the mast, turned by hall_yaw about the hall centre).
const HALL_BV := [Vector2(16.0, -6.0), Vector2(16.0, 6.0), Vector2(11.0, 12.0), Vector2(2.0, 13.5), Vector2(-6.0, 12.0),
	Vector2(-13.0, 9.0), Vector2(-16.0, 2.0), Vector2(-15.0, -6.0), Vector2(-9.0, -12.0), Vector2(0.0, -13.0), Vector2(9.0, -11.0)]
const HALL_GAL := [9, 10, 0, 1, 2]

func _hall_inset(i: int, d: float) -> Vector2:
	var n := HALL_BV.size()
	var a: Vector2 = HALL_BV[(i - 1 + n) % n]
	var b: Vector2 = HALL_BV[i % n]
	var c: Vector2 = HALL_BV[(i + 1) % n]
	var d1 := (b - a).normalized()
	var d2 := (c - b).normalized()
	var n1 := Vector2(-d1.y, d1.x)
	var n2 := Vector2(-d2.y, d2.x)
	var m := (n1 + n2).normalized()
	return b + m * (d / maxf(0.3, m.dot(n1)))

func _hall_to_godot(P: Dictionary, v: Vector2) -> Vector2:
	var c: Array = P["hall"]["centre"]
	var th := deg_to_rad(float(P["P10"]["hall_yaw"]))
	var w := Vector2(float(c[0]) + v.x * cos(th) - v.y * sin(th), float(c[1]) + v.x * sin(th) + v.y * cos(th))
	return Vector2(w.x, -w.y)

func build_boss_fight(P: Dictionary, arena: Node3D) -> void:
	var fight := Node3D.new()
	fight.name = "BossFight"
	fight.set_script(load("res://scripts/boss_arena.gd"))
	add(arena, fight)
	var floor_y := float(P["P10"]["ground"]) + 0.12
	var poly := PackedVector2Array()
	for i in HALL_BV.size():
		poly.append(_hall_to_godot(P, _hall_inset(i, 1.0)))      # the inner wall line (walls are 1 m thick)
	var quads := PackedVector2Array()
	for i in HALL_GAL:
		for v in [_hall_inset(i, 1.0), _hall_inset(i + 1, 1.0), _hall_inset(i + 1, 5.0), _hall_inset(i, 5.0)]:
			quads.append(_hall_to_godot(P, v))
	var gb: Array = P["hall"]["gates"]["BossGate-col"]["bottom"]
	fight.set("floor_y", floor_y)
	fight.set("hall_poly", poly)
	fight.set("gallery_quads", quads)
	fight.set("gate_point", b2g([gb[0], gb[1], floor_y]))
	fight.set("boss_gate", NodePath("../BossGate"))
	fight.set("exit_gate", NodePath("../ExitGate"))
	fight.set("hidden_door", NodePath("../HiddenDoor"))
	fight.set("spawn", NodePath("../BossSpawn"))

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
			rock.lod_bias = 128.0
			rock.set_surface_override_material(s, mesa_material())

	# the hall's moving parts (modelled closed). BossGate stands open until the fight starts (boss_arena.gd drops it
	# behind the player); ExitGate (to the mast) and HiddenDoor stay shut until the Sphaeroid is unpowered, which sets
	# GameState "peak_boss_down" (then all three start open on every later visit).
	var arena := group(main_root, "PeakArena")
	var gates: Dictionary = P["hall"]["gates"]
	for d in [["BossGate", Vector3(0, gates["BossGate-col"]["lift"], 0), true],
			["ExitGate", Vector3(0, gates["ExitGate-col"]["lift"], 0), false],
			["HiddenDoor", Vector3(0, -2.75, 0), false]]:
		var c := Node.new()
		c.name = d[0]
		c.set_script(load("res://scripts/peak_door.gd"))
		c.set("target", NodePath("../../Peak/" + d[0]))
		c.set("open_offset", d[1])
		c.set("start_open", d[2])
		c.set("open_flag", "peak_boss_down")
		add(arena, c)
	# v14: the Pennon on the annex plinth (pennon_pickup.gd; plinth top 1.05 m up, 84% of the way from the door to
	# `inside`: v10_peak.py hall_annex), and a lamp under the annex's hanging shade
	var ax: Dictionary = P["hall"]["annex"]
	var ax_door := b2g(ax["door"])
	var ax_in := b2g(ax["inside"])
	var ax_out := Vector3(ax_in.x - ax_door.x, 0, ax_in.z - ax_door.z)
	var pen := Area3D.new()
	pen.name = "PennonPickup"
	pen.set_script(load("res://scripts/pennon_pickup.gd"))
	pen.position = Vector3(ax_door.x, ax_in.y, ax_door.z) + ax_out * 0.84 + Vector3(0, 1.05, 0)
	pen.rotation.y = atan2(ax_out.x, ax_out.z)      # faces back out through the doorway
	add(arena, pen)
	# v15: the cable car station off the plateau's south-east rim (scripts/cable_station.gd loads
	# assets/level/cable_station.glb + the car; art_src/v15_cable_station.py)
	var cst := Node3D.new()
	cst.name = "CableStation"
	cst.set_script(load("res://scripts/cable_station.gd"))
	add(main_root, cst)
	var ax_lamp := OmniLight3D.new()
	ax_lamp.name = "AnnexLamp"
	ax_lamp.position = b2g(ax["lamp"]) + Vector3(0, -0.35, 0)
	ax_lamp.light_color = Color(1.0, 0.78, 0.6)
	ax_lamp.light_energy = 1.4
	ax_lamp.omni_range = 5.0
	ax_lamp.shadow_enabled = false
	add(arena, ax_lamp)
	var centre: Array = P["hall"]["centre"]
	var boss := Marker3D.new()
	boss.name = "BossSpawn"
	boss.position = b2g(centre) + Vector3(0, 0.15, 0)
	boss.add_to_group("boss_spawn", true)
	var gb0: Array = gates["BossGate-col"]["bottom"]
	boss.rotation.y = yaw_of([gb0[0] - centre[0], gb0[1] - centre[1]])     # it waits facing the entrance
	add(arena, boss)
	build_boss_fight(P, arena)

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

# ------------------------------------------------------------------ v12: Patrol Station 4 at the head of the Peak bridge
## The lift gate on the bridge's first stub opens for the sealed station pass (scripts/patrol_station.gd). Model and
## layout: art_src/v12_station.py -> assets/props/patrol_station.glb + art_src/station.json (prop-local Blender coords:
## origin on the deck centre at the gate line, +Y out along the bridge).
func build_station() -> void:
	var P: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://art_src/peak.json"))
	var S: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://art_src/station.json"))
	var app: Dictionary = P["approach"]
	var st: Array = app["start"]
	var ad: Array = app["dir"]
	var s: float = S["s_gate"]
	# arch1's deck runs from z0 - 0.4 at s = -6 up at `slope` (v10_peak.py approach())
	var z: float = float(st[2]) - 0.4 + (s + 6.0) * float(S["slope"])
	var root := Node3D.new()
	root.name = "PatrolStation"
	root.set_script(load("res://scripts/patrol_station.gd"))
	root.position = b2g([float(st[0]) + float(ad[0]) * s, float(st[1]) + float(ad[1]) * s, z])
	root.rotation.y = yaw_of(ad)
	add(main_root, root)
	var model := inst("res://assets/props/patrol_station.glb", "Model")
	add(root, model)
	main_root.set_editable_instance(model, true)
	for b in model.find_children("*Guards*", "StaticBody3D", true, false):
		(b as StaticBody3D).collision_layer = 16       # invisible walls: like the mesa's guards, not on the interact ray
	for n in ["StatusLamp", "ReaderLamp", "BeaconLens"]:
		var mi := model.find_child(n, true, false) as GeometryInstance3D
		if mi:
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	# the reader (interact) and the gate's collision, which patrol_station.gd lifts with the gate mesh
	var rd: Array = S["reader"]
	var reader := Area3D.new()
	reader.name = "Reader"
	reader.set_script(load("res://scripts/station_reader.gd"))
	reader.position = b2g([rd[0], float(rd[1]) - 0.1, rd[2]])
	add(root, reader)
	box_shape(reader, Vector3(0.5, 0.6, 0.45), Vector3.ZERO)
	var gb := AnimatableBody3D.new()
	gb.name = "GateBody"
	gb.sync_to_physics = true
	gb.position = Vector3(0, float(S["gate_z"]) + float(S["gate_h"]) * 0.5, 0)
	add(root, gb)
	box_shape(gb, Vector3((float(S["post_x"]) - 0.1) * 2.0, float(S["gate_h"]), 0.3), Vector3.ZERO)

	# lights (no shadows): lamp post, status lamp, booth glow, roof flood back up the approach, tip beacon
	var lights := group(root, "Lights")
	var warm := Color(1.0, 0.78, 0.52)
	omni(lights, "GateLamp", b2g(S["lamp"]) - Vector3(0, 0.25, 0), warm, 1.8, 9.0)
	omni(lights, "StatusLight", b2g(S["status"]) + Vector3(0, 0.1, 0), Color(1.0, 0.14, 0.07), 0.9, 3.5)
	omni(lights, "BoothGlow", b2g(S["booth_glow"]), warm, 0.8, 3.6)
	omni(lights, "Beacon", b2g(S["beacon"]) + Vector3(0, 0.1, 0), Color(1.0, 0.62, 0.16), 0.6, 4.5)
	var fl: Array = S["flood"]
	var flood := SpotLight3D.new()
	flood.name = "Flood"
	var fp := b2g([fl[0], float(fl[1]) - 0.1, fl[2]])
	flood.transform = Transform3D(Basis.looking_at(Vector3(-0.25, -0.45, 1.0).normalized(), Vector3.UP), fp)
	flood.light_color = Color(1.0, 0.9, 0.74)
	flood.light_energy = 2.2
	flood.spot_range = 18.0
	flood.spot_angle = 30.0
	flood.light_volumetric_fog_energy = 0.8
	flood.shadow_enabled = false
	add(lights, flood)

# ------------------------------------------------------------------ v11: the silo watcher + loot crates
## SENTINEL-09 on the silo roof: SENTINEL-07 (main.tscn, C deck) sends the player here. Dialogue: scripts/dialogue/
## watcher_lines.gd. Loot: 16 supply crates (scripts/supply_crate.gd; assets/props/supply_crate.glb + parts_case.glb
## from art_src/v11_crates.py), 5 with a voltaic core (the drone needs 3). Floor heights (Godot y) were probed with
## tools/probe_points.gd; the spots keep clear of walk_test.gd's straight-line routes.
const CRATES := [
	# name, SC = supply crate / PC = parts case, Blender x, y, Godot floor y, yaw, loot
	["LiftLanding", "SC", 26.5, -6.0, 34.28, 18.0, {"tokens": 12, "scrap": 2}],
	["StairFoot", "PC", 44.5, 14.5, 34.35, -8.0, {"scrap": 3}],
	["Gallery", "SC", 58.0, 23.0, 40.0, 172.0, {"tokens": 18, "bars": 1}],
	["LinkDeck", "PC", 60.7, 2.0, 40.0, 90.0, {"tokens": 10, "scrap": 1}],
	["TowerTop", "SC", 56.0, -10.3, 46.0, -96.0, {"tokens": 8, "scrap": 2}],
	["BlockC", "SC", 64.5, -29.0, 46.0, 200.0, {"voltaic_core": 1, "tokens": 6}],
	["Pinnacle", "PC", 70.8, -56.1, 46.0, 184.0, {"voltaic_core": 1, "scrap": 2}],
	["SiloLanding", "SC", 97.0, -58.5, 46.0, 75.0, {"tokens": 15, "bars": 1}],
	["SiloRoof", "PC", 91.2, -48.6, 56.0, 30.0, {"tokens": 22}],
	["PumpHouse", "PC", 95.3, 14.6, 34.29, 4.0, {"voltaic_core": 1, "tokens": 5}],
	["WaterTower", "SC", 9.5, 48.0, 34.29, 40.0, {"scrap": 3, "bars": 1}],
	["FrameRuin", "SC", -35.0, 3.0, 34.27, -20.0, {"voltaic_core": 1, "scrap": 1}],
	["TowerBlock", "PC", -24.0, 31.0, 34.43, 135.0, {"tokens": 14, "bars": 1}],
	["Bunker", "SC", 40.0, -10.0, 34.32, 66.0, {"scrap": 2, "tokens": 7}],
	["Pylon", "PC", -6.5, -44.5, 34.30, -150.0, {"voltaic_core": 1, "tokens": 4}],
	["PipeRun", "PC", 75.0, 20.0, 34.31, 12.0, {"scrap": 4}],
]

func build_story() -> void:
	var w := Node3D.new()
	w.name = "SiloWatcher"
	w.set_script(load("res://scripts/creatures/watcher.gd"))
	w.position = b2g([95.0, -47.5, 56.0])         # between the roof tank and the dish, facing the stair (north)
	add(main_root, w)
	add(w, inst("res://assets/creatures/watcher.glb", "Model"))
	var talk := Area3D.new()
	talk.name = "Talk"
	talk.set_script(load("res://scripts/watcher_talk.gd"))
	talk.set("tree_id", "sentinel_09")
	talk.set("speaker", "SENTINEL-09")
	add(w, talk)
	box_shape(talk, Vector3(1.3, 1.4, 1.3), Vector3(0, 0.5, 0))

	var loot := group(main_root, "Loot")
	for c in CRATES:
		var sc: bool = c[1] == "SC"
		var cr := StaticBody3D.new()
		cr.name = "Crate_" + str(c[0])
		cr.set_script(load("res://scripts/supply_crate.gd"))
		cr.position = Vector3(c[2], c[4], -float(c[3]))
		cr.rotation_degrees = Vector3(0, c[5], 0)
		var contents: Dictionary = c[6]
		for k in contents:
			cr.set(k, contents[k])
		add(loot, cr)
		add(cr, inst("res://assets/props/%s.glb" % ("supply_crate" if sc else "parts_case"), "Model"))
		box_shape(cr, Vector3(0.84, 0.5, 0.54) if sc else Vector3(0.68, 0.34, 0.44), Vector3(0, 0.25 if sc else 0.17, 0))
