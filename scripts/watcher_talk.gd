extends "res://scripts/interactable.gd"
## Talk to a watcher (scripts/creatures/watcher.gd): an Area3D child of the watcher, round its head. [E] opens its
## tree from scripts/dialogue/watcher_lines.gd in the player's dialogue box; the head locks on while it talks.

@export var tree_id := "sentinel_07"
@export var speaker := "SENTINEL-07"

func get_prompt() -> String:
	return "Talk to the watcher"

func _on_interact(by: Node) -> void:
	if by.has_method("start_dialogue"):
		get_parent().set("talking", true)
		by.start_dialogue(tree_id, speaker, self)

## player.gd calls this when the box closes.
func end_talk() -> void:
	get_parent().set("talking", false)