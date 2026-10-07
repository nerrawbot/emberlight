extends Control
## Watcher dialogue (bottom centre, above the [E] prompt). Plays a tree from scripts/dialogue/watcher_lines.gd:
## lines type out with a few glitching letters at the cursor; {braced} spans keep scrambling for good (corrupted
## memory). [E] / Space / click skips the typing, then moves on; choices are picked with 1-5, or W/S + [E].
## Esc leaves. Added to the HUD at runtime by player.gd; player.start_dialogue() opens it.

signal finished

const LINES := preload("res://scripts/dialogue/watcher_lines.gd")
const GameState := preload("res://scripts/game_state.gd")
const NOISE := "#%&@$/\\|<>?*~=+01░▒▓"
const CPS := 48.0            # characters per second
const FRESH := 2             # the newest few typed letters still flicker

var active := false
var _tree: Dictionary
var _node: Dictionary
var _lines: Array = []
var _li := 0
var _text := ""              # the current line without braces
var _bad: Array = []         # [from, to) ranges of corrupted text in _text
var _shown := 0.0
var _choices: Array = []
var _sel := 0
var _tick := 0.0
var _panel: PanelContainer
var _speaker: Label
var _body: Label
var _choice_box: VBoxContainer
var _hint: Label

func _ready() -> void:
	name = "Dialogue"
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mono := SystemFont.new()
	mono.font_names = PackedStringArray(["Consolas", "Cascadia Mono", "Lucida Console", "Courier New", "monospace"])
	_panel = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.02, 0.035, 0.06, 0.84)
	sb.border_color = Color(0.45, 0.75, 1.0, 0.55)
	sb.border_width_left = 3
	sb.set_corner_radius_all(2)
	sb.content_margin_left = 22
	sb.content_margin_right = 22
	sb.content_margin_top = 14
	sb.content_margin_bottom = 12
	_panel.add_theme_stylebox_override("panel", sb)
	_panel.anchor_left = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_top = 1.0
	_panel.anchor_bottom = 1.0
	_panel.offset_left = -440.0
	_panel.offset_right = 440.0
	_panel.offset_top = -230.0
	_panel.offset_bottom = -222.0
	_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN     # grows upwards from just above the prompt
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	_panel.add_child(v)
	_speaker = _mk_label(mono, 15, Color(0.5, 0.8, 1.0))
	v.add_child(_speaker)
	_body = _mk_label(mono, 20, Color(0.86, 0.89, 0.92))
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.custom_minimum_size = Vector2(836, 52)
	v.add_child(_body)
	_choice_box = VBoxContainer.new()
	_choice_box.add_theme_constant_override("separation", 2)
	v.add_child(_choice_box)
	_hint = _mk_label(mono, 13, Color(0.5, 0.56, 0.64))
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.add_child(_hint)

func _mk_label(font: Font, size: int, col: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0.02, 0.7))
	l.add_theme_constant_override("shadow_offset_y", 1)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

## Open tree `tree_id` (watcher_lines.gd TREES) at its "start" node; `speaker` heads the box.
func start(tree_id: String, speaker: String) -> void:
	_tree = LINES.TREES.get(tree_id, {})
	_speaker.text = speaker
	active = true
	visible = true
	_goto("start")

func stop() -> void:
	if not active:
		return
	active = false
	visible = false
	finished.emit()

func _goto(id: String) -> void:
	if id == "" or not _tree.has(id):
		stop()
		return
	_node = _tree[id]
	for b in _node.get("branch", []):
		if _passes(b):
			_goto(str(b["goto"]))
			return
	var sets: Dictionary = _node.get("set", {})
	if not sets.is_empty():
		GameState.merge(sets)
	_lines = _node.get("lines", [])
	_choices = []
	_clear_choices()
	if _lines.is_empty():
		_after_lines()
	else:
		_show_line(0)

func _passes(d: Dictionary) -> bool:
	if d.has("need") and not GameState.get_value(str(d["need"]), false):
		return false
	if d.has("need_not") and GameState.get_value(str(d["need_not"]), false):
		return false
	return true

func _show_line(i: int) -> void:
	_li = i
	var raw := str(_lines[i])
	_text = ""
	_bad = []
	var from := -1
	for ch in raw:
		if ch == "{":
			from = _text.length()
		elif ch == "}" and from >= 0:
			_bad.append(Vector2i(from, _text.length()))
			from = -1
		else:
			_text += ch
	_shown = 0.0
	_body.modulate.a = 0.55          # a stutter as the signal comes in
	create_tween().tween_property(_body, "modulate:a", 1.0, 0.25)
	_render()

func _typing() -> bool:
	return _shown < _text.length()

func _after_lines() -> void:
	for c in _node.get("choices", []):
		if _passes(c):
			_choices.append(c)
	if _choices.is_empty():
		_goto(str(_node.get("next", "")))
		return
	_sel = 0
	_draw_choices()

func _clear_choices() -> void:
	for c in _choice_box.get_children():
		c.queue_free()

func _draw_choices() -> void:
	_clear_choices()
	for i in _choices.size():
		var l := _mk_label(_body.get_theme_font("font"), 18, Color(0.95, 0.85, 0.55) if i == _sel else Color(0.66, 0.7, 0.76))
		l.text = ("> " if i == _sel else "  ") + "%d  %s" % [i + 1, str(_choices[i]["text"])]
		_choice_box.add_child(l)
	_hint.text = "[1-%d]  or  [W/S] + [E]   choose" % _choices.size()

func _pick(i: int) -> void:
	if i < 0 or i >= _choices.size():
		return
	var g := str(_choices[i]["goto"])
	_choices = []
	_clear_choices()
	_goto(g)

func _advance() -> void:
	if _typing():
		_shown = _text.length()
		_render()
	elif not _choices.is_empty():
		_pick(_sel)
	elif _li + 1 < _lines.size():
		_show_line(_li + 1)
	else:
		_after_lines()

func _input(event: InputEvent) -> void:
	if not active:
		return
	var used := true
	if event.is_action_pressed("ui_cancel"):
		stop()
	elif event.is_action_pressed("interact") or event.is_action_pressed("jump") or event.is_action_pressed("attack"):
		_advance()
	elif not _choices.is_empty() and event.is_action_pressed("move_forward"):
		_sel = (_sel - 1 + _choices.size()) % _choices.size()
		_draw_choices()
	elif not _choices.is_empty() and event.is_action_pressed("move_back"):
		_sel = (_sel + 1) % _choices.size()
		_draw_choices()
	elif event is InputEventKey and event.pressed and not event.echo and not _choices.is_empty() \
			and event.physical_keycode >= KEY_1 and event.physical_keycode <= KEY_9:
		_pick(event.physical_keycode - KEY_1)
	else:
		used = false
	if used:
		get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if not active:
		return
	if _typing():
		_shown = minf(_shown + delta * CPS, _text.length())
	_tick -= delta
	if _tick <= 0.0:           # re-roll the noise ~14 times a second, not every frame
		_tick = 1.0 / 14.0
		_render()

func _is_bad(i: int) -> bool:
	for r in _bad:
		if i >= r.x and i < r.y:
			return true
	return false

func _render() -> void:
	var n := int(_shown)
	var out := ""
	for i in n:
		var ch := _text[i]
		# corrupted spans flicker between noise and the real letters, so they stay half-readable
		if ch != " " and ((_is_bad(i) and randf() < 0.62) or (i >= n - FRESH and _typing() and randf() < 0.6)):
			out += NOISE[randi() % NOISE.length()]
		else:
			out += ch
	_body.text = out
	if _choices.is_empty():
		_hint.text = "" if _typing() else "[E]  >"