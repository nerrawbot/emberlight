extends RefCounted
## The Pennon's model (assets/props/pennon.glb, art_src/v14_pennon.py) with the Sphaeroid's painterly shader on its
## flat colours. Origin = the grip; blade ~0.75 m above it, span along X.
##   var wing := PennonModel.make(true)    # true: first-person (layer 2, no shadows)

const MODEL := "res://assets/props/pennon.glb"
const PAINT := preload("res://scripts/creatures/painterly.gdshader")
const BRUSH := "res://assets/creatures/sph_paint_brush.png"

static var _mats := {}

static func make(first_person := false) -> Node3D:
	var m := (load(MODEL) as PackedScene).instantiate() as Node3D
	for n in m.find_children("*", "MeshInstance3D", true, false):
		var g := n as MeshInstance3D
		if first_person:
			g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			g.layers = 2
		for s in g.mesh.get_surface_count():
			var src := g.mesh.surface_get_material(s)
			if src is StandardMaterial3D:
				g.set_surface_override_material(s, _painted(src as StandardMaterial3D))
	return m

static func _painted(src: StandardMaterial3D) -> ShaderMaterial:
	var key := src.resource_name
	if _mats.has(key):
		return _mats[key]
	var sm := ShaderMaterial.new()
	sm.shader = PAINT
	sm.set_shader_parameter("brush", load(BRUSH))
	sm.set_shader_parameter("use_paint", false)
	sm.set_shader_parameter("tint", src.albedo_color)
	sm.set_shader_parameter("shade_color", Color(0.42, 0.22, 0.32))
	sm.set_shader_parameter("rim_amt", 0.1)
	sm.set_shader_parameter("rim_color", Color(0.85, 0.55, 0.5))
	_mats[key] = sm
	return sm
