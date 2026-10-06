extends AnimatableBody3D
## The lift car at the top of the shaft in surface.tscn (the cavern's lift.gd runs the rest of the shaft).
## Arriving from the cavern mid-ride (GameState "car_ride"), it carries on up into the daylight and stops at the
## landing. ride_down() (the car's Down button) sinks it back into the shaft and hands over to the cavern.

const GameState := preload("res://scripts/game_state.gd")

@export var top_y := 34.3
@export var speed := 3.2
@export_file("*.tscn") var down_scene := "res://scenes/main.tscn"
@export var handoff_y := 30.6        # where the cavern's lift takes over on the way down
@export var down_respawn := "OldDeckStart"
@export var cable_path: NodePath
@export var pulley_y := 41.6

var moving := false
var _cable: Node3D

func _physics_process(_delta: float) -> void:
	if _cable:     # hoist rope from the car roof to the sheave
		var bottom := position.y + 3.25
		_cable.scale.y = maxf(0.01, pulley_y - bottom)
		_cable.position.y = (pulley_y + bottom) * 0.5

func _ready() -> void:
	_cable = get_node_or_null(cable_path)
	var ride: Variant = GameState.take("car_ride", null)
	if ride is Dictionary:
		position.y = ride.get("y", top_y)
		_arrive.call_deferred(ride)

func _arrive(ride: Dictionary) -> void:
	var p := get_tree().get_first_node_in_group("player")
	if p and p.has_method("board_car"):
		p.board_car(self, ride)
	moving = true
	var t := (top_y - position.y) / speed * 1.35
	var tw := create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tw.tween_property(self, "position:y", top_y, maxf(0.2, t)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void: moving = false)

func ride_down(by: Node) -> void:
	if moving:
		return
	moving = true
	var tw := create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tw.tween_property(self, "position:y", handoff_y - 2.0, (top_y - handoff_y + 2.0) / speed * 1.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	while position.y > handoff_y:
		await get_tree().physics_frame
	if by.has_method("is_in_car") and by.is_in_car(self):
		by.change_scene_by_lift(down_scene, self, {"target": 1, "respawn": down_respawn})
	else:     # stepped off as it left: bring it back up
		tw.kill()
		create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS).tween_property(self, "position:y", top_y, 1.5)
		moving = false
