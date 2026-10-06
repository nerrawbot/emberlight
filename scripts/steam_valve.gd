extends "res://scripts/interactable.gd"
## Turns the steam vents (group "steam_vents") on and off and spins the hand-wheel.

@export var open := true
var _wheel: Node3D

func _ready() -> void:
	super._ready()
	_wheel = find_child("Wheel", true, false)
	_apply.call_deferred()

func get_prompt() -> String:
	return "Close the steam valve" if open else "Open the steam valve"

func _on_interact(by: Node) -> void:
	open = not open
	if _wheel:
		var tw := create_tween()
		tw.tween_property(_wheel, "rotation:z", _wheel.rotation.z + (TAU * 1.5 if open else -TAU * 1.5), 1.2).set_trans(Tween.TRANS_SINE)
	_apply()
	if by.has_method("show_toast"):
		by.show_toast("Steam hisses back into the pipes." if open else "The vents sputter and fall quiet.")

func _apply() -> void:
	for v in get_tree().get_nodes_in_group("steam_vents"):
		v.emitting = open
