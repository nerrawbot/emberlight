extends Node3D
## v19: the signal climb up the Peak's radio mast (surface.tscn). Four bands, four stations: each band's puzzle tunes
## one value of the relay (power, frequency, bearing, gain) and its interlock lets go of the next stage of the climb.
## The cabin's console does the final tuning (Ember's broadcast), which opens the way to the top for the Pennon.
## The gated route pieces live in assets/level/peak.glb (art_src/v10_peak.py GATE_PARTS, modelled walkable, origin on
## the hinge); `gates` holds their closed poses (build_surface.gd copies them from peak.json). SENTINEL-11, the station
## keeper, stands on band 1 (built here at runtime, like cable_station.gd builds its car).
## Puzzles call tune(stage). GameState: KEYS[stage - 1] per band, "mast_final" for the cabin.

signal tuned(stage: int)

const GameState := preload("res://scripts/game_state.gd")
const KEYS := ["mast_power", "mast_freq", "mast_bearing", "mast_gain"]
const NAMES := ["POWER", "FREQUENCY", "BEARING", "GAIN"]
## what SENTINEL-11 says over the band speakers as each station reports in ({braces} = corrupted)
const BARKS := [
	"Band one reports. Power on the feed. The stair lets go. Band two has drifted: its call sign blinks from the end of the cabin's boom. The west side sees it.",
	"Band two in tune. The winch is paying out. Band three's dish looks at nothing: aim it at the far side. Its sight will show you. Follow the cable line {out}.",
	"Bearing locked. The dish hears the far side now. Flaps are coming up. Band four: the waveguide is starved. Three valves feed it, and each robs one needle to feed another. All three needles in the {green}.",
	"Gain at full. The relay is awake. Climb to the cabin. Sit at the console. {Listen}.",
]

## [{node, stage, kind ("turn" | "lift"), origin, axis, angle, offset, nocol}] in Godot coords (from peak.json)
@export var gates: Array = []
@export var sentinel_pos := Vector3.ZERO
@export var sentinel_look := Vector3.ZERO
@export var peak_path := NodePath("../Peak")

const KIT := "res://assets/level/mast_signal.glb"

var sentinel: Node3D
var kit: Node3D
var _parts := {}          # stage -> Array of {node, open, closed, nocol}

func _ready() -> void:
	add_to_group("mast_signal")
	var peak := get_node_or_null(peak_path)
	if peak == null:
		push_warning("mast_signal: no Peak at %s" % peak_path)
		return
	for g: Dictionary in gates:
		var n := peak.find_child(String(g["node"]), true, false) as Node3D
		if n == null:
			push_warning("mast_signal: no gate part %s in the Peak" % g["node"])
			continue
		var open_t := n.global_transform
		var closed: Transform3D
		if g["kind"] == "turn":
			closed = Transform3D(Basis(Vector3(g["axis"]).normalized(), float(g["angle"])) * open_t.basis, open_t.origin)
		else:
			closed = open_t.translated(Vector3(g["offset"]))
		var st := int(g["stage"])
		if not _parts.has(st):
			_parts[st] = []
		_parts[st].append({"node": n, "open": open_t, "closed": closed, "nocol": bool(g["nocol"])})
	for st: int in _parts:
		_pose(st, 1.0 if is_tuned(st) else 0.0)
	_build_sentinel()
	_cabin_banner()
	# the stations' kit (art_src/v19_mast_signal.py): cabinets, plugs, levers... and a controller per band
	kit = (load(KIT) as PackedScene).instantiate() as Node3D
	kit.name = "Kit"
	add_child(kit)
	for b in [["Band1Power", "band1_power"], ["Band2Freq", "band2_freq"], ["Band3Bearing", "band3_bearing"], ["Band4Gain", "band4_gain"], ["CabinConsole", "cabin_console"], ["Summit", "summit"]]:
		var n := Node.new()
		n.name = b[0]
		n.set_script(load("res://scripts/mast/%s.gd" % b[1]))
		add_child(n)
		n.call("setup", self, kit)

## The cabin: stepping in says where you are (the zone build_surface.gd puts at the door used to end the demo here).
func _cabin_banner() -> void:
	var z := get_parent().get_node_or_null("MastCabin")
	if z:
		z.set("message", "THE RELAY CABIN\nthe top of the Heretic's mast")

## The final tuning in the cabin (scripts/mast/cabin_console.gd): Ember's broadcast locked.
func is_final() -> bool:
	return bool(GameState.get_value("mast_final", false))

func final_tune() -> void:
	if is_final():
		return
	GameState.set_value("mast_final", true)
	var p := get_tree().get_first_node_in_group("player")
	if p and p.has_method("show_banner"):
		p.call("show_banner", "EMBERLIGHT\nsignal locked", 3.5)
	tuned.emit(5)

func is_tuned(stage: int) -> bool:
	return stage >= 1 and stage <= KEYS.size() and bool(GameState.get_value(KEYS[stage - 1], false))

## How many bands are tuned, counting up from band 1.
func progress() -> int:
	var n := 0
	while n < KEYS.size() and is_tuned(n + 1):
		n += 1
	return n

## A band's station reports in: set its key, open its stage (animated unless `instant`), the keeper says so.
func tune(stage: int, instant := false) -> void:
	if stage < 1 or stage > KEYS.size() or is_tuned(stage):
		return
	GameState.set_value(KEYS[stage - 1], true)
	if instant:
		_pose(stage, 1.0)
	else:
		_open_anim(stage)
		var p := get_tree().get_first_node_in_group("player")
		if p and p.has_method("show_banner"):
			p.call("show_banner", "%s  —  TUNED" % NAMES[stage - 1], 3.0)
		if p and p.has_method("show_toast"):
			get_tree().create_timer(1.6).timeout.connect(func(): p.call("show_toast", "SENTINEL-11: " + BARKS[stage - 1], 5.0))
	tuned.emit(stage)

## t = 0 closed .. 1 open, for every part of a stage. Collision of `nocol` parts only exists once fully open.
func _pose(stage: int, t: float) -> void:
	for p: Dictionary in _parts.get(stage, []):
		var n: Node3D = p["node"]
		n.global_transform = (p["closed"] as Transform3D).interpolate_with(p["open"], t)
		if p["nocol"]:
			for cs in n.find_children("*", "CollisionShape3D", true, false):
				(cs as CollisionShape3D).set_deferred("disabled", t < 1.0)

func _open_anim(stage: int) -> void:
	var parts: Array = _parts.get(stage, [])
	match stage:
		1:      # the fire-escape section: a jolt as the brake lets go, then down under its counterweight, a bounce
			_swing(parts, [[0.06, 0.25], [0.04, 0.5], [1.0, 2.6], [0.96, 0.18], [1.0, 0.3]], 0.4)
		2:      # the winch pays out: steady, a hitch halfway
			_swing(parts, [[0.45, 2.2], [0.43, 0.3], [1.0, 2.0]], 0.6)
		3:      # the flaps swing up one after another
			for i in parts.size():
				_swing([parts[i]], [[1.05, 0.9], [1.0, 0.25]], 0.3 + 0.45 * i)
		4:      # the plate falls across the gap and slams
			_swing(parts, [[0.1, 0.6], [1.0, 1.4], [0.97, 0.12], [1.0, 0.2]], 0.5)
		_:
			_swing(parts, [[1.0, 1.5]], 0.0)

## Tween parts through keyframes [[t, seconds], ...] after a delay. (Collision of nocol parts comes on at the end.)
func _swing(parts: Array, keys: Array, delay: float) -> void:
	if parts.is_empty():
		return
	var state := [0.0]
	var apply := func(t: float) -> void:
		state[0] = t
		for p: Dictionary in parts:
			(p["node"] as Node3D).global_transform = (p["closed"] as Transform3D).interpolate_with(p["open"], t)
	var tw := create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tw.tween_interval(delay)
	var from := 0.0
	for k: Array in keys:
		var to := float(k[0])
		tw.tween_method(apply, from, to, float(k[1])).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		from = to
	tw.tween_callback(func() -> void:
		for p: Dictionary in parts:
			if p["nocol"]:
				for cs in (p["node"] as Node3D).find_children("*", "CollisionShape3D", true, false):
					(cs as CollisionShape3D).disabled = false)

func _build_sentinel() -> void:
	if sentinel_pos == Vector3.ZERO:
		return
	sentinel = Node3D.new()
	sentinel.name = "Sentinel11"
	sentinel.set_script(load("res://scripts/creatures/watcher.gd"))
	var m := (load("res://assets/creatures/watcher.glb") as PackedScene).instantiate()
	m.name = "Model"
	sentinel.add_child(m)
	var talk := Area3D.new()
	talk.name = "Talk"
	talk.set_script(load("res://scripts/watcher_talk.gd"))
	talk.set("tree_id", "sentinel_11")
	talk.set("speaker", "SENTINEL-11")
	var cs := CollisionShape3D.new()
	var bx := BoxShape3D.new()
	bx.size = Vector3(1.3, 1.4, 1.3)
	cs.shape = bx
	cs.position = Vector3(0, 0.5, 0)
	talk.add_child(cs)
	sentinel.add_child(talk)
	add_child(sentinel)
	sentinel.global_position = sentinel_pos
	var d := sentinel_look - sentinel_pos
	sentinel.rotation.y = atan2(-d.x, -d.z)         # the model faces -Z
