extends Node3D
## Scrap moth drone: drifts in slow loops around an anchor, flaps its tin wings, shies away from the player.

@export var anchor := Vector3.ZERO
@export var radius := 3.0
@export var height_amp := 1.0
@export var speed := 0.35

var _t := 0.0
var _wl: Node3D
var _wr: Node3D
var _light: OmniLight3D
var _core_mat: StandardMaterial3D
var _offset := Vector3.ZERO
var _prev := Vector3.ZERO
var _player: Node3D
var _flap_rate := 20.0

func _ready() -> void:
	# perf: anything moving near a shadowed lamp makes it redraw its shadow map every frame, even if it
	# casts no shadow. Lamps only take shadow casters from layer 1, so moths live on layer 2.
	for g in find_children("*", "GeometryInstance3D", true, false):
		(g as GeometryInstance3D).layers = 2
		(g as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_t = randf() * 100.0
	_flap_rate = randf_range(17.0, 24.0)
	_wl = find_child("Wing_L", true, false) as Node3D
	_wr = find_child("Wing_R", true, false) as Node3D
	_light = get_node_or_null("Glow") as OmniLight3D
	var core := find_child("Core", true, false) as MeshInstance3D
	if core and core.get_active_material(0):
		_core_mat = core.get_active_material(0).duplicate() as StandardMaterial3D
		core.material_override = _core_mat
	global_position = anchor
	_prev = global_position

func _process(delta: float) -> void:
	_t += delta
	if _player == null:
		_player = get_tree().get_first_node_in_group("player") as Node3D
	var p := anchor + Vector3(sin(_t * speed * 1.3) * radius, sin(_t * speed * 2.1) * height_amp + sin(_t * 1.7) * 0.12, cos(_t * speed * 0.9) * radius * 0.7)
	if _player:
		var d := global_position - (_player.global_position + Vector3.UP * 1.5)
		if d.length() < 3.0:
			_offset += d.normalized() * delta * 5.0
	_offset = _offset.move_toward(Vector3.ZERO, delta * 0.5).limit_length(5.0)
	global_position = global_position.lerp(p + _offset, clampf(delta * 1.8, 0.0, 1.0))
	var vel := (global_position - _prev) / maxf(delta, 0.0001)
	_prev = global_position
	if Vector2(vel.x, vel.z).length() > 0.05:
		rotation.y = lerp_angle(rotation.y, atan2(-vel.x, -vel.z), clampf(delta * 3.0, 0.0, 1.0))
	rotation.x = lerpf(rotation.x, clampf(-vel.y * 0.15, -0.4, 0.4), clampf(delta * 3.0, 0.0, 1.0))
	var flap := sin(_t * _flap_rate)
	if _wl:
		_wl.rotation.z = -flap * 0.75
	if _wr:
		_wr.rotation.z = flap * 0.75
	var pulse := 0.75 + 0.25 * sin(_t * 2.7)
	if _light:
		_light.light_energy = 0.9 * pulse
	if _core_mat:
		_core_mat.emission_energy_multiplier = 8.0 * pulse
