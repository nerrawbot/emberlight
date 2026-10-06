extends CharacterBody3D
## Scrap crawler. Wanders around its home, stops to watch the player, scatters when approached.
## Legs are animated procedurally (tripod gait) from the imported Leg_* nodes.

@export var home := Vector3.ZERO
@export var roam_radius := 5.0
@export var walk_speed := 1.1
@export var flee_speed := 3.6
@export var scare_distance := 4.0
@export var model_scale := 1.0

enum State { IDLE, WALK, FLEE, WATCH }
var state := State.IDLE
var _timer := 0.0
var _target := Vector3.ZERO
var _phase := 0.0
var _legs: Array = []
var _body: Node3D
var _body_base_y := 0.0
var _eye_mat: StandardMaterial3D
var _player: Node3D
var _ray: RayCast3D
var _gravity := 9.8
var _stuck := 0.0
var _last := Vector3.ZERO
# perf: anything moving near a shadowed lamp makes it re-render its shadow map each frame. Lamps only
# take shadow casters from layer 1, so scuttlers sit on layer 2 (no shadow) unless near the player;
# far ones also think at a quarter rate.
const SHADOW_DIST := 10.0
const FAR_DIST := 35.0
var _meshes: Array[GeometryInstance3D] = []
var _shadow_on := true
var _lod_t := 0.0
var _far := false
var _tick := 0
var _knock := Vector3.ZERO
var _stun := 0.0

func _ready() -> void:
	collision_layer = 8
	collision_mask = 1
	floor_snap_length = 0.3
	floor_max_angle = deg_to_rad(50)
	var model := get_node("Model") as Node3D
	model.scale = Vector3.ONE * model_scale
	for n in ["L0", "L1", "L2", "R0", "R1", "R2"]:
		var leg := model.find_child("Leg_" + n, true, false) as Node3D
		if leg:
			var grp := (int(n.substr(1)) + (0 if n.begins_with("L") else 1)) % 2
			_legs.append({"node": leg, "base": leg.rotation, "side": signf(leg.position.x), "grp": grp})
	_body = model.find_child("Body", true, false) as Node3D
	if _body:
		_body_base_y = _body.position.y
	var eye := model.find_child("Eye", true, false) as MeshInstance3D
	if eye:
		var m := eye.get_active_material(0)
		if m:
			_eye_mat = m.duplicate() as StandardMaterial3D
			eye.material_override = _eye_mat
	_ray = RayCast3D.new()
	add_child(_ray)
	_ray.position = Vector3(0, 0.5 * model_scale, -0.6 * model_scale)
	_ray.target_position = Vector3(0, -1.4, 0)
	_ray.collision_mask = 1
	_ray.enabled = true
	_phase = randf() * TAU
	rotation.y = randf() * TAU
	for g in model.find_children("*", "GeometryInstance3D", true, false):
		_meshes.append(g)
	_tick = randi() % 4
	_lod_t = randf() * 0.5
	_update_lod(999.0)
	_go_idle()

func _update_lod(dist: float) -> void:
	_far = dist > FAR_DIST
	var want := dist < SHADOW_DIST
	if want == _shadow_on:
		return
	_shadow_on = want
	for g in _meshes:
		g.layers = 1 if want else 2
		g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if want else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

## Whacked by the player's stick: knocked back, then it bolts.
func take_hit(by: Node3D, dir: Vector3) -> void:
	_knock = Vector3(dir.x, 0, dir.z).normalized() * 5.0
	velocity.y = 2.5
	_stun = 0.35
	_flee(by.global_position)
	if _eye_mat:
		_eye_mat.emission_energy_multiplier = 30.0

func _go_idle() -> void:
	state = State.IDLE
	_timer = randf_range(0.8, 3.5)

func _pick_target(away_from_wall := false) -> void:
	var to_home := home - global_position
	to_home.y = 0
	if to_home.length() > roam_radius * 1.3:
		_target = home
	else:
		var a := randf() * TAU
		if away_from_wall:
			a = rotation.y + PI + randf_range(-0.9, 0.9)
			_target = global_position + Vector3(-sin(a), 0, -cos(a)) * randf_range(1.5, 3.0)
			state = State.WALK
			_timer = 6.0
			return
		_target = home + Vector3(cos(a), 0, sin(a)) * randf_range(0.5, roam_radius)
	state = State.WALK
	_timer = 9.0

func _flee(from: Vector3) -> void:
	var away := global_position - from
	away.y = 0
	if away.length() < 0.01:
		away = Vector3(1, 0, 0)
	away = away.normalized().rotated(Vector3.UP, randf_range(-0.6, 0.6))
	_target = global_position + away * randf_range(4.0, 7.0)
	state = State.FLEE
	_timer = randf_range(1.5, 2.5)

func _physics_process(delta: float) -> void:
	if _player == null:
		_player = get_tree().get_first_node_in_group("player") as Node3D
	var to_player := Vector3(999, 0, 0)
	if _player:
		to_player = _player.global_position - global_position
	_lod_t -= delta
	if _lod_t <= 0.0:
		_lod_t = 0.5
		_update_lod(to_player.length())
	var step := 1.0
	if _far:
		_tick = (_tick + 1) % 4
		if _tick != 0:
			return
		step = 4.0
		delta *= step
	if _stun > 0.0:   # knocked back: tumble, then the flee picked in take_hit() carries on
		_stun -= delta
		velocity = Vector3(_knock.x, velocity.y - _gravity * delta, _knock.z)
		move_and_slide()
		_animate(delta, 3.0)
		return
	var pd := Vector2(to_player.x, to_player.z).length() if absf(to_player.y) < 2.5 else 999.0
	_timer -= delta

	match state:
		State.IDLE:
			if pd < scare_distance:
				_flee(_player.global_position)
			elif pd < scare_distance * 2.5 and randf() < 0.02:
				state = State.WATCH
				_timer = randf_range(1.5, 3.5)
			elif _timer <= 0.0:
				_pick_target()
		State.WATCH:
			if pd < scare_distance:
				_flee(_player.global_position)
			elif _timer <= 0.0:
				_go_idle()
		State.WALK:
			if pd < scare_distance:
				_flee(_player.global_position)
			elif _timer <= 0.0:
				_go_idle()
		State.FLEE:
			if _timer <= 0.0:
				if pd < scare_distance * 1.3:
					_flee(_player.global_position)
				else:
					_go_idle()

	var dir := Vector3.ZERO
	var speed := 0.0
	if state == State.WALK or state == State.FLEE:
		dir = _target - global_position
		dir.y = 0
		if dir.length() < 0.35:
			_go_idle()
			dir = Vector3.ZERO
		else:
			dir = dir.normalized()
			speed = walk_speed if state == State.WALK else flee_speed

	var face := dir
	if state == State.WATCH and _player:
		face = Vector3(to_player.x, 0, to_player.z)
	if face.length() > 0.01:
		var yaw := atan2(-face.x, -face.z)
		rotation.y = lerp_angle(rotation.y, yaw, clampf(delta * (9.0 if state == State.FLEE else 4.0), 0.0, 1.0))

	var fwd := -global_transform.basis.z
	fwd.y = 0
	fwd = fwd.normalized()
	var align := clampf(fwd.dot(dir), 0.0, 1.0) if speed > 0.0 else 0.0
	var v := fwd * speed * align

	if speed > 0.0 and is_on_floor() and not _ray.is_colliding():
		v = Vector3.ZERO      # edge ahead: turn around
		_pick_target(true)

	_knock = _knock.move_toward(Vector3.ZERO, 14.0 * delta)
	velocity.x = (v.x + _knock.x) * step   # move_and_slide uses the physics step, so cover the skipped ticks
	velocity.z = (v.z + _knock.z) * step
	if is_on_floor() and velocity.y <= 0.0:
		velocity.y = -0.3
	else:
		velocity.y -= _gravity * delta
	move_and_slide()
	velocity.x = v.x
	velocity.z = v.z
	if speed > 0.0 and is_on_wall():
		_pick_target(true)

	# stuck detection
	if speed > 0.0 and global_position.distance_to(_last) < speed * delta * 0.2:
		_stuck += delta
		if _stuck > 1.0:
			_stuck = 0.0
			_pick_target(true)
	else:
		_stuck = 0.0
	_last = global_position
	_animate(delta, Vector2(v.x, v.z).length())

func _animate(delta: float, spd: float) -> void:
	var amp := clampf(spd / walk_speed, 0.0, 1.8)
	_phase += delta * (3.0 + spd * 7.5)
	for L in _legs:
		var ph: float = _phase + (PI if L.grp == 1 else 0.0)
		var swing := sin(ph) * 0.38 * minf(amp, 1.2)
		var lift := maxf(0.0, cos(ph)) * 0.45 * minf(amp, 1.2)
		var idle := sin(_phase * 0.6 + L.side * 2.0 + L.grp) * 0.05 * (1.0 - minf(amp, 1.0))
		var b: Vector3 = L.base
		L.node.rotation = Vector3(b.x, b.y + (swing + idle) * L.side, b.z + lift * L.side)
	if _body:
		_body.position.y = _body_base_y + absf(sin(_phase)) * 0.03 * amp
		_body.rotation.z = sin(_phase) * 0.04 * amp
		_body.rotation.x = -0.08 * minf(amp, 1.0) if state == State.FLEE else 0.0
	if _eye_mat:
		var base := 16.0 if state == State.FLEE else (11.0 if state == State.WATCH else 6.0)
		_eye_mat.emission_energy_multiplier = base * (0.8 + 0.2 * sin(_phase * 0.4))
