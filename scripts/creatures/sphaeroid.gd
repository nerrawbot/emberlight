extends "res://scripts/creatures/enemy.gd"
## The Sphaeroid: the Peak hall's boss (assets/creatures/sphaeroid.glb, art_src/v13_sphaeroid.py), run by
## scripts/boss_arena.gd. A ~4.4 m iron ball on a pylon leg and a sled skid, a star faceplate with one red eye, a
## cannon on its shoulder.
##   Phase 1 (above half health): cannon volleys (3 quick shells) and leaps at the player (shockwave on landing).
##   Phase 2 (half and under; smoke and sparks leak from its seams): it also launches skates from a hatch in its
##   back (never more than 2 alive) and rolls: legs fold, the star spins up like a saw, and it charges, steering
##   after the player. The roll stops when it hits the player (70 damage, or it breaks a raised shield instead) or
##   after its second wall, and leaves it stunned for ~2 s.
##   Retreating to the gallery to regen: it plants itself and heals, at most 3 swings' worth per retreat (the cap
##   refills when the player comes down and lands a hit), then shells the gallery.
##   Under 2% it seizes up (DOWN) and can't be hurt further: [E] on it (boss_unpower.gd) cuts its power (OFF),
##   which ends the fight. `husk` spawns it already OFF (later visits).
## The body itself stays upright; it turns with rotation.y. The model faces -Z.

signal health_changed(value: float, max_value: float)
signal phase_changed(phase: int)
signal downed
signal unpowered(by: Node)

const MODEL := "res://assets/creatures/sphaeroid.glb"
const Bolt := preload("res://scripts/creatures/tripod_bolt.gd")
const Skate := preload("res://scripts/creatures/skate.gd")
const PAINT := preload("res://scripts/creatures/painterly.gdshader")
const PAINT_DIR := "res://assets/creatures/sph_paint_"
const SC := 0.91             # model scale (~4 m tall; the glb is ~4.4 m)
const R := 1.8 * SC         # hull radius (v13_sphaeroid.py R x scale), world metres
const CZ := 2.17 * SC       # hull centre above the feet, standing
const ROLL_CZ := 1.84 * SC  # ... rolling (the shell's bottom just clears the floor)
const PAD := 0.1            # the player-blocking body stands this far proud of the hull

@export var shot_damage := 10.0
@export var shot_speed := 20.0
@export var jump_damage := 25.0
@export var jump_radius := 5.5
@export var roll_damage := 50.0
@export var roll_speed := 16.0
@export var roll_turn := 0.1          # rad/s it steers after the player while rolling
@export var roll_stun := 2.0
@export var walk_speed := 2.4
@export var heal_rate := 30.0
@export var heal_per_retreat := 60.0  # three swings
@export var stun_frac := 0.02
@export var summon_cooldown := 15.0
@export var max_skates := 2
## Cannon: closer than this it hops back first (a short leap away from the player), then fires.
@export var cannon_keep := 11.0
@export var hop_time := 0.62
@export var shot_gap := 0.5         # between the shells of a volley
@export var strafe_speed := 2.0

var floor_y := 0.0
var arena: Node            # boss_arena.gd (jump targets, the upper-level test); optional
var husk := false
## Tests: stand in IDLE instead of picking attacks (attacks can still be started with _enter()).
var hold_ai := false

enum S { DORMANT, IDLE, CANNON, JUMP_WIND, JUMP_AIR, ROLL_WIND, ROLL, ROLL_STUN, SUMMON, HEAL, PHASE, DOWN, OFF, HOP }
var state := S.DORMANT
var phase := 1
var _t := 0.0               # time left in the current state
var _st := 0.0              # time spent in the current state
var _time := 0.0
var _idle_t := 1.5
var _last := -1
var _repeats := 0
var _heal_budget := 90.0
var _summon_cd := 6.0
var _phase_pending := false
var _down_pending := false
var _shots := 0
var _launched := 0
var _jump_from := Vector3.ZERO
var _jump_to := Vector3.ZERO
var _roll_dir := Vector3.FORWARD
var _roll_v := 0.0
var _walls := 0
var _skates: Array[Node] = []
var _strafe := 1.0          # +1 / -1: which way it circles the player while sizing them up
var _strafe_t := 2.0
var _hopped := false        # this volley's back-hop is done
var _hop_from := Vector3.ZERO
var _hop_to := Vector3.ZERO
static var _paint_cache := {}

# model parts (assets/creatures/sphaeroid.glb)
var _frame: Node3D
var _shell: Node3D
var _star: Node3D
var _turret: Node3D
var _cannon: Node3D
var _muzzle: Node3D
var _leg: Node3D
var _skid: Node3D
var _hatch: Node3D
var _mouth: Node3D
var _star_pos0 := Vector3.ZERO
var _eye_mat: StandardMaterial3D
var _eye_light: OmniLight3D
var _eye_beam: SpotLight3D
var _eye_halo: MeshInstance3D
var _halo_mat: StandardMaterial3D
var _shape: CollisionShape3D
var _solid: AnimatableBody3D
var _solid_shape: CollisionShape3D
var _solid_legs: Array[CollisionShape3D] = []
var _unpower: Area3D
var _unpower_shape: CollisionShape3D
# pose (smoothed towards targets every frame)
var _fold := 0.0            # 0 standing .. 1 folded into a ball
var _squash := 0.0          # jump crouch
var _slump := 0.0           # DOWN / OFF
var _spin := 0.0            # star spin rad/s
var _hatch_open := 0.0
var _glow := 4.0
var _aim_w := 0.0           # turret tracking weight
var _aim_at := Vector3.ZERO
var _lurch := 0.0
# effects
var _roll_sparks: GPUParticles3D
var _heal_fx: GPUParticles3D
var _wounds: Array[GPUParticles3D] = []
var _marker: MeshInstance3D

func _init() -> void:
	max_health = 1500.0      # fifty swings at 30
	sight_range = 60.0
	attack_damage = 12.0
	glow_color = Color(1.0, 0.16, 0.1)

# ------------------------------------------------------------------ build
func _build() -> void:
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	wall_min_slide_angle = 0.0
	_model = (load(MODEL) as PackedScene).instantiate() as Node3D
	_model.name = "Model"
	_model.scale = Vector3.ONE * SC
	add_child(_model)
	_frame = _model.find_child("Sph_Frame", true, false) as Node3D
	_shell = _model.find_child("Sph_Shell", true, false) as Node3D
	_star = _model.find_child("Sph_Star", true, false) as Node3D
	_turret = _model.find_child("Sph_Turret", true, false) as Node3D
	_cannon = _model.find_child("Sph_Cannon", true, false) as Node3D
	_muzzle = _model.find_child("Sph_Muzzle", true, false) as Node3D
	_leg = _model.find_child("Sph_Leg", true, false) as Node3D
	_skid = _model.find_child("Sph_Skid", true, false) as Node3D
	_hatch = _model.find_child("Sph_Hatch", true, false) as Node3D
	_mouth = _model.find_child("Sph_HatchMouth", true, false) as Node3D
	_star_pos0 = _star.position
	var eye := _model.find_child("Sph_Eye", true, false) as MeshInstance3D
	if eye and eye.get_active_material(0):
		_eye_mat = eye.get_active_material(0).duplicate() as StandardMaterial3D
		eye.set_surface_override_material(0, _eye_mat)
	_eye_light = OmniLight3D.new()
	_eye_light.light_color = glow_color
	_eye_light.omni_range = 7.0
	_eye_light.shadow_enabled = false
	_star.add_child(_eye_light)
	_eye_light.position = Vector3(0, 0, -0.9)
	# the eye's stare: a narrow red beam that shows in the haze, and a soft halo on the pupil
	_eye_beam = SpotLight3D.new()
	_eye_beam.light_color = Color(1.0, 0.12, 0.08)
	_eye_beam.spot_range = 22.0
	_eye_beam.spot_angle = 11.0
	_eye_beam.spot_attenuation = 0.6
	_eye_beam.shadow_enabled = false
	_eye_beam.light_volumetric_fog_energy = 5.0
	_star.add_child(_eye_beam)
	_eye_beam.position = Vector3(0, 0, -0.45)
	_halo_mat = StandardMaterial3D.new()
	_halo_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_halo_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_halo_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_halo_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_halo_mat.no_depth_test = false
	_halo_mat.albedo_texture = DeathFx.soft_tex()
	_halo_mat.albedo_color = Color(1.0, 0.18, 0.1, 0.0)
	var hq := QuadMesh.new()
	hq.size = Vector2(1.3, 1.3)
	hq.material = _halo_mat
	_eye_halo = MeshInstance3D.new()
	_eye_halo.mesh = hq
	_eye_halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_eye_halo.layers = 2
	_star.add_child(_eye_halo)
	_eye_halo.position = Vector3(0, 0, -0.5)
	# hits: the hull on layer 8 (the swing's layer); its own moves only collide with the world (layer 1)
	_shape = CollisionShape3D.new()
	var sp := SphereShape3D.new()
	sp.radius = R + 0.15
	_shape.shape = sp
	_shape.position = Vector3(0, CZ, 0)
	add_child(_shape)
	# its body on layer 16 so the player can't walk through it (the player's mask has 16; shots, skates and the
	# interact ray don't): a drum from the floor to the hull's middle (a ball alone sits 0.4 m up, and the capsule
	# slid under its curve), the ball's crown, and boxes for the pylon and the skid. Off while it rolls or leaps,
	# so it never pins anyone against a wall; on landing it shoves the player clear (_eject_player).
	_solid = AnimatableBody3D.new()
	_solid.name = "Solid"
	_solid.collision_layer = 16
	_solid.collision_mask = 0
	_solid.sync_to_physics = false     # with sync on it only follows its own local transform: it stayed behind when the boss moved
	_solid_shape = CollisionShape3D.new()
	var cy := CylinderShape3D.new()
	cy.radius = R + PAD
	cy.height = CZ
	_solid_shape.shape = cy
	_solid_shape.position = Vector3(0, CZ * 0.5, 0)
	_solid.add_child(_solid_shape)
	var crown := CollisionShape3D.new()
	var sp2 := SphereShape3D.new()
	sp2.radius = R + PAD
	crown.shape = sp2
	crown.position = Vector3(0, CZ, 0)
	_solid.add_child(crown)
	_solid_legs.append(crown)
	for b in [[Vector3(2.18, 1.2, 0.0), Vector3(0.85, 2.5, 1.8)], [Vector3(-2.18, 1.1, -0.18), Vector3(0.85, 2.3, 2.35)]]:
		var leg := CollisionShape3D.new()
		var bx := BoxShape3D.new()
		bx.size = b[1]
		leg.shape = bx
		leg.position = b[0]
		_solid.add_child(leg)
		_solid_legs.append(leg)
	add_child(_solid)
	# [E] when it's down (boss_unpower.gd); off until then
	_unpower = Area3D.new()
	_unpower.name = "Unpower"
	_unpower.set_script(load("res://scripts/boss_unpower.gd"))
	_unpower.set("boss", self)
	_unpower.monitoring = false
	_unpower_shape = CollisionShape3D.new()
	var sp3 := SphereShape3D.new()
	sp3.radius = R + 0.3
	_unpower_shape.shape = sp3
	_unpower_shape.position = Vector3(0, CZ - 0.35, 0)
	_unpower_shape.disabled = true
	_unpower.add_child(_unpower_shape)
	add_child(_unpower)
	_unpower.collision_layer = 0
	_unpower.collision_mask = 0
	_make_fx()
	_paint_model()
	_time = randf() * 10.0
	if husk:
		_go_off(true)

func _ready() -> void:
	super._ready()
	if husk:
		remove_from_group("enemies")
	health_changed.emit(health, max_health)

## No floating bar: boss_bar.gd on the HUD shows its health.
func _update_bar(_delta: float) -> void:
	pass

## The player-blocking body on/off (the pylon + skid boxes stay off while the legs are folded up).
func _set_solid(on: bool) -> void:
	_solid_shape.disabled = not on
	for i in _solid_legs.size():
		_solid_legs[i].disabled = not on or (i > 0 and _fold > 0.3)

## Its body came back (landing, end of a roll): if the player is standing inside it, shove them out to the side.
func _eject_player() -> void:
	if not player_alive():
		return
	var off := _player.global_position - global_position
	var flat := Vector3(off.x, 0, off.z)
	if flat.length() > R + PAD + 0.45 or off.y > CZ + R or off.y < -1.0:
		return
	var out := flat.normalized() if flat.length() > 0.05 else -_forward()
	_player.global_position = global_position + out * (R + PAD + 0.5) + Vector3.UP * maxf(off.y, 0.05)
	_player.velocity += out * 4.0

# ------------------------------------------------------------------ painted look
## Hand-painted look (art_src/v13_paint.py maps + painterly.gdshader): swap the glb's PBR materials part by part.
## The emissive eye, core and sight lens and the small hazard/rust decals keep theirs.
func _paint_model() -> void:
	for n in _model.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		for s in mi.mesh.get_surface_count():
			var m := _painted(mi.name, mi.mesh.surface_get_material(s))
			if m:
				mi.set_surface_override_material(s, m)

func _painted(part: String, src: Material) -> Material:
	var mname := src.resource_name if src else ""
	var key := part + "/" + mname
	if _paint_cache.has(key):
		return _paint_cache[key]
	var base := Color(0.5, 0.5, 0.5)
	if src is StandardMaterial3D:
		base = (src as StandardMaterial3D).albedo_color
	var m: ShaderMaterial = null
	match mname:
		"M_SphHull":
			if part == "Sph_Cannon":
				m = _pmat("cannon", 1, 1.0, 0.375, 0.5)
			elif part == "Sph_Turret":
				m = _pmat("steel", 0, 2.0, 0.6, 0.5)
			else:
				m = _pmat("hull", 0, 1.0, 0.268, 0.5, Color(1.2, 1.2, 1.25))
		"M_Steel":
			m = _pmat("steel", 0, 2.0, 0.45, 0.5)
		"M_SphLeg":
			if part == "Sph_Cannon":         # the pale ribs along the barrel
				m = _pmat("", 0, 1.0, 1.0, 0.0, Color(0.42, 0.4, 0.56))
			else:
				m = _pmat("leg", 2, 1.4, 0.375, 0.18, Color(0.82, 0.82, 0.86))
		"M_SphStar":
			m = _pmat("star", 3, 1.0 / 3.5, 1.0, 0.0)
			m.set_shader_parameter("shade_color", Color(0.45, 0.2, 0.3))
		"M_SphIris":
			m = _pmat("", 0, 1.0, 1.0, 0.0, Color(0.9, 0.86, 0.88))
			m.set_shader_parameter("emission_amt", 0.35)
			m.set_shader_parameter("emission_color", Color(1.0, 0.86, 0.86))
		"M_SphDark", "M_SphViolet", "M_Cable", "M_SphTan", "M_SphPink":
			m = _pmat("", 0, 1.0, 1.0, 0.0, base)
	_paint_cache[key] = m
	return m

## A painterly material: `paint` = sph_paint_<paint>.png ("" = flat `tint`), projected per painterly.gdshader `proj`.
func _pmat(paint: String, proj: int, u_rep: float, v_scale: float, v_off: float, tint := Color.WHITE) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = PAINT
	m.set_shader_parameter("brush", load(PAINT_DIR + "brush.png"))
	m.set_shader_parameter("use_paint", paint != "")
	if paint != "":
		m.set_shader_parameter("paint", load(PAINT_DIR + paint + ".png"))
	m.set_shader_parameter("proj", proj)
	m.set_shader_parameter("u_repeat", u_rep)
	m.set_shader_parameter("v_scale", v_scale)
	m.set_shader_parameter("v_offset", v_off)
	m.set_shader_parameter("tint", tint)
	return m

func _make_fx() -> void:
	# sparks off the star where it scrapes the floor in a roll
	_roll_sparks = _particles(Color(1.0, 0.7, 0.35), 40, 0.45, 6.0, 0.05, Vector3(0, -9.0, 0), false)
	_frame.add_child(_roll_sparks)
	_roll_sparks.position = Vector3(0, -1.8, -1.26)     # under the wrapped star's lowest reach
	# healing: pale motes rising round the hull
	_heal_fx = _particles(Color(0.55, 0.95, 1.0), 36, 1.4, 0.8, 0.09, Vector3(0, 1.4, 0), true)
	(_heal_fx.process_material as ParticleProcessMaterial).emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE_SURFACE
	(_heal_fx.process_material as ParticleProcessMaterial).emission_sphere_radius = R / SC + 0.3     # frame space (model units)
	_frame.add_child(_heal_fx)

## A small continuous emitter (off until `emitting`). `soft`: glowing puffs, else hot sparks.
func _particles(col: Color, amount: int, life: float, speed: float, size: float, grav: Vector3, soft: bool) -> GPUParticles3D:
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 70.0 if not soft else 180.0
	pm.initial_velocity_min = speed * 0.5
	pm.initial_velocity_max = speed
	pm.gravity = grav
	pm.scale_curve = DeathFx._curve([Vector2(0, 1), Vector2(1, 0)])
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.albedo_texture = DeathFx.soft_tex()
	m.albedo_color = col * (1.4 if soft else 2.5)
	m.vertex_color_use_as_albedo = true
	var q := QuadMesh.new()
	q.size = Vector2(size, size) * (3.0 if soft else 1.0)
	q.material = m
	var e := GPUParticles3D.new()
	e.amount = amount
	e.lifetime = life
	e.local_coords = false
	e.process_material = pm
	e.draw_pass_1 = q
	e.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	e.layers = 2
	e.emitting = false
	e.visibility_aabb = AABB(Vector3(-8, -8, -8), Vector3(16, 16, 16))
	return e

## Phase 2: a few sparks and smoke wisps leaking from seams in the shell (they roll with it).
func _open_wounds() -> void:
	for d in [Vector3(0.6, 0.55, 0.3), Vector3(-0.5, 0.2, -0.65), Vector3(0.2, -0.3, 0.9)]:
		var p: Vector3 = (d as Vector3).normalized() * (R / SC + 0.02)     # shell space
		var sparks := _particles(Color(1.0, 0.55, 0.2), 5, 0.6, 2.5, 0.05, Vector3(0, -9.0, 0), false)
		sparks.amount_ratio = 1.0
		_shell.add_child(sparks)
		sparks.position = p
		sparks.emitting = true
		var smoke := _particles(Color(0.16, 0.15, 0.2), 4, 1.8, 0.6, 0.22, Vector3(0, 0.8, 0), true)
		var sm := smoke.draw_pass_1.surface_get_material(0) as StandardMaterial3D
		if sm:
			sm.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
			sm.albedo_color = Color(0.2, 0.19, 0.24, 0.45)
		_shell.add_child(smoke)
		smoke.position = p
		smoke.emitting = true
		_wounds.append(sparks)
		_wounds.append(smoke)

# ------------------------------------------------------------------ control (boss_arena.gd)
## The player walked in: the eye lights and it comes for them.
func wake() -> void:
	if state == S.DORMANT:
		_enter(S.IDLE)
		_idle_t = 1.2
		_glow = 30.0
		_player = get_tree().get_first_node_in_group("player") as Node3D

func is_down() -> bool:
	return state == S.DOWN or state == S.OFF

func skates_alive() -> int:
	var n := 0
	for s in _skates:
		if is_instance_valid(s) and not s.get("dead"):
			n += 1
	return n

## Kill off its summons (it went down, or the fight reset).
func clear_minions(burst := true) -> void:
	for s in _skates:
		if is_instance_valid(s) and not s.get("dead"):
			if burst:
				s.call("die", true)
			else:
				s.queue_free()
	_skates.clear()

## [E] while it's down (boss_unpower.gd).
func unpower(by: Node) -> void:
	if state != S.DOWN:
		return
	_go_off(false)
	unpowered.emit(by)

func lose_target() -> void:
	super.lose_target()

# ------------------------------------------------------------------ taking hits
func take_hit(by: Node3D, dir: Vector3) -> void:
	if dead or state == S.DORMANT or state == S.OFF:
		return
	var at := global_position + Vector3.UP * CZ
	if by:
		at = by.global_position + Vector3.UP * 1.2 + Vector3(dir.x, 0, dir.z).normalized() * 1.6
	if state == S.DOWN:
		DeathFx.sparks(self, at, Color(0.9, 0.85, 1.0), 6, 2.5)
		return
	var d: Variant = by.get("attack_damage") if by else null
	var dmg := 30.0 if d == null else float(d)
	if by and not _player_upper():
		_heal_budget = heal_per_retreat      # came down and fought: the next retreat can be healed again
	health = maxf(0.0, health - dmg)
	_flash_t = 0.12
	_set_overlay(_flash_mat)
	DeathFx.sparks(self, at, Color(1.0, 0.7, 0.4), 10, 4.0)
	if health < max_health * stun_frac:
		health = max_health * stun_frac * 0.5
		if state == S.JUMP_AIR:
			_down_pending = true
		else:
			_enter(S.DOWN)
	elif phase == 1 and health <= max_health * 0.5:
		phase = 2
		if state == S.JUMP_AIR or state == S.ROLL:
			_phase_pending = true
		else:
			_enter(S.PHASE)
	health_changed.emit(health, max_health)

# ------------------------------------------------------------------ senses
func _flat_to_player() -> Vector3:
	var v := _player.global_position - global_position
	v.y = 0.0
	return v

## On the gallery or high on its stairs, out of reach (and not just standing on top of it).
func _player_upper() -> bool:
	if not player_alive():
		return false
	if arena and arena.has_method("player_upper"):
		return arena.call("player_upper", _player, self)
	return _player.global_position.y > floor_y + 2.2 and _flat_to_player().length() > R + 1.0

func _face(dir: Vector3, rate: float, delta: float) -> void:
	if Vector2(dir.x, dir.z).length() < 0.05:
		return
	rotation.y = rotate_toward(rotation.y, atan2(-dir.x, -dir.z), rate * delta)

func _forward() -> Vector3:
	return -global_basis.z

# ------------------------------------------------------------------ state machine
func _enter(s: int) -> void:
	state = s
	_st = 0.0
	var p2 := phase == 2
	match s:
		S.IDLE:
			_idle_t = randf_range(1.2, 1.9) if p2 else randf_range(1.8, 2.6)
			_hopped = false
		S.CANNON:
			if not _hopped and _hop_away():
				return                          # hops back first; HOP lands into CANNON
			_t = 0.36 if p2 else 0.5           # aim
			_shots = 0
		S.HOP:
			_t = hop_time
			_hopped = true
			_hop_from = global_position
			_set_solid(false)
			DeathFx.sparks(self, global_position + Vector3.UP * 0.2, Color(0.75, 0.72, 0.85), 14, 4.0)
		S.JUMP_WIND:
			_t = 0.32 if p2 else 0.42
		S.JUMP_AIR:
			_t = 0.95
			_jump_from = global_position
			var want := _player.global_position + Vector3(_player.velocity.x, 0, _player.velocity.z) * 0.35
			want.y = floor_y
			if arena and arena.has_method("jump_target"):
				want = arena.call("jump_target", _jump_from, want)
			_jump_to = Vector3(want.x, floor_y, want.z)
			_set_solid(false)
			_show_marker(_jump_to)
		S.ROLL_WIND:
			_t = 0.6
		S.ROLL:
			_t = 7.0
			_walls = 0
			_roll_v = 4.0
			_roll_dir = _flat_to_player().normalized() if player_alive() else _forward()
			_set_solid(false)
			_shape.position.y = ROLL_CZ + 0.04
		S.ROLL_STUN:
			_t = roll_stun
			_roll_v = 0.0
		S.SUMMON:
			_t = 1.6
			_launched = 0
			_summon_cd = summon_cooldown
		S.HEAL:
			_t = 99.0
		S.PHASE:
			_t = 1.6
			_open_wounds()
			phase_changed.emit(2)
			DeathFx.sparks(self, global_position + Vector3.UP * CZ, Color(1.0, 0.5, 0.2), 40, 7.0)
			if _player and _player.has_method("shake"):
				_player.shake(0.5)
		S.DOWN:
			_t = 0.0
			_roll_v = 0.0
			_set_solid(true)
			_shape.position.y = CZ
			_unpower.collision_layer = 1
			_unpower_shape.disabled = false
			clear_minions()
			_hide_marker()
			DeathFx.sparks(self, global_position + Vector3.UP * CZ, Color(0.85, 0.9, 1.0), 36, 6.0)
			downed.emit()
	if s != S.ROLL and s != S.ROLL_WIND and s != S.JUMP_AIR and s != S.HOP:
		_shape.position.y = CZ

func _think(delta: float) -> void:
	_time += delta
	_st += delta
	_t -= delta
	_summon_cd -= delta
	if state == S.DORMANT or state == S.OFF:
		_animate(delta, false)
		return
	if not player_alive() and state != S.DOWN and state != S.JUMP_AIR and state != S.ROLL and state != S.HOP:
		if state != S.IDLE:
			_enter(S.IDLE)
		_idle_t = 1.0
		velocity = Vector3.ZERO
		_animate(delta, false)
		return
	var moving := false
	match state:
		S.IDLE:
			moving = _idle(delta)
		S.CANNON:
			_cannon_state(delta)
		S.HOP:
			_hop(delta)
		S.JUMP_WIND:
			_face(_flat_to_player(), 3.0, delta)
			if _t <= 0.0:
				_enter(S.JUMP_AIR)
		S.JUMP_AIR:
			_jump_air()
		S.ROLL_WIND:
			_face(_flat_to_player(), 2.5, delta)
			if _t <= 0.0:
				_enter(S.ROLL)
		S.ROLL:
			_roll(delta)
		S.ROLL_STUN:
			if _t <= 0.0:
				_set_solid(true)
				_eject_player()
				_enter(S.IDLE)
				_idle_t = 0.9
		S.SUMMON:
			_summon_state(delta)
		S.HEAL:
			_heal_state(delta)
		S.PHASE:
			if _t <= 0.0:
				_enter(S.IDLE)
				_idle_t = 0.5
		S.DOWN:
			if fmod(_time, 1.3) < delta:
				DeathFx.sparks(self, global_position + Vector3.UP * (CZ - 0.35) + Vector3(randf_range(-1.2, 1.2), randf_range(-0.4, 1.2), randf_range(-1.2, 1.2)), Color(0.8, 0.85, 1.0), 6, 2.0)
	if state != S.JUMP_AIR and state != S.HOP:
		global_position.y = floor_y
	_animate(delta, moving)

## Shuffle to fighting distance and pick the next attack.
func _idle(delta: float) -> bool:
	var to := _flat_to_player()
	var d := to.length()
	_face(to, 1.9 if phase == 1 else 2.4, delta)
	var want := 8.0 if phase == 1 else 6.5
	var spd := walk_speed * (1.0 if phase == 1 else 1.35)
	var v := Vector3.ZERO
	if d > 0.1:
		var dir := to / d
		if d > want + 2.0:
			v = dir * spd
		elif d < want - 2.0:
			v = -dir * spd * 0.7
		# circle the player, switching direction now and then
		_strafe_t -= delta
		if _strafe_t <= 0.0:
			_strafe = -_strafe if randf() < 0.65 else _strafe
			_strafe_t = randf_range(1.4, 3.0)
		v += dir.cross(Vector3.UP) * _strafe * strafe_speed * (1.0 if phase == 1 else 1.3)
	velocity = v
	move_and_slide()
	for i in get_slide_collision_count():       # walked into a wall or pillar: go the other way round
		var n := get_slide_collision(i).get_normal()
		if absf(n.y) < 0.6 and v.dot(n) < -0.5:
			_strafe = -_strafe
			_strafe_t = randf_range(1.4, 3.0)
			break
	_idle_t -= delta
	if _player_upper() and _idle_t > 0.4:
		_idle_t = 0.4
	if _idle_t <= 0.0 and not hold_ai:
		if _phase_pending:
			_phase_pending = false
			_enter(S.PHASE)
		else:
			_pick()
	return v.length() > 0.1

func _pick() -> void:
	if _player_upper():
		_enter(S.HEAL if _heal_budget > 0.0 and health < max_health else S.CANNON)
		return
	var d := _flat_to_player().length()
	var opts := [[S.CANNON, 3.0 if d > 7.0 else 1.4], [S.JUMP_WIND, 3.0 if d < 10.0 else 1.6]]
	if phase == 2:
		opts.append([S.ROLL_WIND, 2.6 if d > 5.0 else 1.0])
		if _summon_cd <= 0.0 and skates_alive() < max_skates:
			opts.append([S.SUMMON, 3.5])
	var total := 0.0
	for o in opts:
		if o[0] == _last and _repeats >= 1:
			o[1] = 0.0          # never the same attack three times running
		total += float(o[1])
	var r := randf() * total
	var pick: int = opts[0][0]
	for o in opts:
		r -= float(o[1])
		if r <= 0.0:
			pick = o[0]
			break
	_repeats = _repeats + 1 if pick == _last else 0
	_last = pick
	_enter(pick)

# ------------------------------------------------------------------ attacks
## Turret tracks the player, muzzle flares, then three shells 0.2 s apart (each led a little).
func _cannon_state(delta: float) -> void:
	_face(_flat_to_player(), 1.4, delta)
	_aim_at = player_chest() + _player.velocity * 0.12
	if _t > 0.0:
		return
	if _shots < 3:
		_fire_shell()
		_shots += 1
		_t = shot_gap
	elif _t < -0.45:
		_enter(S.IDLE)

func _fire_shell() -> void:
	var from := _muzzle.global_position if _muzzle else global_position + Vector3.UP * (CZ + 2.0)
	var tgt := player_chest()
	var flight := from.distance_to(tgt) / shot_speed
	tgt += Vector3(_player.velocity.x, 0, _player.velocity.z) * flight * 0.6
	tgt += Vector3(randf_range(-0.35, 0.35), randf_range(-0.2, 0.25), randf_range(-0.35, 0.35))
	var dir := (tgt - from).normalized()
	var b := Node3D.new()
	b.set_script(Bolt)
	b.set("velocity", dir * shot_speed)
	b.set("damage", shot_damage)
	b.set("radius", 0.6)
	b.set("life", 2.6)
	b.set("shooter", self)
	b.set("color", Color(1.0, 0.36, 0.14))
	b.scale = Vector3.ONE * 2.2
	b.position = from + dir * 0.3
	DeathFx._host(self).add_child(b)
	DeathFx.sparks(self, from + dir * 0.3, Color(1.0, 0.55, 0.25), 12, 5.0)
	_glow = 40.0
	if _cannon:      # recoil
		var tw := create_tween()
		tw.tween_property(_cannon, "position:z", _cannon.position.z + 0.35, 0.05)
		tw.tween_property(_cannon, "position:z", _cannon.position.z, 0.16)

## Too close for the cannon: a short hop back, away from the player (or angled off it, if a wall's behind),
## turret tracking them all the way. Returns false (fire from here) when there's no room or they're far enough.
func _hop_away() -> bool:
	if not player_alive() or _player_upper():
		return false
	var to := _flat_to_player()
	if to.length() > cannon_keep:
		return false
	var away := -to.normalized() if to.length() > 0.1 else -_forward()
	for dist in [7.0, 5.5, 4.0]:
		for ang in [0.0, 0.6, -0.6, 1.1, -1.1]:
			var p := global_position + away.rotated(Vector3.UP, ang) * float(dist)
			p.y = floor_y
			if arena == null or not arena.has_method("landing_ok") or arena.call("landing_ok", p, 2.8):
				_hop_to = p
				_enter(S.HOP)
				return true
	return false

func _hop(delta: float) -> void:
	var k := clampf(1.0 - _t / hop_time, 0.0, 1.0)
	var p := _hop_from.lerp(_hop_to, k)
	p.y = floor_y + 4.0 * 1.5 * k * (1.0 - k)
	global_position = p
	if player_alive():
		_face(_flat_to_player(), 5.0, delta)
		_aim_at = player_chest()
	if k >= 1.0:
		global_position = _hop_to
		_set_solid(true)
		_eject_player()
		_squash = 0.6
		DeathFx.sparks(self, _hop_to + Vector3.UP * 0.2, Color(0.75, 0.72, 0.85), 18, 4.5)
		if player_alive() and _player.has_method("shake"):
			_player.shake(clampf(0.4 - _flat_to_player().length() / 40.0, 0.1, 0.35))
		_enter(S.CANNON)

## A leap along a parabola to where the player is heading; the landing throws a shockwave.
func _jump_air() -> void:
	var k := clampf(1.0 - _t / 0.95, 0.0, 1.0)
	var p := _jump_from.lerp(_jump_to, k)
	p.y = floor_y + 4.0 * 3.2 * k * (1.0 - k)
	global_position = p
	_face(_jump_to - _jump_from, 4.0, get_physics_process_delta_time())
	if k >= 1.0:
		_land()

func _land() -> void:
	global_position = _jump_to
	_set_solid(true)
	_eject_player()
	_hide_marker()
	_squash = 1.0
	_shockwave(_jump_to)
	DeathFx.sparks(self, _jump_to + Vector3.UP * 0.2, Color(0.75, 0.72, 0.85), 30, 6.0)
	if player_alive():
		var off := _player.global_position - _jump_to
		var flat := Vector2(off.x, off.z).length()
		if _player.has_method("shake"):
			_player.shake(clampf(1.0 - flat / 18.0, 0.15, 0.8))
		var grounded: bool = _player.is_on_floor() and absf(_player.global_position.y - floor_y) < 1.0
		if grounded and flat < jump_radius:
			var out := Vector3(off.x, 0, off.z).normalized() if flat > 0.1 else _forward()
			_player.take_damage(jump_damage, "", out * 9.0 + Vector3.UP * 4.0)
	if _down_pending:
		_down_pending = false
		_enter(S.DOWN)
	elif _phase_pending:
		_phase_pending = false
		_enter(S.PHASE)
	else:
		_enter(S.IDLE)
		_idle_t = 0.9 if phase == 2 else 1.3

## Folded into a ball, the star spinning: charges, steering after the player; bounces off walls.
func _roll(delta: float) -> void:
	_roll_v = move_toward(_roll_v, roll_speed, delta * 30.0)
	if player_alive():
		var to := _flat_to_player().normalized()
		var a := _roll_dir.signed_angle_to(to, Vector3.UP)
		_roll_dir = _roll_dir.rotated(Vector3.UP, clampf(a, -roll_turn * delta, roll_turn * delta))
	_face(_roll_dir, 12.0, delta)
	velocity = _roll_dir * _roll_v
	move_and_slide()
	_shell.rotation.x -= _roll_v / R * delta
	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		var n := c.get_normal()
		if absf(n.y) < 0.6 and _roll_dir.dot(n) < -0.2:
			_walls += 1
			n.y = 0.0
			n = n.normalized()
			_roll_dir = _roll_dir.bounce(n).normalized()
			_roll_v *= 0.7
			DeathFx.sparks(self, c.get_position(), Color(1.0, 0.75, 0.4), 30, 7.0)
			if _player and _player.has_method("shake"):
				_player.shake(0.35)
			break
	if player_alive():
		var off := _player.global_position - global_position
		if Vector2(off.x, off.z).length() < R + PAD + 0.5 and off.y < 2.0 * R and off.y > -0.6:
			_roll_hit()
			_enter(S.ROLL_STUN)
			return
	if _walls >= 2 or _t <= 0.0:
		_enter(S.ROLL_STUN)

func _roll_hit() -> void:
	var knock := _roll_dir * 13.0 + Vector3.UP * 5.0
	var sh := 0.0
	if _player.get("has_drone"):
		sh = float(_player.get("shield"))
	if sh > 0.0:
		_player.take_damage(sh, "", knock)      # a raised shield takes the whole hit, and breaks
		_player.velocity += knock
	else:
		_player.take_damage(roll_damage, "", knock)
	DeathFx.sparks(self, _player.global_position + Vector3.UP, Color(1.0, 0.8, 0.5), 24, 6.0)

func _summon_state(delta: float) -> void:
	_face(_flat_to_player(), 1.2, delta)
	if _launched == 0 and _st > 0.5:
		var n := maxi(mini(randi_range(1, 2), max_skates - skates_alive()), 1)
		for i in n:
			get_tree().create_timer(0.35 * i).timeout.connect(_launch_skate)
		_launched = n
	if _t <= 0.0:
		_enter(S.IDLE)

func _launch_skate() -> void:
	if state == S.DOWN or state == S.OFF or not is_inside_tree() or skates_alive() >= max_skates:
		return
	var s := Skate.new() as CharacterBody3D
	s.name = "BossSkate%d" % randi_range(0, 9999)
	s.position = (_mouth.global_position if _mouth else global_position + Vector3.UP * (CZ + 2.0)) + Vector3.UP * 0.5
	s.rotation.y = rotation.y + PI
	get_parent().add_child(s)
	s.velocity = global_basis.z * 4.0 + Vector3.UP * 7.0
	s.add_to_group("boss_minions")
	_skates.append(s)
	DeathFx.sparks(self, s.global_position, Color(1.0, 0.6, 0.2), 16, 4.0)

## Player gone up to regen: it plants itself and draws power (at most heal_per_retreat), then shells them.
func _heal_state(delta: float) -> void:
	_face(_flat_to_player(), 1.0, delta)
	if not _player_upper():
		_enter(S.IDLE)
		_idle_t = 0.3
		return
	if _st < 0.5:
		return
	var h := minf(heal_rate * delta, minf(_heal_budget, max_health - health))
	health += h
	_heal_budget -= h
	health_changed.emit(health, max_health)
	if _heal_budget <= 0.01 or health >= max_health:
		_heal_budget = 0.0
		_enter(S.CANNON)

## Seized (DOWN) -> powered off. `instant`: the husk on later visits.
func _go_off(instant: bool) -> void:
	state = S.OFF
	_roll_v = 0.0
	_spin = 0.0
	_unpower.collision_layer = 0
	_unpower_shape.disabled = true
	_set_solid(true)
	_shape.position.y = CZ
	clear_minions()
	for w in _wounds:
		w.emitting = false
	if instant:
		_slump = 1.0
		_glow = 0.0
		_hatch_open = 0.35
		_apply_pose(0.0)
	else:
		DeathFx.sparks(self, global_position + Vector3.UP * CZ, Color(0.7, 0.8, 1.0), 40, 5.0)
	remove_from_group("enemies")

# ------------------------------------------------------------------ markers + shockwave
func _ring(radius: float, col: Color, width: float) -> MeshInstance3D:
	var t := TorusMesh.new()
	t.inner_radius = radius - width
	t.outer_radius = radius
	t.rings = 48
	t.ring_segments = 4
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = col
	t.material = m
	var mi := MeshInstance3D.new()
	mi.mesh = t
	mi.scale = Vector3(1, 0.05, 1)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.layers = 2
	return mi

## Where a leap will land: a red ring on the floor for the whole flight.
func _show_marker(at: Vector3) -> void:
	_hide_marker()
	_marker = _ring(jump_radius, Color(1.0, 0.18, 0.1, 0.5), 0.25)
	DeathFx._host(self).add_child(_marker)
	_marker.global_position = at + Vector3.UP * 0.06

func _hide_marker() -> void:
	if _marker and is_instance_valid(_marker):
		_marker.queue_free()
	_marker = null

func _exit_tree() -> void:
	_hide_marker()

func _shockwave(at: Vector3) -> void:
	var r := _ring(1.0, Color(1.0, 0.8, 0.6, 0.9), 0.18)
	DeathFx._host(self).add_child(r)
	r.global_position = at + Vector3.UP * 0.1
	var m := (r.mesh as TorusMesh).material as StandardMaterial3D
	var tw := r.create_tween()
	tw.tween_property(r, "scale", Vector3(jump_radius, 0.3, jump_radius), 0.35).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(m, "albedo_color:a", 0.0, 0.45)
	tw.tween_callback(r.queue_free)

# ------------------------------------------------------------------ animation
func _animate(delta: float, moving: bool) -> void:
	var fold_t := 0.0
	var squash_t := 0.0
	var slump_t := 0.0
	var spin_t := 0.4
	var hatch_t := 0.0
	var g := 8.0 + sin(_time * 2.2) * 2.0
	var aim_t := 0.0
	match state:
		S.DORMANT:
			g = 0.6
			spin_t = 0.0
		S.CANNON:
			aim_t = 1.0
			g = lerpf(10.0, 32.0, clampf(_st / 0.4, 0.0, 1.0))
		S.JUMP_WIND:
			squash_t = 1.0
			g = 22.0
		S.JUMP_AIR:
			g = 16.0
		S.HOP:
			aim_t = 1.0
			g = 18.0
		S.ROLL_WIND:
			fold_t = 1.0
			spin_t = 22.0
			g = 26.0
		S.ROLL:
			fold_t = 1.0
			spin_t = 22.0
			g = 26.0
		S.ROLL_STUN:
			fold_t = 1.0 if _t > 0.55 else 0.0
			spin_t = 2.0
			g = 2.0 + (4.0 if fmod(_time, 0.23) < 0.08 else 0.0)
		S.SUMMON:
			hatch_t = 1.0 if _st < 1.3 else 0.0
			g = 14.0
		S.HEAL:
			spin_t = 1.4
			g = 12.0 + sin(_time * 5.0) * 5.0
		S.PHASE:
			spin_t = 8.0
			g = 40.0 if fmod(_time, 0.12) < 0.07 else 8.0
		S.DOWN:
			slump_t = 0.7
			spin_t = 0.0
			g = 1.0 + (3.5 if fmod(_time, 0.9) < 0.1 else 0.0)
		S.OFF:
			slump_t = 1.0
			spin_t = 0.0
			hatch_t = 0.35
			g = 0.0
	_fold = move_toward(_fold, fold_t, delta * 2.6)
	_squash = move_toward(_squash, squash_t, delta * (6.0 if squash_t > _squash else 2.5))
	_slump = move_toward(_slump, slump_t, delta * (0.8 if state == S.OFF else 1.6))
	_spin = lerpf(_spin, spin_t, clampf(delta * (1.5 if spin_t > _spin else 0.8), 0.0, 1.0))
	_hatch_open = move_toward(_hatch_open, hatch_t, delta * 3.0)
	_glow = lerpf(_glow, g, clampf(delta * 10.0, 0.0, 1.0))
	_aim_w = move_toward(_aim_w, aim_t, delta * 4.0)
	_lurch = lerpf(_lurch, 1.0 if moving else 0.0, clampf(delta * 4.0, 0.0, 1.0))
	if not _solid_shape.disabled:     # pylon + skid boxes off while the legs are folded
		for i in range(1, _solid_legs.size()):
			var off := _fold > 0.3
			if _solid_legs[i].disabled != off:
				_solid_legs[i].disabled = off
	if _roll_sparks:
		_roll_sparks.emitting = state == S.ROLL
	if _heal_fx:
		_heal_fx.emitting = state == S.HEAL and _st > 0.5
	if _eye_light:
		_eye_light.light_color = Color(0.55, 0.95, 1.0) if state == S.HEAL else glow_color
	_apply_pose(delta)

func _apply_pose(delta: float) -> void:
	if _frame == null:
		return
	var drop := 0.3 * _squash + 0.37 * _slump
	var bob := absf(sin(_time * 3.2)) * 0.07 * _lurch
	_frame.position.y = lerpf(CZ, ROLL_CZ, _fold) / SC - drop + bob     # model units
	var rear := sin(_st * 9.0) * 0.12 * clampf(_t / 1.6, 0.0, 1.0) if state == S.PHASE else 0.0
	var lean := sin(clampf(1.0 - _t / hop_time, 0.0, 1.0) * PI) * 0.16 if state == S.HOP else 0.0     # rocks back in a hop
	_frame.rotation.x = -0.18 * _slump + rear + lean
	_frame.rotation.z = sin(_time * 3.2) * 0.045 * _lurch
	# the legs splay as the hull sinks (feet stay on the floor), and swing up behind it to roll
	var splay := acos(clampf(1.0 - drop * SC / CZ, -1.0, 1.0))
	if _leg:
		_leg.rotation = Vector3(-2.3 * _fold, 0.0, splay)
	if _skid:
		_skid.rotation = Vector3(-2.3 * _fold, 0.0, -splay)
	if _star:
		_star.position = _star_pos0 + Vector3(0, -0.04 * _fold, 0)     # its points just scrape the floor in a roll
		_star.rotation.z = wrapf(_star.rotation.z + _spin * delta, -PI, PI)
	if _shell and state != S.ROLL and _fold < 0.9:
		var home := roundf(_shell.rotation.x / TAU) * TAU
		_shell.rotation.x = lerpf(_shell.rotation.x, home, clampf(delta * 3.0, 0.0, 1.0))
	if _turret and _cannon:
		var yaw := 0.0
		var pitch := 0.45 * _fold
		if _aim_w > 0.01:
			var par := _turret.get_parent() as Node3D
			var d := par.global_basis.inverse() * (_aim_at - _turret.global_position)
			yaw = clampf(atan2(-d.x, -d.z), -1.3, 1.3) * _aim_w
			pitch = clampf(atan2(d.y, Vector2(d.x, d.z).length()), -0.5, 0.9) * _aim_w
		_turret.rotation.y = lerp_angle(_turret.rotation.y, yaw, clampf(delta * 8.0, 0.0, 1.0))
		_cannon.rotation.x = lerpf(_cannon.rotation.x, pitch, clampf(delta * 8.0, 0.0, 1.0))
	if _hatch:
		_hatch.rotation.x = -1.4 * _hatch_open
	if _eye_mat:
		_eye_mat.emission_energy_multiplier = _glow
	if _eye_light:
		_eye_light.light_energy = _glow * 0.08
	if _eye_beam:
		_eye_beam.light_energy = _glow * 0.35
		_eye_beam.light_color = _eye_light.light_color if _eye_light else glow_color
		_eye_beam.visible = _glow > 0.2
	if _halo_mat:
		_halo_mat.albedo_color = Color(_eye_beam.light_color if _eye_beam else glow_color, clampf(_glow / 14.0, 0.0, 1.0) * 0.9)
		_eye_halo.scale = Vector3.ONE * (0.8 + clampf(_glow / 40.0, 0.0, 1.0) * 0.8)
