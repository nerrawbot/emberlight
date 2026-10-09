extends Node
## v19, the mast's summit: the way up from the cabin balcony to the very top, and the launch into the high wind
## (art_src/v19_mast_signal.py summit()). The caged ladder on the cabin's south wall (L1) stays shut until the final
## tuning (mast_final); then ladders up the upper storey (L2), the top block (L3), the antenna (L4, into the crow's
## nest) and the spike's step-irons (L5) to the perch under the tip beacon. From then on the high wind streams off
## the top towards Ember. Glide off the summit heading roughly at Ember's lamps (within LAUNCH_CONE) with the Pennon
## and the wind takes you: fade out, scenes/ember.tscn at FromHighWind (the transit cutscene comes later). Any other
## glide is just a glide. Checkpoints on the roof deck and in the crow's nest.

const LAUNCH_CONE := deg_to_rad(40.0)
const LAUNCH_RANGE := 90.0          # m from the perch
const LAUNCH_DROP := 45.0           # how far below the perch the wind still has you
const NEXT_SCENE := "res://scenes/ember.tscn"
const GameState := preload("res://scripts/game_state.gd")

var sig: Node
var perch: Node3D
var ember: Node3D
var _cage: Node3D
var _cage_rest := Transform3D.IDENTITY
var _lad1: Area3D
var _wind: CPUParticles3D
var _leaving := false
var _said_perch := false
var _player: CharacterBody3D

func setup(signal_node: Node, kit: Node3D) -> void:
	sig = signal_node
	perch = kit.find_child("B6Perch", true, false) as Node3D
	ember = kit.find_child("B3Ember", true, false) as Node3D
	_cage = kit.find_child("B6Cage", true, false) as Node3D
	if perch == null or ember == null or _cage == null:
		push_warning("summit: kit parts missing")
		set_physics_process(false)
		return
	_cage_rest = _cage.transform
	for k in range(1, 6):
		var bot := kit.find_child("B6Lad%d_bot" % k, true, false) as Node3D
		var top := kit.find_child("B6Lad%d_top" % k, true, false) as Node3D
		if bot and top:
			var a := _ladder("Ladder_%d" % k, bot, top)
			if k == 1:
				_lad1 = a
	for c in [["CP_Roof", "B6Roof"], ["CP_Nest", "B6Nest"]]:
		var m := kit.find_child(c[1], true, false) as Node3D
		if m:
			_checkpoint(c[0], m)
	_build_wind()
	sig.connect("tuned", func(st: int) -> void:
		if st == 5:
			_open(true))
	_open(sig.call("is_final"), true)

## A climbable volume like build_surface.gd's mast ladders: the climber stands on the normal side, steps forward at
## the top. The empties' local +Y (Blender) is the normal: Godot -Z.
func _ladder(n: String, bot: Node3D, top: Node3D) -> Area3D:
	var nrm := -bot.global_basis.z
	nrm.y = 0.0
	nrm = nrm.normalized()
	var z0 := bot.global_position.y
	var z1 := top.global_position.y + 0.8
	var a := Area3D.new()
	a.name = n
	a.set_script(load("res://scripts/ladder.gd"))
	a.set("climb_normal", nrm)
	var cs := CollisionShape3D.new()
	cs.name = "CollisionShape3D"
	var bx := BoxShape3D.new()
	bx.size = Vector3(1.2, z1 - z0, 0.95)
	cs.shape = bx
	a.add_child(cs)
	add_child(a)
	a.global_position = Vector3(bot.global_position.x, (z0 + z1) * 0.5, bot.global_position.z) + nrm * 0.22
	a.rotation.y = atan2(nrm.x, nrm.z)
	return a

func _checkpoint(n: String, at: Node3D) -> void:
	var a := Area3D.new()
	a.name = n
	a.set_script(load("res://scripts/checkpoint.gd"))
	var cs := CollisionShape3D.new()
	var bx := BoxShape3D.new()
	bx.size = Vector3(2.4, 2.5, 2.4)
	cs.shape = bx
	cs.position = Vector3(0, 1.25, 0)
	a.add_child(cs)
	add_child(a)
	a.global_position = at.global_position + Vector3(0, 0.05, 0)
	var d := perch.global_position - at.global_position          # come round facing the way up
	a.rotation.y = atan2(-d.x, -d.z)

## The high wind: long pale streaks pouring off the top towards Ember (only once the relay is in tune).
func _build_wind() -> void:
	_wind = CPUParticles3D.new()
	_wind.name = "HighWind"
	_wind.amount = 70
	_wind.lifetime = 3.2
	_wind.preprocess = 3.0
	_wind.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_wind.emission_box_extents = Vector3(18, 9, 18)
	_wind.particle_flag_align_y = true
	_wind.gravity = Vector3.ZERO
	var to := ember.global_position - perch.global_position
	_wind.direction = Vector3(to.x, to.y * 0.15, to.z).normalized()
	_wind.spread = 6.0
	_wind.initial_velocity_min = 16.0
	_wind.initial_velocity_max = 26.0
	var bm := BoxMesh.new()
	bm.size = Vector3(0.025, 2.8, 0.025)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.48, 0.42, 0.6, 0.42)     # dusty violet: white streaks vanish against the pale haze
	m.disable_fog = true
	bm.material = m
	_wind.mesh = bm
	var g := Gradient.new()          # fade in and out along their life
	g.set_color(0, Color(1, 1, 1, 0))
	g.add_point(0.3, Color(1, 1, 1, 1))
	g.add_point(0.75, Color(1, 1, 1, 1))
	g.set_color(g.get_point_count() - 1, Color(1, 1, 1, 0))
	_wind.color_ramp = g
	m.vertex_color_use_as_albedo = true
	_wind.layers = 2                 # moving: keep it out of the shadow casters
	_wind.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_wind)
	_wind.global_position = perch.global_position + Vector3(0, -6, 0) - _wind.direction * 8.0
	_wind.emitting = false
	_wind.visible = false

func _open(on: bool, instant := false) -> void:
	if _lad1:
		for cs in _lad1.find_children("*", "CollisionShape3D", false, false):
			(cs as CollisionShape3D).set_deferred("disabled", not on)
	_wind.visible = on
	_wind.emitting = on
	var to := _cage_rest.translated(Vector3(0, 2.35, 0)) if on else _cage_rest
	if instant:
		_cage.transform = to
	else:
		var tw := create_tween()
		tw.tween_interval(1.0)
		tw.tween_property(_cage, "transform", _cage_rest.translated(Vector3(0, 0.08, 0)), 0.2)      # the padlock gives
		tw.tween_property(_cage, "transform", to, 2.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

## Is a glide at `pos` with velocity `vel` heading into the high wind?
func into_the_wind(pos: Vector3, vel: Vector3) -> bool:
	if pos.distance_to(perch.global_position) > LAUNCH_RANGE or pos.y < perch.global_position.y - LAUNCH_DROP:
		return false
	var h := Vector2(vel.x, vel.z)
	if h.length() < 2.5:
		return false
	var e := Vector2(ember.global_position.x - pos.x, ember.global_position.z - pos.z)
	return h.angle_to(e) <= LAUNCH_CONE and h.angle_to(e) >= -LAUNCH_CONE

func _physics_process(_delta: float) -> void:
	if _leaving or not sig.call("is_final"):
		return
	if _player == null:
		_player = get_tree().get_first_node_in_group("player") as CharacterBody3D
		if _player == null:
			return
	var at := _player.global_position
	if not _said_perch and at.distance_to(perch.global_position) < 2.5:
		_said_perch = true
		var t := "The high wind pours off the top, towards the lamps. Jump into it and open the Pennon." if _player.get("has_pennon") \
			else "The high wind tugs at you. Without wings it's only a very long fall. (The hall below the mast.)"
		_player.call("show_toast", t, 4.5)
	if bool(_player.get("gliding")) and into_the_wind(at, _player.velocity):
		_leave()

## The wind takes you. (The transit cutscene goes here later.)
func _leave() -> void:
	_leaving = true
	var p := _player
	p.set("input_enabled", false)
	if p.has_method("show_banner"):
		p.call("show_banner", "THE HIGH WIND\nto Emberlight", 3.0)
	GameState.merge({"left_by_high_wind": true})
	if p.has_method("fade_out"):
		await p.call("fade_out", 2.0)
	get_tree().root.set_meta("spawn_point", "FromHighWind")
	get_tree().call_deferred("change_scene_to_file", NEXT_SCENE)
