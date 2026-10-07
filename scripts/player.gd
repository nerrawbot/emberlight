extends CharacterBody3D
## First-person controller.
## WASD/arrows move, Shift dash, Space jump (hold for height), LMB/Q swing the steel shaft (once picked up),
## E interact, F lantern, M map, Esc frees the mouse.
## Supports ladders (look up/down to choose direction), small step-ups, pushing rigid bodies
## and riding moving platforms. Health (HUD/HealthArc) persists across scenes via GameState.

const GameState := preload("res://scripts/game_state.gd")
const SHAFT_MODEL := "res://assets/props/shaft.glb"
const MINIMAP := preload("res://scripts/minimap.gd")
const BANNER_FONT := preload("res://assets/fonts/Cinzel-Variable.ttf")
const Items := preload("res://scripts/items.gd")
## View-model pose of the shaft (camera space): grip low on the right, head leaning in from the upper right.
const SHAFT_REST_POS := Vector3(0.42, -0.56, -0.5)
const SHAFT_REST_ROT := Vector3(-46.0, -8.0, 6.0)

signal health_changed(value: float, max_value: float)
## After die(): back on the ground at `at` (a checkpoint, or a respawn point after a health death).
signal respawned(at: Vector3, from_health: bool)
## The drone's shield (HUD/ShieldArc). `has`: the player has a working drone.
signal shield_changed(value: float, max_value: float, block: float, has: bool)
## Tokens / materials changed (add_item, use_item).
signal inventory_changed

@export var walk_speed := 3.8
@export var jump_velocity := 5.2
@export var fall_gravity_mult := 1.55     # falls faster than it rises: snappier arc
@export var apex_gravity_mult := 1      # brief hang at the top while jump is held
@export var jump_cut := 0.45              # releasing jump early keeps this much upward speed
@export var dash_speed := 9.0
@export var dash_time := 0.25
@export var dash_cooldown := 0.65
@export var attack_range := 2.5
@export var attack_cooldown := 0.42
@export var attack_force := 14.0
## Health taken off an enemy per swing (the surface hostiles have 85-100: three or four hits).
@export var attack_damage := 30.0
@export var mouse_sensitivity := 0.0012
@export var ground_accel := 12.0
@export var air_accel := 3.0
@export var respawn_height := -15.0
@export var interact_distance := 2.6
@export var max_step_height := 0.4
@export var climb_speed := 2.8
@export var push_force := 320.0
@export var coyote_time := 0.12
@export var jump_buffer := 0.12
## Falls longer than this (metres) are fatal and send you back to the last checkpoint. 0 = off.
@export var max_safe_fall := 0.0
@export var max_health := 100.0
## Free falls longer than this hurt (fall_damage per metre beyond it), in every scene.
@export var hurt_fall := 5.5
@export var fall_damage := 14.0
@export var regen_delay := 10.0
@export var regen_rate := 2.0
## v9: the warden drone's shield soaks damage before health. One block = shield_block points.
@export var shield_max := 15.0
@export var shield_block := 15.0
@export var shield_regen_delay := 4.0
@export var shield_regen_rate := 6.0

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var ray: RayCast3D = $Head/Camera3D/InteractRay
@onready var lantern: OmniLight3D = $Head/Lantern
@onready var prompt: Label = $HUD/Prompt
@onready var banner: Label = $HUD/Banner
@onready var toast: Label = $HUD/Toast
@onready var fade: ColorRect = get_node_or_null("HUD/Fade")
@onready var hurt_flash: ColorRect = get_node_or_null("HUD/HurtFlash")

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
var spawn_transform: Transform3D
var input_enabled := true
var _bob_t := 0.0
var _banner_tween: Tween
var _toast_tween: Tween
var _banner_sub: Label
var _fade_tween: Tween
var _ladders: Array[Node] = []
var _ladder_block := 0.0
var _coyote := 0.0
var _jump_buf := 0.0
var _fall_top := 0.0
var _airborne := false
var _dying := false
var _jump_held := false
var _dash_t := 0.0
var _dash_cd := 0.0
var _dash_dir := Vector3.ZERO
var _air_dash := true
var _attack_cd := 0.0
var _stick: Node3D
var _was_floor := true
var has_weapon := false
var health := 100.0
var _since_hurt := 99.0
var has_drone := false
var shield := 0.0
var _since_shield_hit := 99.0
var _drone: Node3D
var _hurt_tween: Tween
var _trauma := 0.0          # screen shake, 0..1 (offset/roll grow with its square)
var _shake_t := 0.0
var _shake_noise := FastNoiseLite.new()
var _dialogue: Control      # v11 HUD extras, added at runtime (_add_hud_extras)
var _inventory: Control
var _feed: Control
var _talker: Node
## Set by boss_arena.gd during a boss fight: blacking out sends you back to the last checkpoint (outside the arena)
## instead of the nearest respawn point (the lift landing on the surface).
var death_to_checkpoint := false
## Debug console (scripts/debug_console.gd) `god`: take_damage does nothing.
var god := false
## Debug console `fly` / `noclip`: free flight along the view. Space up, Ctrl down, Shift faster. No falls while on;
## noclip also turns the collision shape off.
var flying := false
var noclip := false
var fly_speed := 10.0

## v14: the Pennon (pennon_pickup.gd). [Space] in mid-air, with at least glide_min_height of air below (so never
## straight out of a jump on flat ground), opens it; [Space] again folds it. Steer by looking: level it sinks
## slowly and speeds up towards dash speed; looking down dives (faster, sinks harder), looking up bleeds speed.
## It folds on landing, on a ladder, or after flying into a wall. Gliding never counts as a fall.
@export var glide_min_height := 3.0
@export var glide_sink := 1.7         # m/s, level
@export var glide_dive_sink := 5.0    # extra m/s looking straight down
@export var glide_accel := 6.0        # m/s^2 towards the glide speed (dash_speed)
@export var glide_fov := 14.0         # degrees added at full glide speed
const PennonModel := preload("res://scripts/pennon_model.gd")
const WING_POS := Vector3(0, -0.42, -0.55)    # the grip, camera-local, low in view; the blade rides overhead
const WING_ROT := Vector3(0.16, 0, 0)         # tipped back: only its leading edge shows at the top
var has_pennon := false
var gliding := false
var _glide_v := 0.0
var _glide_t := 0.0
var _wing: Node3D
var _wing_tw: Tween
var _fov_tw: Tween
var _base_fov := 75.0

const ACTIONS := {
	"move_forward": [KEY_W, KEY_UP],
	"move_back": [KEY_S, KEY_DOWN],
	"move_left": [KEY_A, KEY_LEFT],
	"move_right": [KEY_D, KEY_RIGHT],
	"jump": [KEY_SPACE],
	"dash": [KEY_SHIFT],
	"attack": [KEY_Q],
	"interact": [KEY_E],
	"toggle_lantern": [KEY_F],
	"toggle_map": [KEY_M],
	"toggle_inventory": [KEY_I],
}

func _ready() -> void:
	_ensure_input_actions()
	add_to_group("player")
	collision_mask |= 16      # the surface's invisible ramps + edge guards (layer 16, see build_surface.gd)
	spawn_transform = global_transform
	ray.target_position = Vector3(0, 0, -interact_distance)
	prompt.text = ""
	banner.modulate.a = 0.0
	toast.modulate.a = 0.0
	_shake_noise.frequency = 0.25
	_shake_noise.seed = randi()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	has_weapon = GameState.get_value("has_weapon", false)
	health = clampf(GameState.get_value("health", max_health), 1.0, max_health)
	health_changed.emit.call_deferred(health, max_health)
	if has_weapon:
		_make_stick()
	has_drone = GameState.get_value("has_drone", false)
	has_pennon = GameState.get_value("has_pennon", false)
	_base_fov = camera.fov
	shield = clampf(GameState.get_value("shield", shield_max), 0.0, shield_max) if has_drone else 0.0
	_add_shield_arc()
	if has_drone:
		_spawn_drone.call_deferred(null)
	_emit_shield.call_deferred()
	_add_minimap()
	_add_hud_extras()
	_style_banner()
	var dc := CanvasLayer.new()
	dc.name = "DebugConsole"
	dc.set_script(load("res://scripts/debug_console.gd"))
	dc.set("player", self)
	add_child(dc)
	var root := get_tree().root
	if root.has_meta("spawn_point"):
		var sp := str(root.get_meta("spawn_point"))
		root.remove_meta("spawn_point")
		_apply_spawn.call_deferred(sp)
	if fade:
		fade.color.a = 1.0
		fade_in(GameState.take("fade_in", 0.8))

## Corner minimap + M map (scripts/minimap.gd), under the hurt flash and fade so those still cover it.
func _add_minimap() -> void:
	if has_node("HUD/Minimap"):
		return
	var mm: Control = MINIMAP.new()
	mm.set("player", self)
	$HUD.add_child(mm)
	if hurt_flash:
		$HUD.move_child(mm, hurt_flash.get_index())

## Arriving from another scene: stand on the named spawn marker.
func _apply_spawn(spawn_name: String) -> void:
	for m in get_tree().get_nodes_in_group("spawn_point"):
		if m.name == spawn_name:
			global_transform = Transform3D(Basis(Vector3.UP, (m as Node3D).global_rotation.y), (m as Node3D).global_position)
			head.rotation.x = 0.0
			velocity = Vector3.ZERO
			spawn_transform = global_transform
			return
	push_warning("spawn point '%s' not found" % spawn_name)

# ---------------------------------------------------------------- riding the lift between scenes
## The cavern (main.tscn) and the surface (surface.tscn) share the lift shaft. The scene swaps mid-ride, inside
## the dark shaft, and the other scene's car carries on with the player standing where they were.
func is_in_car(car: Node3D, half := 1.5) -> bool:
	var d := global_position - car.global_position
	return absf(d.x) < half and absf(d.z) < half and d.y > -0.4 and d.y < 2.5

func change_scene_by_lift(next_scene: String, car: Node3D, ride: Dictionary) -> void:
	await fade_out(0.22)        # a short dip in the dark shaft hides the swap
	ride["y"] = car.global_position.y
	ride["offset"] = global_position - car.global_position
	ride["yaw"] = rotation.y
	ride["pitch"] = head.rotation.x
	GameState.set_value("car_ride", ride)
	GameState.set_value("fade_in", 0.35)
	get_tree().call_deferred("change_scene_to_file", next_scene)

## Arriving mid-ride: stand in `car` as recorded by change_scene_by_lift(); respawn at `respawn_marker` from now on.
func board_car(car: Node3D, ride: Dictionary) -> void:
	global_position = car.global_position + (ride.get("offset", Vector3(0, 0.05, 0)) as Vector3)
	rotation.y = ride.get("yaw", rotation.y)
	head.rotation.x = ride.get("pitch", 0.0)
	velocity = Vector3.ZERO
	reset_fall()
	for m in get_tree().get_nodes_in_group("spawn_point"):
		if m.name == ride.get("respawn", ""):
			spawn_transform = Transform3D(Basis(Vector3.UP, (m as Node3D).global_rotation.y), (m as Node3D).global_position)

func fade_in(sec: float) -> void:
	if fade == null:
		return
	if _fade_tween:
		_fade_tween.kill()
	_fade_tween = create_tween()
	_fade_tween.tween_property(fade, "color:a", 0.0, sec)

func fade_out(sec: float) -> void:
	if fade == null:
		return
	if _fade_tween:
		_fade_tween.kill()
	_fade_tween = create_tween()
	_fade_tween.tween_property(fade, "color:a", 1.0, sec)
	await _fade_tween.finished

func _ensure_input_actions() -> void:
	for action in ACTIONS:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for key in ACTIONS[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event(action, ev)
		if action == "attack":
			var mb := InputEventMouseButton.new()
			mb.button_index = MOUSE_BUTTON_LEFT
			InputMap.action_add_event(action, mb)

# ---------------------------------------------------------------- ladders
func enter_ladder(l: Node) -> void:
	if not _ladders.has(l):
		_ladders.append(l)

func exit_ladder(l: Node) -> void:
	_ladders.erase(l)

func is_on_ladder() -> bool:
	return not _ladders.is_empty() and _ladder_block <= 0.0

# ---------------------------------------------------------------- input
func _unhandled_input(event: InputEvent) -> void:
	if not input_enabled:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		head.rotate_x(-event.relative.y * mouse_sensitivity)
		head.rotation.x = clamp(head.rotation.x, deg_to_rad(-88), deg_to_rad(88))
	elif event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event.is_action_pressed("attack"):
		attack()
	elif event.is_action_pressed("dash"):
		dash()
	elif event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event.is_action_pressed("toggle_lantern"):
		lantern.visible = not lantern.visible
	elif event.is_action_pressed("interact"):
		try_interact()
	elif event.is_action_pressed("toggle_inventory") and _inventory:
		_inventory.call("toggle")

func try_interact() -> bool:
	var target := _get_interactable()
	if target:
		target.call("interact", self)
		return true
	return false

# ---------------------------------------------------------------- physics
func _physics_process(delta: float) -> void:
	if not input_enabled:
		return
	_ladder_block = maxf(0.0, _ladder_block - delta)
	_dash_cd = maxf(0.0, _dash_cd - delta)
	_attack_cd = maxf(0.0, _attack_cd - delta)
	_jump_held = Input.is_action_pressed("jump")
	_coyote = coyote_time if is_on_floor() else maxf(0.0, _coyote - delta)
	if Input.is_action_just_pressed("jump"):
		_jump_buf = jump_buffer
	else:
		_jump_buf = maxf(0.0, _jump_buf - delta)

	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if flying:
		_fly_physics(input_dir)
		_regen(delta)
		_update_prompt()
		return
	if Input.is_action_just_pressed("jump") and has_pennon and not is_on_floor() and not is_on_ladder():
		if gliding:
			_end_glide()
			_jump_buf = 0.0
		elif _coyote <= 0.0 and _dash_t <= 0.0 and _glide_clearance():
			_start_glide()
			_jump_buf = 0.0
	var climbed := false
	if gliding:
		_glide_physics(delta, input_dir)
	else:
		if is_on_ladder():
			climbed = _ladder_physics(input_dir)
		if not climbed:
			_ground_physics(delta, input_dir)

	var hspeed := Vector2(velocity.x, velocity.z).length()
	if is_on_floor() and hspeed > 0.5:
		_bob_t += delta * hspeed * 1.6
	camera.position.y = sin(_bob_t * 2.0) * 0.035 * clamp(hspeed / walk_speed, 0.0, 1.5)
	if global_position.y < respawn_height:
		respawn()
	_track_fall(climbed)
	_regen(delta)
	_update_prompt()

func _track_fall(climbed: bool) -> void:
	if climbed or is_on_floor():
		var drop := _fall_top - global_position.y
		if _airborne and not climbed and max_safe_fall > 0.0 and drop > max_safe_fall + 200:   # (+3: a jump's own arc)
			die("That drop was too far.")
		elif _airborne and not climbed and hurt_fall > 0.0 and drop > hurt_fall:
			take_damage((drop - hurt_fall) * fall_damage, "That landing hurt." if drop > hurt_fall + 3.0 else "")
		_airborne = false
		_fall_top = global_position.y
	else:
		_airborne = true
		_fall_top = maxf(_fall_top, global_position.y)

## Debug console: `on` flies, `through_walls` also drops collision. Landing afterwards never counts as a fall.
func set_flying(on: bool, through_walls := false) -> void:
	flying = on
	noclip = on and through_walls
	$CollisionShape3D.disabled = noclip
	if on:
		_end_glide()
		_dash_t = 0.0
	velocity = Vector3.ZERO
	reset_fall()

func _fly_physics(input_dir: Vector2) -> void:
	var dir := camera.global_basis * Vector3(input_dir.x, 0.0, input_dir.y)
	if Input.is_action_pressed("jump"):
		dir += Vector3.UP
	if Input.is_physical_key_pressed(KEY_CTRL):
		dir += Vector3.DOWN
	var speed := fly_speed * (3.0 if Input.is_action_pressed("dash") else 1.0)
	velocity = dir.limit_length(1.0) * speed
	if noclip:
		global_position += velocity * get_physics_process_delta_time()
	else:
		move_and_slide()
	reset_fall()

## Call after teleporting the player so the move doesn't count as a fall.
func reset_fall() -> void:
	_airborne = false
	_fall_top = global_position.y

## Fatal fall / hazard: fade out, back to the last checkpoint (spawn_transform), fade in.
## `to_respawn_point`: go to the nearest node in group "respawn_point" instead (surface: the lift landing), which
## also becomes the checkpoint. Scenes without one fall back to the checkpoint.
func die(msg := "", to_respawn_point := false) -> void:
	if _dying:
		return
	_dying = true
	input_enabled = false
	velocity = Vector3.ZERO
	await fade_out(0.35)
	if to_respawn_point:
		var best: Node3D = null
		for m in get_tree().get_nodes_in_group("respawn_point"):
			var n := m as Node3D
			if best == null or n.global_position.distance_to(global_position) < best.global_position.distance_to(global_position):
				best = n
		if best:
			spawn_transform = Transform3D(Basis(Vector3.UP, best.global_rotation.y), best.global_position)
	respawn()
	head.rotation.x = 0.0
	_airborne = false
	_fall_top = global_position.y
	_set_health(max_health)
	if has_drone:
		_set_shield(shield_max)
	_trauma = 0.0
	input_enabled = true
	_dying = false
	respawned.emit(global_position, to_respawn_point)
	fade_in(0.6)
	if msg != "":
		show_toast(msg)

## False while dying / fading between scenes: enemies hold off.
func is_alive() -> bool:
	return not _dying and input_enabled and health > 0.0

## Screen shake: adds trauma (0..1); it decays over ~0.6 s.
func shake(amount: float) -> void:
	_trauma = clampf(_trauma + amount, 0.0, 1.0)

func _process(delta: float) -> void:
	if _trauma <= 0.0:
		return
	_trauma = maxf(0.0, _trauma - delta * 1.6)
	_shake_t += delta * 60.0
	var k := _trauma * _trauma
	camera.h_offset = _shake_noise.get_noise_2d(_shake_t, 0.0) * 0.14 * k
	camera.v_offset = _shake_noise.get_noise_2d(0.0, _shake_t) * 0.1 * k
	camera.rotation = Vector3(_shake_noise.get_noise_2d(_shake_t, 50.0) * 0.05, _shake_noise.get_noise_2d(50.0, _shake_t) * 0.05,
		_shake_noise.get_noise_2d(_shake_t, 100.0) * 0.09) * k

# ---------------------------------------------------------------- health
func _set_health(v: float) -> void:
	health = clampf(v, 0.0, max_health)
	GameState.set_value("health", health)
	health_changed.emit(health, max_health)

## Hurt the player (falls, hazards, enemies). Shakes the view; `knock` shoves them (enemy hits).
## At 0 they collapse and come round at the nearest respawn point (or the last checkpoint where there is none).
func take_damage(amount: float, msg := "", knock := Vector3.ZERO) -> void:
	if _dying or amount <= 0.0 or god:
		return
	if has_drone and shield > 0.0:        # the drone's shield soaks it first
		var soak := minf(shield, amount)
		_set_shield(shield - soak)
		_since_shield_hit = 0.0
		amount -= soak
		if _drone and is_instance_valid(_drone):
			_drone.call("on_shield_hit", shield <= 0.0)
		if amount <= 0.001:
			shake(0.2)
			return
	_since_hurt = 0.0
	_since_shield_hit = 0.0
	_set_health(health - amount)
	if hurt_flash:
		if _hurt_tween:
			_hurt_tween.kill()
		hurt_flash.color.a = clampf(0.18 + amount / 120.0, 0.18, 0.5)
		_hurt_tween = create_tween()
		_hurt_tween.tween_property(hurt_flash, "color:a", 0.0, 0.7).set_ease(Tween.EASE_OUT)
	shake(clampf(0.45 + amount / 60.0, 0.45, 0.9))
	if knock != Vector3.ZERO:
		velocity += knock
		_dash_t = 0.0
	if health <= 0.0:
		var to_point := not death_to_checkpoint and not get_tree().get_nodes_in_group("respawn_point").is_empty()
		die("You black out... and come round by the lift." if to_point else "You black out... and come round further back.", to_point)
	elif msg != "":
		show_toast(msg)

func heal(amount: float) -> void:
	_set_health(health + amount)

func _regen(delta: float) -> void:
	_since_hurt += delta
	if _since_hurt > regen_delay and health < max_health and not _dying:
		_set_health(health + regen_rate * delta)
	_since_shield_hit += delta
	if has_drone and _since_shield_hit > shield_regen_delay and shield < shield_max and not _dying:
		_set_shield(shield + shield_regen_rate * delta)

# ---------------------------------------------------------------- v9: the warden drone + its shield
func _set_shield(v: float) -> void:
	shield = clampf(v, 0.0, shield_max)
	GameState.set_value("shield", shield)
	_emit_shield()

func _emit_shield() -> void:
	shield_changed.emit(shield, shield_max, shield_block, has_drone)
	if _drone and is_instance_valid(_drone):
		_drone.call("on_shield", shield / maxf(shield_max, 0.001))

## Thin grey arc over the health dome (scripts/shield_arc.gd), same rect as HUD/HealthArc.
func _add_shield_arc() -> void:
	var hp := get_node_or_null("HUD/HealthArc") as Control
	if hp == null or has_node("HUD/ShieldArc"):
		return
	var arc := Control.new()
	arc.name = "ShieldArc"
	arc.set_script(load("res://scripts/shield_arc.gd"))
	arc.anchor_left = hp.anchor_left
	arc.anchor_right = hp.anchor_right
	arc.anchor_top = hp.anchor_top
	arc.anchor_bottom = hp.anchor_bottom
	arc.offset_left = hp.offset_left
	arc.offset_right = hp.offset_right
	arc.offset_top = hp.offset_top
	arc.offset_bottom = hp.offset_bottom
	$HUD.add_child(arc)
	$HUD.move_child(arc, hp.get_index() + 1)

## The companion flies in world space beside the player (a sibling in the scene). `from`: where it starts
## (the repaired drone on the tower deck); null = right next to the player (arriving in a scene).
func _spawn_drone(from: Variant) -> void:
	if _drone and is_instance_valid(_drone):
		return
	_drone = Node3D.new()
	_drone.name = "WardenDrone"
	_drone.set_script(load("res://scripts/drone_companion.gd"))
	get_parent().add_child(_drone)
	if from is Transform3D:
		_drone.set("player", self)
		_drone.global_transform = from
	else:
		_drone.call("place_near", self)
	_emit_shield()

## Repaired drone (drone_pickup.gd): it joins you with its shield up.
func give_drone(from: Variant = null) -> void:
	has_drone = true
	GameState.set_value("has_drone", true)
	_spawn_drone(from)
	_set_shield(shield_max)

# ---------------------------------------------------------------- v11: inventory (GameState "items": {id: count})
## Ids are in scripts/items.gd: "tokens" (currency), "station_pass_sealed" (key), "station_pass" (valuable),
## "scrap", "bars", "voltaic_core" (materials).
func item_count(id: String) -> int:
	var items: Dictionary = GameState.get_value("items", {})
	return int(items.get(id, 0))

## Add `n` of an item; shows "+n Name" in the pickup feed unless `quiet`.
func add_item(id: String, n := 1, quiet := false) -> void:
	if n <= 0:
		return
	var items: Dictionary = GameState.get_value("items", {})
	items[id] = int(items.get(id, 0)) + n
	GameState.set_value("items", items)
	if not quiet and _feed:
		_feed.call("push", "+%d  %s" % [n, Items.label(id, n)], Items.color(id))
	inventory_changed.emit()
	if _inventory and _inventory.visible:
		_inventory.call("refresh")

## Spend `n` of an item; false (and nothing spent) if there aren't enough.
func use_item(id: String, n := 1) -> bool:
	var items: Dictionary = GameState.get_value("items", {})
	var have := int(items.get(id, 0))
	if have < n:
		return false
	items[id] = have - n
	GameState.set_value("items", items)
	inventory_changed.emit()
	return true

## Pickup feed (right edge), [I] inventory panel and the watcher dialogue box; under the hurt flash and fade.
func _add_hud_extras() -> void:
	if has_node("HUD/Dialogue"):
		return
	var at := hurt_flash.get_index() if hurt_flash else $HUD.get_child_count()
	_feed = load("res://scripts/pickup_feed.gd").new()
	_inventory = load("res://scripts/inventory_panel.gd").new()
	_inventory.set("player", self)
	_dialogue = load("res://scripts/dialogue_box.gd").new()
	_dialogue.connect("finished", _on_dialogue_finished)
	for c in [_feed, _inventory, _dialogue]:
		$HUD.add_child(c)
		$HUD.move_child(c, at)
		at += 1

## Talk to a watcher (watcher_talk.gd): movement and look stop until the box closes; `talker.end_talk()` then.
func start_dialogue(tree_id: String, speaker: String, talker: Node = null) -> void:
	if _dialogue == null or _dialogue.get("active"):
		return
	_talker = talker
	input_enabled = false
	velocity = Vector3.ZERO
	prompt.text = ""
	if _inventory:
		_inventory.call("close")       # also unpauses
	_dialogue.call("start", tree_id, speaker)

func _on_dialogue_finished() -> void:
	if _talker and is_instance_valid(_talker) and _talker.has_method("end_talk"):
		_talker.call("end_talk")
	_talker = null
	# a beat before control returns, so the Space that closed the box isn't read as a jump
	get_tree().create_timer(0.12).timeout.connect(func(): input_enabled = true)

func _ladder_physics(input_dir: Vector2) -> bool:
	var ladder: Node = _ladders.back()
	var n: Vector3 = ladder.get("climb_normal")
	var fwd_in := -input_dir.y
	var climb_dir := 1.0 if head.rotation.x > deg_to_rad(-30.0) else -1.0
	var vertical := fwd_in * climb_dir
	if is_on_floor() and vertical <= 0.0:
		return false  # standing at the foot (or on top) and not climbing: walk normally
	if _jump_buf > 0.0:
		_jump_buf = 0.0
		_ladder_block = 0.45
		velocity = n * 3.5 + Vector3.UP * 2.5
		move_and_slide()
		return true
	var right := transform.basis.x
	var h := right * input_dir.x * 1.6 - n * 0.9
	velocity = Vector3(h.x, vertical * climb_speed, h.z)
	move_and_slide()
	return true

func _ground_physics(delta: float, input_dir: Vector2) -> void:
	if is_on_floor():
		_air_dash = true
		if not _was_floor:
			_land_dip()
	_was_floor = is_on_floor()
	if _dash_t > 0.0:   # dash: fixed burst, no gravity, then hand back to normal movement
		_dash_t -= delta
		velocity = _dash_dir * dash_speed
		if _dash_t <= 0.0:
			velocity = _dash_dir * walk_speed * 1.2
		move_and_slide()
		_push_bodies(delta)
		return
	if not is_on_floor():
		var g := gravity
		if velocity.y < 0.0:
			g *= fall_gravity_mult
		elif _jump_held and velocity.y < 1.2:
			g *= apex_gravity_mult
		velocity.y -= g * delta
		if velocity.y > 0.0 and not _jump_held:
			velocity.y *= jump_cut        # short hop when jump is tapped
	if _jump_buf > 0.0 and _coyote > 0.0:
		velocity.y = jump_velocity
		_jump_buf = 0.0
		_coyote = 0.0
	var dir := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	var accel := ground_accel if is_on_floor() else air_accel
	var target := dir * walk_speed
	velocity.x = lerp(velocity.x, target.x, clamp(accel * delta, 0.0, 1.0))
	velocity.z = lerp(velocity.z, target.z, clamp(accel * delta, 0.0, 1.0))
	_try_step_up(delta)
	move_and_slide()
	_push_bodies(delta)

# ---------------------------------------------------------------- v14: gliding (the Pennon)
## Taken from the annex plinth (pennon_pickup.gd).
func give_pennon() -> void:
	has_pennon = true
	GameState.set_value("has_pennon", true)

## Enough air below to open it.
func _glide_clearance() -> bool:
	var q := PhysicsRayQueryParameters3D.create(global_position, global_position + Vector3.DOWN * glide_min_height,
		collision_mask, [get_rid()])
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()

func _start_glide() -> void:
	gliding = true
	_glide_t = 0.0
	_glide_v = Vector2(velocity.x, velocity.z).length()
	_dash_t = 0.0
	if _stick:
		_stick.visible = false
	if _wing == null:
		_wing = PennonModel.make(true)
		_wing.name = "Pennon"
		_wing.scale = Vector3.ONE * 1.1
		camera.add_child(_wing)
	_wing.visible = true
	# unfurls: swings up from below the view and snaps open
	_wing.position = WING_POS + Vector3(0, -0.6, 0.15)
	_wing.rotation = WING_ROT + Vector3(0.9, 0, 0.3)
	if _wing_tw:
		_wing_tw.kill()
	_wing_tw = create_tween().set_parallel()
	_wing_tw.tween_property(_wing, "position", WING_POS, 0.26).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_wing_tw.tween_property(_wing, "rotation", WING_ROT, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	shake(0.12)

func _end_glide() -> void:
	if not gliding:
		return
	gliding = false
	head.rotation.z = 0.0
	if _wing:
		if _wing_tw:
			_wing_tw.kill()
		_wing_tw = create_tween().set_parallel()
		_wing_tw.tween_property(_wing, "position", WING_POS + Vector3(0, -0.7, 0.2), 0.2).set_ease(Tween.EASE_IN)
		_wing_tw.tween_property(_wing, "rotation", WING_ROT + Vector3(0.9, 0, -0.2), 0.2)
		_wing_tw.chain().tween_callback(func():
			_wing.visible = false
			if _stick:
				_stick.visible = true)
	if _fov_tw:
		_fov_tw.kill()
	_fov_tw = create_tween()
	_fov_tw.tween_property(camera, "fov", _base_fov, 0.35)

func _glide_physics(delta: float, input_dir: Vector2) -> void:
	_glide_t += delta
	var pitch := head.rotation.x                  # + looking up, - down
	var down := clampf(-pitch / 1.2, 0.0, 1.0)
	var up := clampf(pitch / 1.2, 0.0, 1.0)
	var target := dash_speed * (1.0 + 0.35 * down - 0.55 * up)
	_glide_v = move_toward(_glide_v, target, glide_accel * delta * (1.0 if _glide_v < target else 0.6))
	var want := -transform.basis.z * _glide_v + transform.basis.x * input_dir.x * 2.0
	var k := clampf(delta * 3.0, 0.0, 1.0)
	velocity.x = lerpf(velocity.x, want.x, k)
	velocity.z = lerpf(velocity.z, want.z, k)
	var sink := glide_sink + glide_dive_sink * down * down - glide_sink * 0.4 * up
	velocity.y = move_toward(velocity.y, -sink, delta * 12.0)     # catches a fall quickly, then settles
	_fall_top = global_position.y                                 # a glide is never a fall
	_airborne = false
	move_and_slide()
	if is_on_floor() or is_on_ladder():
		_end_glide()
		return
	if is_on_wall() and _glide_t > 0.3 and get_wall_normal().dot(-transform.basis.z) < -0.75:
		_end_glide()                                              # flew head-on into a wall (glancing ones slide)
		_glide_v = 0.0
		return
	# wider view with speed, a little lean into turns
	camera.fov = lerpf(camera.fov, _base_fov + glide_fov * clampf(_glide_v / dash_speed, 0.0, 1.2), clampf(delta * 4.0, 0.0, 1.0))
	head.rotation.z = lerpf(head.rotation.z, -input_dir.x * 0.06, clampf(delta * 5.0, 0.0, 1.0))
	if _wing:
		_wing.rotation.z = lerpf(_wing.rotation.z, -input_dir.x * 0.18 + sin(_glide_t * 2.3) * 0.025, clampf(delta * 6.0, 0.0, 1.0))
		_wing.position.y = WING_POS.y + sin(_glide_t * 3.1) * 0.012 if not (_wing_tw and _wing_tw.is_running()) else _wing.position.y

# ---------------------------------------------------------------- dash + stick
func dash() -> void:
	if not input_enabled or gliding or flying or _dash_cd > 0.0 or is_on_ladder() or (not is_on_floor() and not _air_dash):
		return
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if input_dir == Vector2.ZERO:
		input_dir = Vector2(0, -1)
	_dash_dir = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	_dash_t = dash_time
	_dash_cd = dash_cooldown
	if not is_on_floor():
		_air_dash = false
	var tw := create_tween()
	tw.tween_property(camera, "fov", 102.0, 0.15)
	tw.tween_property(camera, "fov", 92.0, 0.25)

## The steel shaft held in view (assets/props/shaft.glb, origin at the grip, shaft along +Y).
func _make_stick() -> void:
	if _stick:
		return
	_stick = Node3D.new()
	_stick.name = "Shaft"
	camera.add_child(_stick)
	_stick.position = SHAFT_REST_POS
	_stick.rotation_degrees = SHAFT_REST_ROT
	var model: Node3D = load(SHAFT_MODEL).instantiate()
	_stick.add_child(model)
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var g := mi as MeshInstance3D
		g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		g.layers = 2          # never forces a shadow-map redraw (shadowed lights take casters from layer 1 only)
		for s in g.mesh.get_surface_count():
			var m := g.mesh.surface_get_material(s)
			if m is StandardMaterial3D:
				# no reflection probes underground: keep the steel readable with a cool rim instead of black chrome
				var t := (m as StandardMaterial3D).duplicate() as StandardMaterial3D
				t.metallic = minf(t.metallic, 0.55)
				t.rim_enabled = true
				t.rim = 0.35
				t.rim_tint = 0.6
				g.set_surface_override_material(s, t)

## Pick up the shaft (weapon_pickup.gd). Brings it up into view unless `quiet`.
func give_weapon(quiet := false) -> void:
	has_weapon = true
	GameState.set_value("has_weapon", true)
	_make_stick()
	if quiet:
		return
	_stick.position = SHAFT_REST_POS + Vector3(0.1, -0.7, 0.2)
	_stick.rotation_degrees = SHAFT_REST_ROT + Vector3(40, 0, -30)
	var tw := create_tween().set_parallel()
	tw.tween_property(_stick, "position", SHAFT_REST_POS, 0.55).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_stick, "rotation_degrees", SHAFT_REST_ROT, 0.6).set_trans(Tween.TRANS_SINE)

## Swing the shaft: short-range box check in front of the player. Needs the weapon.
func attack() -> bool:
	if not input_enabled or _attack_cd > 0.0 or not has_weapon or gliding:
		return false
	_attack_cd = attack_cooldown
	if _stick == null:
		_make_stick()
	# wind-up, diagonal strike from upper right to lower left, recover
	var tw := create_tween()
	tw.tween_property(_stick, "rotation_degrees", SHAFT_REST_ROT + Vector3(18, -10, -14), 0.05).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(_stick, "position", SHAFT_REST_POS + Vector3(0.06, 0.04, 0.05), 0.05)
	tw.tween_property(_stick, "rotation_degrees", Vector3(-95, 25, 75), 0.09).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(_stick, "position", Vector3(0.05, -0.5, -0.62), 0.09).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(_stick, "rotation_degrees", SHAFT_REST_ROT, 0.26).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(_stick, "position", SHAFT_REST_POS, 0.26).set_trans(Tween.TRANS_SINE)
	await get_tree().create_timer(0.1).timeout
	var fwd := -camera.global_transform.basis.z
	var q := PhysicsShapeQueryParameters3D.new()
	# body-height box in front of you, so low critters get hit as well as things at eye level
	var bx := BoxShape3D.new()
	bx.size = Vector3(1.2, 1.9, attack_range - 0.2)
	q.shape = bx
	var flat := Vector3(fwd.x, 0, fwd.z).normalized()
	q.transform = Transform3D(global_transform.basis, global_position + flat * (0.2 + bx.size.z * 0.5) + Vector3.UP * 0.95)
	q.collision_mask = 1 | 8
	q.exclude = [get_rid()]
	var hit := false
	for r in get_world_3d().direct_space_state.intersect_shape(q, 32):   # the floor and walls fill results too
		var c: Object = r.collider
		if c.has_method("take_hit"):
			c.take_hit(self, fwd)
			hit = true
		elif c is RigidBody3D:
			(c as RigidBody3D).apply_central_impulse(Vector3(fwd.x, 0.25, fwd.z).normalized() * attack_force * (c as RigidBody3D).mass * 0.45)
			hit = true
	if hit:
		shake(0.2)
		var k := create_tween()
		k.tween_property(head, "position:z", head.position.z + 0.04, 0.04)
		k.tween_property(head, "position:z", head.position.z, 0.1)
	return hit

func _land_dip() -> void:
	var tw := create_tween()
	tw.tween_property(head, "position:y", 1.5, 0.06)
	tw.tween_property(head, "position:y", 1.62, 0.18).set_trans(Tween.TRANS_SINE)

func _push_bodies(delta: float) -> void:
	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		var body := c.get_collider()
		if body is RigidBody3D:
			var d := -c.get_normal()
			d.y = 0.0
			if d.length() > 0.01:
				(body as RigidBody3D).apply_central_impulse(d.normalized() * push_force * delta)

func _try_step_up(_delta: float) -> void:
	# Lets the player walk over small lips and broken steps (up to max_step_height).
	var horiz := Vector3(velocity.x, 0.0, velocity.z)
	if horiz.length() < 0.2 or not is_on_floor() or not is_on_wall():
		return
	var dir := horiz.normalized()
	if dir.dot(get_wall_normal()) > -0.2:
		return
	var xf := global_transform
	var up := Vector3(0.0, max_step_height, 0.0)
	if test_move(xf, up):
		return
	var raised := xf.translated(up)
	for probe in [0.15, 0.3, 0.45]:
		var motion: Vector3 = dir * probe
		if test_move(raised, motion):
			continue
		var col := KinematicCollision3D.new()
		var ahead := raised.translated(motion)
		if test_move(ahead, -up, col):
			var dy := ahead.origin.y + col.get_travel().y - xf.origin.y
			if dy > 0.04 and col.get_normal().y > cos(floor_max_angle):
				global_position = Vector3(xf.origin.x, xf.origin.y + dy + 0.01, xf.origin.z) + dir * 0.05
				return

# ---------------------------------------------------------------- interaction + HUD
func _get_interactable() -> Node:
	if ray.is_colliding():
		var c := ray.get_collider()
		if c and c.has_method("interact"):
			return c
	return null

func _update_prompt() -> void:
	var t := _get_interactable()
	if t:
		var txt: String = t.call("get_prompt") if t.has_method("get_prompt") else str(t.get("prompt_text"))
		prompt.text = "[E]  " + txt if txt != "" else ""
	elif is_on_ladder() and not is_on_floor():
		prompt.text = "W / S  climb      Space  let go"
	else:
		prompt.text = ""

func respawn() -> void:
	_end_glide()
	global_transform = spawn_transform
	velocity = Vector3.ZERO

## Area banners in Cinzel (assets/fonts, SIL OFL): the first line bold, the rest in regular weight underneath
## (Banner/Sub, a child so it fades with it).
func _style_banner() -> void:
	var ts := TextServerManager.get_primary_interface()
	var bold := FontVariation.new()
	bold.base_font = BANNER_FONT
	bold.variation_opentype = {ts.name_to_tag("wght"): 700}
	bold.spacing_glyph = 2
	banner.add_theme_font_override("font", bold)
	banner.add_theme_font_size_override("font_size", 44)
	banner.add_theme_color_override("font_shadow_color", Color(0, 0, 0.03, 0.6))
	banner.add_theme_constant_override("shadow_offset_y", 2)
	var reg := FontVariation.new()
	reg.base_font = BANNER_FONT
	reg.variation_opentype = {ts.name_to_tag("wght"): 400}
	reg.spacing_glyph = 1
	_banner_sub = Label.new()
	_banner_sub.name = "Sub"
	_banner_sub.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_banner_sub.offset_top = 62
	_banner_sub.offset_bottom = 100
	_banner_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner_sub.add_theme_font_override("font", reg)
	_banner_sub.add_theme_font_size_override("font_size", 26)
	_banner_sub.add_theme_color_override("font_color", Color(0.86, 0.85, 0.82))
	_banner_sub.add_theme_color_override("font_shadow_color", Color(0, 0, 0.03, 0.6))
	_banner_sub.add_theme_constant_override("shadow_offset_y", 2)
	banner.add_child(_banner_sub)

func show_banner(text: String, hold := 3.5) -> void:
	var lines := text.split("\n", true, 1)
	banner.text = lines[0]
	_banner_sub.text = lines[1] if lines.size() > 1 else ""
	if _banner_tween:
		_banner_tween.kill()
	_banner_tween = create_tween()
	_banner_tween.tween_property(banner, "modulate:a", 1.0, 0.8)
	_banner_tween.tween_interval(hold)
	_banner_tween.tween_property(banner, "modulate:a", 0.0, 1.2)

func show_toast(text: String, hold := 2.2) -> void:
	toast.text = text
	if _toast_tween:
		_toast_tween.kill()
	toast.modulate.a = 1.0
	_toast_tween = create_tween()
	_toast_tween.tween_interval(hold)
	_toast_tween.tween_property(toast, "modulate:a", 0.0, 0.8)
