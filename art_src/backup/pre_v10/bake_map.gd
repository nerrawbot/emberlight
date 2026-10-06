extends SceneTree
## Bakes the minimap floor plans: res://assets/map/<name>.res (scripts/map_info.gd) for each scene below.
## Casts rays straight down on a grid and keeps up to 4 walkable floors per column, so the minimap can show the
## floor the player is on and dim the decks above and below. Re-run after changing a level's collision.
## tools\godot.cmd --headless --script res://tools/bake_map.gd [-- start main surface]
## Also writes shots/map_<name>.png, a quick preview coloured by the top floor's height.

const MapInfo := preload("res://scripts/map_info.gd")
## cap: rays start here (Godot y); floors above it are left off (main's surface plate, rock tops).
## clip: optional [x0, z0, x1, z1] limit on the collision bounds.
const SCENES := {
	"start": {"path": "res://scenes/start.tscn", "title": "The Heretic – Upper Subterranean", "cap": 41.0, "texel": 0.25},
	"main": {"path": "res://scenes/main.tscn", "title": "The Heretic – Lower Subterranean", "cap": 33.5, "texel": 0.25},
	"surface": {"path": "res://scenes/surface.tscn", "title": "The Complex", "cap": 80.0, "texel": 0.4,
		"clip": [-100.0, -100.0, 160.0, 100.0]},
}
## The region all three scenes belong to (The Heretic is the mountain).
const REGION := "Forsaken Debris"
const LAYERS := 4               # floors kept per texel in the map
const RAW := 8                    # floors found per column before the reachability pass
const EMPTY := -100000.0
const STEP := 0.5                 # max height change between neighbouring texels that still counts as walkable
const NEIGHBOURS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
	Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]
const MASK := 1 | 16              # level collision + the surface's invisible ramps/guards
const MIN_NORMAL_Y := 0.64        # ~50 degrees: anything steeper is wall
## A floor needs ground under at least 3 of these 4 points (player radius): drops guard tops, rails, pipes, rungs.
const SUPPORT := [Vector3(0.35, 0, 0), Vector3(-0.35, 0, 0), Vector3(0, 0, 0.35), Vector3(0, 0, -0.35)]

var _queue: Array = []
var _scene: Node
var _wait := 0

func _initialize() -> void:
	var args := Array(OS.get_cmdline_user_args())
	_queue = args.filter(func(a): return SCENES.has(a)) if not args.is_empty() else SCENES.keys()
	DirAccess.make_dir_recursive_absolute("res://assets/map")
	DirAccess.make_dir_recursive_absolute("res://shots")

func _physics_process(_delta: float) -> bool:
	if _scene == null:
		if _queue.is_empty():
			quit()
			return true
		_scene = _load(SCENES[_queue[0]])
		_wait = 3
		return false
	_wait -= 1
	if _wait > 0:
		return false            # let the physics server pick up the bodies
	var key: String = _queue.pop_front()
	_bake(key, SCENES[key])
	_scene.queue_free()
	_scene = null
	return false

func _load(cfg: Dictionary) -> Node:
	var s: Node = load(cfg["path"]).instantiate()
	# moving or pushable things aren't floor plan: the player, crates, the lift car, the drawbridge, gates
	for b in s.find_children("*", "CollisionObject3D", true, false):
		if b is RigidBody3D or b is CharacterBody3D or b is AnimatableBody3D:
			(b as CollisionObject3D).collision_layer = 0
	for n in s.find_children("ShotTour", "", true, false):
		n.free()
	root.add_child(s)
	return s

func _bounds(cfg: Dictionary) -> Rect2:
	var box := AABB()
	var first := true
	for b in _scene.find_children("*", "StaticBody3D", true, false):
		if ((b as StaticBody3D).collision_layer & MASK) == 0 or b is AnimatableBody3D:
			continue
		for cs in b.find_children("*", "CollisionShape3D", true, false):
			var shape: Shape3D = (cs as CollisionShape3D).shape
			if shape == null:
				continue
			var bb: AABB = (cs as CollisionShape3D).global_transform * shape.get_debug_mesh().get_aabb()
			box = bb if first else box.merge(bb)
			first = false
	var r := Rect2(box.position.x, box.position.z, box.size.x, box.size.z)
	if cfg.has("clip"):
		var c: Array = cfg["clip"]
		r = r.intersection(Rect2(c[0], c[1], c[2] - c[0], c[3] - c[1]))
	return r.grow(1.0)

func _bake(key: String, cfg: Dictionary) -> void:
	var t0 := Time.get_ticks_msec()
	var space := root.get_world_3d().direct_space_state
	var texel: float = cfg["texel"]
	var cap: float = cfg["cap"]
	var rect := _bounds(cfg)
	var w := int(ceil(rect.size.x / texel))
	var h := int(ceil(rect.size.y / texel))
	var q := PhysicsRayQueryParameters3D.new()
	q.collision_mask = MASK
	q.hit_back_faces = false
	var sq := PhysicsRayQueryParameters3D.new()
	sq.collision_mask = MASK
	sq.hit_back_faces = false
	var hq := PhysicsRayQueryParameters3D.new()
	hq.collision_mask = MASK
	hq.hit_from_inside = true
	var floor_y := -1000.0
	var hs := PackedFloat32Array()          # RAW floor heights per texel, highest first; EMPTY pads the rest
	hs.resize(w * h * RAW)
	hs.fill(EMPTY)
	for j in h:
		for i in w:
			var x := rect.position.x + (i + 0.5) * texel
			var z := rect.position.y + (j + 0.5) * texel
			var base := (j * w + i) * RAW
			var n := 0
			var y := cap
			for guard in 32:
				q.from = Vector3(x, y, z)
				q.to = Vector3(x, floor_y, z)
				var r := space.intersect_ray(q)
				if r.is_empty():
					break
				var p: Vector3 = r["position"]
				y = p.y - 0.05
				if (r["normal"] as Vector3).y < MIN_NORMAL_Y:
					continue
				if n > 0 and hs[base + n - 1] - p.y < 0.3:
					continue
				var ok := 0
				for o in SUPPORT:
					sq.from = p + o + Vector3(0, 0.35, 0)
					sq.to = p + o - Vector3(0, 0.35, 0)
					if not space.intersect_ray(sq).is_empty():
						ok += 1
				if ok < 3:
					continue
				# headroom: rules out the tops of rock lumps buried in the ceiling mass (the ray up hits the inside
				# of whatever encloses them)
				hq.from = p + Vector3(0, 0.1, 0)
				hq.to = p + Vector3(0, 1.7, 0)
				if not space.intersect_ray(hq).is_empty():
					continue
				hs[base + n] = p.y
				n += 1
				if n == RAW:
					break

	# keep only floor you can walk to: flood out from known standing spots, stepping between neighbouring texels
	# whose floors are within STEP of each other (stairs and ramps connect, walls and drops don't)
	var reach := PackedByteArray()
	reach.resize(w * h * RAW)
	var todo := PackedInt32Array()
	var seeds := _seeds(cfg)
	for s: Vector3 in seeds:
		var rad := int(ceil(1.5 / texel))
		var ci := int((s.x - rect.position.x) / texel)
		var cj := int((s.z - rect.position.y) / texel)
		for j in range(maxi(cj - rad, 0), mini(cj + rad + 1, h)):
			for i in range(maxi(ci - rad, 0), mini(ci + rad + 1, w)):
				for k in RAW:
					var id := (j * w + i) * RAW + k
					if hs[id] > s.y - 2.5 and hs[id] < s.y + 0.8 and reach[id] == 0:
						reach[id] = 1
						todo.append(id)
	var head := 0
	while head < todo.size():
		var id := todo[head]
		head += 1
		var cell := id / RAW
		var ci := cell % w
		var cj := cell / w
		var y0 := hs[id]
		for d: Vector2i in NEIGHBOURS:
			var ni := ci + d.x
			var nj := cj + d.y
			if ni < 0 or nj < 0 or ni >= w or nj >= h:
				continue
			var nb := (nj * w + ni) * RAW
			for k in RAW:
				if reach[nb + k] == 0 and absf(hs[nb + k] - y0) <= STEP:
					reach[nb + k] = 1
					todo.append(nb + k)

	# crop to what's reachable (plus a margin) and pack the top LAYERS reachable floors per texel
	var i0 := w
	var j0 := h
	var i1 := -1
	var j1 := -1
	var lo := INF
	var hi := -INF
	for id in todo:
		var cell := id / RAW
		i0 = mini(i0, cell % w)
		i1 = maxi(i1, cell % w)
		j0 = mini(j0, cell / w)
		j1 = maxi(j1, cell / w)
		lo = minf(lo, hs[id])
		hi = maxf(hi, hs[id])
	if todo.is_empty():
		push_error("%s: no reachable floor (seeds: %d)" % [key, seeds.size()])
		return
	i0 = maxi(i0 - 4, 0)
	j0 = maxi(j0 - 4, 0)
	i1 = mini(i1 + 4, w - 1)
	j1 = mini(j1 + 4, h - 1)
	var cw := i1 - i0 + 1
	var ch := j1 - j0 + 1
	var y_min := lo - 0.5
	var y_span := maxf(hi - lo + 1.0, 1.0)
	var data := PackedByteArray()
	data.resize(cw * ch * 4)
	var preview := Image.create_empty(cw, ch, false, Image.FORMAT_RGB8)
	var overflow := 0
	for j in ch:
		for i in cw:
			var base := ((j + j0) * w + i + i0) * RAW
			var o := (j * cw + i) * 4
			var n := 0
			for k in RAW:
				if reach[base + k] == 0:
					continue
				if n == LAYERS:
					overflow += 1
					break
				if n == 0:
					var c := Color(0.1, 0.12, 0.3).lerp(Color(0.85, 0.9, 1.0), (hs[base + k] - y_min) / y_span)
					preview.set_pixel(i, j, c)
				data[o + n] = 1 + int(round((hs[base + k] - y_min) / y_span * 254.0))
				n += 1
	var img := Image.create_from_data(cw, ch, false, Image.FORMAT_RGBA8, data)
	var info := MapInfo.new()
	info.title = cfg["title"]
	info.region = REGION
	info.heights = ImageTexture.create_from_image(img)
	info.origin = rect.position + Vector2(i0, j0) * texel
	info.texel = texel
	info.y_min = y_min
	info.y_span = y_span
	var out := "res://assets/map/%s.res" % key
	var err := ResourceSaver.save(info, out, ResourceSaver.FLAG_COMPRESS)
	preview.save_png("res://shots/map_%s.png" % key)
	print("%s: %dx%d texels at %.2f m, origin %s, floors y %.1f..%.1f, %d seeds, %d columns over %d layers, %.1f s -> %s (%s)" % [
		key, cw, ch, texel, info.origin, lo, hi, seeds.size(), overflow, LAYERS, (Time.get_ticks_msec() - t0) / 1000.0,
		out, error_string(err)])

## Places a player is known to stand: spawn/respawn markers, trigger volumes (both ends, so a ladder seeds its top
## and bottom), creatures, the player, plus the scene's own `seeds` (Godot coords).
func _seeds(cfg: Dictionary) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for g in ["spawn_point", "respawn_point"]:
		for m in get_nodes_in_group(g):
			out.append((m as Node3D).global_position)
	for a in _scene.find_children("*", "Area3D", true, false):
		var sc: Script = a.get_script()
		if sc and sc.resource_path.ends_with("kill_zone.gd"):
			continue
		for cs in a.find_children("*", "CollisionShape3D", false, false):
			var shape: Shape3D = (cs as CollisionShape3D).shape
			if shape == null:
				continue
			var bb: AABB = (cs as CollisionShape3D).global_transform * shape.get_debug_mesh().get_aabb()
			var c := bb.get_center()
			out.append(Vector3(c.x, bb.position.y, c.z))
			out.append(Vector3(c.x, bb.end.y, c.z))
	for b in _scene.find_children("*", "CharacterBody3D", true, false):
		out.append((b as Node3D).global_position)
	for s: Array in cfg.get("seeds", []):
		out.append(Vector3(s[0], s[1], s[2]))
	return out
