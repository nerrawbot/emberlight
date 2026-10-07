extends StaticBody3D
## Loot crate (surface.tscn "Loot/Crate_*", built by tools/build_surface.gd). Children: Model (assets/props/
## supply_crate.glb or parts_case.glb: *_Floor, *_Side_F/B/L/R, *_Lid with its origin on the hinge) and a
## CollisionShape3D. [E] pries the lid open; a swing of the shaft (player.attack -> take_hit) bursts it into its
## panels. Either way the contents fly to the player as glowing motes and land in the inventory (player.add_item).
## Opened crates stay opened across scene changes (GameState "opened_crates": {"<scene>:<name>": "pried"|"smashed"}).

const GameState := preload("res://scripts/game_state.gd")
const Items := preload("res://scripts/items.gd")
const LID_OPEN := 1.95          # rad about the hinge (+X lifts the front, which faces -Z)

@export var tokens := 0
@export var scrap := 0
@export var bars := 0
@export var voltaic_core := 0

var _opened := false
var _model: Node3D
var _lid: Node3D

func _ready() -> void:
	add_to_group("interactable")
	_model = get_node_or_null("Model") as Node3D
	if _model:
		for c in _model.get_children():
			if str(c.name).ends_with("_Lid"):
				_lid = c as Node3D
	var state := str((GameState.get_value("opened_crates", {}) as Dictionary).get(_key(), ""))
	if state == "smashed":
		queue_free()
	elif state == "pried":
		_opened = true
		if _lid:
			_lid.rotation.x = LID_OPEN

func _key() -> String:
	return "%s:%s" % [owner.scene_file_path if owner else "", name]

func _save(state: String) -> void:
	var d: Dictionary = GameState.get_value("opened_crates", {})
	d[_key()] = state
	GameState.set_value("opened_crates", d)

func get_prompt() -> String:
	return "" if _opened else "Pry the crate open"

func interact(by: Node) -> void:
	if _opened:
		return
	_opened = true
	_save("pried")
	if _lid:
		var tw := create_tween()
		tw.tween_property(_lid, "rotation:x", 0.25, 0.12).set_trans(Tween.TRANS_SINE)      # the catch gives...
		tw.tween_property(_lid, "rotation:x", LID_OPEN, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_deliver(by, 0.25)

## The shaft (player.attack()). Bursts the crate, opened or not; only an unopened one gives anything.
func take_hit(by: Node, dir: Vector3) -> void:
	var had_loot := not _opened
	_opened = true
	_save("smashed")
	_burst(dir)
	if had_loot:
		_deliver(by, 0.05)
	get_tree().create_timer(3.0).timeout.connect(queue_free)

func _burst(dir: Vector3) -> void:
	var cs := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if cs:
		cs.set_deferred("disabled", true)
	if _model == null:
		return
	var centre := global_position + Vector3.UP * 0.22
	var flat := Vector3(dir.x, 0.0, dir.z).normalized()
	for c in _model.find_children("*", "MeshInstance3D", true, false):
		var mi := c as MeshInstance3D
		var gt := mi.global_transform
		var rb := RigidBody3D.new()
		rb.collision_layer = 0          # debris settles on the floor but never trips the player
		rb.collision_mask = 1
		rb.mass = 1.5
		get_parent().add_child(rb)
		rb.global_transform = gt
		mi.get_parent().remove_child(mi)
		rb.add_child(mi)
		mi.transform = Transform3D.IDENTITY
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.layers = 2                   # moving: keep it out of the shadowed lamps' caster mask
		var bb := mi.get_aabb()
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(maxf(bb.size.x, 0.04), maxf(bb.size.y, 0.04), maxf(bb.size.z, 0.04))
		shape.shape = box
		shape.position = bb.get_center()
		rb.add_child(shape)
		rb.center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
		rb.center_of_mass = bb.get_center()
		var out := (gt * bb.get_center()) - centre
		out.y = maxf(out.y, 0.0)
		rb.apply_central_impulse((out.normalized() * 2.2 + flat * 2.4 + Vector3.UP * 2.0) * rb.mass)
		rb.angular_velocity = Vector3(randf_range(-9, 9), randf_range(-9, 9), randf_range(-9, 9))
		var tw := rb.create_tween()
		tw.tween_interval(randf_range(3.5, 5.0))
		tw.tween_property(mi, "scale", Vector3.ONE * 0.01, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		tw.tween_callback(rb.queue_free)

func _deliver(by: Node, delay: float) -> void:
	var loot := []
	for id in ["tokens", "scrap", "bars", "voltaic_core"]:
		var n := int(get(id))
		if n > 0:
			loot.append([id, n])
	if loot.is_empty():
		if by and by.has_method("show_toast"):
			by.show_toast("Empty. Someone got here first.")
		return
	var start := global_position + Vector3.UP * 0.35
	var scene := get_tree().current_scene
	for i in loot.size():
		_mote(scene, by, start, str(loot[i][0]), int(loot[i][1]), delay + i * 0.14)

## A glowing bead that pops out of the crate and homes in on the player's head; the item is added when it arrives.
func _mote(scene: Node, by: Node, start: Vector3, id: String, n: int, delay: float) -> void:
	var col := Items.color(id)
	var m := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.07 if id == "voltaic_core" else 0.045
	sm.height = sm.radius * 2.0
	sm.radial_segments = 10
	sm.rings = 5
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = col
	mat.emission_enabled = true
	mat.emission = col
	mat.emission_energy_multiplier = 3.0
	sm.material = mat
	m.mesh = sm
	m.layers = 2
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.visible = false
	scene.add_child(m)
	m.global_position = start
	if id == "voltaic_core":
		var l := OmniLight3D.new()
		l.light_color = col
		l.light_energy = 0.8
		l.omni_range = 1.6
		l.shadow_enabled = false
		m.add_child(l)
	var pop := start + Vector3(randf_range(-0.25, 0.25), 0.55, randf_range(-0.25, 0.25))
	var tw := m.create_tween()
	tw.tween_interval(delay)
	tw.tween_callback(func(): m.visible = true)
	tw.tween_property(m, "global_position", pop, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.12)
	tw.tween_method(_home.bind(m, pop, by), 0.0, 1.0, 0.32).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(_arrive.bind(m, by, id, n))

func _home(t: float, m: Node3D, pop: Vector3, by: Node) -> void:
	var to := pop
	if is_instance_valid(by):
		to = (by as Node3D).global_position + Vector3.UP * 1.25
	m.global_position = pop.lerp(to, t)

func _arrive(m: Node3D, by: Node, id: String, n: int) -> void:
	if is_instance_valid(by) and by.has_method("add_item"):
		by.add_item(id, n)
	m.queue_free()