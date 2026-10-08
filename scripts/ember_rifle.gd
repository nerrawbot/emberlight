extends Node3D
## v16: the Ember rifle kit (debug only for now: console `rifle`). A furnace long-gun from Emberlight, held in view
## (assets/props/ember_rifle.glb, art_src/v16_ember_rifle.py), added under the camera by player.gd set_rifle_kit().
##   LMB         hipfire: a horizontal fan of PELLETS ember shots; the shaft damage (player.attack_damage) is split
##               evenly over them, so a target caught by every pellet takes exactly one shaft hit.
##   RMB hold    aim: the gun comes up to the eye, the view narrows, the player slows; it charges while held
##               (1x -> MAX_MULT x the shaft damage over CHARGE_TIME). Release fires one heavy ember bolt.
##   (auto)      after every shot the lever cycles and the chamber re-lights (reload); the Q back leap (player.gd)
##               finishes a reload instantly.
## Hits go through the same take_hit(by, dir) as the shaft: attack_damage is set to the shot damage for the call.

const MODEL := "res://assets/props/ember_rifle.glb"
const PAINT := preload("res://scripts/creatures/painterly.gdshader")
const BRUSH := "res://assets/creatures/sph_paint_brush.png"
const DeathFx := preload("res://scripts/creatures/death_fx.gd")
const EMBER := Color(1.0, 0.46, 0.14)
const EMBER_HOT := Color(1.0, 0.78, 0.42)

const PELLETS := 5
const FAN_DEG := 24.0            # full width of the hipfire fan
const PELLET_RANGE := 28.0
const CHARGE_TIME := 1.4
const MAX_MULT := 4.0
const BOLT_RANGE := 140.0
const RELOAD_HIP := 0.8
const RELOAD_BOLT := 1.1
const AIM_FOV := 0.55            # x the base fov
const AIM_MOVE := 0.45           # x walk speed at full aim
const HIT_MASK := 1 | 8          # world + scuttlers (as the shaft)
const KICK_HIP := 0.8            # recoil strength: hipfire, and the bolt from a tap to a full charge
const KICK_BOLT := Vector2(1.0, 1.9)
const CLIMB := 0.035             # rad the view climbs per unit of kick
const RECOVER := 0.6             # share of the climb that settles back by itself
const SPRING_K := 320.0
const SPRING_D := 24.0           # a touch under critical: snaps back with a small overshoot

const HIP_POS := Vector3(0.25, -0.3, -0.46)
const HIP_ROT := Vector3(0.06, 0.1, -0.06)
# the rear notch (glb (0, 0.158, -0.004)) sits just under the eye; tipped up so the front post meets it
const AIM_POS := Vector3(0.0, -0.176, -0.34)
const AIM_ROT := Vector3(0.044, 0.0, 0.0)

var player: CharacterBody3D
var camera: Camera3D
var loaded := true
var aiming := false
var charge := 0.0
var aim_blend := 0.0
var reload_amt := 0.0            # 0..1, the reload swing (tweened)
var reload_frac := 1.0           # reload progress for the HUD
var _model: Node3D
var _lever: Node3D
var _muzzle: Node3D
var _coal_mat: ShaderMaterial
var _vent_mat: ShaderMaterial
var _flash: OmniLight3D
# recoil: a kick into two springs (position, rotation) that snap the gun back with a little overshoot; the view
# climbs and settles back RECOVER of the way on its own (_climb left to recover)
var _rp := Vector3.ZERO
var _rpv := Vector3.ZERO
var _rr := Vector3.ZERO
var _rrv := Vector3.ZERO
var _heat := 0.0                 # vents flare after a shot
var _climb := 0.0
var _base_pos := Vector3.ZERO
var _base_rot := Vector3.ZERO
var _reload_tw: Tween
var _t := 0.0
var _hud: Control
var _fov_on := false
var _base_fov := 75.0

func _ready() -> void:
	name = "EmberRifle"
	camera = player.get("camera") as Camera3D if player else get_viewport().get_camera_3d()
	_base_fov = float(player.get("_base_fov")) if player else camera.fov
	_model = (load(MODEL) as PackedScene).instantiate() as Node3D
	add_child(_model)
	_paint(_model)
	_lever = _model.find_child("Lever", true, false) as Node3D
	_muzzle = _model.find_child("Muzzle", true, false) as Node3D
	_flash = OmniLight3D.new()
	_flash.light_color = EMBER_HOT
	_flash.omni_range = 6.0
	_flash.light_energy = 0.0
	_flash.shadow_enabled = false
	_flash.light_volumetric_fog_energy = 0.5
	(_muzzle if _muzzle else self).add_child(_flash)
	_base_pos = HIP_POS + Vector3(0.05, -0.5, 0.2)
	_base_rot = HIP_ROT + Vector3(0.8, 0, -0.4)
	position = _base_pos
	rotation = _base_rot
	var hud_parent := player.get_node_or_null("HUD") if player else null
	if hud_parent:
		_hud = RifleHud.new()
		_hud.rifle = self
		hud_parent.add_child(_hud)
		hud_parent.move_child(_hud, 0)

func _exit_tree() -> void:
	if _hud:
		_hud.queue_free()
	if player:
		player.set("move_mult", 1.0)
		player.set("look_mult", 1.0)
	if _fov_on and camera:
		camera.fov = _base_fov

## glb colours / graded textures -> the creatures' painterly shader; the coal + vents glow (their emission is driven in _process)
func _paint(root: Node) -> void:
	for n in root.find_children("*", "MeshInstance3D", true, false):
		var g := n as MeshInstance3D
		g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		g.layers = 2
		for s in g.mesh.get_surface_count():
			var src := g.mesh.surface_get_material(s) as StandardMaterial3D
			if src == null:
				continue
			var sm := ShaderMaterial.new()
			sm.shader = PAINT
			sm.set_shader_parameter("brush", load(BRUSH))
			sm.set_shader_parameter("use_paint", false)
			sm.set_shader_parameter("tint", src.albedo_color)
			if src.albedo_texture:      # the palette-graded Poly Haven maps (art_src/tex/er_*.png), through the mesh UVs
				sm.set_shader_parameter("use_paint", true)
				sm.set_shader_parameter("paint", src.albedo_texture)
				sm.set_shader_parameter("proj", 4)
			sm.set_shader_parameter("shade_color", Color(0.36, 0.16, 0.2))
			sm.set_shader_parameter("rim_amt", 0.14)
			sm.set_shader_parameter("rim_color", Color(1.0, 0.55, 0.32))
			sm.set_shader_parameter("spec_amt", 0.5 if src.metallic > 0.5 else 0.25)
			if src.resource_name == "M_ER_Coal":
				_coal_mat = sm
				sm.set_shader_parameter("emission_color", EMBER)
			elif src.resource_name == "M_ER_Vent":
				_vent_mat = sm
				sm.set_shader_parameter("emission_color", EMBER)
			g.set_surface_override_material(s, sm)

# ---------------------------------------------------------------- per frame: pose, charge, glow, fov
func _process(delta: float) -> void:
	_t += delta
	var gliding := bool(player.get("gliding")) if player else false
	visible = not gliding
	if aiming and (gliding or not bool(player.get("input_enabled"))):
		aiming = false
		charge = 0.0
	if aiming and loaded:
		charge = minf(1.0, charge + delta / CHARGE_TIME)
	aim_blend = move_toward(aim_blend, 1.0 if aiming else 0.0, delta / 0.16)
	var a := aim_blend * aim_blend * (3.0 - 2.0 * aim_blend)
	_heat = maxf(0.0, _heat - delta * 3.5)
	var dt := minf(delta, 0.05)
	_rpv += (-_rp * SPRING_K - _rpv * SPRING_D) * dt
	_rp += _rpv * dt
	_rrv += (-_rr * SPRING_K - _rrv * SPRING_D) * dt
	_rr += _rrv * dt
	# the view settles back most of the way after the climb
	if _climb > 0.0001 and player:
		var head := player.get("head") as Node3D
		var back := _climb * (1.0 - exp(-delta * 7.0))
		_climb -= back
		if head:
			head.rotation.x = clampf(head.rotation.x - back, deg_to_rad(-88), deg_to_rad(88))
	# pose: hip <-> aim, the reload swing, a little breathing sway (less when aiming), the full-charge tremble,
	# then the recoil springs on top (unsmoothed, so the kick is instant)
	var pos := HIP_POS.lerp(AIM_POS, a)
	var rot := HIP_ROT.lerp(AIM_ROT, a)
	pos += Vector3(0.03, -0.08, 0.06) * reload_amt * (1.0 - a * 0.6)
	rot += Vector3(0.28, 0.1, 0.42) * reload_amt * (1.0 - a * 0.6)
	var sway := (1.0 - a * 0.8) * 0.006
	pos += Vector3(sin(_t * 1.3) * sway, sin(_t * 2.6) * sway * 0.6, 0)
	if aiming and charge >= 1.0:
		pos += Vector3(sin(_t * 61.0), cos(_t * 53.0), 0) * 0.0012
	_base_pos = _base_pos.lerp(pos, 1.0 - exp(-delta * 22.0))
	_base_rot = _base_rot.lerp(rot, 1.0 - exp(-delta * 22.0))
	position = _base_pos + _rp
	rotation = _base_rot + _rr
	# glow: the coal breathes, dims while the lever is back, the vents flare with the charge
	var coal := (0.0 if not loaded else 1.0) * (1.0 + 0.25 * sin(_t * 5.0) + 0.15 * sin(_t * 13.0))
	coal = maxf(coal, 0.25 + 0.75 * reload_frac * (1.0 - reload_amt))
	if _coal_mat:
		_coal_mat.set_shader_parameter("emission_amt", coal + charge * 1.4)
		_coal_mat.set_shader_parameter("emission_color", EMBER.lerp(EMBER_HOT, charge))
	if _vent_mat:
		var flick := 0.85 + 0.15 * sin(_t * 31.0 + sin(_t * 7.0) * 3.0)
		_vent_mat.set_shader_parameter("emission_amt", (0.25 + charge * charge * 4.5) * flick + _heat * 3.0)
		_vent_mat.set_shader_parameter("emission_color", EMBER.lerp(EMBER_HOT, charge))
	if _flash:
		_flash.light_energy = maxf(0.0, _flash.light_energy - delta * 40.0)
	# view: narrower while aiming (a touch more as it charges), slower feet, slower look
	if a > 0.001 or _fov_on:
		camera.fov = lerpf(_base_fov, _base_fov * AIM_FOV * (1.0 - 0.08 * charge), a)
		_fov_on = a > 0.001
	if player:
		player.set("move_mult", lerpf(1.0, AIM_MOVE, a))
		player.set("look_mult", camera.fov / _base_fov if _fov_on else 1.0)

# ---------------------------------------------------------------- input (called by player.gd while the kit is on)
## LMB: the fan. Ignored while aiming (release RMB to fire) or reloading.
func hipfire() -> bool:
	if not loaded or aiming or not visible:
		return false
	var base := _base_damage()
	var fwd := -camera.global_basis.z
	var up := camera.global_basis.y
	var right := camera.global_basis.x
	var hits := {}
	for i in PELLETS:
		var t := (float(i) / (PELLETS - 1)) - 0.5 if PELLETS > 1 else 0.0
		var yaw := deg_to_rad(t * FAN_DEG + randf_range(-1.2, 1.2))
		var pitch := deg_to_rad(randf_range(-1.6, 1.6))
		var d := fwd.rotated(up, yaw)
		d = d.rotated(right, pitch).normalized()
		_ray(d, PELLET_RANGE, base / PELLETS, hits, 0.022)
	_deal(hits, fwd)
	_fired(KICK_HIP, 0.2, RELOAD_HIP)
	if _hud:
		_hud.call("bloom")
	return true

func aim_press() -> void:
	if not visible:
		return
	aiming = true
	charge = 0.0

## RMB released: fire the charged bolt if loaded (else just lower the gun).
func aim_release() -> bool:
	if not aiming:
		return false
	aiming = false
	var c := charge
	charge = 0.0
	if not loaded or not visible:
		return false
	var mult := 1.0 + (MAX_MULT - 1.0) * c
	var hits := {}
	var fwd := -camera.global_basis.z
	_ray(fwd, BOLT_RANGE, _base_damage() * mult, hits, 0.03 + 0.05 * c)
	_deal(hits, fwd)
	_fired(lerpf(KICK_BOLT.x, KICK_BOLT.y, c), 0.25 + 0.35 * c, RELOAD_BOLT)
	if player and c > 0.5:            # a heavy bolt shoves you back a step
		var back := Vector3(fwd.x, 0, fwd.z).normalized() * -(c - 0.5) * 7.0
		player.velocity += back
	return true

## The back leap: the lever slams home mid-air.
func finish_reload() -> void:
	if loaded:
		return
	if _reload_tw:
		_reload_tw.kill()
	_reload_done()
	if _lever:
		_lever.rotation = Vector3.ZERO

func current_mult() -> float:
	return 1.0 + (MAX_MULT - 1.0) * charge

# ---------------------------------------------------------------- shots
func _base_damage() -> float:
	var d: Variant = player.get("attack_damage") if player else null
	return 30.0 if d == null else float(d)

## one hitscan ray from the eye; damage piles up per collider in `hits`, then a tracer from the muzzle to where it landed
func _ray(dir: Vector3, length: float, dmg: float, hits: Dictionary, width: float) -> void:
	var from := camera.global_position
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * length, HIT_MASK)
	q.exclude = [player.get_rid()] if player else []
	var r := get_world_3d().direct_space_state.intersect_ray(q)
	var end := from + dir * length
	if not r.is_empty():
		end = r.position
		var c: Object = r.collider
		if c.has_method("take_hit"):
			hits[c] = float(hits.get(c, 0.0)) + dmg
		elif c is RigidBody3D:
			var rb := c as RigidBody3D
			rb.apply_impulse(dir * 3.5 * rb.mass * dmg / 30.0, r.position - rb.global_position)
		DeathFx.sparks(player, r.position + r.normal * 0.05, EMBER_HOT, 5 if width < 0.03 else 12, 3.0 + width * 40.0)
	var mz := _muzzle.global_position if _muzzle else global_position
	_tracer(mz, end, width)

func _deal(hits: Dictionary, dir: Vector3) -> void:
	if hits.is_empty():
		return
	var keep := _base_damage()
	for c in hits:
		if is_instance_valid(c):
			player.set("attack_damage", hits[c])
			c.call("take_hit", player, dir)
	player.set("attack_damage", keep)
	if _hud:
		_hud.call("hit_mark")

func _fired(kick: float, shake: float, reload: float) -> void:
	loaded = false
	_heat = 1.0
	# the gun slams back and the muzzle flips up, with a random twist; less shove at the eye (it'd clip the camera)
	var a := aim_blend
	_rpv += Vector3(randf_range(-0.25, 0.25), 0.35 + 0.4 * a, 3.2 * (1.0 - 0.55 * a)) * kick
	_rrv += Vector3(6.0, randf_range(-1.6, 1.6), randf_range(-2.4, 2.4)) * kick
	if _flash:
		_flash.light_energy = 6.0 + kick * 6.0
	if player:
		player.call("shake", shake)
		player.call("punch", Vector3(1.1, randf_range(-0.35, 0.35), randf_range(-0.6, 0.6)) * kick)
		var head := player.get("head") as Node3D
		if head:          # the view climbs; most of it settles back (_process), the rest is yours to pull down
			var up := CLIMB * kick
			head.rotation.x = clampf(head.rotation.x + up, deg_to_rad(-88), deg_to_rad(88))
			_climb += up * RECOVER
	if _muzzle:
		var mz := _muzzle.global_position
		var dir := -camera.global_basis.z
		DeathFx.sparks(player, mz, EMBER_HOT, 8 + int(kick * 6.0), 2.5 + kick * 2.0)
		_muzzle_flash(kick)
		_smoke(mz + dir * 0.1, dir, 3 + int(kick * 4.0))
	# the auto reload: the gun rolls out, the lever racks back and slams home, the chamber relights
	reload_frac = 0.0
	if _reload_tw:
		_reload_tw.kill()
	_reload_tw = create_tween()
	_reload_tw.tween_interval(0.1)
	_reload_tw.tween_property(self, "reload_amt", 1.0, reload * 0.25).set_trans(Tween.TRANS_SINE)
	if _lever:
		_reload_tw.tween_property(_lever, "rotation:y", -1.1, reload * 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_reload_tw.tween_interval(reload * 0.08)
		_reload_tw.tween_property(_lever, "rotation:y", 0.0, reload * 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_reload_tw.tween_property(self, "reload_amt", 0.0, reload * 0.27).set_trans(Tween.TRANS_SINE)
	_reload_tw.parallel().tween_property(self, "reload_frac", 1.0, reload * 0.27)
	_reload_tw.tween_callback(_reload_done)

func _reload_done() -> void:
	loaded = true
	reload_frac = 1.0
	reload_amt = 0.0
	_rrv += Vector3(-0.8, 0.0, 0.6)         # the lever slamming home jolts the gun
	if player:
		player.call("shake", 0.05)

## a hot star at the muzzle for a couple of frames (two crossed billboards, additive), rides with the gun
func _muzzle_flash(kick: float) -> void:
	if _muzzle == null:
		return
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.billboard_keep_scale = true
	m.albedo_texture = DeathFx.soft_tex()
	m.albedo_color = Color(EMBER_HOT.r * 2.4, EMBER_HOT.g * 1.8, EMBER_HOT.b * 1.2, 1.0)
	m.disable_receive_shadows = true
	var root := Node3D.new()
	_muzzle.add_child(root)
	for s in [Vector2(0.34, 0.34), Vector2(0.62, 0.16)]:
		var q := QuadMesh.new()
		q.size = s * (0.7 + 0.35 * kick)
		q.material = m
		var mi := MeshInstance3D.new()
		mi.mesh = q
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.layers = 2
		root.add_child(mi)
	var tw := root.create_tween().set_parallel()
	tw.tween_property(root, "scale", Vector3.ONE * 1.5, 0.07).set_ease(Tween.EASE_OUT)
	tw.tween_property(m, "albedo_color:a", 0.0, 0.07)
	tw.chain().tween_callback(root.queue_free)

## a puff of grey-violet smoke rolling out of the muzzle, left behind in the world
func _smoke(at: Vector3, dir: Vector3, n: int) -> void:
	var pm := ParticleProcessMaterial.new()
	pm.direction = dir
	pm.spread = 22.0
	pm.initial_velocity_min = 0.5
	pm.initial_velocity_max = 2.4
	pm.gravity = Vector3(0, 0.4, 0)
	pm.damping_min = 2.5
	pm.damping_max = 4.0
	pm.angle_min = -180.0
	pm.angle_max = 180.0
	pm.scale_min = 0.6
	pm.scale_max = 1.2
	pm.scale_curve = DeathFx._curve([Vector2(0, 0.25), Vector2(1, 1.0)])
	pm.color_ramp = DeathFx._ramp([Color(0.6, 0.42, 0.36, 0.0), Color(0.36, 0.33, 0.42, 0.4), Color(0.26, 0.25, 0.32, 0.0)], [0.0, 0.12, 1.0])
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = DeathFx.soft_tex()
	m.roughness = 1.0
	var q := QuadMesh.new()
	q.size = Vector2(0.45, 0.45)
	q.material = m
	var e := DeathFx._emitter("MuzzleSmoke", n, 1.1, pm, q)
	e.explosiveness = 0.9
	(player.get_parent() if player else get_tree().current_scene).add_child(e)
	e.global_position = at
	e.emitting = true
	DeathFx._free_after(e, 1.6)

## a streak of glowing slag from the muzzle to the hit, fading fast
func _tracer(from: Vector3, to: Vector3, width: float) -> void:
	var len := from.distance_to(to)
	if len < 0.05:
		return
	var host := player.get_parent() if player else get_tree().current_scene
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(width, width, len)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = Color(EMBER_HOT.r * 2.0, EMBER_HOT.g * 1.6, EMBER_HOT.b, 1.0)
	m.disable_receive_shadows = true
	bm.material = m
	mi.mesh = bm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.layers = 2
	host.add_child(mi)
	mi.global_position = (from + to) * 0.5
	mi.look_at(to, Vector3.UP if absf((to - from).normalized().y) < 0.99 else Vector3.RIGHT)
	var life := 0.1 + width * 4.0
	var tw := mi.create_tween().set_parallel()
	tw.tween_property(mi, "scale", Vector3(0.15, 0.15, 1.0), life).set_ease(Tween.EASE_IN)
	tw.tween_property(m, "albedo_color:a", 0.0, life)
	tw.chain().tween_callback(mi.queue_free)

# ---------------------------------------------------------------- HUD: fan brackets, reload ticks, aim reticle + charge
class RifleHud extends Control:
	var rifle: Node3D
	var _hit := 0.0
	var _bloom := 0.0

	func _init() -> void:
		name = "RifleHud"
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_preset(Control.PRESET_FULL_RECT)

	func hit_mark() -> void:
		_hit = 1.0

	## the fan brackets jump out after a hipfire shot and draw back in
	func bloom() -> void:
		_bloom = 1.0

	func _process(delta: float) -> void:
		_hit = maxf(0.0, _hit - delta * 4.0)
		_bloom = maxf(0.0, _bloom - delta * 3.0)
		queue_redraw()

	func _draw() -> void:
		if rifle == null or not rifle.visible:
			return
		var c := size * 0.5
		var cam := rifle.get("camera") as Camera3D
		var a: float = rifle.get("aim_blend")
		var ember := Color(1.0, 0.55, 0.22)
		var loaded: bool = rifle.get("loaded")
		var dimmed := 1.0 if loaded else 0.35
		# hipfire: chevrons at the edges of the fan
		if a < 0.99 and cam:
			var half := tan(deg_to_rad(FAN_DEG * 0.5)) / tan(deg_to_rad(cam.fov * 0.5)) * size.y * 0.5
			half += 26.0 * _bloom * _bloom
			var al := (1.0 - a) * 0.8 * dimmed
			for s in [-1.0, 1.0]:
				var x: float = c.x + s * half
				draw_polyline(PackedVector2Array([Vector2(x + s * 7, c.y - 9), Vector2(x, c.y), Vector2(x + s * 7, c.y + 9)]),
					Color(ember, al), 2.0)
		# reload: six ticks under the crosshair filling up
		var rf: float = rifle.get("reload_frac")
		if rf < 1.0:
			for i in 6:
				var on := rf * 6.0 > i
				draw_rect(Rect2(c.x - 27 + i * 9, c.y + 22, 6, 3), Color(ember, 0.9 if on else 0.22))
		# aiming: a thin reticle and four charge pips (1x .. 4x)
		if a > 0.01:
			var k: float = rifle.call("current_mult")
			var gap := 10.0 + (1.0 - a) * 20.0
			var col := Color(ember.lerp(Color(1, 0.86, 0.6), (k - 1.0) / 3.0), a * dimmed)
			for d in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1)]:
				draw_line(c + d * gap, c + d * (gap + 14.0), col, 1.5)
			for i in 4:
				var lit: float = clampf(k - float(i), 0.0, 1.0) if i > 0 else 1.0
				var r := Rect2(c.x - 29 + i * 15, c.y - 34, 12, 5)
				draw_rect(r, Color(0.05, 0.03, 0.02, 0.6 * a))
				draw_rect(Rect2(r.position, Vector2(r.size.x * lit, r.size.y)), Color(col, a * dimmed))
				draw_rect(r, Color(ember, 0.5 * a), false, 1.0)
		# hit marker
		if _hit > 0.0:
			for d in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
				draw_line(c + d * 6.0, c + d * 12.0, Color(1, 0.9, 0.75, _hit), 2.0)
