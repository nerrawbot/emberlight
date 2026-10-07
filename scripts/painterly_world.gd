extends Node
## Painterly look for a level (painterly_world.gdshader, the world cousin of the Sphaeroid's painterly.gdshader).
## On ready, every StandardMaterial3D on a mesh in the scene is swapped for a painted ShaderMaterial (one per source
## material, as a surface override, so the glbs stay PBR on disk). Meshes added later (the cable station, drops) are
## caught through `node_added`. Left alone: emissive lamps and lenses, glass, anything already a ShaderMaterial (the
## mesa), and the player and creatures (anything under a CharacterBody3D or a scripts/creatures/ script).

const SHADER := preload("res://scripts/painterly_world.gdshader")
const BRUSH := preload("res://assets/creatures/sph_paint_brush.png")

## Per-material tweaks by the glb's material name (shader uniform -> value).
const TUNE := {
	"M_Steel": {"detail_amt": 0.2, "broad_blur": 5.0, "spec_amt": 0.35, "tint": Color(0.8, 0.78, 0.8)},  # was metallic (darker); blotches read as noise
	"M_Grate": {"detail_amt": 0.6, "broad_blur": 2.0},      # the grating's holes are its whole look
	"M_Hazard": {"detail_amt": 0.6, "broad_blur": 2.0, "smear": 0.012},
	"M_Corrugated": {"detail_amt": 0.5},
	"M_Spire": {"bands": 2.0, "step_mix": 0.4, "rim_amt": 0.0},
	"M_Silhouette": {"rim_amt": 0.0},
	"M_Grass": {"step_mix": 0.3, "spec_amt": 0.0},
	"M_GrassDry": {"step_mix": 0.3, "spec_amt": 0.0},
}

var _cache := {}
var _two_sided: Shader

func _ready() -> void:
	_two_sided = Shader.new()
	_two_sided.code = SHADER.code.replace("shader_type spatial;", "shader_type spatial;\nrender_mode cull_disabled;")
	get_tree().node_added.connect(_on_node_added)
	_paint_tree.call_deferred(get_parent())

func _on_node_added(n: Node) -> void:
	if n is MeshInstance3D:
		_paint_mesh.call_deferred(n)

func _paint_tree(root: Node) -> void:
	for n in root.find_children("*", "MeshInstance3D", true, false):
		_paint_mesh(n)

func _paint_mesh(mi: MeshInstance3D) -> void:
	if not is_instance_valid(mi) or not mi.is_inside_tree() or mi.mesh == null or _skipped(mi):
		return
	for s in mi.mesh.get_surface_count():
		var src := mi.get_surface_override_material(s)
		if src == null:
			src = mi.mesh.surface_get_material(s)
		var m := _painted(src)
		if m:
			mi.set_surface_override_material(s, m)

func _skipped(n: Node) -> bool:
	var p := n
	while p and p != get_parent():
		if p is CharacterBody3D or p.is_in_group("debris"):
			return true
		var sc := p.get_script() as Script
		if sc and sc.resource_path.begins_with("res://scripts/creatures/"):
			return true
		p = p.get_parent()
	return p == null      # not in this scene

func _painted(src: Material) -> Material:
	if not src is StandardMaterial3D:
		return null
	if _cache.has(src):
		return _cache[src]
	var sm := src as StandardMaterial3D
	var m: ShaderMaterial = null
	if not sm.emission_enabled and sm.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED \
			and sm.shading_mode == BaseMaterial3D.SHADING_MODE_PER_PIXEL and not sm.uv1_triplanar:
		m = ShaderMaterial.new()
		m.shader = _two_sided if sm.cull_mode == BaseMaterial3D.CULL_DISABLED else SHADER
		m.set_shader_parameter("brush", BRUSH)
		m.set_shader_parameter("tint", sm.albedo_color)
		m.set_shader_parameter("uv_scale", sm.uv1_scale)
		m.set_shader_parameter("uv_offset", sm.uv1_offset)
		if sm.albedo_texture:
			m.set_shader_parameter("use_albedo_tex", true)
			m.set_shader_parameter("albedo_tex", sm.albedo_texture)
		if sm.normal_enabled and sm.normal_texture:
			m.set_shader_parameter("use_normal_tex", true)
			m.set_shader_parameter("normal_tex", sm.normal_texture)
		for k in TUNE.get(sm.resource_name, {}):
			m.set_shader_parameter(k, TUNE[sm.resource_name][k])
	_cache[src] = m
	return m
