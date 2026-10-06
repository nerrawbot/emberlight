extends Area3D
## Walking through sets the player's respawn point to this node's position and facing (yaw).

func _ready() -> void:
	collision_layer = 0       # only detects; never blocks the player's interact ray
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		body.spawn_transform = Transform3D(Basis(Vector3.UP, global_rotation.y), global_position)
