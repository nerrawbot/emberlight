extends Node3D
## Spawns the surface's hostiles (creatures/tripod.gd, creatures/skate.gd) at random spots around the player:
## open, level ground 22-48 m away, above the haze and the stair well, never within `safe_radius` of a respawn
## point (the lift landing), and out of sight when it can manage it. Enemies left far behind are recycled so the
## population follows the player along the route. When the player blacks out and comes round at the lift, the
## enemies near it are cleared and the rest lose track of them.
## Off under the walk test (--walktest), with --noenemies, and when the scene isn't the current scene (bench.gd).
## Keep this node at the origin: enemies are its children, placed in world coordinates.

const Tripod := preload("res://scripts/creatures/tripod.gd")
const Skate := preload("res://scripts/creatures/skate.gd")

@export var enabled := true
@export var max_tripods := 2
@export var max_skates := 2
@export var interval := Vector2(14.0, 34.0)
@export var first_delay := 6.0
@export var spawn_dist := Vector2(22.0, 48.0)
@export var safe_radius := 24.0
## Spots lower than this are the cove, the stair well or off the edge. (v8: just under grade, G 34.3 - the
## collapse heap in the stair well tops out ~33.8)
@export var min_ground_y := 34.1
@export var recycle_dist := 85.0

var _timer := 0.0
var _player: Node3D
var _far := {}          # enemy -> seconds spent beyond recycle_dist
var _check_t := 0.0

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if "--walktest" in args or "--noenemies" in args or "--enemytest" in args:
		enabled = false
	_timer = first_delay
	_hook_player.call_deferred()

func _hook_player() -> void:
	if get_tree().current_scene != owner and get_tree().current_scene != get_parent():
		enabled = false      # instanced by a tool script (bench.gd), not played
	_player = get_tree().get_first_node_in_group("player") as Node3D
	if _player and _player.has_signal("respawned"):
		_player.connect("respawned", _on_player_respawned)

func count(script: Script) -> int:
	var n := 0
	for e in get_children():
		if e.get_script() == script and not e.get("dead"):
			n += 1
	return n

func _physics_process(delta: float) -> void:
	if not enabled or _player == null:
		return
	_check_t -= delta
	if _check_t <= 0.0:
		_check_t = 1.0
		_recycle(1.0)
	if not (_player.has_method("is_alive") and _player.is_alive()):
		return
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = randf_range(interval.x, interval.y)
	var kinds: Array[int] = []
	if count(Tripod) < max_tripods:
		kinds.append(0)
	if count(Skate) < max_skates:
		kinds.append(1)
	if not kinds.is_empty():
		try_spawn(kinds[randi() % kinds.size()])

## Spawn one enemy (0 tripod, 1 skate) at a random valid spot. Returns it, or null if no spot was found.
func try_spawn(kind: int) -> Node3D:
	if _player == null:
		_player = get_tree().get_first_node_in_group("player") as Node3D
	var space := get_world_3d().direct_space_state
	var cam := get_viewport().get_camera_3d()
	for attempt in 24:
		var ang := randf() * TAU
		var r := randf_range(spawn_dist.x, spawn_dist.y)
		var c := _player.global_position + Vector3(cos(ang) * r, 0.0, sin(ang) * r)
		var hit := _ray(space, c + Vector3.UP * 40.0, c - Vector3.UP * 40.0)
		if hit.is_empty():
			continue
		var g: Vector3 = hit.position
		if g.y < min_ground_y or (hit.normal as Vector3).y < 0.85 or _near_respawn(g):
			continue
		var spot := g
		if kind == 0:
			if not _open_ground(space, g):
				continue
		else:
			spot = g + Vector3.UP * randf_range(3.5, 6.0)
			if not _ray(space, g + Vector3.UP * 0.3, spot + Vector3.UP * 1.0).is_empty():
				continue     # something overhead (a deck, a roof)
		if not _clear(space, spot + Vector3.UP * (1.3 if kind == 0 else 0.0), 1.0 if kind == 0 else 0.8):
			continue
		# early attempts insist on a spot the player can't see
		if attempt < 16 and cam and cam.is_position_in_frustum(spot + Vector3.UP) \
				and _ray(space, cam.global_position, spot + Vector3.UP).is_empty():
			continue
		return _spawn(kind, spot)
	return null

func _spawn(kind: int, at: Vector3) -> Node3D:
	var e := (Tripod.new() if kind == 0 else Skate.new()) as CharacterBody3D
	e.name = ("Tripod" if kind == 0 else "Skate") + str(randi() % 10000)
	e.position = at
	e.rotation.y = randf() * TAU
	add_child(e)
	return e

func _ray(space: PhysicsDirectSpaceState3D, a: Vector3, b: Vector3) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(a, b, 1)
	if _player:
		q.exclude = [(_player as CollisionObject3D).get_rid()]
	return space.intersect_ray(q)

## A tripod needs room for its feet: ground within a metre of level all round it.
func _open_ground(space: PhysicsDirectSpaceState3D, g: Vector3) -> bool:
	for k in 6:
		var a := k * TAU / 6.0
		var p := g + Vector3(cos(a), 0.0, sin(a)) * 2.0
		var h := _ray(space, p + Vector3.UP * 2.0, p - Vector3.UP * 2.0)
		if h.is_empty() or absf((h.position as Vector3).y - g.y) > 1.0:
			return false
	return true

func _clear(space: PhysicsDirectSpaceState3D, centre: Vector3, radius: float) -> bool:
	var q := PhysicsShapeQueryParameters3D.new()
	var s := SphereShape3D.new()
	s.radius = radius
	q.shape = s
	q.transform = Transform3D(Basis.IDENTITY, centre)
	q.collision_mask = 1 | 8
	return space.intersect_shape(q, 1).is_empty()

func _near_respawn(p: Vector3) -> bool:
	for m in get_tree().get_nodes_in_group("respawn_point"):
		if (m as Node3D).global_position.distance_to(p) < safe_radius:
			return true
	return false

## Enemies the player has left far behind (lost in the haze by then) go; new ones turn up nearer.
func _recycle(step: float) -> void:
	for e in get_children():
		if not (e is Node3D) or e.get("dead"):
			continue
		if (e as Node3D).global_position.distance_to(_player.global_position) > recycle_dist:
			_far[e] = float(_far.get(e, 0.0)) + step
			if _far[e] > 12.0:
				_far.erase(e)
				e.queue_free()
		else:
			_far.erase(e)
	for k in _far.keys():
		if not is_instance_valid(k):
			_far.erase(k)

func _on_player_respawned(at: Vector3, from_health: bool) -> void:
	for e in get_children():
		if not (e is Node3D):
			continue
		if from_health and (e as Node3D).global_position.distance_to(at) < safe_radius + 10.0:
			e.queue_free()
		elif e.has_method("lose_target"):
			e.lose_target()
	_timer = maxf(_timer, first_delay * 1.5)
