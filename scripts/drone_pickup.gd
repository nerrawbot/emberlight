extends "res://scripts/interactable.gd"
## The broken warden drone on the K-tower's top deck (surface.tscn). [E] with a repair kit (player.use_item, a
## placeholder item - you start with one): it rights itself, lifts off and joins the player (player.give_drone()).
## Children: Model (drone.glb), CollisionShape3D. Sparks + the flickering light are made here.
## Gone for good once repaired (GameState "has_drone").

const GameState := preload("res://scripts/game_state.gd")

var _model: Node3D
var _wl: Node3D
var _wr: Node3D
var _ring: Node3D
var _core_mat: StandardMaterial3D
var _light: OmniLight3D
var _sparks: GPUParticles3D
var _t := 0.0
var _spark_cd := 1.0
var _repairing := false

func _ready() -> void:
	super._ready()
	if GameState.get_value("has_drone", false):
		queue_free()
		return
	_model = get_node_or_null("Model") as Node3D
	if _model == null:
		return
	for g in _model.find_children("*", "GeometryInstance3D", true, false):
		(g as GeometryInstance3D).layers = 2
		(g as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_wl = _model.find_child("DWing_L", true, false) as Node3D
	_wr = _model.find_child("DWing_R", true, false) as Node3D
	_ring = _model.find_child("DRing", true, false) as Node3D
	var core := _model.find_child("DCore", true, false) as MeshInstance3D
	if core and core.get_active_material(0) is StandardMaterial3D:
		_core_mat = core.get_active_material(0).duplicate() as StandardMaterial3D
		_core_mat.emission_enabled = true
		_core_mat.emission = Color(0.55, 0.88, 1.0)
		core.material_override = _core_mat
	# crashed: on its side, one wing folded under, the other bent up, the halo knocked askew
	_model.position = Vector3(0, 0.1, 0)
	_model.rotation = Vector3(0.25, 0.6, 1.15)
	if _wl:
		_wl.rotation = Vector3(0.2, 0.0, -0.95)
	if _wr:
		_wr.rotation = Vector3(0.45, 0.2, 0.55)
	if _ring:
		_ring.position += Vector3(0.02, -0.04, 0.0)
		_ring.rotation = Vector3(0.45, 0.0, 0.2)
	_light = OmniLight3D.new()
	_light.light_color = Color(0.6, 0.88, 1.0)
	_light.omni_range = 2.2
	_light.shadow_enabled = false
	_light.light_volumetric_fog_energy = 0.2
	_light.position = Vector3(0, 0.25, 0)
	add_child(_light)
	_sparks = _make_sparks()
	add_child(_sparks)

func _make_sparks() -> GPUParticles3D:
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 60.0
	pm.initial_velocity_min = 0.8
	pm.initial_velocity_max = 2.0
	pm.gravity = Vector3(0, -6.0, 0)
	pm.scale_min = 0.6
	pm.scale_max = 1.2
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.albedo_color = Color(0.75, 0.92, 1.0)
	m.emission_enabled = true
	m.emission = Color(0.6, 0.9, 1.0)
	m.emission_energy_multiplier = 4.0
	var q := QuadMesh.new()
	q.size = Vector2(0.025, 0.025)
	q.material = m
	var e := GPUParticles3D.new()
	e.name = "Sparks"
	e.amount = 14
	e.lifetime = 0.6
	e.one_shot = true
	e.explosiveness = 0.9
	e.emitting = false
	e.process_material = pm
	e.draw_pass_1 = q
	e.position = Vector3(0, 0.22, 0)
	e.layers = 2
	e.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return e

func get_prompt() -> String:
	if _repairing:
		return ""
	var p := get_tree().get_first_node_in_group("player")
	if p and p.has_method("item_count") and p.item_count("repair_kit") > 0:
		return "Repair the broken drone  (use a repair kit: %d)" % p.item_count("repair_kit")
	return "A broken drone. It needs a repair kit."

func _process(delta: float) -> void:
	if _model == null:
		return
	_t += delta
	if _repairing:
		var flap := sin(_t * 34.0)
		if _wl:
			_wl.rotation.z = lerpf(_wl.rotation.z, -flap * 0.35 - 0.1, clampf(delta * 6.0, 0.0, 1.0))
		if _wr:
			_wr.rotation.z = lerpf(_wr.rotation.z, flap * 0.35 + 0.1, clampf(delta * 6.0, 0.0, 1.0))
		if _ring:
			_ring.rotation.y += delta * 6.0
		return
	# dying spluttering core + a crackle of sparks now and then
	var e := 0.3
	if fmod(_t, 2.3) < 0.18 or randf() < 0.03:
		e = 3.0 + randf() * 3.0
	if _core_mat:
		_core_mat.emission_energy_multiplier = e
	_light.light_energy = 0.05 + 0.12 * e
	_spark_cd -= delta
	if _spark_cd <= 0.0:
		_spark_cd = randf_range(1.2, 3.5)
		_sparks.restart()

func _on_interact(by: Node) -> void:
	if _repairing:
		return
	if not (by.has_method("use_item") and by.has_method("give_drone")):
		return
	if not by.use_item("repair_kit"):
		if by.has_method("show_toast"):
			by.show_toast("Its core still flickers. You'd need parts to fix it.")
		return
	_repairing = true
	if by.has_method("show_toast"):
		by.show_toast("You patch the drone together...", 1.6)
	_sparks.amount = 30
	_sparks.restart()
	if _core_mat:
		var tc := create_tween()
		tc.tween_property(_core_mat, "emission_energy_multiplier", 9.0, 1.4)
	var tw := create_tween().set_parallel()
	tw.tween_property(_model, "rotation", Vector3(0, _model.rotation.y + PI, 0), 1.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_model, "position", Vector3(0, 1.3, 0), 1.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT).set_delay(0.3)
	if _ring:
		tw.tween_property(_ring, "rotation:x", 0.0, 0.8).set_delay(0.4)
		tw.tween_property(_ring, "rotation:z", 0.0, 0.8).set_delay(0.4)
	tw.tween_property(_light, "light_energy", 0.9, 1.4)
	await tw.finished
	await get_tree().create_timer(0.25).timeout
	if is_instance_valid(by):
		by.give_drone(_model.global_transform)
		if by.has_method("show_toast"):
			by.show_toast("The drone takes station beside you. Its shield soaks the next hit.", 3.5)
	queue_free()
