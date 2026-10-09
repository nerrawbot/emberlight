extends "res://scripts/interactable.gd"
## A use-spot for the mast's puzzles (scripts/mast/band*.gd): the puzzle script sets the prompt and the action as
## callables. An empty prompt hides the [E] hint; enabled = false takes it out of the interact ray's way.

var prompt_fn: Callable
var use_fn: Callable

func get_prompt() -> String:
	return String(prompt_fn.call()) if prompt_fn.is_valid() else prompt_text

func _on_interact(by: Node) -> void:
	if use_fn.is_valid():
		use_fn.call(by)

func set_enabled(on: bool) -> void:
	for cs in find_children("*", "CollisionShape3D", false, false):
		(cs as CollisionShape3D).set_deferred("disabled", not on)

## A use-spot under `parent` with a box (or sphere when size.y == 0) shape at `offset`.
static func make(parent: Node3D, name_: String, size: Vector3, offset: Vector3, prompt: Callable, use: Callable) -> Area3D:
	var a := Area3D.new()
	a.name = name_
	a.set_script(load("res://scripts/mast/mast_use.gd"))
	a.set("prompt_fn", prompt)
	a.set("use_fn", use)
	var cs := CollisionShape3D.new()
	if size.y == 0.0:
		var sp := SphereShape3D.new()
		sp.radius = size.x
		cs.shape = sp
	else:
		var bx := BoxShape3D.new()
		bx.size = size
		cs.shape = bx
	cs.position = offset
	a.add_child(cs)
	parent.add_child(a)
	return a
