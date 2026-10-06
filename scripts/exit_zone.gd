extends Area3D
## Trigger volume that ends the level or moves the player to another scene.
## If `next_scene` is set, the player fades out and the new scene puts them at the node
## called `target_spawn` (a Marker3D in group "spawn_point"); see player.gd `_apply_spawn()`.

signal exit_reached(body: Node)

const GameState := preload("res://scripts/game_state.gd")

@export_file("*.tscn") var next_scene := ""
@export var target_spawn := ""
@export var message := ""
@export var banner_hold := 5.0
@export var once := true
## Merged into GameState just before the scene change (e.g. {"lift_stop": 2}).
@export var set_flags := {}

var _triggered := false

func _ready() -> void:
	collision_layer = 0       # only detects; never blocks the player's interact ray
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if (once and _triggered) or not body.is_in_group("player"):
		return
	_triggered = true
	exit_reached.emit(body)
	if message != "" and body.has_method("show_banner"):
		body.show_banner(message, banner_hold)
	if next_scene != "":
		if body.has_method("fade_out"):
			body.input_enabled = false
			await body.fade_out(0.6)
		GameState.merge(set_flags)
		get_tree().root.set_meta("spawn_point", target_spawn)
		get_tree().call_deferred("change_scene_to_file", next_scene)
