extends RefCounted
## One-shot effects for the surface hostiles (static helpers, nothing to instance):
##   burst()  - an enemy killed by the player: a flash, sparks, embers, a smoke puff and the model flung apart
##              as tumbling debris. Counts, colours and speeds are randomised each time.
##   sparks() - a small spark puff (bolt impacts, stomps, a skate clipping the ground).
## Every node made here is parented to the current scene and frees itself.

static var _soft: GradientTexture2D

static func _host(n: Node) -> Node:
	var t := n.get_tree()
	return t.current_scene if t.current_scene else t.root

static func _free_after(node: Node, sec: float) -> void:
	node.get_tree().create_timer(sec, false).timeout.connect(node.queue_free)

static func soft_tex() -> GradientTexture2D:
	if _soft == null:
		var gr := Gradient.new()
		gr.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
		gr.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.5), Color(1, 1, 1, 0)])
		_soft = GradientTexture2D.new()
		_soft.gradient = gr
		_soft.fill = GradientTexture2D.FILL_RADIAL
		_soft.fill_from = Vector2(0.5, 0.5)
		_soft.fill_to = Vector2(1.0, 0.5)
		_soft.width = 64
		_soft.height = 64
	return _soft

static func _curve(points: Array) -> CurveTexture:
	var c := Curve.new()
	for p in points:
		c.add_point(p)
	var t := CurveTexture.new()
	t.curve = c
	return t

static func _ramp(cols: Array, offs: Array) -> GradientTexture1D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array(offs)
	g.colors = PackedColorArray(cols)
	var t := GradientTexture1D.new()
	t.gradient = g
	return t

static func _emitter(name: String, amount: int, life: float, pm: ParticleProcessMaterial, mesh: Mesh) -> GPUParticles3D:
	var e := GPUParticles3D.new()
	e.name = name
	e.amount = maxi(1, amount)
	e.lifetime = life
	e.one_shot = true
	e.explosiveness = 0.92
	e.randomness = 0.4
	e.process_material = pm
	e.draw_pass_1 = mesh
	e.visibility_aabb = AABB(Vector3(-8, -8, -8), Vector3(16, 16, 16))
	e.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	e.layers = 2
	return e

## Hot streaks thrown out in every direction, falling under gravity and shrinking out.
static func _spark_emitter(count: int, color: Color, speed: float, life: float) -> GPUParticles3D:
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 180.0
	pm.initial_velocity_min = speed * 0.35
	pm.initial_velocity_max = speed
	pm.gravity = Vector3(0, -9.8, 0)
	pm.damping_min = 0.5
	pm.damping_max = 2.0
	pm.particle_flag_align_y = true
	pm.scale_min = 0.5
	pm.scale_max = 1.4
	pm.scale_curve = _curve([Vector2(0, 1), Vector2(0.7, 0.7), Vector2(1, 0)])
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0, 0, 0)
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = 7.0
	var b := BoxMesh.new()
	b.size = Vector3(0.022, 0.2, 0.022)
	b.material = m
	return _emitter("Sparks", count, life, pm, b)

static func sparks(near: Node, pos: Vector3, color: Color, count := 14, speed := 5.0) -> void:
	var e := _spark_emitter(count, color, speed, 0.5)
	_host(near).add_child(e)
	e.global_position = pos
	e.emitting = true
	_free_after(e, 1.2)

## Kill burst at the enemy (call before it frees itself; `model` is its imported model).
static func burst(enemy: Node3D, model: Node3D, glow: Color) -> void:
	var host := _host(enemy)
	var c := enemy.global_position
	if model:
		var aabb := AABB()
		var first := true
		for mi in model.find_children("*", "MeshInstance3D", true, false):
			var g := mi as MeshInstance3D
			var a := g.global_transform * g.get_aabb()
			aabb = a if first else aabb.merge(a)
			first = false
		if not first:
			c = aabb.get_center()
	var fx := Node3D.new()
	fx.name = "DeathFx"
	host.add_child(fx)
	fx.global_position = c
	# the palette shifts a little every time: the enemy's glow, white-hot, or a molten orange
	var hot := [glow, glow.lerp(Color(1, 0.95, 0.8), randf_range(0.3, 0.7)), Color(1.0, randf_range(0.45, 0.7), 0.15)]
	# sparks: two or three bursts of different heat and speed
	for i in randi_range(2, 3):
		var s := _spark_emitter(randi_range(30, 70), hot[randi() % hot.size()], randf_range(7.0, 13.0), randf_range(0.5, 1.1))
		fx.add_child(s)
		s.emitting = true
	# embers: slow glowing motes that drift up and wink out
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.6
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 70.0
	pm.initial_velocity_min = 0.6
	pm.initial_velocity_max = 2.8
	pm.gravity = Vector3(0, 0.6, 0)
	pm.turbulence_enabled = true
	pm.turbulence_influence_max = 0.15
	pm.scale_min = 0.4
	pm.scale_max = 1.3
	pm.scale_curve = _curve([Vector2(0, 0.2), Vector2(0.15, 1), Vector2(1, 0)])
	var em := StandardMaterial3D.new()
	em.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	em.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	em.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	em.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	em.albedo_texture = soft_tex()
	em.albedo_color = hot[randi() % hot.size()] * 2.5
	var eq := QuadMesh.new()
	eq.size = Vector2(0.09, 0.09)
	eq.material = em
	var embers := _emitter("Embers", randi_range(25, 55), randf_range(1.6, 2.6), pm, eq)
	embers.explosiveness = 0.7
	fx.add_child(embers)
	embers.emitting = true
	# smoke: a dark puff that rolls up and spreads
	var sp := ParticleProcessMaterial.new()
	sp.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	sp.emission_sphere_radius = 0.5
	sp.direction = Vector3(0, 1, 0)
	sp.spread = 60.0
	sp.initial_velocity_min = 0.4
	sp.initial_velocity_max = 1.8
	sp.gravity = Vector3(0, 0.35, 0)
	sp.damping_min = 0.4
	sp.damping_max = 0.9
	sp.angle_min = -180.0
	sp.angle_max = 180.0
	sp.scale_min = 0.8
	sp.scale_max = 1.6
	sp.scale_curve = _curve([Vector2(0, 0.5), Vector2(1, 1.0)])
	var grey := randf_range(0.14, 0.26)
	sp.color_ramp = _ramp([Color(grey * 1.6, grey * 1.3, grey, 0.0), Color(grey, grey, grey * 1.25, 0.55), Color(grey, grey, grey * 1.3, 0.0)], [0.0, 0.15, 1.0])
	var sm := StandardMaterial3D.new()
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	sm.vertex_color_use_as_albedo = true
	sm.albedo_texture = soft_tex()
	sm.roughness = 1.0
	var sq := QuadMesh.new()
	sq.size = Vector2(1.6, 1.6)
	sq.material = sm
	var smoke := _emitter("Smoke", randi_range(10, 18), randf_range(1.8, 2.6), sp, sq)
	smoke.explosiveness = 0.85
	fx.add_child(smoke)
	smoke.emitting = true
	# flash
	var light := OmniLight3D.new()
	light.light_color = glow.lerp(Color(1, 0.9, 0.7), 0.4)
	light.light_energy = randf_range(6.0, 9.0)
	light.omni_range = 9.0
	light.shadow_enabled = false
	light.light_volumetric_fog_energy = 2.0
	fx.add_child(light)
	var tw := fx.create_tween()
	tw.tween_property(light, "light_energy", 0.0, 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
	_free_after(fx, 3.5)
	if model:
		_debris(host, model, c)

## The model's parts as rigid bodies: thrown out from the centre, tumbling, then shrinking away.
## (layer 0: they land on the world but never block the player or the interact ray.)
static func _debris(host: Node, model: Node3D, centre: Vector3) -> void:
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var src := mi as MeshInstance3D
		if randf() < 0.12:     # some bits just vaporise
			continue
		var aabb := src.get_aabb()
		var gx := src.global_transform.orthonormalized()
		var rb := RigidBody3D.new()
		rb.name = "Debris"
		rb.add_to_group("debris")
		rb.collision_layer = 0
		rb.collision_mask = 1
		rb.mass = clampf(aabb.size.length() * 3.0, 0.5, 6.0)
		rb.transform = Transform3D(gx.basis, gx * aabb.get_center())
		var m := MeshInstance3D.new()
		m.mesh = src.mesh
		m.material_override = src.material_override
		for s in src.mesh.get_surface_count():
			var o := src.get_surface_override_material(s)
			if o:
				m.set_surface_override_material(s, o)
		m.position = -aabb.get_center()
		rb.add_child(m)
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = (aabb.size * 0.8).max(Vector3(0.08, 0.08, 0.08))
		cs.shape = bs
		rb.add_child(cs)
		host.add_child(rb)
		var out := rb.global_position - centre
		out.y = 0.0
		out = out.normalized() if out.length() > 0.05 else Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized()
		rb.linear_velocity = out * randf_range(2.0, 6.5) + Vector3.UP * randf_range(2.5, 6.0)
		rb.angular_velocity = Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * randf_range(4.0, 10.0)
		var tw := rb.create_tween()
		tw.tween_interval(randf_range(2.2, 3.8))
		tw.tween_property(m, "scale", Vector3.ONE * 0.01, 0.7).set_ease(Tween.EASE_IN)
		tw.tween_callback(rb.queue_free)
