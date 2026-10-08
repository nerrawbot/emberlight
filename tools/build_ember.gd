extends SceneTree
## v19: a stub for the next major area, Ember (the city of Emberlight + the Ember Fields), so the mast's launch into
## the high wind (scripts/mast/summit.gd) has somewhere to land: a turf landing pad at the edge of the Fields at dusk,
## a lamp post, Emberlight's lamps on the horizon, a "to be continued" arrival banner. Spawn: FromHighWind.
## The real area replaces this; keep the spawn name.
##   tools\godot.cmd --headless --script res://tools/build_ember.gd

var main_root: Node3D

func add(parent: Node, child: Node) -> Node:
	parent.add_child(child)
	child.owner = main_root
	return child

func mat(c: Color, emit := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.9
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = emit
	return m

func _init() -> void:
	main_root = Node3D.new()
	main_root.name = "Ember"

	var intro := Node.new()          # power_grid.gd doubles as the arrival banner (as on the surface)
	intro.name = "PowerGrid"
	intro.set_script(load("res://scripts/power_grid.gd"))
	intro.set("intro_text", "EMBER FIELDS\nthe edge of the lamps  —  to be continued")
	add(main_root, intro)

	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.16, 0.1, 0.16)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.42, 0.3, 0.38)
	env.ambient_light_energy = 0.8
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.fog_enabled = true
	env.fog_light_color = Color(0.38, 0.22, 0.24)
	env.fog_density = 0.012
	env.fog_sky_affect = 1.0
	we.environment = env
	add(main_root, we)

	var sun := DirectionalLight3D.new()
	sun.name = "Dusk"
	sun.light_color = Color(1.0, 0.55, 0.35)
	sun.light_energy = 0.35
	sun.rotation_degrees = Vector3(-12, 140, 0)
	add(main_root, sun)

	# the Fields: a wide dark ground, and the landing pad (a raised turf disc ringed with stones)
	var ground := StaticBody3D.new()
	ground.name = "Ground"
	add(main_root, ground)
	var gm := MeshInstance3D.new()
	gm.name = "Mesh"
	var pm := PlaneMesh.new()
	pm.size = Vector2(800, 800)
	pm.material = mat(Color(0.14, 0.11, 0.1))
	gm.mesh = pm
	add(ground, gm)
	var gcs := CollisionShape3D.new()
	gcs.name = "CollisionShape3D"
	var gb := BoxShape3D.new()
	gb.size = Vector3(800, 1, 800)
	gcs.shape = gb
	gcs.position = Vector3(0, -0.5, 0)
	add(ground, gcs)
	var pad := StaticBody3D.new()
	pad.name = "LandingPad"
	add(main_root, pad)
	var pmi := MeshInstance3D.new()
	pmi.name = "Mesh"
	var cm := CylinderMesh.new()
	cm.top_radius = 9.0
	cm.bottom_radius = 9.6
	cm.height = 0.8
	cm.material = mat(Color(0.25, 0.27, 0.16))
	pmi.mesh = cm
	pmi.position = Vector3(0, 0.4, 0)
	add(pad, pmi)
	var pcs := CollisionShape3D.new()
	pcs.name = "CollisionShape3D"
	var cs := CylinderShape3D.new()
	cs.radius = 9.3
	cs.height = 0.8
	pcs.shape = cs
	pcs.position = Vector3(0, 0.4, 0)
	add(pad, pcs)
	for i in 14:
		var a := TAU * i / 14.0
		var st := MeshInstance3D.new()
		st.name = "Stone_%d" % i
		var bm := BoxMesh.new()
		bm.size = Vector3(0.7, 0.5 + 0.3 * float(i % 3), 0.5)
		bm.material = mat(Color(0.3, 0.27, 0.3))
		st.mesh = bm
		st.position = Vector3(cos(a) * 9.2, 0.9, sin(a) * 9.2)
		st.rotation.y = -a
		add(main_root, st)

	# a lamp post on the pad's edge, lit (someone knew you were coming)
	var post := MeshInstance3D.new()
	post.name = "LampPost"
	var pc := CylinderMesh.new()
	pc.top_radius = 0.07
	pc.bottom_radius = 0.1
	pc.height = 3.4
	pc.material = mat(Color(0.12, 0.1, 0.1))
	post.mesh = pc
	post.position = Vector3(3.0, 0.8 + 1.7, -5.5)
	add(main_root, post)
	var bulb := MeshInstance3D.new()
	bulb.name = "Lamp"
	var sp := SphereMesh.new()
	sp.radius = 0.22
	sp.height = 0.44
	sp.material = mat(Color(1.0, 0.62, 0.3), 6.0)
	bulb.mesh = sp
	bulb.position = Vector3(3.0, 4.35, -5.5)
	add(main_root, bulb)
	var ol := OmniLight3D.new()
	ol.name = "LampLight"
	ol.light_color = Color(1.0, 0.65, 0.35)
	ol.light_energy = 2.5
	ol.omni_range = 14.0
	ol.position = Vector3(3.0, 4.2, -5.5)
	add(main_root, ol)

	# Emberlight's lamps on the horizon, north (-Z)
	var city := Node3D.new()
	city.name = "Emberlight"
	add(main_root, city)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for i in 28:
		var l := MeshInstance3D.new()
		l.name = "Lamp_%d" % i
		var s := SphereMesh.new()
		var r := rng.randf_range(0.6, 1.6)
		s.radius = r
		s.height = r * 2.0
		s.material = mat(Color(1.0, rng.randf_range(0.5, 0.75), 0.3), rng.randf_range(4.0, 9.0))
		l.mesh = s
		l.position = Vector3(rng.randf_range(-90, 90), rng.randf_range(2, 26), -rng.randf_range(160, 230))
		add(city, l)

	var spawns := Node3D.new()
	spawns.name = "Spawns"
	add(main_root, spawns)
	var m := Marker3D.new()
	m.name = "FromHighWind"
	m.position = Vector3(0, 0.85, 2.0)
	m.rotation_degrees = Vector3(0, 0, 0)          # facing -Z, the city
	m.add_to_group("spawn_point", true)
	m.add_to_group("respawn_point", true)
	add(spawns, m)

	var player: Node3D = load("res://scenes/player.tscn").instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	player.name = "Player"
	player.transform = m.transform
	add(main_root, player)

	var ps := PackedScene.new()
	ps.pack(main_root)
	print("ember saved: ", ResourceSaver.save(ps, "res://scenes/ember.tscn"))
	quit()
