extends "res://scripts/interactable.gd"
## The Sphaeroid's [E] once it has seized up under 2% health (creatures/sphaeroid.gd turns this area's layer on
## then): cuts its power, which ends the fight.

var boss: Node

func get_prompt() -> String:
	return "Cut the Sphaeroid's power"

func _on_interact(by: Node) -> void:
	if boss and is_instance_valid(boss):
		boss.call("unpower", by)
