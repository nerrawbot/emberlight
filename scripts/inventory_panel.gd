extends Control
## [I] inventory (v12 layout, v16 "industrial relic" look). Added to the HUD at runtime by player.gd (_add_hud_extras()).
## Opening it pauses the game (the tree is paused; this panel runs with PROCESS_MODE_ALWAYS) and frees the mouse; I or Esc
## closes it.
##   header      title + ledger stamp + tokens
##   left        EQUIPMENT: the weapon, the companion, gear (cards)
##   middle      hex slot grids (odd rows offset): KEY ITEMS, VALUABLES, MATERIALS (scripts/items.gd sections)
##   right       detail pane for the selected slot: big hex icon in a slowly turning ring, name, kind, count, description
## Look: a riveted plate with cut corners and brushy edges, hex slots, hazard-stripe headings (drawn by scripts/ui_ink.gd).
## No rounded corners. Palette follows the scene: cool steel/lilac in the caverns, gold/rust on the surface (picked on
## open). Animation: the plate fades/scales in with a scan line, slots stagger in, the selected hex pulses with a light
## running round its rim, hover shimmers. Fonts: Cinzel for titles, Alegreya for body text (italic for descriptions).
## Icons are placeholder hexes (the item colour + a two-letter mark) until assets/icons/<id>.png exists.
## Select with the mouse (hover / click) or the arrow keys / WASD.

const Items := preload("res://scripts/items.gd")
const Ink := preload("res://scripts/ui_ink.gd")
const TITLE_FONT := preload("res://assets/fonts/Cinzel-Variable.ttf")
const BODY_FONT := preload("res://assets/fonts/Alegreya-Variable.ttf")
const ITALIC_FONT := preload("res://assets/fonts/Alegreya-Italic-Variable.ttf")

const PANEL_SIZE := Vector2(1140, 680)
const ROW_SIZE := 5
const TILE_W := 98.0

var player: Node
var P: Dictionary = Ink.CAVERN
var _built_for := {}
var _was_paused := false
var _title_font: FontVariation
var _head_font: FontVariation
var _body_font: FontVariation
var _strong_font: FontVariation
var _italic_font: FontVariation
var _dim: ColorRect
var _plate: Plate
var _tokens_label: Label
var _tokens_icon: IconTile
var _equip_box: VBoxContainer
var _grid_box: VBoxContainer
var _detail_icon: IconTile
var _detail_name: Label
var _detail_kind: Label
var _detail_count: Label
var _detail_desc: Label
var _paused_label: Label
var _slots: Array[Slot] = []
var _sel_key := ""
var _anim: Tween
var _closing := false
var _t := 0.0

# ---------------------------------------------------------------- the riveted plate behind everything
class Plate extends PanelContainer:
	var pal: Dictionary
	var reveal := 1.0          # 0..1: the scan line sweeping down on open

	func _init() -> void:
		texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		var sb := StyleBoxEmpty.new()
		sb.content_margin_left = 34
		sb.content_margin_right = 34
		sb.content_margin_top = 26
		sb.content_margin_bottom = 22
		add_theme_stylebox_override("panel", sb)

	func set_reveal(v: float) -> void:
		reveal = v
		queue_redraw()

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		var outer := Ink.rough(Ink.chamfer(r, [30.0, 12.0, 30.0, 12.0]), 18.0, 1.3, 3.0)
		var shadow := PackedVector2Array()
		for p in outer:
			shadow.append(p + Vector2(10, 14))
		draw_colored_polygon(shadow, Color(0, 0, 0, 0.45))
		Ink.painted_fill(self, outer, pal["ink2"], pal["ink"], Color(pal["metal"], 0.16))
		# a worn, lighter band down the left, like a scrubbed plate
		var band := Ink.rough(PackedVector2Array([Vector2(30, 0), Vector2(250, 0), Vector2(190, size.y), Vector2(0, size.y),
			Vector2(0, 30)]), 30.0, 6.0, 9.0)
		var buv := PackedVector2Array()
		for p in band:
			buv.append(p / 220.0)
		draw_colored_polygon(band, Color(pal["metal"], 0.06), buv, Ink.BRUSH)
		Ink.dry_outline(self, outer, Color(pal["metal"].darkened(0.2), 0.95), 2.0, 1.0)
		var inner := Ink.chamfer(r.grow(-9.0), [24.0, 8.0, 24.0, 8.0])
		Ink.dry_outline(self, Ink.rough(inner, 40.0, 0.6, 5.0), Color(pal["metal"], 0.32), 1.0, 2.0)
		# bolts at the corners and along the long edges
		for b in [Vector2(30, 19), Vector2(size.x - 22, 19), Vector2(22, size.y - 19), Vector2(size.x - 30, size.y - 19)]:
			Ink.bolt(self, b, 4.5, pal["metal"])
		var n := int(size.x / 190.0)
		for i in range(1, n):
			var x := size.x * i / n
			Ink.bolt(self, Vector2(x, 19), 3.2, pal["metal"])
			Ink.bolt(self, Vector2(x, size.y - 19), 3.2, pal["metal"])
		# hazard strip along the bottom-left and a stencilled plate number bottom-right
		Ink.hazard(self, Rect2(46, size.y - 12, 150, 5), Color(pal["hazard"], 0.75), Color(pal["ink"], 0.0), 6.0)
		draw_string(ThemeDB.fallback_font, Vector2(size.x * 0.715, size.y - 4), "FD - 07 / LEDGER", HORIZONTAL_ALIGNMENT_LEFT,
			-1, 10, Color(pal["faint"], 0.7))
		# opening scan line
		if reveal < 1.0:
			var y := size.y * reveal
			draw_rect(Rect2(10, y - 26, size.x - 20, 26), Color(pal["glow"], 0.05 * (1.0 - reveal)))
			draw_rect(Rect2(10, y - 1, size.x - 20, 2), Color(pal["glow"], 0.55 * (1.0 - reveal)))

# ---------------------------------------------------------------- hex icon (placeholder art until icons exist)
class IconTile extends Control:
	var col := Color(0.8, 0.8, 0.8)
	var mark := "?"
	var tex: Texture2D
	var count := 0
	var dim := false
	var font: Font
	var pal: Dictionary
	var sel := 0.0           # 0..1, tweened by Slot
	var hover := 0.0
	var ring := false        # the turning outer ring round the detail pane icon
	var _t := 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		set_process(false)

	func setup(c: Color, m: String, t: Texture2D, n: int, faded := false) -> void:
		col = c
		mark = m
		tex = t
		count = n
		dim = faded
		_update_process()
		queue_redraw()

	func set_sel(v: float) -> void:
		sel = v
		_update_process()
		queue_redraw()

	func set_hover(v: float) -> void:
		hover = v
		_update_process()
		queue_redraw()

	func _update_process() -> void:
		set_process(ring or sel > 0.001 or hover > 0.001)

	func _process(d: float) -> void:
		_t += d
		queue_redraw()

	func _draw() -> void:
		var a := 0.45 if dim else 1.0
		var c := size * 0.5
		var R := Ink.hex_radius(size) - (8.0 if ring else 3.0)
		var hx := Ink.hex(c, R)
		draw_colored_polygon(Ink.hex(c + Vector2(2, 3), R), Color(0, 0, 0, 0.5 * a))
		var lift := 0.08 * hover + 0.1 * sel
		Ink.painted_fill(self, hx, Color(col.darkened(0.72 - lift), 0.97 * a), Color(col.darkened(0.9 - lift), 0.97 * a),
			Color(col, 0.16 * a), 1.0 / 120.0)
		Ink.dry_outline(self, hx, Color(col.darkened(0.2), 0.9 * a), 2.0, R)
		draw_polyline(Ink.closed(Ink.hex(c, R - 5.0)), Color(col, 0.18 * a), 1.0)
		# a notch stamped in the top edge
		draw_line(c + Vector2(-R * 0.18, -R * 0.866 + 1.5), c + Vector2(R * 0.18, -R * 0.866 + 1.5), Color(col, 0.55 * a), 3.0)
		if tex:
			var s := R * 1.15
			draw_texture_rect(tex, Rect2(c - Vector2(s, s) * 0.5, Vector2(s, s)), false, Color(1, 1, 1, a))
		else:
			draw_colored_polygon(Ink.hex(c, R * 0.42, PI / 6.0), Color(col, 0.13 * a))
			var f := font if font else ThemeDB.fallback_font
			var fs := int(R * 0.62)
			var w := f.get_string_size(mark, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			draw_string(f, Vector2(c.x - w * 0.5, c.y + fs * 0.36), mark, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(col, a))
		# selection: an outer ring that breathes + a light running round the rim; hover: the light alone, fainter
		var glow: Color = pal.get("glow", Color(1, 1, 1))
		if sel > 0.001:
			var pulse := 0.65 + 0.35 * sin(_t * 3.6)
			Ink.dry_outline(self, Ink.hex(c, R + 4.0), Color(col.lerp(glow, 0.4), 0.85 * sel * pulse), 2.0, R + 1.0)
		var run := maxf(sel, hover * 0.7)
		if run > 0.001:
			_rim_light(c, R + (4.0 if sel > 0.5 else 0.0), Color(glow, run))
		if ring:
			var pts := Ink.hex(c, R + 7.0, _t * 0.12)
			for i in 6:
				var p0 := pts[i]
				var p1 := pts[(i + 1) % 6]
				draw_line(p0.lerp(p1, 0.12), p0.lerp(p1, 0.42), Color(col, 0.35 * a), 1.0)
				draw_line(p0.lerp(p1, 0.58), p0.lerp(p1, 0.88), Color(col, 0.35 * a), 1.0)
				draw_line(p0, p0 + (p0 - c).normalized() * 5.0, Color(col, 0.6 * a), 2.0)
		if count > 1:
			_count_tag(c, R)

	func _count_tag(c: Vector2, R: float) -> void:
		var f2 := font if font else ThemeDB.fallback_font
		var s2 := str(count)
		var fs2 := maxi(14, int(R * 0.36))
		var w2 := f2.get_string_size(s2, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2).x
		var bx := c.x + R * 0.38
		var by := c.y + R * 0.5
		var bw := w2 + 14.0
		var bh := fs2 + 4.0
		var tag := PackedVector2Array([Vector2(bx + 5, by), Vector2(bx + bw + 5, by), Vector2(bx + bw, by + bh), Vector2(bx, by + bh)])
		draw_colored_polygon(tag, Color(0.02, 0.02, 0.03, 0.92))
		draw_polyline(Ink.closed(tag), Color(col, 0.8), 1.0)
		draw_string(f2, Vector2(bx + 7.5, by + fs2 - 1), s2, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2, Color(0.96, 0.94, 0.9))

	func _rim_light(c: Vector2, R: float, g: Color) -> void:
		var pts := Ink.hex(c, R)
		var head := fmod(_t * 0.55, 1.0) * 6.0
		for k in 14:
			var u := fposmod(head - k * 0.06, 6.0)
			var i := int(u)
			var u2 := fposmod(u - 0.06, 6.0)
			var i2 := int(u2)
			var p0 := pts[i].lerp(pts[(i + 1) % 6], u - i)
			var p1 := pts[i2].lerp(pts[(i2 + 1) % 6], u2 - i2)
			draw_line(p1, p0, Color(g, g.a * (1.0 - k / 14.0)), 2.5)

# ---------------------------------------------------------------- a selectable slot (hex tile or equipment card)
class Slot extends PanelContainer:
	signal picked(slot: Slot)
	var key := ""
	var info := {}
	var selected := false
	var card := false
	var icon: IconTile
	var _hover := false
	var _sel_amt := 0.0
	var _tw: Tween

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		var sb := StyleBoxEmpty.new()
		sb.set_content_margin_all(6)
		sb.content_margin_left = 10
		add_theme_stylebox_override("panel", sb)
		mouse_entered.connect(func():
			_hover = true
			_animate()
			picked.emit(self))
		mouse_exited.connect(func():
			_hover = false
			_animate())

	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed:
			picked.emit(self)

	func set_selected(on: bool) -> void:
		if on == selected:
			return
		selected = on
		_animate()

	func _animate() -> void:
		if not is_inside_tree():
			_set_amt(1.0 if selected else 0.0)
			return
		if _tw:
			_tw.kill()
		_tw = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_parallel(true)
		_tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_tw.tween_method(_set_amt, _sel_amt, 1.0 if selected else 0.0, 0.18)
		if icon:
			_tw.tween_method(icon.set_hover, icon.hover, 1.0 if _hover else 0.0, 0.15)

	func _set_amt(v: float) -> void:
		_sel_amt = v
		if icon:
			icon.set_sel(v)
		queue_redraw()

	func _draw() -> void:
		if not card:
			return
		var c: Color = info.get("color", Color(0.7, 0.75, 0.8))
		var r := Rect2(Vector2.ZERO, size)
		var h := maxf(_sel_amt, 0.35 if _hover else 0.0)
		# a slanted card plate; the selected one fills in, with a bright tab down its left edge
		var pts := PackedVector2Array([Vector2(0, 0), Vector2(r.end.x - 14, 0), Vector2(r.end.x, 14), Vector2(r.end.x, r.end.y),
			Vector2(10, r.end.y), Vector2(0, r.end.y - 10)])
		draw_colored_polygon(pts, Color(c.darkened(0.75), 0.18 + 0.4 * h))
		draw_polyline(Ink.closed(pts), Color(c, 0.12 + 0.6 * _sel_amt), 1.0)
		if _sel_amt > 0.01:
			draw_rect(Rect2(0, 6, 4, (r.size.y - 16) * _sel_amt), Color(c, 0.9))

# ---------------------------------------------------------------- heading stripe and brushed rules
class Stripe extends Control:
	var pal: Dictionary

	func _init() -> void:
		custom_minimum_size = Vector2(26, 10)
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		Ink.hazard(self, Rect2(0, 1, 22, 8), Color(pal["hazard"], 0.85), Color(pal["ink"], 0.9), 5.0)

class Rule extends Control:
	var pal: Dictionary
	var vertical := false
	var seed := 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var length := size.y if vertical else size.x
		var pts := PackedVector2Array()
		var n := maxi(2, int(length / 12.0))
		for i in n + 1:
			var t := float(i) / n
			var j := (Ink.hash1(seed + i) - 0.5) * 1.2
			pts.append(Vector2(size.x * 0.5 + j, length * t) if vertical else Vector2(length * t, size.y * 0.5 + j))
		var col: Color = pal["metal"]
		draw_polyline(pts, Color(col, 0.45), 1.0)
		# dry-brush skips: a faint, broken second pass
		var off := Vector2(1.5, 0) if vertical else Vector2(0, 1.5)
		for i in n:
			if Ink.hash1(seed * 3.0 + i) > 0.55:
				draw_line(pts[i] + off, pts[i + 1] + off, Color(col, 0.18), 1.0)
		var tick := Vector2(4, 0) if vertical else Vector2(0, 4)
		for e in [pts[0], pts[pts.size() - 1]]:
			draw_line(e - tick, e + tick, Color(col, 0.6), 1.0)

# ---------------------------------------------------------------- layout
func _ready() -> void:
	name = "Inventory"
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_font = _font(TITLE_FONT, 700, 4)
	_head_font = _font(TITLE_FONT, 700, 3)
	_body_font = _font(BODY_FONT, 500, 0)
	_strong_font = _font(BODY_FONT, 700, 0)
	_italic_font = _font(ITALIC_FONT, 450, 0)
	set_process(false)

func _font(base: Font, weight: int, spacing: int) -> FontVariation:
	var ts := TextServerManager.get_primary_interface()
	var f := FontVariation.new()
	f.base_font = base
	f.variation_opentype = {ts.name_to_tag("wght"): weight}
	f.spacing_glyph = spacing
	return f

func _build() -> void:
	for c in get_children():
		remove_child(c)
		c.queue_free()
	_built_for = P
	_dim = ColorRect.new()
	_dim.color = Color(P["ink"].darkened(0.5), 0.62)
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_dim)
	_plate = Plate.new()
	_plate.pal = P
	_plate.anchor_left = 0.5
	_plate.anchor_right = 0.5
	_plate.anchor_top = 0.5
	_plate.anchor_bottom = 0.5
	_plate.offset_left = -PANEL_SIZE.x * 0.5
	_plate.offset_right = PANEL_SIZE.x * 0.5
	_plate.offset_top = -PANEL_SIZE.y * 0.5
	_plate.offset_bottom = PANEL_SIZE.y * 0.5
	_plate.pivot_offset = PANEL_SIZE * 0.5
	_plate.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_plate)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	_plate.add_child(root)

	# header: title + ledger stamp | tokens
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	root.add_child(head)
	var tbox := VBoxContainer.new()
	tbox.add_theme_constant_override("separation", -4)
	tbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(tbox)
	var title := _label("INVENTORY", 34, P["text"])
	title.add_theme_font_override("font", _title_font)
	tbox.add_child(title)
	var stamp := _label("FORSAKEN DEBRIS  -  SUPPLY LEDGER", 11, P["faint"])
	stamp.add_theme_font_override("font", _head_font)
	tbox.add_child(stamp)
	_tokens_icon = _icon(Vector2(48, 44))
	_tokens_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(_tokens_icon)
	_tokens_label = _label("0", 32, Items.color("tokens"))
	_tokens_label.add_theme_font_override("font", _strong_font)
	_tokens_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(_tokens_label)
	var tl := _label("TOKENS", 13, P["dim"])
	tl.add_theme_font_override("font", _head_font)
	tl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(tl)
	root.add_child(_rule(false, 1.0))

	# body: equipment | grids | detail
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 22)
	root.add_child(body)
	_equip_box = VBoxContainer.new()
	_equip_box.custom_minimum_size.x = 270
	_equip_box.add_theme_constant_override("separation", 8)
	body.add_child(_equip_box)
	body.add_child(_rule(true, 2.0))
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	_grid_box = VBoxContainer.new()
	_grid_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid_box.add_theme_constant_override("separation", 8)
	scroll.add_child(_grid_box)
	body.add_child(_rule(true, 3.0))
	_build_detail(body)

	root.add_child(_rule(false, 5.0))
	_build_footer(root)

func _build_detail(body: Control) -> void:
	var det := VBoxContainer.new()
	det.custom_minimum_size.x = 290
	det.add_theme_constant_override("separation", 6)
	body.add_child(det)
	_detail_icon = _icon(Vector2(170, 152))
	_detail_icon.ring = true
	_detail_icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	det.add_child(_detail_icon)
	det.add_child(_gap(4))
	_detail_name = _label("", 27, P["text"])
	_detail_name.add_theme_font_override("font", _strong_font)
	_detail_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	det.add_child(_detail_name)
	_detail_kind = _label("", 12, P["accent"])
	_detail_kind.add_theme_font_override("font", _head_font)
	det.add_child(_detail_kind)
	det.add_child(_rule(false, 4.0))
	_detail_count = _label("", 18, P["text"].darkened(0.1))
	det.add_child(_detail_count)
	_detail_desc = _label("", 19, P["dim"].lightened(0.15))
	_detail_desc.add_theme_font_override("font", _italic_font)
	_detail_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_desc.custom_minimum_size.x = 290
	det.add_child(_detail_desc)

func _build_footer(root: Control) -> void:
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 10)
	root.add_child(foot)
	for k in [["MOUSE / ARROWS", "select"], ["I / ESC", "close"]]:
		var kk := _label(k[0], 11, P["accent"])
		kk.add_theme_font_override("font", _head_font)
		kk.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		foot.add_child(kk)
		foot.add_child(_label(k[1], 16, P["dim"]))
		foot.add_child(_gap_w(14))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(spacer)
	var st := Stripe.new()
	st.pal = P
	foot.add_child(st)
	_paused_label = _label("PAUSED", 14, P["accent"])
	_paused_label.add_theme_font_override("font", _title_font)
	foot.add_child(_paused_label)

# ---------------------------------------------------------------- open / close (pauses the game)
func toggle() -> void:
	if visible and not _closing:
		close()
	else:
		open()

func _scene_path() -> String:
	var n: Node = player.get_parent() if player else get_tree().current_scene
	return n.scene_file_path if n else ""

func open() -> void:
	if visible and not _closing:
		return
	if not _closing:
		_was_paused = get_tree().paused
	_closing = false
	P = Ink.palette_for(_scene_path())
	if _built_for != P:
		_build()
	visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	refresh(true)
	set_process(true)
	if _anim:
		_anim.kill()
	_plate.modulate.a = 0.0
	_plate.scale = Vector2(0.975, 0.975)
	_dim.modulate.a = 0.0
	_plate.set_reveal(0.0)
	_anim = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_parallel(true)
	_anim.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_anim.tween_property(_dim, "modulate:a", 1.0, 0.2)
	_anim.tween_property(_plate, "modulate:a", 1.0, 0.18)
	_anim.tween_property(_plate, "scale", Vector2.ONE, 0.26)
	_anim.tween_method(_plate.set_reveal, 0.0, 1.0, 0.42).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func close() -> void:
	if not visible or _closing:
		return
	_closing = true
	get_tree().paused = _was_paused
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if _anim:
		_anim.kill()
	_anim = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_parallel(true)
	_anim.tween_property(_dim, "modulate:a", 0.0, 0.14)
	_anim.tween_property(_plate, "modulate:a", 0.0, 0.12)
	_anim.tween_property(_plate, "scale", Vector2(0.985, 0.985), 0.12)
	_anim.chain().tween_callback(_finish_close)

func _finish_close() -> void:
	if _closing:
		_closing = false
		visible = false
		set_process(false)

func _process(d: float) -> void:
	_t += d
	if _paused_label:
		_paused_label.modulate.a = 0.55 + 0.45 * (0.5 + 0.5 * sin(_t * 2.2))

func _input(event: InputEvent) -> void:
	if not visible or _closing:
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
func refresh(stagger := false) -> void:
	if _plate == null:
		return
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
	if player and player.get("has_pennon"):
		_equip_box.add_child(_gap(8))
		_equip_box.add_child(_heading("GEAR"))
		_equip_box.add_child(_card("pennon", {"name": "The Pennon", "color": Color(0.62, 0.3, 0.24), "abbr": "Pn",
			"kind": "GEAR", "count": "[Space] mid-air, from a height",
			"desc": "A wing of lashed planks. Open it falling from a height to glide; look down to dive, up to slow. [Space] again lets go."}))

	# hex grids: rows of ROW_SIZE, every other row nudged half a tile (honeycomb)
	for sec in [["KEY ITEMS", Items.KEY_ITEMS], ["VALUABLES", Items.VALUABLES], ["MATERIALS", Items.MATERIALS]]:
		_grid_box.add_child(_heading(sec[0]))
		var held := (sec[1] as Array).filter(func(id): return _count(id) > 0)
		if held.is_empty():
			_grid_box.add_child(_empty_note("Nothing yet."))
		else:
			var rows := VBoxContainer.new()
			rows.add_theme_constant_override("separation", 2)
			_grid_box.add_child(rows)
			var row: HBoxContainer
			for k in held.size():
				if k % ROW_SIZE == 0:
					row = HBoxContainer.new()
					row.add_theme_constant_override("separation", 2)
					if (k / ROW_SIZE) % 2 == 1:
						row.add_child(_gap_w(TILE_W * 0.5))
					rows.add_child(row)
				row.add_child(_tile(held[k]))
		_grid_box.add_child(_gap(6))

	var keep := _slots.filter(func(s): return s.key == _sel_key)
	_select(keep[0] if not keep.is_empty() else (_slots[0] if not _slots.is_empty() else null))
	if stagger:
		for i in _slots.size():
			var s := _slots[i]
			s.modulate.a = 0.0
			var tw := s.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
			tw.tween_interval(0.08 + i * 0.035)
			tw.tween_property(s, "modulate:a", 1.0, 0.2)

func _tile(id: String) -> Slot:
	var n := _count(id)
	var info := {"id": id, "name": Items.label(id, n), "color": Items.color(id), "abbr": Items.abbr(id), "n": n}
	var s := _new_slot("item:" + id, info)
	s.custom_minimum_size = Vector2(TILE_W, 0)
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 2)
	s.add_child(v)
	var ic := _icon(Vector2(88, 80))
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ic.setup(info["color"], info["abbr"], Items.icon_texture(id), n)
	v.add_child(ic)
	s.icon = ic
	var cap := _label(info["name"], 15, P["text"].darkened(0.12))
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cap.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cap.custom_minimum_size.x = 84
	v.add_child(cap)
	_add_slot(s)
	return s

func _card(key: String, info: Dictionary) -> Slot:
	var s := _new_slot(key, info)
	s.card = true
	var h := HBoxContainer.new()
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_theme_constant_override("separation", 12)
	s.add_child(h)
	var ic := _icon(Vector2(70, 62))
	ic.setup(info["color"], info["abbr"], null, 0)
	h.add_child(ic)
	s.icon = ic
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	v.add_theme_constant_override("separation", -2)
	h.add_child(v)
	var nm := _label(info["name"], 21, info["color"])
	nm.add_theme_font_override("font", _strong_font)
	v.add_child(nm)
	v.add_child(_label(info["count"], 15, P["dim"]))
	_add_slot(s)
	return s

func _new_slot(key: String, info: Dictionary) -> Slot:
	var s := Slot.new()
	s.key = key
	s.info = info
	return s

func _icon(sz: Vector2) -> IconTile:
	var ic := IconTile.new()
	ic.pal = P
	ic.custom_minimum_size = sz
	ic.font = _strong_font
	return ic

func _add_slot(s: Slot) -> void:
	s.picked.connect(_select)
	_slots.append(s)

func _select(s: Slot) -> void:
	for o in _slots:
		o.set_selected(o == s)
	if s == null:
		_sel_key = ""
		_detail_icon.setup(P["faint"], "", null, 0, true)
		_detail_name.text = "Empty"
		_detail_name.add_theme_color_override("font_color", P["dim"])
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
			_detail_kind.text = "VALUABLE  -  SELLS FOR %d" % int(it.get("value", 0))
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
	l.add_theme_font_override("font", _body_font)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _heading(t: String) -> Control:
	var h := HBoxContainer.new()
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_theme_constant_override("separation", 8)
	var st := Stripe.new()
	st.pal = P
	h.add_child(st)
	var l := _label(t, 13, P["accent"])
	l.add_theme_font_override("font", _head_font)
	h.add_child(l)
	var r := _rule(false, t.length())
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(r)
	return h

func _empty_note(t: String) -> Label:
	var l := _label(t, 17, P["faint"])
	l.add_theme_font_override("font", _italic_font)
	return l

func _gap(h: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size.y = h
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c

func _gap_w(w: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size.x = w
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c

func _rule(vertical: bool, seed: float) -> Rule:
	var r := Rule.new()
	r.pal = P
	r.vertical = vertical
	r.seed = seed * 13.0
	if vertical:
		r.custom_minimum_size.x = 8
	else:
		r.custom_minimum_size.y = 8
	return r
