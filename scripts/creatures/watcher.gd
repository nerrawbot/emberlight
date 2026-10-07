extends Node3D
## Bolted-on scrap sentinel: idly sweeps a thin searchlight, then locks on and tracks the player
## when it has line of sight.

@export var sight_range := 16.0
@export var beam_color := Color(0.55, 0.8, 1.0)

var _neck: Node3D
var _head: Node3D
var _lens_mat: StandardMaterial3D
var _spot: SpotLight3D
var _t := 0.0
var _yaw := 0.0
var _pitch := 0.0
var _alert := 0.0
var _player: Node3D
var _scan_speed := 0.35
var talking := false        # set by its watcher_talk.gd child: lock onto the player and flicker the lens as it speaks

func _ready() -> void:
	_t = randf() * 20.0
	_scan_speed = randf_range(0.25, 0.45)
	# perf: the head moves every frame, which would force nearby lamps to redraw their shadow maps;
	# lamps only take shadow casters from layer 1 (see build_main.gd shadow_fade())
	for g in find_children("*", "GeometryInstance3D", true, false):
		(g as GeometryInstance3D).layers = 2
		(g as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_neck = find_child("Neck", true, false) as Node3D
	_head = find_child("Head", true, false) as Node3D
	var lens := find_child("Lens", true, false) as MeshInstance3D
	if lens:
		if lens.get_active_material(0):
			_lens_mat = lens.get_active_material(0).duplicate() as StandardMaterial3D
			lens.material_override = _lens_mat
		_spot = SpotLight3D.new()
		_spot.name = "Beam"
		lens.add_child(_spot)
		_spot.position = Vector3(0, 0, -0.03)
		_spot.light_color = beam_color
		_spot.light_energy = 1.0
		_spot.spot_range = sight_range
		_spot.spot_angle = 8.0
		_spot.spot_attenuation = 1.2
		_spot.light_volumetric_fog_energy = 5.0
		_spot.shadow_enabled = false

func _physics_process(delta: float) -> void:
	_t += delta
	if _neck == null or _head == null:
		return
	if _player == null:
		_player = get_tree().get_first_node_in_group("player") as Node3D
	var tracking := false
	var tgt := Vector3.ZERO
	if _player:
		tgt = _player.global_position + Vector3.UP * 1.5
		var eye := _head.global_position
		if talking:
			tracking = true
		elif eye.distance_to(tgt) < sight_range:
			var q := PhysicsRayQueryParameters3D.create(eye, tgt, 1)
			q.exclude = [_player.get_rid()]
			tracking = get_world_3d().direct_space_state.intersect_ray(q).is_empty()
	var want_yaw: float
	var want_pitch: float
	if tracking:
		var base := _neck.get_parent() as Node3D
		var lp := base.global_transform.affine_inverse() * tgt - _neck.position
		want_yaw = atan2(-lp.x, -lp.z)
		var v := lp.rotated(Vector3.UP, -want_yaw) - _head.position
		want_pitch = atan2(v.y, maxf(0.05, -v.z))
		_alert = move_toward(_alert, 1.0, delta * 2.5)
	else:
		want_yaw = sin(_t * _scan_speed) * 1.3
		want_pitch = -0.2 + sin(_t * 0.23) * 0.25
		_alert = move_toward(_alert, 0.0, delta * 0.8)
	_yaw = lerp_angle(_yaw, want_yaw, clampf(delta * (5.0 if tracking else 1.0), 0.0, 1.0))
	_pitch = lerpf(_pitch, clampf(want_pitch, -1.2, 0.9), clampf(delta * 4.0, 0.0, 1.0))
	_neck.rotation.y = _yaw
	_head.rotation.x = _pitch
	if _spot:
		_spot.light_energy = lerpf(0.9, 2.6, _alert)
		_spot.spot_angle = lerpf(9.0, 6.0, _alert)
	if _lens_mat:
		_lens_mat.emission_energy_multiplier = lerpf(4.0, 14.0, _alert) * (1.0 if _alert < 0.9 or fmod(_t, 0.4) < 0.3 else 0.5)
		if talking:
			_lens_mat.emission_energy_multiplier *= randf_range(0.55, 1.15)
