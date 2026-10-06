
# v5: the surface - a dark-blue mesa under warm, yellow haze (after the reference painting: industrial ruins on a
# plateau, tall misty spires behind). Built in its own Blender scene "Surface5", exported to assets/level/surface.glb.
# Shares main.tscn's coordinate frame around the lift headframe (Lift3-col is reused as-is) and the stair-3 gate,
# so arriving by lift or by the stairs lines up with the cavern below.
#
# Route (Blender coords, Z up; ground G = 34.3):
#   lift landing (24, -3) -> east across the plateau -> stair 1 up to the gallery deck Z40 (X 50..62, Y 9..24)
#   -> link deck south along bunker A -> K-braced tower, stair 2 up to Z46 -> gantry catwalk south (X 57..59)
#   -> block C roof Z46 (X 54..67, Y -38..-27): the lookout over the cliff edge.
#   Stair 3 pit (X 34.3..46.2, Y 0.68..5.72) leads back down to the cavern (scene change a few steps down).
#
# Run: exec(open(r"...\art_src\v5_surface.py").read()); build_all(); export_all()
exec(open(r"C:\Users\Pigeon\Documents\UnderworksCavern\art_src\gen_lib.py").read())
import json

if "Surface5" not in bpy.data.scenes:
    bpy.data.scenes.new("Surface5")
S5 = bpy.data.scenes["Surface5"]
for k in ("blendermcp_use_polyhaven", "blendermcp_use_sketchfab", "blendermcp_use_polypizza"):
    if hasattr(S5, k): setattr(S5, k, True)

G = 34.3
CENTER = Vector((32.0, -6.0))
L5 = dict(
    ground=G,
    lift=(18.6, 22.8, -5.8, -0.8),
    pit=(34.3, 46.2, 0.68, 5.72), pit_floor=26.6,
    gallery=(50.0, 62.0, 9.0, 24.0, 40.0),
    stair1=((43.0, 12.0, G), (50.0, 12.0, 40.0)),
    link=(57.5, 61.5, -0.2, 9.2, 40.0),
    tower=(55.0, 61.0, -11.0, -0.2),
    stair2=((58.0, -0.6, 40.0), (58.0, -8.4, 46.0)),    # in line with the gantry (X 57..59)
    top_deck=(55.0, 61.0, -11.0, -8.4, 46.0),
    gantry=(57.0, 59.0, -27.0, -11.0, 46.0),
    blockC=(54.0, 67.0, -38.0, -27.0, 46.0),
    lookout=(60.5, -36.6),
)

def s5coll(name):
    c = bpy.data.collections.get(name)
    if c is None:
        c = bpy.data.collections.new(name); S5.collection.children.link(c)
    elif c.name not in S5.collection.children:
        S5.collection.children.link(c)
    for o in list(c.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    return c

def merge_into(name, C, uv=True):
    """Join every mesh of collection C into one object (bmesh; works outside the context view layer)."""
    objs = [o for o in bpy.data.collections[C].objects if o.type == 'MESH']
    mats = []; bm = bmesh.new()
    for o in objs:
        nv, nf = len(bm.verts), len(bm.faces)
        bm.from_mesh(o.data)
        bm.verts.ensure_lookup_table(); bm.faces.ensure_lookup_table()
        rot = o.rotation_quaternion if o.rotation_mode == 'QUATERNION' else o.rotation_euler.to_quaternion()
        bmesh.ops.transform(bm, matrix=Matrix.LocRotScale(o.location, rot, o.scale), verts=bm.verts[nv:])
        remap = []
        for m in o.data.materials:
            if m not in mats: mats.append(m)
            remap.append(mats.index(m) if m else 0)
        for f in bm.faces[nf:]:
            f.material_index = remap[f.material_index] if remap else 0
    old = bpy.data.objects.get(name)
    if old: bpy.data.objects.remove(old, do_unlink=True)
    me = bpy.data.meshes.new(name); bm.to_mesh(me); bm.free()
    for m in mats:
        if m: me.materials.append(m)
    for o in objs: bpy.data.objects.remove(o, do_unlink=True)
    ob = bpy.data.objects.new(name, me); bpy.data.collections[C].objects.link(ob)
    if uv and me.materials: box_uv(ob)
    return ob

def mats5():
    pbr_mat("M_MesaCliff", "mesa_cliff_albedo.jpg", "mesa_cliff_orm.jpg", "mesa_cliff_normal.jpg", 1.2)
    pbr_mat("M_MesaGround", "mesa_ground_albedo.jpg", "mesa_ground_orm.jpg", "mesa_ground_normal.jpg", 1.0)
    flat_mat("M_Grass", (0.42, 0.56, 0.16), rough=0.8, double=True)
    flat_mat("M_GrassDry", (0.55, 0.52, 0.22), rough=0.85, double=True)
    flat_mat("M_PalePipe", (0.52, 0.5, 0.56), rough=0.55, metal=0.2)
    # (flat_mat keeps an existing material: push the tuned values every build)
    for n, col in (("M_Grass", (0.5, 0.7, 0.16)), ("M_GrassDry", (0.66, 0.62, 0.24)), ("M_PalePipe", (0.36, 0.35, 0.42))):
        b = next(x for x in M(n).node_tree.nodes if x.type == 'BSDF_PRINCIPLED')
        b.inputs["Base Color"].default_value = (*col, 1); M(n).diffuse_color = (*col, 1)
    flat_mat("M_Spire", (0.12, 0.13, 0.2), rough=0.95)

# ---------------------------------------------------------------- terrain helpers
def rim_radius(th):
    """Mesa outline (distance from CENTER). A bite out of the south-east puts the cliff right below the lookout."""
    n = noise.fractal(Vector((math.cos(th) * 1.3, math.sin(th) * 1.3, 4.2)), 0.6, 2.0, 3, noise_basis='PERLIN_ORIGINAL')
    r = 66.0 + 11.0 * n
    bite = math.exp(-((math.atan2(math.sin(th + 0.95), math.cos(th + 0.95))) / 0.32) ** 2)   # centred on -54 deg
    return r - 19.0 * bite

FLAT = [(8, 30, -12, 6), (30, 50, -3, 10), (40, 75, -42, 28)]

def flat_mask(x, y):
    d = 1e9
    for (x0, x1, y0, y1) in FLAT:
        dx = max(x0 - x, 0, x - x1); dy = max(y0 - y, 0, y - y1)
        d = min(d, math.hypot(dx, dy))
    t = min(1.0, d / 14.0)
    return t * t * (3 - 2 * t)

def ground_h(x, y, rr):
    """Height of the plateau top. rr = r / rim radius (0 centre .. 1 rim)."""
    m = flat_mask(x, y)
    n = noise.fractal(Vector((x * 0.035, y * 0.035, 1.7)), 0.55, 2.0, 4, noise_basis='PERLIN_ORIGINAL')
    small = noise.fractal(Vector((x * 0.16, y * 0.16, 7.3)), 0.5, 2.0, 2, noise_basis='PERLIN_ORIGINAL')
    h = G + 0.25 * small * (0.3 + m) + (2.2 * n + 0.6) * m
    lip = max(0.0, rr - 0.86) / 0.14           # rocky lip rising at the rim
    h += lip * lip * 2.2 * (0.6 + 0.8 * max(0.0, n + 0.3)) * m
    return h

# ---------------------------------------------------------------- the plateau + cliffs
def mesa():
    C = "S5_MesaC"; s5coll(C)
    bm = bmesh.new()
    N = 128
    fr = [0.0, 0.04, 0.09, 0.15, 0.22, 0.29, 0.36, 0.43, 0.5, 0.56, 0.62, 0.68, 0.73, 0.78, 0.82, 0.86, 0.9, 0.93, 0.96, 0.98, 1.0]
    rims = [rim_radius(2 * math.pi * k / N) for k in range(N)]
    top_rings = []
    for f in fr:
        ring = []
        for k in range(N):
            th = 2 * math.pi * k / N
            r = rims[k] * f
            x = CENTER.x + r * math.cos(th); y = CENTER.y + r * math.sin(th)
            ring.append(bm.verts.new((x, y, ground_h(x, y, f))))
            if f == 0.0: break
        top_rings.append(ring)
    # cliff: drop from the rim with strata ledges, flaring into a talus at the bottom
    drops = [0.6, 1.8, 3.5, 6.0, 9.0, 13.0, 18.0, 24.0, 31.0, 40.0, 52.0, 68.0, 90.0, 120.0]
    cliff = [top_rings[-1]]
    for di, dz in enumerate(drops):
        ring = []
        for k in range(N):
            th = 2 * math.pi * k / N
            rv = top_rings[-1][k].co
            z = rv.z - dz
            st = noise.fractal(Vector((math.cos(th) * 2.5, math.sin(th) * 2.5, z * 0.09)), 0.55, 2.0, 3, noise_basis='PERLIN_ORIGINAL')
            ledge = 0.9 * math.sin(z * 0.55 + st * 2.0)               # banded strata
            r = rims[k] + 1.6 * st + ledge - (0.8 if dz < 2.0 else 0.0) + max(0.0, dz - 30.0) * 0.55
            ring.append(bm.verts.new((CENTER.x + r * math.cos(th), CENTER.y + r * math.sin(th), z)))
        cliff.append(ring)
    def bridge(a, b, mat_idx):
        for k in range(N):
            if len(a) == 1:
                f = bm.faces.new((a[0], b[k], b[(k + 1) % N]))
            else:
                f = bm.faces.new((a[k], a[(k + 1) % N], b[(k + 1) % N], b[k]))
            f.material_index = mat_idx
    for i in range(len(top_rings) - 1):
        bridge(top_rings[i], top_rings[i + 1], 0)
    for i in range(len(cliff) - 1):
        bridge(cliff[i], cliff[i + 1], 1)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    for f in bm.faces:
        f.smooth = True
    me = bpy.data.meshes.new("plateau"); bm.to_mesh(me); bm.free()
    me.materials.append(M("M_MesaGround")); me.materials.append(M("M_MesaCliff"))
    ob = bpy.data.objects.new("plateau", me); bpy.data.collections[C].objects.link(ob)
    # holes: lift shaft and the stair-3 well
    lx0, lx1, ly0, ly1 = L5["lift"]
    carve_box(ob, (lx0 + 0.02, ly0 + 0.02, G - 3.0), (lx1 - 0.02, ly1 - 0.02, G + 3.0), pad=3.0)
    px0, px1, py0, py1 = L5["pit"]
    carve_box(ob, (px0, py0, G - 3.0), (px1, py1, G + 3.0), pad=3.0)
    # outcrops along the rim and a few boulders on the plateau (none on the route)
    rnd = random.Random(5)
    for i in range(46):
        k = rnd.randrange(N); th = 2 * math.pi * k / N
        r = rims[k] * rnd.uniform(0.9, 0.99)
        x = CENTER.x + r * math.cos(th); y = CENTER.y + r * math.sin(th)
        if flat_mask(x, y) < 0.6: continue
        s = rnd.uniform(1.4, 4.2)
        rockblob(C, (x, y, ground_h(x, y, 0.95) + s * 0.25), (s * rnd.uniform(0.8, 1.6), s * rnd.uniform(0.8, 1.4), s * rnd.uniform(0.5, 1.1)),
                 amp=0.45, seed=200 + i, sub=2, mat="M_MesaCliff", name="outcrop")
    for i, (x, y, s) in enumerate([(4, 14, 2.4), (-6, -16, 3.0), (12, -26, 1.8), (30, 22, 2.0), (2, 30, 3.4), (84, 4, 2.6), (80, 22, 2.2),
                                   (36, -30, 2.0), (-14, 6, 2.8), (46, 30, 1.6), (90, -14, 3.0), (22, 34, 1.4)]):
        rockblob(C, (x, y, ground_h(x, y, 0.5) + s * 0.2), (s * 1.3, s, s * 0.7), amp=0.45, seed=300 + i, sub=2, mat="M_MesaCliff", name="boulder")
    return merge_into("S5_Mesa-col", C)

# ---------------------------------------------------------------- stair-3 well (back down to the cavern)
def stairwell(C, D, R):
    x0, x1, y0, y1 = L5["pit"]; fz = L5["pit_floor"]
    t = 0.3
    boxmm(C, "M_Concrete", x0, x1 + t, y0 - t, y0, fz - 0.5, G + 0.12, "pit_s", 0.02)
    boxmm(C, "M_Concrete", x0, x1 + t, y1, y1 + t, fz - 0.5, G + 0.12, "pit_n", 0.02)
    boxmm(C, "M_Concrete", x1, x1 + t, y0, y1, fz - 0.5, G + 0.12, "pit_e", 0.02)
    boxmm(C, "M_Concrete", x0 + 6.0, x1, y0, y1, fz - 0.5, fz, "pit_f", 0.0)
    boxmm(C, "M_Silhouette", x1 - 0.05, x1, y0 + 0.4, y1 - 0.4, fz, fz + 2.6, "pit_door", 0.0)   # the way on: black
    flight_lo = (x1 - 0.2, (y0 + y1) / 2, fz); flight_hi = (x0, (y0 + y1) / 2, G)
    stairs(D, flight_lo, flight_hi, width=3.0, rampcat=R)
    # curb + railings round the well (the gate closes the west end)
    for (a, b) in (((x0, y0 - t), (x1 + t, y0 - t)), ((x0, y1 + t), (x1 + t, y1 + t)), ((x1 + t, y0 - t), (x1 + t, y1 + t))):
        railing(D, (a[0], a[1], G + 0.12), (b[0], b[1], G + 0.12), h=1.1, spacing=1.6)

# ---------------------------------------------------------------- the works (the painting's centrepiece)
def deck5(C, x0, x1, y0, y1, z, mat="M_Grate"):
    boxmm(C, mat, x0, x1, y0, y1, z - 0.08, z, "deck", 0.0)
    for (a, b) in (((x0, y0), (x1, y0)), ((x0, y1), (x1, y1)), ((x0, y0), (x0, y1)), ((x1, y0), (x1, y1))):
        member(C, "M_Steel", (a[0], a[1], z - 0.25), (b[0], b[1], z - 0.25), 0.16, 0.34)

def legs(C, x0, x1, y0, y1, z, step=4.0, base=None):
    nx = max(1, int(round((x1 - x0) / step))); ny = max(1, int(round((y1 - y0) / step)))
    for i in range(nx + 1):
        for j in range(ny + 1):
            if 0 < i < nx and 0 < j < ny: continue
            x = x0 + (x1 - x0) * i / nx; y = y0 + (y1 - y0) * j / ny
            ibeam(C, (x, y, (base if base is not None else G - 1.0)), (x, y, z - 0.3), h=0.34, w=0.28)

def xbrace(C, p0, p1, z0, z1, sz=0.12, mat="M_Steel"):
    member(C, mat, (p0[0], p0[1], z0), (p1[0], p1[1], z1), sz, sz)
    member(C, mat, (p1[0], p1[1], z0), (p0[0], p0[1], z1), sz, sz)

def streaks(D, x0, x1, y, z0, z1, n, seed, face=-1):
    """Dark rain streaks down a wall (the vertical scratches in the reference)."""
    rnd = random.Random(seed)
    for i in range(n):
        x = rnd.uniform(x0, x1); l = rnd.uniform(1.5, (z1 - z0) * 0.7)
        boxmm(D, "M_Silhouette", x - 0.04, x + 0.04, y + face * 0.02, y + face * 0.035, z1 - l, z1 - 0.2, "streak", 0.0)

def works(C, D, R):
    # --- gallery: long deck on columns (left of the painting), roof slab with railings, pale pipes beneath
    gx0, gx1, gy0, gy1, gz = L5["gallery"]
    deck5(C, gx0, gx1, gy0, gy1, gz)
    legs(C, gx0, gx1, gy0, gy1, gz)
    for (a, b) in (((gx0, gy1), (gx1, gy1)), ((gx0, 13.0), (gx0, gy1)), ((gx0, gy0), (gx0, 11.0)), ((gx0, gy0), (57.5, gy0))):
        railing(D, (a[0], a[1], gz), (b[0], b[1], gz), h=1.1, spacing=1.8)
        member(R, None, (a[0], a[1], gz + 0.6), (b[0], b[1], gz + 0.6), 0.08, 1.2, "guard")
    # roof slab over the back half, on posts; railing round the top, grass on it
    boxmm(C, "M_Concrete", 53.0, gx1, 15.0, gy1, gz + 3.6, gz + 4.1, "groof", 0.05)
    for x in (53.3, 57.5, 61.7):
        for y in (15.3, 23.7):
            ibeam(C, (x, y, gz), (x, y, gz + 3.6), h=0.3, w=0.24)
    railing(D, (53.0, 15.0, gz + 4.1), (53.0, gy1, gz + 4.1), h=1.0, spacing=1.6, broken=0.3, seed=3)
    railing(D, (53.0, gy1, gz + 4.1), (gx1, gy1, gz + 4.1), h=1.0, spacing=1.6, broken=0.2, seed=4)
    for i in range(6):        # cross-braces between the legs (truss look)
        x = gx0 + 2.0 * i
        member(D, "M_Steel", (x, gy0, G + 0.5), (x + 2.0, gy0, gz - 0.4), 0.08, 0.08)
    # pale pipes looping under the deck (the white bends in the painting)
    for (yy, r) in ((19.0, 0.62), (21.2, 0.5)):
        cyl(C, "M_PalePipe", (63.0, yy, G + 1.6), (51.5, yy, G + 1.6), r, 14, "pipe")
        cyl(C, "M_PalePipe", (51.5, yy, G + 1.6), (49.6, yy, G + 2.9), r, 14, "pipe_b")
        cyl(C, "M_PalePipe", (49.6, yy, G + 2.9), (49.6, yy, gz - 1.0), r, 14, "pipe_up")
        cyl(C, "M_PalePipe", (49.6, yy, gz - 1.0), (51.2, yy, gz - 1.05), r, 14, "pipe_t")     # turns in under the deck
        cyl(C, "M_Steel", (51.2, yy, gz - 1.05), (51.45, yy, gz - 1.05), r + 0.08, 14, "pipe_cap")
        for x in (52.5, 56.0, 59.5, 62.6):
            cyl(C, "M_Steel", (x, yy, G + 1.6 - r - 0.1), (x, yy, G - 0.6), 0.12, 8, "saddle")
            cyl(C, "M_Steel", (x - 0.1, yy, G + 1.6), (x + 0.1, yy, G + 1.6), r + 0.06, 14, "flange")
    # stair 1: ground -> gallery
    lo, hi = L5["stair1"]
    stairs(D, lo, hi, width=2.0, rampcat=R)
    for s in (-1, 1):
        member(R, None, (lo[0], lo[1] + s * 1.03, lo[2] + 0.6), (hi[0], hi[1] + s * 1.03, hi[2] + 0.6), 0.06, 1.2, "guardrail")
    boxmm(C, "M_Concrete", lo[0] - 1.0, lo[0] + 0.05, lo[1] - 1.3, lo[1] + 1.3, G - 0.6, G + 0.05, "stair_pad", 0.03)

    # --- link deck along bunker A's west face, down to the tower
    lx0, lx1, ly0, ly1, lz = L5["link"]
    deck5(C, lx0, lx1, ly0, ly1, lz)
    legs(C, lx0, lx1, ly0, ly1, lz, step=4.6)
    railing(D, (lx0, ly0 + 0.2, lz), (lx0, gy0, lz), h=1.1, spacing=1.8)
    member(R, None, (lx0, ly0 + 0.2, lz + 0.6), (lx0, gy0, lz + 0.6), 0.08, 1.2, "guard")

    # --- bunker A (sloped roof mass) and bunker B (the tall block), concrete with streaks
    boxmm(C, "M_Concrete", 61.5, 73.0, -0.2, 9.0, G - 1.0, 44.0, "bunkerA", 0.08)
    # sloped roof rising from north (Z44) to south (Z49): a wedge
    bmw = bmesh.new()
    vs = [bmw.verts.new(v) for v in ((61.5, 9.0, 44.0), (73.0, 9.0, 44.0), (73.0, -0.2, 44.0), (61.5, -0.2, 44.0),
                                     (61.5, -0.2, 49.5), (73.0, -0.2, 49.5))]
    for f in ((0, 3, 2, 1), (0, 1, 5, 4), (3, 4, 5, 2), (0, 4, 3), (1, 2, 5)):
        bmw.faces.new([vs[i] for i in f])
    bmesh.ops.recalc_face_normals(bmw, faces=bmw.faces)
    mk_obj("wedge", bmw, "M_Concrete", C)
    boxmm(C, "M_Concrete", 61.0, 73.5, -11.5, -0.2, G - 1.0, 56.0, "bunkerB", 0.08)
    boxmm(C, "M_Concrete", 60.6, 74.0, -12.0, 0.3, 56.0, 56.6, "capB", 0.05)
    boxmm(C, "M_Rust", 64.0, 70.0, -9.0, -3.0, 56.6, 59.6, "headhouse", 0.05)
    cyl(C, "M_Steel", (71.5, -2.0, 56.6), (71.5, -2.0, 66.0), 0.08, 6, "antenna")
    member(C, "M_Steel", (70.6, -2.0, 64.0), (72.4, -2.0, 64.0), 0.06, 0.06)
    streaks(D, 61.6, 72.8, -0.2 + 9.2, 34.5, 44.0, 14, 11, face=1)
    streaks(D, 61.2, 73.3, -11.5, 34.5, 56.0, 18, 12, face=-1)
    for (x, y) in ((61.0, -6.0), (61.0, 4.0)):      # dark window slots
        boxmm(D, "M_Silhouette", x - 0.06, x, y - 1.6, y + 1.6, 49.0 if y < 0 else 41.5, 50.2 if y < 0 else 42.5, "slot", 0.0)

    # --- K-braced steel tower in front of bunker B, stair 2 inside
    tx0, tx1, ty0, ty1 = L5["tower"]
    for x in (tx0, tx1):
        for y in (ty0, ty1):
            ibeam(C, (x, y, G - 1.0), (x, y, 53.0), h=0.42, w=0.34)
    for z in (40.0 - 0.3, 46.0 - 0.3, 53.0):
        for (a, b) in (((tx0, ty0), (tx1, ty0)), ((tx0, ty1), (tx1, ty1)), ((tx0, ty0), (tx0, ty1)), ((tx1, ty0), (tx1, ty1))):
            ibeam(C, (a[0], a[1], z), (b[0], b[1], z), h=0.36, w=0.26)
    for (z0, z1) in ((G, 39.7), (39.7, 45.7), (45.7, 53.0)):
        ym = (ty0 + ty1) / 2
        member(D, "M_Steel", (tx0, ty0, z0), (tx0, ym, z1), 0.14, 0.14)      # K on the west face
        member(D, "M_Steel", (tx0, ty1, z0), (tx0, ym, z1), 0.14, 0.14)
        xbrace(D, (tx0, ty0), (tx1, ty0), z0, z1, 0.12)
    deck5(C, tx0, tx1, ty0, ty1, 40.0)
    tdx0, tdx1, tdy0, tdy1, tdz = L5["top_deck"]
    deck5(C, tdx0, tdx1, tdy0, tdy1, tdz)
    lo2, hi2 = L5["stair2"]
    stairs(D, lo2, hi2, width=2.0, rampcat=R)
    for s in (-1, 1):
        member(R, None, (lo2[0] + s * 1.03, lo2[1], lo2[2] + 0.6), (hi2[0] + s * 1.03, hi2[1], hi2[2] + 0.6), 0.06, 1.2, "guardrail")
    railing(D, (tx0, ty1, 40.0), (tx0, ty0, 40.0), h=1.1, spacing=1.8)
    member(R, None, (tx0, ty1, 40.6), (tx0, ty0, 40.6), 0.08, 1.2, "guard")
    railing(D, (tx0, ty0, 40.0), (tx1, ty0, 40.0), h=1.1, spacing=1.8)
    member(R, None, (tx0, ty0, 40.6), (tx1, ty0, 40.6), 0.08, 1.2, "guard")
    railing(D, (tx0, tdy1, tdz), (tx0, tdy0, tdz), h=1.1, spacing=1.6)
    member(R, None, (tx0, tdy1, tdz + 0.6), (tx0, tdy0, tdz + 0.6), 0.08, 1.2, "guard")
    for (a, b) in ((tx0, 56.9), (59.1, tx1)):     # either side of the stairhead
        railing(D, (a, tdy1, tdz), (b, tdy1, tdz), h=1.1, spacing=1.2)
        member(R, None, (a, tdy1, tdz + 0.6), (b, tdy1, tdz + 0.6), 0.08, 1.2, "guard")
    railing(D, (tx1, tdy1, tdz), (tx1, tdy0, tdz), h=1.1, spacing=1.6)     # east side of the top deck (bunker B is behind)
    railing(D, (tx0, tdy0, tdz), (L5["gantry"][0], tdy0, tdz), h=1.1, spacing=1.6)
    member(R, None, (tx0, tdy0, tdz + 0.6), (L5["gantry"][0], tdy0, tdz + 0.6), 0.08, 1.2, "guard")
    railing(D, (L5["gantry"][1], tdy0, tdz), (tx1, tdy0, tdz), h=1.1, spacing=1.6)
    member(R, None, (L5["gantry"][1], tdy0, tdz + 0.6), (tx1, tdy0, tdz + 0.6), 0.08, 1.2, "guard")
    # lamp mast on the tower top + sign board
    boxmm(C, "M_Rust", tx0 + 0.4, tx1 - 0.4, ty0 + 0.5, ty0 + 0.62, 50.0, 52.4, "sign", 0.02)
    boxmm(D, "M_Hazard", tx0 + 0.5, tx1 - 0.5, ty0 + 0.45, ty0 + 0.5, 50.1, 50.5, "sign_haz", 0.0)

    # --- gantry: catwalk truss + two big pipes, from the tower south to block C
    ax0, ax1, ay0, ay1, az = L5["gantry"]
    boxmm(C, "M_Grate", ax0, ax1, ay0, ay1, az - 0.08, az, "gdeck", 0.0)
    for x in (ax0, ax1):
        truss(D, Vector((x, ay0, az - 0.2)), Vector((x, ay1, az - 0.2)), height=1.25, mat="M_Steel", panel=1.6, sz=0.09)
        member(R, None, (x, ay0, az + 0.6), (x, ay1, az + 0.6), 0.08, 1.2, "guard")
    for k in range(int(ay1 - ay0) // 2 + 1):
        y = ay0 + 2.0 * k
        member(C, "M_Steel", (ax0, y, az - 0.3), (ax1 + 2.4, y, az - 0.3), 0.14, 0.24)
    for (x, z, r) in ((60.1, az + 0.3, 0.58), (61.4, az + 1.5, 0.46)):
        cyl(C, "M_PalePipe", (x, -11.2, z), (x, -27.2, z), r, 16, "gpipe")
        for y in (-14.0, -19.0, -24.0):
            cyl(C, "M_Steel", (x, y - 0.1, z), (x, y + 0.1, z), r + 0.07, 16, "gflange")
    for x in (ax0, ax1 + 2.4):    # mid pier
        ibeam(C, (x, -19.0, G - 1.0), (x, -19.0, az - 0.4), h=0.38, w=0.3)
    xbrace(D, (ax0, -19.0), (ax1 + 2.4, -19.0), G, az - 0.5, 0.12)

    # --- block C (right of the painting): flat roof = the lookout, vertical pipes, tank
    cx0, cx1, cy0, cy1, cz = L5["blockC"]
    boxmm(C, "M_Concrete", cx0, cx1, cy0, cy1, G - 1.0, cz, "blockC", 0.08)
    for (a, b) in (((cx0, cy0), (cx0, cy1)), ((cx0 + 5.0, cy1), (cx1, cy1))):
        boxmm(C, "M_Concrete", min(a[0], b[0]) - 0.17, max(a[0], b[0]) + 0.17, min(a[1], b[1]) - 0.17, max(a[1], b[1]) + 0.17, cz, cz + 0.9, "parapet", 0.03)
    # the lookout side (south + east) has a low curb and a railing, so you can see down over the edge
    for (a, b) in (((cx0, cy0), (cx1, cy0)), ((cx1, cy0), (cx1, cy1))):
        boxmm(C, "M_Concrete", min(a[0], b[0]) - 0.17, max(a[0], b[0]) + 0.17, min(a[1], b[1]) - 0.17, max(a[1], b[1]) + 0.17, cz, cz + 0.25, "curb", 0.03)
        railing(D, (a[0], a[1], cz + 0.25), (b[0], b[1], cz + 0.25), h=1.0, spacing=1.6)
        member(R, None, (a[0], a[1], cz + 0.8), (b[0], b[1], cz + 0.8), 0.1, 1.2, "guard")
    cyl(C, "M_Rust", (63.5, -31.0, cz), (63.5, -31.0, cz + 4.2), 2.0, 18, "tank")
    cyl(C, "M_Steel", (63.5, -31.0, cz + 4.2), (63.5, -31.0, cz + 4.5), 2.15, 18, "tank_lid")
    for (x, top) in ((56.0, cz + 1.6), (58.0, cz + 3.0), (65.5, cz + 2.2)):
        cyl(C, "M_PalePipe", (x, cy0 - 0.6, G - 1.0), (x, cy0 - 0.6, top), 0.35, 12, "vpipe")
        cyl(C, "M_Steel", (x, cy0 - 0.6, top), (x, cy0 - 0.6, top + 0.2), 0.45, 12, "vpipe_cap")
        for z in (G + 3.0, G + 7.0, cz - 1.0):
            member(C, "M_Steel", (x, cy0 - 0.6, z), (x, cy0 + 0.02, z), 0.12, 0.12)
    streaks(D, cx0 + 0.2, cx1 - 0.2, cy0, 34.5, cz, 16, 13, face=-1)
    streaks(D, cx0 + 0.2, cx1 - 0.2, cy1, 34.5, cz, 10, 14, face=1)
    boxmm(D, "M_Silhouette", cx1, cx1 + 0.03, -34.0, -31.0, G, G + 2.6, "doorC", 0.0)

    # --- the thin tall mast (far left of the painting) and two stubby ruins near the edges
    member(C, "M_Steel", (40.0, 30.0, G - 0.5), (40.0, 30.0, 62.0), 0.32, 0.32)
    member(C, "M_Steel", (38.4, 30.0, 59.5), (41.6, 30.0, 59.5), 0.14, 0.14)
    member(C, "M_Steel", (38.9, 30.0, 61.0), (41.1, 30.0, 61.0), 0.12, 0.12)
    for (x, y, w, d, h, s) in ((-14.0, 32.0, 7.0, 6.0, 20.0, 21), (88.0, 30.0, 9.0, 7.0, 12.0, 22)):
        boxmm(C, "M_Concrete", x - w / 2, x + w / 2, y - d / 2, y + d / 2, G - 2.0, G + h, "ruin", 0.1)
        boxmm(C, "M_Concrete", x - w / 2 - 0.5, x + w / 2 + 0.5, y - d / 2 - 0.5, y + d / 2 + 0.5, G + h, G + h + 0.6, "ruin_cap", 0.05)
        for k in range(3):
            member(D, "M_Rust", (x - w / 2 - 0.6, y - d / 2 + 1.0 + k * 2.0, G + h - 2.0 - k * 3.0), (x + w / 2 + 0.6, y - d / 2 + 1.0 + k * 2.0, G + h - 2.0 - k * 3.0), 0.18, 0.18)
        streaks(D, x - w / 2 + 0.3, x + w / 2 - 0.3, y - d / 2, G, G + h, 9, s, face=-1)

# ---------------------------------------------------------------- grass tufts (bright yellow-green, like the painting)
def grass_spots():
    """Points on top surfaces where tufts grow: ledges, roofs, deck edges, the ground near walls."""
    pts = []
    gx0, gx1, gy0, gy1, gz = L5["gallery"]
    rnd = random.Random(77)
    for i in range(14): pts.append((rnd.uniform(53.2, gx1 - 0.2), rnd.choice((15.2, gy1 - 0.2, rnd.uniform(15.2, gy1))), gz + 4.1, 0.55))
    for i in range(10): pts.append((rnd.uniform(61.8, 72.8), rnd.uniform(0.0, 8.8), 44.0 + 0.2, 0.6))   # under the wedge lip
    for i in range(12): pts.append((rnd.choice((60.8, 73.7)), rnd.uniform(-11.8, 0.1), 56.6, 0.6))
    for i in range(6): pts.append((rnd.uniform(59.2, 66.8), -27.0, 46.9, 0.5))       # north parapet
    for i in range(6): pts.append((rnd.uniform(54.2, 66.8), -37.85, 46.25, 0.5))     # lookout curb
    for i in range(5): pts.append((54.0, rnd.uniform(-37.5, -27.5), 46.9, 0.5))      # west parapet
    for i in range(8): pts.append((rnd.uniform(gx0, gx1), rnd.choice((gy0 + 0.05, gy1 - 0.05)), gz, 0.4))
    for i in range(6): pts.append((rnd.uniform(-17.0, -11.0), rnd.uniform(29.0, 35.0), G + 20.6, 0.6))
    for i in range(5): pts.append((rnd.uniform(84.0, 92.0), rnd.uniform(27.0, 33.0), G + 12.6, 0.6))
    # ground: clumps hugging walls and columns, scattered over the plateau (off the route's middle)
    for i in range(260):
        th = rnd.uniform(0, 2 * math.pi); r = rim_radius(th) * math.sqrt(rnd.uniform(0.02, 0.97))
        x = CENTER.x + r * math.cos(th); y = CENTER.y + r * math.sin(th)
        if 18.0 < x < 25.5 and -6.5 < y < 0.0: continue          # lift
        if 33.5 < x < 47.0 and 0.0 < y < 6.5: continue           # stair well
        pts.append((x, y, ground_h(x, y, r / rim_radius(th)) - 0.05, rnd.uniform(0.55, 1.2)))
    for i in range(50):     # along the foot of the works
        x = rnd.uniform(48, 75); y = rnd.uniform(-40, 26)
        pts.append((x, y, ground_h(x, y, 0.5) - 0.05, rnd.uniform(0.6, 1.3)))
    return pts

def grass():
    C = "S5_GrassC"; s5coll(C)
    rnd = random.Random(9)
    for i, (x, y, z, s) in enumerate(grass_spots()):
        fern(C, (x, y, z), scale=s * 1.25, seed=900 + i, n=rnd.randint(6, 11), mat=("M_Grass" if rnd.random() < 0.7 else "M_GrassDry"), up=1.6)
    return merge_into("S5_Grass", C, uv=False)

# ---------------------------------------------------------------- distant spires (the misty pillars)
def spire(C, x, y, top, r0, seed, ruin=False):
    rnd = random.Random(seed)
    bm = bmesh.new(); N = 10
    zs = [top - k * 7.0 for k in range(int((top + 90.0) / 7.0) + 1)]
    rings = []
    for z in zs:
        depth = top - z
        st = noise.fractal(Vector((x * 0.01 + seed, y * 0.01, z * 0.08)), 0.55, 2.0, 3, noise_basis='PERLIN_ORIGINAL')
        r = r0 * (1.0 + depth * 0.003) + (r0 * 0.18 if int(z / 9.0 + seed) % 3 == 0 else 0.0) + r0 * 0.12 * st
        ring = []
        for k in range(N):
            th = 2 * math.pi * k / N + seed
            q = 1.0 + 0.22 * noise.noise(Vector((math.cos(th) * 2 + seed, math.sin(th) * 2, z * 0.05)))
            ring.append(bm.verts.new((x + r * q * math.cos(th), y + r * q * 0.8 * math.sin(th), z)))
        rings.append(ring)
    bm.faces.new(rings[0])
    for i in range(len(rings) - 1):
        for k in range(N):
            bm.faces.new((rings[i][k], rings[i + 1][k], rings[i + 1][(k + 1) % N], rings[i][(k + 1) % N]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    mk_obj("spire", bm, "M_Spire", C)
    if ruin:      # industrial ruin on top: tower blocks with crossbars, like the background of the reference
        w = r0 * rnd.uniform(0.5, 0.8)
        h = rnd.uniform(8.0, 22.0)
        boxmm(C, "M_Spire", x - w, x + w * 0.4, y - w * 0.6, y + w * 0.6, top - 1.0, top + h, "rblock", 0.0)
        boxmm(C, "M_Spire", x - w * 0.2, x + w * 0.9, y - w * 0.5, y + w * 0.5, top - 1.0, top + h * 0.6, "rblock2", 0.0)
        for k in range(rnd.randint(1, 3)):
            z = top + h * rnd.uniform(0.35, 0.9)
            boxmm(C, "M_Spire", x - w * 1.5, x + w * 1.4, y - 0.8, y + 0.8, z, z + 1.4, "rbar", 0.0)
        if rnd.random() < 0.6:
            boxmm(C, "M_Spire", x + w * 0.1, x + w * 0.35, y - 0.4, y + 0.4, top + h, top + h + rnd.uniform(6, 14), "rmast", 0.0)

SPIRES = []
def spire_layout():
    rnd = random.Random(42)
    out = []
    for i in range(44):
        th = rnd.uniform(0, 2 * math.pi)
        d = rnd.uniform(170.0, 620.0)
        if i < 7:         # a few nearer ones off the lookout (south-east) and behind the works (east)
            th = rnd.uniform(-1.5, 0.35); d = rnd.uniform(140.0, 230.0)
        x = CENTER.x + d * math.cos(th); y = CENTER.y + d * math.sin(th)
        top = G + rnd.uniform(10.0, 60.0) + d * rnd.uniform(0.04, 0.16)
        r0 = rnd.uniform(3.5, 7.5) + d * 0.011          # slender, like the misty pillars in the reference
        out.append((x, y, top, r0, i, rnd.random() < 0.5))
    return out

def spires():
    C = "S5_SpiresC"; s5coll(C)
    for (x, y, top, r0, i, ruin) in spire_layout():
        spire(C, x, y, top, r0, 500 + i, ruin)
    return merge_into("S5_Spires", C, uv=False)

# ---------------------------------------------------------------- build + export
def build_all():
    mats5()
    mesa()
    C, D, R = "S5_WorksC", "S5_DetailC", "S5_RampsC"
    for c in (C, D, R): s5coll(c)
    stairwell(C, D, R)
    works(C, D, R)
    merge_into("S5_Works-col", C)
    merge_into("S5_Detail", D)
    ramps = merge_into("S5_Ramps-colonly", R, uv=False)
    ramps.data.materials.clear()
    grass(); spires()
    # the lift headframe is shared with the cavern (Lift3-col, built by v3_lift_tunnel.py)
    if "Lift3-col" not in S5.collection.objects:
        S5.collection.objects.link(bpy.data.objects["Lift3-col"])
    with open(os.path.join(PROJ, "art_src", "surface.json"), "w") as f:
        json.dump({"layout": L5, "spires": [list(s[:4]) for s in spire_layout()]}, f, indent=1)
    print("surface built:", [(o.name, len(o.data.vertices)) for o in S5.objects if o.type == 'MESH'])

def export_all():
    names = ["S5_Mesa-col", "S5_Works-col", "S5_Detail", "S5_Ramps-colonly", "S5_Grass", "S5_Spires", "Lift3-col"]
    sc = bpy.context.scene
    tmp = bpy.data.collections.new("_EXPORT_TMP"); sc.collection.children.link(tmp)
    for n in names:
        if n not in sc.objects:
            tmp.objects.link(bpy.data.objects[n])
    bpy.context.view_layer.update()
    for o in sc.objects:
        o.select_set(o.name in names)
    bpy.ops.export_scene.gltf(filepath=os.path.join(PROJ, "assets", "level", "surface.glb"), export_format='GLB', use_selection=True,
                              use_active_scene=True, export_apply=True, export_yup=True)
    sc.collection.children.unlink(tmp); bpy.data.collections.remove(tmp)
    print("exported surface.glb")
