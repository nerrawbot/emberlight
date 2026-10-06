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
## View-model pose of the shaft (camera space): grip low on the right, head leaning in from the upper right.
const SHAFT_REST_POS := Vector3(0.42, -0.56, -0.5)
const SHAFT_REST_ROT := Vector3(-46.0, -8.0, 6.0)

signal health_changed(value: float, max_value: float)
## After die(): back on the ground at `at` (a checkpoint, or a respawn point after a health death).
signal respawned(at: Vector3, from_health: bool)
## The drone's shield (HUD/ShieldArc). `has`: the player has a working drone.
signal shield_changed(value: float, max_value: float, block: float, has: bool)

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
	shield = clampf(GameState.get_value("shield", shield_max), 0.0, shield_max) if has_drone else 0.0
	_add_shield_arc()
	if has_drone:
		_spawn_drone.call_deferred(null)
	_emit_shield.call_deferred()
	_add_minimap()
	_style_banner()
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
	var climbed := false
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
	if _dying or amount <= 0.0:
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
		var to_point := not get_tree().get_nodes_in_group("respawn_point").is_empty()
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

## Inventory placeholder (GameState "items"): repair parts etc. Starts with one repair kit.
func item_count(id: String) -> int:
	var items: Dictionary = GameState.get_value("items", {"repair_kit": 1})
	return int(items.get(id, 0))

func use_item(id: String) -> bool:
	var items: Dictionary = GameState.get_value("items", {"repair_kit": 1})
	var n := int(items.get(id, 0))
	if n <= 0:
		return false
	items[id] = n - 1
	GameState.set_value("items", items)
	return true

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

# ---------------------------------------------------------------- dash + stick
func dash() -> void:
	if not input_enabled or _dash_cd > 0.0 or is_on_ladder() or (not is_on_floor() and not _air_dash):
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
	if not input_enabled or _attack_cd > 0.0 or not has_weapon:
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
		prompt.text = "[E]  " + txt
	elif is_on_ladder() and not is_on_floor():
		prompt.text = "W / S  climb      Space  let go"
	else:
		prompt.text = ""

func respawn() -> void:
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
