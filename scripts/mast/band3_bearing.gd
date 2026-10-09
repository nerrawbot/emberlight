extends Node
## v19, mast band 3: BEARING. A steerable dish on the band's south strip and a sighting pedestal beside it
## (art_src/v19_mast_signal.py band3()). [E] at the eyepiece looks through the dish: a zoomed camera on it, the player
## frozen. Mouse / WASD aim (Shift fine, wheel zooms), Space or LMB locks, E or Esc steps back. The pictogram on the
## pedestal says to follow the cable line out: past its pylon, ~700 m out in the haze, Ember's lights (they only show
## through the sight until it has found them; from then on they stay lit on the horizon). Locked on them, mast_signal.tune(3) swings the hop flaps up. A "signal" bar in
## the scope stirs within a few degrees of them.

const MastUse := preload("res://scripts/mast/mast_use.gd")
const YAW_LIMIT := deg_to_rad(115.0)
const PITCH_MIN := deg_to_rad(-20.0)
const PITCH_MAX := deg_to_rad(35.0)
const LOCK_ANGLE := deg_to_rad(1.6)
const SIGNAL_ANGLE := deg_to_rad(7.0)
const FOV_WIDE := 24.0
const FOV_NARROW := 4.0

var sig: Node
var solved := false
var scoped := false
var yaw := 0.0                   # about B3Yaw's local up, from its modelled rest (aiming roughly south)
var pitch := 0.0                 # elevation of the dish, up positive
var _yaw_node: Node3D
var _tilt: Node3D
var _yaw_rest := Transform3D.IDENTITY
var _tilt_rest := Transform3D.IDENTITY
var _eye: Node3D
var _ember: Node3D
var _cam: Camera3D
var _player: Node
var _prev_cam: Camera3D
var _layer: CanvasLayer
var _ov: Control
var _since := 0.0
var _signal := 0.0
var _use: Area3D
var _lights: Array = []          # [MeshInstance3D halo, StandardMaterial3D, phase]
var _t := 0.0

func setup(signal_node: Node, kit: Node3D) -> void:
	sig = signal_node
	_yaw_node = kit.find_child("B3Yaw", true, false) as Node3D
	_tilt = kit.find_child("B3Tilt", true, false) as Node3D
	_eye = kit.find_child("B3Eye", true, false) as Node3D
	_ember = kit.find_child("B3Ember", true, false) as Node3D
	if _yaw_node == null or _tilt == null or _eye == null or _ember == null:
		push_warning("band3_bearing: kit parts missing")
		set_process(false)
		return
	_yaw_rest = _yaw_node.transform
	_tilt_rest = _tilt.transform
	_build_ember()
	_cam = Camera3D.new()
	_cam.name = "SightCam"
	_cam.fov = FOV_WIDE
	_cam.far = 3000.0
	_cam.near = 0.2
	_tilt.add_child(_cam)
	# the sight's optics cut through the haze: its own environment, the scene's with a fraction of the fog
	var env := get_viewport().find_world_3d().environment
	if env:
		var e2 := env.duplicate() as Environment
		e2.fog_density *= 0.18
		e2.volumetric_fog_density *= 0.15
		_cam.environment = e2
	_cam.position = Vector3(0, 0, 1.25)           # just past the feed horn
	_cam.rotation = Vector3(0, PI, 0)             # the dish looks along its local +Z
	sig.connect("tuned", func(st: int) -> void:
		if st == 3 and not solved:
			_set_solved())
	if sig.call("is_tuned", 3):
		_set_solved()
		return
	_use = MastUse.make(_eye, "Use", Vector3(0.4, 0.4, 0.4), Vector3(0.1, 0, 0),
		func() -> String: return "" if solved else "Look through the sight",
		func(by: Node) -> void: enter(by))

## Ember: a big faint glow and a scatter of small warm lamps, past the fog (only a far camera sees them).
func _build_ember() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	_lights.append(_ember_light(Vector3.ZERO, 70.0, Color(0.95, 0.42, 0.12), 0.35, 0.0))
	for i in 9:
		var off := Vector3(rng.randf_range(-12, 12), rng.randf_range(-4, 5), rng.randf_range(-12, 12))
		_lights.append(_ember_light(off, rng.randf_range(9.0, 15.0), Color(1.0, rng.randf_range(0.45, 0.65), 0.15), 0.95, rng.randf() * TAU))

func _ember_light(off: Vector3, size: float, c: Color, alpha: float, phase: float) -> Array:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.15, Color(1, 1, 1, 0.8))
	g.add_point(0.45, Color(1, 1, 1, 0.2))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_MIX      # mixed, not added: added warmth vanishes on the pale haze
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.disable_fog = true
	m.render_priority = 20       # after the cloud sea's big transparent planes, which sort nearer and would cover them
	m.albedo_texture = tex
	m.albedo_color = Color(c.r, c.g, c.b, alpha)
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	var mi := MeshInstance3D.new()
	mi.mesh = q
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.layers = 2
	_ember.add_child(mi)
	mi.position = off
	return [mi, m, phase, alpha]

## Where the dish looks (world), and how far off Ember that is.
func aim_dir() -> Vector3:
	return (_tilt.global_basis * Vector3(0, 0, 1)).normalized()

func off_angle() -> float:
	return aim_dir().angle_to((_ember.global_position - _cam.global_position).normalized())

func _apply_aim() -> void:
	_yaw_node.transform = _yaw_rest * Transform3D(Basis(Vector3.UP, yaw), Vector3.ZERO)
	_tilt.transform = _tilt_rest * Transform3D(Basis(Vector3.RIGHT, -pitch), Vector3.ZERO)

func enter(by: Node) -> void:
	if scoped or solved:
		return
	_player = by
	scoped = true
	_since = 0.0
	by.set("input_enabled", false)
	by.set("velocity", Vector3.ZERO)
	var hud := by.get_node_or_null("HUD")
	if hud:
		hud.set("visible", false)          # a CanvasLayer
	_prev_cam = get_viewport().get_camera_3d()
	_cam.make_current()
	_build_overlay()

func leave() -> void:
	if not scoped:
		return
	scoped = false
	if _layer:
		_layer.queue_free()
		_layer = null
	if _prev_cam and is_instance_valid(_prev_cam):
		_prev_cam.make_current()
	if _player:
		var hud := _player.get_node_or_null("HUD")
		if hud:
			hud.set("visible", true)
		var p := _player
		get_tree().create_timer(0.15).timeout.connect(func() -> void: p.set("input_enabled", true))

func _input(event: InputEvent) -> void:
	if not scoped:
		return
	var handled := true
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var k := 0.0011 * _cam.fov / FOV_WIDE * (0.35 if Input.is_action_pressed("dash") else 1.0)
		_turn(-event.relative.x * k, -event.relative.y * k)
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_cam.fov = maxf(FOV_NARROW, _cam.fov * 0.85)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_cam.fov = minf(FOV_WIDE, _cam.fov / 0.85)
		elif event.button_index == MOUSE_BUTTON_LEFT:
			_lock()
	elif _since > 0.25 and (event.is_action_pressed("interact") or event.is_action_pressed("ui_cancel")):
		leave()
	elif event.is_action_pressed("jump"):
		_lock()
	else:
		handled = false
	if handled:
		get_viewport().set_input_as_handled()

func _turn(dy: float, dp: float) -> void:
	yaw = clampf(yaw + dy, -YAW_LIMIT, YAW_LIMIT)
	pitch = clampf(pitch + dp, PITCH_MIN, PITCH_MAX)
	_apply_aim()

func _process(delta: float) -> void:
	_t += delta
	# Ember shows through the sight until it's found; after that it stays lit on the horizon (the summit glide aims at it)
	_ember.visible = scoped or solved
	for l: Array in _lights:          # Ember's lamps breathe a little
		var m: StandardMaterial3D = l[1]
		m.albedo_color.a = float(l[3]) * (0.75 + 0.25 * sin(_t * 0.7 + float(l[2])))
	if not scoped:
		return
	_since += delta
	var v := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if v != Vector2.ZERO:
		var rate := deg_to_rad(16.0) * _cam.fov / FOV_WIDE * (0.3 if Input.is_action_pressed("dash") else 1.0)
		_turn(-v.x * rate * delta, -v.y * rate * delta)
	var a := off_angle()
	var target := clampf(1.0 - a / SIGNAL_ANGLE, 0.0, 1.0)
	_signal = lerpf(_signal, target * target, minf(1.0, delta * 6.0))
	if _ov:
		_ov.queue_redraw()

func _lock() -> void:
	if solved:
		return
	if off_angle() <= LOCK_ANGLE:
		_set_solved()
		sig.call("tune", 3)
		get_tree().create_timer(1.6).timeout.connect(leave)
	else:
		_toast_in_scope("NOTHING ON THIS BEARING  —  only haze")

func _toast_in_scope(text: String) -> void:
	if _layer == null:
		return
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", Color(1.0, 0.75, 0.5))
	l.add_theme_font_size_override("font_size", 20)
	l.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	l.position = Vector2(-160, -150)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.size = Vector2(320, 30)
	_layer.add_child(l)
	var tw := l.create_tween()
	tw.tween_interval(1.4)
	tw.tween_property(l, "modulate:a", 0.0, 0.6)
	tw.tween_callback(l.queue_free)

## The scope's face: a dark vignette, crosshair with ticks, bearing / elevation, the signal bar, the controls.
func _build_overlay() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 40
	add_child(_layer)
	var g := Gradient.new()
	g.set_color(0, Color(0, 0, 0, 0))
	g.set_color(1, Color(0, 0, 0, 1))
	g.add_point(0.62, Color(0, 0, 0, 0))
	g.add_point(0.72, Color(0.01, 0.0, 0.02, 0.95))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 512
	tex.height = 512
	var vig := TextureRect.new()
	vig.texture = tex
	vig.set_anchors_preset(Control.PRESET_FULL_RECT)
	vig.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	vig.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(vig)
	_ov = Control.new()
	_ov.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ov.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_ov)
	_ov.draw.connect(_draw_overlay)

func _draw_overlay() -> void:
	var sz := _ov.size
	var c := sz * 0.5
	var ink := Color(0.14, 0.07, 0.04, 0.9)            # dark reticle on the bright haze, with a pale edge
	var edge := Color(1.0, 0.92, 0.8, 0.5)
	var r := minf(sz.x, sz.y) * 0.34
	for pass_ in [[edge, 4.0], [ink, 1.6]]:
		_ov.draw_line(c + Vector2(-r, 0), c + Vector2(-12, 0), pass_[0], pass_[1])
		_ov.draw_line(c + Vector2(12, 0), c + Vector2(r, 0), pass_[0], pass_[1])
		_ov.draw_line(c + Vector2(0, -r), c + Vector2(0, -12), pass_[0], pass_[1])
		_ov.draw_line(c + Vector2(0, 12), c + Vector2(0, r), pass_[0], pass_[1])
	for i in range(1, 6):
		var d := r * i / 6.0
		for s in [-1, 1]:
			_ov.draw_line(c + Vector2(s * d, -5), c + Vector2(s * d, 5), ink, 1.0)
			_ov.draw_line(c + Vector2(-5, s * d), c + Vector2(5, s * d), ink, 1.0)
	_ov.draw_arc(c, 6.0, 0.0, TAU, 20, ink, 1.0)
	var f := ThemeDB.fallback_font
	var aim := aim_dir()
	var bearing := fposmod(rad_to_deg(atan2(aim.x, -aim.z)), 360.0)
	var elev := rad_to_deg(asin(clampf(aim.y, -1.0, 1.0)))
	var left := c + Vector2(-r - 10, r * 0.7)
	_ov.draw_string_outline(f, c + Vector2(-r, r + 34), "BRG %05.1f°   ELV %+05.1f°   ×%d" % [bearing, elev, int(round(FOV_WIDE / _cam.fov * 3.0))],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 18, 4, edge)
	_ov.draw_string(f, c + Vector2(-r, r + 34), "BRG %05.1f°   ELV %+05.1f°   ×%d" % [bearing, elev, int(round(FOV_WIDE / _cam.fov * 3.0))],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 18, ink)
	# the signal bar, right of the reticle
	var bx := c.x + r + 28
	var top := c.y - r * 0.6
	var h := r * 1.2
	_ov.draw_rect(Rect2(bx, top, 12, h), Color(ink, 0.4), false, 1.0)
	var jitter := 0.04 * sin(Time.get_ticks_msec() * 0.031) * _signal
	var fill := clampf(_signal + jitter, 0.0, 1.0)
	_ov.draw_rect(Rect2(bx + 2, top + h * (1.0 - fill), 8, h * fill), Color(1.0, 0.6, 0.25, 0.9))
	_ov.draw_string(f, Vector2(bx - 14, top - 10), "SIG", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, ink)
	_ov.draw_string(f, Vector2(left.x, sz.y - 40), "Mouse / WASD aim    Shift fine    Wheel zoom    Space / LMB lock    E leave",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.95, 0.85, 0.7, 0.75))      # on the dark vignette

## Locked on Ember (or tuned some other way): the dish keeps that bearing from now on.
func _set_solved() -> void:
	solved = true
	if _use:
		_use.call("set_enabled", false)
	# aim at Ember: yaw about the column, then pitch
	var to := _ember.global_position - _tilt.global_position
	var local := _yaw_node.get_parent_node_3d().global_basis.inverse() * to if _yaw_node.get_parent_node_3d() else to
	var rest_dir := _yaw_rest.basis * Vector3(0, 0, 1)
	var flat := Vector2(local.x, local.z)
	var rest_flat := Vector2(rest_dir.x, rest_dir.z)
	yaw = clampf(-wrapf(flat.angle() - rest_flat.angle(), -PI, PI), -YAW_LIMIT, YAW_LIMIT)
	pitch = clampf(atan2(local.y, flat.length()), PITCH_MIN, PITCH_MAX)
	_apply_aim()
