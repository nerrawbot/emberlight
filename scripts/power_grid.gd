extends Node
## Global power state. Lights, the lift and indicators listen to `power_changed`.

signal power_changed(on: bool)

@export var powered := false
@export var intro_text := "THE POWER IS OUT\nfind the breaker"

const GameState := preload("res://scripts/game_state.gd")

func _enter_tree() -> void:
	add_to_group("power_grid")
	# stays on when you leave the scene and come back (e.g. a trip to the surface)
	if GameState.get_value(_key(), false):
		powered = true

func _key() -> String:
	return "powered@" + (owner.scene_file_path if owner else "")

func _ready() -> void:
	if not "--shots" in OS.get_cmdline_user_args() and not "--walktest" in OS.get_cmdline_user_args():
		_intro.call_deferred()

func _intro() -> void:
	await get_tree().create_timer(1.2).timeout
	var p := get_tree().get_first_node_in_group("player")
	if p and p.has_method("show_banner") and not powered:
		p.show_banner(intro_text, 3.0)

func set_powered(on: bool) -> void:
	if on == powered:
		return
	powered = on
	GameState.set_value(_key(), on)
	power_changed.emit(on)
