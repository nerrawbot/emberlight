extends Area3D
## Climbable volume. `climb_normal` points from the ladder towards the climbing player.

@export var climb_normal := Vector3(0, 0, 1)

func _ready() -> void:
	body_entered.connect(_on_enter)
	body_exited.connect(_on_exit)

func _on_enter(b: Node) -> void:
	if b.has_method("enter_ladder"):
		b.enter_ladder(self)

func _on_exit(b: Node) -> void:
	if b.has_method("exit_ladder"):
		b.exit_ladder(self)
