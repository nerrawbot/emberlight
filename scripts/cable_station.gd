extends Node3D
## v15: the cable car station on the Peak island (assets/level/cable_station.glb + assets/props/cable_car.glb,
## art_src/v15_cable_station.py). The near station works; the far terminal is dead. [E] on the call panel: the
## bullwheel hauls, the car lurches out along its rail, the brake bites with a clunk and it swings back - and the far
## lamp blinks and goes dark. GameState "cable_far_fixed" (set by the repair quest in the next area, later) makes the
## far terminal answer; the ride itself isn't wired up yet. "FromCableCar" (group spawn_point) stands in the car,
## facing the door, for arriving by the return trip.

const GameState := preload("res://scripts/game_state.gd")
const DeathFx := preload("res://scripts/creatures/death_fx.gd")
const STATION := "res://assets/level/cable_station.glb"
const CAR := "res://assets/props/cable_car.glb"
const FLOOR := -4.56          # car floor top below the grip (v15 build_car fz): flush with the deck

var car: AnimatableBody3D
var _wheel: Node3D
var _wheel_basis := Basis.IDENTITY
var _dock := Transform3D.IDENTITY
var _far_light: OmniLight3D
var _far_mat: StandardMaterial3D
var _t := -1.0                # time since the panel was pulled (-1 = idle)
var _haul := 0.0              # car's pull out along the line (m)
var _haul_v := 0.0
var _swing := 0.0             # car sway about its grip (rad)
var _swing_v := 0.0
var _clunked := false

func _ready() -> void:
	var st := (load(STATION) as PackedScene).instantiate() as Node3D
	st.name = "Station"
	add_child(st)
	_wheel = st.find_child("Bullwheel", true, false) as Node3D
	if _wheel:
		_wheel_basis = _wheel.basis
	var dock := st.find_child("CarDock", true, false) as Node3D
	_dock = dock.global_transform if dock else Transform3D.IDENTITY
	_build_car()
	for n in ["Lamp1", "Lamp2"]:
		var m := st.find_child(n, true, false) as Node3D
		if m:
			var l := OmniLight3D.new()
			l.light_color = Color(1.0, 0.78, 0.55)
			l.light_energy = 1.6
			l.omni_range = 9.0
			l.light_volumetric_fog_energy = 0.5
			l.shadow_enabled = false
			m.add_child(l)
	var fl := st.find_child("FarLamp", true, false) as Node3D
	if fl:
		_far_light = OmniLight3D.new()
		_far_light.light_color = Color(1.0, 0.12, 0.06)
		_far_light.omni_range = 1.6
		_far_light.light_energy = 0.0
		_far_light.shadow_enabled = false
		fl.add_child(_far_light)
		var bulb := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.065
		sm.height = 0.13
		_far_mat = StandardMaterial3D.new()
		_far_mat.albedo_color = Color(0.25, 0.04, 0.03)
		_far_mat.emission_enabled = true
		_far_mat.emission = Color(1.0, 0.1, 0.05)
		_far_mat.emission_energy_multiplier = 0.0
		sm.material = _far_mat
		bulb.mesh = sm
		fl.add_child(bulb)
	var ps := st.find_child("PanelSpot", true, false) as Node3D
	if ps:
		var panel := Area3D.new()
		panel.name = "CallPanel"
		panel.set_script(load("res://scripts/interactable.gd"))
		panel.set("prompt_text", "Call the far terminal")
		var cs := CollisionShape3D.new()
		var bx := BoxShape3D.new()
		bx.size = Vector3(1.0, 1.3, 1.3)
		cs.shape = bx
		panel.add_child(cs)
		ps.add_child(panel)
		panel.connect("interacted", _on_panel)
	var sp := st.find_child("FromCableCar", true, false) as Node3D
	if sp:
		var mk := Marker3D.new()
		mk.name = "FromCableCar"
		mk.add_to_group("spawn_point", true)
		add_child(mk)
		mk.global_transform = sp.global_transform

## The car hangs from its grip at CarDock: a moving body you can stand in (floor, walls, door gap on -X, roof).
func _build_car() -> void:
	car = AnimatableBody3D.new()
	car.name = "CableCar"
	car.sync_to_physics = true          # it's moved by its own transform, so riders get its motion
	add_child(car)
	car.global_transform = _dock
	var m := (load(CAR) as PackedScene).instantiate() as Node3D
	car.add_child(m)
	var h := 2.3
	for b in [[Vector3(0, FLOOR - 0.05, 0), Vector3(2.2, 0.1, 2.6)],
			[Vector3(1.06, FLOOR + h * 0.5, 0), Vector3(0.08, h, 2.6)],
			[Vector3(0, FLOOR + h * 0.5, 1.22), Vector3(2.2, h, 0.08)],
			[Vector3(0, FLOOR + h * 0.5, -1.22), Vector3(2.2, h, 0.08)],
			[Vector3(-1.06, FLOOR + h * 0.5, 0.925), Vector3(0.08, h, 0.75)],
			[Vector3(-1.06, FLOOR + h * 0.5, -0.925), Vector3(0.08, h, 0.75)],
			[Vector3(0, FLOOR + h + 0.06, 0), Vector3(2.36, 0.12, 2.76)]]:
		var cs := CollisionShape3D.new()
		var bx := BoxShape3D.new()
		bx.size = b[1]
		cs.shape = bx
		cs.position = b[0]
		car.add_child(cs)

func _on_panel(by: Node) -> void:
	if GameState.get_value("cable_far_fixed", false):
		if by.has_method("show_toast"):
			by.show_toast("The far terminal answers.   (The return trip isn't wired up yet.)", 3.0)
		return
	if _t >= 0.0:
		return
	_t = 0.0
	_clunked = false

## The haul: the rope pulls the car ~0.6 m out along its rail, the brake bites (clunk) and lets it settle back.
func _haul_target(t: float) -> float:
	if t < 0.15:
		return 0.0
	if t < 0.9:
		return 0.6 * smoothstep(0.15, 0.9, t)
	if t < 1.6:
		return 0.42
	return 0.42 * (1.0 - smoothstep(1.6, 3.4, t))

func _physics_process(delta: float) -> void:
	if _t < 0.0:
		return
	_t += delta
	var acc := 60.0 * (_haul_target(_t) - _haul) - (14.0 if _t > 0.9 and _t < 1.1 else 9.0) * _haul_v
	_haul_v += acc * delta
	_haul += _haul_v * delta
	# the cabin lags behind its grip and swings (pendulum ~4.4 m)
	_swing_v += (-(9.8 / 4.4) * _swing - 0.7 * _swing_v - acc / 4.4) * delta
	_swing += _swing_v * delta
	car.global_transform = _dock * Transform3D(Basis(Vector3.RIGHT, _swing), Vector3(0, 0, -_haul))
	if _wheel:
		_wheel.basis = _wheel_basis * Basis(Vector3.UP, -_haul / 2.0)
	# the far terminal's lamp: three red blinks, then dark
	var lit := _t > 0.3 and _t < 1.8 and fmod(_t - 0.3, 0.5) < 0.25
	if _far_light:
		_far_light.light_energy = 1.2 if lit else 0.0
		_far_mat.emission_energy_multiplier = 5.0 if lit else 0.0
	if not _clunked and _t >= 0.9:
		_clunked = true
		_clunk()
	if _t > 7.0 and absf(_swing) < 0.002 and absf(_haul) < 0.002:
		_t = -1.0
		_haul = 0.0
		_haul_v = 0.0
		_swing = 0.0
		_swing_v = 0.0
		car.global_transform = _dock

func _clunk() -> void:
	DeathFx.sparks(self, car.global_position + Vector3.UP * 0.3, Color(1.0, 0.75, 0.4), 22, 5.0)
	if _wheel:
		DeathFx.sparks(self, _wheel.global_position, Color(1.0, 0.7, 0.35), 14, 4.0)
	var p := get_tree().get_first_node_in_group("player") as Node3D
	if p == null:
		return
	var d := p.global_position.distance_to(car.global_position)
	if p.has_method("shake") and d < 40.0:
		p.call("shake", clampf(0.5 - d / 80.0, 0.1, 0.45))
	if d < 20.0 and p.has_method("show_toast"):
		get_tree().create_timer(0.6).timeout.connect(func():
			if is_instance_valid(p):
				p.call("show_toast", "The rope hauls, the brake bites. The far terminal doesn't answer.", 3.5))
