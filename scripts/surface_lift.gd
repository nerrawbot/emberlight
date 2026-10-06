extends "res://scripts/interactable.gd"
## Car button in surface.tscn, where the lift car is parked at the top of the shaft.
## "Down" sinks the car (surface_car.gd ride_down); inside the shaft the cavern's lift takes over mid-ride.

@export var car_dir := -1
@export var car_path: NodePath

var _mat := StandardMaterial3D.new()

func _ready() -> void:
	super._ready()
	var lamp := find_child("Lamp", true, false) as MeshInstance3D
	_mat.albedo_color = Color(0.05, 0.05, 0.08)
	_mat.emission_enabled = true
	_mat.emission = Color(0.3, 0.75, 1.0)
	_mat.emission_energy_multiplier = 4.0
	if lamp:
		lamp.material_override = _mat

func get_prompt() -> String:
	return "Lift down to the upper deck" if car_dir < 0 else "Lift up (already at the top)"

func _on_interact(by: Node) -> void:
	var b := find_child("Button", true, false) as Node3D
	if b:
		var tw := create_tween()
		tw.tween_property(b, "position:z", b.position.z - 0.025, 0.08)
		tw.tween_property(b, "position:z", b.position.z, 0.15)
	if car_dir > 0:
		if by.has_method("show_toast"):
			by.show_toast("Already at the top landing.")
		return
	var car := get_node_or_null(car_path)
	if car == null or car.moving:
		return
	if by.has_method("show_toast"):
		by.show_toast("Lift on its way to the upper deck...")
	_mat.emission = Color(0.85, 0.95, 1.0)
	car.ride_down(by)
