# v12: the patrol station at the head of the Peak bridge (surface.tscn "PatrolStation", scripts/patrol_station.gd),
# plus a little polish on the bridge's first stub (railings, threshold plate, lamp, signs, tip beacon).
# One prop in its own frame: origin on the stub's deck centre at the gate line, +Y out along the bridge (Godot -Z),
# +X = the right-hand side walking out. The stub deck rises 0.0308 m per m (v10_peak.py arch1: z0-0.4 -> z0+0.3 over
# 22.75 m), so everything standing on it follows dz(). The stub tip is at y = 10.75, its deck edges at x = +-1.6.
# Nodes (Godot):
#   Frame-col        gantry posts, crossbeam + sign, threshold plate, reader post, lamp post, sign post (trimesh)
#   Booth-col        guard booth cantilevered off the right side of the stub on brackets (not enterable)
#   Detail           railings along the stub, sandbags, conduit, antenna, text, tip beacon post
#   Guards-colonly   invisible walls (2.4 m) along both deck edges past the gate + wings closing the gate's corners
#   Gate             the lift gate, modelled closed, origin at its bottom centre (patrol_station.gd lifts it)
#   Reader           pass reader head on its post (origin = the reader face centre)
#   ReaderLamp       the reader's lamp lens (recoloured at runtime)
#   StatusLamp       the lamp lens on top of the crossbeam (red locked / green open)
#   BeaconLens       amber lens on the tip post
# Blender scene "Props12", collection STATION12. Layout numbers in ST12 (also written to art_src/station.json).
# Run: exec(open(r"D:\Emberlight\art_src\v12_station.py").read()); build_station()  then  export_station()
exec(open(r"D:\Emberlight\art_src\gen_lib.py").read())
import json
PROJ = r"D:\Emberlight"
TEX = os.path.join(PROJ, "art_src", "tex")

if "Props12" not in bpy.data.scenes:
    bpy.data.scenes.new("Props12")
P12 = bpy.data.scenes["Props12"]
TMP12 = "C12_TMP"
COLL12 = "STATION12"

ST12 = dict(
    s_gate=6.0,              # metres along the approach from peak.json "start" (the rim is at s = 4)
    slope=0.7 / 22.75,       # deck rise per metre
    tip=10.75,               # stub tip (local y)
    half=1.6,                # deck half width
    post_x=1.95,             # gantry post centres
    gate_h=2.5, gate_lift=2.55, gate_z=0.07,
    booth=(1.85, 4.35, 0.35, 2.85),       # x0, x1, y0, y1
    booth_h=2.55,
    reader=(1.3, -0.75, 1.12),            # face centre
    lamp=(-0.95, -0.55, 3.75),            # lamp head (light position)
    status=(0.0, 0.05, 5.78),
    beacon=(1.42, 10.15, 1.62),
    booth_glow=(3.1, 1.6, 1.9),
    flood=(2.2, 0.55, 2.85),              # booth roof floodlight, aims back up the approach
    guard_y=(0.0, 9.6), guard_h=2.4,
)

def dz(y):
    return ST12["slope"] * y

def _c12(name):
    c = bpy.data.collections.get(name)
    if c is None:
        c = bpy.data.collections.new(name)
    if c.name not in P12.collection.children:
        P12.collection.children.link(c)
    return c

def mats12():
    flat_mat("M_Paint12", (0.82, 0.78, 0.66), rough=0.7)                     # stencil paint
    flat_mat("M_BoothGlass", (0.05, 0.07, 0.1), rough=0.12, emit=(1.0, 0.72, 0.42), strength=0.6, metal=0.3)
    flat_mat("M_LensRed", (0.6, 0.08, 0.05), rough=0.3, emit=(1.0, 0.12, 0.06), strength=4.0)
    flat_mat("M_LensAmber", (0.7, 0.45, 0.1), rough=0.3, emit=(1.0, 0.62, 0.15), strength=4.0)
    flat_mat("M_Sandbag", (0.36, 0.33, 0.27), rough=0.95)
    # (flat_mat keeps an existing material: push the tuned values every build) - the glass stays dark under the
    # cream sky (it read as white panes), with a faint warm glow from inside
    for n, col, rough, metal, emit, k in (("M_BoothGlass", (0.035, 0.045, 0.06), 0.42, 0.0, (1.0, 0.66, 0.36), 0.35),
                                          ("M_Sandbag", (0.2, 0.18, 0.14), 0.95, 0.0, None, 0.0)):
        b = next(x for x in M(n).node_tree.nodes if x.type == 'BSDF_PRINCIPLED')
        b.inputs["Base Color"].default_value = (*col, 1); M(n).diffuse_color = (*col, 1)
        b.inputs["Roughness"].default_value = rough; b.inputs["Metallic"].default_value = metal
        if emit:
            b.inputs["Emission Color"].default_value = (*emit, 1); b.inputs["Emission Strength"].default_value = k

def piece(name, build, pivot=(0, 0, 0), uv=True):
    """build() makes meshes in TMP12; they're merged into one object `name` (in STATION12) with its origin at `pivot`."""
    old = bpy.data.objects.get(name)
    if old: bpy.data.objects.remove(old, do_unlink=True)
    tmp = _c12(TMP12)
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
            f.material_index = remap[f.material_index] if remap else 0
    for o in objs: bpy.data.objects.remove(o, do_unlink=True)
    me = bpy.data.meshes.new(name); bm.to_mesh(me); bm.free()
    for m in mats:
        if m is not None: me.materials.append(m)
    ob = bpy.data.objects.new(name, me)
    _c12(COLL12).objects.link(ob)
    if uv and me.materials: box_uv(ob)
    me.transform(Matrix.Translation(-Vector(pivot)))
    ob.location = pivot
    return ob

def text_mesh(cat, s, at, size, yaw=0.0, mat="M_Paint12", align='CENTER', depth=0.006):
    """Stencil lettering: a Blender text object turned into a mesh, standing in the XZ plane facing -Y (rotated by yaw)."""
    cu = bpy.data.curves.new("txt12", 'FONT'); cu.body = s; cu.size = size; cu.extrude = depth
    cu.align_x = align; cu.align_y = 'CENTER'; cu.resolution_u = 2
    tob = bpy.data.objects.new("txt12", cu); coll(cat).objects.link(tob)
    tob.rotation_euler = (math.radians(90), 0, yaw); tob.location = at
    dg = bpy.context.evaluated_depsgraph_get()
    me = bpy.data.meshes.new_from_object(tob.evaluated_get(dg))
    ob = bpy.data.objects.new("txt", me); coll(cat).objects.link(ob)
    ob.location = tob.location; ob.rotation_euler = tob.rotation_euler
    me.materials.clear(); me.materials.append(M(mat))
    bpy.data.objects.remove(tob, do_unlink=True); bpy.data.curves.remove(cu)
    return ob

def hazard_bar(cat, x0, x1, y0, y1, z0, z1, n=6):
    """Alternating hazard / steel blocks along x (cheap chevrons)."""
    w = (x1 - x0) / n
    for i in range(n):
        boxmm(cat, "M_Hazard" if i % 2 == 0 else "M_Steel", x0 + i * w, x0 + (i + 1) * w, y0, y1, z0, z1, "hz", 0.0)

# ---------------------------------------------------------------- parts
def frame():
    T = TMP12; px = ST12["post_x"]
    for sx in (-1, 1):
        x = sx * px
        # box-section post (two flanges + web: the gate runs in the channel facing the deck)
        boxmm(T, "M_Steel", x - 0.15, x + 0.15, -0.16, -0.12, -1.3, 5.6, "flange", 0.01)
        boxmm(T, "M_Steel", x - 0.15, x + 0.15, 0.12, 0.16, -1.3, 5.6, "flange", 0.01)
        boxmm(T, "M_Steel", x + sx * 0.08, x + sx * 0.15, -0.12, 0.12, -1.3, 5.6, "web", 0.0)
        boxmm(T, "M_Concrete", x - 0.32, x + 0.32, -0.36, 0.36, -1.5, 0.12, "footing", 0.04)
        for z in (0.25, 0.75, 1.25):                    # painted bands on the approach face
            boxmm(T, "M_Hazard", x - 0.155, x + 0.155, -0.172, -0.16, z, z + 0.25, "band", 0.0)
        # counterweight + its chain over a sheave at the top, on the outer face
        boxmm(T, "M_Rust", x + sx * 0.16, x + sx * 0.36, -0.1, 0.1, 2.6, 3.4, "counterweight", 0.02)
        member(T, "M_Cable", (x + sx * 0.26, 0.0, 3.4), (x + sx * 0.26, 0.0, 5.45), 0.025, 0.025, "chain")
        cyl(T, "M_Steel", (x + sx * 0.05, -0.1, 5.45), (x + sx * 0.05, 0.1, 5.45), 0.17, 12, "sheave")
    # crossbeam + sign board on the approach side
    boxmm(T, "M_Steel", -px - 0.2, px + 0.2, -0.2, 0.2, 5.25, 5.6, "crossbeam", 0.02)
    boxmm(T, "M_RustSheet", -1.75, 1.75, -0.27, -0.21, 4.2, 5.05, "signboard", 0.01)
    hazard_bar(T, -1.75, 1.75, -0.29, -0.265, 4.2, 4.3, 10)
    member(T, "M_Steel", (-1.4, -0.21, 5.05), (-1.4, -0.2, 5.25), 0.06, 0.06, "hanger")
    member(T, "M_Steel", (1.4, -0.21, 5.05), (1.4, -0.2, 5.25), 0.06, 0.06, "hanger")
    # status lamp housing on top (the lens is its own node)
    sx_, sy_, sz_ = ST12["status"]
    boxmm(T, "M_Steel", -0.16, 0.16, -0.12, 0.22, 5.6, 5.68, "lamp_base", 0.01)
    cyl(T, "M_Steel", (0, sy_, 5.66), (0, sy_, 5.72), 0.13, 12, "lamp_ring")
    member(T, "M_Steel", (0, sy_, 5.9), (0, sy_, 5.96), 0.3, 0.3, "lamp_cap")
    for a in range(4):
        q = (math.cos(a * math.pi / 2) * 0.11, sy_ + math.sin(a * math.pi / 2) * 0.11)
        member(T, "M_Steel", (q[0], q[1], 5.7), (q[0], q[1], 5.92), 0.02, 0.02, "cage")
    # threshold plate under the gate (steel, hazard edge): covers the rock's bumps where the gate closes
    boxmm(T, "M_Grate", -1.6, 1.6, -1.25, 0.35, -0.08 + dz(-1.25), ST12["gate_z"] + dz(0.0), "threshold", 0.015)
    boxmm(T, "M_Hazard", -1.6, 1.6, -1.29, -1.2, -0.08 + dz(-1.25), ST12["gate_z"] - 0.005 + dz(-1.25), "th_edge", 0.01)
    # reader post
    rx, ry, rz = ST12["reader"]
    boxmm(T, "M_Steel", rx - 0.07, rx + 0.07, ry - 0.07, ry + 0.07, dz(ry) - 0.05, rz - 0.18, "reader_post", 0.01)
    boxmm(T, "M_Concrete", rx - 0.18, rx + 0.18, ry - 0.18, ry + 0.18, dz(ry) - 0.1, dz(ry) + 0.12, "reader_base", 0.03)
    # lamp post (left of the gate): pole, arm out over the deck, head
    lx, ly, lz = ST12["lamp"]
    cyl(T, "M_Steel", (-1.72, ly, -0.7), (-1.72, ly, lz + 0.35), 0.075, 10, "lamp_pole")
    boxmm(T, "M_Concrete", -2.0, -1.44, ly - 0.28, ly + 0.28, -0.75, dz(ly) + 0.1, "lamp_base", 0.04)
    member(T, "M_Steel", (-1.72, ly, lz + 0.3), (lx - 0.1, ly, lz + 0.22), 0.06, 0.06, "lamp_arm")
    member(T, "M_Steel", (-1.72, ly, lz - 0.3), (-1.3, ly, lz + 0.26), 0.035, 0.035, "lamp_brace")
    boxmm(T, "M_Steel", lx - 0.24, lx + 0.24, ly - 0.16, ly + 0.16, lz + 0.08, lz + 0.26, "lamp_head", 0.03)
    boxmm(T, "M_Lamp", lx - 0.19, lx + 0.19, ly - 0.12, ly + 0.12, lz + 0.05, lz + 0.08, "lamp_lens", 0.0)
    # warning sign before the gate (left side), on two legs
    y = -3.2
    for x in (-1.5, -0.7):
        member(T, "M_Steel", (x, y, dz(y) - 0.3), (x, y, dz(y) + 1.75), 0.06, 0.06, "sign_leg")
    boxmm(T, "M_RustSheet", -1.62, -0.58, y - 0.03, y + 0.01, dz(y) + 1.0, dz(y) + 1.78, "sign", 0.01)
    boxmm(T, "M_Hazard", -1.62, -0.58, y - 0.045, y - 0.03, dz(y) + 1.0, dz(y) + 1.08, "sign_band", 0.0)

def booth():
    T = TMP12
    x0, x1, y0, y1 = ST12["booth"]; H = ST12["booth_h"]; t = 0.06
    zf = dz((y0 + y1) / 2)
    boxmm(T, "M_Steel", x0, x1, y0, y1, zf - 0.26, zf, "floor", 0.02)
    # walls: rust sheet with a window band on the deck side (-X) and the approach side (-Y)
    wz0, wz1 = zf + 1.0, zf + 1.85
    def wall_x(x, ya, yb, win):
        if not win:
            boxmm(T, "M_RustSheet", x - t / 2, x + t / 2, ya, yb, zf, zf + H, "wall", 0.01); return
        boxmm(T, "M_RustSheet", x - t / 2, x + t / 2, ya, yb, zf, wz0, "wall", 0.01)
        boxmm(T, "M_RustSheet", x - t / 2, x + t / 2, ya, yb, wz1, zf + H, "wall", 0.01)
        boxmm(T, "M_RustSheet", x - t / 2, x + t / 2, ya, ya + 0.25, wz0, wz1, "wall", 0.0)
        boxmm(T, "M_RustSheet", x - t / 2, x + t / 2, yb - 0.25, yb, wz0, wz1, "wall", 0.0)
        boxmm(T, "M_BoothGlass", x - 0.012, x + 0.012, ya + 0.25, yb - 0.25, wz0, wz1, "glass", 0.0)
        boxmm(T, "M_Steel", x - 0.05, x + 0.05, ya + 0.2, yb - 0.2, wz0 - 0.06, wz0, "sill", 0.0)
        member(T, "M_Steel", (x - 0.04, (ya + yb) / 2, wz0), (x - 0.04, (ya + yb) / 2, wz1), 0.04, 0.04, "mullion")
    def wall_y(y, xa, xb, win):
        if not win:
            boxmm(T, "M_RustSheet", xa, xb, y - t / 2, y + t / 2, zf, zf + H, "wall", 0.01); return
        boxmm(T, "M_RustSheet", xa, xb, y - t / 2, y + t / 2, zf, wz0, "wall", 0.01)
        boxmm(T, "M_RustSheet", xa, xb, y - t / 2, y + t / 2, wz1, zf + H, "wall", 0.01)
        boxmm(T, "M_RustSheet", xa, xa + 0.3, y - t / 2, y + t / 2, wz0, wz1, "wall", 0.0)
        boxmm(T, "M_RustSheet", xb - 0.3, xb, y - t / 2, y + t / 2, wz0, wz1, "wall", 0.0)
        boxmm(T, "M_BoothGlass", xa + 0.3, xb - 0.3, y - 0.012, y + 0.012, wz0, wz1, "glass", 0.0)
        boxmm(T, "M_Steel", xa + 0.25, xb - 0.25, y - 0.05, y + 0.05, wz0 - 0.06, wz0, "sill", 0.0)
    wall_x(x0 + t / 2, y0, y1, True)
    wall_x(x1 - t / 2, y0, y1, False)
    wall_y(y0 + t / 2, x0, x1, True)
    wall_y(y1 - t / 2, x0, x1, False)
    # corner posts, roof with an overhang, roof vent
    for (x, y) in ((x0, y0), (x1, y0), (x0, y1), (x1, y1)):
        boxmm(T, "M_Steel", x - 0.05, x + 0.05, y - 0.05, y + 0.05, zf - 0.26, zf + H + 0.02, "corner", 0.01)
    zr = zf + H
    boxmm(T, "M_Steel", x0 - 0.22, x1 + 0.18, y0 - 0.3, y1 + 0.18, zr, zr + 0.1, "roof", 0.02)
    boxmm(T, "M_Corrugated", x0 - 0.2, x1 + 0.16, y0 - 0.28, y1 + 0.16, zr + 0.1, zr + 0.14, "roof_skin", 0.0)
    boxmm(T, "M_Steel", x1 - 0.85, x1 - 0.3, y1 - 0.8, y1 - 0.3, zr + 0.14, zr + 0.5, "roof_vent", 0.02)
    for k in range(4):
        z = zr + 0.2 + k * 0.07
        boxmm(T, "M_Rust", x1 - 0.87, x1 - 0.28, y1 - 0.82, y1 - 0.28, z, z + 0.025, "vent_fin", 0.0)
    # brackets: two cantilever beams under the floor into the stub's side, each with a raking strut
    for y in (y0 + 0.35, y1 - 0.35):
        ibeam(T, (1.45, y, zf - 0.38), (x1 + 0.05, y, zf - 0.38), h=0.24, w=0.16, mat="M_Rust", name="bracket")
        member(T, "M_Rust", (x1 - 0.1, y, zf - 0.45), (2.05, y, zf - 2.6), 0.14, 0.14, "strut")
        boxmm(T, "M_Steel", 1.85, 2.25, y - 0.2, y + 0.2, zf - 2.85, zf - 2.35, "anchor_plate", 0.02)
    member(T, "M_Rust", (2.05, y0 + 0.35, zf - 2.6), (2.05, y1 - 0.35, zf - 2.6), 0.12, 0.12, "strut_tie")

def details():
    T = TMP12; h = ST12["half"]; tip = ST12["tip"]
    x0, x1, y0, y1 = ST12["booth"]
    # railings along both deck edges (a bit tired towards the tip)
    def rail_run(x, ya, yb, broken, seed):
        railing(T, (x, ya, dz(ya) - 0.04), (x, yb, dz(yb) - 0.04), h=1.1, mat="M_Steel", spacing=1.5, broken=broken, seed=seed)
        member(T, "M_Steel", (x, ya, dz(ya) + 0.06), (x, yb, dz(yb) + 0.06), 0.02, 0.14, "kick")
    rail_run(-1.5, 0.35, 6.4, 0.0, 3)
    rail_run(-1.5, 6.4, 10.0, 0.35, 7)
    rail_run(1.5, y1 + 0.15, 6.4, 0.0, 5)
    rail_run(1.5, 6.4, 10.0, 0.3, 11)
    # conduit: booth -> along the deck edge -> the gate post (feeds the reader + lamps)
    cyl(T, "M_PalePipe", (x0 + 0.02, y0 + 0.4, dz(y0) + 0.25), (1.7, y0 + 0.4, dz(y0) + 0.25), 0.045, 8, "conduit")
    cyl(T, "M_PalePipe", (1.7, y0 + 0.4, dz(y0) + 0.25), (1.7, 0.2, dz(0.2) + 0.25), 0.045, 8, "conduit")
    cyl(T, "M_PalePipe", (ST12["post_x"] - 0.15, 0.0, 0.25), (1.7, 0.2, dz(0.2) + 0.25), 0.045, 8, "conduit")
    rx, ry, rz = ST12["reader"]
    cyl(T, "M_PalePipe", (ST12["post_x"] - 0.15, -0.13, 0.3), (rx, ry + 0.06, dz(ry) + 0.12), 0.03, 8, "reader_cable")
    # booth roof: antenna mast + floodlight aimed back up the approach
    zr = dz((y0 + y1) / 2) + ST12["booth_h"] + 0.14
    cyl(T, "M_Steel", (x1 - 0.3, y0 + 0.3, zr), (x1 - 0.3, y0 + 0.3, zr + 2.4), 0.03, 6, "antenna")
    for k in range(3):
        z = zr + 0.9 + k * 0.5
        member(T, "M_Steel", (x1 - 0.55, y0 + 0.3, z), (x1 - 0.05, y0 + 0.3, z), 0.02, 0.02, "antenna_bar")
    fx, fy, fz = ST12["flood"]
    member(T, "M_Steel", (fx, fy + 0.3, zr), (fx, fy + 0.3, fz - 0.05), 0.05, 0.05, "flood_post")
    boxmm(T, "M_Steel", fx - 0.17, fx + 0.17, fy - 0.05, fy + 0.3, fz - 0.15, fz + 0.15, "flood_head", 0.02)
    boxmm(T, "M_Lamp", fx - 0.13, fx + 0.13, fy - 0.07, fy - 0.05, fz - 0.11, fz + 0.11, "flood_lens", 0.0)
    # lettering (kept out of the -col meshes): gantry sign, the warning sign before the gate
    text_mesh(T, "PATROL STATION 4", (0.0, -0.29, 4.82), 0.3)
    text_mesh(T, "PASS REQUIRED", (0.0, -0.29, 4.5), 0.22)
    text_mesh(T, "PATROL STATION 4", (0.0, -0.19, 4.82), 0.3, yaw=math.pi)      # the far face, seen coming back
    text_mesh(T, "MESA  -  WORKS", (0.0, -0.19, 4.5), 0.22, yaw=math.pi)
    y = -3.2
    text_mesh(T, "CHECKPOINT", (-1.1, y - 0.05, dz(y) + 1.58), 0.15)
    text_mesh(T, "HALT  -  SHOW PASS", (-1.1, y - 0.05, dz(y) + 1.33), 0.1)
    text_mesh(T, "RELAY AUTHORITY", (-1.1, y - 0.05, dz(y) + 1.17), 0.075)
    # booth number + a notice board beside the window
    text_mesh(T, "4", (x1 - 0.55, y0 - 0.005, dz(y0) + 2.15), 0.42, mat="M_Hazard")
    boxmm(T, "M_Concrete3", x0 + 0.15, x0 + 0.85, y0 - 0.02, y0 - 0.005, dz(y0) + 0.35, dz(y0) + 0.85, "notice", 0.0)
    # sandbags by the lamp post (on the deck edge, left of the approach)
    rnd = random.Random(12)
    for k, (x, y, z) in enumerate([(-1.3, -1.45, 0.0), (-1.3, -2.05, 0.0), (-1.3, -1.75, 0.2), (-0.95, -1.6, 0.0)]):
        bm = bmesh.new(); bmesh.ops.create_icosphere(bm, subdivisions=2, radius=1.0)
        bmesh.ops.scale(bm, vec=(0.3, 0.2, 0.11), verts=bm.verts)
        for v in bm.verts:
            v.co.z = max(v.co.z, -0.07)
        ob = mk_obj("sandbag", bm, "M_Sandbag", T)
        ob.location = (x, y, dz(y) + z + 0.06); ob.rotation_euler = (0, 0, math.radians(90 + rnd.uniform(-12, 12)))
    # tip: hazard kerb across the broken end, beacon post (lens = own node)
    hazard_bar(T, -1.45, 1.45, tip - 0.32, tip - 0.2, dz(tip) - 0.06, dz(tip) + 0.05, 8)
    bx, by, bz = ST12["beacon"]
    member(T, "M_Steel", (bx, by, dz(by) - 0.1), (bx, by, bz - 0.08), 0.08, 0.08, "beacon_post")
    cyl(T, "M_Steel", (bx, by, bz - 0.1), (bx, by, bz - 0.06), 0.09, 10, "beacon_base")
    member(T, "M_Steel", (bx, by, bz + 0.16), (bx, by, bz + 0.2), 0.18, 0.18, "beacon_cap")

def guards():
    T = TMP12; y0, y1 = ST12["guard_y"]; H = ST12["guard_h"]; h = ST12["half"]
    for sx in (-1, 1):
        x = sx * (h + 0.04)
        member(T, None, (x, y0, dz(y0) + H / 2 - 0.3), (x, y1, dz(y1) + H / 2 - 0.3), 0.2, H, "guard")
        # wing at the gate line, out over the stub's shoulder: no climbing round the gate post
        member(T, None, (sx * 1.8, 0.0, 0.6), (sx * 3.2, 0.0, 0.6), 0.25, 4.0, "wing")

def gate():
    T = TMP12; w = ST12["post_x"] - 0.13; H = ST12["gate_h"]; z0 = ST12["gate_z"]
    # frame: square tube, mid rail, bars in the top half, mesh in the bottom half, hazard bottom rail
    boxmm(T, "M_Steel", -w, w, -0.05, 0.05, z0 + H - 0.12, z0 + H, "top", 0.01)
    boxmm(T, "M_Steel", -w, w, -0.05, 0.05, z0 + 1.15, z0 + 1.25, "mid", 0.01)
    for sx in (-1, 1):
        boxmm(T, "M_Steel", sx * w - 0.06, sx * w + 0.06, -0.05, 0.05, z0, z0 + H, "stile", 0.01)
    n = 12
    for i in range(1, n):
        x = -w + 2 * w * i / n
        member(T, "M_Steel", (x, 0, z0 + 1.25), (x, 0, z0 + H - 0.12), 0.035, 0.035, "bar")
    boxmm(T, "M_Grate", -w + 0.06, w - 0.06, -0.02, 0.02, z0 + 0.22, z0 + 1.15, "mesh", 0.0)
    hazard_bar(T, -w, w, -0.06, 0.06, z0, z0 + 0.22, 8)
    member(T, "M_Steel", (-w + 0.1, 0.0, z0 + 1.28), (-0.05, 0.0, z0 + H - 0.15), 0.05, 0.05, "brace")
    member(T, "M_Steel", (w - 0.1, 0.0, z0 + 1.28), (0.05, 0.0, z0 + H - 0.15), 0.05, 0.05, "brace")
    for x in (-w - 0.02, w + 0.02):
        for z in (z0 + 0.4, z0 + H - 0.4):
            cyl(T, "M_Rubber", (x, -0.06, z), (x, 0.06, z), 0.05, 8, "roller")
    boxmm(T, "M_RustSheet", -0.62, 0.62, -0.07, -0.05, z0 + 0.5, z0 + 0.86, "plate", 0.005)
    text_mesh(T, "NO ENTRY", (0.0, -0.075, z0 + 0.68), 0.2, mat="M_Paint12")

def reader():
    T = TMP12; rx, ry, rz = ST12["reader"]
    face = "M_ShaftDark" if "M_ShaftDark" in bpy.data.materials else "M_Rubber"
    boxmm(T, "M_Steel", rx - 0.13, rx + 0.13, ry - 0.06, ry + 0.08, rz - 0.22, rz + 0.18, "reader_box", 0.02)
    boxmm(T, face, rx - 0.09, rx + 0.09, ry - 0.075, ry - 0.06, rz - 0.12, rz + 0.04, "slot_face", 0.0)
    boxmm(T, "M_Steel", rx - 0.07, rx + 0.07, ry - 0.09, ry - 0.075, rz - 0.02, rz + 0.0, "slot", 0.0)
    boxmm(T, "M_Steel", rx - 0.15, rx + 0.15, ry - 0.1, ry + 0.1, rz + 0.18, rz + 0.22, "hood", 0.01)

def lens(name, c, r, mat):
    def b():
        bm = bmesh.new(); bmesh.ops.create_uvsphere(bm, u_segments=12, v_segments=8, radius=r)
        ob = mk_obj("lens", bm, mat, TMP12); ob.location = c
    return piece(name, b, c, uv=False)

def build_station():
    win = bpy.context.window
    if win: win.scene = P12
    mats12()
    c = _c12(COLL12)
    for o in list(c.objects): bpy.data.objects.remove(o, do_unlink=True)
    piece("Frame-col", frame)
    piece("Booth-col", booth)
    piece("Detail", details)
    g = piece("Guards-colonly", guards, uv=False); g.data.materials.clear()
    piece("Gate", gate)
    rx, ry, rz = ST12["reader"]
    piece("Reader", reader, (rx, ry - 0.075, rz))
    lens("ReaderLamp", (rx, ry - 0.08, rz + 0.1), 0.025, "M_LensRed")
    lens("StatusLamp", ST12["status"], 0.1, "M_LensRed")
    bx, by, bz = ST12["beacon"]
    lens("BeaconLens", (bx, by, bz + 0.05), 0.11, "M_LensAmber")
    for o in list(_c12(TMP12).objects): bpy.data.objects.remove(o, do_unlink=True)
    with open(os.path.join(PROJ, "art_src", "station.json"), "w") as f:
        json.dump(ST12, f, indent=1)
    print("station:", [(o.name, len(o.data.vertices)) for o in c.objects])

def export_station():
    sc = bpy.context.scene
    assert sc.name == "Props12", "make Props12 the active scene first"
    names = {o.name for o in bpy.data.collections[COLL12].objects}
    for o in sc.objects:
        o.select_set(o.name in names)
    bpy.ops.export_scene.gltf(filepath=os.path.join(PROJ, "assets", "props", "patrol_station.glb"), export_format='GLB',
                              use_selection=True, use_active_scene=True, export_apply=True, export_yup=True)
    print("exported patrol_station.glb", sorted(names))