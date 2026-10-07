# v13: the Sphaeroid - the Peak arena's boss (scripts/creatures/sphaeroid.gd). ~4.4 m tall (S13 scale 0.82).
# After the reference painting: a drip-streaked indigo iron ball with a rust-maroon four-point star on its face
# (tan ridge inlays, a pink edge, a white-rimmed red eye), a ribbed cannon riding an arm over the top right, a pale
# tapered pylon leg on its right and a stencilled sled skid on its left.
# Separate nodes so Godot can animate it (Blender +Y = forward = Godot -Z; Z up):
#   Sph_Frame  (root, origin = hull centre)  hubs on the roll axis (X), the yoke arms that hold the star, the cannon arm
#     Sph_Shell  (origin = hull centre)      the ball; it spins about X when rolling
#       Sph_Hatch  (origin on its hinge)       skate launch hatch on the back
#         Sph_HatchMouth (empty)                where launched skates appear
#     Sph_Star   (origin = star centre)      the faceplate; spins about Y (saw) when rolling
#       Sph_Eye                               the red pupil + slit (emissive M_SphEye)
#     Sph_Turret (origin = turret base)      yaws about Z
#       Sph_Cannon (origin = trunnion)         pitches about X; barrel along +Y
#         Sph_Muzzle (empty)                    shot spawn point
#     Sph_Leg    (origin = +X hub pivot)     folds up/back about X for the roll
#     Sph_Skid   (origin = -X hub pivot)     folds up/back about X for the roll
# Blender scene "Props13", collection SPHAEROID13 (in cavern.blend).
# Run: exec(open(r"D:\Emberlight\art_src\v13_sphaeroid.py").read()); build_sphaeroid()
#      then, with Props13 the active scene: export_sphaeroid()   -> assets/creatures/sphaeroid.glb
exec(open(r"D:\Emberlight\art_src\gen_lib.py").read())
PROJ = r"D:\Emberlight"
TEX = os.path.join(PROJ, "art_src", "tex")

if "Props13" not in bpy.data.scenes:
    bpy.data.scenes.new("Props13")
P13 = bpy.data.scenes["Props13"]
TMP13 = "S13_TMP"
COLL13 = "SPHAEROID13"

S13 = {
    "scale": 0.82,        # the whole model is built at the numbers below, then scaled about the feet (~4.4 m tall)
    "R": 2.2,             # hull radius
    "CZ": 2.65,           # hull centre height standing (rolling: = R)
    "hub_x": 2.5,         # leg / skid pivots on the roll axis (+-X)
    "star_y": 2.52,       # star back face radius: the star is wrapped onto a sphere this far out (clears the yoke)
    "star_z": -0.1,       # star centre below the hull centre
    "star_tip": 2.3, 
    "star_waist": 0.6, 
    "star_tilt": 0.0,     # degrees: 0 = points straight up/down and to the sides
    "turret": (1.55, -0.35, 1.68),
    "cannon_h": 0.45,     # trunnion above the turret base
    "barrel": (-1.25, 1.6, 0.5),   # y0, y1, radius (cannon-local)
    "hatch_dir": (0.0, -0.72, 0.69),
    "hatch_ang": 21.0,
}

def _c13(name):
    c = bpy.data.collections.get(name)
    if c is None:
        c = bpy.data.collections.new(name)
    if c.name not in P13.collection.children:
        P13.collection.children.link(c)
    return c

_c13(TMP13)       # gen_lib's coll() finds it by name instead of linking a new one into the active scene

# ---------------------------------------------------------------------------------------------- textures + mats
def _grade(src, dst, dark, light, rust, k, gamma=1.0):
    import numpy as np
    img = bpy.data.images.load(os.path.join(TEX, src), check_existing=False)
    w, h = img.size
    px = np.empty(w * h * 4, dtype=np.float32); img.pixels.foreach_get(px)
    px = px.reshape(-1, 4)
    r, g, b = px[:, 0], px[:, 1], px[:, 2]
    lum = np.clip(0.3 * r + 0.59 * g + 0.11 * b, 0, 1) ** gamma
    ru = np.clip((r - b) * 4.0, 0, 1)[:, None] * k
    d = np.array(dark, np.float32); l = np.array(light, np.float32); rc = np.array(rust, np.float32)
    out = d + (l - d) * lum[:, None]
    out = out * (1 - ru) + rc * ru
    px[:, :3] = np.clip(out, 0, 1)
    new = bpy.data.images.new(dst, w, h)
    new.pixels.foreach_set(px.ravel())
    new.filepath_raw = os.path.join(TEX, dst); new.file_format = 'JPEG'
    new.save()
    bpy.data.images.remove(new); bpy.data.images.remove(img)
    for i in bpy.data.images:          # a regrade: refresh any copy the materials already hold
        if i.filepath and os.path.basename(i.filepath) == dst:
            i.reload()

def grade_textures():
    _grade("rustsheet_albedo.jpg", "sph_hull_albedo.jpg", (0.05, 0.05, 0.11), (0.36, 0.35, 0.58), (0.22, 0.12, 0.16), 0.5, 1.15)
    _grade("rustsheet_albedo.jpg", "sph_leg_albedo.jpg", (0.24, 0.23, 0.34), (0.74, 0.72, 0.86), (0.42, 0.18, 0.11), 0.85)
    _grade("rustsheet_albedo.jpg", "sph_star_albedo.jpg", (0.10, 0.03, 0.03), (0.38, 0.13, 0.10), (0.26, 0.08, 0.05), 0.3)

def mats13():
    pbr_mat("M_SphHull", "sph_hull_albedo.jpg", "rustsheet_orm.jpg", "rustsheet_normal.jpg")
    pbr_mat("M_SphLeg", "sph_leg_albedo.jpg", "rustsheet_orm.jpg", "rustsheet_normal.jpg")
    pbr_mat("M_SphStar", "sph_star_albedo.jpg", "rustsheet_orm.jpg", "rustsheet_normal.jpg", 0.6)
    flat_mat("M_SphTan", (0.56, 0.40, 0.31), rough=0.7)
    flat_mat("M_SphPink", (0.86, 0.62, 0.58), rough=0.5)
    flat_mat("M_SphIris", (0.92, 0.84, 0.84), rough=0.35, emit=(1.0, 0.85, 0.85), strength=0.6)
    flat_mat("M_SphEye", (0.25, 0.01, 0.01), rough=0.3, emit=(1.0, 0.07, 0.05), strength=14.0)
    flat_mat("M_SphDark", (0.025, 0.022, 0.035), rough=0.85)
    flat_mat("M_SphViolet", (0.17, 0.13, 0.34), rough=0.55, metal=0.4)
    flat_mat("M_SphCore", (0.2, 0.05, 0.03), rough=0.3, emit=(1.0, 0.3, 0.12), strength=8.0)

# ---------------------------------------------------------------------------------------------- piece merging
_PIV = {}

def piece(name, build, pivot=(0, 0, 0), parent=None, uv=True, warp=None):
    """build() makes meshes in TMP13; they're merged into one object `name` whose origin is `pivot` (world)."""
    old = bpy.data.objects.get(name)
    if old: bpy.data.objects.remove(old, do_unlink=True)
    tmp = _c13(TMP13)
    for o in list(tmp.objects): bpy.data.objects.remove(o, do_unlink=True)
    build()
    objs = [o for o in tmp.objects if o.type == 'MESH']
    bm = bmesh.new(); mats = []
    for o in objs:
        nv, nf = len(bm.verts), len(bm.faces)
        bm.from_mesh(o.data); bm.verts.ensure_lookup_table(); bm.faces.ensure_lookup_table()
        rot = o.rotation_quaternion if o.rotation_mode == 'QUATERNION' else o.rotation_euler.to_quaternion()
        bmesh.ops.transform(bm, matrix=Matrix.LocRotScale(o.location, rot, o.scale), verts=bm.verts[nv:])
        remap = []
        for m in o.data.materials:
            if m not in mats: mats.append(m)
            remap.append(mats.index(m))
        for f in bm.faces[nf:]:
            f.material_index = remap[f.material_index] if f.material_index < len(remap) else 0
    for o in objs: bpy.data.objects.remove(o, do_unlink=True)
    if warp:
        for v in bm.verts: v.co = warp(v.co)
    sc = S13["scale"]
    for v in bm.verts: v.co = v.co * sc
    pivot = Vector(pivot) * sc
    bm.normal_update()
    lim = math.radians(40.0)
    for f in bm.faces: f.smooth = True
    for e in bm.edges:
        if len(e.link_faces) != 2 or e.calc_face_angle(0.0) > lim:
            e.smooth = False
    me = bpy.data.meshes.new(name); bm.to_mesh(me); bm.free()
    for m in mats: me.materials.append(m)
    ob = bpy.data.objects.new(name, me)
    _c13(COLL13).objects.link(ob)
    if uv and me.materials: box_uv(ob)
    me.transform(Matrix.Translation(-Vector(pivot)))
    _PIV[name] = Vector(pivot)
    if parent:
        ob.parent = bpy.data.objects[parent]
        ob.matrix_parent_inverse = Matrix.Identity(4)
        ob.location = Vector(pivot) - _PIV[parent]
    else:
        ob.location = pivot
    return ob

def marker(name, at, parent):
    old = bpy.data.objects.get(name)
    if old: bpy.data.objects.remove(old, do_unlink=True)
    e = bpy.data.objects.new(name, None)
    e.empty_display_size = 0.25
    _c13(COLL13).objects.link(e)
    e.parent = bpy.data.objects[parent]
    e.matrix_parent_inverse = Matrix.Identity(4)
    e.location = Vector(at) * S13["scale"] - _PIV[parent]
    return e

def text_mesh(s, at, size, yaw=0.0, mat="M_SphDark", depth=0.006):
    """Stencil lettering standing in the XZ plane facing -Y, turned by yaw."""
    cu = bpy.data.curves.new("txt13", 'FONT'); cu.body = s; cu.size = size; cu.extrude = depth
    cu.align_x = 'CENTER'; cu.align_y = 'CENTER'; cu.resolution_u = 2
    tob = bpy.data.objects.new("txt13", cu); _c13(TMP13).objects.link(tob)
    tob.rotation_euler = (math.radians(90), 0, yaw); tob.location = at
    dg = bpy.context.evaluated_depsgraph_get()
    me = bpy.data.meshes.new_from_object(tob.evaluated_get(dg))
    ob = bpy.data.objects.new("txt", me); _c13(TMP13).objects.link(ob)
    ob.location = tob.location; ob.rotation_euler = tob.rotation_euler
    me.materials.clear(); me.materials.append(M(mat))
    bpy.data.objects.remove(tob, do_unlink=True); bpy.data.curves.remove(cu)
    return ob

def C(x, y, z):
    """Hull-centre-relative -> world."""
    return Vector((x, y, z + S13["CZ"]))

def boxc(mat, x0, x1, y0, y1, z0, z1, name="box", bevel=0.03):
    """boxmm with hull-centre-relative heights."""
    cz = S13["CZ"]
    return boxmm(TMP13, mat, x0, x1, y0, y1, z0 + cz, z1 + cz, name, bevel)

def sph(d, r):
    """Point at radius r from the hull centre in direction d."""
    d = Vector(d).normalized()
    return C(*(d * r))

def ring(mat, axis, off, width, thick, seg=40, name="band"):
    """A seam band round the hull: a short fat disc on `axis` whose rim stands `thick` proud of the surface."""
    R = S13["R"]
    a = Vector(axis).normalized()
    rr = math.sqrt(max(R * R - off * off, 0.01)) + thick
    c = C(*(a * off))
    return cyl(TMP13, mat, c - a * width * 0.5, c + a * width * 0.5, rr, seg, name)

def pipe(mat, pts, r, seg=10):
    for i in range(len(pts) - 1):
        cyl(TMP13, mat, pts[i], pts[i + 1], r, seg, "pipe")
        if 0 < i:
            rockblob(TMP13, pts[i], (r, r, r), amp=0.0, seed=0, sub=1, mat=mat, name="joint")

# ---------------------------------------------------------------------------------------------- shell
def build_shell():
    R = S13["R"]
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=40, v_segments=20, radius=R)
    ob = mk_obj("hull", bm, "M_SphHull", TMP13); ob.location = C(0, 0, 0)
    # seam bands: two latitudes and a meridian (they tumble visibly when it rolls about X)
    ring("M_Steel", (0, 0, 1), 0.95, 0.12, 0.035, 40)
    ring("M_Steel", (0, 0, 1), -0.95, 0.12, 0.035, 40)
    ring("M_Steel", (0, 1, 0), 0.0, 0.12, 0.035, 40)
    # rivets along the meridian
    for k in range(28):
        a = k / 28 * 2 * math.pi
        d = Vector((math.cos(a), 0.0, math.sin(a)))
        p0 = sph(d, R + 0.02); p1 = sph(d, R + 0.075)
        for dy in (-0.1, 0.1):
            cyl(TMP13, "M_Steel", p0 + Vector((0, dy, 0)), p1 + Vector((0, dy, 0)), 0.025, 6, "rivet")
    # dark vent slots (the painting's slot on its right side) with steel slats
    for d in ((0.62, 0.38, 0.12), (-0.55, 0.3, -0.35)):
        d = Vector(d).normalized()
        c = sph(d, R - 0.02)
        ob = boxmm(TMP13, "M_SphDark", -0.32, 0.32, -0.12, 0.12, -0.42, 0.42, "vent", 0.02)
        ob.location = c
        ob.rotation_mode = 'QUATERNION'; ob.rotation_quaternion = d.to_track_quat('Y', 'Z')
        side = d.cross(Vector((0, 0, 1))).normalized(); up = side.cross(d).normalized()
        for k in range(5):
            o = up * (-0.32 + k * 0.16)
            member(TMP13, "M_Steel", c + d * 0.1 + o - side * 0.3, c + d * 0.1 + o + side * 0.3, 0.05, 0.03, "slat")
    # violet grab bars on its back left (the reference's purple tubes)
    for k in range(3):
        z = 0.55 - k * 0.55
        d0 = Vector((-0.78, -0.48, z)).normalized(); d1 = Vector((-0.55, -0.78, z)).normalized()
        a = sph(d0, R + 0.01); b = sph(d1, R + 0.01)
        a2 = sph(d0, R + 0.2); b2 = sph(d1, R + 0.2)
        pipe("M_SphViolet", [a, a2, b2, b], 0.06, 8)
    # hatch rim (the hatch itself is a child piece)
    hd = Vector(S13["hatch_dir"]).normalized()
    ha = math.radians(S13["hatch_ang"])
    rr = R * math.sin(ha) + 0.05
    c = sph(hd, R * math.cos(ha))
    cyl(TMP13, "M_Steel", c - hd * 0.05, c + hd * 0.32, rr, 24, "hatchrim")
    cyl(TMP13, "M_SphCore", c + hd * 0.05, c + hd * 0.33, rr - 0.12, 20, "hatchwell")     # glowing launch well
    # weld drips: short dark streak plates down the flanks
    random.seed(13)
    for k in range(16):
        a = random.uniform(0, 2 * math.pi); z = random.uniform(-0.2, 0.75)
        d = Vector((math.cos(a), math.sin(a), z)).normalized()
        d2 = Vector((d.x, d.y, d.z - random.uniform(0.25, 0.5))).normalized()
        member(TMP13, "M_SphDark", sph(d, R + 0.004), sph(d2, R + 0.004), 0.03, random.uniform(0.03, 0.07), "drip")

def _hatch_axes():
    hd = Vector(S13["hatch_dir"]).normalized()
    side = hd.cross(Vector((0, 0, 1))).normalized()
    up = side.cross(hd).normalized()
    return hd, side, up

def build_hatch():
    R = S13["R"]
    hd, side, up = _hatch_axes()
    ha = math.radians(S13["hatch_ang"])
    bm = bmesh.new()
    nr, na = 5, 24
    outer = []; inner = []
    for i in range(nr + 1):
        t = ha * i / nr
        ro = []; ri = []
        for j in range(na if i else 1):
            a = 2 * math.pi * j / na
            d = hd * math.cos(t) + (side * math.cos(a) + up * math.sin(a)) * math.sin(t)
            ro.append(bm.verts.new(sph(d, R + 0.33)))
            ri.append(bm.verts.new(sph(d, R + 0.25)))
        outer.append(ro); inner.append(ri)
    for rings, flip in ((outer, False), (inner, True)):
        for i in range(nr):
            a, b = rings[i], rings[i + 1]
            for j in range(na):
                f = (a[0], b[j], b[(j + 1) % na]) if len(a) == 1 else (a[j], b[j], b[(j + 1) % na], a[(j + 1) % na])
                bm.faces.new(tuple(reversed(f)) if flip else f)
    for j in range(na):
        o0, o1 = outer[nr][j], outer[nr][(j + 1) % na]; i0, i1 = inner[nr][j], inner[nr][(j + 1) % na]
        bm.faces.new((o0, i0, i1, o1))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    mk_obj("hatch", bm, "M_SphHull", TMP13)
    # hazard stripe + a handle
    c = sph(hd, R + 0.34)
    member(TMP13, "M_Hazard", c - side * 0.45, c + side * 0.45, 0.16, 0.02, "stripe")
    pipe("M_SphViolet", [c - up * 0.2 - side * 0.2, c - up * 0.2 - side * 0.2 + hd * 0.12,
                          c - up * 0.2 + side * 0.2 + hd * 0.12, c - up * 0.2 + side * 0.2], 0.04, 6)

def hatch_hinge():
    R = S13["R"]
    hd, side, up = _hatch_axes()
    ha = math.radians(S13["hatch_ang"])
    d = hd * math.cos(ha) + up * math.sin(ha)        # the hatch's top edge (towards the crown): hinge there
    return sph(d, R + 0.29)

# ---------------------------------------------------------------------------------------------- frame
def build_frame():
    R = S13["R"]; hx = S13["hub_x"]
    for s in (-1, 1):
        # axle hubs on the roll axis
        cyl(TMP13, "M_Steel", C(s * (R - 0.25), 0, 0), C(s * (hx + 0.02), 0, 0), 0.46, 20, "hub")
        cyl(TMP13, "M_SphDark", C(s * (hx + 0.02), 0, 0), C(s * (hx + 0.06), 0, 0), 0.3, 16, "hubcap")
        for k in range(8):
            a = k / 8 * 2 * math.pi
            o = Vector((0, math.cos(a), math.sin(a))) * 0.37
            cyl(TMP13, "M_Steel", C(s * hx, 0, 0) + o, C(s * (hx + 0.07), 0, 0) + o, 0.035, 6, "bolt")
        # yoke arm: round the equator to the front, then in to the star axle
        pts = []
        for k in range(8):
            a = math.radians(4 + k * 10)
            pts.append(C(s * (R + 0.16) * math.cos(a), (R + 0.16) * math.sin(a), 0.0))
        pts.append(C(s * 0.42, R + 0.16, -0.05)); pts.append(C(0.0, R + 0.16, S13["star_z"]))
        pipe("M_Steel", pts, 0.11, 10)
    # star axle housing
    cyl(TMP13, "M_Steel", C(0, R - 0.1, S13["star_z"]), C(0, S13["star_y"] + 0.02, S13["star_z"]), 0.28, 16, "axle")
    # cannon arm: off the +X hub, over the top, under the turret
    T = Vector(S13["turret"])
    pts = []
    for k in range(5):
        a = math.radians(6 + k * 10)
        pts.append(C((R + 0.2) * math.cos(a), -0.08 * k, (R + 0.2) * math.sin(a)))
    pts.append(C(T.x, T.y, T.z - 0.05))
    pipe("M_Steel", pts, 0.13, 10)
    # a rear brace for the turret
    pipe("M_Steel", [C(T.x, T.y - 0.1, T.z - 0.05), sph((0.55, -0.6, 0.55), R + 0.12), sph((0.45, -0.85, 0.2), R + 0.05)], 0.07, 8)
    # hydraulic cable loop between hub and turret
    pipe("M_Cable", [sph((0.9, 0.25, 0.25), R + 0.12), sph((0.75, 0.3, 0.55), R + 0.2), C(T.x - 0.2, T.y + 0.3, T.z + 0.05)], 0.035, 6)

def build_turret():
    T = C(*S13["turret"])
    cyl(TMP13, "M_Steel", T + Vector((0, 0, -0.1)), T + Vector((0, 0, 0.16)), 0.55, 20, "ring")
    cyl(TMP13, "M_SphDark", T + Vector((0, 0, 0.16)), T + Vector((0, 0, 0.2)), 0.5, 20, "ring2")
    for s in (-1, 1):       # trunnion cheeks
        boxmm(TMP13, "M_SphHull", T.x + s * 0.5 - 0.07, T.x + s * 0.5 + 0.07, T.y - 0.3, T.y + 0.3, T.z + 0.15, T.z + S13["cannon_h"] + 0.22, "cheek", 0.03)
        cyl(TMP13, "M_Steel", T + Vector((s * 0.4, 0, S13["cannon_h"])), T + Vector((s * 0.6, 0, S13["cannon_h"])), 0.13, 12, "pin")

def build_cannon():
    T = C(*S13["turret"])
    P = T + Vector((0, 0, S13["cannon_h"]))
    y0, y1, r = S13["barrel"]
    # main tube (the reference: a fat ribbed tube with a big open mouth)
    cyl(TMP13, "M_SphHull", P + Vector((0, y0, 0)), P + Vector((0, y1 - 0.12, 0)), r, 24, "barrel")
    rockblob(TMP13, P + Vector((0, y0, 0)), (r, r * 0.8, r), amp=0.0, seed=0, sub=2, mat="M_SphHull", name="breech")
    # flared mouth with a dark bore
    cyl(TMP13, "M_SphHull", P + Vector((0, y1 - 0.14, 0)), P + Vector((0, y1, 0)), r + 0.07, 24, "lip", r2=r + 0.1)
    cyl(TMP13, "M_SphDark", P + Vector((0, y1 - 0.9, 0)), P + Vector((0, y1 + 0.005, 0)), r - 0.07, 20, "bore")
    # ribs along the top + bands
    for k in range(6):
        a = math.radians(60 + k * 12)
        o = Vector((math.cos(a), 0, math.sin(a))) * (r + 0.015)
        member(TMP13, "M_SphLeg", P + o + Vector((0, y0 + 0.5, 0)), P + o + Vector((0, y1 - 0.35, 0)), 0.04, 0.05, "rib")
    for y in (y0 + 0.35, 0.15, y1 - 0.3):
        cyl(TMP13, "M_Steel", P + Vector((0, y - 0.05, 0)), P + Vector((0, y + 0.05, 0)), r + 0.04, 24, "band")
    # trunnion block + a sight
    boxmm(TMP13, "M_Steel", P.x - 0.4, P.x + 0.4, P.y - 0.35, P.y + 0.35, P.z - r - 0.08, P.z - 0.1, "block", 0.03)
    boxmm(TMP13, "M_SphDark", P.x - r - 0.12, P.x - r + 0.05, P.y + 0.5, P.y + 0.75, P.z + 0.05, P.z + 0.22, "sight", 0.01)
    cyl(TMP13, "M_SphEye", P + Vector((-r - 0.035, 0.76, 0.135)), P + Vector((-r - 0.035, 0.78, 0.135)), 0.05, 8, "sightlens")

# ---------------------------------------------------------------------------------------------- star
def star_r(theta):
    tilt = math.radians(S13["star_tilt"])
    d = (theta - tilt) % (math.pi / 2)
    d = min(d, math.pi / 2 - d) / (math.pi / 4)        # 0 at a tip, 1 between tips
    return S13["star_waist"] + (S13["star_tip"] - S13["star_waist"]) * (1 - d) ** 2.0, d

def _star_pt(theta, t, front):
    r, d = star_r(theta)
    w = 0.0
    if front:
        w = 0.12 + 0.2 * (1 - d) ** 1.4 * (1 - 0.75 * t) + 0.05 * (1 - t)
    sc = C(0, S13["star_y"], S13["star_z"])
    return sc + Vector((t * r * math.cos(theta), w, t * r * math.sin(theta)))

def build_star():
    na = 4 * 26
    t0 = math.radians(S13["star_tilt"])     # sample from a tip so every tip is a sharp vertex
    ts = [0.0, 0.12, 0.25, 0.42, 0.6, 0.78, 0.9, 1.0]
    bm = bmesh.new()
    front = []; back = []
    for t in ts:
        if t == 0.0:
            front.append([bm.verts.new(_star_pt(0, 0, True))]); back.append([bm.verts.new(_star_pt(0, 0, False))])
            continue
        front.append([bm.verts.new(_star_pt(t0 + 2 * math.pi * j / na, t, True)) for j in range(na)])
        back.append([bm.verts.new(_star_pt(t0 + 2 * math.pi * j / na, t, False)) for j in range(na)])
    for rings, flip in ((front, True), (back, False)):
        for i in range(len(ts) - 1):
            a, b = rings[i], rings[i + 1]
            for j in range(na):
                f = (a[0], b[j], b[(j + 1) % na]) if len(a) == 1 else (a[j], b[j], b[(j + 1) % na], a[(j + 1) % na])
                bm.faces.new(tuple(reversed(f)) if flip else f)
    for j in range(na):
        bm.faces.new((front[-1][j], back[-1][j], back[-1][(j + 1) % na], front[-1][(j + 1) % na]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    mk_obj("star", bm, "M_SphStar", TMP13)
    tilt = math.radians(S13["star_tilt"])
    up = Vector((0, 0.012, 0))
    for k in range(4):
        th = tilt + k * math.pi / 2
        # tan ridge inlay + a cross tick near the hub
        for k2 in range(6):
            ta, tb = 0.3 + 0.56 * k2 / 6, 0.3 + 0.56 * (k2 + 1) / 6
            member(TMP13, "M_SphTan", _star_pt(th, ta, True) + up, _star_pt(th, tb, True) + up, 0.07, 0.02, "inlay")
        p = _star_pt(th, 0.36, True) + up * 2
        n = Vector((-math.sin(th), 0, math.cos(th)))
        member(TMP13, "M_SphTan", p - n * 0.17, p + n * 0.17, 0.05, 0.02, "tick")
        # pink highlight along the leading edge of each point (the spin direction)
        prev = None
        for s in range(9):
            a = th + math.radians(2 + s * 4.5)
            q = _star_pt(a, 0.985, True) + up
            if prev is not None:
                member(TMP13, "M_SphPink", prev, q, 0.035, 0.02, "edge")
            prev = q
    # hub: dark ring + white rim
    sc = C(0, S13["star_y"], S13["star_z"])
    cyl(TMP13, "M_SphDark", sc + Vector((0, 0.2, 0)), sc + Vector((0, 0.42, 0)), 0.55, 28, "hubring")
    cyl(TMP13, "M_SphIris", sc + Vector((0, 0.42, 0)), sc + Vector((0, 0.46, 0)), 0.42, 28, "iris")
    cyl(TMP13, "M_SphDark", sc + Vector((0, 0.46, 0)), sc + Vector((0, 0.47, 0)), 0.22, 20, "pupilring")

def build_eye():
    sc = C(0, S13["star_y"], S13["star_z"])
    cyl(TMP13, "M_SphEye", sc + Vector((0, 0.46, 0)), sc + Vector((0, 0.5, 0)), 0.15, 20, "pupil")
    member(TMP13, "M_SphEye", sc + Vector((-0.4, 0.475, 0)), sc + Vector((0.4, 0.475, 0)), 0.03, 0.04, "slit")

def star_warp(co):
    """Bend the flat-built star onto the shell: a point at planar distance rho from the star centre (its back plane
    at star_y) goes to angle rho / star_y round a sphere of radius star_y about the hull axis at star height, so the
    arms hug the ball; the relief (forward offset from the back plane) stands out along the sphere normal."""
    rs = S13["star_y"]
    c0 = C(0, 0, S13["star_z"])
    u, v = co.x - c0.x, co.z - c0.z
    w = co.y - rs
    rho = math.hypot(u, v)
    if rho < 1e-6:
        return Vector((c0.x, rs + w, c0.z))
    phi = rho / rs
    du, dv = u / rho, v / rho
    r = rs + w
    return Vector((c0.x + r * math.sin(phi) * du, r * math.cos(phi), c0.z + r * math.sin(phi) * dv))

# ---------------------------------------------------------------------------------------------- leg + skid
def build_leg():
    hx = S13["hub_x"]; cz = S13["CZ"]
    bm = bmesh.new()
    zb, zt = -cz + 0.12, 0.3
    vb = [(hx + 0.02, -1.05), (hx + 0.8, -1.05), (hx + 0.8, 1.05), (hx + 0.02, 1.05)]
    vt = [(hx + 0.02, -0.55), (hx + 0.48, -0.55), (hx + 0.48, 0.55), (hx + 0.02, 0.55)]
    lo = [bm.verts.new(C(x, y, zb)) for x, y in vb]; hi = [bm.verts.new(C(x, y, zt)) for x, y in vt]
    bm.faces.new(list(reversed(lo))); bm.faces.new(hi)
    for i in range(4):
        bm.faces.new((lo[i], lo[(i + 1) % 4], hi[(i + 1) % 4], hi[i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    _bevel(bm, 0.05)
    mk_obj("pylon", bm, "M_SphLeg", TMP13)
    # rounded crown over the hub, a steel band, a dark inset slot, foot plate
    cyl(TMP13, "M_SphLeg", C(hx + 0.02, 0, 0), C(hx + 0.42, 0, 0), 0.6, 20, "crown")
    cyl(TMP13, "M_Steel", C(hx + 0.42, 0, 0), C(hx + 0.5, 0, 0), 0.32, 16, "pin")
    boxc("M_Steel", hx + 0.0, hx + 0.72, -0.86, 0.86, -1.35, -1.12, "band", 0.03)
    boxc("M_SphDark", hx + 0.55, hx + 0.7, -0.24, 0.24, -0.95, -0.25, "slot", 0.02)
    boxc("M_Steel", hx - 0.1, hx + 0.95, -1.2, 1.2, -cz, -cz + 0.14, "foot", 0.04)
    for s in (-1, 1):
        member(TMP13, "M_Rust", C(hx + 0.74, s * 0.6, -1.5), C(hx + 0.79, s * 0.75, -cz + 0.2), 0.04, 0.03, "streak")

def build_skid():
    hx = S13["hub_x"]; cz = S13["CZ"]
    # strut from the -X hub down to the sled
    bm = bmesh.new()
    zb, zt = -cz + 0.28, 0.3
    vb = [(-hx - 0.02, -0.35), (-hx - 0.02, 1.15), (-hx - 0.72, 1.15), (-hx - 0.72, -0.35)]
    vt = [(-hx - 0.02, -0.5), (-hx - 0.02, 0.5), (-hx - 0.46, 0.5), (-hx - 0.46, -0.5)]
    lo = [bm.verts.new(C(x, y, zb)) for x, y in vb]; hi = [bm.verts.new(C(x, y, zt)) for x, y in vt]
    bm.faces.new(list(reversed(lo))); bm.faces.new(hi)
    for i in range(4):
        bm.faces.new((lo[i], lo[(i + 1) % 4], hi[(i + 1) % 4], hi[i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    _bevel(bm, 0.05)
    mk_obj("strut", bm, "M_SphLeg", TMP13)
    boxc("M_Steel", -hx - 0.75, -hx + 0.01, -0.5, 1.3, -1.15, -0.93, "band", 0.03)
    boxc("M_SphDark", -hx - 0.74, -hx - 0.6, 0.15, 0.6, -0.8, -0.2, "slot", 0.02)
    cyl(TMP13, "M_SphLeg", C(-hx - 0.02, 0, 0), C(-hx - 0.42, 0, 0), 0.48, 18, "crown")
    cyl(TMP13, "M_Steel", C(-hx - 0.42, 0, 0), C(-hx - 0.5, 0, 0), 0.28, 16, "pin")
    # the sled plate (pale, stencilled) with an upturned nose
    x0, x1 = -hx - 0.75, -hx + 0.35
    boxc("M_SphLeg", x0, x1, -1.25, 1.35, -cz, -cz + 0.24, "sled", 0.04)
    member(TMP13, "M_SphLeg", C((x0 + x1) / 2, 1.3, -cz + 0.12), C((x0 + x1) / 2, 1.75, -cz + 0.5), x1 - x0, 0.2, "nose", 0.03)
    boxc("M_Steel", x0 + 0.1, x1 - 0.1, -1.2, 1.3, -cz + 0.24, -cz + 0.3, "deck", 0.02)
    text_mesh("II-151V", C(x0 - 0.004, 0.05, -cz + 0.12), 0.15, yaw=-math.pi / 2)

# ---------------------------------------------------------------------------------------------- build / export
def build_sphaeroid(regrade=True):
    if regrade or not os.path.exists(os.path.join(TEX, "sph_hull_albedo.jpg")):
        grade_textures()
    mats13()
    c = _c13(COLL13)
    for o in list(c.objects): bpy.data.objects.remove(o, do_unlink=True)
    T = C(*S13["turret"])
    hx = S13["hub_x"]
    piece("Sph_Frame", build_frame, C(0, 0, 0))
    piece("Sph_Shell", build_shell, C(0, 0, 0), "Sph_Frame")
    piece("Sph_Hatch", build_hatch, hatch_hinge(), "Sph_Shell")
    marker("Sph_HatchMouth", sph(S13["hatch_dir"], S13["R"] + 0.3), "Sph_Hatch")
    piece("Sph_Star", build_star, C(0, S13["star_y"], S13["star_z"]), "Sph_Frame", warp=star_warp)
    piece("Sph_Eye", build_eye, C(0, S13["star_y"], S13["star_z"]), "Sph_Star", warp=star_warp)
    piece("Sph_Turret", build_turret, T, "Sph_Frame")
    piece("Sph_Cannon", build_cannon, T + Vector((0, 0, S13["cannon_h"])), "Sph_Turret")
    marker("Sph_Muzzle", T + Vector((0, S13["barrel"][1] + 0.05, S13["cannon_h"])), "Sph_Cannon")
    piece("Sph_Leg", build_leg, C(hx, 0, 0), "Sph_Frame")
    piece("Sph_Skid", build_skid, C(-hx, 0, 0), "Sph_Frame")
    tmp = bpy.data.collections.get(TMP13)
    if tmp:
        for o in list(tmp.objects): bpy.data.objects.remove(o, do_unlink=True)
    zs = [(o.matrix_world @ Vector(b)).z for o in c.objects if o.type == 'MESH' for b in o.bound_box]
    print("sphaeroid built:", sorted(o.name for o in c.objects), "height %.2f" % max(zs))

def export_sphaeroid():
    sc = bpy.context.scene
    assert sc.name == "Props13", "make Props13 the active scene first"
    names = {o.name for o in bpy.data.collections[COLL13].objects}
    for o in sc.objects:
        o.select_set(o.name in names)
    bpy.ops.export_scene.gltf(filepath=os.path.join(PROJ, "assets", "creatures", "sphaeroid.glb"), export_format='GLB',
                              use_selection=True, use_active_scene=True, export_apply=True, export_yup=True)
    print("exported sphaeroid.glb", sorted(names))
