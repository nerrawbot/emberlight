extends SceneTree
## v18: sticks weathering and signage decals on the surface works' walls and writes res://scenes/surface_decals.tscn
## (instanced in surface.tscn as "Decals"). Textures come from tools/make_decals.gd (assets/decals/).
## From open ground (terrain ray hits on a 2 m grid) it casts level rays in 8 directions; a hit on the works' collision
## (S5_Works, the Peak's hall) facing sideways is a candidate. Each decal checks its own rectangle is flat wall (rays at
## the corners hit the same body, same plane), picks a kind by what fits: soot/rust/damp stains along the foot of the
## wall, leaks running down from higher up, posters at eye height, stencilled codes, hazard bands, arrows.
## tools\godot.cmd --headless --script res://tools/bake_decals.gd [-- seed=N]

const SCENE := "res://scenes/surface.tscn"
const OUT := "res://scenes/surface_decals.tscn"
const AREA := Rect2(-165.0, -100.0, 325.0, 300.0)
const STEP := 2.0
const SPACING := 2.6           # min distance between decal centres
const DIR := "res://assets/decals/"
## kind: [weight, textures, width range, height (m) or -1 = from the texture aspect, centre height above ground range]
const KINDS := {
	"stain": [5.0, ["stain_soot", "stain_rust", "stain_damp"], Vector2(1.4, 2.6), 0.0, Vector2(0.35, 0.8)],
	"leak": [3.5, ["leak_rust", "leak_soot"], Vector2(0.7, 1.2), 0.0, Vector2(1.6, 3.2)],
	"poster": [1.3, ["poster_red", "poster_blue"], Vector2(0.55, 0.7), -1.0, Vector2(1.45, 1.75)],
	"stencil": [1.6, ["stencil_b2", "stencil_k9", "stencil_04", "stencil_17", "stencil_c3", "stencil_no_entry", "stencil_keep_clear"], Vector2(0.0, 0.0), 0.5, Vector2(1.9, 2.8)],
	"hazard": [0.9, ["hazard"], Vector2(1.4, 2.2), -1.0, Vector2(0.55, 0.9)],
	"arrow": [0.6, ["arrow"], Vector2(0.7, 1.0), -1.0, Vector2(1.3, 1.6)],
}

var _rng := RandomNumberGenerator.new()
var _space: PhysicsDirectSpaceState3D
var _terrain: Array[RID] = []
var _walls: Array[RID] = []
var _placed: Array[Vector3] = []
var _tex := {}

func _initialize() -> void:
	var sd := 18
	for a in OS.get_cmdline_user_args():
		if a.begins_with("seed="):
			sd = int(a.substr(5))
	_rng.seed = sd
	_run.call_deferred()

func _run() -> void:
	var main: Node = load(SCENE).instantiate()
	for n in ["Player", "Enemies", "ShotTour", "Decals"]:
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
	for path in ["Level/S5_Works", "Peak/PeakWorks"]:
		for b in main.get_node(path).find_children("*", "StaticBody3D", true, false):
			_walls.append((b as StaticBody3D).get_rid())
	for k in KINDS:
		for t in KINDS[k][1]:
			_tex[t] = load(DIR + t + ".png")
	var out := Node3D.new()
	out.name = "Decals"
	var counts := {}
	var dirs: Array[Vector3] = []
	for i in 8:
		dirs.append(Vector3(cos(i * TAU / 8.0), 0.0, sin(i * TAU / 8.0)))
	for i in int(AREA.size.x / STEP):
		for j in int(AREA.size.y / STEP):
			var x := AREA.position.x + (i + _rng.randf()) * STEP
			var z := AREA.position.y + (j + _rng.randf()) * STEP
			var down := _ray(Vector3(x, 140.0, z), Vector3(x, -20.0, z))
			if down.is_empty() or not _terrain.has(down.rid) or down.normal.y < 0.85:
				continue
			var g: Vector3 = down.position
			var first := _rng.randi() % 8
			for di in 8:
				var d: Vector3 = dirs[(first + di) % 8]
				var hit := _ray(g + Vector3(0, 1.2, 0), g + Vector3(0, 1.2, 0) + d * 7.0)
				if hit.is_empty() or not _walls.has(hit.rid) or absf(hit.normal.y) > 0.15:
					continue
				var kind := _place(out, hit, g.y)
				if kind != "":
					counts[kind] = counts.get(kind, 0) + 1
	print("decals: ", counts)
	for c in out.get_children():
		c.owner = out
	var ps := PackedScene.new()
	var err := ps.pack(out)
	if err == OK:
		err = ResourceSaver.save(ps, OUT)
	print("wrote ", OUT, " err=", err)
	out.free()
	quit()

func _ray(a: Vector3, b: Vector3) -> Dictionary:
	return _space.intersect_ray(PhysicsRayQueryParameters3D.create(a, b, 1))

func _pick() -> String:
	var total := 0.0
	for k in KINDS:
		total += KINDS[k][0]
	var v := _rng.randf() * total
	for k in KINDS:
		v -= KINDS[k][0]
		if v <= 0.0:
			return k
	return "stain"

## Is the w x h rectangle centred on c (on the wall with normal n, along = a) flat wall of body rid?
func _flat(c: Vector3, n: Vector3, a: Vector3, w: float, h: float, rid: RID) -> bool:
	for o in [Vector2(0, 0), Vector2(-0.5, -0.5), Vector2(0.5, -0.5), Vector2(-0.5, 0.5), Vector2(0.5, 0.5), Vector2(0, 0.5), Vector2(0, -0.5)]:
		var p: Vector3 = c + a * o.x * w + Vector3.UP * o.y * h
		var hit := _ray(p + n * 0.4, p - n * 0.4)
		if hit.is_empty() or hit.rid != rid or hit.normal.dot(n) < 0.97 or absf((hit.position - p).dot(n)) > 0.08:
			return false
	return true

func _place(out: Node3D, hit: Dictionary, ground_y: float) -> String:
	var n: Vector3 = hit.normal
	n = Vector3(n.x, 0.0, n.z).normalized()
	var along := Vector3.UP.cross(n).normalized()
	for attempt in 2:
		var kind := _pick() if attempt == 0 else "stain"
		var k: Array = KINDS[kind]
		var tname: String = k[1][_rng.randi() % k[1].size()]
		var tex: Texture2D = _tex[tname]
		var aspect := float(tex.get_height()) / tex.get_width()
		var w: float
		var h: float
		if kind == "stencil":
			h = k[3] * _rng.randf_range(0.85, 1.25)
			w = h / aspect
		else:
			w = _rng.randf_range(k[2].x, k[2].y)
			h = w * aspect if k[3] < 0.0 else (w * aspect if kind == "leak" else w * _rng.randf_range(0.55, 0.8))
		var cy := ground_y + _rng.randf_range(k[4].x, k[4].y)
		if kind == "leak":
			cy = ground_y + _rng.randf_range(k[4].x, k[4].y) + h * 0.15
		var c: Vector3 = hit.position
		c.y = cy
		c += along * _rng.randf_range(-0.6, 0.6)
		var near := false
		for p in _placed:
			if p.distance_to(c) < SPACING:
				near = true
				break
		if near:
			return ""
		if not _flat(c, n, along, w, h, hit.rid):
			continue
		var dcl := Decal.new()
		dcl.name = "%s_%d" % [tname, _placed.size()]
		dcl.texture_albedo = tex
		dcl.size = Vector3(w, 0.6, h)
		var z := -Vector3.UP            # texture top (v = 0, at -Z) points up the wall
		dcl.transform = Transform3D(Basis(n.cross(z), n, z), c)
		dcl.upper_fade = 0.2
		dcl.lower_fade = 0.2
		dcl.normal_fade = 0.6
		dcl.cull_mask = 1
		dcl.distance_fade_enabled = true
		dcl.distance_fade_begin = 38.0
		dcl.distance_fade_length = 14.0
		var v := _rng.randf_range(0.8, 1.0)
		dcl.modulate = Color(v, v, v, 1.0 if kind in ["poster", "stencil", "hazard", "arrow"] else _rng.randf_range(0.75, 1.0))
		out.add_child(dcl)
		_placed.append(c)
		return kind
	return ""