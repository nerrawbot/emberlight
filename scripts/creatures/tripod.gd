extends "res://scripts/creatures/enemy.gd"
## Tripod: a triangular scrap walker on three long legs (assets/creatures/tripod.glb, art_src/v7_enemies.py).
## It roams. When it spots the player it keeps 7-15 m off and fires charged bolts from its eye: the red aim line is
## the tell, and it locks 0.3 s before the shot, so a late sidestep or dash beats it. If the player closes in, it
## raises the nearest leg (0.5 s) and stabs it down where they stand. Hitting it mid-charge cancels the shot.
## Legs: 2-bone IK from the hips onto planted feet; a foot steps when the body has moved too far from it.

const MODEL := "res://assets/creatures/tripod.glb"
const Bolt := preload("res://scripts/creatures/tripod_bolt.gd")
const LEG_ANGLES := [30.0, 150.0, 270.0]   # degrees from +X towards forward, as in v7_enemies.py TRI
const HIP_R := 0.72
const THIGH := 1.25
const SHIN := 1.55
const FOOT_R := 1.95
const BODY_H := 1.55
const STOMP_RAISE := 0.5
const STOMP_STRIKE := 0.62
const STOMP_END := 1.05

@export var walk_speed := 1.4
@export var chase_speed := 2.3
@export var keep_near := 7.0
@export var keep_far := 15.0
@export var bolt_speed := 40.0
@export var charge_time := 0.8
@export var stomp_range := 3.3
@export var stomp_radius := 1.35

enum S { ROAM, ENGAGE, CHARGE, STOMP, STAGGER }
var state := S.ROAM
var _t := 0.0
var _cd_bolt := 1.5
var _cd_stomp := 0.0
var _target := Vector3.ZERO
var _pause := 0.0
var _strafe := 1.0
var _strafe_t := 0.0
var _knock := Vector3.ZERO
var _aim := Vector3.ZERO
var _phase := 0.0
var _crouch := 0.0
var _jolt := 0.0
var _scan := 0.0
var _body_y := BODY_H

var _body: Node3D
var _eye: Node3D
var _lens: Node3D
var _lens_mat: StandardMaterial3D
var _eye_light: OmniLight3D
var _aim_line: MeshInstance3D
var _aim_mat: StandardMaterial3D
var _legs: Array = []
var _stomp_leg := -1
var _stomp_at := Vector3.ZERO
var _stomp_raise := Vector3.ZERO
var _stomp_done := false
var _st := 0.0

func _init() -> void:
	max_health = 100.0     # four swings at 30
	sight_range = 30.0
	bar_height = 3.0
	glow_color = Color(1.0, 0.22, 0.12)

func _build() -> void:
	collision_mask = 1 | 16     # the invisible deck guards keep it on the decks
	floor_snap_length = 0.6
	floor_max_angle = deg_to_rad(46)
	_model = (load(MODEL) as PackedScene).instantiate() as Node3D
	_model.name = "Model"
	add_child(_model)
	var shape := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.65
	cap.height = 2.5
	shape.shape = cap
	shape.position = Vector3(0, 1.25, 0)
	add_child(shape)
	_body = _model.find_child("Tri_Body", true, false) as Node3D
	_eye = _model.find_child("Tri_Eye", true, false) as Node3D
	_lens = _model.find_child("Tri_Lens", true, false) as Node3D
	var lens_mi := _lens as MeshInstance3D
	if lens_mi and lens_mi.get_active_material(0):
		_lens_mat = lens_mi.get_active_material(0).duplicate() as StandardMaterial3D
		lens_mi.material_override = _lens_mat
	_eye_light = OmniLight3D.new()
	_eye_light.light_color = glow_color
	_eye_light.light_energy = 0.4
	_eye_light.omni_range = 3.5
	_eye_light.shadow_enabled = false
	_lens.add_child(_eye_light)
	_eye_light.position = Vector3(0, 0, -0.15)
	# aim line: a thin glowing rod from the lens to where the bolt will go
	_aim_mat = StandardMaterial3D.new()
	_aim_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_aim_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_aim_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_aim_mat.albedo_color = Color(glow_color.r * 2.0, glow_color.g * 2.0, glow_color.b * 2.0, 0.0)
	var rod := CylinderMesh.new()
	rod.top_radius = 0.012
	rod.bottom_radius = 0.012
	rod.height = 1.0
	rod.radial_segments = 6
	rod.rings = 1
	rod.material = _aim_mat
	_aim_line = MeshInstance3D.new()
	_aim_line.mesh = rod
	_aim_line.top_level = true
	_aim_line.visible = false
	_aim_line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_aim_line.layers = 2
	add_child(_aim_line)
	for i in 3:
		var a := deg_to_rad(float(LEG_ANGLES[i]))
		var dir := Vector3(cos(a), 0, -sin(a))     # Blender (cos, sin, 0) -> Godot (cos, 0, -sin)
		_legs.append({
			"thigh": _model.find_child("Tri_Thigh%d" % i, true, false),
			"shin": _model.find_child("Tri_Shin%d" % i, true, false),
			"hip": dir * HIP_R, "rest": dir * FOOT_R, "out": dir,
			"foot": Vector3.ZERO, "from": Vector3.ZERO, "to": Vector3.ZERO, "t": -1.0, "dur": 0.3, "lift": 0.35})
	_phase = randf() * TAU
	_scan = randf() * TAU
	_plant_all()
	_pick_roam()

func _plant_all() -> void:
	for L in _legs:
		L.foot = _ground_point(to_global(L.rest))
		L.t = -1.0
	_pose()

func _ground_point(p: Vector3) -> Vector3:
	var hit := ground_at(p, 2.0, 3.5)
	return hit.position if not hit.is_empty() else Vector3(p.x, global_position.y, p.z)

func _eye_pos() -> Vector3:
	return _lens.global_position if _lens else global_position + Vector3.UP * 1.2

# ------------------------------------------------------------------ AI
func _pick_roam() -> void:
	_target = wander_target(10.0)
	_t = randf_range(6.0, 10.0)

func _enter(s: int) -> void:
	state = s
	match s:
		S.CHARGE:
			_t = charge_time
			_aim = player_chest()
		S.ROAM:
			home = global_position
			_pick_roam()

func _on_hit(by: Node3D, dir: Vector3) -> void:
	_jolt = 1.0
	if state == S.STOMP:
		return                 # too heavy to stop mid-stomp
	_knock = Vector3(dir.x, 0, dir.z).normalized() * 2.5
	_aim_line.visible = false
	state = S.STAGGER
	_t = 0.35
	_cd_bolt = maxf(_cd_bolt, 0.8)

func lose_target() -> void:
	super.lose_target()
	if state != S.ROAM:
		_cancel_stomp()
		_aim_line.visible = false
		_enter(S.ROAM)

func _think(delta: float) -> void:
	_cd_bolt -= delta
	_cd_stomp -= delta
	_t -= delta
	update_sight(delta, _eye_pos())
	var flat_to := Vector3.ZERO
	var dist := 999.0
	if player_alive():
		flat_to = _player.global_position - global_position
		flat_to.y = 0.0
		dist = flat_to.length()
	var move := Vector3.ZERO
	var face := Vector3.ZERO
	var look := Vector3.ZERO     # where the eye points (world); zero = scan
	match state:
		S.ROAM:
			if _sees:
				_enter(S.ENGAGE)
			elif _pause > 0.0:
				_pause -= delta
			else:
				var d := _target - global_position
				d.y = 0.0
				if d.length() < 0.8 or _t <= 0.0:
					_pause = randf_range(1.0, 3.5)
					_pick_roam()
				else:
					move = d.normalized() * walk_speed
					face = move
		S.ENGAGE:
			if not player_alive() or _seen_t > 6.0:
				_enter(S.ROAM)
			else:
				var g := _last_seen - global_position
				g.y = 0.0
				var d := g.length()
				var n := g / maxf(d, 0.01)
				face = n
				look = player_chest() if _sees else Vector3.ZERO
				if _sees and dist < stomp_range and _cd_stomp <= 0.0 and absf(_player.global_position.y - global_position.y) < 2.2:
					_start_stomp()
				elif _sees and _cd_bolt <= 0.0 and dist > 3.5:
					_enter(S.CHARGE)
				else:
					_strafe_t -= delta
					if _strafe_t <= 0.0:
						_strafe_t = randf_range(1.8, 4.0)
						_strafe = -_strafe if randf() < 0.6 else _strafe
					if not _sees or d > keep_far:
						move = n * chase_speed
					elif d < keep_near:
						move = -n * walk_speed + n.cross(Vector3.UP) * _strafe * walk_speed * 0.5
					else:
						move = n.cross(Vector3.UP) * _strafe * walk_speed * 0.7
		S.CHARGE:
			if not player_alive():
				_aim_line.visible = false
				_enter(S.ROAM)
			else:
				if _t > 0.3:      # tracking; then locked for the last 0.3 s
					_aim = _aim.lerp(player_chest(), clampf(delta * 8.0, 0.0, 1.0))
				face = _aim - global_position
				face.y = 0.0
				look = _aim
				_crouch = move_toward(_crouch, 0.28, delta * 0.8)
				if _t <= 0.0:
					_fire()
					_cd_bolt = randf_range(2.2, 3.4)
					_enter(S.ENGAGE)
		S.STOMP:
			look = player_chest() if player_alive() else Vector3.ZERO
			face = _stomp_at - global_position
			face.y = 0.0
			_stomp_update(delta)
		S.STAGGER:
			move = _knock
			_knock = _knock.move_toward(Vector3.ZERO, delta * 8.0)
			if _t <= 0.0:
				_enter(S.ENGAGE if player_alive() else S.ROAM)
	if state != S.CHARGE:
		_crouch = move_toward(_crouch, 0.0, delta * 1.5)
	_update_aim_line()
	_move(delta, move, face)
	_animate(delta, look)

func _move(delta: float, move: Vector3, face: Vector3) -> void:
	if move.length() > 0.05 and state != S.STAGGER:
		# don't walk off the mesa or a deck: probe the ground ahead
		var ahead := global_position + move.normalized() * 1.7
		var hit := ground_at(ahead, 1.5, 2.2)
		if hit.is_empty() or (hit.normal as Vector3).y < 0.6:
			move = Vector3.ZERO
			if state == S.ROAM:
				_pause = 0.5
				_target = global_position - (ahead - global_position) * 3.0
			else:
				_strafe = -_strafe
	var accel := 6.0 if move.length() > 0.05 else 4.0
	velocity.x = move_toward(velocity.x, move.x, accel * delta)
	velocity.z = move_toward(velocity.z, move.z, accel * delta)
	if is_on_floor() and velocity.y <= 0.0:
		velocity.y = -0.5
	else:
		velocity.y -= _gravity * delta
	move_and_slide()
	if state == S.ROAM and is_on_wall():
		_pick_roam()
	if face.length() > 0.05:
		var yaw := atan2(-face.x, -face.z)
		rotation.y = lerp_angle(rotation.y, yaw, clampf(delta * (3.5 if state != S.ROAM else 2.0), 0.0, 1.0))

# ------------------------------------------------------------------ attacks
func _fire() -> void:
	_aim_line.visible = false
	var b := Node3D.new()
	b.set_script(Bolt)
	var from := _eye_pos()
	var dir := (_aim - from).normalized()
	b.set("velocity", dir * bolt_speed)
	b.set("damage", attack_damage)
	b.set("shooter", self)
	b.set("color", glow_color)
	b.position = from + dir * 0.25
	DeathFx._host(self).add_child(b)
	_jolt = 0.8
	DeathFx.sparks(self, from + dir * 0.2, glow_color, 8, 3.0)

func _start_stomp() -> void:
	var best := 0
	var best_d := 999.0
	for i in 3:
		var d := (_legs[i].foot as Vector3).distance_to(_player.global_position)
		if d < best_d:
			best_d = d
			best = i
	_stomp_leg = best
	_stomp_done = false
	var L: Dictionary = _legs[best]
	L.from = L.foot
	L.t = -1.0
	_stomp_raise = _body.global_transform * (L.hip as Vector3) + global_transform.basis * (L.out as Vector3) * 0.7 + Vector3.UP * 0.6
	_stomp_at = _player.global_position
	state = S.STOMP
	_st = 0.0

func _stomp_update(delta: float) -> void:
	_st += delta
	var L: Dictionary = _legs[_stomp_leg]
	if _st < STOMP_RAISE:
		if player_alive():   # tracks the player while the leg is up
			_stomp_at = _player.global_position
		var c := global_position
		var off := _stomp_at - c
		off.y = 0.0
		if off.length() > 2.9:
			_stomp_at = c + off.normalized() * 2.9 + Vector3(0, _stomp_at.y - c.y, 0)
		var k := smoothstep(0.0, 1.0, _st / STOMP_RAISE)
		L.foot = (L.from as Vector3).lerp(_stomp_raise, k) + Vector3.UP * sin(k * PI) * 0.4
	elif _st < STOMP_STRIKE:
		var k := (_st - STOMP_RAISE) / (STOMP_STRIKE - STOMP_RAISE)
		L.foot = _stomp_raise.lerp(_ground_point(_stomp_at), k * k)
	else:
		if not _stomp_done:
			_stomp_done = true
			var hitp := _ground_point(_stomp_at)
			L.foot = hitp
			DeathFx.sparks(self, hitp + Vector3.UP * 0.1, Color(1.0, 0.75, 0.45), 18, 4.5)
			_jolt = 1.0
			if player_alive():
				var d := _player.global_position - hitp
				var dy := d.y
				d.y = 0.0
				if d.length() < stomp_radius and absf(dy) < 1.6:
					hurt_player((d.normalized() if d.length() > 0.05 else -global_transform.basis.z) * 5.0 + Vector3.UP * 2.5)
				elif d.length() < 4.0 and _player.has_method("shake"):
					_player.shake(0.15)     # a near miss still rattles you
		if _st >= STOMP_END:
			_cancel_stomp()
			_cd_stomp = randf_range(1.4, 2.2)
			_enter(S.ENGAGE)

func _cancel_stomp() -> void:
	if _stomp_leg >= 0:
		var L: Dictionary = _legs[_stomp_leg]
		L.foot = _ground_point(L.foot)
		L.t = -1.0
	_stomp_leg = -1

# ------------------------------------------------------------------ animation
func _update_aim_line() -> void:
	if state != S.CHARGE:
		_aim_line.visible = false
		_aim_mat.albedo_color.a = 0.0
		return
	var from := _eye_pos()
	var to := from + (_aim - from).normalized() * sight_range
	var q := PhysicsRayQueryParameters3D.create(from, to, 1)
	q.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		to = hit.position
	var v := to - from
	var len := v.length()
	if len < 0.1:
		_aim_line.visible = false
		return
	var y := v / len
	var x := y.cross(Vector3.UP if absf(y.y) < 0.95 else Vector3.RIGHT).normalized()
	var z := x.cross(y)
	_aim_line.global_transform = Transform3D(Basis(x, y * len, z), from + v * 0.5)
	_aim_line.visible = true
	var k := 1.0 - clampf(_t / charge_time, 0.0, 1.0)
	var locked := _t <= 0.3
	_aim_mat.albedo_color.a = (0.9 if fmod(_t, 0.08) < 0.05 else 0.35) if locked else 0.15 + 0.5 * k

func _animate(delta: float, look: Vector3) -> void:
	var hv := Vector2(velocity.x, velocity.z).length()
	_phase += delta * (1.5 + hv * 3.0)
	_jolt = move_toward(_jolt, 0.0, delta * 4.0)
	_update_legs(delta)
	# body: rides at its height above the feet, bobs with the gait, leans into the walk, jolts on hits/shots
	var avg := 0.0
	for L in _legs:
		avg += (L.foot as Vector3).y
	avg = avg / 3.0 - global_position.y
	_body_y = lerpf(_body_y, clampf(avg, -0.6, 0.6) + BODY_H - _crouch, clampf(delta * 5.0, 0.0, 1.0))
	var bob := sin(_phase * 2.0) * 0.04 * clampf(hv, 0.0, 1.0) + sin(_phase * 0.7) * 0.02
	_body.position = Vector3(0, _body_y + bob, 0)
	var fwd_speed := (global_transform.basis.inverse() * velocity).z
	_body.rotation = Vector3(fwd_speed * 0.05 - _jolt * 0.12 + _crouch * 0.4, 0, sin(_phase) * 0.03 * clampf(hv, 0.0, 1.0) + _jolt * 0.05 * sin(_phase * 9.0))
	# eye: tracks `look`, otherwise scans slowly
	var yaw := sin(_phase * 0.35 + _scan) * 0.7
	var pitch := -0.15
	if look != Vector3.ZERO:
		var lp := _body.global_transform.affine_inverse() * look - _eye.position
		yaw = atan2(-lp.x, -lp.z)
		pitch = atan2(lp.y, Vector2(lp.x, lp.z).length())
	_eye.rotation.y = lerp_angle(_eye.rotation.y, clampf(yaw, -1.5, 1.5), clampf(delta * 6.0, 0.0, 1.0))
	_eye.rotation.x = lerpf(_eye.rotation.x, clampf(pitch, -1.1, 0.7), clampf(delta * 6.0, 0.0, 1.0))
	var glow := 4.0
	if state == S.CHARGE:
		glow = lerpf(6.0, 30.0, 1.0 - clampf(_t / charge_time, 0.0, 1.0))
	elif state == S.ENGAGE or state == S.STOMP:
		glow = 9.0
	if _lens_mat:
		_lens_mat.emission_energy_multiplier = lerpf(_lens_mat.emission_energy_multiplier, glow, clampf(delta * 10.0, 0.0, 1.0))
	_eye_light.light_energy = glow * 0.12

func _update_legs(delta: float) -> void:
	var vel := Vector3(velocity.x, 0, velocity.z)
	var stepping := 0
	for i in 3:
		var L: Dictionary = _legs[i]
		if i == _stomp_leg or L.t < 0.0:
			continue
		L.t += delta / (L.dur as float)
		var k := minf(L.t, 1.0)
		L.foot = (L.from as Vector3).lerp(L.to, smoothstep(0.0, 1.0, k)) + Vector3.UP * sin(k * PI) * (L.lift as float)
		if L.t >= 1.0:
			L.t = -1.0
			L.foot = L.to
		else:
			stepping += 1
	# the foot furthest from where it wants to be steps next (a second may join when it's badly behind)
	var worst := -1
	var worst_d := 0.0
	for i in 3:
		var L: Dictionary = _legs[i]
		if i == _stomp_leg or L.t >= 0.0:
			continue
		var want := to_global(L.rest) + vel * 0.45
		var d := Vector2(want.x - L.foot.x, want.z - L.foot.z).length()
		var thresh := 0.55 if vel.length() > 0.2 else 0.3
		if stepping > 0:
			thresh = 1.3
		if stepping < 2 and d > thresh and d > worst_d:
			worst = i
			worst_d = d
	if worst >= 0:
		var L: Dictionary = _legs[worst]
		L.from = L.foot
		L.to = _ground_point(to_global(L.rest) + vel * 0.45)
		L.dur = clampf(0.34 - vel.length() * 0.05, 0.2, 0.34)
		L.lift = 0.3 + minf(vel.length(), 2.5) * 0.06
		L.t = 0.0
	_pose()

func _pose() -> void:
	if _body == null:
		return
	var bx := _body.global_transform
	for L in _legs:
		_solve(L.thigh, L.shin, bx * (L.hip as Vector3), L.foot, global_transform.basis * (L.out as Vector3))

## 2-bone IK: hip -> knee -> foot, knee bending up and outwards.
func _solve(thigh: Node3D, shin: Node3D, hip: Vector3, foot: Vector3, out: Vector3) -> void:
	var v := foot - hip
	var raw := v.length()
	var u := v / raw if raw > 0.001 else Vector3.DOWN
	var d := clampf(raw, 0.35, THIGH + SHIN - 0.01)
	var pole := Vector3.UP + out * 0.6
	pole = pole - u * pole.dot(u)
	pole = pole.normalized() if pole.length() > 0.01 else out
	var ca := clampf((THIGH * THIGH + d * d - SHIN * SHIN) / (2.0 * THIGH * d), -1.0, 1.0)
	var knee := hip + u * (THIGH * ca) + pole * (THIGH * sqrt(1.0 - ca * ca))
	_orient(thigh, hip, knee, pole)
	_orient(shin, knee, hip + u * d, pole)

## Segments run along their local -Z (Blender +Y) from their origin; local +Y faces the pole (knee side).
func _orient(n: Node3D, a: Vector3, b: Vector3, pole: Vector3) -> void:
	if n == null:
		return
	var z := a - b
	if z.length() < 0.001:
		return
	z = z.normalized()
	var x := pole.cross(z)
	x = x.normalized() if x.length() > 0.001 else z.cross(Vector3.RIGHT).normalized()
	n.global_transform = Transform3D(Basis(x, z.cross(x), z), a)
