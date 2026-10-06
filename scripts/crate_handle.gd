extends "res://scripts/interactable.gd"
## Child Area3D of a RigidBody3D crate: [E] shoves the crate where the player is looking.

@export var shove_speed := 3.6

func get_prompt() -> String:
	return "Shove the crate"

func _on_interact(by: Node) -> void:
	var body := get_parent() as RigidBody3D
	if body == null:
		return
	var cam := by.get_node_or_null("Head/Camera3D") as Node3D
	var dir: Vector3 = -cam.global_transform.basis.z if cam else (body.global_position - by.global_position)
	dir.y = 0.0
	dir = dir.normalized()
	body.apply_central_impulse((dir + Vector3.UP * 0.2) * shove_speed * body.mass)
	body.apply_torque_impulse(Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * body.mass * 0.15)
