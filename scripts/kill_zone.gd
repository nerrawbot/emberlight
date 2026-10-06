extends Area3D
## Deadly volume (deep water, pits): sends the player back to their last checkpoint.

@export var message := "The water closes over you..."

func _ready() -> void:
	collision_layer = 0       # only detects; never blocks the player's interact ray
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player") and body.has_method("die"):
		body.die(message)
