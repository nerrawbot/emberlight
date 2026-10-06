extends Control
## Player health as a segmented semicircle at the bottom centre of the HUD.
## The arc fills left -> right over the top. Damage leaves a pale "trail" that drains after a moment;
## below `low_frac` it turns warm and pulses. At full health it fades back so it stays out of the way.

@export var radius := 92.0
@export var thickness := 9.0
@export var segments := 12
@export var gap_deg := 1.6
@export var low_frac := 0.3
@export var fill_color := Color(0.78, 0.86, 1.0, 0.95)
@export var low_color := Color(1.0, 0.45, 0.32, 0.95)
@export var track_color := Color(0.05, 0.05, 0.1, 0.55)
@export var trail_color := Color(1.0, 0.92, 0.85, 0.8)

var _frac := 1.0
var _trail := 1.0
var _trail_hold := 0.0
var _t := 0.0
var _alpha := 0.55
var _font: Font

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = get_theme_default_font()
	var p: Node = owner if owner and owner.has_signal("health_changed") else get_tree().get_first_node_in_group("player")
	if p and p.has_signal("health_changed"):
		p.health_changed.connect(_on_health)

func _on_health(value: float, max_value: float) -> void:
	var f := clampf(value / maxf(max_value, 1.0), 0.0, 1.0)
	if f < _frac - 0.001:
		_trail = maxf(_trail, _frac)
		_trail_hold = 0.6
	_frac = f
	if _trail < _frac:
		_trail = _frac
	queue_redraw()

func _process(delta: float) -> void:
	_t += delta
	_trail_hold -= delta
	if _trail_hold <= 0.0 and _trail > _frac:
		_trail = maxf(_frac, _trail - delta * 0.6)
	# fade back while healthy and nothing is happening; full strength when hurt
	var want: float = 0.45 if (_frac >= 0.999 and _trail <= _frac) else 1.0
	_alpha = move_toward(_alpha, want, delta * (3.0 if want > _alpha else 0.5))
	queue_redraw()

func _seg_arcs(from_f: float, to_f: float, color: Color, width: float, center: Vector2) -> void:
	# draw the [from_f, to_f] part of the semicircle, broken into segments with small gaps
	var gap := deg_to_rad(gap_deg)
	for i in segments:
		var s0 := float(i) / segments
		var s1 := float(i + 1) / segments
		var a := maxf(s0, from_f)
		var b := minf(s1, to_f)
		if b <= a:
			continue
		var a0: float = PI + PI * a + (gap * 0.5 if a <= s0 + 0.0001 else 0.0)
		var a1: float = PI + PI * b - (gap * 0.5 if b >= s1 - 0.0001 else 0.0)
		if a1 > a0:
			draw_arc(center, radius, a0, a1, maxi(3, int((a1 - a0) * 40.0)), color, width, true)

func _draw() -> void:
	var center := Vector2(size.x * 0.5, size.y - 4.0)
	var low := _frac < low_frac
	var pulse: float = 0.5 + 0.5 * sin(_t * 6.0) if low else 0.0
	var col: Color = fill_color.lerp(low_color, clampf((low_frac - _frac) / low_frac * 2.0 + 0.5, 0.0, 1.0)) if low else fill_color
	var m := Color(1, 1, 1, _alpha)
	# thin outer guide + track
	draw_arc(center, radius + thickness * 0.5 + 3.0, PI, TAU, 64, Color(0.75, 0.82, 1.0, 0.18) * m, 1.0, true)
	_seg_arcs(0.0, 1.0, track_color * m, thickness, center)
	# soft glow under the fill
	var glow := col
	glow.a = (0.16 + 0.22 * pulse) * _alpha
	_seg_arcs(0.0, _frac, glow, thickness + 7.0, center)
	if _trail > _frac:
		_seg_arcs(_frac, _trail, trail_color * m, thickness, center)
	_seg_arcs(0.0, _frac, col * m, thickness, center)
	# end cap tick at the current value
	if _frac > 0.0:
		var a := PI + PI * _frac
		var dir := Vector2(cos(a), sin(a))
		draw_line(center + dir * (radius - thickness * 0.9), center + dir * (radius + thickness * 0.9), Color(1, 1, 1, 0.9 * _alpha), 2.0, true)
	# number in the middle of the dome
	if _font:
		var txt := str(int(ceil(_frac * 100.0)))
		var fs := 26
		var w := _font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(_font, center + Vector2(-w * 0.5, -radius * 0.32), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(col.r, col.g, col.b, 0.9 * _alpha))
		var lab := "VITALS"
		var w2 := _font.get_string_size(lab, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
		draw_string(_font, center + Vector2(-w2 * 0.5, -radius * 0.32 + 16.0), lab, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.75, 0.8, 0.95, 0.55 * _alpha))
