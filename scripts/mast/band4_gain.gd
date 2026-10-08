extends Node
## v19, mast band 4: GAIN (properly tricky). Three attenuator valves on waveguide ducts round the band (north red,
## east amber, south teal) and a master board with the gain lever on the west strip (art_src/v19_mast_signal.py
## band4()). Three gain needles, 0..8; the green is 4. Every valve robs one needle to feed another (or feeds two), so
## they can't be set one at a time: each wheel turns both ways ([E] on its left or right half). A needle at its stop
## jams the wheel. All three in the green, then the lever: mast_signal.tune(4) drops the plate across the gap.
## Each station repeats the three gauges over its wheel; the master board has them big.

const MastUse := preload("res://scripts/mast/mast_use.gd")
## what a clockwise notch of each valve does to needles 1, 2, 3 (anticlockwise: the opposite)
const EFFECT := {"red": [1, -1, 0], "amber": [0, 1, 1], "teal": [1, 0, -1]}
const START := [7, 0, 1]        # = green + red x2, amber x-2, teal x1: solved by red x-2, amber x2, teal x-1
const GREEN := 4
const STEP_DEG := 20.0
const LEVER_ON := deg_to_rad(153.0)          # about the lever's local X

var sig: Node
var needles_val: Array = START.duplicate()
var solved := false
var _needles := {}              # station -> [Node3D x3]
var _needle_rest := {}          # Node3D -> Transform3D
var _wheels := {}               # colour -> Node3D
var _wheel_rest := {}
var _wheel_turns := {}          # colour -> int (notches, for the spin)
var _lever: Node3D
var _lever_rest := Transform3D.IDENTITY
var _uses: Array = []
var _busy := false

func setup(signal_node: Node, kit: Node3D) -> void:
	sig = signal_node
	for st in ["red", "amber", "teal", "master"]:
		var arr := []
		for i in 3:
			var n := kit.find_child("B4Needle_%s_%d" % [st, i + 1], true, false) as Node3D
			if n:
				arr.append(n)
				_needle_rest[n] = n.transform
		_needles[st] = arr
	for c in EFFECT:
		var w := kit.find_child("B4Wheel_" + c, true, false) as Node3D
		if w:
			_wheels[c] = w
			_wheel_rest[c] = w.transform
			_wheel_turns[c] = 0
	_lever = kit.find_child("B4Lever", true, false) as Node3D
	if _wheels.size() < 3 or _lever == null or (_needles["master"] as Array).size() < 3:
		push_warning("band4_gain: kit parts missing")
		return
	_lever_rest = _lever.transform
	sig.connect("tuned", func(st: int) -> void:
		if st == 4 and not solved:
			_set_solved())
	if sig.call("is_tuned", 4):
		_set_solved()
		return
	_show_needles(0.0)
	for c: String in EFFECT:
		var col := c
		# the viewer's right is the wheel's local -X: that half turns it clockwise
		for d in [1, -1]:
			var dir: int = d
			_uses.append(MastUse.make(_wheels[c], "Use%s" % ("CW" if d > 0 else "CCW"), Vector3(0.36, 0.8, 0.3),
				Vector3(-0.2 * dir, 0, 0),
				func() -> String: return "" if solved else "Turn the %s valve %s" % [col, "clockwise" if dir > 0 else "anticlockwise"],
				func(_by: Node) -> void: turn(col, dir)))
	_uses.append(MastUse.make(_lever, "Use", Vector3(0.4, 0.6, 0.4), Vector3(0, -0.2, -0.05),
		func() -> String: return "" if solved else "Throw the gain lever",
		func(_by: Node) -> void: _throw()))

func _say(text: String, hold := 2.6) -> void:
	var p := get_tree().get_first_node_in_group("player")
	if p and p.has_method("show_toast"):
		p.call("show_toast", text, hold)

## One notch of a valve: +1 clockwise, -1 anticlockwise. Jams (and says so) if a needle would pass a stop.
func turn(c: String, dir: int) -> bool:
	if _busy or solved:
		return false
	var e: Array = EFFECT[c]
	var to := needles_val.duplicate()
	for i in 3:
		to[i] = int(to[i]) + int(e[i]) * dir
		if to[i] < 0 or to[i] > 8:
			_jam(c, dir)
			return false
	needles_val = to
	_busy = true
	_wheel_turns[c] = int(_wheel_turns[c]) + dir
	var w: Node3D = _wheels[c]
	var tw := create_tween().set_parallel(true)
	tw.tween_property(w, "transform", (_wheel_rest[c] as Transform3D) * Transform3D(Basis(Vector3(0, 0, 1), deg_to_rad(40.0 * int(_wheel_turns[c]))), Vector3.ZERO), 0.35).set_trans(Tween.TRANS_SINE)
	_needle_tweens(tw, 0.55)
	tw.chain().tween_callback(func() -> void: _busy = false)
	return true

func _jam(c: String, dir: int) -> void:
	var w: Node3D = _wheels[c]
	var rest := (_wheel_rest[c] as Transform3D) * Transform3D(Basis(Vector3(0, 0, 1), deg_to_rad(40.0 * int(_wheel_turns[c]))), Vector3.ZERO)
	var tw := create_tween()
	tw.tween_property(w, "transform", rest * Transform3D(Basis(Vector3(0, 0, 1), deg_to_rad(6.0 * dir)), Vector3.ZERO), 0.08)
	tw.tween_property(w, "transform", rest, 0.15)
	_say("The %s valve jams: a needle is hard against its stop." % c)

func _needle_xf(n: Node3D, v: float) -> Transform3D:
	return (_needle_rest[n] as Transform3D) * Transform3D(Basis(Vector3(0, 0, 1), deg_to_rad((v - GREEN) * STEP_DEG)), Vector3.ZERO)

func _show_needles(_t: float) -> void:
	for st in _needles:
		var arr: Array = _needles[st]
		for i in arr.size():
			(arr[i] as Node3D).transform = _needle_xf(arr[i], float(needles_val[i]))

## Needles swing to their new values with a little overshoot, the far boards a beat late (the signal travels).
func _needle_tweens(tw: Tween, dur: float) -> void:
	for st in _needles:
		var arr: Array = _needles[st]
		for i in arr.size():
			var n: Node3D = arr[i]
			var v := float(needles_val[i])
			tw.tween_property(n, "transform", _needle_xf(n, v), dur).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(0.08 if st == "master" else 0.0)

func in_green() -> bool:
	for v in needles_val:
		if int(v) != GREEN:
			return false
	return true

func _throw() -> void:
	if _busy or solved:
		return
	_busy = true
	var on := _lever_rest * Transform3D(Basis(Vector3.RIGHT, LEVER_ON), Vector3.ZERO)
	var part := _lever_rest * Transform3D(Basis(Vector3.RIGHT, LEVER_ON * 0.45), Vector3.ZERO)
	var tw := create_tween()
	if not in_green():
		# the gain surges: every needle kicks up, then all fall back
		tw.tween_property(_lever, "transform", part, 0.35).set_trans(Tween.TRANS_SINE)
		tw.tween_property(_lever, "transform", _lever_rest, 0.3).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		var nt := create_tween().set_parallel(true)
		for st in _needles:
			for n: Node3D in _needles[st]:
				nt.tween_property(n, "transform", _needle_xf(n, 8.0), 0.35).set_trans(Tween.TRANS_SINE)
		nt.chain()
		_needle_tweens(nt, 0.6)
		tw.tween_interval(0.35)
		tw.tween_callback(func() -> void:
			_busy = false
			_say("The gain surges and falls back. All three needles must sit in the green.", 3.0))
		return
	tw.tween_property(_lever, "transform", on, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void:
		_busy = false
		_set_solved()
		sig.call("tune", 4))

func _set_solved() -> void:
	solved = true
	needles_val = [GREEN, GREEN, GREEN]
	_show_needles(0.0)
	if _lever:
		_lever.transform = _lever_rest * Transform3D(Basis(Vector3.RIGHT, LEVER_ON), Vector3.ZERO)
	for u in _uses:
		(u as Area3D).call("set_enabled", false)
