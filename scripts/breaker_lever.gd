extends "res://scripts/interactable.gd"
## Main breaker: toggles the power grid and animates its handle.

@export var on_angle := 1.9
var _handle: Node3D

func _ready() -> void:
	super._ready()
	_handle = find_child("Handle", true, false)
	_setup.call_deferred()

func _setup() -> void:
	var g := grid()
	if g:
		g.power_changed.connect(_on_power)
		_on_power(g.powered, true)

func get_prompt() -> String:
	var g := grid()
	return "Cut the power" if (g and g.powered) else "Pull the breaker"

func _on_interact(by: Node) -> void:
	var g := grid()
	if g == null:
		return
	g.set_powered(not g.powered)
	if by.has_method("show_toast"):
		by.show_toast("Power restored. Somewhere a motor groans awake." if g.powered else "Power cut.")

func _on_power(on: bool, instant := false) -> void:
	if _handle == null:
		return
	var target := on_angle if on else 0.0
	if instant:
		_handle.rotation.x = target
	else:
		create_tween().tween_property(_handle, "rotation:x", target, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
