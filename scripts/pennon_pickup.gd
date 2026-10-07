extends "res://scripts/interactable.gd"
## The Pennon on the plinth in the Peak hall's annex (behind HiddenDoor, which opens once the Sphaeroid is
## unpowered). [E] takes it: player.give_pennon(). It hovers and turns slowly over the plinth, lit by a warm glint.
## Gone for good once taken (GameState "has_pennon").

const GameState := preload("res://scripts/game_state.gd")
const PennonModel := preload("res://scripts/pennon_model.gd")

var _model: Node3D
var _glint: OmniLight3D
var _t := 0.0

func _ready() -> void:
	super._ready()
	prompt_text = "Take the Pennon"
	if GameState.get_value("has_pennon", false):
		queue_free()
		return
	_model = PennonModel.make()
	_model.scale = Vector3.ONE * 0.5
	add_child(_model)
	_glint = OmniLight3D.new()
	_glint.light_color = Color(1.0, 0.72, 0.55)
	_glint.omni_range = 3.5
	_glint.shadow_enabled = false
	_glint.position = Vector3(0, 0.9, 0.5)
	add_child(_glint)
	var cs := CollisionShape3D.new()
	var bx := BoxShape3D.new()
	bx.size = Vector3(1.6, 0.7, 0.6)
	cs.shape = bx
	cs.position = Vector3(0, 0.35, 0)
	add_child(cs)

func _process(delta: float) -> void:
	_t += delta
	if _model:
		_model.position.y = 0.12 + sin(_t * 1.3) * 0.04
		_model.rotation.y = sin(_t * 0.4) * 0.35
		_model.rotation.z = sin(_t * 0.9) * 0.05
	if _glint:
		_glint.light_energy = 0.8 + 0.4 * pow(0.5 + 0.5 * sin(_t * 1.7), 3.0)

func _on_interact(by: Node) -> void:
	if not by.has_method("give_pennon"):
		return
	by.give_pennon()
	if by.has_method("show_banner"):
		by.show_banner("THE PENNON")
	if by.has_method("show_toast"):
		by.show_toast("A wing of lashed planks.   [Space] in mid-air, from a height:  glide.   [Space] again:  let go.", 5.0)
	queue_free()
