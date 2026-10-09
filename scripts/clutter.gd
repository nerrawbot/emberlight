extends Node3D
## v17 ground clutter on the surface (scenes/surface_clutter.tscn, baked by tools/bake_clutter.gd from the kit in
## art_src/v17_clutter.py). The bake runs headless, where a MultiMesh can't hold its transforms (they live in the
## rendering server), so each MultiMeshInstance3D carries them as "xf" metadata (12 floats each: basis x, y, z, origin)
## and they are filled in here.

func _ready() -> void:
	for n in find_children("*", "MultiMeshInstance3D", true, false):
		var mmi := n as MultiMeshInstance3D
		if not mmi.has_meta("xf"):
			continue
		var xf: PackedFloat32Array = mmi.get_meta("xf")
		var mm := mmi.multimesh
		mm.instance_count = 0
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.instance_count = xf.size() / 12
		for i in mm.instance_count:
			var k := i * 12
			mm.set_instance_transform(i, Transform3D(Vector3(xf[k], xf[k + 1], xf[k + 2]), Vector3(xf[k + 3], xf[k + 4], xf[k + 5]),
				Vector3(xf[k + 6], xf[k + 7], xf[k + 8]), Vector3(xf[k + 9], xf[k + 10], xf[k + 11])))
