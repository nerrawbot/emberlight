extends AnimatableBody3D
## Cargo lift with several landings (cavern floor, upper deck, surface). Needs grid power.
## Drives its cable, counterweight, headframe sheave and one safety gate per landing.

signal state_changed
signal arrived(stop: int)

const GameState := preload("res://scripts/game_state.gd")

@export var stops: PackedFloat32Array = PackedFloat32Array([0.2, 18.0, 34.3])
@export var stop_names: PackedStringArray = PackedStringArray(["the cavern floor", "the upper deck", "the surface"])
@export var start_stop := 1
@export var speed := 3.2
@export var pulley_y := 41.6
@export var cw_top := 40.0
@export var sheave_radius := 1.15
@export var cable_path: NodePath
@export var counterweight_path: NodePath
@export var cw_cable_path: NodePath
@export var sheave_path: NodePath
## One entry per stop (same order as `stops`); leave an entry empty for a landing without a gate.
@export var gate_paths: Array[NodePath] = []
## Riding up to the top stop with the player aboard swaps to this scene once the car passes handoff_y
## (still inside the shaft lining), where the same car carries on up. Empty = no hand-over.
@export_file("*.tscn") var handoff_scene := ""
@export var handoff_y := 30.4
@export var handoff_respawn := "FromLift"

var target := 0
var moving := false
var _handing := false
var _cable: Node3D
var _cw: Node3D
var _cw_cable: Node3D
var _sheave: Node3D
var _gates: Array = []

func _ready() -> void:
	target = clampi(start_stop, 0, stops.size() - 1)
	position.y = stops[target]
	# arriving from surface.tscn mid-ride: the car is in the shaft, carrying the player down
	var ride: Variant = GameState.take("car_ride", null)
	if ride is Dictionary:
		position.y = ride.get("y", position.y)
		target = clampi(ride.get("target", 1), 0, stops.size() - 1)
		moving = true
		_board.call_deferred(ride)
	_cable = get_node_or_null(cable_path)
	_cw = get_node_or_null(counterweight_path)
	_cw_cable = get_node_or_null(cw_cable_path)
	_sheave = get_node_or_null(sheave_path)
	for p in gate_paths:
		_gates.append(get_node_or_null(p) if not p.is_empty() else null)
	_update_rig()
	_update_gates.call_deferred(true)

func _board(ride: Dictionary) -> void:
	var p := get_tree().get_first_node_in_group("player")
	if p and p.has_method("board_car"):
		p.board_car(self, ride)
	state_changed.emit()

func _grid() -> Node:
	return get_tree().get_first_node_in_group("power_grid")

func has_power() -> bool:
	var g := _grid()
	return g == null or g.powered

func is_at(stop: int) -> bool:
	return not moving and absf(position.y - stops[stop]) < 0.05

## Landing the car is parked at, or -1 while it is between landings.
func current_stop() -> int:
	for i in stops.size():
		if is_at(i):
			return i
	return -1

func nearest_stop() -> int:
	var best := 0
	for i in stops.size():
		if absf(position.y - stops[i]) < absf(position.y - stops[best]):
			best = i
	return best

func send_to(stop: int) -> String:
	if not has_power():
		return "No power. The lift motor is dead."
	if is_at(stop):
		return "The lift is already here."
	target = stop
	moving = true
	_update_gates()
	state_changed.emit()
	return "Lift on its way to %s..." % stop_names[stop]

## Car controls: one landing up (+1) or down (-1) from where the car is (or is heading).
func step(dir: int) -> String:
	var from := target if moving else nearest_stop()
	var to := from + dir
	if to < 0 or to >= stops.size():
		return "Already at the %s landing." % ("bottom" if dir < 0 else "top")
	return send_to(to)

func next_stop_name(dir: int) -> String:
	var to := (target if moving else nearest_stop()) + dir
	return stop_names[to] if to >= 0 and to < stops.size() else ""

func _physics_process(delta: float) -> void:
	if not moving or not has_power():
		return
	var goal := stops[target]
	var remaining := absf(goal - position.y)
	var v := speed * clampf(remaining / 1.4, 0.22, 1.0)   # ease into the stop
	position.y = move_toward(position.y, goal, v * delta)
	if absf(position.y - goal) < 0.001:
		position.y = goal
		moving = false
		_update_gates()
		state_changed.emit()
		arrived.emit(target)
	_update_rig()
	if handoff_scene != "" and not _handing and moving and target == stops.size() - 1 and position.y >= handoff_y:
		var p := get_tree().get_first_node_in_group("player")
		if p and p.has_method("is_in_car") and p.is_in_car(self):
			_handing = true
			p.change_scene_by_lift(handoff_scene, self, {"respawn": handoff_respawn})

func _update_rig() -> void:
	var travel := position.y - stops[0]
	if _cable:
		var bottom := position.y + 3.25
		_cable.scale.y = maxf(0.01, pulley_y - bottom)
		_cable.position.y = (pulley_y + bottom) * 0.5
	if _cw:
		_cw.position.y = cw_top - travel
		if _cw_cable:
			var b := _cw.position.y + 0.3
			_cw_cable.scale.y = maxf(0.01, pulley_y - b)
			_cw_cable.position.y = (pulley_y + b) * 0.5
	if _sheave:
		_sheave.rotation.x = travel / sheave_radius

func _update_gates(instant := false) -> void:
	for i in _gates.size():
		var g = _gates[i]
		if g and g.has_method("set_open"):
			g.set_open(is_at(i), instant)
