extends "res://scripts/interactable.gd"
## Bolted double gate across the top of the surface stairwell. The bolt is on the surface side
## (local -X), so it can only be opened by someone who came up by the lift.
## Children: Model (stair_gate.glb with GateLeaf_L / GateLeaf_R), Block (StaticBody3D).

signal opened

const GameState := preload("res://scripts/game_state.gd")

@export var open_angle := 105.0
@export var is_open := false
## v8: the stairwell behind it has caved in (assets/level/collapse.glb), so the gate stays shut for good
@export var collapsed := false

var _leaves: Array[Node3D] = []
var _block: CollisionShape3D

func _ready() -> void:
	super._ready()
	for n in ["GateLeaf_L", "GateLeaf_R"]:
		var l := find_child(n, true, false) as Node3D
		if l:
			_leaves.append(l)
	_block = get_node_or_null("Block/CollisionShape3D")
	if collapsed:
		return
	# the same gate exists in the cavern (main.tscn) and on the surface (surface.tscn): opened in one, open in both
	if GameState.get_value("stair_gate_open", false):
		is_open = true
	if is_open:
		_apply(true)

func _on_surface_side(by: Node) -> bool:
	return to_local((by as Node3D).global_position).x < 0.0

func get_prompt() -> String:
	if collapsed:
		return "Stairwell caved in"
	if is_open:
		return "Gate (open)"
	var p := get_tree().get_first_node_in_group("player")
	if p and _on_surface_side(p):
		return "Draw the bolt and open the gate"
	return "Bolted shut from the other side"

func _on_interact(by: Node) -> void:
	if collapsed:
		if by.has_method("show_toast"):
			by.show_toast("Rubble chokes the stairs below. No way down here.")
		return
	if is_open:
		return
	if not _on_surface_side(by):
		if by.has_method("show_toast"):
			by.show_toast("It won't budge. The bolt is on the surface side.")
		return
	is_open = true
	GameState.set_value("stair_gate_open", true)
	_apply(false)
	opened.emit()
	if by.has_method("show_toast"):
		by.show_toast("The bolt grinds back. The stairs down are open.")

func _apply(instant: bool) -> void:
	if _block:
		_block.set_deferred("disabled", true)
	for i in _leaves.size():
		var l := _leaves[i]
		# left leaf hinges at -Y (Godot +Z), right at +Y (Godot -Z); both swing towards local -X
		var a := deg_to_rad(open_angle) * (1.0 if i == 0 else -1.0)
		if instant:
			l.rotation.y = a
		else:
			create_tween().tween_property(l, "rotation:y", a, 1.4).set_trans(Tween.TRANS_SINE).set_delay(0.25 * i)
