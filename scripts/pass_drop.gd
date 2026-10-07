extends "res://scripts/interactable.gd"
## v12: a station pass lying where a mob died (enemy_spawner.gd decides the drops). A card spinning over the ground
## under a thin light beam, so it can be spotted from a distance. Walk over it or press [E] to take it.
## The sealed pass (the 6th kill's guaranteed drop) glows amber, plain passes a cold white.
## Spawn with PassDrop.drop(parent, death_position, item_id, player): it falls to the floor under the death spot,
## or lands at the player's feet if the mob died over the void.

const SEALED := "station_pass_sealed"

@export var item_id := "station_pass"

var _card: MeshInstance3D
var _light: OmniLight3D
var _t := 0.0
var _taken := false
var _ready_to_take := false

static func drop(parent: Node, at: Vector3, id: String, player: Node3D) -> Node3D:
	var d: Area3D = (load("res://scripts/pass_drop.gd") as GDScript).new()
	d.name = "PassDrop_" + id
	d.set("item_id", id)
	parent.add_child(d)
	var space := d.get_world_3d().direct_space_state
	var ground: Variant = _floor_below(space, at + Vector3.UP * 0.5, 30.0)
	if ground == null and player:
		var ahead := player.global_position - player.global_transform.basis.z * 1.4
		ground = _floor_below(space, ahead + Vector3.UP * 1.0, 4.0)
		if ground == null:
			ground = player.global_position
		at = (ground as Vector3) + Vector3.UP * 2.0
	d.global_position = at
	var rest: Vector3 = (ground as Vector3) + Vector3.UP * 0.55
	var tw := d.create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(d, "global_position", rest, clampf(sqrt(maxf(at.y - rest.y, 0.05) / 9.0), 0.15, 0.9))
	tw.tween_property(d, "global_position", rest + Vector3.UP * 0.18, 0.12).set_ease(Tween.EASE_OUT)
	tw.tween_property(d, "global_position", rest, 0.12).set_ease(Tween.EASE_IN)
	tw.tween_callback(func(): d.set("_ready_to_take", true))
	return d

static func _floor_below(space: PhysicsDirectSpaceState3D, from: Vector3, depth: float) -> Variant:
	var q := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * depth, 1 | 16)
	var hit := space.intersect_ray(q)
	if hit.is_empty() or (hit.normal as Vector3).y < 0.6:
		return null
	return hit.position

func _ready() -> void:
	super._ready()
	add_to_group("pass_drop")
	collision_layer = 1
	collision_mask = 1
	monitoring = true
	var cs := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = 0.6
	cs.shape = sh
	add_child(cs)
	body_entered.connect(_on_body_entered)
	var sealed := item_id == SEALED
	var col: Color = Color(1.0, 0.68, 0.3) if sealed else Color(0.8, 0.9, 1.0)
	# the card: a slim plate + a stripe, unshaded-bright so it reads in the haze
	_card = MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.22, 0.3, 0.014)
	_card.mesh = bm
	var m := StandardMaterial3D.new()
	m.albedo_color = col.darkened(0.35)
	m.emission_enabled = true
	m.emission = col
	m.emission_energy_multiplier = 2.2 if sealed else 1.4
	m.metallic = 0.3
	m.roughness = 0.4
	_card.material_override = m
	_card.layers = 2
	_card.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_card)
	var seal := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.035
	sm.height = 0.03
	seal.mesh = sm
	seal.position = Vector3(0.0, -0.07, 0.012)
	var smat := StandardMaterial3D.new()
	smat.albedo_color = Color(0.55, 0.06, 0.04) if sealed else Color(0.3, 0.3, 0.32)
	smat.emission_enabled = sealed
	smat.emission = Color(0.8, 0.1, 0.05)
	seal.material_override = smat
	seal.layers = 2
	_card.add_child(seal)
	# the beam: a tall faint additive column
	var beam := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.025
	cm.bottom_radius = 0.07
	cm.height = 9.0
	cm.radial_segments = 8
	cm.cap_top = false
	cm.cap_bottom = false
	beam.mesh = cm
	beam.position.y = 4.4
	var bmat := StandardMaterial3D.new()
	bmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bmat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	bmat.cull_mode = BaseMaterial3D.CULL_DISABLED
	bmat.albedo_color = Color(col.r, col.g, col.b, 0.32 if sealed else 0.2)
	bmat.disable_receive_shadows = true
	beam.material_override = bmat
	beam.layers = 2
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(beam)
	_light = OmniLight3D.new()
	_light.light_color = col
	_light.light_energy = 1.4 if sealed else 0.8
	_light.omni_range = 3.5
	_light.shadow_enabled = false
	_light.light_volumetric_fog_energy = 0.0
	add_child(_light)

func get_prompt() -> String:
	return "Take the sealed station pass" if item_id == SEALED else "Take the station pass"

func _process(delta: float) -> void:
	_t += delta
	if _card:
		_card.rotation.y = _t * 1.6
		_card.position.y = 0.06 * sin(_t * 2.3)
	if _light:
		_light.light_energy = (1.4 if item_id == SEALED else 0.8) * (0.85 + 0.15 * sin(_t * 3.1))

func _on_body_entered(b: Node) -> void:
	if _ready_to_take and b.is_in_group("player"):
		_on_interact(b)

func _on_interact(by: Node) -> void:
	if _taken or not by.has_method("add_item"):
		return
	_taken = true
	by.call("add_item", item_id, 1)
	if item_id == SEALED and by.has_method("show_toast"):
		by.call("show_toast", "A sealed station pass. The checkpoint on the Peak bridge will honour it.", 3.5)
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3.ONE * 0.01, 0.18)
	tw.tween_callback(queue_free)