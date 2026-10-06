extends "res://scripts/interactable.gd"
## Lift call point on a landing (car_dir = 0) or an up/down button in the car (car_dir = +1 / -1).
## Indicator lamp shows power + movement.

@export var lift_path: NodePath
@export var stop := 0
@export var car_dir := 0

var _lift: Node
var _mat := StandardMaterial3D.new()
var _t := 0.0

func _ready() -> void:
	super._ready()
	var lamp := find_child("Lamp", true, false) as MeshInstance3D
	_mat.albedo_color = Color(0.05, 0.05, 0.08)
	_mat.emission_enabled = true
	if lamp:
		lamp.material_override = _mat
	_setup.call_deferred()

func _setup() -> void:
	_lift = get_node_or_null(lift_path)
	_refresh()

func get_prompt() -> String:
	if _lift == null:
		return prompt_text
	if car_dir != 0:
		var dest: String = _lift.next_stop_name(car_dir)
		if dest == "":
			return "Lift %s (already at the %s)" % ["up" if car_dir > 0 else "down", "top" if car_dir > 0 else "bottom"]
		return "Lift %s to %s" % ["up" if car_dir > 0 else "down", dest]
	return "Call the lift"

func _on_interact(by: Node) -> void:
	if _lift == null:
		return
	var msg: String = _lift.step(car_dir) if car_dir != 0 else _lift.send_to(stop)
	if by.has_method("show_toast"):
		by.show_toast(msg)
	var b := find_child("Button", true, false) as Node3D
	if b:
		var tw := create_tween()
		tw.tween_property(b, "position:z", b.position.z - 0.025, 0.08)
		tw.tween_property(b, "position:z", b.position.z, 0.15)

func _process(delta: float) -> void:
	_t += delta
	_refresh()

func _refresh() -> void:
	var g := grid()
	var powered: bool = g == null or g.powered
	if not powered:
		_mat.emission = Color(0.55, 0.12, 0.55)
		_mat.emission_energy_multiplier = 0.5 + 0.4 * float(sin(_t * 2.0) > 0.6)
	elif _lift and _lift.moving:
		_mat.emission = Color(0.85, 0.95, 1.0)
		_mat.emission_energy_multiplier = 6.0 if fmod(_t, 0.5) < 0.25 else 0.6
	else:
		_mat.emission = Color(0.3, 0.75, 1.0)
		_mat.emission_energy_multiplier = 4.0
