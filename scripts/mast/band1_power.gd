extends Node
## v19, mast band 1: POWER (the tutorial). A dead junction cabinet by the band's NE corner (art_src/v19_mast_signal.py,
## assets/level/mast_signal.glb). Three loose coupler plugs lie round the band; the wiring diagram inside the cabinet's
## open door says which stencilled socket each colour goes in (red -> triangle, amber -> circle, teal -> square).
## [E] on a plug carries it (one at a time: taking another swaps them); [E] on a socket seats it: right = it clunks
## home and its lamp lights, wrong = sparks and it is spat out onto the floor. With all three lit, the main breaker
## latches: the feed comes on and mast_signal.tune(1) lowers the stair.

const MastUse := preload("res://scripts/mast/mast_use.gd")
const SOCKET_SHAPES := ["circle", "square", "triangle"]
const ANSWER := {"red": 2, "amber": 0, "teal": 1}
const LEVER_ON := deg_to_rad(153.0)          # about the lever's local Z (arm hangs down OFF, points up ON)

var sig: Node
var plugs := {}                 # colour -> Node3D
var plug_use := {}              # colour -> Area3D
var sockets: Array[Node3D] = []
var lamps: Array[MeshInstance3D] = []
var lever: Node3D
var seated := {}                # socket index -> colour
var carrying := ""
var solved := false
var _held: MeshInstance3D
var _lever_off := Transform3D.IDENTITY
var _lever_use: Area3D
var _feed: OmniLight3D
var _lamp_on: StandardMaterial3D
var _busy := false

func setup(signal_node: Node, kit: Node3D) -> void:
	sig = signal_node
	for c in ANSWER:
		var p := kit.find_child("B1Plug_" + c, true, false) as Node3D
		if p:
			plugs[c] = p
	for i in 3:
		sockets.append(kit.find_child("B1Socket_%d" % i, true, false) as Node3D)
		lamps.append(kit.find_child("B1Lamp_%d" % i, true, false) as MeshInstance3D)
	lever = kit.find_child("B1Lever", true, false) as Node3D
	var fl := kit.find_child("B1FeedLamp", true, false) as Node3D
	if plugs.size() < 3 or sockets.has(null) or lamps.has(null) or lever == null or fl == null:
		push_warning("band1_power: kit parts missing")
		return
	_lever_off = lever.transform
	_lamp_on = StandardMaterial3D.new()
	_lamp_on.albedo_color = Color(0.5, 0.42, 0.15)
	_lamp_on.emission_enabled = true
	_lamp_on.emission = Color(1.0, 0.72, 0.3)
	_lamp_on.emission_energy_multiplier = 4.0
	_feed = OmniLight3D.new()
	_feed.light_color = Color(1.0, 0.78, 0.5)
	_feed.omni_range = 7.0
	_feed.light_energy = 0.0
	_feed.shadow_enabled = false
	fl.add_child(_feed)
	sig.connect("tuned", func(st: int) -> void:
		if st == 1 and not solved:
			_set_solved())      # tuned some other way (the debug console's `tune`)
	if sig.call("is_tuned", 1):
		_set_solved()
		return
	for c in plugs:
		var col: String = c
		plug_use[c] = MastUse.make(plugs[c], "Use", Vector3(0.32, 0, 0), Vector3.ZERO,
			func() -> String: return "Take the %s coupler" % col if carrying == "" else "Swap for the %s coupler" % col,
			func(_by: Node) -> void: _take(col))
	for i in 3:
		var k: int = i
		MastUse.make(sockets[i], "Use", Vector3(0.3, 0.3, 0.3), Vector3(0.12, 0, 0),
			func() -> String: return _socket_prompt(k),
			func(_by: Node) -> void: _use_socket(k))
	_lever_use = MastUse.make(lever, "Use", Vector3(0.35, 0.6, 0.4), Vector3(0.05, -0.2, 0),
		func() -> String: return "" if solved else "Throw the main breaker",
		func(_by: Node) -> void: _throw())

func _say(text: String, hold := 2.6) -> void:
	var p := get_tree().get_first_node_in_group("player")
	if p and p.has_method("show_toast"):
		p.call("show_toast", text, hold)

func _socket_prompt(i: int) -> String:
	if solved or seated.has(i):
		return ""
	if carrying != "":
		return "Seat the %s coupler (%s socket)" % [carrying, SOCKET_SHAPES[i]]
	return "Empty socket (%s)" % SOCKET_SHAPES[i]

## Pick a plug up (putting down the one in hand where this one lay).
func _take(c: String) -> void:
	if _busy:
		return
	var p: Node3D = plugs[c]
	if carrying != "":
		var old: Node3D = plugs[carrying]
		old.global_transform = p.global_transform
		_show_plug(carrying, true)
	carrying = c
	_show_plug(c, false)
	_hold(c)
	_say("You take the %s coupler." % c)

func _show_plug(c: String, on: bool) -> void:
	(plugs[c] as Node3D).visible = on
	(plug_use[c] as Area3D).call("set_enabled", on)

## A copy of the plug in the lower right of the view while it is carried.
func _hold(c: String) -> void:
	if _held:
		_held.queue_free()
		_held = null
	if c == "":
		return
	var p := get_tree().get_first_node_in_group("player")
	var cam: Camera3D = p.get("camera") if p else null
	var src := plugs[c] as MeshInstance3D
	if cam == null or src == null:
		return
	_held = MeshInstance3D.new()
	_held.mesh = src.mesh
	for s in src.get_surface_override_material_count():
		_held.set_surface_override_material(s, src.get_surface_override_material(s))
	_held.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_held.layers = 2
	cam.add_child(_held)
	_held.position = Vector3(0.24, -0.2, -0.42)
	_held.rotation = Vector3(0.3, deg_to_rad(105.0), 0.15)

func _use_socket(i: int) -> void:
	if _busy or solved or seated.has(i):
		return
	if carrying == "":
		_say("It needs a coupler.")
		return
	var c := carrying
	carrying = ""
	_hold("")
	var p: Node3D = plugs[c]
	var seat := sockets[i].global_transform * Transform3D(Basis(Vector3.UP, PI), Vector3(0.17, 0, 0))
	p.global_transform = seat.translated_local(Vector3(-0.12, 0, 0))     # pushed in from a little way out
	p.visible = true
	_busy = true
	var tw := create_tween()
	tw.tween_property(p, "global_transform", seat, 0.18).set_ease(Tween.EASE_IN)
	if ANSWER[c] == i:
		seated[i] = c
		tw.tween_callback(func() -> void:
			_busy = false
			lamps[i].material_override = _lamp_on
			if seated.size() == 3:
				_say("All three lamps burn. The breaker should hold now.", 3.0)
			else:
				_say("It seats with a clunk. The %s lamp warms." % SOCKET_SHAPES[i]))
	else:
		tw.tween_callback(func() -> void:
			_spark(sockets[i].global_position + sockets[i].global_basis.x * 0.1)
			_say("Sparks. It spits the %s coupler back out." % c))
		var drop := _floor_spot(sockets[i].global_position + sockets[i].global_basis.x * 0.75)
		var land := Transform3D(Basis(Vector3.UP, randf() * TAU) * Basis(Vector3.RIGHT, 0.0), drop + Vector3.UP * 0.075)
		tw.tween_interval(0.12)
		tw.tween_property(p, "global_transform", land, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_callback(func() -> void:
			_busy = false
			(plug_use[c] as Area3D).call("set_enabled", true))

func _floor_spot(at: Vector3) -> Vector3:
	var space := get_viewport().world_3d.direct_space_state
	var q := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 0.5, at + Vector3.DOWN * 3.0, 1)
	var hit := space.intersect_ray(q)
	return hit["position"] if not hit.is_empty() else at + Vector3.DOWN * 1.1

func _spark(at: Vector3) -> void:
	var l := OmniLight3D.new()
	l.light_color = Color(0.7, 0.85, 1.0)
	l.omni_range = 3.5
	l.light_energy = 6.0
	l.shadow_enabled = false
	add_child(l)
	l.global_position = at
	var tw := l.create_tween()
	for k in 4:
		tw.tween_property(l, "light_energy", 0.5, 0.05)
		tw.tween_property(l, "light_energy", 5.0 - k, 0.04)
	tw.tween_property(l, "light_energy", 0.0, 0.15)
	tw.tween_callback(l.queue_free)
	var ps := CPUParticles3D.new()
	ps.one_shot = true
	ps.amount = 28
	ps.lifetime = 0.6
	ps.explosiveness = 0.95
	ps.direction = Vector3(1, 0.4, 0)
	ps.spread = 50.0
	ps.initial_velocity_min = 1.5
	ps.initial_velocity_max = 3.5
	ps.gravity = Vector3(0, -9.8, 0)
	var sm := SphereMesh.new()
	sm.radius = 0.012
	sm.height = 0.024
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.8, 0.9, 1.0)
	sm.material = mat
	ps.mesh = sm
	add_child(ps)
	ps.global_position = at
	ps.global_basis = sockets[0].global_basis
	ps.emitting = true
	get_tree().create_timer(1.2).timeout.connect(ps.queue_free)

func _throw() -> void:
	if _busy or solved:
		return
	_busy = true
	var on := _lever_off * Transform3D(Basis(Vector3(0, 0, 1), LEVER_ON), Vector3.ZERO)
	var part := _lever_off * Transform3D(Basis(Vector3(0, 0, 1), LEVER_ON * 0.45), Vector3.ZERO)
	var tw := create_tween()
	if seated.size() < 3:
		tw.tween_property(lever, "transform", part, 0.35).set_trans(Tween.TRANS_SINE)
		tw.tween_property(lever, "transform", _lever_off, 0.3).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		tw.tween_callback(func() -> void:
			_busy = false
			_say("The breaker won't latch. The feed is incomplete: %d of 3 couplers seated." % seated.size(), 3.0))
		return
	tw.tween_property(lever, "transform", on, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void:
		solved = true
		_busy = false
		_lever_use.call("set_enabled", false)
		_power_up()
		sig.call("tune", 1))

## The feed comes on: the lamps flicker up together, the cabinet's work lamp lights.
func _power_up() -> void:
	var tw := create_tween()
	for k in 3:
		tw.tween_callback(func() -> void: _feed.light_energy = 1.6)
		tw.tween_interval(0.07 + 0.05 * k)
		tw.tween_callback(func() -> void: _feed.light_energy = 0.2)
		tw.tween_interval(0.1)
	tw.tween_property(_feed, "light_energy", 1.4, 0.4)
	_lamp_on.emission_energy_multiplier = 6.0

## Already tuned on an earlier visit: plugs home, lamps lit, lever up, feed on.
func _set_solved() -> void:
	solved = true
	carrying = ""
	_hold("")
	for a in plug_use.values():
		(a as Area3D).call("set_enabled", false)
	if _lever_use:
		_lever_use.call("set_enabled", false)
	for c: String in ANSWER:
		var i: int = ANSWER[c]
		seated[i] = c
		(plugs[c] as Node3D).visible = true
		(plugs[c] as Node3D).global_transform = sockets[i].global_transform * Transform3D(Basis(Vector3.UP, PI), Vector3(0.17, 0, 0))
		lamps[i].material_override = _lamp_on
	lever.transform = _lever_off * Transform3D(Basis(Vector3(0, 0, 1), LEVER_ON), Vector3.ZERO)
	_feed.light_energy = 1.4
