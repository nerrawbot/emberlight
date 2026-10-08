extends Node
## v19, the mast's radio cabin: the relay console and the final tuning (art_src/v19_mast_signal.py cabin_console()).
## [E] at the desk opens a close-up panel (the player frozen, the mouse free): an oscilloscope with Ember's carrier
## (amber) and the relay's own trace (teal), three knobs (FREQUENCY, PHASE, GAIN: drag up/down or use the wheel; the
## bands made them work), and the broadcast underneath, its letters scrambled until the traces agree. Held in
## agreement for a moment, it locks: mast_signal.final_tune(), the panel closes and the lamplighter in Emberlight
## speaks (watcher_lines.gd "ember_lamplighter"). The CRT in the cabin shows the same traces (a shader on B5Screen).

const MastUse := preload("res://scripts/mast/mast_use.gd")
## Ember's carrier: cycles across the screen, phase, amplitude (and a slow breath on top)
const EMBER := {"freq": 3.4, "phase": 2.2, "amp": 0.64}
const RANGES := {"freq": [1.0, 6.0], "phase": [0.0, TAU], "amp": [0.1, 1.0]}
const LOCK_Q := 0.92
const LOCK_HOLD := 1.2
const CARRIER := "...this is Emberlight, lamp station nine, calling the Heretic relay. Is anyone there? Anyone at all? This is Emberlight, calling... "
const GLYPHS := "#%&@$*+=?!~^"

var sig: Node
var knobs := {"freq": 1.8, "phase": 0.3, "amp": 0.25}
var quality := 0.0              # strict: what the lock needs
var agreement := 0.0            # forgiving: what the panel shows (the % and how much of the broadcast gets through)
var open := false
var locked := false
var _screen_mat: ShaderMaterial
var _seat: Node3D
var _use: Area3D
var _player: Node
var _layer: CanvasLayer
var _scope: Control
var _text: Label
var _q_label: Label
var _knob_ctl := {}
var _drag := ""
var _hold := 0.0
var _t := 0.0
var _scramble_t := 0.0
var _crt_light: OmniLight3D

const CRT_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled;
uniform float ef; uniform float ep; uniform float ea;
uniform float rf; uniform float rp; uniform float ra;
uniform float q; uniform float powered = 1.0; uniform float t;
float tr(float x, float f, float p, float a) { return a * sin(6.2832 * f * x + p) * 0.42; }
void fragment() {
	vec2 uv = UV;
	float x = uv.x; float y = (0.5 - uv.y);
	vec3 col = vec3(0.02, 0.05, 0.04);
	vec2 g = abs(fract(uv * vec2(10.0, 6.0)) - 0.5);
	col += vec3(0.02, 0.08, 0.06) * step(0.47, max(g.x, g.y));
	float breath = 1.0 + 0.04 * sin(t * 0.9);
	float e = tr(x, ef, ep + t * 0.4, ea * breath);
	float r = tr(x, rf, rp + t * 0.4, ra) + (1.0 - q) * 0.05 * sin(x * 173.0 + t * 37.0);
	col += vec3(1.0, 0.55, 0.15) * smoothstep(0.018, 0.0, abs(y - e)) * 1.6;
	col += vec3(0.2, 1.0, 0.85) * smoothstep(0.015, 0.0, abs(y - r)) * 1.4;
	col += vec3(0.05, 0.1, 0.08) * sin(uv.y * 400.0 + t * 8.0) * 0.3;
	ALBEDO = col * powered;
	EMISSION = col * powered * 1.4;
}
"""

func setup(signal_node: Node, kit: Node3D) -> void:
	sig = signal_node
	var scr := kit.find_child("B5Screen", true, false) as MeshInstance3D
	_seat = kit.find_child("B5Seat", true, false) as Node3D
	if scr == null or _seat == null:
		push_warning("cabin_console: kit parts missing")
		set_process(false)
		return
	var qm := QuadMesh.new()            # a clean 0..1 quad: the glb's has box-projected UVs
	qm.orientation = PlaneMesh.FACE_X
	qm.size = Vector2(1.24, 0.76)
	scr.mesh = qm
	var sh := Shader.new()
	sh.code = CRT_SHADER
	_screen_mat = ShaderMaterial.new()
	_screen_mat.shader = sh
	scr.material_override = _screen_mat
	_crt_light = OmniLight3D.new()
	_crt_light.light_color = Color(0.45, 0.9, 0.75)
	_crt_light.omni_range = 3.5
	_crt_light.light_energy = 0.7
	_crt_light.shadow_enabled = false
	scr.add_child(_crt_light)
	_crt_light.position = Vector3(0.4, 0, 0)
	if sig.call("is_final"):
		_set_locked()
	_use = MastUse.make(_seat, "Use", Vector3(1.0, 1.0, 2.6), Vector3.ZERO,
		func() -> String: return "" if locked else ("Tune the relay" if _powered() else "The relay console (dead)"),
		func(by: Node) -> void: enter(by))
	_update_screen()

func _powered() -> bool:
	return int(sig.call("progress")) >= 4

func quality_of(k: Dictionary) -> float:
	var df := (float(k["freq"]) - EMBER["freq"]) / 0.16
	var dp := 0.5 + 0.5 * cos(float(k["phase"]) - EMBER["phase"])
	var da := (float(k["amp"]) - EMBER["amp"]) / 0.12
	return exp(-df * df) * pow(dp, 6.0) * exp(-da * da)

## How close it looks: a broad score, so the text clears and the % climbs well before the lock is in reach.
func agreement_of(k: Dictionary) -> float:
	var df := (float(k["freq"]) - EMBER["freq"]) / 0.9
	var dp := 0.5 + 0.5 * cos(float(k["phase"]) - EMBER["phase"])
	var da := (float(k["amp"]) - EMBER["amp"]) / 0.4
	return exp(-df * df) * pow(dp, 1.5) * exp(-da * da)

func _process(delta: float) -> void:
	_t += delta
	quality = 1.0 if locked else quality_of(knobs)
	agreement = 1.0 if locked else agreement_of(knobs)
	_update_screen()
	if not open:
		return
	if not locked:
		_hold = _hold + delta if quality >= LOCK_Q else 0.0
		if _hold >= LOCK_HOLD:
			_lock()
	_scramble_t -= delta
	if _scramble_t <= 0.0:
		_scramble_t = 0.09
		_text.text = _scrambled(CARRIER, agreement)
	_q_label.text = "SIGNAL LOCKED" if locked else ("AGREEMENT %3d%%" % int(round(agreement * 100.0)))
	_scope.queue_redraw()
	for k in _knob_ctl:
		(_knob_ctl[k] as Control).queue_redraw()

func _update_screen() -> void:
	if _screen_mat == null:
		return
	var on := 1.0 if _powered() else 0.0
	_screen_mat.set_shader_parameter("powered", on)
	_crt_light.light_energy = 0.7 * on
	_screen_mat.set_shader_parameter("ef", EMBER["freq"])
	_screen_mat.set_shader_parameter("ep", EMBER["phase"])
	_screen_mat.set_shader_parameter("ea", EMBER["amp"])
	var k: Dictionary = EMBER if locked else knobs
	_screen_mat.set_shader_parameter("rf", k["freq"])
	_screen_mat.set_shader_parameter("rp", k["phase"])
	_screen_mat.set_shader_parameter("ra", k["amp"])
	_screen_mat.set_shader_parameter("q", agreement)
	_screen_mat.set_shader_parameter("t", _t)

## Each letter survives with the agreement's odds; the rest flicker as noise. (Spaces stay, so it reads as words.)
func _scrambled(s: String, q: float) -> String:
	var out := ""
	var keep := pow(q, 0.8)
	for i in s.length():
		var ch := s[i]
		if ch == " " or randf() < keep:
			out += ch
		else:
			out += GLYPHS[randi() % GLYPHS.length()]
	return out

func enter(by: Node) -> void:
	if open or locked:
		return
	if not _powered():
		if by.has_method("show_toast"):
			by.call("show_toast", "The screen stays dark. The bands below aren't all in tune.", 3.0)
		return
	_player = by
	open = true
	_hold = 0.0
	by.set("input_enabled", false)
	by.set("velocity", Vector3.ZERO)
	var hud := by.get_node_or_null("HUD")
	if hud:
		hud.set("visible", false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_build_ui()

func leave() -> void:
	if not open:
		return
	open = false
	_drag = ""
	if _layer:
		_layer.queue_free()
		_layer = null
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if _player:
		var hud := _player.get_node_or_null("HUD")
		if hud:
			hud.set("visible", true)
		var p := _player
		get_tree().create_timer(0.15).timeout.connect(func() -> void: p.set("input_enabled", true))

func _input(event: InputEvent) -> void:
	if not open:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("interact"):
		leave()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_drag = ""
	elif event is InputEventMouseMotion and _drag != "":
		var fine := 0.25 if Input.is_key_pressed(KEY_SHIFT) else 1.0
		set_knob(_drag, float(knobs[_drag]) - event.relative.y * _knob_rate(_drag) * fine)
		get_viewport().set_input_as_handled()

func _knob_rate(k: String) -> float:
	var r: Array = RANGES[k]
	return (float(r[1]) - float(r[0])) / 400.0          # 400 px of drag = the whole range

func set_knob(k: String, v: float) -> void:
	if locked:
		return
	var r: Array = RANGES[k]
	if k == "phase":
		knobs[k] = fposmod(v, TAU)
	else:
		knobs[k] = clampf(v, float(r[0]), float(r[1]))

func _lock() -> void:
	locked = true
	knobs = EMBER.duplicate()
	sig.call("final_tune")
	get_tree().create_timer(2.2).timeout.connect(func() -> void:
		leave()
		var p := _player
		if p and p.has_method("start_dialogue"):
			get_tree().create_timer(0.4).timeout.connect(func() -> void:
				p.call("start_dialogue", "ember_lamplighter", "EMBERLIGHT  —  the lamplighter", null)))

func _set_locked() -> void:
	locked = true
	knobs = EMBER.duplicate()
	quality = 1.0
	if _use:
		_use.call("set_enabled", false)

# ------------------------------------------------------------------------------------------------ the close-up panel
func _build_ui() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 45
	add_child(_layer)
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.025, 0.05, 0.94)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_layer.add_child(bg)
	var title := Label.new()
	title.text = "HERETIC RELAY  —  FINAL TUNING"
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(0.95, 0.75, 0.45))
	title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title.position = Vector2(-260, 30)
	title.size = Vector2(520, 40)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_layer.add_child(title)
	_scope = Control.new()
	_scope.set_anchors_preset(Control.PRESET_CENTER)
	_scope.custom_minimum_size = Vector2(760, 330)
	_scope.size = Vector2(760, 330)
	_scope.position = Vector2(-380, -260)
	_layer.add_child(_scope)
	_scope.draw.connect(_draw_scope)
	var names := {"freq": "FREQUENCY", "phase": "PHASE", "amp": "GAIN"}
	var i := 0
	for k in ["freq", "phase", "amp"]:
		var c := Control.new()
		c.set_anchors_preset(Control.PRESET_CENTER)
		c.size = Vector2(150, 170)
		c.position = Vector2(-290 + i * 220, 90)
		c.mouse_filter = Control.MOUSE_FILTER_STOP
		_layer.add_child(c)
		var key: String = k
		var nm: String = names[k]
		c.draw.connect(func() -> void: _draw_knob(c, key, nm))
		c.gui_input.connect(func(ev: InputEvent) -> void: _knob_input(key, ev))
		_knob_ctl[k] = c
		i += 1
	_q_label = Label.new()
	_q_label.add_theme_font_size_override("font_size", 18)
	_q_label.add_theme_color_override("font_color", Color(0.45, 0.95, 0.8))
	_q_label.set_anchors_preset(Control.PRESET_CENTER)
	_q_label.position = Vector2(220, -300)
	_q_label.size = Vector2(160, 30)
	_q_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_layer.add_child(_q_label)
	_text = Label.new()
	_text.add_theme_font_size_override("font_size", 19)
	_text.add_theme_color_override("font_color", Color(1.0, 0.72, 0.4))
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD
	_text.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_text.position = Vector2(-380, -150)
	_text.size = Vector2(760, 70)
	_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_layer.add_child(_text)
	var help := Label.new()
	help.text = "Drag a knob up / down (Shift: fine) or scroll over it.  Make the relay's trace sit on Ember's.    [Esc / E]  step back"
	help.add_theme_font_size_override("font_size", 14)
	help.add_theme_color_override("font_color", Color(0.7, 0.65, 0.75, 0.8))
	help.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	help.position = Vector2(-450, -50)
	help.size = Vector2(900, 24)
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_layer.add_child(help)

func _knob_input(k: String, ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed:
		if ev.button_index == MOUSE_BUTTON_LEFT:
			_drag = k
		elif ev.button_index == MOUSE_BUTTON_WHEEL_UP:
			set_knob(k, float(knobs[k]) + _knob_rate(k) * (4.0 if not Input.is_key_pressed(KEY_SHIFT) else 1.0))
		elif ev.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			set_knob(k, float(knobs[k]) - _knob_rate(k) * (4.0 if not Input.is_key_pressed(KEY_SHIFT) else 1.0))

func _trace_y(x: float, f: float, p: float, a: float, h: float) -> float:
	return h * 0.5 - a * sin(TAU * f * x + p + _t * 0.4) * h * 0.42

func _draw_scope() -> void:
	var s := _scope.size
	_scope.draw_rect(Rect2(Vector2.ZERO, s), Color(0.02, 0.06, 0.05))
	for gx in range(1, 10):
		_scope.draw_line(Vector2(s.x * gx / 10.0, 0), Vector2(s.x * gx / 10.0, s.y), Color(0.1, 0.25, 0.2, 0.6), 1.0)
	for gy in range(1, 6):
		_scope.draw_line(Vector2(0, s.y * gy / 6.0), Vector2(s.x, s.y * gy / 6.0), Color(0.1, 0.25, 0.2, 0.6), 1.0)
	_scope.draw_rect(Rect2(Vector2.ZERO, s), Color(0.3, 0.6, 0.5, 0.8), false, 2.0)
	var n := 220
	var ep := PackedVector2Array()
	var rp := PackedVector2Array()
	var breath := 1.0 + 0.04 * sin(_t * 0.9)
	var k: Dictionary = EMBER if locked else knobs
	var noise := (1.0 - agreement) * 0.05
	for i in n + 1:
		var x := float(i) / n
		ep.append(Vector2(x * s.x, _trace_y(x, EMBER["freq"], EMBER["phase"], EMBER["amp"] * breath, s.y)))
		var y := _trace_y(x, k["freq"], k["phase"], k["amp"], s.y) + noise * s.y * sin(x * 173.0 + _t * 37.0)
		rp.append(Vector2(x * s.x, y))
	_scope.draw_polyline(ep, Color(1.0, 0.58, 0.18, 0.95), 3.0, true)
	_scope.draw_polyline(rp, Color(0.3, 1.0, 0.85, 0.9), 2.0, true)
	var f := ThemeDB.fallback_font
	_scope.draw_string(f, Vector2(12, 24), "EMBER", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1.0, 0.6, 0.2))
	_scope.draw_string(f, Vector2(80, 24), "RELAY", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.3, 1.0, 0.85))

func _draw_knob(c: Control, k: String, nm: String) -> void:
	var ctr := Vector2(c.size.x * 0.5, 70)
	var r: Array = RANGES[k]
	var t := (float(knobs[k]) - float(r[0])) / (float(r[1]) - float(r[0]))
	c.draw_circle(ctr, 52, Color(0.12, 0.1, 0.14))
	c.draw_arc(ctr, 56, deg_to_rad(135), deg_to_rad(405), 40, Color(0.5, 0.45, 0.4, 0.7), 2.0)
	var col: Color = {"freq": Color(0.3, 1.0, 0.85), "phase": Color(1.0, 0.7, 0.2), "amp": Color(1.0, 0.35, 0.25)}[k]
	c.draw_circle(ctr, 40, col.darkened(0.6))
	var a := deg_to_rad(135.0 + 270.0 * t)
	c.draw_line(ctr, ctr + Vector2(cos(a), sin(a)) * 46, col, 4.0)
	c.draw_circle(ctr, 8, Color(0.05, 0.05, 0.06))
	var f := ThemeDB.fallback_font
	c.draw_string(f, Vector2(0, 150), nm, HORIZONTAL_ALIGNMENT_CENTER, c.size.x, 17, Color(0.9, 0.85, 0.8))
