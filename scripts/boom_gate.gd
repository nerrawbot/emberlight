extends Node3D
## Safety boom at the top landing: closed (and solid) whenever the lift car is not there.

@export var open_angle := -1.35
@onready var _bar: Node3D = $Pivot
@onready var _shape: CollisionShape3D = $Block/CollisionShape3D

func set_open(open: bool, instant := false) -> void:
	_shape.set_deferred("disabled", open)
	var t := open_angle if open else 0.0
	if instant:
		_bar.rotation.x = t
	else:
		create_tween().tween_property(_bar, "rotation:x", t, 0.9).set_trans(Tween.TRANS_SINE)
