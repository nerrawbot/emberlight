extends "res://scripts/creatures/enemy.gd"
## Skate: a hovering, ray-shaped scrap drone (assets/creatures/skate.glb, art_src/v7_enemies.py).
## It drifts about a few metres up. When it spots the player it circles them, then winds up: it rises, its core
## flares and the wings flutter. Then it dives through where they stand and hurts them on contact. After a dive it
## hangs low and wobbling for about a second, inside swing reach. A hit knocks it away and breaks off a dive.

const MODEL := "res://assets/creatures/skate.glb"

@export var cruise_speed := 3.5
@export var orbit_speed := 6.0
@export var orbit_radius := 7.0
@export var dive_speed := 16.0
@export var windup_time := 0.75
@export var hover_height := 3.4      # above the ground while patrolling
@export var stalk_height := 2.4      # above the player while circling

enum S { PATROL, STALK, WINDUP, DIVE, RECOVER, STAGGER }
var state := S.PATROL
var _t := 0.0
var _time := 0.0
var _target := Vector3.ZERO
var _orbit := 1.0
var _dive_to := Vector3.ZERO
var _dive_dir := Vector3.FORWARD
var _dive_hit := false
var _ground_y := 0.0
var _ground_t := 0.0
var _void := false
var _yaw := 0.0
var _yaw_rate := 0.0
var _pitch := 0.0
var _roll := 0.0
var _flap := 0.0

var _wings: Array[Node3D] = []
var _tails: Array = []        # [[seg0, seg1, seg2], [...]]
var _core_mat: StandardMaterial3D
var _core_light: OmniLight3D
var _glow := 6.0

func _init() -> void:
	max_health = 85.0      # three swings at 30
	sight_range = 28.0
	bar_height = 1.0
	glow_color = Color(1.0, 0.55, 0.16)

func _build() -> void:
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	wall_min_slide_angle = 0.0
	_model = (load(MODEL) as PackedScene).instantiate() as Node3D
	_model.name = "Model"
	add_child(_model)
	var shape := CollisionShape3D.new()
	var sp := SphereShape3D.new()
	sp.radius = 0.6
	shape.shape = sp
	add_child(shape)
	for n in ["Skate_WingL", "Skate_WingR"]:
		_wings.append(_model.find_child(n, true, false) as Node3D)
	for side in ["L", "R"]:
		var chain: Array[Node3D] = []
		for k in 3:
			chain.append(_model.find_child("Skate_Tail%s%d" % [side, k], true, false) as Node3D)
		_tails.append(chain)
	# one emissive material drives the core and the sensor eyes (both use M_SkateCore)
	var core := _model.find_child("Skate_Core", true, false) as MeshInstance3D
	if core and core.get_active_material(0):
		_core_mat = core.get_active_material(0).duplicate() as StandardMaterial3D
		for mi in _model.find_children("*", "MeshInstance3D", true, false):
			var g := mi as MeshInstance3D
			for s in g.mesh.get_surface_count():
				var m := g.mesh.surface_get_material(s)
				if m and m.resource_name == core.get_active_material(0).resource_name:
					g.set_surface_override_material(s, _core_mat)
	_core_light = OmniLight3D.new()
	_core_light.light_color = glow_color
	_core_light.light_energy = 0.8
	_core_light.omni_range = 4.0
	_core_light.shadow_enabled = false
	_core_light.position = Vector3(0, -0.35, 0)
	add_child(_core_light)
	_time = randf() * 10.0
	_yaw = rotation.y          # the spawn heading; the body itself stays unrotated (the model turns)
	rotation = Vector3.ZERO
	_orbit = 1.0 if randf() < 0.5 else -1.0
	_ground_y = global_position.y - hover_height
	_pick_patrol()

func _pick_patrol() -> void:
	_target = wander_target(12.0)
	_t = randf_range(4.0, 8.0)

func _enter(s: int) -> void:
	state = s
	match s:
		S.STALK:
			_t = randf_range(1.6, 3.0)
		S.WINDUP:
			_t = windup_time
			_dive_to = player_chest()
		S.DIVE:
			_dive_dir = (_dive_to - global_position).normalized()
			_t = clampf(global_position.distance_to(_dive_to) / dive_speed + 0.3, 0.35, 1.2)
			_dive_hit = false
		S.RECOVER:
			_t = randf_range(0.9, 1.3)
		S.PATROL:
			home = global_position
			_pick_patrol()

func _on_hit(_by: Node3D, dir: Vector3) -> void:
	velocity = Vector3(dir.x, 0, dir.z).normalized() * 7.0 + Vector3.UP * 2.5
	state = S.STAGGER
	_t = 0.45
	_roll += 1.2 * (1.0 if randf() < 0.5 else -1.0)

func lose_target() -> void:
	super.lose_target()
	if state != S.PATROL:
		_enter(S.PATROL)

func _think(delta: float) -> void:
	_time += delta
	_t -= delta
	update_sight(delta, global_position + Vector3.UP * 0.1)
	_ground_t -= delta
	if _ground_t <= 0.0:
		_ground_t = 0.2
		var hit := ground_at(global_position, 0.0, 30.0)
		_void = hit.is_empty()
		if not _void:          # over the cove or off the edge: keep the last ground height (don't sink into the haze)
			_ground_y = (hit.position as Vector3).y
	var want := Vector3.ZERO          # desired velocity
	var face := Vector3.ZERO
	var accel := 3.0
	match state:
		S.PATROL:
			if _sees:
				_enter(S.STALK)
			else:
				if _void:
					_target = home     # drifted out over nothing: head back
				var alt := _ground_y + hover_height
				if player_alive() and global_position.distance_to(_player.global_position) < 70.0:
					alt = maxf(alt, _player.global_position.y + stalk_height + 1.0)   # hunting: up where they can see them
				var goal := Vector3(_target.x, alt + sin(_time * 0.9) * 0.4, _target.z)
				var d := goal - global_position
				if Vector2(d.x, d.z).length() < 1.0 or _t <= 0.0:
					_pick_patrol()
				want = d.limit_length(cruise_speed)
				face = Vector3(d.x, 0, d.z)
		S.STALK:
			if not player_alive() or _seen_t > 5.0:
				_enter(S.PATROL)
			else:
				var c := _last_seen
				var off := global_position - c
				off.y = 0.0
				if off.length() < 0.2:
					off = Vector3(1, 0, 0)
				var ang := atan2(off.z, off.x) + _orbit * (orbit_speed / orbit_radius) * 0.6
				var goal := c + Vector3(cos(ang), 0, sin(ang)) * orbit_radius
				goal.y = c.y + stalk_height + sin(_time * 1.4) * 0.35
				want = (goal - global_position) * 1.6
				want = want.limit_length(orbit_speed)
				face = Vector3(want.x, 0, want.z)
				accel = 4.0
				if _t <= 0.0 and _sees and global_position.distance_to(player_chest()) < 13.0:
					_enter(S.WINDUP)
		S.WINDUP:
			if not player_alive():
				_enter(S.PATROL)
			else:
				if _t > 0.15:   # follows the player, then locks
					_dive_to = player_chest() + Vector3(_player.velocity.x, 0, _player.velocity.z) * 0.18
				want = Vector3.UP * 1.0 - (_dive_to - global_position).normalized() * 0.8
				face = _dive_to - global_position
				face.y = 0.0
				accel = 6.0
				if _t <= 0.0:
					_enter(S.DIVE)
		S.DIVE:
			velocity = _dive_dir * dive_speed
		S.RECOVER:
			var low := maxf(_ground_y + 1.3, global_position.y - 0.4)
			want = Vector3(0, (low - global_position.y) * 1.5, 0) + Vector3(sin(_time * 7.0), 0, cos(_time * 5.0)) * 0.4
			accel = 3.5
			face = Vector3(velocity.x, 0, velocity.z)
			if _t <= 0.0:
				_enter(S.STALK if player_alive() and _seen_t < 3.0 else S.PATROL)
		S.STAGGER:
			want = Vector3.ZERO
			accel = 2.5
			if _t <= 0.0:
				_enter(S.STALK if player_alive() else S.PATROL)
				_t = randf_range(1.0, 1.8)
	if state != S.DIVE:
		velocity = velocity.lerp(want, clampf(accel * delta, 0.0, 1.0))
		if global_position.y < _ground_y + 1.0:      # never scrape along the ground
			velocity.y = maxf(velocity.y, 2.5)
	var hit_world := move_and_slide()
	if state == S.DIVE:
		if not _dive_hit and player_alive() and global_position.distance_to(player_chest()) < 1.25:
			_dive_hit = true
			hurt_player(Vector3(_dive_dir.x, 0, _dive_dir.z).normalized() * 7.0 + Vector3.UP * 2.0)
			_enter(S.RECOVER)
			velocity = _dive_dir * 4.0
		elif hit_world or _t <= 0.0:
			if hit_world:
				DeathFx.sparks(self, global_position - _dive_dir * 0.3, Color(1.0, 0.75, 0.4), 12, 4.0)
				velocity = get_wall_normal() * 3.0 if is_on_wall() else Vector3.UP * 2.0
			else:
				velocity = _dive_dir * 5.0
			_enter(S.RECOVER)
	_animate(delta, face)

# ------------------------------------------------------------------ animation
func _animate(delta: float, face: Vector3) -> void:
	var want_pitch := clampf(velocity.y * 0.08, -0.4, 0.4)
	var turn := 3.0
	if state == S.WINDUP or state == S.DIVE:
		# nose locked on the player through the wind-up and the dive (until it's past them)
		var aim := _dive_dir
		if player_alive():
			var to_p := player_chest() - global_position
			if state == S.WINDUP or to_p.dot(_dive_dir) > 0.3:
				aim = to_p.normalized()
		face = Vector3(aim.x, 0, aim.z)
		want_pitch = asin(clampf(aim.y, -1.0, 1.0))
		turn = 16.0
	var prev := _yaw
	if state == S.DIVE:            # straight at them: no smoothing to lag behind
		if face.length() > 0.05:
			_yaw = atan2(-face.x, -face.z)
		_pitch = want_pitch
	else:
		if face.length() > 0.05:
			_yaw = lerp_angle(_yaw, atan2(-face.x, -face.z), clampf(delta * turn, 0.0, 1.0))
		_pitch = lerpf(_pitch, want_pitch, clampf(delta * (turn if turn > 3.0 else 6.0), 0.0, 1.0))
	_yaw_rate = lerpf(_yaw_rate, angle_difference(prev, _yaw) / maxf(delta, 0.001), clampf(delta * 5.0, 0.0, 1.0))
	var want_roll := clampf(_yaw_rate * 0.35, -0.7, 0.7)
	if state == S.RECOVER or state == S.STAGGER:
		want_roll += sin(_time * 9.0) * 0.25
	_roll = lerpf(_roll, want_roll, clampf(delta * 4.0, 0.0, 1.0))
	_model.rotation = Vector3(_pitch, _yaw, _roll)
	# wings: lazy flaps cruising, a buzzing flutter in the wind-up, swept up and back in the dive, big slow beats after
	var rate := 2.4
	var amp := 0.22
	var bias := 0.0
	match state:
		S.STALK:
			rate = 3.2
			amp = 0.28
		S.WINDUP:
			rate = 14.0
			amp = 0.1
			bias = 0.3
		S.DIVE:
			rate = 0.0
			amp = 0.0
			bias = 0.55
		S.RECOVER, S.STAGGER:
			rate = 3.0
			amp = 0.45
	_flap += delta * rate * TAU
	var w := sin(_flap) * amp + bias
	if _wings[0]:
		_wings[0].rotation.z = lerp_angle(_wings[0].rotation.z, -w, clampf(delta * 14.0, 0.0, 1.0))
	if _wings[1]:
		_wings[1].rotation.z = lerp_angle(_wings[1].rotation.z, w, clampf(delta * 14.0, 0.0, 1.0))
	# tails: a lagging wave, swinging out against turns
	for side in 2:
		var chain: Array = _tails[side]
		for k in chain.size():
			var seg := chain[k] as Node3D
			if seg == null:
				continue
			var ph := _time * 3.0 - k * 0.9 + side * 0.6
			seg.rotation = Vector3(sin(ph * 0.8) * 0.12 + (0.25 if state == S.DIVE else 0.0) * (1.0 if k == 0 else 0.3),
				sin(ph) * 0.22 - _yaw_rate * 0.12, 0.0)
	# core: pulses; flares in the wind-up
	var g := 5.0 + sin(_time * 3.0) * 1.5
	if state == S.WINDUP:
		g = lerpf(8.0, 32.0, 1.0 - clampf(_t / windup_time, 0.0, 1.0)) * (1.0 if fmod(_time, 0.1) < 0.06 else 0.6)
	elif state == S.DIVE:
		g = 24.0
	elif state == S.RECOVER or state == S.STAGGER:
		g = 2.5 + sin(_time * 20.0) * 1.5
	_glow = lerpf(_glow, g, clampf(delta * 12.0, 0.0, 1.0))
	if _core_mat:
		_core_mat.emission_energy_multiplier = _glow
	_core_light.light_energy = _glow * 0.12
