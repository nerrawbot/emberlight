extends Node3D
## The Peak hall's boss fight (surface.tscn PeakArena/BossFight, built by build_surface.gd build_peak()).
## The Sphaeroid (creatures/sphaeroid.gd) waits dormant in the middle of the hall. Once the player is inside and
## well past the entrance, BossGate drops behind them and the fight starts (boss bar, banner). Blacking out resets
## it: the player comes round at the last checkpoint (CP_HallEntrance, just outside) instead of the lift, the gate
## lifts and a fresh boss waits. Cutting its power when it's down sets GameState "peak_boss_down" (+ where the husk
## lies), opens BossGate, ExitGate (to the mast) and HiddenDoor (the annex), and pays out loot.
## Later visits: the husk sits where it fell and the doors start open (peak_door.gd open_flag).

const GameState := preload("res://scripts/game_state.gd")
const Boss := preload("res://scripts/creatures/sphaeroid.gd")
const BossBar := preload("res://scripts/boss_bar.gd")
const Items := preload("res://scripts/items.gd")

@export var floor_y := 38.12
## The hall's inner wall line, Godot XZ.
@export var hall_poly := PackedVector2Array()
## The floor under the gallery, Godot XZ, 4 points per quad: leaps never land there (the arc would hit the deck).
@export var gallery_quads := PackedVector2Array()
## The BossGate threshold (floor level): the fight starts once the player is this far in.
@export var gate_point := Vector3.ZERO
@export var start_dist := 4.5
@export var boss_gate: NodePath
@export var exit_gate: NodePath
@export var hidden_door: NodePath
@export var spawn: NodePath
@export var loot := {"tokens": 150, "scrap": 16, "bars": 4}

var boss: CharacterBody3D
var fighting := false
var _player: Node3D
var _bar: Control

func _ready() -> void:
	_setup.call_deferred()

func _setup() -> void:
	_player = get_tree().get_first_node_in_group("player") as Node3D
	if _player and _player.has_signal("respawned"):
		_player.connect("respawned", _on_player_respawned)
	if GameState.get_value("peak_boss_down", false):
		_spawn_boss(true)
	else:
		_spawn_boss(false)

func _spawn_boss(as_husk: bool) -> void:
	if boss and is_instance_valid(boss):
		boss.call("clear_minions", false)
		boss.queue_free()
	var b := Boss.new() as CharacterBody3D
	b.name = "Sphaeroid"
	b.set("husk", as_husk)
	b.set("floor_y", floor_y)
	b.set("arena", self)
	var m := get_node_or_null(spawn) as Node3D
	var at := m.global_position if m else global_position
	var yaw := m.global_rotation.y if m else 0.0
	if as_husk:
		var h: Variant = GameState.get_value("peak_boss_husk", null)
		if h is Dictionary:
			var p: Array = h.get("pos", [at.x, at.y, at.z])
			at = Vector3(float(p[0]), float(p[1]), float(p[2]))
			yaw = float(h.get("yaw", yaw))
	b.position = Vector3(at.x, floor_y, at.z)
	b.rotation.y = yaw
	add_child(b)
	boss = b
	if not as_husk:
		b.connect("health_changed", _on_boss_health)
		b.connect("downed", _on_boss_downed)
		b.connect("unpowered", _on_boss_unpowered)

func _physics_process(_delta: float) -> void:
	if fighting or boss == null or not is_instance_valid(boss) or boss.get("husk") or boss.call("is_down"):
		return
	if _player == null or not _player.has_method("is_alive") or not _player.is_alive():
		return
	var p := _player.global_position
	if inside_hall(p) and absf(p.y - floor_y) < 1.5 and Vector2(p.x - gate_point.x, p.z - gate_point.z).length() > start_dist:
		start_fight()

func start_fight() -> void:
	if fighting:
		return
	fighting = true
	var g := get_node_or_null(boss_gate)
	if g:
		g.call("close")
	if _player:
		_player.set("death_to_checkpoint", true)
		if _player.has_method("show_banner"):
			_player.show_banner("Sphaeroid\nRelay Warden II-151V", 2.6)
	_ensure_bar()
	_bar.set("down", false)
	_bar.call("set_health", boss.get("health"), boss.get("max_health"))
	_bar.set("shown", true)
	boss.call("wake")

func _ensure_bar() -> void:
	if _bar and is_instance_valid(_bar):
		return
	_bar = Control.new()
	_bar.name = "BossBar"
	_bar.set_script(BossBar)
	_bar.set("title", "SPHAEROID")
	_bar.set("subtitle", "Relay Warden II-151V")
	var hud := _player.get_node_or_null("HUD") if _player else null
	if hud:
		hud.add_child(_bar)
	else:
		add_child(_bar)

func _on_boss_health(v: float, m: float) -> void:
	if _bar and is_instance_valid(_bar):
		_bar.call("set_health", v, m)

func _on_boss_downed() -> void:
	if _bar and is_instance_valid(_bar):
		_bar.set("down", true)
	if _player and _player.has_method("show_toast"):
		_player.show_toast("It seizes up, sparking. Cut its power.", 3.5)

func _on_boss_unpowered(by: Node) -> void:
	fighting = false
	GameState.set_value("peak_boss_down", true)
	GameState.set_value("peak_boss_husk", {"pos": [boss.global_position.x, boss.global_position.y, boss.global_position.z],
		"yaw": boss.rotation.y})
	for path in [boss_gate, exit_gate, hidden_door]:
		var d := get_node_or_null(path)
		if d:
			d.call("open")
	if _player:
		_player.set("death_to_checkpoint", false)
		if _player.has_method("show_banner"):
			_player.show_banner("The Sphaeroid falls silent\nSomewhere above, a door grinds open", 4.0)
	if _bar and is_instance_valid(_bar):
		_bar.set("shown", false)
	_pay_out(by if by else _player)

## A fresh boss after the player blacks out mid-fight; the gate lifts again.
func _on_player_respawned(_at: Vector3, _from_health: bool) -> void:
	if not fighting:
		return
	fighting = false
	_spawn_boss(false)
	var g := get_node_or_null(boss_gate)
	if g:
		g.call("open")
	if _bar and is_instance_valid(_bar):
		_bar.set("shown", false)
	if _player:
		_player.set("death_to_checkpoint", false)

# ------------------------------------------------------------------ hall geometry (used by the boss)
func inside_hall(p: Vector3) -> bool:
	return hall_poly.size() >= 3 and Geometry2D.is_point_in_polygon(Vector2(p.x, p.z), hall_poly)

## Up on the gallery or high on its stairs (out of the boss's reach), not just standing on top of the boss.
func player_upper(p: Node3D, b: Node3D) -> bool:
	var pos := p.global_position
	if pos.y < floor_y + 2.2 or not inside_hall(pos):
		return false
	return Vector2(pos.x - b.global_position.x, pos.z - b.global_position.z).length() > 3.2

func _edge_dist(q: Vector2, poly: PackedVector2Array, from: int, n: int) -> float:
	var best := INF
	for i in n:
		var a := poly[from + i]
		var b := poly[from + (i + 1) % n]
		best = minf(best, q.distance_to(Geometry2D.get_closest_point_to_segment(q, a, b)))
	return best

## Can it land here: inside the hall, clear of the walls and out from under the gallery.
func landing_ok(p: Vector3, margin := 3.0) -> bool:
	var q := Vector2(p.x, p.z)
	if not Geometry2D.is_point_in_polygon(q, hall_poly) or _edge_dist(q, hall_poly, 0, hall_poly.size()) < margin:
		return false
	for k in range(0, gallery_quads.size() - 3, 4):
		var quad := gallery_quads.slice(k, k + 4)
		if Geometry2D.is_point_in_polygon(q, quad) or _edge_dist(q, gallery_quads, k, 4) < margin * 0.5:
			return false
	return true

## The nearest good landing spot on the way from `want` back towards the hall's middle.
func jump_target(from: Vector3, want: Vector3) -> Vector3:
	if hall_poly.size() < 3:
		return want
	var c := Vector2.ZERO
	for v in hall_poly:
		c += v
	c /= hall_poly.size()
	var mid := Vector3(c.x, floor_y, c.y)
	for i in 13:
		var p := want.lerp(mid, i / 12.0)
		if landing_ok(p):
			return p
	return from

# ------------------------------------------------------------------ loot
## The reward flies out of the husk as glowing motes and lands in the inventory (like supply_crate.gd).
func _pay_out(to: Node) -> void:
	if to == null:
		return
	var start := boss.global_position + Vector3.UP * 2.2
	var i := 0
	for id in loot:
		var total := int(loot[id])
		var beads := clampi(total / 10 + 1, 1, 6)
		for k in beads:
			var n := total / beads + (1 if k < total % beads else 0)
			if n > 0:
				_mote(to, start, str(id), n, 0.6 + i * 0.09)
				i += 1

func _mote(by: Node, start: Vector3, id: String, n: int, delay: float) -> void:
	var col := Items.color(id)
	var m := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.06
	sm.height = 0.12
	sm.radial_segments = 10
	sm.rings = 5
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = col
	sm.material = mat
	m.mesh = sm
	m.layers = 2
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.visible = false
	add_child(m)
	m.global_position = start
	var pop := start + Vector3(randf_range(-1.4, 1.4), randf_range(0.8, 1.8), randf_range(-1.4, 1.4))
	var tw := m.create_tween()
	tw.tween_interval(delay)
	tw.tween_callback(func(): m.visible = true)
	tw.tween_property(m, "global_position", pop, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.15)
	tw.tween_method(_mote_home.bind(m, pop, by), 0.0, 1.0, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(_mote_arrive.bind(m, by, id, n))

func _mote_home(t: float, m: Node3D, pop: Vector3, by: Node) -> void:
	var to := pop
	if is_instance_valid(by):
		to = (by as Node3D).global_position + Vector3.UP * 1.25
	m.global_position = pop.lerp(to, t)

func _mote_arrive(m: Node3D, by: Node, id: String, n: int) -> void:
	if is_instance_valid(by) and by.has_method("add_item"):
		by.add_item(id, n)
	m.queue_free()
