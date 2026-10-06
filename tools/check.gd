extends SceneTree
func _init() -> void:
	var m: Node = load("res://scenes/main.tscn").instantiate()
	var lvl := m.get_node("Level")
	for c in lvl.get_children():
		var line := "%s [%s]" % [c.name, c.get_class()]
		for cc in c.get_children():
			line += " | %s[%s]" % [cc.name, cc.get_class()]
			for ccc in cc.get_children():
				if ccc is CollisionShape3D:
					line += " shape=%s faces=%d" % [ccc.shape.get_class(), (ccc.shape.get_faces().size()/3 if ccc.shape is ConcavePolygonShape3D else 0)]
		print(line)
		if c is MeshInstance3D:
			for i in c.mesh.get_surface_count():
				var mat = c.mesh.surface_get_material(i)
				if mat is StandardMaterial3D:
					print("   mat ", mat.resource_name, " alb=", mat.albedo_texture != null, " nrm=", mat.normal_enabled, " rough_tex=", mat.roughness_texture != null, " emis=", mat.emission_enabled, " e=", mat.emission_energy_multiplier, " cull=", mat.cull_mode)
	m.free()
	quit()
