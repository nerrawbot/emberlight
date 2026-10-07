extends Node3D
## v12: Patrol Station 4 at the head of the Peak bridge (surface.tscn "PatrolStation", built by build_surface.gd
## build_station(); model assets/props/patrol_station.glb from art_src/v12_station.py). The lift gate across the
## stub stays down until the player presents the sealed station pass at the reader (station_reader.gd). Then it
## goes up for good: GameState `open_flag`. Plain (broken-seal) passes are refused.
## Children: Model (the glb: Gate, StatusLamp, ReaderLamp, BeaconLens are its moving / recoloured parts), Reader,
## GateBody (AnimatableBody3D, the gate's collision), Lights/StatusLight, Lights/Beacon.

const GameState := preload("res://scripts/game_state.gd")

@export var key_item := "station_pass_sealed"
@export var void_item := "station_pass"
@export var open_flag := "station_gate_open"
@export var lift := 2.55
@export var duration := 2.4

const RED := Color(1.0, 0.14, 0.07)
const GREEN := Color(0.3, 1.0, 0.45)
const AMBER := Color(1.0, 0.62, 0.16)

var is_open := false
var _gate: Node3D
var _body: AnimatableBody3D
var _gate_y0 := 0.0
var _body_y0 := 0.0
var _status_mat := StandardMaterial3D.new()
var _reader_mat := StandardMaterial3D.new()
var _beacon_mat := StandardMaterial3D.new()
var _status_light: OmniLight3D
var _beacon_light: OmniLight3D
var _t := 0.0
var _flash := 0.0          # reader blink timer (refused)
var _busy := false

func _ready() -> void:
	_gate = get_node_or_null("Model/Gate") as Node3D
	_body = get_node_or_null("GateBody") as AnimatableBody3D
	_status_light = get_node_or_null("Lights/StatusLight") as OmniLight3D
	_beacon_light = get_node_or_null("Lights/Beacon") as OmniLight3D
	for pair in [["Model/StatusLamp", _status_mat], ["Model/ReaderLamp", _reader_mat], ["Model/BeaconLens", _beacon_mat]]:
		var mi := get_node_or_null(pair[0]) as MeshInstance3D
		var m: StandardMaterial3D = pair[1]
		m.emission_enabled = true
		m.roughness = 0.3
		if mi:
			mi.material_override = m
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_beacon_mat.albedo_color = AMBER.darkened(0.4)
	_beacon_mat.emission = AMBER
	if _gate:
		_gate_y0 = _gate.position.y
	if _body:
		_body_y0 = _body.position.y
	if GameState.get_value(open_flag, false):
		is_open = true
		if _gate:
			_gate.position.y = _gate_y0 + lift
		if _body:
			_body.position.y = _body_y0 + lift
	_set_lamps(GREEN if is_open else RED)

func _process(delta: float) -> void:
	_t += delta
	# the tip beacon: a slow amber pulse, warning of the drop
	var k := pow(0.5 + 0.5 * sin(_t * 3.3), 4.0)
	_beacon_mat.emission_energy_multiplier = 0.6 + 5.0 * k
	if _beacon_light:
		_beacon_light.light_energy = 0.15 + 1.6 * k
	if _flash > 0.0:
		_flash -= delta
		var on := fmod(_flash, 0.24) > 0.12
		_reader_mat.emission_energy_multiplier = 6.0 if on else 0.4
		if _flash <= 0.0:
			_set_lamps(GREEN if is_open else RED)

func _set_lamps(c: Color) -> void:
	for m in [_status_mat, _reader_mat]:
		(m as StandardMaterial3D).albedo_color = c.darkened(0.45)
		(m as StandardMaterial3D).emission = c
		(m as StandardMaterial3D).emission_energy_multiplier = 3.5
	if _status_light:
		_status_light.light_color = c

## [E] prompt for the reader.
func reader_prompt() -> String:
	if is_open or _busy:
		return ""
	return "Present the sealed station pass" if _count(get_tree().get_first_node_in_group("player"), key_item) > 0 \
		else "Use the pass reader"

func present(by: Node) -> void:
	if is_open or _busy:
		return
	if _count(by, key_item) > 0:
		_busy = true
		_say(by, "PASS ACCEPTED  -  seal verified. Proceed.")
		_set_lamps(GREEN)
		var tw := create_tween()
		tw.tween_interval(0.6)
		tw.tween_callback(open)
		return
	_flash = 1.2
	_set_lamps(RED)
	GameState.set_value("station_refused", true)
	if _count(by, void_item) > 0:
		_say(by, "PASS VOID  -  the seal is broken. Entry refused.")
	else:
		_say(by, "NO PASS  -  a station pass is required beyond this point.")

func open() -> void:
	if is_open:
		return
	is_open = true
	_busy = false
	GameState.set_value(open_flag, true)
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if _gate:
		tw.tween_property(_gate, "position:y", _gate_y0 + lift, duration)
	if _body:
		tw.tween_property(_body, "position:y", _body_y0 + lift, duration)

func _count(who: Node, id: String) -> int:
	if who and who.has_method("item_count"):
		return int(who.call("item_count", id))
	return 0

func _say(who: Node, text: String) -> void:
	if who and who.has_method("show_toast"):
		who.call("show_toast", text, 2.8)