extends Node3D
## The tripod's charged bolt: a slow glowing slug you can sidestep or dash out of. Each physics tick it sweeps the
## segment it travels: passing within `radius` of the player's body hurts them, anything solid bursts it.

const DeathFx := preload("res://scripts/creatures/death_fx.gd")

var velocity := Vector3.ZERO
var damage := 15.0
var radius := 0.5
var life := 3.0
var color := Color(1.0, 0.25, 0.12)
var shooter: Node3D

func _ready() -> void:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0, 0, 0)
	m.emission_enabled = true
	m.emission = color.lerp(Color(1, 0.9, 0.75), 0.35)
	m.emission_energy_multiplier = 9.0
	var core := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.11
	s.height = 0.22
	s.radial_segments = 12
	s.rings = 6
	s.material = m
	core.mesh = s
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	core.layers = 2
	add_child(core)
	var halo := MeshInstance3D.new()
	var hm := StandardMaterial3D.new()
	hm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	hm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	hm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	hm.albedo_texture = DeathFx.soft_tex()
	hm.albedo_color = color * 1.6
	var q := QuadMesh.new()
	q.size = Vector2(0.8, 0.8)
	q.material = hm
	halo.mesh = q
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	halo.layers = 2
	add_child(halo)
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = 2.0
	light.omni_range = 4.0
	light.shadow_enabled = false
	add_child(light)
	# a short smoky-red trail left in world space
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 180.0
	pm.initial_velocity_min = 0.0
	pm.initial_velocity_max = 0.8
	pm.gravity = Vector3.ZERO
	pm.scale_curve = DeathFx._curve([Vector2(0, 1), Vector2(1, 0)])
	var tm := StandardMaterial3D.new()
	tm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	tm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	tm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	tm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	tm.albedo_texture = DeathFx.soft_tex()
	tm.albedo_color = color * 1.2
	var tq := QuadMesh.new()
	tq.size = Vector2(0.3, 0.3)
	tq.material = tm
	var trail := GPUParticles3D.new()
	trail.amount = 48
	trail.lifetime = 0.35
	trail.local_coords = false
	trail.process_material = pm
	trail.draw_pass_1 = tq
	trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	trail.layers = 2
	trail.visibility_aabb = AABB(Vector3(-30, -30, -30), Vector3(60, 60, 60))
	add_child(trail)

func _physics_process(delta: float) -> void:
	life -= delta
	if life <= 0.0:
		_burst(global_position)
		return
	var a := global_position
	var b := a + velocity * delta
	var p := get_tree().get_first_node_in_group("player") as Node3D
	if p and p.has_method("is_alive") and p.is_alive():
		# the player as a vertical segment through their body
		var pts := Geometry3D.get_closest_points_between_segments(a, b, p.global_position + Vector3.UP * 0.3, p.global_position + Vector3.UP * 1.5)
		if pts[0].distance_to(pts[1]) < radius:
			var push := Vector3(velocity.x, 0, velocity.z).normalized() * 3.5 + Vector3.UP * 1.5
			p.take_damage(damage, "", push)
			_burst(pts[0])
			return
	var q := PhysicsRayQueryParameters3D.create(a, b, 1)
	var ex: Array[RID] = []
	if p:
		ex.append((p as CollisionObject3D).get_rid())
	if shooter and is_instance_valid(shooter):
		ex.append((shooter as CollisionObject3D).get_rid())
	q.exclude = ex
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		_burst(hit.position)
		return
	global_position = b

func _burst(at: Vector3) -> void:
	DeathFx.sparks(self, at, color, 22, 6.0)
	queue_free()
