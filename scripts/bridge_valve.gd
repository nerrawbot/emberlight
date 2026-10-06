extends "res://scripts/interactable.gd"
## Hydraulic valve on the pipe machinery: opening it vents the ram and lowers the drawbridge.
## One-way: once open it stays open.

@export var bridge_path: NodePath
@export var steam_paths: Array[NodePath] = []

var is_open := false
var _wheel: Node3D

func _ready() -> void:
	super._ready()
	_wheel = find_child("Wheel", true, false)

func get_prompt() -> String:
	return "Valve (open)" if is_open else "Open the hydraulic valve"

func _on_interact(by: Node) -> void:
	if is_open:
		return
	is_open = true
	if _wheel:
		create_tween().tween_property(_wheel, "rotation:z", _wheel.rotation.z - TAU * 2.0, 1.6).set_trans(Tween.TRANS_SINE)
	for p in steam_paths:
		var s := get_node_or_null(p) as GPUParticles3D
		if s:
			s.restart()
			s.emitting = true
	var b := get_node_or_null(bridge_path)
	if b and b.has_method("lower"):
		b.lower()
	if by.has_method("show_toast"):
		by.show_toast("Pressure bleeds out of the ram with a shriek. The walkway is coming down.", 3.5)
