extends Area3D
## Base class for anything the player can use with [E].
## Override _on_interact() / get_prompt() in subclasses, or connect to `interacted`.

signal interacted(by: Node)

@export var prompt_text := "Interact"
@export var interact_id: StringName = &""

func _ready() -> void:
	add_to_group("interactable")
	monitorable = true

func get_prompt() -> String:
	return prompt_text

func interact(by: Node) -> void:
	interacted.emit(by)
	_on_interact(by)

func _on_interact(_by: Node) -> void:
	print("[Interactable] %s used" % name)

func grid() -> Node:
	return get_tree().get_first_node_in_group("power_grid")
