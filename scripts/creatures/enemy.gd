extends CharacterBody3D
## Base for the surface hostiles (tripod.gd, skate.gd): health, the floating health bar (it appears once the
## player lands a hit and fades after a few quiet seconds), hit flash, sight checks and the death burst
## (death_fx.gd). Subclasses set their numbers in _init(), build their model in _build() and run their AI in _think().
## Spawned by enemy_spawner.gd; set `position` before adding to the tree (the body plants its feet in _ready).

const DeathFx := preload("res://scripts/creatures/death_fx.gd")
const BAR_SHADER := preload("res://scripts/creatures/enemy_bar.gdshader")
const BAR_SIZE := Vector2(1.3, 0.14)

signal died(enemy: Node, by_player: bool)

@export var max_health := 100.0
@export var sight_range := 24.0
## Damage per landed attack on the player (100 health: they survive six, the seventh drops them).
@export var attack_damage := 15.0
@export var bar_height := 2.6
## Below this height the body has fallen off the mesa: it's removed (no burst).
@export var kill_y := 20.0

## Colour of the glowing parts (eye, core); the death sparks and the bar pick it up.
var glow_color := Color(1.0, 0.3, 0.15)
var health := 100.0
var dead := false
var home := Vector3.ZERO
var _player: Node3D
var _model: Node3D
var _bar: MeshInstance3D
var _bar_mat: ShaderMaterial
var _bar_show := 0.0        # seconds the bar stays up
var _bar_alpha := 0.0
var _bar_trail := 1.0
var _trail_hold := 0.0
var _flash_mat: StandardMaterial3D
var _flash_t := 0.0
var _sees := false
var _sight_t := 0.0
var _seen_t := 99.0         # seconds since the player was last in sight
var _last_seen := Vector3.ZERO
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)

func _ready() -> void:
	collision_layer = 8        # the player's swing hits layer 8; the interact ray and the player don't
	collision_mask = 1
	health = max_health
	home = global_position
	add_to_group("enemies")
	_flash_mat = StandardMaterial3D.new()
	_flash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_flash_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_flash_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_flash_mat.albedo_color = Color(1.0, 0.92, 0.8, 0.0)
	_build()
	_make_bar()
	var p := get_tree().get_first_node_in_group("player")
	if p:
		add_collision_exception_with(p)    # they hit by attacks, never by shoving
		_player = p as Node3D

## Subclass: add the model, collision shape and anything else.
func _build() -> void:
	pass

## Subclass: AI + movement, once per physics tick.
func _think(_delta: float) -> void:
	pass

## Subclass: reaction to a landed swing (knockback, interrupting an attack).
func _on_hit(_by: Node3D, _dir: Vector3) -> void:
	pass

## The player respawned somewhere: forget them.
func lose_target() -> void:
	_sees = false
	_seen_t = 99.0

func _physics_process(delta: float) -> void:
	if dead:
		return
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node3D
	_think(delta)
	if global_position.y < kill_y:
		die(false)

func _process(delta: float) -> void:
	_update_bar(delta)
	if _flash_t > 0.0:
		_flash_t -= delta
		_flash_mat.albedo_color.a = clampf(_flash_t / 0.18, 0.0, 1.0) * 0.75
		if _flash_t <= 0.0:
			_set_overlay(null)

# ------------------------------------------------------------------ senses
func player_alive() -> bool:
	return _player != null and is_instance_valid(_player) and _player.has_method("is_alive") and _player.is_alive()

func player_chest() -> Vector3:
	return _player.global_position + Vector3.UP * 1.1

## Throttled line-of-sight check from `eye` (updates _sees, _seen_t, _last_seen).
func update_sight(delta: float, eye: Vector3) -> void:
	_sight_t -= delta
	if _sight_t <= 0.0:
		_sight_t = 0.15
		_sees = false
		if player_alive():
			var tgt := _player.global_position + Vector3.UP * 1.4
			if eye.distance_to(tgt) < sight_range:
				var q := PhysicsRayQueryParameters3D.create(eye, tgt, 1)
				q.exclude = [get_rid(), _player.get_rid()]
				_sees = get_world_3d().direct_space_state.intersect_ray(q).is_empty()
	if _sees:
		_seen_t = 0.0
		_last_seen = _player.global_position
	else:
		_seen_t += delta

## Next wander point (y ignored). Mostly they drift towards wherever the player is (they hear them), so the
## ones the spawner drops 20-50 m off come looking; otherwise somewhere round `home`.
func wander_target(near_radius: float) -> Vector3:
	if player_alive() and randf() < 0.7:
		var to := _player.global_position - global_position
		to.y = 0.0
		var d := to.length()
		if d > 8.0 and d < 90.0:
			var dir := (to / d).rotated(Vector3.UP, randf_range(-0.6, 0.6))
			home = global_position + dir * minf(d - 6.0, randf_range(7.0, 14.0))
			return home
	var a := randf() * TAU
	return home + Vector3(cos(a), 0, sin(a)) * randf_range(2.0, near_radius)

## Ray straight down through `p` (world, layer 1, skipping self + player).
func ground_at(p: Vector3, up := 2.5, down := 4.0) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(p + Vector3.UP * up, p - Vector3.UP * down, 1)
	q.exclude = [get_rid()] if _player == null else [get_rid(), _player.get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(q)

## Hurt the player if they're still alive; `knock` shoves them.
func hurt_player(knock: Vector3) -> void:
	if player_alive() and _player.has_method("take_damage"):
		_player.take_damage(attack_damage, "", knock)

# ------------------------------------------------------------------ taking hits
## Whacked by the player's shaft (player.gd attack()).
func take_hit(by: Node3D, dir: Vector3) -> void:
	if dead:
		return
	var d: Variant = by.get("attack_damage") if by else null
	var dmg := 30.0 if d == null else float(d)
	if _bar_show <= 0.0 or _trail_hold <= 0.0:
		_bar_trail = maxf(_bar_trail, health / max_health)
	_trail_hold = 0.4
	health = maxf(0.0, health - dmg)
	_bar_show = 5.0
	_flash_t = 0.18
	_set_overlay(_flash_mat)
	_seen_t = 0.0
	if by:
		_last_seen = by.global_position
	_on_hit(by, dir)
	if health <= 0.0:
		die(true)

func die(by_player := true) -> void:
	if dead:
		return
	dead = true
	died.emit(self, by_player)
	if by_player:
		DeathFx.burst(self, _model, glow_color)
	queue_free()

func _set_overlay(m: Material) -> void:
	if _model == null:
		return
	for g in _model.find_children("*", "GeometryInstance3D", true, false):
		(g as GeometryInstance3D).material_overlay = m

# ------------------------------------------------------------------ health bar
func _make_bar() -> void:
	_bar = MeshInstance3D.new()
	_bar.name = "HealthBar"
	var q := QuadMesh.new()
	q.size = BAR_SIZE
	_bar.mesh = q
	_bar_mat = ShaderMaterial.new()
	_bar_mat.shader = BAR_SHADER
	_bar_mat.render_priority = 10
	_bar_mat.set_shader_parameter("size", BAR_SIZE)
	_bar_mat.set_shader_parameter("fill_color", glow_color.lerp(Color(1, 0.25, 0.2), 0.4))
	_bar.material_override = _bar_mat
	_bar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_bar.layers = 2
	_bar.top_level = true
	_bar.visible = false
	add_child(_bar)

func _update_bar(delta: float) -> void:
	_bar_show -= delta
	_bar_alpha = move_toward(_bar_alpha, 1.0 if _bar_show > 0.0 else 0.0, delta * (6.0 if _bar_show > 0.0 else 1.5))
	_bar.visible = _bar_alpha > 0.01
	if not _bar.visible:
		return
	var frac := health / max_health
	_trail_hold -= delta
	if _trail_hold <= 0.0:
		_bar_trail = move_toward(_bar_trail, frac, delta * 0.8)
	_bar.global_position = global_position + Vector3.UP * bar_height
	var cam := get_viewport().get_camera_3d()
	var s := 1.0
	if cam:   # grow with distance so it stays readable
		s = clampf(cam.global_position.distance_to(_bar.global_position) / 7.0, 1.0, 3.0)
	_bar.scale = Vector3(s, s, 1.0)
	_bar_mat.set_shader_parameter("fill", frac)
	_bar_mat.set_shader_parameter("trail", maxf(_bar_trail, frac))
	_bar_mat.set_shader_parameter("alpha", _bar_alpha)
