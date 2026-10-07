# v15: the cable car station on the Peak island (surface.tscn CableStation, scripts/cable_station.gd).
# A built-out deck off the plateau's south-east rim (bearing -50 deg from the plateau centre): a ramp up a rock
# channel, a concrete deck cantilevered ~10 m past the cliff on steel struts, an operator's booth, a shed roof over
# the bullwheel, and the car bay. The line runs out over the haze to one tall pylon and on into the void (the far
# terminal is off-stage, in the next area). The car works; the far side doesn't (yet) - cable_station.gd.
# Station-local frame: origin on the rim at plateau height (G2), +Y out along the line, Z up; W maps it to the world.
# Out: assets/level/cable_station.glb (world Blender coords; Bullwheel + empties CarDock, PanelSpot, Lamp1/2,
#      FarLamp, FromCableCar as their own nodes) and assets/props/cable_car.glb (car-local: origin = the grip).
# Run (no save needed; materials come from peak.blend):
#   D:\Blender\blender.exe --background art_src\peak.blend --python art_src\v15_cable_station.py
exec(open(r"D:\Emberlight\art_src\gen_lib.py").read())
import json

G2 = 38.0
ZD = 40.0                       # deck top
ZW = ZD + 4.6                   # bullwheel / haul rope height in the station
LINE_X = (3.0, -1.0)            # car line, return line (station-local x)
WHEEL = (1.0, 11.0)             # bullwheel centre (x, y); radius 2.0
DOCK_Y = 16.0                   # the car's grip on the car line
PYLON_Y, PYLON_Z = 110.0, 40.5  # pylon crossarm
FAR_Y, FAR_Z = 900.0, -20.0     # the ropes just run on into the void (no far terminal modelled)
PEAK_C = (-87.09, -147.57)      # plateau centre (peak.json P10 peak)
BEAR = -50.0
_u = Vector((math.cos(math.radians(BEAR)), math.sin(math.radians(BEAR)), 0))
ORIGIN = Vector((PEAK_C[0] + _u.x * 31.0, PEAK_C[1] + _u.y * 31.0, 0.0))   # local z values are absolute heights
YAW = math.atan2(-_u.x, _u.y)                  # local +Y -> _u
W = Matrix.Translation(ORIGIN) @ Matrix.Rotation(YAW, 4, 'Z')

def sc(name):
    c = bpy.data.collections.get(name)
    if c is None:
        c = bpy.data.collections.new(name)
    if c.name not in bpy.context.scene.collection.children:
        bpy.context.scene.collection.children.link(c)
    for o in list(c.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    return c

flat_mat("M_LampDead", (0.25, 0.04, 0.03), rough=0.4, emit=(0.6, 0.05, 0.03), strength=0.3)
flat_mat("M_LampGreen", (0.1, 0.4, 0.15), rough=0.4, emit=(0.3, 1.0, 0.45), strength=6.0)
flat_mat("M_Glass", (0.2, 0.22, 0.28), rough=0.15, metal=0.3)

GUARD_H = 1.8
def guard(R, a, b, z, h=GUARD_H, t=0.2):
    member(R, None, (a[0], a[1], z + h / 2 - 0.1), (b[0], b[1], z + h / 2 - 0.1), t, h, "guard")

def rail(D, R, a, b, z, h=1.1, broken=0.0, seed=0):
    railing(D, (a[0], a[1], z), (b[0], b[1], z), h=h, spacing=1.6, broken=broken, seed=seed)
    guard(R, a, b, z)

def merge(name, cats, uv=True, xf=None):
    """Join every mesh in `cats` into one object `name` (bmesh, no operators); world transform baked in, then xf."""
    old = bpy.data.objects.get(name)
    if old: bpy.data.objects.remove(old, do_unlink=True)
    bpy.context.view_layer.update()     # matrix_world is stale after setting location/rotation (esp. --background)
    bm = bmesh.new(); mats = []
    for cat in cats:
        for o in [o for o in bpy.data.collections[cat].objects if o.type == 'MESH']:
            n0 = len(bm.verts); f0 = len(bm.faces)
            bm.from_mesh(o.data); bm.verts.ensure_lookup_table(); bm.faces.ensure_lookup_table()
            m = (xf or Matrix.Identity(4)) @ o.matrix_world
            bmesh.ops.transform(bm, matrix=m, verts=bm.verts[n0:])
            remap = []
            for mm in o.data.materials:
                if mm not in mats: mats.append(mm)
                remap.append(mats.index(mm))
            for f in bm.faces[f0:]:
                f.material_index = remap[f.material_index] if remap and f.material_index < len(remap) else 0
    me = bpy.data.meshes.new(name); bm.normal_update(); bm.to_mesh(me); bm.free()
    for mm in mats:
        if mm: me.materials.append(mm)
    ob = bpy.data.objects.new(name, me)
    bpy.data.collections["S15_OUT"].objects.link(ob)
    if uv and me.materials: box_uv(ob)
    return ob

def empty(name, loc, yaw=0.0, coll_name="S15_OUT", xf=None):
    old = bpy.data.objects.get(name)
    if old: bpy.data.objects.remove(old, do_unlink=True)
    e = bpy.data.objects.new(name, None); e.empty_display_size = 0.4
    bpy.data.collections[coll_name].objects.link(e)
    e.matrix_world = (xf if xf is not None else W) @ Matrix.Translation(loc) @ Matrix.Rotation(yaw, 4, 'Z')
    return e

# ---------------------------------------------------------------------------------------------- the station
def build_station():
    C, D, R = "S15_C", "S15_D", "S15_R"
    for n in (C, D, R, "S15_WHEEL", "S15_FAR"):
        sc(n)
    # ramp up the rock channel (smooth slab: no treads to hop on), hazard nosing where it meets the deck
    bm = bmesh.new()
    x0, x1, ya, yb, za, zb = -3.2, -0.8, -3.5, 6.0, G2 + 0.55, ZD
    vs = [bm.verts.new(v) for v in ((x0, ya, za), (x1, ya, za), (x1, yb, zb), (x0, yb, zb),
                                    (x0, ya, za - 0.6), (x1, ya, za - 0.6), (x1, yb, zb - 0.6), (x0, yb, zb - 0.6))]
    for f in ((0, 1, 2, 3), (7, 6, 5, 4), (0, 4, 5, 1), (1, 5, 6, 2), (2, 6, 7, 3), (3, 7, 4, 0)):
        bm.faces.new([vs[i] for i in f])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    mk_obj("ramp", bm, "M_Concrete2", C)
    for s in (x0 - 0.12, x1):
        member(D, "M_Steel", (s + 0.06, ya, za + 0.05), (s + 0.06, yb, zb + 0.05), 0.12, 0.16, "ramp_kerb")
    boxmm(D, "M_Hazard", x0, x1, yb - 0.3, yb, ZD, ZD + 0.01, "nosing", 0.0)
    # the deck: slab, steel edge beams, grate strip over the car bay
    boxmm(C, "M_Concrete2", -6.5, 5.2, 6.0, 20.5, ZD - 0.5, ZD, "deck", 0.04)
    for y in (6.0, 20.5):
        ibeam(D, (-6.6, y, ZD - 0.75), (5.3, y, ZD - 0.75), 0.5, 0.3, 0.05)
    for x in (-6.5, 5.2):
        ibeam(D, (x, 6.0, ZD - 0.75), (x, 20.5, ZD - 0.75), 0.5, 0.3, 0.05)
    boxmm(D, "M_Grate", 1.7, 4.3, 12.5, 20.4, ZD, ZD + 0.02, "bay_grate", 0.0)
    boxmm(D, "M_Hazard", 1.55, 1.7, 9.5, 20.4, ZD, ZD + 0.015, "bay_edge", 0.0)
    # piers into the rim and raking struts out to the deck's outer edge
    for x in (-6.0, -2.0, 2.0, 4.8):
        cyl(C, "M_Concrete", (x, 7.5, ZD - 0.5), (x, 7.5, G2 - 6.0), 0.45, 10, "pier")
        ibeam(D, (x, 20.2, ZD - 0.9), (x, 8.2, G2 - 9.0), 0.4, 0.28, 0.045)
        ibeam(D, (x, 14.0, ZD - 0.9), (x, 8.0, G2 - 4.0), 0.32, 0.24, 0.04)
    for k in range(3):
        y = 10.0 + k * 3.4; z = ZD - 0.9 - (20.2 - y) * 0 - (y - 8.2) * 0.0
        t = (20.2 - y) / 12.0
        zz = (ZD - 0.9) + (G2 - 9.0 - (ZD - 0.9)) * t
        member(D, "M_Steel", (-6.0, y, zz), (4.8, y, zz), 0.14, 0.14, "strut_tie")
    # operator's booth (back corner): walls with a window to the bay, a door gap facing the ramp
    bx0, bx1, by0, by1, bh = -6.4, -3.9, 6.6, 10.4, 2.7
    boxmm(C, "M_RustSheet", bx0, bx0 + 0.12, by0, by1, ZD, ZD + bh, "booth_w", 0.02)
    boxmm(C, "M_RustSheet", bx0, bx1, by1 - 0.12, by1, ZD, ZD + bh, "booth_n", 0.02)
    boxmm(C, "M_RustSheet", bx0, bx1, by0, by0 + 0.12, ZD, ZD + bh, "booth_s", 0.02)
    boxmm(C, "M_RustSheet", bx1 - 0.12, bx1, by0, by0 + 1.2, ZD, ZD + bh, "booth_e1", 0.02)
    boxmm(C, "M_RustSheet", bx1 - 0.12, bx1, by0 + 1.2, by1, ZD, ZD + 1.0, "booth_e2", 0.02)
    boxmm(C, "M_RustSheet", bx1 - 0.12, bx1, by0 + 1.2, by1, ZD + 2.2, ZD + bh, "booth_e3", 0.02)
    boxmm(D, "M_Glass", bx1 - 0.08, bx1 - 0.04, by0 + 1.3, by1 - 0.1, ZD + 1.0, ZD + 2.2, "booth_glass", 0.0)
    for k in range(4):
        member(D, "M_Rust", (bx1 - 0.06, by0 + 1.2 + k * 0.9, ZD + 1.0), (bx1 - 0.06, by0 + 1.2 + k * 0.9, ZD + 2.2), 0.06, 0.06, "mullion")
    boxmm(C, "M_Corrugated", bx0 - 0.2, bx1 + 0.2, by0 - 0.2, by1 + 0.2, ZD + bh, ZD + bh + 0.15, "booth_roof", 0.02)
    boxmm(C, "M_Steel", bx0 + 0.15, bx0 + 0.8, by0 + 0.5, by1 - 0.5, ZD, ZD + 1.0, "booth_desk", 0.02)
    # roof shed over the bullwheel and the bay: columns, rafters, corrugated sheet sloping out
    cols = [(-6.3, 9.3), (-6.3, 14.9), (-6.3, 20.3), (5.0, 9.3), (5.0, 14.9), (5.0, 20.3)]
    for x, y in cols:
        ibeam(C, (x, y, ZD), (x, y, ZD + 6.1 - (y - 9.3) * 0.05), 0.32, 0.28, 0.04)
    for y in (9.3, 14.9, 20.3):
        z = ZD + 6.1 - (y - 9.3) * 0.05
        ibeam(D, (-6.6, y, z), (5.3, y, z), 0.36, 0.24, 0.04)
    roof = boxmm(D, "M_Corrugated", -7.0, 5.7, 8.8, 21.0, 0, 0.12, "roof", 0.0)
    roof.location.z = ZD + 6.35 - 0.3; roof.rotation_euler.x = math.atan2(-0.6, 11.7)
    for y in (8.8, 21.0):
        z = ZD + 6.38 - (y - 8.8) * 0.0513
        boxmm(D, "M_Hazard", -7.0, 5.7, y - 0.06, y + 0.06, z - 0.35, z - 0.05, "roof_fascia", 0.0)
    # rail the car's grip runs on through the station, and a rope deflection sheave on the return side
    lx = LINE_X[0]
    member(D, "M_Steel", (lx, WHEEL[1], ZW + 0.35), (lx, 21.0, ZW + 0.35), 0.18, 0.22, "car_rail")
    for y in (12.0, 15.5, 19.0):
        member(D, "M_Steel", (lx, y, ZW + 0.45), (lx, y, ZD + 6.0 - (y - 9.3) * 0.05), 0.12, 0.12, "rail_hanger")
    # walkway lamps (shades; cable_station.gd lights them) and the panel pedestal by the bay
    for name, y in (("Lamp1", 12.5), ("Lamp2", 18.0)):
        p = Vector((-2.4, y, ZD + 5.2))
        cyl(D, "M_Cable", p + Vector((0, 0, 0.7)), p + Vector((0, 0, 0.2)), 0.02, 6, "cord")
        cyl(D, "M_Lamp", p + Vector((0, 0, 0.2)), p, 0.28, 12, "shade", r2=0.09)
        empty(name, p + Vector((0, 0, -0.2)))
    boxmm(C, "M_Steel", 0.55, 1.25, 12.8, 13.9, ZD, ZD + 1.1, "pedestal", 0.03)
    boxmm(D, "M_Rust", 0.5, 1.3, 12.75, 13.95, ZD + 1.1, ZD + 1.2, "pedestal_top", 0.02)
    cyl(D, "M_LampGreen", (0.48, 13.05, ZD + 0.92), (0.44, 13.05, ZD + 0.92), 0.06, 10, "lamp_near")
    cyl(D, "M_LampDead", (0.48, 13.65, ZD + 0.92), (0.44, 13.65, ZD + 0.92), 0.06, 10, "lamp_far")
    empty("FarLamp", Vector((0.4, 13.65, ZD + 0.92)))
    empty("PanelSpot", Vector((0.9, 13.35, ZD + 0.6)), math.pi * 0.5)
    # railings + guards round the open edges (the bay's outer end too: the car doesn't leave yet)
    rail(D, R, (-6.4, 6.1), (-6.4, 20.4), ZD)
    rail(D, R, (5.1, 6.1), (5.1, 20.4), ZD, seed=2)
    rail(D, R, (-6.4, 20.4), (5.1, 20.4), ZD, broken=0.15, seed=3)
    rail(D, R, (-6.4, 6.1), (-3.4, 6.1), ZD, seed=4)
    rail(D, R, (-0.6, 6.1), (5.1, 6.1), ZD, seed=5)

    # ---- bullwheel (its own node, origin at the hub; cable_station.gd turns it about Z) and its hanger
    Wc = "S15_WHEEL"; r = 2.0
    cyl(Wc, "M_Steel", (0, 0, -0.18), (0, 0, 0.18), 0.35, 12, "hub")
    for k in range(32):
        a0 = 2 * math.pi * k / 32; a1 = 2 * math.pi * (k + 1) / 32
        p0 = Vector((math.cos(a0) * r, math.sin(a0) * r, 0)); p1 = Vector((math.cos(a1) * r, math.sin(a1) * r, 0))
        member(Wc, "M_Rust", p0, p1, 0.16, 0.22, "rim")
    for k in range(8):
        a = 2 * math.pi * k / 8
        member(Wc, "M_Steel", (0, 0, 0), (math.cos(a) * (r - 0.05), math.sin(a) * (r - 0.05), 0), 0.1, 0.08, "spoke")
    member(Wc, "M_Hazard", (r * 0.9, 0, 0.13), (r * 0.6, 0, 0.13), 0.12, 0.02, "tick")    # shows it turning
    hx, hy = WHEEL
    cyl(D, "M_Steel", (hx, hy, ZW + 0.2), (hx, hy, ZD + 5.95), 0.14, 10, "wheel_shaft")
    ibeam(D, (hx, 9.3, ZD + 5.95), (hx, 14.9, ZD + 5.67), 0.3, 0.22, 0.04)
    # the return side: rope runs straight out under the roof
    # ---- the line: two ropes out to the pylon and on to the far terminal
    for lx in LINE_X:
        a = Vector((lx, hy, ZW)); b = Vector((lx, PYLON_Y, PYLON_Z)); c = Vector((lx, FAR_Y, FAR_Z))
        for p, q, sag, n in ((a, b, 1.6, 24), (b, c, 30.0, 64)):
            pts = cable_pts(p, q, sag, n)
            for i in range(n):
                cyl(D, "M_Cable", pts[i], pts[i + 1], 0.045, 6, "rope")
    # ---- the pylon, rising out of the haze
    P = "S15_FAR"; px = 1.0
    for sx in (-1, 1):
        for sy in (-1, 1):
            bot = Vector((px + sx * 6.0, PYLON_Y + sy * 6.0, -75.0)); top = Vector((px + sx * 1.3, PYLON_Y + sy * 1.3, PYLON_Z - 1.0))
            member(P, "M_Rust", bot, top, 0.45, 0.45, "pyl_leg")
    ztop = PYLON_Z - 1.0
    def corner(c, z):
        w = 6.0 + (1.3 - 6.0) * (z + 75.0) / (ztop + 75.0)
        return Vector((px + c[0] * w, PYLON_Y + c[1] * w, z))
    cs = ((-1, -1), (1, -1), (1, 1), (-1, 1))
    zs = [-75.0 + k * 9.0 for k in range(13)] + [ztop]
    for k in range(len(zs) - 1):
        for i in range(4):
            a, b = cs[i], cs[(i + 1) % 4]
            member(P, "M_Steel", corner(a, zs[k]), corner(b, zs[k + 1]), 0.18, 0.18, "pyl_brace")
            member(P, "M_Steel", corner(b, zs[k]), corner(a, zs[k + 1]), 0.18, 0.18, "pyl_brace")
            member(P, "M_Steel", corner(a, zs[k + 1]), corner(b, zs[k + 1]), 0.16, 0.16, "pyl_ring")
    member(P, "M_Rust", (px - 4.2, PYLON_Y, PYLON_Z - 0.6), (px + 4.2, PYLON_Y, PYLON_Z - 0.6), 0.5, 0.6, "crossarm")
    for lx in LINE_X:
        cyl(P, "M_Steel", (lx - 0.12, PYLON_Y - 1.0, PYLON_Z - 0.2), (lx - 0.12, PYLON_Y + 1.0, PYLON_Z - 0.2), 0.08, 6, "sheave_bar")
        for dy in (-0.6, 0.0, 0.6):
            cyl(P, "M_Steel", (lx - 0.2, PYLON_Y + dy, PYLON_Z - 0.2), (lx + 0.2, PYLON_Y + dy, PYLON_Z - 0.2), 0.2, 10, "sheave")
    cyl(P, "M_LampDead", (px, PYLON_Y, PYLON_Z + 0.3), (px, PYLON_Y, PYLON_Z + 0.6), 0.18, 8, "beacon_dead")
    # ---- markers for cable_station.gd
    empty("CarDock", Vector((LINE_X[0], DOCK_Y, ZW)))
    empty("FromCableCar", Vector((LINE_X[0] + 0.2, DOCK_Y, ZD + 0.1)), math.pi * 0.5)

# ---------------------------------------------------------------------------------------------- the car
def build_car():
    """Car-local: origin = the grip on the rope, +Y along the line, door on -X. Floor top 4.56 m below the grip
    (flush with the deck: walk straight in)."""
    K = "S15_CAR"; sc(K)
    fz = ZD + 0.04 - ZW                 # floor top
    rz = fz + 2.3                       # roof underside
    boxmm(K, "M_Steel", -0.2, 0.2, -0.55, 0.55, -0.15, 0.6, "grip", 0.03)
    for y in (-0.32, 0.32):
        cyl(K, "M_Rust", (-0.26, y, 0.62), (0.26, y, 0.62), 0.17, 12, "grip_wheel")
    member(K, "M_Rust", (0, 0, -0.15), (0, 0.15, -1.0), 0.16, 0.16, "hanger1")
    member(K, "M_Rust", (0, 0.15, -1.0), (0, 0, rz + 0.12), 0.16, 0.16, "hanger2")
    boxmm(K, "M_Steel", -0.6, 0.6, -0.25, 0.25, rz + 0.12, rz + 0.3, "hanger_foot", 0.02)
    boxmm(K, "M_RustSheet", -1.18, 1.18, -1.38, 1.38, rz, rz + 0.12, "roof", 0.03)
    boxmm(K, "M_Hazard", -1.2, 1.2, -1.4, 1.4, rz + 0.12, rz + 0.14, "roof_band", 0.0)
    boxmm(K, "M_Steel", -1.1, 1.1, -1.3, 1.3, fz - 0.1, fz, "floor", 0.02)
    boxmm(K, "M_Grate", -1.0, 1.0, -1.2, 1.2, fz, fz + 0.01, "floor_grate", 0.0)
    pz = fz + 1.0                       # top of the lower panels
    boxmm(K, "M_RustSheet", 1.02, 1.1, -1.3, 1.3, fz, pz, "wall_px", 0.01)
    for s in (-1, 1):
        boxmm(K, "M_RustSheet", -1.1, 1.1, s * 1.22 - 0.04, s * 1.22 + 0.04, fz, pz, "wall_y", 0.01)
        boxmm(K, "M_RustSheet", -1.1, -1.02, min(s * 0.55, s * 1.3), max(s * 0.55, s * 1.3), fz, pz, "wall_nx", 0.01)
        boxmm(K, "M_Hazard", -1.12, 1.12, s * 1.3 - 0.02, s * 1.3 + 0.02, fz + 0.05, fz + 0.2, "band", 0.0)
    for x, y in ((-1.06, -1.26), (1.06, -1.26), (1.06, 1.26), (-1.06, 1.26), (-1.06, -0.55), (-1.06, 0.55)):
        member(K, "M_Rust", (x, y, fz), (x, y, rz), 0.08, 0.08, "post")
    for x0, x1, y0, y1 in ((1.06, 1.06, -1.26, 1.26), (-1.06, 1.06, -1.26, -1.26), (-1.06, 1.06, 1.26, 1.26)):
        member(K, "M_Rust", (x0, y0, pz), (x1, y1, pz), 0.07, 0.07, "sill")
        for t in (0.33, 0.66):
            a = Vector((x0 + (x1 - x0) * t, y0 + (y1 - y0) * t, pz))
            member(K, "M_Rust", a, a + Vector((0, 0, rz - pz)), 0.04, 0.04, "mullion")
    member(K, "M_Rust", (-1.06, -0.55, rz - 0.2), (-1.06, 0.55, rz - 0.2), 0.08, 0.08, "door_head")
    boxmm(K, "M_Steel", 0.6, 1.0, -1.1, 1.1, fz, fz + 0.45, "bench", 0.03)
    boxmm(K, "M_Concrete3", 1.1, 1.13, -0.35, 0.35, pz - 0.5, pz - 0.1, "plate", 0.0)
    member(K, "M_Steel", (-0.8, -1.1, rz - 0.15), (-0.8, 1.1, rz - 0.15), 0.04, 0.04, "grab_bar")

def build_all():
    sc("S15_OUT")
    build_station()
    build_car()
    out = "S15_OUT"
    merge("CableStation-col", ["S15_C"], xf=W)
    merge("CableStationDetail", ["S15_D"], xf=W)
    g = merge("CableStationGuards-colonly", ["S15_R"], uv=False, xf=W); g.data.materials.clear()
    merge("CableLine", ["S15_FAR"], xf=W)
    wh = merge("Bullwheel", ["S15_WHEEL"])
    wh.matrix_world = W @ Matrix.Translation((WHEEL[0], WHEEL[1], ZW))
    car = merge("CableCar", ["S15_CAR"])
    for n in ("S15_C", "S15_D", "S15_R", "S15_FAR", "S15_WHEEL", "S15_CAR"):
        for o in list(bpy.data.collections[n].objects):
            bpy.data.objects.remove(o, do_unlink=True)
    print("station built:", sorted(o.name for o in bpy.data.collections[out].objects))
    print("origin", tuple(round(v, 2) for v in ORIGIN), "yaw", round(math.degrees(YAW), 2))

def export_all():
    bpy.context.view_layer.update()     # the exporter reads the evaluated depsgraph: flush the transforms set above
    objs = bpy.data.collections["S15_OUT"].objects
    for o in bpy.context.scene.objects:
        o.select_set(o.name in objs and o.name != "CableCar")
    bpy.ops.export_scene.gltf(filepath=os.path.join(PROJ, "assets", "level", "cable_station.glb"), export_format='GLB',
                              use_selection=True, use_active_scene=True, export_apply=True, export_yup=True)
    for o in bpy.context.scene.objects:
        o.select_set(o.name == "CableCar")
    car = bpy.data.objects["CableCar"]
    keep = car.matrix_world.copy(); car.matrix_world = Matrix.Identity(4)
    bpy.context.view_layer.update()
    bpy.ops.export_scene.gltf(filepath=os.path.join(PROJ, "assets", "props", "cable_car.glb"), export_format='GLB',
                              use_selection=True, use_active_scene=True, export_apply=True, export_yup=True)
    car.matrix_world = keep
    print("exported cable_station.glb + cable_car.glb")

build_all()
export_all()
