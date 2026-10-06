extends SceneTree
## Builds res://scenes/start.tscn: the lower workings, where the player really spawns (top platform).
## Geometry: assets/level/start.glb + assets/props/drawbridge.glb (art_src/v4_start_room.py).
## Layout numbers come from art_src/start_room.json (Blender coords, converted with b2g()).
## Run headless:  godot --headless --path . --script res://tools/build_start.gd
## NOTE: overwrites scenes/start.tscn.

var main_root: Node3D
var L: Dictionary
var data: Dictionary
var _radial: GradientTexture2D

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

func shadow_fade(l: Light3D) -> void:
	l.distance_fade_enabled = true
	l.distance_fade_begin = 90.0
	l.distance_fade_length = 10.0
	l.distance_fade_shadow = 28.0
	l.shadow_caster_mask = 1

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

func _init() -> void:
	data = JSON.parse_string(FileAccess.get_file_as_string("res://art_src/start_room.json"))
	L = data["layout"]
	main_root = Node3D.new()
	main_root.name = "Start"

	var grid := Node.new()
	grid.name = "PowerGrid"
	grid.set_script(load("res://scripts/power_grid.gd"))
	grid.set("intro_text", "THE HERETIC – UPPER SUBTERRANEAN\nfind a way down")
	add(main_root, grid)

	add(main_root, inst("res://assets/level/start.glb", "Level"))
	build_environment()
	build_lights()
	build_puzzle()
	build_ladder()
	build_safety()
	build_particles()
	build_pickup()
	build_exits_and_spawns()

	var ps := PackedScene.new()
	ps.pack(main_root)
	print("start saved: ", ResourceSaver.save(ps, "res://scenes/start.tscn"))
	main_root.free()
	quit()

# ------------------------------------------------------------------ environment (matches the cavern's grade)
func build_environment() -> void:
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.0, 0.0, 0.01)
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
	env.volumetric_fog_density = 0.016
	env.volumetric_fog_albedo = Color(0.62, 0.68, 0.9)
	env.volumetric_fog_emission = Color(0.035, 0.04, 0.08)
	env.volumetric_fog_emission_energy = 1.0
	env.volumetric_fog_anisotropy = 0.45
	env.volumetric_fog_length = 70.0
	env.volumetric_fog_ambient_inject = 0.22
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.12
	env.adjustment_saturation = 0.95
	we.environment = env
	add(main_root, we)
	# mist pooled over the water, thinning upwards
	var fv := FogVolume.new()
	fv.name = "LowMist"
	fv.size = Vector3(30, 10, 26)
	fv.position = b2g([0, 0, 3.0])
	var fm := FogMaterial.new()
	fm.density = 0.05
	fm.albedo = Color(0.6, 0.66, 0.9)
	fm.height_falloff = 0.3
	fm.edge_fade = 0.5
	fv.material = fm
	add(main_root, fv)

# ------------------------------------------------------------------ lights
func build_lights() -> void:
	var g := group(main_root, "Lights")
	var fol := group(g, "FoliageGlow")
	var i := 0
	for f in data["ferns"]:
		var s: float = f[3]
		omni(fol, "Glow_%02d" % i, b2g([f[0], f[1], f[2] + 0.6]), Color(0.3, 0.46, 1.0), 2.0 * s, 7.0 + 3.0 * s, s >= 1.5, 2.0)
		i += 1
	var lamps := group(g, "CageLamps")
	i = 0
	for p in data["lamps"]:
		omni(lamps, "Lamp_%02d" % i, b2g(p) + Vector3(0, -0.2, 0), Color(0.62, 0.74, 1.0), 2.4, 11.0, i != 4, 3.0)
		i += 1
	# cold daylight through a crack in the roof, falling on the broken arch (the white streak in the reference)
	var beam := SpotLight3D.new()
	beam.name = "RoofCrackBeam"
	beam.transform = Transform3D(Basis(), b2g([-4.5, -5.5, 47.5])).looking_at(b2g([-8.0, -6.8, L["arch"]]), Vector3.UP)
	beam.light_color = Color(0.85, 0.9, 1.0)
	beam.light_energy = 6.0
	beam.spot_range = 45.0
	beam.spot_angle = 7.0
	beam.spot_attenuation = 0.4
	beam.light_volumetric_fog_energy = 6.0
	beam.shadow_enabled = true
	shadow_fade(beam)
	beam.distance_fade_shadow = 60.0
	add(g, beam)
	# the lit bottom bridge: light spilling out of the tunnel + a soft fill under the bridge
	omni(g, "TunnelSpill", b2g([12.5, -1.0, L["bottom"] + 2.6]), Color(0.75, 0.85, 1.0), 4.0, 16.0, true, 4.0)
	omni(g, "BridgeFill", b2g([2.0, -1.0, L["bottom"] - 2.0]), Color(0.45, 0.55, 0.9), 1.5, 14.0, false, 3.5)
	# shadowless haze fills against the back wall: they light the fog so the structures read as
	# silhouettes, like the layered greys in the reference
	var hz := group(g, "Haze")
	i = 0
	for p in [[0.0, 0.0, 30.0], [0.0, 7.0, 13.0], [-6.0, 6.5, 33.0], [5.0, -6.0, 41.0], [3.0, 5.0, 20.0]]:
		omni(hz, "Haze_%d" % i, b2g(p), Color(0.45, 0.52, 0.78), 1.7, 20.0, false, 3.5)
		i += 1
	for p in [[14.0, -1.0, L["bottom"] + 3.2], [17.0, -1.0, L["bottom"] + 3.2]]:
		omni(g, "TunnelLamp_%d" % g.get_child_count(), b2g(p), Color(0.62, 0.74, 1.0), 1.3, 6.0, false, 1.5)

# ------------------------------------------------------------------ valve + drawbridge
func build_puzzle() -> void:
	var g := group(main_root, "Puzzle")
	var by: Array = L["bridge_y"]
	var bridge := AnimatableBody3D.new()
	bridge.name = "Drawbridge"
	bridge.set_script(load("res://scripts/drawbridge.gd"))
	bridge.position = b2g([L["hinge_x"], (by[0] + by[1]) * 0.5, L["mid"]])
	add(g, bridge)
	add(bridge, inst("res://assets/props/drawbridge.glb", "Model"))
	var ln: float = L["bridge_len"]
	var w: float = by[1] - by[0]
	box_shape(bridge, Vector3(ln, 0.12, w), Vector3(-ln * 0.5, -0.06, 0), "Deck")
	box_shape(bridge, Vector3(ln, 1.1, 0.08), Vector3(-ln * 0.5, 0.55, w * 0.5), "RailA")
	box_shape(bridge, Vector3(ln, 1.1, 0.08), Vector3(-ln * 0.5, 0.55, -w * 0.5), "RailB")

	var steam := steam_burst(g, "RamSteam", b2g([L["hinge_x"] + 0.4, by[0] - 0.35, L["mid"] - 0.6]))
	var steam2 := steam_burst(g, "ValveSteam", b2g([L["valve"][0] + 0.4, L["valve"][1] - 0.4, L["mid"] + 1.4]))
	var v := Area3D.new()
	v.name = "HydraulicValve"
	v.set_script(load("res://scripts/bridge_valve.gd"))
	v.position = b2g([L["valve"][0], L["valve"][1], L["mid"]])
	v.rotation_degrees = Vector3(0, -90, 0)     # hand-wheel faces west, towards the player
	v.set("bridge_path", NodePath("../Drawbridge"))
	var sp: Array[NodePath] = [NodePath("../" + steam.name), NodePath("../" + steam2.name)]
	v.set("steam_paths", sp)
	add(g, v)
	add(v, inst("res://assets/props/steam_valve.glb", "Model"))
	box_shape(v, Vector3(1.0, 1.4, 1.2), Vector3(0, 1.1, 0.2))
	var vb := StaticBody3D.new()
	vb.name = "SolidBody"
	add(v, vb)
	box_shape(vb, Vector3(0.45, 2.1, 0.45), Vector3(0, 1.05, 0))

# ------------------------------------------------------------------ ladder: left landing (Z mid) -> arch ledge
func build_ladder() -> void:
	var lad: Array = L["ladder"]
	var l := Area3D.new()
	l.name = "ArchLadder"
	l.set_script(load("res://scripts/ladder.gd"))
	var z0: float = L["arch"]
	var z1: float = L["mid"] + 0.8
	l.position = b2g([lad[0], lad[1] + 0.22, (z0 + z1) * 0.5])
	l.set("climb_normal", Vector3(0, 0, -1))   # the climber stands north of it (Blender +Y = Godot -Z)
	add(main_root, l)
	box_shape(l, Vector3(1.2, z1 - z0, 0.95), Vector3.ZERO)

# ------------------------------------------------------------------ checkpoints, kill water, invisible guards
func build_safety() -> void:
	var g := group(main_root, "Safety")
	var cps := [["CP_LeftLanding", [-6.0, -4.4, L["mid"]], 0.0, Vector3(5.0, 2.5, 3.0)],
		["CP_Bottom", [0.0, -1.0, L["bottom"]], -90.0, Vector3(2.0, 2.5, 2.6)]]
	for c in cps:
		var a := Area3D.new()
		a.name = c[0]
		a.set_script(load("res://scripts/checkpoint.gd"))
		a.position = b2g(c[1]) + Vector3(0, 0.05, 0)
		a.rotation_degrees = Vector3(0, c[2], 0)
		add(g, a)
		box_shape(a, c[3], Vector3(0, 1.25, 0))
	var k := Area3D.new()
	k.name = "DeepWater"
	k.set_script(load("res://scripts/kill_zone.gd"))
	k.position = b2g([0, 0, L["water"] - 1.0])
	add(g, k)
	box_shape(k, Vector3(40, 2.0, 40), Vector3.ZERO)
	# stop the drawbridge gap being jumped: walls along the mid ledge's west edge (the raised bridge closes
	# the middle) and along the south side of flight 2
	var guard := StaticBody3D.new()
	guard.name = "Guards"
	add(g, guard)
	var hx: float = L["hinge_x"]
	var by: Array = L["bridge_y"]
	var ml: Array = L["mid_ledge"]
	var f2y: float = L["f2"][0][1]
	var mz: float = L["mid"]
	_guard(guard, "LedgeS", [hx, ml[2], mz], [hx, by[0] - 0.05, mz + 3.0])
	_guard(guard, "LedgeN", [hx, by[1] + 0.05, mz], [hx, f2y - 1.05, mz + 3.0])
	_guard(guard, "Flight2S", [L["f2"][0][0], f2y - 1.1, mz], [hx, f2y - 1.1, L["l1"] + 3.0])

func _guard(body: Node, n: String, a: Array, b: Array) -> void:
	var p0 := b2g(a)
	var p1 := b2g(b)
	var size := (p1 - p0).abs() + Vector3(0.15, 0, 0.15)
	box_shape(body, size, (p0 + p1) * 0.5, n)

# ------------------------------------------------------------------ particles (kept light)
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

func pmat(color: Color, emission: float, additive := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if additive:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.billboard_keep_scale = true
	m.vertex_color_use_as_albedo = true
	m.albedo_color = color
	m.albedo_texture = radial_tex()
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if emission > 0.0:
		m.emission_enabled = true
		m.emission = Color(color.r, color.g, color.b)
		m.emission_energy_multiplier = emission
	return m

func fade_ramp(peak := 1.0) -> GradientTexture1D:
	var gr := Gradient.new()
	gr.offsets = PackedFloat32Array([0.0, 0.2, 0.7, 1.0])
	gr.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, peak), Color(1, 1, 1, peak), Color(1, 1, 1, 0)])
	var t := GradientTexture1D.new()
	t.gradient = gr
	return t

func quad(size: Vector2, mat: Material) -> QuadMesh:
	var q := QuadMesh.new()
	q.size = size
	q.material = mat
	return q

func emitter(parent: Node, n: String, pos: Vector3, amount: int, lifetime: float, pm: ParticleProcessMaterial, mesh: Mesh, aabb: AABB) -> GPUParticles3D:
	var e := GPUParticles3D.new()
	e.name = n
	e.position = pos
	e.amount = amount
	e.lifetime = lifetime
	e.preprocess = lifetime
	e.process_material = pm
	e.draw_pass_1 = mesh
	e.visibility_aabb = aabb
	e.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	e.layers = 2
	add(parent, e)
	return e

func steam_burst(parent: Node, n: String, pos: Vector3) -> GPUParticles3D:
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.1
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 35.0
	pm.initial_velocity_min = 2.0
	pm.initial_velocity_max = 3.5
	pm.gravity = Vector3(0, 0.6, 0)
	pm.damping_min = 1.2
	pm.damping_max = 1.8
	pm.scale_min = 0.6
	pm.scale_max = 1.2
	var c := Curve.new()
	c.max_value = 3.0
	c.add_point(Vector2(0, 0.3))
	c.add_point(Vector2(1, 2.6))
	var ct := CurveTexture.new()
	ct.curve = c
	pm.scale_curve = ct
	pm.color_ramp = fade_ramp(0.6)
	var e := emitter(parent, n, pos, 60, 2.6, pm, quad(Vector2(0.9, 0.9), pmat(Color(0.75, 0.8, 0.97, 0.75), 0.45)), AABB(Vector3(-5, -3, -5), Vector3(10, 10, 10)))
	e.one_shot = true
	e.explosiveness = 0.35
	e.emitting = false
	e.preprocess = 0.0
	return e

func build_particles() -> void:
	var g := group(main_root, "Particles")
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(10, 22, 8)
	pm.spread = 180.0
	pm.initial_velocity_max = 0.06
	pm.gravity = Vector3(0, -0.015, 0)
	pm.turbulence_enabled = true
	pm.turbulence_influence_max = 0.07
	pm.scale_min = 0.5
	pm.scale_max = 1.5
	pm.color_ramp = fade_ramp(1.0)
	emitter(g, "Dust", b2g([0, 0, 24]), 700, 16.0, pm, quad(Vector2(0.04, 0.04), pmat(Color(0.72, 0.78, 1.0, 0.5), 0.12)), AABB(Vector3(-12, -24, -10), Vector3(24, 48, 20)))
	var spore := quad(Vector2(0.05, 0.05), pmat(Color(0.35, 0.6, 1.0, 0.9), 5.0, true))
	var i := 0
	for f in data["ferns"]:
		var sp := ParticleProcessMaterial.new()
		sp.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		sp.emission_sphere_radius = 1.0
		sp.direction = Vector3(0, 1, 0)
		sp.spread = 60.0
		sp.initial_velocity_min = 0.05
		sp.initial_velocity_max = 0.2
		sp.gravity = Vector3(0, 0.02, 0)
		sp.turbulence_enabled = true
		sp.turbulence_influence_max = 0.1
		sp.color_ramp = fade_ramp(1.0)
		emitter(g, "Spores_%02d" % i, b2g(f), 14, 7.0, sp, spore, AABB(Vector3(-3, -2, -3), Vector3(6, 6, 6)))
		i += 1

# ------------------------------------------------------------------ the weapon: steel shaft at the west end of the bottom bridge
const PICKUP_AT := [-7.4, -1.0]     # Blender x, y on the bottom bridge (dead end, away from the tunnel)

func build_pickup() -> void:
	var g := group(main_root, "Pickup")
	var base := b2g([PICKUP_AT[0], PICKUP_AT[1], L["bottom"]])
	var plinth := StaticBody3D.new()     # an old crate as a plinth
	plinth.name = "Plinth"
	plinth.position = base
	plinth.rotation_degrees = Vector3(0, 12, 0)
	add(g, plinth)
	add(plinth, inst("res://assets/props/loose_crate.glb", "Model"))
	box_shape(plinth, Vector3(1.24, 1.24, 1.24), Vector3(0, 0.62, 0))
	var top := base + Vector3(0, 1.24, 0)

	# the shaft leans against the crate's east face (towards the stairs), butt on the deck, head on the lid edge
	var a := Area3D.new()
	a.name = "SteelShaft"
	a.set_script(load("res://scripts/weapon_pickup.gd"))
	a.position = base
	a.rotation_degrees = Vector3(0, 12, 0)
	add(g, a)
	var m := inst("res://assets/props/shaft.glb", "Model")
	m.rotation_degrees = Vector3(0, 15, 22)         # tipped 22 deg off vertical, back towards the crate (-X)
	m.position = Vector3(0.98, 0.25, 0.15)            # grip ~0.25 m up; the butt cap rests on the grating
	add(a, m)
	box_shape(a, Vector3(1.1, 1.8, 1.6), Vector3(0.95, 0.9, 0.1))
	var glint := OmniLight3D.new()
	glint.name = "Glint"
	glint.position = Vector3(1.1, 1.0, 0.2)
	glint.light_color = Color(0.75, 0.85, 1.0)
	glint.light_energy = 1.0
	glint.omni_range = 2.6
	glint.light_volumetric_fog_energy = 0.5
	add(a, glint)
	# a cold shaft of light on it, readable through the fog from the stairs above
	var spot := SpotLight3D.new()
	spot.name = "PickupBeam"
	spot.transform = Transform3D(Basis(), top + Vector3(1.6, 7.5, -0.6)).looking_at(top + Vector3(0.9, -0.6, 0.2), Vector3.UP)
	spot.light_color = Color(0.7, 0.8, 1.0)
	spot.light_energy = 5.0
	spot.spot_range = 11.0
	spot.spot_angle = 9.0
	spot.spot_attenuation = 0.6
	spot.light_volumetric_fog_energy = 4.0
	add(g, spot)

# ------------------------------------------------------------------ exits, spawns, player
func build_exits_and_spawns() -> void:
	var t: Array = L["tunnel"]
	var bz: float = L["bottom"]
	var exit := Area3D.new()
	exit.name = "ExitToCavern"
	exit.set_script(load("res://scripts/exit_zone.gd"))
	exit.set("next_scene", "res://scenes/main.tscn")
	exit.set("target_spawn", "FromStart")
	exit.set("once", false)
	exit.position = b2g([t[1] + 0.45, -1.0, bz + 1.2])
	add(main_root, exit)
	box_shape(exit, Vector3(0.8, 2.4, 1.1), Vector3.ZERO)

	var spawns := group(main_root, "Spawns")
	var begin := Marker3D.new()
	begin.name = "Begin"
	begin.position = b2g([-7.6, -1.5, L["top"] + 0.02])
	begin.rotation_degrees = Vector3(0, -90, 0)        # facing east, across the shaft
	begin.add_to_group("spawn_point", true)
	add(spawns, begin)
	var back := Marker3D.new()
	back.name = "FromCavern"
	back.position = b2g([t[1] - 1.9, -1.0, bz + 0.02])
	back.rotation_degrees = Vector3(0, 90, 0)          # facing west, back into the shaft
	back.add_to_group("spawn_point", true)
	add(spawns, back)

	var player: Node3D = load("res://scenes/player.tscn").instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	player.name = "Player"
	player.transform = begin.transform
	player.set("max_safe_fall", 6.0)
	add(main_root, player)

	var tour := Node.new()
	tour.name = "ShotTour"
	tour.set_script(load("res://scripts/shot_tour.gd"))
	add(main_root, tour)
