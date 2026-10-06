extends "res://scripts/interactable.gd"
## The steel shaft lying at the bottom of the start room. [E] picks it up (player.give_weapon()).
## Children: Model (shaft.glb), Glint (OmniLight3D, optional), CollisionShape3D.
## Gone for good once taken (GameState "has_weapon"), so it doesn't reappear when you come back.

const GameState := preload("res://scripts/game_state.gd")

var _glint: OmniLight3D
var _t := 0.0

func _ready() -> void:
	super._ready()
	prompt_text = "Take the steel shaft"
	_glint = get_node_or_null("Glint")
	if GameState.get_value("has_weapon", false):
		queue_free()

func _process(delta: float) -> void:
	_t += delta
	if _glint:   # slow breathing glint so it catches the eye from the stairs
		_glint.light_energy = 0.9 + 0.5 * pow(0.5 + 0.5 * sin(_t * 1.7), 3.0)

func _on_interact(by: Node) -> void:
	if not by.has_method("give_weapon"):
		return
	by.give_weapon()
	if by.has_method("show_toast"):
		by.show_toast("A steel shaft, heavy at one end.   [LMB / Q]  swing", 3.5)
	queue_free()
