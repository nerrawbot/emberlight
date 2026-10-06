extends Control
## The drone's shield: a thin grey arc just outside the health dome (health_arc.gd), one segment per block
## (player.shield_block, 15). Hidden until the player has the drone. Same rect as HUD/HealthArc (player.gd adds it).
## Hits leave a pale trail like the health arc; while it's down the empty track blinks slowly until it regenerates.

@export var radius := 110.0
@export var thickness := 6.0
@export var span := 0.62            # fraction of the half circle it covers, centred over the top
@export var gap_deg := 2.0
@export var fill_color := Color(0.66, 0.67, 0.69, 0.95)     # neutral grey: apart from the health arc's pale blue
@export var track_color := Color(0.04, 0.04, 0.05, 0.6)
@export var trail_color := Color(1.0, 1.0, 1.0, 0.75)

var _frac := 1.0
var _trail := 1.0
var _trail_hold := 0.0
var _blocks := 1
var _has := false
var _t := 0.0
var _alpha := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var p := get_tree().get_first_node_in_group("player")
	if p and p.has_signal("shield_changed"):
		p.shield_changed.connect(_on_shield)

func _on_shield(value: float, max_value: float, block: float, has: bool) -> void:
	var f := clampf(value / maxf(max_value, 0.001), 0.0, 1.0)
	if f < _frac - 0.001:
		_trail = maxf(_trail, _frac)
		_trail_hold = 0.4
	_frac = f
	_trail = maxf(_trail, _frac)
	_blocks = maxi(1, int(ceil(max_value / maxf(block, 0.001) - 0.001)))
	_has = has
	queue_redraw()

func _process(delta: float) -> void:
	_t += delta
	_trail_hold -= delta
	if _trail_hold <= 0.0 and _trail > _frac:
		_trail = maxf(_frac, _trail - delta * 0.9)
	var want: float = 0.0 if not _has else (0.5 if (_frac >= 0.999 and _trail <= _frac) else 1.0)
	_alpha = move_toward(_alpha, want, delta * (3.0 if want > _alpha else 0.6))
	if _alpha > 0.0 or want > 0.0:
		queue_redraw()

func _arcs(from_f: float, to_f: float, color: Color, width: float, center: Vector2) -> void:
	var gap := deg_to_rad(gap_deg)
	var a_lo := PI + PI * (1.0 - span) * 0.5
	var a_len := PI * span
	for i in _blocks:
		var s0 := float(i) / _blocks
		var s1 := float(i + 1) / _blocks
		var a := maxf(s0, from_f)
		var b := minf(s1, to_f)
		if b <= a:
			continue
		var a0: float = a_lo + a_len * a + (gap * 0.5 if a <= s0 + 0.0001 and i > 0 else 0.0)
		var a1: float = a_lo + a_len * b - (gap * 0.5 if b >= s1 - 0.0001 and i < _blocks - 1 else 0.0)
		if a1 > a0:
			draw_arc(center, radius, a0, a1, maxi(3, int((a1 - a0) * 40.0)), color, width, true)

func _draw() -> void:
	if _alpha <= 0.001:
		return
	var center := Vector2(size.x * 0.5, size.y - 4.0)
	var m := Color(1, 1, 1, _alpha)
	var track := track_color
	if _frac <= 0.0:          # down: the empty track blinks
		track = track.lerp(Color(0.6, 0.62, 0.7, 0.5), 0.5 + 0.5 * sin(_t * 5.0))
	_arcs(0.0, 1.0, track * m, thickness, center)
	if _trail > _frac:
		_arcs(_frac, _trail, trail_color * m, thickness, center)
	var glow := fill_color
	glow.a = 0.18 * _alpha
	_arcs(0.0, _frac, glow, thickness + 5.0, center)
	_arcs(0.0, _frac, fill_color * m, thickness, center)
	# end ticks so a single block still reads as a bar
	for f: float in [0.0, 1.0]:
		var a: float = PI + PI * (1.0 - span) * 0.5 + PI * span * f
		var dir := Vector2(cos(a), sin(a))
		draw_line(center + dir * (radius - thickness), center + dir * (radius + thickness), Color(0.8, 0.82, 0.88, 0.5 * _alpha), 1.0, true)
