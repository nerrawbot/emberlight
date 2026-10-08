extends SceneTree
## v17: scatters the ground clutter kit (assets/props/clutter.glb, built by art_src/v17_clutter.py) over the surface's
## open ground and writes res://scenes/surface_clutter.tscn (instanced in surface.tscn as "Clutter").
## Casts rays straight down on a jittered 1 m grid; only hits on the terrain bodies (the mesa, the Peak's plateau) count,
## so nothing lands on decks, roofs or under them. Density comes from two noise fields (grass patches, debris fields)
## plus nearness to the works (rubble piles up along walls). Pieces with collision need clear space around them (no
## structure within their radius + CLEAR_PAD, level ground at four points 2.4 m out) so they never jam a path; the route
## lines, spawns, interactables and small zones are kept clear for everything. Meshes and materials are copied into the
## .tscn (it doesn't depend on the glb's internal ids); placement goes into one MultiMesh per piece per CHUNK cell, its
## transforms kept as metadata that scripts/clutter.gd loads (headless, MultiMesh buffers don't survive saving).
## tools\godot.cmd --headless --script res://tools/bake_clutter.gd [-- seed=N] [-- density=1.0]
## Re-bake the minimap afterwards (the rocks have collision): tools\godot.cmd --headless --script res://tools/bake_map.gd -- surface

const SCENE := "res://scenes/surface.tscn"
const KIT := "res://assets/props/clutter.glb"
const OUT := "res://scenes/surface_clutter.tscn"
const AREA := Rect2(-165.0, -100.0, 325.0, 300.0)     # Godot x, z (bake_map.gd's clip for the surface)
const CHUNK := 64.0
const CLEAR_PAD := 0.6
const MASK := 1 | 16
## r: footprint radius (m), s: scale range, align: how far the piece tilts to the ground normal, range: visibility
## range end (m), shadow, col: has collision, sink: extra metres pushed into the ground.
const PIECES := {
	"TuftA": {"r": 0.2, "s": Vector2(0.6, 1.3), "align": 0.7, "range": 55.0, "shadow": false, "col": false},
	"TuftB": {"r": 0.25, "s": Vector2(0.6, 1.2), "align": 0.7, "range": 55.0, "shadow": false, "col": false},
	"TuftC": {"r": 0.4, "s": Vector2(0.8, 1.3), "align": 0.8, "range": 55.0, "shadow": false, "col": false},
	"Pebbles": {"r": 0.8, "s": Vector2(0.7, 1.4), "align": 1.0, "range": 45.0, "shadow": false, "col": false},
	"RubbleB": {"r": 1.0, "s": Vector2(0.8, 1.3), "align": 1.0, "range": 70.0, "shadow": false, "col": false},
	"Sheet": {"r": 1.0, "s": Vector2(0.85, 1.15), "align": 1.0, "range": 80.0, "shadow": false, "col": false},
	"Planks": {"r": 1.0, "s": Vector2(0.9, 1.1), "align": 1.0, "range": 70.0, "shadow": false, "col": false},
	"Tyre": {"r": 0.5, "s": Vector2(0.9, 1.1), "align": 0.8, "range": 70.0, "shadow": false, "col": false},
	"RockA": {"r": 0.9, "s": Vector2(0.9, 3.0), "align": 0.4, "range": 160.0, "shadow": true, "col": true, "sink": 0.1},
	"RockB": {"r": 0.5, "s": Vector2(0.8, 2.2), "align": 0.5, "range": 110.0, "shadow": true, "col": true, "sink": 0.05},
	"RockC": {"r": 1.0, "s": Vector2(1.0, 2.6), "align": 0.8, "range": 130.0, "shadow": true, "col": true, "sink": 0.05},
	"RubbleA": {"r": 1.2, "s": Vector2(0.8, 1.4), "align": 0.7, "range": 140.0, "shadow": true, "col": true, "sink": 0.08},
	"SlabA": {"r": 1.3, "s": Vector2(0.85, 1.2), "align": 0.9, "range": 140.0, "shadow": true, "col": true},
	"Kerb": {"r": 1.0, "s": Vector2(0.9, 1.2), "align": 0.9, "range": 90.0, "shadow": true, "col": true, "sink": 0.04},
	"DrumUp": {"r": 0.35, "s": Vector2(0.95, 1.05), "align": 0.2, "range": 100.0, "shadow": true, "col": true},
	"DrumSide": {"r": 0.6, "s": Vector2(0.95, 1.05), "align": 0.9, "range": 100.0, "shadow": true, "col": true},
	"Girder": {"r": 1.9, "s": Vector2(0.8, 1.2), "align": 0.9, "range": 140.0, "shadow": true, "col": true, "sink": 0.05},
	"PipeSeg": {"r": 1.1, "s": Vector2(0.9, 1.1), "align": 0.9, "range": 140.0, "shadow": true, "col": true, "sink": 0.12},
	"Reel": {"r": 0.6, "s": Vector2(0.9, 1.1), "align": 0.5, "range": 110.0, "shadow": true, "col": true},
}
## Picks per placement class (weights).
const ROCKS := {"RockA": 3.0, "RockB": 4.0, "RockC": 2.0, "Pebbles": 5.0}
const DEBRIS := {"RubbleA": 3.0, "RubbleB": 5.0, "SlabA": 1.5, "Kerb": 2.0, "DrumUp": 1.5, "DrumSide": 1.5, "Girder": 1.0,
	"PipeSeg": 0.7, "Sheet": 2.0, "Planks": 1.5, "Tyre": 1.0, "Reel": 0.6}
const TUFTS := {"TuftA": 3.0, "TuftB": 3.0, "TuftC": 2.0}
## Route lines kept clear (art_src/v5_surface.py KEEP_CLEAR_SEGS in Godot x, z): a -> b, radius.
const ROUTES := [[Vector2(24, 3), Vector2(43, -12), 3.2], [Vector2(18, 3), Vector2(30, 3), 4.5],
	[Vector2(43, -12), Vector2(50, -12), 2.2]]

var _rng := RandomNumberGenerator.new()
var _density := 1.0
var _space: PhysicsDirectSpaceState3D
var _terrain: Array[RID] = []
var _keep_pts: Array = []          # [Vector3, radius]
var _keep_boxes: Array[AABB] = []
var _placed := {}                  # Vector2i cell (2 m) -> Array of [Vector2 xz, r]
var _out := {}                     # piece -> Array[Transform3D]
var _stats := {}                   # rejection counts (printed)
var _noise_grass := FastNoiseLite.new()
var _noise_debris := FastNoiseLite.new()
var _noise_rock := FastNoiseLite.new()

func _initialize() -> void:
	var sd := 17
	for a in OS.get_cmdline_user_args():
		if a.begins_with("seed="):
			sd = int(a.substr(5))
		elif a.begins_with("density="):
			_density = float(a.substr(8))
	_rng.seed = sd
	for n in [_noise_grass, _noise_debris, _noise_rock]:
		n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		n.fractal_octaves = 3
	_noise_grass.seed = sd; _noise_grass.frequency = 0.045
	_noise_debris.seed = sd + 1; _noise_debris.frequency = 0.03
	_noise_rock.seed = sd + 2; _noise_rock.frequency = 0.05
	_run.call_deferred()

func _run() -> void:
	var main: Node = load(SCENE).instantiate()
	for n in ["Player", "Enemies", "ShotTour", "Clutter"]:
		var c := main.get_node_or_null(n)
		if c:
			main.remove_child(c)
			c.free()
	root.add_child(main)
	await physics_frame
	await physics_frame
	_space = main.get_world_3d().direct_space_state
	for path in ["Level/S5_Mesa", "Peak/Peak"]:
		for b in main.get_node(path).find_children("*", "StaticBody3D", true, false):
			_terrain.append((b as StaticBody3D).get_rid())
	print("terrain bodies: ", _terrain.size())
	_collect_keep_clear(main)
	for k in PIECES:
		_out[k] = []
	_scatter()
	var counts := {}
	for k in _out:
		counts[k] = _out[k].size()
	print("placed: ", counts)
	print("samples: ", _stats)
	var box := Rect2(25, -15, 35, 30)
	var inbox := 0
	for k in _out:
		for t in _out[k]:
			if box.has_point(Vector2(t.origin.x, t.origin.z)):
				inbox += 1
	print("in debug box: ", inbox)
	for k in _out:
		if not _out[k].is_empty():
			print("  e.g. %s at %s" % [k, _out[k][_out[k].size() / 2].origin])
	_write()
	quit()

# ------------------------------------------------------------------------------------------------ keep-clear
func _collect_keep_clear(main: Node) -> void:
	for m in main.find_children("*", "Marker3D", true, false):
		_keep_pts.append([(m as Marker3D).global_position, 4.0])
	for a in main.find_children("*", "Area3D", true, false):
		if String(main.get_path_to(a)).begins_with("Safety"):
			continue
		for cs in a.find_children("*", "CollisionShape3D", true, false):
			var bb := _shape_aabb(cs)
			if bb.size != Vector3.ZERO and bb.size.x < 16.0 and bb.size.z < 16.0:
				_keep_boxes.append(bb.grow(1.2))
	# loot crates, pickups and other scripted props stand on the ground: keep a ring round them
	for n in main.find_children("*", "Node3D", true, false):
		var sc := n.get_script() as Script
		if sc and not n is Area3D and (n is StaticBody3D or n is AnimatableBody3D):
			_keep_pts.append([(n as Node3D).global_position, 2.2])
	for n in main.get_node("Loot").get_children():
		_keep_pts.append([(n as Node3D).global_position, 2.2])
	print("keep clear: %d points, %d boxes" % [_keep_pts.size(), _keep_boxes.size()])

func _shape_aabb(cs: CollisionShape3D) -> AABB:
	if cs.shape == null:
		return AABB()
	var local: AABB
	if cs.shape is BoxShape3D:
		var s: Vector3 = cs.shape.size
		local = AABB(-s / 2.0, s)
	elif cs.shape is SphereShape3D:
		var r: float = cs.shape.radius
		local = AABB(Vector3(-r, -r, -r), Vector3(r, r, r) * 2.0)
	elif cs.shape is CylinderShape3D or cs.shape is CapsuleShape3D:
		var r2: float = cs.shape.radius
		var h: float = cs.shape.height
		local = AABB(Vector3(-r2, -h / 2.0, -r2), Vector3(r2 * 2.0, h, r2 * 2.0))
	else:
		return AABB()
	return cs.global_transform * local

func _kept_clear(p: Vector3, r: float) -> bool:
	for k in _keep_pts:
		if Vector2(p.x - k[0].x, p.z - k[0].z).length() < k[1] + r and absf(p.y - k[0].y) < 6.0:
			return true
	for bb in _keep_boxes:
		if bb.grow(r).has_point(p + Vector3(0, 0.5, 0)):
			return true
	var q := Vector2(p.x, p.z)
	for seg in ROUTES:
		var a: Vector2 = seg[0]
		var b: Vector2 = seg[1]
		var t := clampf((q - a).dot(b - a) / (b - a).length_squared(), 0.0, 1.0)
		if (a + (b - a) * t).distance_to(q) < seg[2] + r:
			return true
	return false

# ------------------------------------------------------------------------------------------------ physics probes
func _down(x: float, z: float, top := 140.0) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(Vector3(x, top, z), Vector3(x, -20.0, z), MASK)
	return _space.intersect_ray(q)

func _is_terrain(hit: Dictionary) -> bool:
	return not hit.is_empty() and _terrain.has(hit.rid)

## Nearest non-terrain collision within radius r of p (above ground): 0 = none.
func _structure_near(p: Vector3, r: float) -> bool:
	var sh := SphereShape3D.new()
	sh.radius = r
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = sh
	q.transform = Transform3D(Basis(), p + Vector3(0, r * 0.5 + 0.15, 0))
	q.collision_mask = MASK
	q.exclude = _terrain
	return not _space.intersect_shape(q, 1).is_empty()

## Level enough ground around p for a solid piece: terrain within 0.9 m of p's height at four points `d` out.
func _roomy(p: Vector3, d: float) -> bool:
	for o in [Vector2(d, 0), Vector2(-d, 0), Vector2(0, d), Vector2(0, -d)]:
		var h := _down(p.x + o.x, p.z + o.y, p.y + 4.0)
		if not _is_terrain(h) or absf(h.position.y - p.y) > 0.9:
			return false
	return true

func _overlaps(xz: Vector2, r: float) -> bool:
	var c := Vector2i(floori(xz.x / 2.0), floori(xz.y / 2.0))
	var reach := int(ceil((r + 2.0) / 2.0))
	for i in range(-reach, reach + 1):
		for j in range(-reach, reach + 1):
			for e in _placed.get(c + Vector2i(i, j), []):
				if xz.distance_to(e[0]) < (r + e[1]) * 0.85:
					return true
	return false

func _mark(xz: Vector2, r: float) -> void:
	var c := Vector2i(floori(xz.x / 2.0), floori(xz.y / 2.0))
	if not _placed.has(c):
		_placed[c] = []
	_placed[c].append([xz, r])

# ------------------------------------------------------------------------------------------------ scatter
func _pick(table: Dictionary) -> String:
	var total := 0.0
	for k in table:
		total += table[k]
	var v := _rng.randf() * total
	for k in table:
		v -= table[k]
		if v <= 0.0:
			return k
	return table.keys()[0]

func _scatter() -> void:
	var nx := int(AREA.size.x)
	var nz := int(AREA.size.y)
	for i in nx:
		for j in nz:
			var x := AREA.position.x + i + _rng.randf()
			var z := AREA.position.y + j + _rng.randf()
			var hit := _down(x, z)
			if hit.is_empty():
				continue
			if not _is_terrain(hit):
				_stats["off_terrain"] = _stats.get("off_terrain", 0) + 1
				continue
			var n: Vector3 = hit.normal
			if n.y < 0.6:
				_stats["steep"] = _stats.get("steep", 0) + 1
				continue
			var p: Vector3 = hit.position
			var rk := (_noise_rock.get_noise_2d(x, z) + 1.0) * 0.5
			if n.y < 0.8:
				# scree: stones caught on the slopes (no walking here, so no roomy check)
				_stats["slope"] = _stats.get("slope", 0) + 1
				if _rng.randf() < (0.04 + 0.08 * smoothstep(0.5, 0.8, rk)) * _density:
					_try_place(_pick(ROCKS), p, n, true)
				continue
			_stats["ground"] = _stats.get("ground", 0) + 1
			var g := (_noise_grass.get_noise_2d(x, z) + 1.0) * 0.5
			var d := (_noise_debris.get_noise_2d(x, z) + 1.0) * 0.5
			var rough := 1.0 - smoothstep(0.86, 0.97, n.y)        # broken, sloping ground: rocks
			# chances per square metre for each class
			var c_tuft := 0.4 * smoothstep(0.45, 0.75, g) + 0.025
			var c_rock := 0.025 + 0.07 * smoothstep(0.55, 0.85, rk) + 0.08 * rough
			var c_debris := 0.012 + 0.07 * smoothstep(0.58, 0.85, d)
			var roll := _rng.randf()
			var piece := ""
			if roll < c_tuft * _density:
				piece = _pick(TUFTS)
			elif roll < (c_tuft + c_rock) * _density:
				piece = _pick(ROCKS)
			elif roll < (c_tuft + c_rock + c_debris) * _density:
				piece = _pick(DEBRIS)
			elif _rng.randf() < 0.25 * _density and _structure_near(p, 5.0):
				piece = _pick(DEBRIS)      # rubble collects along the works' walls
			if piece == "":
				continue
			_try_place(piece, p, n)

func _try_place(piece: String, p: Vector3, n: Vector3, slope := false) -> void:
	var cfg: Dictionary = PIECES[piece]
	var sc := _rng.randf_range(cfg.s.x, cfg.s.y)
	var r: float = cfg.r * sc
	var xz := Vector2(p.x, p.z)
	if _kept_clear(p, r if cfg.col else 0.0):
		_stats["kept_clear"] = _stats.get("kept_clear", 0) + 1
		return
	if _overlaps(xz, r):
		_stats["overlap"] = _stats.get("overlap", 0) + 1
		return
	if cfg.col:
		if _structure_near(p, r + CLEAR_PAD):
			_stats["col_near_structure"] = _stats.get("col_near_structure", 0) + 1
			return
		if not slope and not _roomy(p, 2.4):
			_stats["col_not_roomy"] = _stats.get("col_not_roomy", 0) + 1
			return
	elif r > 0.4 and _structure_near(p, r * 0.6):
		_stats["near_structure"] = _stats.get("near_structure", 0) + 1
		return
	var up := Vector3.UP.slerp(n, cfg.align).normalized()
	var tilt := Basis(Quaternion(Vector3.UP, up)) if up.dot(Vector3.UP) < 0.9999 else Basis()
	var b := tilt * Basis(Vector3.UP, _rng.randf() * TAU) * Basis.from_scale(Vector3.ONE * sc)
	var sink: float = cfg.get("sink", 0.0) * sc
	_out[piece].append(Transform3D(b, p - up * sink))
	_mark(xz, r)

# ------------------------------------------------------------------------------------------------ output
func _local_mesh(src: Mesh) -> ArrayMesh:
	var m: ArrayMesh = src.duplicate()
	for s in m.get_surface_count():
		var mat := m.surface_get_material(s)
		if mat:
			m.surface_set_material(s, mat.duplicate())
	return m

func _write() -> void:
	var kit: Node = load(KIT).instantiate()
	var meshes := {}
	for mi in kit.find_children("*", "MeshInstance3D", true, false):
		meshes[String(mi.name)] = _local_mesh((mi as MeshInstance3D).mesh)
	var out := Node3D.new()
	out.name = "Clutter"
	out.set_script(load("res://scripts/clutter.gd"))
	var body := StaticBody3D.new()
	body.name = "Collision"
	out.add_child(body)
	var shapes := {}
	var n_col := 0
	for piece in PIECES:
		var cfg: Dictionary = PIECES[piece]
		if not meshes.has(piece):
			push_error("clutter.glb has no " + piece)
			continue
		var cells := {}
		for t: Transform3D in _out[piece]:
			var c := Vector2i(floori(t.origin.x / CHUNK), floori(t.origin.z / CHUNK))
			if not cells.has(c):
				cells[c] = []
			cells[c].append(t)
			if cfg.col:
				if not shapes.has(piece):
					shapes[piece] = (meshes[piece] as ArrayMesh).create_convex_shape(true, true)
				var cs := CollisionShape3D.new()
				cs.name = "%s_%d" % [piece, n_col]
				cs.shape = shapes[piece]
				cs.transform = t
				body.add_child(cs)
				n_col += 1
		for c in cells:
			var centre := Vector3((c.x + 0.5) * CHUNK, 0.0, (c.y + 0.5) * CHUNK)
			var list: Array = cells[c]
			centre.y = list[0].origin.y
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = meshes[piece]
			mm.instance_count = list.size()
			var maabb: AABB = (meshes[piece] as ArrayMesh).get_aabb()
			var bounds := AABB()
			var xf := PackedFloat32Array()
			for k in list.size():
				var t: Transform3D = list[k]
				var lt := Transform3D(t.basis, t.origin - centre)
				for v in [lt.basis.x, lt.basis.y, lt.basis.z, lt.origin]:
					xf.append_array([v.x, v.y, v.z])
				bounds = (lt * maabb) if k == 0 else bounds.merge(lt * maabb)
			mm.custom_aabb = bounds      # (else the loaded MultiMesh can cull as if it were empty)
			var mmi := MultiMeshInstance3D.new()
			mmi.name = "%s_%d_%d" % [piece, c.x, c.y]
			mmi.multimesh = mm
			mmi.set_meta("xf", xf)          # scripts/clutter.gd fills the MultiMesh (a headless bake can't store it)
			mmi.position = centre
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if cfg.shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mmi.visibility_range_end = cfg.range + CHUNK * 0.71
			mmi.visibility_range_end_margin = 4.0
			out.add_child(mmi)
	for c in out.find_children("*", "", true, false):
		c.owner = out
	var ps := PackedScene.new()
	var err := ps.pack(out)
	if err == OK:
		err = ResourceSaver.save(ps, OUT)
	print("wrote ", OUT, " (", n_col, " collision shapes) err=", err)
	kit.free()
	out.free()