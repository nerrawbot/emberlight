extends Node
## Slides a door or shutter that is part of an instanced level glb: a "-col" mesh with its StaticBody3D child, e.g.
## the Peak's BossGate / ExitGate / HiddenDoor (art_src/v10_peak.py models them closed, origin at the bottom centre).
## open() / close() tween the target by `open_offset`. Once the GameState key `open_flag` is set (the boss fight's
## job), the door starts open on every later visit.

const GameState := preload("res://scripts/game_state.gd")

@export var target: NodePath
@export var open_offset := Vector3(0, 4.6, 0)
@export var start_open := false
@export var open_flag := ""
@export var duration := 1.6

var is_open := false
var _body: Node3D
var _closed: Vector3
var _tw: Tween

func _ready() -> void:
	_body = get_node_or_null(target) as Node3D
	if _body == null:
		push_warning("peak_door: no target at %s" % target)
		return
	_closed = _body.position
	if start_open or (open_flag != "" and GameState.get_value(open_flag, false)):
		_body.position = _closed + open_offset
		is_open = true

func open() -> void:
	_move(true)

func close() -> void:
	_move(false)

func _move(to_open: bool) -> void:
	if _body == null or is_open == to_open:
		return
	is_open = to_open
	if _tw:
		_tw.kill()
	_tw = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tw.tween_property(_body, "position", _closed + (open_offset if to_open else Vector3.ZERO), duration)
