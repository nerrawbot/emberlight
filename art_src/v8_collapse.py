
# v8: the stair-3 collapse. Fallen slabs and rubble choke the top of stair 3, so the stairs no longer link the cavern and
# the surface (the lift is the only way up). One plug serves both scenes (they share a coordinate frame here):
#   main.tscn    - from the stair you see a debris talus burying the upper flight and the plug's underside overhead,
#                  with a few pinholes of daylight (tilted along main's SurfaceSun, so they throw thin light shafts).
#   surface.tscn - from the well's railings you see a rubble heap just below grade; the same pinholes show the dark below.
# The plug covers main's whole opening at grade (x 32..46.8, y 0.3..7.7) and tucks under its rim; its top stays below
# G everywhere, so in surface.tscn everything outside the well is hidden under the terrain.
# Built in Blender scene "Surface5" (collection S8_CollapseC), exported to assets/level/collapse.glb:
#   Collapse-col (mesh + trimesh), CollapseBlock-colonly (stops anyone squeezing between the talus and the plug).
# Run: exec(open(r"...\art_src\v8_collapse.py").read()); build_collapse(); export_collapse()   (Surface5 active for export)
exec(open(r"D:\Emberlight\art_src\v5_surface.py").read())

C8 = dict(
    x0=31.6, x1=47.4, y0=-0.1, y1=8.1,      # plug footprint
    top=G - 0.6, bot=G - 2.35,              # mean top / underside heights
    well=(34.3, 46.2, 0.68, 5.72),          # surface well: rubble detail on top only inside this
    # pinholes: top-cell centres (x, y, cells along y). Each runs down-east through the plug, in line with the view of
    # someone on main's stair looking up the flight, so they show sky from below (main.tscn adds a thin spot beam
    # down each one: CollapseBeams)
    holes=[(40.0, 1.9, 1), (41.6, 4.3, 2), (43.4, 2.5, 1), (40.9, 3.4, 1), (44.2, 4.6, 1)],
    sun=(0.85, 0.0),       # bottom offset per metre of depth
    # main's stair 3 ramp: z = 25 + (47.5 - x) * k, y 2.2..4.2
    stair_k=(34.3 - 25.0) / (47.5 - 34.0),
    toe=41.3,                               # where the talus meets the stair
)

def stair_z(x):
    return 25.0 + (47.5 - x) * C8["stair_k"]

def _n(x, y, f, s):
    return noise.fractal(Vector((x * f + s, y * f - s, s * 0.37)), 0.55, 2.0, 3, noise_basis='PERLIN_ORIGINAL')

def plug_mesh(cat):
    """Closed heightfield slab: jagged top + jagged underside + perimeter walls, with tilted through-holes."""
    x0, x1, y0, y1 = C8["x0"], C8["x1"], C8["y0"], C8["y1"]
    nx, ny = 53, 28
    dx, dy = (x1 - x0) / nx, (y1 - y0) / ny
    def top_h(x, y):
        h = C8["top"] + 0.32 * _n(x, y, 0.35, 3.1) + 0.12 * _n(x, y, 1.4, 7.7)
        return min(G - 0.18, h)
    def bot_h(x, y):
        h = C8["bot"] + 0.4 * _n(x, y, 0.3, 11.3) - 0.35 * max(0.0, _n(x, y, 0.9, 5.5))   # sagging lumps
        return h
    bm = bmesh.new()
    T = [[None] * (ny + 1) for _ in range(nx + 1)]
    B = [[None] * (ny + 1) for _ in range(nx + 1)]
    rnd = random.Random(8)
    for i in range(nx + 1):
        for j in range(ny + 1):
            x = x0 + i * dx; y = y0 + j * dy
            edge = i in (0, nx) or j in (0, ny)
            jx = 0.0 if edge else rnd.uniform(-0.06, 0.06); jy = 0.0 if edge else rnd.uniform(-0.06, 0.06)
            T[i][j] = bm.verts.new((x + jx, y + jy, top_h(x, y)))
            B[i][j] = bm.verts.new((x - jx, y - jy, bot_h(x, y)))
    # hole cells: top (i, j) -> bottom (i + si, j + sj)
    th = 1.75
    si = int(round(C8["sun"][0] * th / dx)); sj = int(round(C8["sun"][1] * th / dy))
    top_holes = {}; bot_holes = set()
    for (hx, hy, n) in C8["holes"]:
        i = int((hx - x0) / dx); j = int((hy - y0) / dy)
        for k in range(n):
            top_holes[(i, j + k)] = (i + si, j + k + sj)
            bot_holes.add((i + si, j + k + sj))
    fT = []; fB = []
    for i in range(nx):
        for j in range(ny):
            if (i, j) not in top_holes:
                fT.append(bm.faces.new((T[i][j], T[i + 1][j], T[i + 1][j + 1], T[i][j + 1])))
            if (i, j) not in bot_holes:
                fB.append(bm.faces.new((B[i][j], B[i][j + 1], B[i + 1][j + 1], B[i + 1][j])))
    # hole tubes (skip the shared edges of multi-cell cracks: only the outline gets walls)
    for (ti, tj), (bi, bj) in top_holes.items():
        ring_t = [T[ti][tj], T[ti + 1][tj], T[ti + 1][tj + 1], T[ti][tj + 1]]
        ring_b = [B[bi][bj], B[bi + 1][bj], B[bi + 1][bj + 1], B[bi][bj + 1]]
        nb = [(ti, tj - 1), (ti + 1, tj), (ti, tj + 1), (ti - 1, tj)]       # neighbour across each edge
        for k in range(4):
            if nb[k] in top_holes and nb[k] != (ti, tj):
                if k in (0, 2):          # crack runs along y: shared edges are the j-edges
                    continue
            a, b = k, (k + 1) % 4
            bm.faces.new((ring_t[a], ring_b[a], ring_b[b], ring_t[b]))
    # perimeter walls
    def wall(ts, bs):
        for k in range(len(ts) - 1):
            bm.faces.new((ts[k], bs[k], bs[k + 1], ts[k + 1]))
    wall([T[i][0] for i in range(nx + 1)], [B[i][0] for i in range(nx + 1)])
    wall([T[i][ny] for i in range(nx, -1, -1)], [B[i][ny] for i in range(nx, -1, -1)])
    wall([T[0][j] for j in range(ny, -1, -1)], [B[0][j] for j in range(ny, -1, -1)])
    wall([T[nx][j] for j in range(ny + 1)], [B[nx][j] for j in range(ny + 1)])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    # concrete slabs with rock between (by noise patches)
    for f in bm.faces:
        c = f.calc_center_median()
        f.material_index = 1 if _n(c.x, c.y, 0.45, 21.0) > 0.12 else 0
    ob = mk_obj("plug", bm, "M_Concrete", cat); ob.data.materials.append(M("M_Rock"))
    for (ti, tj), (bi, bj) in top_holes.items():       # beam placement for build_main / main.tscn
        bx, by = x0 + (bi + 0.5) * dx, y0 + (bj + 0.5) * dy
        print("hole top (%.2f, %.2f, %.2f) bottom (%.2f, %.2f, %.2f)" % (x0 + (ti + 0.5) * dx, y0 + (tj + 0.5) * dy, top_h(x0 + (ti + 0.5) * dx, y0 + (tj + 0.5) * dy),
                                                                      bx, by, bot_h(bx, by)))
    return ob, [(x0 + (i + 0.5) * dx, y0 + (j + 0.5) * dy) for (i, j) in top_holes]

def clear_of_holes(x, y, holes, r):
    return all((x - hx) ** 2 + (y - hy) ** 2 > r * r for (hx, hy) in holes)

def tilted_slab(cat, c, size, rot, mat="M_Concrete", name="slab"):
    ob = boxmm(cat, mat, -size[0] / 2, size[0] / 2, -size[1] / 2, size[1] / 2, -size[2] / 2, size[2] / 2, name, 0.03)
    ob.location = c; ob.rotation_euler = rot
    return ob

def talus(cat):
    """The debris that slid down main's stair 3: a heap from the toe up to the plug's underside, a fallen slab on top."""
    rnd = random.Random(81)
    toe = C8["toe"]
    cap = C8["bot"] + 0.45                                  # never above the plug's underside (hidden in surface.tscn)
    for k in range(46):
        x = rnd.uniform(37.0, toe)                          # west of ~37.4 the stair is already above the plug's underside
        y = rnd.uniform(0.5, 7.4)
        zs = stair_z(x)
        rise = min(4.6, (toe - x) * 1.25 + 0.4)            # ~50 deg face rising west from the toe
        s = rnd.uniform(0.6, 1.5)
        sz = max(0.5, rise * 0.45)
        cz = min(zs + rise * rnd.uniform(0.35, 0.8), cap - sz * 0.8)
        rockblob(cat, (x, y, cz), (s * rnd.uniform(1.0, 1.6), s * rnd.uniform(0.9, 1.4), sz),
                 amp=0.45, seed=800 + k, sub=2, mat=rnd.choice(("M_Rock", "M_Concrete", "M_Rock")), name="talus")
    # small stuff spilling down the treads below the toe
    for k in range(14):
        x = rnd.uniform(toe - 0.2, toe + 2.6); y = rnd.uniform(2.3, 4.1); s = rnd.uniform(0.12, 0.32)
        rockblob(cat, (x, y, stair_z(x) + s * 0.5), (s * 1.3, s, s * 0.8), amp=0.4, seed=860 + k, sub=1, mat="M_Concrete", name="chip")
    # two big slabs leaning on the heap (the stairwell lid that came down first)
    tilted_slab(cat, (38.9, 2.6, stair_z(38.9) + 1.2), (4.2, 2.6, 0.28), (math.radians(8), math.radians(-42), math.radians(4)))
    tilted_slab(cat, (38.0, 4.4, stair_z(38.0) + 0.6), (3.6, 2.2, 0.26), (math.radians(-12), math.radians(-48), math.radians(-9)))
    # the old stair's upper stringers sticking out of the heap, bent
    for (y, s) in ((2.2, 1), (4.2, -1)):
        a = Vector((toe + 0.4, y, stair_z(toe + 0.4) - 0.15))
        member(cat, "M_Steel", a, a + Vector((-2.2, 0.15 * s, 1.9)), 0.08, 0.3, "stringer")

def underside(cat, holes):
    """Hanging rebar and a sagging sheet of grating under the plug (seen from main's stair)."""
    rnd = random.Random(82)
    n = 0
    while n < 34:
        x = rnd.uniform(37.0, 47.0); y = rnd.uniform(0.6, 7.4)
        if not clear_of_holes(x - 1.5, y, holes, 0.8): continue
        a = Vector((x, y, C8["bot"] + 0.2))
        member(cat, "M_Rust", a, a + Vector((rnd.uniform(-0.4, 0.4), rnd.uniform(-0.4, 0.4), -rnd.uniform(0.5, 1.6))), 0.03, 0.03, "rebar")
        n += 1
    tilted_slab(cat, (45.2, 6.6, C8["bot"] - 0.35), (2.4, 1.4, 0.05), (math.radians(14), math.radians(9), 0.3), mat="M_Grate", name="sag")

def heap_top(cat, holes):
    """Visible from the surface: broken slabs, rubble and rebar on the plug, inside the well, all below grade."""
    wx0, wx1, wy0, wy1 = C8["well"]
    rnd = random.Random(83)
    n = 0
    while n < 9:     # slab fragments, tipped every which way
        x = rnd.uniform(wx0 + 1.0, wx1 - 1.0); y = rnd.uniform(wy0 + 0.9, wy1 - 0.9)
        if not clear_of_holes(x, y, holes, 1.3): continue
        sx, sy = rnd.uniform(1.2, 2.6), rnd.uniform(0.9, 1.8)
        tilted_slab(cat, (x, y, G - 0.75), (sx, sy, 0.22), (rnd.uniform(-0.3, 0.3), rnd.uniform(-0.25, 0.25), rnd.uniform(0, 3.14)))
        n += 1
    n = 0
    while n < 30:    # rubble
        x = rnd.uniform(wx0 + 0.3, wx1 - 0.3); y = rnd.uniform(wy0 + 0.3, wy1 - 0.3)
        if not clear_of_holes(x, y, holes, 0.6): continue
        s = rnd.uniform(0.18, 0.5)
        rockblob(cat, (x, y, G - 0.75 + s * 0.2), (s * 1.4, s, s * 0.6), amp=0.4, seed=900 + n, sub=1,
                 mat=rnd.choice(("M_Concrete", "M_Rock")), name="rubble")
        n += 1
    for k in range(10):
        x = rnd.uniform(wx0 + 0.8, wx1 - 0.8); y = rnd.uniform(wy0 + 0.6, wy1 - 0.6)
        a = Vector((x, y, G - 0.8))
        member(cat, "M_Rust", a, a + Vector((rnd.uniform(-0.6, 0.6), rnd.uniform(-0.6, 0.6), rnd.uniform(0.25, 0.6))), 0.03, 0.03, "rebar")
    # a twisted length of the old handrail
    member(cat, "M_Steel", (36.2, 1.4, G - 0.62), (39.4, 1.9, G - 0.45), 0.05, 0.05, "rail_bit")
    member(cat, "M_Steel", (39.4, 1.9, G - 0.45), (40.1, 2.9, G - 0.7), 0.05, 0.05, "rail_bit")

def build_collapse():
    cat = "S8_CollapseC"; s5coll(cat)
    plug, holes = plug_mesh(cat)
    talus(cat)
    underside(cat, holes)
    heap_top(cat, holes)
    ob = merge_into("Collapse-col", cat)
    # stops anyone squeezing up between the talus and the plug (main); buried and harmless in surface.tscn
    cb = "S8_CollapseBlockC"; s5coll(cb)
    boxmm(cb, None, 35.6, 39.8, -0.2, 8.2, 26.5, G - 1.1, "block", 0.0)
    blk = merge_into("CollapseBlock-colonly", cb, uv=False)
    blk.data.materials.clear()
    print("collapse built:", len(ob.data.vertices), "verts; holes", [tuple(round(v, 2) for v in h) for h in holes])
    return ob

def export_collapse():
    sc = bpy.context.scene
    names = ["Collapse-col", "CollapseBlock-colonly"]
    for o in sc.objects:
        o.select_set(o.name in names)
    bpy.ops.export_scene.gltf(filepath=os.path.join(PROJ, "assets", "level", "collapse.glb"), export_format='GLB',
                              use_selection=True, use_active_scene=True, export_apply=True, export_yup=True)
    print("exported collapse.glb from", sc.name)
