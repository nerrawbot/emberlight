
# v7: the surface's two hostiles. Built in Blender scene "Enemies7", exported to assets/creatures/{tripod,skate}.glb.
#   TRIPOD - a triangular scrap walker on three long two-segment legs (Godot poses the legs with 2-bone IK).
#            Tri_Body (origin = body centre) > Tri_Eye (turret under the front edge, aims) > Tri_Lens.
#            Tri_Thigh0..2 (origin = hip, segment runs along local +Y, length TRI["thigh"])
#            Tri_Shin0..2  (origin = knee, runs along local +Y, length TRI["shin"], spike foot at the end).
#            Leg i hangs off the corner at angle TRI["angles"][i] (degrees from +X; +Y is forward), radius TRI["hip_r"].
#   SKATE  - a hovering ray-shaped drone: Skate_Hull > Skate_Core (glowing furnace under the belly),
#            Skate_WingL/R (origin on the hinge, flap about the forward axis), Skate_TailL0..2 / R0..2 (chains).
# Facing Blender +Y (= Godot -Z). Run: exec(open(r"...\art_src\v7_enemies.py").read()); build_all(); export_all()
exec(open(r"D:\Emberlight\art_src\gen_lib.py").read())

if "Enemies7" not in bpy.data.scenes:
    bpy.data.scenes.new("Enemies7")
E7 = bpy.data.scenes["Enemies7"]
TMP = "TMP7"

TRI = {"angles": [30.0, 150.0, 270.0], "hip_r": 0.72, "thigh": 1.25, "shin": 1.55}
UV_T = {"M_Steel": 0.8, "M_RustSheet": 0.8, "M_Corrugated": 0.9, "M_Hazard": 0.45}

def e7coll(name):
    c = bpy.data.collections.get(name)
    if c is None:
        c = bpy.data.collections.new(name)
    if c.name not in E7.collection.children:
        E7.collection.children.link(c)
    return c

e7coll(TMP)       # scratch pieces live in Enemies7 (gen_lib's coll() would link a new one into whatever scene is active)

def _mats():
    flat_mat("M_TriEye", (0.12, 0.02, 0.03), rough=0.3, emit=(1.0, 0.16, 0.1), strength=12.0)
    flat_mat("M_SkateCore", (0.15, 0.06, 0.01), rough=0.3, emit=(1.0, 0.52, 0.14), strength=10.0)

def _clear_tmp():
    c = coll(TMP)
    for o in list(c.objects):
        bpy.data.objects.remove(o, do_unlink=True)

_PIV = {}

def merge(name, C, pivot=(0, 0, 0), parent=None, sharp=38.0):
    """Join everything built into TMP into one object `name` (origin = pivot, world coords), box UVs, sharp edges."""
    objs = [o for o in bpy.data.collections[TMP].objects if o.type == 'MESH']
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
            remap.append(mats.index(m))
        for f in bm.faces[nf:]:
            f.material_index = remap[f.material_index] if f.material_index < len(remap) else 0
    bmesh.ops.translate(bm, vec=-Vector(pivot), verts=bm.verts)
    bm.normal_update()
    uv = bm.loops.layers.uv.verify()
    names = [m.name for m in mats]
    for f in bm.faces:
        t = UV_T.get(names[f.material_index] if f.material_index < len(names) else "", 0.6)
        n = f.normal; ax = max(range(3), key=lambda i: abs(n[i]))
        for l in f.loops:
            c = l.vert.co
            if ax == 0: u, v = c.y * (1 if n.x > 0 else -1), c.z
            elif ax == 1: u, v = c.x * (-1 if n.y > 0 else 1), c.z
            else: u, v = c.x, c.y * (1 if n.z > 0 else -1)
            l[uv].uv = (u / t, v / t)
        f.smooth = True
    lim = math.radians(sharp)
    for e in bm.edges:
        if len(e.link_faces) != 2 or e.calc_face_angle(0.0) > lim:
            e.smooth = False
    old = bpy.data.objects.get(name)
    if old: bpy.data.objects.remove(old, do_unlink=True)
    me = bpy.data.meshes.new(name); bm.to_mesh(me); bm.free()
    for m in mats: me.materials.append(m)
    ob = bpy.data.objects.new(name, me)
    e7coll(C).objects.link(ob)
    _PIV[name] = Vector(pivot)
    if parent:
        ob.parent = bpy.data.objects[parent]
        ob.matrix_parent_inverse = Matrix.Identity(4)
        ob.location = Vector(pivot) - _PIV[parent]
    else:
        ob.location = pivot
    _clear_tmp()
    return ob

def lathe_y(mat, prof, seg=12, name="lathe", sz=1.0, y0=0.0):
    """Revolve (radius, y) around the Y axis (forward); sz flattens it vertically."""
    bm = bmesh.new(); rings = []
    for (r, y) in prof:
        if r <= 1e-5:
            rings.append([bm.verts.new((0, y + y0, 0))]); continue
        rings.append([bm.verts.new((r * math.cos(2 * math.pi * k / seg), y + y0, r * sz * math.sin(2 * math.pi * k / seg))) for k in range(seg)])
    for i in range(len(rings) - 1):
        a, b = rings[i], rings[i + 1]
        for k in range(seg):
            if len(a) == 1: bm.faces.new((a[0], b[(k + 1) % seg], b[k]))
            elif len(b) == 1: bm.faces.new((a[k], a[(k + 1) % seg], b[0]))
            else: bm.faces.new((a[k], a[(k + 1) % seg], b[(k + 1) % seg], b[k]))
    if len(rings[0]) > 1: bm.faces.new(rings[0])
    if len(rings[-1]) > 1: bm.faces.new(list(reversed(rings[-1])))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return mk_obj(name, bm, mat, TMP)

def ball(mat, c, r, sub=2, s=(1, 1, 1)):
    return rockblob(TMP, c, (r * s[0], r * s[1], r * s[2]), amp=0.0, seed=0, sub=sub, mat=mat, name="ball")

def prism(mat, pts, z0, z1, name="prism"):
    """Extrude an XY polygon (counter-clockwise) from z0 to z1."""
    bm = bmesh.new()
    lo = [bm.verts.new((x, y, z0)) for x, y in pts]; hi = [bm.verts.new((x, y, z1)) for x, y in pts]
    bm.faces.new(list(reversed(lo))); bm.faces.new(hi)
    n = len(pts)
    for i in range(n):
        bm.faces.new((lo[i], lo[(i + 1) % n], hi[(i + 1) % n], hi[i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return mk_obj(name, bm, mat, TMP)

# ====================================================================== TRIPOD
def _corner(a_deg, r, z=0.0):
    a = math.radians(a_deg)
    return Vector((r * math.cos(a), r * math.sin(a), z))

def tri_body():
    # truncated-triangle hull: long edges between the leg corners, short chamfers at the corners
    pts = []
    for a in TRI["angles"]:
        for d in (-16.0, 16.0):
            p = _corner(a + d, 0.92); pts.append((p.x, p.y))
    bm = bmesh.new()
    rings = []
    for (z, s) in ((-0.2, 0.86), (-0.12, 1.0), (0.12, 1.0), (0.2, 0.84)):
        rings.append([bm.verts.new((x * s, y * s, z)) for x, y in pts])
    n = len(pts)
    bm.faces.new(list(reversed(rings[0])))
    for i in range(3):
        a, b = rings[i], rings[i + 1]
        for k in range(n):
            bm.faces.new((a[k], a[(k + 1) % n], b[(k + 1) % n], b[k]))
    # sloped top rising to the hub ring
    hub = [bm.verts.new((x * 0.34, y * 0.34, 0.36)) for x, y in pts]
    for k in range(n):
        bm.faces.new((rings[3][k], rings[3][(k + 1) % n], hub[(k + 1) % n], hub[k]))
    bm.faces.new(hub)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    ob = mk_obj("hull", bm, "M_Steel", TMP)
    for i, a in enumerate(TRI["angles"]):
        # sloped armour plates on each long face (rust sheet), riveted
        b = TRI["angles"][(i + 1) % 3]
        mid = (a + b) / 2 if abs(b - a) < 180 else (a + b) / 2 + 180
        c = _corner(mid, 0.5, 0.29)
        p = boxmm(TMP, "M_RustSheet", -0.32, 0.32, -0.16, 0.16, -0.012, 0.012, "plate", 0.0)
        p.location = c
        q = Quaternion((0, 0, 1), math.radians(mid + 90)) @ Quaternion((1, 0, 0), math.radians(21))
        p.rotation_mode = 'QUATERNION'; p.rotation_quaternion = q
        for t in (-0.26, 0.0, 0.26):
            rv = cyl(TMP, "M_Steel", (0, 0, 0), (0, 0, 0.03), 0.022, 6, "rivet")
            rv.location = c + q @ Vector((t, -0.12, 0.012))
        # hip housing: a drum on the hinge axis (tangent to the corner)
        h = _corner(a, TRI["hip_r"]); tang = Vector((-math.sin(math.radians(a)), math.cos(math.radians(a)), 0))
        cyl(TMP, "M_Steel", h - tang * 0.2, h + tang * 0.2, 0.17, 12, "hipdrum")
        cyl(TMP, "M_RustSheet", h - tang * 0.23, h - tang * 0.19, 0.12, 12, "hipcap")
        cyl(TMP, "M_RustSheet", h + tang * 0.19, h + tang * 0.23, 0.12, 12, "hipcap")
        # cables from the hub to each hip
        member(TMP, "M_Cable", _corner(a + 20, 0.25, 0.38), h + Vector((0, 0, 0.16)), 0.03, 0.03)
        member(TMP, "M_Cable", _corner(a - 20, 0.25, 0.38), h + Vector((0, 0, 0.12)), 0.025, 0.025)
    # hazard band on the front edge (between the two front legs)
    boxmm(TMP, "M_Hazard", -0.5, 0.5, 0.655, 0.675, -0.1, 0.1, "band", 0.0)
    # hub: reactor stack with a vented cap and two exhausts leaning back
    cyl(TMP, "M_Steel", (0, 0, 0.34), (0, 0, 0.56), 0.24, 14, "hub")
    cyl(TMP, "M_RustSheet", (0, 0, 0.56), (0, 0, 0.62), 0.27, 14, "hubring")
    cyl(TMP, "M_Steel", (0, 0, 0.62), (0, 0, 0.7), 0.16, 14, "cap", r2=0.08)
    for s in (-1, 1):
        cyl(TMP, "M_Steel", (0.12 * s, -0.12, 0.45), (0.2 * s, -0.42, 0.86), 0.045, 8, "exhaust")
        cyl(TMP, "M_Cable", (0.2 * s, -0.42, 0.86), (0.215 * s, -0.47, 0.94), 0.055, 8, "exhaust_tip")
    # antenna on the back corner
    member(TMP, "M_Steel", _corner(270, 0.62, 0.2), _corner(270, 0.75, 1.15), 0.02, 0.02)
    ball("M_TriEye", _corner(270, 0.75, 1.16), 0.035, 1)
    # belly: turret ring the eye hangs from
    cyl(TMP, "M_Steel", (0, 0.2, -0.2), (0, 0.2, -0.28), 0.2, 14, "turret_ring")

def tri_eye():
    c = Vector((0, 0.2, -0.42))
    ball("M_Steel", c, 0.19, 2)
    cyl(TMP, "M_RustSheet", c + Vector((0, 0.05, 0)), c + Vector((0, 0.34, 0)), 0.13, 14, "barrel")
    boxmm(TMP, "M_Steel", -0.17, 0.17, 0.1, 0.42, 0.06, 0.1, "hood", 0.01).location = c + Vector((0, 0.24, 0.1))
    cyl(TMP, "M_Steel", c + Vector((0, 0.34, 0)), c + Vector((0, 0.4, 0)), 0.15, 14, "bezel")
    for s in (-1, 1):
        cyl(TMP, "M_Steel", c + Vector((0.18 * s, 0, 0)), c + Vector((0.24 * s, 0, 0)), 0.07, 10, "trunnion")
    cyl(TMP, "M_Steel", (0, 0.2, -0.28), (0, 0.2, -0.24), 0.08, 10, "neck")

def tri_lens():
    cyl(TMP, "M_TriEye", (0, 0.6, -0.42), (0, 0.615, -0.42), 0.115, 16, "lens")

def tri_thigh():
    L = TRI["thigh"]
    cyl(TMP, "M_RustSheet", (-0.16, 0, 0), (0.16, 0, 0), 0.12, 12, "hip")
    member(TMP, "M_Steel", (0, 0.05, 0), (0, L - 0.08, 0), 0.12, 0.17, "beam", 0.015)
    boxmm(TMP, "M_Hazard", -0.075, 0.075, L * 0.48, L * 0.58, -0.1, 0.1, "band", 0.0)
    cyl(TMP, "M_Steel", (0, 0.16, -0.15), (0, L * 0.6, -0.15), 0.05, 8, "piston")
    cyl(TMP, "M_Cable", (0, L * 0.6, -0.15), (0, L - 0.14, -0.12), 0.026, 6, "rod")
    member(TMP, "M_Steel", (0, 0.12, -0.08), (0, 0.18, -0.15), 0.06, 0.04)
    for s in (-1, 1):
        boxmm(TMP, "M_Steel", 0.07 * s - 0.015, 0.07 * s + 0.015, L - 0.2, L + 0.08, -0.1, 0.1, "clevis", 0.01)
    member(TMP, "M_Cable", (0.08, 0.1, 0.1), (0.07, L - 0.25, 0.1), 0.02, 0.02)
    cyl(TMP, "M_Steel", (-0.11, L, 0), (0.11, L, 0), 0.075, 10, "kneepin")

def tri_shin():
    L = TRI["shin"]
    ball("M_Steel", (0, 0, 0), 0.1, 2)
    cyl(TMP, "M_Steel", (0, 0.04, 0), (0, L - 0.28, 0), 0.08, 10, "shin", r2=0.05)
    cyl(TMP, "M_RustSheet", (0, 0.18, 0), (0, 0.42, 0), 0.098, 10, "sleeve")
    boxmm(TMP, "M_Hazard", -0.07, 0.07, L * 0.55, L * 0.6, -0.07, 0.07, "band", 0.0)
    cyl(TMP, "M_RustSheet", (0, L - 0.3, 0), (0, L - 0.24, 0), 0.075, 10, "collar")
    cyl(TMP, "M_Steel", (0, L - 0.25, 0), (0, L, 0), 0.06, 8, "spike", r2=0.006)
    for k in range(3):     # claw toes splayed round the spike
        a = k / 3 * 2 * math.pi
        d = Vector((math.cos(a), 0, math.sin(a)))
        member(TMP, "M_Steel", Vector((0, L - 0.26, 0)) + d * 0.05, Vector((0, L - 0.05, 0)) + d * 0.13, 0.025, 0.03)
    member(TMP, "M_Cable", (0.06, 0.05, 0.06), (0.04, L - 0.35, 0.05), 0.018, 0.018)

def build_tripod():
    C = "E7_Tripod"
    c = e7coll(C)
    for o in list(c.objects): bpy.data.objects.remove(o, do_unlink=True)
    _clear_tmp()
    tri_body(); merge("Tri_Body", C)
    tri_eye(); merge("Tri_Eye", C, (0, 0.2, -0.42), parent="Tri_Body")
    tri_lens(); merge("Tri_Lens", C, (0, 0.6, -0.42), parent="Tri_Eye")
    # legs, posed for the preview only (Godot re-poses them every frame)
    for i, a in enumerate(TRI["angles"]):
        tri_thigh(); th = merge("Tri_Thigh%d" % i, C)
        tri_shin(); sh = merge("Tri_Shin%d" % i, C)
        out = _corner(a, 1.0).normalized()
        hip = _corner(a, TRI["hip_r"])
        knee = hip + out * 0.75 + Vector((0, 0, 0.95))
        foot = _corner(a, 1.95, -1.5)
        for ob, p0, p1 in ((th, hip, knee), (sh, knee, foot)):
            ob.location = p0
            ob.rotation_mode = 'QUATERNION'; ob.rotation_quaternion = (p1 - p0).to_track_quat('Y', 'Z')
    print("tripod:", [o.name for o in c.objects])

# ====================================================================== SKATE
def skate_hull():
    lathe_y("M_Steel", [(0.0, -0.62), (0.07, -0.6), (0.14, -0.45), (0.2, -0.2), (0.23, 0.1), (0.21, 0.35), (0.15, 0.55), (0.06, 0.66), (0.0, 0.68)], 14, "hull", sz=0.62)
    for y in (-0.28, 0.24):
        lathe_y("M_RustSheet", [(0.0, y - 0.035), (0.225, y - 0.035), (0.225, y + 0.035), (0.0, y + 0.035)], 14, "band", sz=0.66)
    # dorsal fin + spine
    bm = bmesh.new()
    vs = [bm.verts.new(p) for p in ((0, 0.3, 0.12), (0, -0.5, 0.1), (0, -0.62, 0.36), (0, -0.2, 0.2))]
    bm.faces.new(vs)
    sl = bmesh.ops.extrude_face_region(bm, geom=bm.faces[:])
    bmesh.ops.translate(bm, vec=(0.025, 0, 0), verts=[v for v in sl["geom"] if isinstance(v, bmesh.types.BMVert)])
    bmesh.ops.translate(bm, vec=(-0.0125, 0, 0), verts=bm.verts)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    mk_obj("fin", bm, "M_RustSheet", TMP)
    # sensor eyes + mandible plates
    for s in (-1, 1):
        cyl(TMP, "M_SkateCore", (0.08 * s, 0.6, 0.035), (0.085 * s, 0.645, 0.035), 0.03, 8, "eye")
        member(TMP, "M_Steel", (0.07 * s, 0.5, -0.07), (0.16 * s, 0.82, -0.08), 0.06, 0.02, "mandible")
        member(TMP, "M_Steel", (0.22 * s, 0.0, 0.0), (0.3 * s, 0.0, 0.0), 0.16, 0.08, "hinge")   # wing roots
    # cage round the core
    for k in range(4):
        a = (k + 0.5) / 4 * 2 * math.pi
        member(TMP, "M_Steel", (0.15 * math.cos(a), 0.15 * math.sin(a), -0.1), (0.13 * math.cos(a), 0.13 * math.sin(a), -0.33), 0.022, 0.022)
    cyl(TMP, "M_Steel", (0, 0, -0.33), (0, 0, -0.36), 0.15, 12, "cagering")
    cyl(TMP, "M_Cable", (0, 0, -0.36), (0, 0, -0.4), 0.05, 8, "cagetip", r2=0.01)
    # tail mounts
    for s in (-1, 1):
        cyl(TMP, "M_Steel", (0.08 * s, -0.55, 0), (0.08 * s, -0.66, 0), 0.04, 8, "tailmount")

def skate_core():
    ball("M_SkateCore", (0, 0, -0.2), 0.12, 2, (1, 1, 1.1))

def skate_wing(sx):
    # swept-back ray wing: leading edge root (0.28, 0.42) -> tip (1.28, -0.32); trailing edge -> (0.85, -0.5) -> root (0.28, -0.52)
    outline = [(0.28, 0.42), (0.75, 0.18), (1.28, -0.32), (0.85, -0.5), (0.28, -0.52)]
    bm = bmesh.new()
    def th(x):          # thick at the root, thin at the tip
        return 0.055 * (1.0 - (x - 0.28) / 1.1) + 0.012
    top = [bm.verts.new((sx * x, y, th(x) + 0.03 * (1 - (x - 0.28)))) for x, y in outline]
    bot = [bm.verts.new((sx * x, y, -th(x) * 0.6)) for x, y in outline]
    n = len(outline)
    bm.faces.new(top if sx > 0 else list(reversed(top)))
    bm.faces.new(list(reversed(bot)) if sx > 0 else bot)
    for i in range(n):
        f = (bot[i], bot[(i + 1) % n], top[(i + 1) % n], top[i])
        bm.faces.new(f if sx > 0 else tuple(reversed(f)))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    ob = mk_obj("wing", bm, "M_Corrugated", TMP)
    ob.data.materials.append(M("M_RustSheet"))
    for f in ob.data.polygons:
        if f.normal.z < -0.5: f.material_index = 1
    # ribs on top
    for (x1, y1) in ((1.2, -0.3), (0.95, -0.42), (0.7, 0.1)):
        member(TMP, "M_Steel", (sx * 0.3, 0.0, 0.07), (sx * x1, y1, th(x1) + 0.035), 0.035, 0.025)
    # serrated leading edge: steel teeth pointing forward-out
    le0 = Vector((0.28, 0.42)); le1 = Vector((0.75, 0.18)); le2 = Vector((1.28, -0.32))
    for (a, b, cnt) in ((le0, le1, 4), (le1, le2, 5)):
        d = (b - a); nrm = Vector((d.y, -d.x)).normalized()
        nrm = -nrm if nrm.y < 0 else nrm
        for k in range(cnt):
            p = a + d * ((k + 0.5) / cnt)
            bm2 = bmesh.new()
            w = d.normalized() * 0.05
            q0 = bm2.verts.new((sx * (p.x - w.x), p.y - w.y, 0.02)); q1 = bm2.verts.new((sx * (p.x + w.x), p.y + w.y, 0.02))
            q2 = bm2.verts.new((sx * (p.x + nrm.x * 0.11), p.y + nrm.y * 0.11, 0.02))
            q3 = bm2.verts.new((sx * (p.x - w.x), p.y - w.y, -0.02)); q4 = bm2.verts.new((sx * (p.x + w.x), p.y + w.y, -0.02))
            q5 = bm2.verts.new((sx * (p.x + nrm.x * 0.11), p.y + nrm.y * 0.11, -0.02))
            for f in ((q0, q1, q2), (q5, q4, q3), (q0, q3, q4, q1), (q1, q4, q5, q2), (q2, q5, q3, q0)):
                bm2.faces.new(f)
            bmesh.ops.recalc_face_normals(bm2, faces=bm2.faces)
            mk_obj("tooth", bm2, "M_Steel", TMP)
    # hazard-striped wing tip
    boxmm(TMP, "M_Hazard", sx * 1.05 - 0.09, sx * 1.05 + 0.09, -0.36, -0.22, -0.01, 0.035, "tip", 0.0)

def skate_tail(sx, k):
    y0 = -0.66 - 0.42 * k; y1 = y0 - 0.42
    cyl(TMP, "M_Cable", (sx * 0.08, y0, 0), (sx * 0.08, y1 + 0.02, 0), 0.022, 6, "cable")
    cyl(TMP, "M_Steel", (sx * 0.08, y0 - 0.02, 0), (sx * 0.08, y0 - 0.09, 0), 0.04, 8, "collar")
    if k == 2:
        cyl(TMP, "M_Steel", (sx * 0.08, y1 + 0.04, 0), (sx * 0.08, y1 - 0.14, 0), 0.06, 8, "barb", r2=0.004)
        for s in (-1, 1):
            member(TMP, "M_Hazard", (sx * 0.08, y1 + 0.02, 0), (sx * 0.08 + 0.09 * s, y1 + 0.12, 0), 0.04, 0.012)

def build_skate():
    C = "E7_Skate"
    c = e7coll(C)
    for o in list(c.objects): bpy.data.objects.remove(o, do_unlink=True)
    _clear_tmp()
    skate_hull(); merge("Skate_Hull", C)
    skate_core(); merge("Skate_Core", C, (0, 0, -0.2), parent="Skate_Hull")
    for side, sx in (("L", -1), ("R", 1)):
        skate_wing(sx); merge("Skate_Wing" + side, C, (sx * 0.28, 0, 0), parent="Skate_Hull")
        prev = "Skate_Hull"
        for k in range(3):
            skate_tail(sx, k)
            nm = "Skate_Tail%s%d" % (side, k)
            merge(nm, C, (sx * 0.08, -0.66 - 0.42 * k, 0), parent=prev)
            prev = nm
    # preview: float it off to the side of the tripod
    bpy.data.objects["Skate_Hull"].location = (3.5, 0, 0.5)
    print("skate:", [o.name for o in c.objects])

def build_all():
    _mats()
    build_tripod()
    build_skate()

# ====================================================================== export
def _export(names, fname):
    sc = bpy.context.scene
    tmp = bpy.data.collections.new("_EXPORT_TMP"); sc.collection.children.link(tmp)
    saved = {}
    for n in names:
        ob = bpy.data.objects[n]
        tmp.objects.link(ob)
        if ob.parent is None:          # export roots at the origin (the preview offsets are just for looking)
            saved[n] = ob.location.copy(); ob.location = (0, 0, 0)
    bpy.context.view_layer.update()
    for o in sc.objects:
        o.select_set(o.name in names)
    bpy.ops.export_scene.gltf(filepath=os.path.join(PROJ, "assets", "creatures", fname), export_format='GLB', use_selection=True,
                              use_active_scene=True, export_apply=True, export_yup=True)
    for n, loc in saved.items():
        bpy.data.objects[n].location = loc
    sc.collection.children.unlink(tmp); bpy.data.collections.remove(tmp)
    print("exported", fname)

def export_all():
    tri = ["Tri_Body", "Tri_Eye", "Tri_Lens"] + ["Tri_Thigh%d" % i for i in range(3)] + ["Tri_Shin%d" % i for i in range(3)]
    _export(tri, "tripod.glb")
    sk = ["Skate_Hull", "Skate_Core", "Skate_WingL", "Skate_WingR"] + ["Skate_Tail%s%d" % (s, k) for s in "LR" for k in range(3)]
    _export(sk, "skate.glb")
