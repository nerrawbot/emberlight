extends Node3D
## The repaired warden drone (assets/props/drone.glb, art_src/v9_drone.py): orbits the player at a distance and keeps
## their shield up (player.gd: shield / take_damage). Spawned by player.give_drone() / player._ready() as a sibling
## of the player, so it moves in world space and lags behind naturally.
## Shield hit: the core flares and a bubble flashes round the player. Shield down: it sputters, sinks and dims until
## the shield comes back.

const MODEL := "res://assets/props/drone.glb"

@export var orbit_radius := 2.4
@export var orbit_height := 0.75        # above the player's head
@export var orbit_speed := 0.55         # rad/s
@export var follow := 2.6
@export var wall_margin := 0.35

var player: Node3D
var _model: Node3D
var _wl: Node3D
var _wr: Node3D
var _ring: Node3D
var _core_mat: StandardMaterial3D
var _light: OmniLight3D
var _bubble: MeshInstance3D
var _bubble_mat: StandardMaterial3D
var _t := 0.0
var _ang := 0.0
var _flare := 0.0
var _frac := 1.0           # shield fraction (0 = down)
var _prev := Vector3.ZERO
var _ray := PhysicsRayQueryParameters3D.new()

func _ready() -> void:
	_model = load(MODEL).instantiate()
	_model.name = "Model"
	add_child(_model)
	# perf: moving things live on render layer 2 and cast no shadows (shadowed lamps take casters from layer 1 only)
	for g in _model.find_children("*", "GeometryInstance3D", true, false):
		(g as GeometryInstance3D).layers = 2
		(g as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_wl = _model.find_child("DWing_L", true, false) as Node3D
	_wr = _model.find_child("DWing_R", true, false) as Node3D
	_ring = _model.find_child("DRing", true, false) as Node3D
	var core := _model.find_child("DCore", true, false) as MeshInstance3D
	if core and core.get_active_material(0) is StandardMaterial3D:
		_core_mat = core.get_active_material(0).duplicate() as StandardMaterial3D
		_core_mat.emission_enabled = true
		_core_mat.emission = Color(0.55, 0.88, 1.0)
		core.material_override = _core_mat
	_light = OmniLight3D.new()
	_light.light_color = Color(0.6, 0.88, 1.0)
	_light.light_energy = 0.6
	_light.omni_range = 2.6
	_light.light_volumetric_fog_energy = 0.3
	_light.shadow_enabled = false
	add_child(_light)
	# shield bubble (top level: it sits on the player, not on the drone)
	_bubble = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.95
	sm.height = 2.1
	sm.radial_segments = 24
	sm.rings = 12
	_bubble.mesh = sm
	_bubble_mat = StandardMaterial3D.new()
	_bubble_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_bubble_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_bubble_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_bubble_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_bubble_mat.rim_enabled = false
	_bubble_mat.albedo_color = Color(0.55, 0.8, 1.0, 0.0)
	_bubble.material_override = _bubble_mat
	_bubble.layers = 2
	_bubble.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_bubble.top_level = true
	_bubble.visible = false
	add_child(_bubble)
	_ray.collision_mask = 1
	_ang = randf() * TAU
	_prev = global_position

## Snap next to the player (arriving in a scene).
func place_near(p: Node3D) -> void:
	player = p
	global_position = _target(0.0)
	_prev = global_position

func _target(delta: float) -> Vector3:
	_ang += orbit_speed * delta
	var head := player.global_position + Vector3.UP * 1.7
	var r := orbit_radius * (1.0 + 0.12 * sin(_t * 0.43))
	var h := orbit_height + 0.25 * sin(_t * 0.9) - (0.9 if _frac <= 0.0 else 0.0)   # sinks while the shield is down
	var want := head + Vector3(cos(_ang) * r, h, sin(_ang) * r)
	# don't orbit through walls (tunnels, the lift car): pull in to just short of whatever's in the way
	if is_inside_tree():
		_ray.from = head
		_ray.to = want
		var ex: Array[RID] = []
		if player is CollisionObject3D:
			ex.append((player as CollisionObject3D).get_rid())
		_ray.exclude = ex
		var hit := get_world_3d().direct_space_state.intersect_ray(_ray)
		if hit:
			var hp: Vector3 = hit.position
			want = head + (hp - head) * maxf(0.0, 1.0 - wall_margin / maxf(head.distance_to(hp), 0.01))
	return want

## Shield took a hit (player.gd). `down`: it just broke.
func on_shield_hit(down: bool) -> void:
	_flare = 1.0
	_bubble.visible = true
	_bubble_mat.albedo_color.a = 0.45 if down else 0.3

func on_shield(frac: float) -> void:
	_frac = frac

func _process(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as Node3D
		if player == null:
			return
	_t += delta
	var want := _target(delta)
	if global_position.distance_to(want) > 25.0:      # teleports, respawns
		global_position = want
	global_position = global_position.lerp(want, clampf(delta * follow, 0.0, 1.0))
	var vel := (global_position - _prev) / maxf(delta, 0.0001)
	_prev = global_position
	# face where it's going, but keep an eye on the player when hanging about
	var look := Vector2(vel.x, vel.z)
	if look.length() < 0.4:
		var to_p := player.global_position - global_position
		look = Vector2(to_p.x, to_p.z)
	if look.length() > 0.01:
		rotation.y = lerp_angle(rotation.y, atan2(-look.x, -look.y), clampf(delta * 4.0, 0.0, 1.0))
	rotation.x = lerpf(rotation.x, clampf(-vel.y * 0.12, -0.35, 0.35), clampf(delta * 3.0, 0.0, 1.0))
	rotation.z = lerpf(rotation.z, clampf(-Vector3(vel.x, 0, vel.z).dot(global_transform.basis.x) * 0.08, -0.4, 0.4), clampf(delta * 3.0, 0.0, 1.0))
	# wings: a fast shimmer while the shield is up, slow labouring beats while it's down
	var down := _frac <= 0.0
	var flap := sin(_t * (9.0 if down else 34.0))
	if _wl:
		_wl.rotation.z = -flap * (0.6 if down else 0.35) - 0.1
	if _wr:
		_wr.rotation.z = flap * (0.6 if down else 0.35) + 0.1
	if _ring:
		_ring.rotation.y += delta * (0.8 if down else 3.0 + 6.0 * _flare)
	# core: brightness follows the shield; flares on a hit, flickers while down
	_flare = maxf(0.0, _flare - delta * 2.5)
	var e := 1.5 + 6.5 * _frac + 14.0 * _flare
	if down:
		e = 0.6 + (2.5 if randf() < 0.08 else 0.0)
	if _core_mat:
		_core_mat.emission_energy_multiplier = e
	_light.light_energy = 0.15 + 0.08 * e
	# bubble flash round the player
	if _bubble.visible:
		_bubble.global_position = player.global_position + Vector3.UP * 1.0
		_bubble_mat.albedo_color.a = maxf(0.0, _bubble_mat.albedo_color.a - delta * 1.2)
		var s := 1.0 + 0.15 * (1.0 - _bubble_mat.albedo_color.a / 0.45)
		_bubble.scale = Vector3(s, s, s)
		if _bubble_mat.albedo_color.a <= 0.0:
			_bubble.visible = false
