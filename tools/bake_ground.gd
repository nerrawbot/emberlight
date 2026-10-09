extends SceneTree
## v18: bakes the surface's ground height (terrain only: the mesa and the Peak's plateau, rays pass through everything
## else) into res://assets/map/surface_ground.res, a half-float ImageTexture at 1 m per texel. painterly_world.gd hands
## it to the painterly shader, which darkens walls and props near the ground (grime, damp) by height above it.
## Texels off the terrain hold -1000 (no grime). Re-run after reshaping the terrain:
## tools\godot.cmd --headless --script res://tools/bake_ground.gd

const SCENE := "res://scenes/surface.tscn"
const OUT := "res://assets/map/surface_ground.res"
const AREA := Rect2(-168.0, -104.0, 336.0, 312.0)     # Godot x, z (covers bake_map.gd's clip for the surface)
const TEXEL := 1.0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var main: Node = load(SCENE).instantiate()
	for n in ["Player", "Enemies", "ShotTour"]:
		var c := main.get_node_or_null(n)
		if c:
			main.remove_child(c)
			c.free()
	root.add_child(main)
	await physics_frame
	await physics_frame
	var space: PhysicsDirectSpaceState3D = main.get_world_3d().direct_space_state
	var terrain: Array[RID] = []
	for path in ["Level/S5_Mesa", "Peak/Peak"]:
		for b in main.get_node(path).find_children("*", "StaticBody3D", true, false):
			terrain.append((b as StaticBody3D).get_rid())
	var others: Array[RID] = []
	for b in main.find_children("*", "CollisionObject3D", true, false):
		var rid: RID = (b as CollisionObject3D).get_rid()
		if not terrain.has(rid):
			others.append(rid)
	var w := int(AREA.size.x / TEXEL)
	var h := int(AREA.size.y / TEXEL)
	var img := Image.create(w, h, false, Image.FORMAT_RF)
	var hits := 0
	for j in h:
		for i in w:
			var x := AREA.position.x + (i + 0.5) * TEXEL
			var z := AREA.position.y + (j + 0.5) * TEXEL
			var q := PhysicsRayQueryParameters3D.create(Vector3(x, 160.0, z), Vector3(x, -40.0, z), 0xFFFFFFFF, others)
			var hit := space.intersect_ray(q)
			var y := -1000.0
			if not hit.is_empty() and terrain.has(hit.rid):
				y = hit.position.y
				hits += 1
			img.set_pixel(i, j, Color(y, 0, 0))
	var tex := ImageTexture.create_from_image(img)
	tex.set_meta("area", AREA)
	var err := ResourceSaver.save(tex, OUT)
	print("ground: %dx%d texels, %d on terrain -> %s err=%d" % [w, h, hits, OUT, err])
	quit()
