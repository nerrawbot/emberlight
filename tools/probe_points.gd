extends SceneTree
## Ground probe for placing props: loads a scene, lets physics settle, and casts down at Blender (x, y) points.
## Prints the Godot hit position, the floor normal's y, the collider and whether a 0.7 m box just above is clear.
##   tools\godot.cmd --headless --script res://tools/probe_points.gd -- scene=res://scenes/surface.tscn 26.5,-6 44.5,14.5
## Also prints the merged AABB of any glb passed as aabb=res://...glb

func _initialize() -> void:
	var scene_path := "res://scenes/surface.tscn"
	var pts: Array[Vector2] = []
	for a in OS.get_cmdline_user_args():
		if a.begins_with("scene="):
			scene_path = a.substr(6)
		elif a.begins_with("aabb="):
			_aabb(a.substr(5))
		elif "," in a:
			var p := a.split(",")
			pts.append(Vector2(float(p[0]), float(p[1])))
	if pts.is_empty():
		quit()
		return
	var s: Node = load(scene_path).instantiate()
	root.add_child(s)
	for i in 3:
		await physics_frame
	var space := (s as Node3D).get_world_3d().direct_space_state
	for p in pts:
		var from := Vector3(p.x, 120.0, -p.y)
		var q := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 140.0, 1 | 16)
		var hits := []
		var excl: Array[RID] = []
		for k in 4:                  # every floor down the column (decks over ground)
			q.exclude = excl
			var r := space.intersect_ray(q)
			if r.is_empty():
				break
			var pos: Vector3 = r.position
			var box := PhysicsShapeQueryParameters3D.new()
			var bs := BoxShape3D.new()
			bs.size = Vector3(0.7, 0.4, 0.5)
			box.shape = bs
			box.transform = Transform3D(Basis(), pos + Vector3.UP * 0.3)
			box.collision_mask = 1
			var clear := space.intersect_shape(box, 4).is_empty()
			hits.append("y=%.2f n=%.2f %s%s" % [pos.y, (r.normal as Vector3).y, (r.collider as Node).name, "" if clear else " BLOCKED"])
			excl.append(r.rid)
		print("B(%.1f, %.1f): " % [p.x, p.y], " | ".join(hits))
	quit()

func _aabb(path: String) -> void:
	var n: Node3D = load(path).instantiate()
	root.add_child(n)
	var bb := AABB()
	var first := true
	for c in n.find_children("*", "MeshInstance3D", true, false):
		var mi := c as MeshInstance3D
		var b := mi.global_transform * mi.get_aabb()
		print("  ", mi.name, " ", b)
		bb = b if first else bb.merge(b)
		first = false
	print("AABB ", path, ": ", bb)
	n.queue_free()