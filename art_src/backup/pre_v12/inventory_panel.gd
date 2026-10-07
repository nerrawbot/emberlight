extends Control
## [I] inventory (v12 layout). Added to the HUD at runtime by player.gd (_add_hud_extras()). Opening it pauses the
## game (the tree is paused; this panel runs with PROCESS_MODE_ALWAYS) and frees the mouse; I or Esc closes it.
##   header      title + tokens
##   left        EQUIPMENT: the weapon, the companion (cards)
##   middle      slot grids: KEY ITEMS, VALUABLES, MATERIALS (scripts/items.gd sections)
##   right       detail pane for the selected slot: big icon, name, kind, count / sell value, description
## Icons are placeholder tiles (the item's colour + a two-letter mark) until assets/icons/<id>.png exists.
## Select with the mouse (hover / click) or the arrow keys / WASD.

const Items := preload("res://scripts/items.gd")
const TITLE_FONT := preload("res://assets/fonts/Cinzel-Variable.ttf")

const PANEL_SIZE := Vector2(1120, 660)
const ACCENT := Color(0.5, 0.62, 0.78)
const DIM_TEXT := Color(0.56, 0.59, 0.65)
const GRID_COLS := 5

var player: Node
var _was_paused := false
var _title_font: FontVariation
var _body_font: FontVariation
var _tokens_label: Label
var _tokens_icon: IconTile
var _equip_box: VBoxContainer
var _grid_box: VBoxContainer
var _detail_icon: IconTile
var _detail_name: Label
var _detail_kind: Label
var _detail_count: Label
var _detail_desc: Label
var _slots: Array[Slot] = []
var _sel_key := ""

# ---------------------------------------------------------------- the icon tile (placeholder art)
class IconTile extends Control:
	var col := Color(0.8, 0.8, 0.8)
	var mark := "?"
	var tex: Texture2D
	var count := 0
	var dim := false
	var font: Font

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func setup(c: Color, m: String, t: Texture2D, n: int, faded := false) -> void:
		col = c
		mark = m
		tex = t
		count = n
		dim = faded
		queue_redraw()

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		var a := 0.45 if dim else 1.0
		var bg := StyleBoxFlat.new()
		bg.bg_color = Color(col.darkened(0.82), 0.95 * a)
		bg.border_color = Color(col.darkened(0.25), 0.9 * a)
		bg.set_border_width_all(2)
		bg.set_corner_radius_all(int(size.x * 0.08))
		draw_style_box(bg, r)
		if tex:
			draw_texture_rect(tex, r.grow(-size.x * 0.12), false, Color(1, 1, 1, a))
		else:
			# placeholder: a faint diamond and the item's two-letter mark
			var c := size * 0.5
			var d := size.x * 0.3
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -d), c + Vector2(d, 0), c + Vector2(0, d), c + Vector2(-d, 0)]),
				Color(col, 0.16 * a))
			var f := font if font else ThemeDB.fallback_font
			var fs := int(size.y * 0.3)
			var w := f.get_string_size(mark, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			draw_string(f, Vector2(c.x - w * 0.5, c.y + fs * 0.36), mark, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(col, a))
		if count > 1:
			var f2 := ThemeDB.fallback_font
			var s := str(count)
			var fs2 := maxi(14, int(size.y * 0.2))
			var w2 := f2.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2).x
			var br := Rect2(size.x - w2 - 12, size.y - fs2 - 8, w2 + 9, fs2 + 5)
			draw_rect(br, Color(0.02, 0.025, 0.04, 0.88))
			draw_string(f2, Vector2(br.position.x + 4.5, br.position.y + fs2 - 1), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2,
				Color(0.95, 0.95, 0.92))

# ---------------------------------------------------------------- a selectable slot (grid tile or equipment card)
class Slot extends PanelContainer:
	signal picked(slot: Slot)
	var key := ""
	var info := {}
	var selected := false
	var _hover := false

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_entered.connect(func():
			_hover = true
			picked.emit(self))
		mouse_exited.connect(func():
			_hover = false
			_restyle())

	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed:
			picked.emit(self)

	func set_selected(on: bool) -> void:
		selected = on
		_restyle()

	func _restyle() -> void:
		var sb := StyleBoxFlat.new()
		var c: Color = info.get("color", Color(0.7, 0.75, 0.8))
		sb.bg_color = Color(c.darkened(0.7), 0.55) if selected else (Color(1, 1, 1, 0.045) if _hover else Color(0, 0, 0, 0.0))
		sb.border_color = Color(c, 0.85) if selected else Color(1, 1, 1, 0.08)
		sb.set_border_width_all(2 if selected else 1)
		sb.set_corner_radius_all(5)
		sb.set_content_margin_all(6)
		add_theme_stylebox_override("panel", sb)

# ---------------------------------------------------------------- layout
func _ready() -> void:
	name = "Inventory"
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ts := TextServerManager.get_primary_interface()
	_title_font = FontVariation.new()
	_title_font.base_font = TITLE_FONT
	_title_font.variation_opentype = {ts.name_to_tag("wght"): 700}
	_title_font.spacing_glyph = 3
	_body_font = FontVariation.new()
	_body_font.base_font = TITLE_FONT
	_body_font.variation_opentype = {ts.name_to_tag("wght"): 600}
	_body_font.spacing_glyph = 1

	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.02, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.038, 0.062, 0.96)
	sb.border_color = Color(ACCENT, 0.5)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	sb.set_content_margin_all(28)
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = 18
	panel.add_theme_stylebox_override("panel", sb)
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -PANEL_SIZE.x * 0.5
	panel.offset_right = PANEL_SIZE.x * 0.5
	panel.offset_top = -PANEL_SIZE.y * 0.5
	panel.offset_bottom = PANEL_SIZE.y * 0.5
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(panel)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 14)
	panel.add_child(root)

	# header: title + tokens
	var head := HBoxContainer.new()
	root.add_child(head)
	var title := _label("INVENTORY", 32, Color(0.92, 0.91, 0.88))
	title.add_theme_font_override("font", _title_font)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	_tokens_icon = IconTile.new()
	_tokens_icon.custom_minimum_size = Vector2(38, 38)
	head.add_child(_tokens_icon)
	_tokens_label = _label("0", 28, Items.color("tokens"))
	_tokens_label.add_theme_font_override("font", _body_font)
	head.add_child(_tokens_label)
	var tl := _label("TOKENS", 15, DIM_TEXT)
	tl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(tl)
	root.add_child(_rule(false))

	# body: equipment | grids | detail
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 22)
	root.add_child(body)
	_equip_box = VBoxContainer.new()
	_equip_box.custom_minimum_size.x = 270
	_equip_box.add_theme_constant_override("separation", 8)
	body.add_child(_equip_box)
	body.add_child(_rule(true))
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	_grid_box = VBoxContainer.new()
	_grid_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid_box.add_theme_constant_override("separation", 8)
	scroll.add_child(_grid_box)
	body.add_child(_rule(true))
	var det := VBoxContainer.new()
	det.custom_minimum_size.x = 290
	det.add_theme_constant_override("separation", 8)
	body.add_child(det)
	_detail_icon = IconTile.new()
	_detail_icon.custom_minimum_size = Vector2(128, 128)
	_detail_icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_detail_icon.font = _body_font
	det.add_child(_detail_icon)
	_detail_name = _label("", 24, Color(0.92, 0.91, 0.88))
	_detail_name.add_theme_font_override("font", _body_font)
	_detail_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	det.add_child(_detail_name)
	_detail_kind = _label("", 14, ACCENT)
	det.add_child(_detail_kind)
	_detail_count = _label("", 17, Color(0.82, 0.84, 0.86))
	det.add_child(_detail_count)
	_detail_desc = _label("", 17, Color(0.7, 0.72, 0.76))
	_detail_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_desc.custom_minimum_size.x = 290
	det.add_child(_detail_desc)

	root.add_child(_rule(false))
	var foot := HBoxContainer.new()
	root.add_child(foot)
	var hint := _label("Mouse / arrows  select        [I] / Esc  close", 15, DIM_TEXT)
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(hint)
	var paused := _label("PAUSED", 15, Color(ACCENT, 0.9))
	paused.add_theme_font_override("font", _title_font)
	foot.add_child(paused)

# ---------------------------------------------------------------- open / close (pauses the game)
func toggle() -> void:
	if visible:
		close()
	else:
		open()

func open() -> void:
	if visible:
		return
	visible = true
	_was_paused = get_tree().paused
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	refresh()

func close() -> void:
	if not visible:
		return
	visible = false
	get_tree().paused = _was_paused
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("toggle_inventory") or event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_left") or event.is_action_pressed("ui_up") or event.is_action_pressed("move_left") \
			or event.is_action_pressed("move_forward"):
		_step(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_right") or event.is_action_pressed("ui_down") or event.is_action_pressed("move_right") \
			or event.is_action_pressed("move_back"):
		_step(1)
		get_viewport().set_input_as_handled()

# ---------------------------------------------------------------- contents
func refresh() -> void:
	_slots.clear()
	for box in [_equip_box, _grid_box]:
		for c in box.get_children():
			box.remove_child(c)
			c.queue_free()
	_tokens_label.text = str(_count("tokens"))
	_tokens_icon.setup(Items.color("tokens"), Items.abbr("tokens"), Items.icon_texture("tokens"), 0)

	# equipment column
	_equip_box.add_child(_heading("WEAPON"))
	if player and player.get("has_weapon"):
		_equip_box.add_child(_card("weapon", {"name": "Steel shaft", "color": Color(0.84, 0.87, 0.9), "abbr": "Sh",
			"kind": "WEAPON  -  EQUIPPED", "count": "[LMB / Q]  swing", "desc": "A length of drive shaft with a bolted coupling head. Heavy at one end."}))
	else:
		_equip_box.add_child(_empty_note("Empty hands."))
	_equip_box.add_child(_gap(8))
	_equip_box.add_child(_heading("COMPANION"))
	if player and player.get("has_drone"):
		_equip_box.add_child(_card("drone", {"name": "Warden drone", "color": Color(0.6, 0.86, 1.0), "abbr": "Dr",
			"kind": "COMPANION", "count": "Shield %d" % int(player.get("shield_max")),
			"desc": "Orbits close. Soaks a hit with its shield, then needs a few seconds to recharge."}))
	else:
		_equip_box.add_child(_empty_note("None."))

	# grids
	for sec in [["KEY ITEMS", Items.KEY_ITEMS], ["VALUABLES", Items.VALUABLES], ["MATERIALS", Items.MATERIALS]]:
		_grid_box.add_child(_heading(sec[0]))
		var held := (sec[1] as Array).filter(func(id): return _count(id) > 0)
		if held.is_empty():
			_grid_box.add_child(_empty_note("Nothing yet."))
		else:
			var g := GridContainer.new()
			g.columns = GRID_COLS
			g.add_theme_constant_override("h_separation", 8)
			g.add_theme_constant_override("v_separation", 8)
			for id in held:
				g.add_child(_tile(id))
			_grid_box.add_child(g)
		_grid_box.add_child(_gap(6))

	var keep := _slots.filter(func(s): return s.key == _sel_key)
	_select(keep[0] if not keep.is_empty() else (_slots[0] if not _slots.is_empty() else null))

func _tile(id: String) -> Slot:
	var n := _count(id)
	var info := {"id": id, "name": Items.label(id, n), "color": Items.color(id), "abbr": Items.abbr(id), "n": n}
	var s := Slot.new()
	s.key = "item:" + id
	s.info = info
	s.custom_minimum_size = Vector2(96, 0)
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 4)
	s.add_child(v)
	var ic := IconTile.new()
	ic.custom_minimum_size = Vector2(80, 80)
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ic.font = _body_font
	ic.setup(info["color"], info["abbr"], Items.icon_texture(id), n)
	v.add_child(ic)
	var cap := _label(info["name"], 13, Color(0.8, 0.82, 0.85))
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cap.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cap.custom_minimum_size.x = 84
	v.add_child(cap)
	_add_slot(s)
	return s

func _card(key: String, info: Dictionary) -> Slot:
	var s := Slot.new()
	s.key = key
	s.info = info
	var h := HBoxContainer.new()
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_theme_constant_override("separation", 12)
	s.add_child(h)
	var ic := IconTile.new()
	ic.custom_minimum_size = Vector2(64, 64)
	ic.font = _body_font
	ic.setup(info["color"], info["abbr"], null, 0)
	h.add_child(ic)
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(v)
	v.add_child(_label(info["name"], 19, info["color"]))
	v.add_child(_label(info["count"], 14, DIM_TEXT))
	_add_slot(s)
	return s

func _add_slot(s: Slot) -> void:
	s.picked.connect(_select)
	s.set_selected(false)
	_slots.append(s)

func _select(s: Slot) -> void:
	for o in _slots:
		o.set_selected(o == s)
	if s == null:
		_sel_key = ""
		_detail_icon.setup(Color(0.4, 0.42, 0.46), "", null, 0, true)
		_detail_name.text = "Empty"
		_detail_kind.text = ""
		_detail_count.text = ""
		_detail_desc.text = "Things you find, take from crates or pry off the dead will show up here."
		return
	_sel_key = s.key
	var info := s.info
	var id: String = info.get("id", "")
	_detail_name.text = str(info["name"])
	_detail_name.add_theme_color_override("font_color", info["color"])
	if id == "":
		_detail_icon.setup(info["color"], info["abbr"], null, 0)
		_detail_kind.text = str(info["kind"])
		_detail_count.text = str(info["count"])
		_detail_desc.text = str(info["desc"])
		return
	var n: int = info["n"]
	_detail_icon.setup(info["color"], info["abbr"], Items.icon_texture(id), 0)
	var k := Items.kind(id)
	var it: Dictionary = Items.INFO.get(id, {})
	match k:
		"key":
			_detail_kind.text = "KEY ITEM"
		"valuable":
			_detail_kind.text = "VALUABLE  -  sells for %d tokens" % int(it.get("value", 0))
		_:
			_detail_kind.text = "MATERIAL"
	_detail_count.text = "Held: %d" % n
	_detail_desc.text = str(it.get("desc", ""))

func _step(d: int) -> void:
	if _slots.is_empty():
		return
	var i := 0
	for k in _slots.size():
		if _slots[k].key == _sel_key:
			i = k
	_select(_slots[wrapi(i + d, 0, _slots.size())])

# ---------------------------------------------------------------- small widgets
func _count(id: String) -> int:
	if player and player.has_method("item_count"):
		return int(player.call("item_count", id))
	return 0

func _label(t: String, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _heading(t: String) -> Label:
	var l := _label(t, 14, ACCENT)
	l.add_theme_font_override("font", _title_font)
	return l

func _empty_note(t: String) -> Label:
	return _label(t, 15, Color(0.45, 0.47, 0.52))

func _gap(h: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size.y = h
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c

func _rule(vertical: bool) -> ColorRect:
	var r := ColorRect.new()
	r.color = Color(ACCENT, 0.22)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if vertical:
		r.custom_minimum_size.x = 1
	else:
		r.custom_minimum_size.y = 1
	return r