extends Control
## HUD map. A round minimap in the top-right corner turns with the player (heading always up); M opens a large
## north-up map of the whole scene. Both draw the scene's baked floor plan (assets/map/<scene>.res, made by
## tools/bake_map.gd) with scripts/minimap.gdshader: the floor you're on and those below it, darker with depth,
## with hatching under decks overhead. Markers: exits/scene links (amber, pinned to the rim when out of range,
## with a small arrow when well above or below you) and enemies (red). player.gd adds this to its HUD.

const MapInfo := preload("res://scripts/map_info.gd")
const SHADER := preload("res://scripts/minimap.gdshader")
const TITLE_FONT := preload("res://assets/fonts/Cinzel-Variable.ttf")      # as the area banners (player.gd)
const MINI_SIZE := 230.0
const MINI_MARGIN := 26.0
const MINI_RADIUS_M := 28.0       # metres from the player to the rim
const BIG_FILL := 0.84            # share of the screen the M map may use
const BIG_MAX_SCALE := 16.0       # px per metre (small scenes stop there instead of filling the screen)
const REF_MARGIN := 1.1           # floors up to this far above the feet count as "this floor" (stairs ahead)
const LEVEL_DIFF := 3.0           # markers this far above/below get an up/down arrow
const COL_RIM := Color(0.62, 0.7, 1.0, 0.55)
const COL_EXIT := Color(1.0, 0.74, 0.32)
const COL_ENEMY := Color(1.0, 0.3, 0.28)
const COL_PLAYER := Color(1.0, 0.97, 0.9)
const COL_SHADOW := Color(0.0, 0.0, 0.04, 0.85)
const COL_TEXT := Color(0.8, 0.85, 1.0, 0.9)

var player: CharacterBody3D
var info: MapInfo
var big := false: set = set_big
var _mini: ColorRect
var _big: ColorRect
var _dim: ColorRect
var _overlay: Control
var _exits: Array[Node3D] = []
var _ref_y := 0.0
var _cam: Camera3D
var _title_font: FontVariation

func _ready() -> void:
	name = "Minimap"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var scene: Node = player.owner if player and player.owner else get_tree().current_scene
	var path := "res://assets/map/%s.res" % scene.scene_file_path.get_file().get_basename() if scene else ""
	if path == "" or not ResourceLoader.exists(path):
		visible = false
		set_process(false)
		return
	info = load(path)
	_cam = player.get_node("Head/Camera3D")
	_title_font = FontVariation.new()
	_title_font.base_font = TITLE_FONT
	_title_font.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 700}
	_ref_y = player.global_position.y

	_mini = _map_rect("Mini", true)
	_mini.anchor_left = 1.0
	_mini.anchor_right = 1.0
	_mini.offset_left = -MINI_MARGIN - MINI_SIZE
	_mini.offset_right = -MINI_MARGIN
	_mini.offset_top = MINI_MARGIN
	_mini.offset_bottom = MINI_MARGIN + MINI_SIZE
	_dim = ColorRect.new()
	_dim.name = "Dim"
	_dim.color = Color(0.0, 0.0, 0.02, 0.5)
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dim.visible = false
	add_child(_dim)
	_big = _map_rect("Big", false)
	_big.visible = false
	var m := _big.material as ShaderMaterial
	m.set_shader_parameter("center", info.origin + info.size_m() * 0.5)
	m.set_shader_parameter("half_m", info.size_m() * 0.5)
	m.set_shader_parameter("yaw", 0.0)
	_overlay = Control.new()
	_overlay.name = "Markers"
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.draw.connect(_draw_markers)
	add_child(_overlay)
	_find_exits.call_deferred(scene)

func _map_rect(n: String, round_mask: bool) -> ColorRect:
	var r := ColorRect.new()
	r.name = n
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new()
	m.shader = SHADER
	m.set_shader_parameter("heights", info.heights)
	m.set_shader_parameter("map_origin", info.origin)
	m.set_shader_parameter("map_size", info.size_m())
	m.set_shader_parameter("y_min", info.y_min)
	m.set_shader_parameter("y_span", info.y_span)
	m.set_shader_parameter("round_mask", round_mask)
	r.material = m
	add_child(r)
	return r

func _find_exits(scene: Node) -> void:
	for a in scene.find_children("*", "Area3D", true, false):
		var sc: Script = a.get_script()
		if sc and sc.resource_path == "res://scripts/exit_zone.gd":
			var cs := a.find_child("*", false, false) as Node3D     # its CollisionShape3D: the box's middle
			_exits.append(cs if cs else a)

func set_big(v: bool) -> void:
	big = v and info != null
	if _big:
		_big.visible = big
		_dim.visible = big
		_mini.visible = not big

func _unhandled_input(event: InputEvent) -> void:
	if info and event.is_action_pressed("toggle_map"):
		big = not big
		get_viewport().set_input_as_handled()

func _process(_delta: float) -> void:
	var cam_on := _cam.current
	_mini.visible = cam_on and not big
	_big.visible = cam_on and big
	_dim.visible = _big.visible
	_overlay.visible = cam_on
	if not cam_on:
		return
	var pos := player.global_position
	# the reference height follows the floor you're standing on: a jump doesn't flip the map to the deck above,
	# a fall updates it straight away
	if player.is_on_floor():
		_ref_y = pos.y
	else:
		_ref_y = minf(_ref_y, pos.y)
	var ref := _ref_y + REF_MARGIN
	if big:
		var vp := get_viewport_rect().size
		var sz := info.size_m()
		var k := minf(minf(vp.x * BIG_FILL / sz.x, vp.y * BIG_FILL / sz.y), BIG_MAX_SCALE)
		_big.size = sz * k
		_big.position = (vp - _big.size) * 0.5 + Vector2(0, 10)
		(_big.material as ShaderMaterial).set_shader_parameter("ref_y", ref)
	else:
		var m := _mini.material as ShaderMaterial
		m.set_shader_parameter("center", Vector2(pos.x, pos.z))
		m.set_shader_parameter("yaw", _yaw())
		m.set_shader_parameter("half_m", Vector2(MINI_RADIUS_M, MINI_RADIUS_M))
		m.set_shader_parameter("ref_y", ref)
	_overlay.queue_redraw()

func _yaw() -> float:
	var f := -player.global_basis.z
	return atan2(-f.x, -f.z)

## World offset (x, z) -> screen offset in metres, for a map turned by `yaw` (0 = north-up).
static func _turn(d: Vector2, yaw: float) -> Vector2:
	var c := cos(yaw)
	var s := sin(yaw)
	return Vector2(c * d.x - s * d.y, s * d.x + c * d.y)

func _enemies() -> Array[Node3D]:
	var out: Array[Node3D] = []
	for e in get_tree().get_nodes_in_group("enemies"):
		if e is Node3D and not e.is_queued_for_deletion() and not e.get("dead"):
			out.append(e)
	return out

func _draw_markers() -> void:
	var pos := player.global_position
	var font := ThemeDB.fallback_font
	if big:
		var r := _big.get_rect()
		var k := r.size.x / info.size_m().x
		var to_px := func(w: Vector3) -> Vector2: return r.position + (Vector2(w.x, w.z) - info.origin) * k
		_overlay.draw_rect(r.grow(1.0), COL_RIM, false, 1.5)
		_overlay.draw_string(_title_font, r.position + Vector2(0, -12), info.title.to_upper(), HORIZONTAL_ALIGNMENT_LEFT,
			-1, 22, COL_TEXT)
		if info.region != "":
			_overlay.draw_string(TITLE_FONT, r.position + Vector2(0, -40), info.region.to_upper(), HORIZONTAL_ALIGNMENT_LEFT,
				-1, 13, Color(COL_TEXT, 0.55))
		_overlay.draw_string(font, r.position + Vector2(0, r.size.y + 24), "M  close", HORIZONTAL_ALIGNMENT_LEFT,
			-1, 15, Color(COL_TEXT, 0.6))
		_overlay.draw_string(font, r.end + Vector2(-14, -10 - r.size.y), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, COL_TEXT)
		for e in _exits:
			_exit_mark(to_px.call(e.global_position), e.global_position.y - pos.y, 1.0)
		for e in _enemies():
			_enemy_mark(to_px.call(e.global_position))
		_arrow(to_px.call(pos), -_yaw(), 1.2)
		return

	var rect := _mini.get_rect()
	var c := rect.get_center()
	var rad := rect.size.x * 0.5
	var k := rad / MINI_RADIUS_M
	var yaw := _yaw()
	_overlay.draw_arc(c, rad, 0.0, TAU, 96, COL_RIM, 2.0, true)
	# north: a small N riding the rim
	var n_at := c + _turn(Vector2(0, -1), yaw) * (rad - 1.0)
	_overlay.draw_circle(n_at, 9.0, COL_SHADOW)
	_overlay.draw_string(font, n_at + Vector2(-5, 5), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, COL_TEXT)
	for e in _exits:
		var w := e.global_position
		var v := _turn(Vector2(w.x - pos.x, w.z - pos.z), yaw) * k
		var far := v.length() > rad - 10.0
		if far:
			v = v.normalized() * (rad - 10.0)
		_exit_mark(c + v, w.y - pos.y, 0.75 if far else 1.0)
	for e in _enemies():
		var w := e.global_position
		var v := _turn(Vector2(w.x - pos.x, w.z - pos.z), yaw) * k
		if v.length() < rad - 4.0:
			_enemy_mark(c + v)
	_arrow(c, 0.0, 1.0)

func _arrow(at: Vector2, angle: float, s: float) -> void:
	var pts := PackedVector2Array([Vector2(0, -10), Vector2(7, 7.5), Vector2(0, 3.5), Vector2(-7, 7.5)])
	var xf := Transform2D(angle, at)
	for i in pts.size():
		pts[i] = xf * (pts[i] * s)
	var ring := pts.duplicate()
	ring.append(pts[0])
	_overlay.draw_polyline(ring, COL_SHADOW, 3.0, true)
	_overlay.draw_colored_polygon(pts, COL_PLAYER)

func _exit_mark(at: Vector2, dy: float, alpha: float) -> void:
	var d := 6.0 * alpha + 1.5
	var pts := PackedVector2Array([at + Vector2(0, -d), at + Vector2(d, 0), at + Vector2(0, d), at + Vector2(-d, 0)])
	var ring := pts.duplicate()
	ring.append(pts[0])
	_overlay.draw_polyline(ring, COL_SHADOW, 3.0, true)
	_overlay.draw_colored_polygon(pts, Color(COL_EXIT, alpha))
	if absf(dy) > LEVEL_DIFF:      # well above or below you: a small arrow beside it
		var up := dy > 0.0
		var b := at + Vector2(d + 6.0, 0)
		var tri := PackedVector2Array([b + Vector2(0, -4 if up else 4), b + Vector2(4, 3 if up else -3),
			b + Vector2(-4, 3 if up else -3)])
		_overlay.draw_colored_polygon(tri, Color(COL_EXIT, alpha))

func _enemy_mark(at: Vector2) -> void:
	_overlay.draw_circle(at, 5.0, COL_SHADOW)
	_overlay.draw_circle(at, 3.5, COL_ENEMY)
