extends SceneTree

func _init() -> void:
	for p in ["res://scripts/creatures/enemy.gd", "res://scripts/creatures/tripod.gd", "res://scripts/creatures/skate.gd",
			"res://scripts/creatures/tripod_bolt.gd", "res://scripts/creatures/death_fx.gd", "res://scripts/enemy_spawner.gd", "res://scripts/player.gd"]:
		var s: Script = load(p)
		print(p, " ok=", s != null and s.can_instantiate())
	var t: Node = load("res://assets/creatures/tripod.glb").instantiate()
	print_tree_of(t, "")
	t.free()
	var k: Node = load("res://assets/creatures/skate.glb").instantiate()
	print_tree_of(k, "")
	k.free()
	var scene: Node = load("res://scenes/surface.tscn").instantiate()
	root.add_child(scene)
	await physics_frame
	await physics_frame
	var space := (scene as Node3D).get_world_3d().direct_space_state
	var rows := []
	for zi in range(-20, 32, 2):
		var line := "%4d " % zi
		for xi in range(4, 64, 2):
			var q := PhysicsRayQueryParameters3D.create(Vector3(xi, 80, zi), Vector3(xi, 0, zi), 1)
			var h := space.intersect_ray(q)
			if h.is_empty():
				line += " . "
				continue
			var y: float = (h.position as Vector3).y
			var n: Vector3 = h.normal
			var ch := "#" if n.y < 0.85 else ("=" if absf(y - 34.3) < 0.4 else ("^" if y > 34.7 else "v"))
			line += ch + str(int(round(y - 34.3))).lpad(2)
		rows.append(line)
	print("     " + "".join(range(4, 64, 2).map(func(x): return str(x).lpad(3))))
	for r in rows:
		print(r)
	quit()

func print_tree_of(n: Node, ind: String) -> void:
	print(ind, n.name, " (", n.get_class(), ")")
	for c in n.get_children():
		print_tree_of(c, ind + "  ")
