extends Control
## Boss health bar across the top of the HUD (added by boss_arena.gd): the name in Cinzel, a thin bar with a damage
## trail, a notch at half (the phase change) and a pulse once the boss is down.

const FONT := preload("res://assets/fonts/Cinzel-Variable.ttf")
const BAR_W := 640.0
const BAR_H := 10.0

var title := "SPHAEROID"
var subtitle := ""
var shown := false
var down := false
var _frac := 1.0
var _trail := 1.0
var _hold := 0.0
var _alpha := 0.0
var _t := 0.0
var _bold: FontVariation
var _flash := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor_left = 0.5
	anchor_right = 0.5
	anchor_top = 0.0
	anchor_bottom = 0.0
	offset_left = -BAR_W * 0.5 - 20.0
	offset_right = BAR_W * 0.5 + 20.0
	offset_top = 22.0
	offset_bottom = 100.0
	_bold = FontVariation.new()
	_bold.base_font = FONT
	_bold.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 700}

func set_health(v: float, m: float) -> void:
	var f := clampf(v / maxf(m, 1.0), 0.0, 1.0)
	if f < _frac:
		_hold = 0.5
		_flash = 1.0
		_trail = maxf(_trail, _frac)
	elif f > _frac:
		_trail = f          # healing: the bar grows straight back
	_frac = f

func _process(delta: float) -> void:
	_t += delta
	_alpha = move_toward(_alpha, 1.0 if shown else 0.0, delta * (2.5 if shown else 1.2))
	_hold -= delta
	if _hold <= 0.0:
		_trail = move_toward(_trail, _frac, delta * 0.5)
	_flash = maxf(0.0, _flash - delta * 4.0)
	visible = _alpha > 0.01
	if visible:
		queue_redraw()

func _draw() -> void:
	var a := _alpha
	var w := size.x
	var x0 := (w - BAR_W) * 0.5
	var ty := 26.0
	draw_string(_bold, Vector2(0, ty), title, HORIZONTAL_ALIGNMENT_CENTER, w, 22, Color(0.93, 0.9, 0.95, a))
	if subtitle != "":
		draw_string(FONT, Vector2(0, ty + 15.0), subtitle, HORIZONTAL_ALIGNMENT_CENTER, w, 11, Color(0.75, 0.72, 0.82, a * 0.85))
	var y := ty + 31.0
	var r := Rect2(x0, y, BAR_W, BAR_H)
	draw_rect(r.grow(2.0), Color(0.02, 0.02, 0.04, 0.7 * a))
	draw_rect(r, Color(0.12, 0.1, 0.14, 0.85 * a))
	draw_rect(Rect2(x0, y, BAR_W * _trail, BAR_H), Color(0.95, 0.85, 0.75, 0.55 * a))
	var fill := Color(0.86, 0.2, 0.14).lerp(Color(1, 0.9, 0.85), _flash * 0.5)
	if down:
		fill = Color(0.6, 0.62, 0.75).lerp(Color(0.95, 0.95, 1.0), 0.5 + 0.5 * sin(_t * 6.0))
	draw_rect(Rect2(x0, y, BAR_W * _frac, BAR_H), Color(fill, a))
	draw_rect(Rect2(x0, y, BAR_W * _frac, 2.0), Color(1, 0.75, 0.65, 0.35 * a))
	# the phase notch at half
	draw_rect(Rect2(x0 + BAR_W * 0.5 - 1.0, y - 3.0, 2.0, BAR_H + 6.0), Color(0.95, 0.9, 0.85, 0.8 * a))
	draw_rect(r.grow(2.0), Color(0.6, 0.55, 0.65, 0.5 * a), false, 1.0)
