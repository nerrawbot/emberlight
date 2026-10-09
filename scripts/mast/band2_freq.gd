extends Node
## v19, mast band 2: FREQUENCY. The relay's call-sign lamp hangs off the end of the cabin's long boom, 53 m up, and
## blinks the call sign (B2Beacon; only band 2's west strip can see it past the cabin). The tuning console on that
## strip has an 8-step dial: each step makes the station lamp on its post (B2Lamp) blink a different rhythm, on the
## same clock as the beacon. Match the beacon, press the key: mast_signal.tune(2) lets the winch pay the hops out.
## A wrong match is rejected (both lamps stutter). Kit: art_src/v19_mast_signal.py band2().

const MastUse := preload("res://scripts/mast/mast_use.gd")
## dot = 1 slot lit, dash = 3, 1 dark slot between; every rhythm starts at slot 0 of the same 20-slot cycle
const PATTERNS := ["...", "-", "-.", ".-", "--", "..-", "-..", ".-."]
const TARGET := 6                       # the call sign: long, short, short
const SLOT := 0.22
const CYCLE := 20

var sig: Node
var dial := 0
var solved := false
var _knob: Node3D
var _knob_rest := Transform3D.IDENTITY
var _key: Node3D
var _key_rest := Transform3D.IDENTITY
var _lamp_mat: StandardMaterial3D
var _beacon_mat: StandardMaterial3D
var _lamp_light: OmniLight3D
var _beacon_light: OmniLight3D
var _beacon_halo: StandardMaterial3D
var _lamp_halo: StandardMaterial3D
var _slots: Array = []                  # per pattern: Array[bool] of CYCLE slots
var _stutter := 0.0                     # > 0: both lamps flicker at random (a rejected call)
var _t := 0.0
var _busy := false
var _key_use: Area3D
var _dial_use: Area3D

func setup(signal_node: Node, kit: Node3D) -> void:
	sig = signal_node
	_knob = kit.find_child("B2Dial", true, false) as Node3D
	_key = kit.find_child("B2Key", true, false) as Node3D
	var lamp := kit.find_child("B2Lamp", true, false) as MeshInstance3D
	var beacon := kit.find_child("B2Beacon", true, false) as MeshInstance3D
	if _knob == null or _key == null or lamp == null or beacon == null:
		push_warning("band2_freq: kit parts missing")
		set_process(false)
		return
	for p: String in PATTERNS:
		var s := []
		for i in CYCLE:
			s.append(false)
		var at := 0
		for ch in p:
			var n := 3 if ch == "-" else 1
			for i in n:
				s[at + i] = true
			at += n + 1
		_slots.append(s)
	_knob_rest = _knob.transform
	_key_rest = _key.transform
	_lamp_mat = _glow_mat(Color(1.0, 0.62, 0.3))
	lamp.material_override = _lamp_mat
	_beacon_mat = _glow_mat(Color(1.0, 0.2, 0.1))
	beacon.material_override = _beacon_mat
	_lamp_light = _light(lamp, Color(1.0, 0.65, 0.35), 4.0)
	_beacon_light = _light(beacon, Color(1.0, 0.2, 0.1), 9.0)
	_lamp_halo = _halo(lamp, Color(1.0, 0.6, 0.3), 0.9, false)
	_beacon_halo = _halo(beacon, Color(1.0, 0.22, 0.1), 10.0, true)
	beacon.scale = Vector3.ONE * 1.8
	sig.connect("tuned", func(st: int) -> void:
		if st == 2 and not solved:
			_set_solved())
	if sig.call("is_tuned", 2):
		_set_solved()
		return
	_dial_use = MastUse.make(_knob, "Use", Vector3(0.5, 0.5, 0.3), Vector3.ZERO,
		func() -> String: return "" if solved else "Turn the dial (step %d of 8)" % (dial + 1),
		func(_by: Node) -> void: _turn())
	_key_use = MastUse.make(_key, "Use", Vector3(0.3, 0.3, 0.3), Vector3(0, 0, -0.08),
		func() -> String: return "" if solved else "Send on this channel",
		func(_by: Node) -> void: _send())

func _glow_mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c.darkened(0.7)
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = 0.0
	return m

func _light(at: Node3D, c: Color, rng: float) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.light_color = c
	l.omni_range = rng
	l.light_energy = 0.0
	l.shadow_enabled = false
	l.light_volumetric_fog_energy = 1.5
	at.add_child(l)
	return l

## A soft billboard glow round a lamp; `through_fog` keeps the far one readable 50 m up against the bright haze
## (no fog on it, and mixed rather than added so the red shows on a pale sky).
func _halo(at: Node3D, c: Color, size: float, through_fog: bool) -> StandardMaterial3D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.12, Color(1, 1, 1, 0.9))
	g.add_point(0.4, Color(1, 1, 1, 0.3))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 64
	tex.height = 64
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_MIX if through_fog else BaseMaterial3D.BLEND_MODE_ADD    # mix reads on bright haze
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.no_depth_test = false
	m.disable_fog = through_fog
	m.albedo_texture = tex
	m.albedo_color = Color(c.r, c.g, c.b, 0.0)
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	var mi := MeshInstance3D.new()
	mi.mesh = q
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.layers = 2
	at.add_child(mi)
	return m

func _process(delta: float) -> void:
	_t += delta
	var slot := int(_t / SLOT) % CYCLE
	var b: bool = _slots[TARGET][slot]
	var l: bool = _slots[dial][slot]
	if _stutter > 0.0:
		_stutter -= delta
		b = randf() < 0.5
		l = randf() < 0.5
	_set_lamp(_beacon_mat, _beacon_light, _beacon_halo, b, 8.0, 5.0)
	_set_lamp(_lamp_mat, _lamp_light, _lamp_halo, l, 5.0, 1.6)

func _set_lamp(m: StandardMaterial3D, li: OmniLight3D, halo: StandardMaterial3D, on: bool, emit: float, energy: float) -> void:
	m.emission_energy_multiplier = emit if on else 0.15
	li.light_energy = energy if on else 0.0
	halo.albedo_color.a = 0.9 if on else 0.0

func _turn() -> void:
	if _busy or solved:
		return
	dial = (dial + 1) % PATTERNS.size()
	_busy = true
	var to := _knob_rest * Transform3D(Basis(Vector3(0, 0, 1), deg_to_rad(45.0 * dial)), Vector3.ZERO)
	var tw := create_tween()
	tw.tween_property(_knob, "transform", to, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void: _busy = false)

func _send() -> void:
	if _busy or solved:
		return
	_busy = true
	var tw := create_tween()
	tw.tween_property(_key, "transform", _key_rest.translated_local(Vector3(0, 0, 0.06)), 0.08)
	tw.tween_property(_key, "transform", _key_rest, 0.2)
	tw.tween_callback(func() -> void:
		_busy = false
		if dial == TARGET:
			_set_solved()
			sig.call("tune", 2)
		else:
			_stutter = 1.2
			var p := get_tree().get_first_node_in_group("player")
			if p and p.has_method("show_toast"):
				p.call("show_toast", "The relay rejects the channel. Both lamps stutter; somewhere above, a winch shudders.", 3.2))

## In tune: the dial stays on the call sign, so the station lamp blinks in step with the beacon from now on.
func _set_solved() -> void:
	solved = true
	dial = TARGET
	if _knob:
		_knob.transform = _knob_rest * Transform3D(Basis(Vector3(0, 0, 1), deg_to_rad(45.0 * dial)), Vector3.ZERO)
	for a in [_dial_use, _key_use]:
		if a:
			(a as Area3D).call("set_enabled", false)
