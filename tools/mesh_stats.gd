extends SceneTree
## Debug: per-node vertex counts of a glb / scene (sanity check after a Blender re-export).
##   tools\godot.cmd --headless --script res://tools/mesh_stats.gd -- res://assets/level/surface.glb

func _init() -> void:
	for path in OS.get_cmdline_user_args():
		var s: Node = (load(path) as PackedScene).instantiate()
		print(path)
		for m in s.find_children("*", "MeshInstance3D", true, false):
			var mesh := (m as MeshInstance3D).mesh
			var v := 0
			for i in mesh.get_surface_count():
				v += (mesh.surface_get_arrays(i)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
			print("  %-28s %8d verts  %d surfaces" % [m.name, v, mesh.get_surface_count()])
		s.free()
	quit()