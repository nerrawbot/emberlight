
# v3: lift shaft through to the surface + surface headframe, and a tunnel behind the low-ledge walkway.
# Run inside Blender (Scene "Scene"). Re-runnable: it removes previous V3 objects first,
# but the rock/surface carve and island removal are destructive, so run it on a fresh copy
# of art_src/backup/cavern_pre_v3.blend if you need to redo it.
exec(open(r"C:\Users\Pigeon\Documents\UnderworksCavern\art_src\gen_lib.py").read())
sc = bpy.data.scenes["Scene"]
bpy.context.window.scene = sc

# ---------------------------------------------------------------- layout constants (Blender coords)
# shaft opening: car X 19.2..22.2, Y -4.4..-1.4 plus the counterweight lane at Y -5.2
SX0, SX1, SY0, SY1 = 18.6, 22.8, -5.8, -0.8
SURF = 34.3                 # surface walking height
SHEAVE_C = Vector((20.7, -4.05, 41.6))
SHEAVE_R = 1.15
# tunnel behind the low-ledge walkway
TX0, TX1, TY0, TY1 = -10.4, 3.0, -10.05, -7.35
TFLOOR, TCEIL = 1.6, 4.5


def carve(ob, lo, hi, pad=1.5):
    """Cut an axis-aligned box hole into a mesh: bisect along the box planes near the box, delete faces inside."""
    bm = bmesh.new(); bm.from_mesh(ob.data)
    mw = ob.matrix_world; inv = mw.inverted()
    lo_l = inv @ Vector(lo); hi_l = inv @ Vector(hi)
    lo_l, hi_l = Vector([min(a, b) for a, b in zip(lo_l, hi_l)]), Vector([max(a, b) for a, b in zip(lo_l, hi_l)])
    def near(f):
        mn = [min(v.co[i] for v in f.verts) for i in range(3)]; mx = [max(v.co[i] for v in f.verts) for i in range(3)]
        return all(mx[i] > lo_l[i] - pad and mn[i] < hi_l[i] + pad for i in range(3))
    for axis in range(3):
        for val in (lo_l[axis], hi_l[axis]):
            faces = [f for f in bm.faces if near(f)]
            if not faces: continue
            edges = list({e for f in faces for e in f.edges}); verts = list({v for f in faces for v in f.verts})
            no = Vector((0, 0, 0)); no[axis] = 1.0; co = Vector((0, 0, 0)); co[axis] = val
            bmesh.ops.bisect_plane(bm, geom=verts + edges + faces, plane_co=co, plane_no=no, dist=1e-4)
    dead = [f for f in bm.faces if all(lo_l[i] + 1e-3 < f.calc_center_median()[i] < hi_l[i] - 1e-3 for i in range(3))]
    bmesh.ops.delete(bm, geom=dead, context='FACES')
    bm.to_mesh(ob.data); bm.free(); ob.data.update()
    return len(dead)


def kill_islands(name, pred):
    ob = sc.objects[name]
    return remove_islands(ob, pred)


def fresh(cname):
    c = bpy.data.collections.get(cname)
    if c:
        for o in list(c.objects): bpy.data.objects.remove(o, do_unlink=True)
    else:
        c = bpy.data.collections.new(cname); sc.collection.children.link(c)
    return c


def run_carve():
    log = {}
    log["rock_shaft"] = carve(sc.objects["Rock-col"], (SX0, SY0, 25.5), (SX1, SY1, 36.0))
    log["surface_shaft"] = carve(sc.objects["Surface-col"], (SX0, SY0, 33.0), (SX1, SY1, 35.5), pad=0.5)
    log["rock_tunnel"] = carve(sc.objects["Rock-col"], (TX0 - 0.5, TY0, TFLOOR - 0.05), (TX1 + 0.3, TY1, TCEIL + 0.1))
    # old in-cavern sheave, its beam + motor, and the lamp hanging in the car's new path
    log["d2_sheave"] = kill_islands("Detail2", lambda mn, mx, c: mn.x > 19.5 and (mx.y - mn.y) < 2.0 and 27.5 < c.z < 29.5 and -4.4 < c.y < -1.4)
    log["lamp_in_shaft"] = kill_islands("Lamps2", lambda mn, mx, c: 20.3 < c.x < 21.1 and -3.3 < c.y < -2.5 and 25.8 < c.z < 27.1)
    # junk blocking the walkway's dead end
    log["s2_block"] = kill_islands("Struct2-col", lambda mn, mx, c: 0.5 < c.x < 1.5 and -8.6 < c.y < -7.4 and 1.6 < c.z < 2.4)
    log["d2_block"] = kill_islands("Detail2", lambda mn, mx, c: 0.5 < c.x < 1.3 and -8.6 < c.y < -8.0 and 1.5 < c.z < 2.4)
    log["ferns_mouth"] = kill_islands("Foliage", lambda mn, mx, c: c.x < 1.4 and -10.0 < c.y < -7.3 and 1.0 < c.z < 2.1)
    print("carve:", log)


# ---------------------------------------------------------------- shaft lining + surface headframe
def build_lift3():
    C = "V3Lift"; fresh(C)
    t = 0.3
    zb = 28.6
    boxmm(C, "M_Concrete", SX0 - t, SX0, SY0 - t, SY1 + t, zb, SURF, "lw", 0.0)
    boxmm(C, "M_Concrete", SX1, SX1 + t, SY0 - t, SY1 + t, zb, SURF, "le", 0.0)
    boxmm(C, "M_Concrete", SX0, SX1, SY0 - t, SY0, zb, SURF, "ls", 0.0)
    boxmm(C, "M_Concrete", SX0, SX1, SY1, SY1 + t, zb, SURF, "ln", 0.0)
    # ring beam where the lining meets the cavern ceiling (hides the rock seam)
    for (a, b) in (((SX0 - 0.45, SY0 - 0.45), (SX1 + 0.45, SY0)), ((SX0 - 0.45, SY1), (SX1 + 0.45, SY1 + 0.45)),
                   ((SX0 - 0.45, SY0), (SX0, SY1)), ((SX1, SY0), (SX1 + 0.45, SY1))):
        boxmm(C, "M_Concrete", a[0], b[0], a[1], b[1], zb - 0.5, zb + 0.6, "ring", 0.04)
    # guide rails inside the lining (continue the tower's corner posts up to the surface)
    for x in (18.9, 22.5):
        for y in (-4.7, -1.1):
            member(C, "M_Steel", (x, y, 28.0), (x, y, SURF + 0.05), 0.14, 0.14)
    # surface collar: curb on N/S/W, steel landing plate with hazard edge on the east
    cw = 0.35; ch = 0.18
    boxmm(C, "M_Concrete", SX0 - t - cw, SX0 - t, SY0 - t - cw, SY1 + t + cw, SURF - 0.3, SURF + ch, "curbw", 0.03)
    boxmm(C, "M_Concrete", SX0 - t, SX1 + t, SY0 - t - cw, SY0 - t, SURF - 0.3, SURF + ch, "curbs", 0.03)
    boxmm(C, "M_Concrete", SX0 - t, SX1 + t, SY1 + t, SY1 + t + cw, SURF - 0.3, SURF + ch, "curbn", 0.03)
    boxmm(C, "M_Steel", SX1, SX1 + 2.2, -4.55, -1.25, SURF - 0.05, SURF + 0.015, "landing", 0.0)
    boxmm(C, "M_Hazard", SX1, SX1 + 0.35, -4.55, -1.25, SURF + 0.015, SURF + 0.02, "lhaz", 0.0)
    # sill bridging the gap between the car (outer edge X 22.38) and the lining
    boxmm(C, "M_Steel", 22.42, SX1, -4.4, -1.4, SURF - 0.25, SURF, "sill", 0.0)
    # east side: concrete stub over the counterweight lane so nobody walks into it
    boxmm(C, "M_Concrete", SX1, SX1 + t + cw, SY0 - t, -4.6, SURF - 0.3, SURF + ch, "curbe", 0.03)
    # railings on the curbs
    rz = SURF + ch
    railing(C, (SX0 - t - 0.17, SY0 - t - 0.17, rz), (SX0 - t - 0.17, SY1 + t + 0.17, rz), h=1.1, spacing=1.6)
    railing(C, (SX0 - t - 0.17, SY0 - t - 0.17, rz), (SX1 + t + 0.17, SY0 - t - 0.17, rz), h=1.1, spacing=1.6)
    railing(C, (SX0 - t - 0.17, SY1 + t + 0.17, rz), (SX1 + t + 0.17, SY1 + t + 0.17, rz), h=1.1, spacing=1.6)
    railing(C, (SX1 + t + 0.17, SY0 - t - 0.17, rz), (SX1 + t + 0.17, -4.6, rz), h=1.1, spacing=1.6)
    # headframe: four legs, two levels of girts, diagonal bracing, sheave deck
    top = 43.0
    lx = (SX0 - t - 0.17, SX1 + t + 0.17); ly = (SY0 - t - 0.17, SY1 + t + 0.17)
    for x in lx:
        for y in ly:
            ibeam(C, (x, y, SURF - 0.3), (x, y, top), h=0.34, w=0.26)
            boxmm(C, "M_Concrete", x - 0.35, x + 0.35, y - 0.35, y + 0.35, SURF - 0.1, SURF + 0.35, "pad", 0.04)
    for z in (38.6, top):
        ibeam(C, (lx[0], ly[0], z), (lx[1], ly[0], z), h=0.3, w=0.22)
        ibeam(C, (lx[0], ly[1], z), (lx[1], ly[1], z), h=0.3, w=0.22)
        ibeam(C, (lx[0], ly[0], z), (lx[0], ly[1], z), h=0.3, w=0.22)
        ibeam(C, (lx[1], ly[0], z), (lx[1], ly[1], z), h=0.3, w=0.22)
    for y in ly:   # X-bracing on the long sides (N/S), upper bay only so the landing stays clear
        member(C, "M_Steel", (lx[0], y, 38.6), (lx[1], y, top), 0.1, 0.1)
        member(C, "M_Steel", (lx[1], y, 38.6), (lx[0], y, top), 0.1, 0.1)
    for x in (lx[0],):  # west face fully braced
        member(C, "M_Steel", (x, ly[0], SURF + 0.3), (x, ly[1], 38.6), 0.1, 0.1)
        member(C, "M_Steel", (x, ly[1], SURF + 0.3), (x, ly[0], 38.6), 0.1, 0.1)
        member(C, "M_Steel", (x, ly[0], 38.6), (x, ly[1], top), 0.1, 0.1)
        member(C, "M_Steel", (x, ly[1], 38.6), (x, ly[0], top), 0.1, 0.1)
    # sheave bearers (the wheel itself is a separate prop so it can turn)
    for x in (SHEAVE_C.x - 0.45, SHEAVE_C.x + 0.45):
        ibeam(C, (x, ly[0], top), (x, ly[1], top), h=0.36, w=0.24)
        boxmm(C, "M_Rust", x - 0.15, x + 0.15, SHEAVE_C.y - 0.3, SHEAVE_C.y + 0.3, SHEAVE_C.z - 0.25, top - 0.15, "bearing", 0.03)
    cyl(C, "M_Steel", (SHEAVE_C.x - 0.6, SHEAVE_C.y, SHEAVE_C.z), (SHEAVE_C.x + 0.6, SHEAVE_C.y, SHEAVE_C.z), 0.09, 10, "axle")
    # winch house beside the headframe (west), with a hazard band
    boxmm(C, "M_Corrugated", 13.6, 17.2, -5.6, -1.2, SURF, SURF + 3.2, "house", 0.05)
    boxmm(C, "M_Steel", 13.4, 17.4, -5.8, -1.0, SURF + 3.2, SURF + 3.45, "roof", 0.03)
    boxmm(C, "M_Hazard", 13.58, 17.22, -5.62, -1.18, SURF + 2.6, SURF + 2.85, "band", 0.0)
    cyl(C, "M_Steel", (17.2, -3.4, SURF + 2.4), (lx[0], -3.4, 41.3), 0.05, 6, "rope")
    # lamp housing on the east girt, looking down on the landing
    boxmm(C, "M_Steel", 23.05, 23.45, -3.1, -2.7, 38.25, 38.55, "lamph", 0.02)
    boxmm(C, "M_Lamp", 23.1, 23.4, -3.05, -2.75, 38.2, 38.26, "lampg", 0.0)
    ob = join_into("Lift3-col", C)
    print("Lift3-col", len(ob.data.vertices))
    return ob


# ---------------------------------------------------------------- tunnel
def build_tunnel():
    C = "V3Tunnel"; fresh(C)
    # floor and walls (walls/ceiling are displaced rock slabs, kept clear of the walking width)
    boxmm(C, "M_Concrete", TX0, 0.3, TY0, TY1, TFLOOR - 0.35, TFLOOR, "floor", 0.0)   # the walkway slab covers X 0..13
    rockslab(C, TX0 - 0.3, TX1 + 0.6, TY0 - 1.1, TY0 - 0.12, TFLOOR - 0.6, TCEIL + 0.9, amp=0.22, freq=0.55, seed=31, spacing=0.9, name="ws")
    rockslab(C, TX0 - 0.3, TX1 + 0.6, TY1 + 0.12, TY1 + 1.1, TFLOOR - 0.6, TCEIL + 0.9, amp=0.22, freq=0.55, seed=32, spacing=0.9, name="wn")
    rockslab(C, TX0 - 0.3, TX1 + 0.6, TY0 - 1.0, TY1 + 1.0, TCEIL + 0.12, TCEIL + 1.2, amp=0.22, freq=0.55, seed=33, spacing=0.9, name="wc")
    # steel sets every ~2 m
    x = TX1 - 0.9
    while x > TX0 + 0.8:
        for y in (TY0 + 0.12, TY1 - 0.12):
            ibeam(C, (x, y, TFLOOR), (x, y, TCEIL - 0.1), h=0.22, w=0.16, mat="M_Rust")
        ibeam(C, (x, TY0 + 0.05, TCEIL - 0.1), (x, TY1 - 0.05, TCEIL - 0.1), h=0.24, w=0.18, mat="M_Rust")
        x -= 2.1
    # lagging boards on the ceiling between sets
    for k in range(5):
        boxmm(C, "M_Rust", TX0 + 0.5, TX1 - 0.5, TY0 + 0.35 + k * 0.5, TY0 + 0.6 + k * 0.5, TCEIL - 0.02, TCEIL + 0.03, "lag", 0.0)
    # cable tray + pipe along the north wall
    cyl(C, "M_Steel", (TX0 + 0.3, TY1 - 0.3, 3.9), (TX1 + 0.4, TY1 - 0.3, 3.9), 0.09, 8, "pipe")
    for k in range(5):
        xx = TX0 + 1.0 + k * 2.1
        member(C, "M_Steel", (xx, TY1 - 0.05, 3.9), (xx, TY1 - 0.32, 3.9), 0.05, 0.05)
    # drainage gutter grate along the south edge
    boxmm(C, "M_Grate", TX0 + 0.2, 0.3, TY0 + 0.05, TY0 + 0.45, TFLOOR, TFLOOR + 0.012, "gutter", 0.0)
    # mouth portal (hides the rock seam)
    boxmm(C, "M_Concrete", TX1 - 0.6, TX1, TY0 - 0.6, TY0 + 0.02, TFLOOR - 0.4, TCEIL + 0.5, "pp_s", 0.05)
    boxmm(C, "M_Concrete", TX1 - 0.6, TX1, TY1 - 0.02, TY1 + 0.6, TFLOOR - 0.4, TCEIL + 0.5, "pp_n", 0.05)
    boxmm(C, "M_Concrete", TX1 - 0.65, TX1 + 0.05, TY0 - 0.6, TY1 + 0.6, TCEIL - 0.05, TCEIL + 0.9, "lintel", 0.05)
    boxmm(C, "M_Hazard", TX1 + 0.03, TX1 + 0.05, TY0 + 0.1, TY1 - 0.1, TCEIL + 0.05, TCEIL + 0.35, "haz", 0.0)
    # bulkhead at the far end with an open doorway into the dark
    bx = TX0 + 0.25
    boxmm(C, "M_Concrete", bx - 0.5, bx, TY0 - 0.2, -9.25, TFLOOR - 0.3, TCEIL + 0.3, "bh_s", 0.03)
    boxmm(C, "M_Concrete", bx - 0.5, bx, -8.15, TY1 + 0.2, TFLOOR - 0.3, TCEIL + 0.3, "bh_n", 0.03)
    boxmm(C, "M_Concrete", bx - 0.5, bx, -9.25, -8.15, 3.9, TCEIL + 0.3, "bh_t", 0.03)
    for y in (-9.3, -8.1):
        member(C, "M_Steel", (bx + 0.05, y, TFLOOR), (bx + 0.05, y, 3.95), 0.14, 0.14)
    member(C, "M_Steel", (bx + 0.05, -9.37, 3.95), (bx + 0.05, -8.03, 3.95), 0.14, 0.18)
    boxmm(C, "M_Hazard", bx + 0.0, bx + 0.02, -9.25, -8.15, 3.95, 4.15, "bh_haz", 0.0)
    # one door leaf hanging open against the wall
    boxmm(C, "M_Rust", bx + 0.08, bx + 1.2, TY1 - 0.18, TY1 - 0.1, TFLOOR + 0.05, 3.85, "leaf", 0.02)
    # dark vestibule behind the doorway (what you see through it)
    boxmm(C, "M_Silhouette", bx - 3.0, bx - 2.8, -9.6, -7.8, TFLOOR - 0.3, 4.2, "void_back", 0.0)
    boxmm(C, "M_Silhouette", bx - 2.9, bx - 0.45, -9.6, -9.4, TFLOOR - 0.3, 4.2, "void_s", 0.0)
    boxmm(C, "M_Silhouette", bx - 2.9, bx - 0.45, -8.0, -7.8, TFLOOR - 0.3, 4.2, "void_n", 0.0)
    boxmm(C, "M_Silhouette", bx - 2.9, bx - 0.45, -9.6, -7.8, 4.0, 4.2, "void_t", 0.0)
    boxmm(C, "M_Concrete", bx - 2.9, bx - 0.45, -9.6, -7.8, TFLOOR - 0.3, TFLOOR, "void_f", 0.0)
    # cage lamps on two of the sets
    for xx in (TX1 - 3.0, TX0 + 2.4):
        boxmm(C, "M_Steel", xx - 0.12, xx + 0.12, -8.82, -8.58, TCEIL - 0.42, TCEIL - 0.22, "lh", 0.01)
        boxmm(C, "M_Lamp", xx - 0.08, xx + 0.08, -8.78, -8.62, TCEIL - 0.47, TCEIL - 0.42, "lg", 0.0)
    ob = join_into("Tunnel-col", C)
    print("Tunnel-col", len(ob.data.vertices))
    return ob


# ---------------------------------------------------------------- moving props: sheave + stair gate
def build_props3():
    exec(open(r"C:\Users\Pigeon\Documents\UnderworksCavern\art_src\v2_creatures.py").read().split("T=\"TMP\"")[0], globals())
    T = "TMP"
    def sheave():
        r = SHEAVE_R
        for k in range(24):
            a0 = k / 24 * 2 * math.pi; a1 = (k + 1) / 24 * 2 * math.pi
            for dx in (-0.09, 0.09):
                member(T, "M_Rust", (dx, r * math.cos(a0), r * math.sin(a0)), (dx, r * math.cos(a1), r * math.sin(a1)), 0.05, 0.16)
            member(T, "M_Steel", (0, (r - 0.06) * math.cos(a0), (r - 0.06) * math.sin(a0)), (0, (r - 0.06) * math.cos(a1), (r - 0.06) * math.sin(a1)), 0.14, 0.06)
        for k in range(6):
            a = k / 6 * 2 * math.pi
            member(T, "M_Rust", (0, 0, 0), (0, (r - 0.08) * math.cos(a), (r - 0.08) * math.sin(a)), 0.06, 0.09)
        cyl(T, "M_Steel", (-0.16, 0, 0), (0.16, 0, 0), 0.2, 12, "hub")
        boxmm(T, "M_Hazard", -0.165, -0.16, -0.05, 0.05, 0.25, r - 0.15, "mark", 0.0)
    part("Sheave", "PROPS3", sheave, (0, 0, 0))
    # stair gate: frame across the stairwell top, two leaves hinged on the outer posts.
    # local frame: gate plane is YZ (spans Y -1.65..1.65), leaves swing towards -X (the surface side).
    def gframe():
        for y in (-1.72, 1.72):
            member(T, "M_Steel", (0, y, 0), (0, y, 2.75), 0.16, 0.16)
            boxmm(T, "M_Concrete", -0.25, 0.25, y - 0.25, y + 0.25, -0.05, 0.12, "foot", 0.03)
        member(T, "M_Steel", (0, -1.8, 2.75), (0, 1.8, 2.75), 0.18, 0.22)
        boxmm(T, "M_Hazard", -0.12, -0.115, -1.6, 1.6, 2.66, 2.84, "haz", 0.0)
        boxmm(T, "M_Rust", -0.3, -0.12, 1.85, 2.15, 0.9, 1.5, "lockbox", 0.03)
    part("GateFrame", "PROPS3", gframe, (0, 0, 0))
    def leaf(s):
        def b():
            y0, y1 = (-1.62, -0.02) if s < 0 else (0.02, 1.62)
            for z in (0.12, 1.3, 2.55):
                member(T, "M_Rust", (0, y0, z), (0, y1, z), 0.07, 0.08)
            for y in (y0, y1):
                member(T, "M_Rust", (0, y, 0.08), (0, y, 2.6), 0.08, 0.08)
            n = 9
            for i in range(1, n):
                y = y0 + (y1 - y0) * i / n
                member(T, "M_Steel", (0, y, 0.12), (0, y, 2.55), 0.03, 0.03)
            member(T, "M_Steel", (0, y0, 0.12), (0, y1, 2.55), 0.04, 0.04)
            boxmm(T, "M_Hazard", -0.05, 0.05, (y0 + y1) / 2 - 0.35, (y0 + y1) / 2 + 0.35, 1.18, 1.42, "sign", 0.0)
            if s > 0:
                cyl(T, "M_Steel", (0, 0.05, 1.3), (0, -0.25, 1.3), 0.035, 8, "bolt")
        return b
    part("GateLeaf_L", "PROPS3", leaf(-1), (0, -1.62, 0), parent="GateFrame")
    part("GateLeaf_R", "PROPS3", leaf(1), (0, 1.62, 0), parent="GateFrame")
    print("props3 done")


def export_level():
    names = ["Rock-col", "Concrete-col", "Steel-col", "Detail", "Background", "Framing", "Foliage", "Lamps",
             "Surface-col", "SurfaceDeco-col", "StairRamps-colonly", "Struct2-col", "Detail2", "Proxies-colonly",
             "Ramps2-colonly", "Lamps2", "Water", "Lift3-col", "Tunnel-col"]
    bpy.ops.object.select_all(action='DESELECT')
    for n in names:
        sc.objects[n].select_set(True)
    bpy.context.view_layer.objects.active = sc.objects[names[0]]
    bpy.ops.export_scene.gltf(filepath=os.path.join(PROJ, "assets", "level", "cavern.glb"), export_format='GLB',
                              use_selection=True, use_active_scene=True, export_apply=True, export_yup=True)
    print("exported level")


def export_prop(names, fname):
    bpy.ops.object.select_all(action='DESELECT')
    for n in names:
        sc.objects[n].select_set(True)
    bpy.context.view_layer.objects.active = sc.objects[names[0]]
    bpy.ops.export_scene.gltf(filepath=os.path.join(PROJ, "assets", "props", fname), export_format='GLB',
                              use_selection=True, use_active_scene=True, export_apply=True, export_yup=True)
    print("exported", fname)
