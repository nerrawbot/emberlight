# v19: the signal climb's puzzle props on the Peak's radio mast (surface.tscn MastSignal, scripts/mast_signal.gd).
# The gated route pieces themselves are in v10_peak.py (GATE_PARTS -> peak.glb); this file is the stations' kit:
#   Band 1 (POWER, the tutorial): a dead junction cabinet on the strip between the lattice and the railing, north of
#     where the gantry comes in. Its north door hangs open with the wiring diagram inside (colour stripe -> stencilled
#     shape); the south door has fallen off. Front panel: three sockets with a shape stencilled over each (circle,
#     square, triangle from south to north), a lamp over each, and the main breaker lever (modelled OFF, hanging down).
#     Three loose coupler plugs (red, amber, teal) lie round the band. Red -> triangle, amber -> circle, teal -> square.
# Mast-local frame as in v10_peak.py (origin on the mast axis, +X towards the hall, Z = absolute height); XF puts it in
# the world. Read from peak.json, so run v10 first if the mast moves.
# Out: assets/level/mast_signal.glb (world Blender coords). Nodes: MastSig1-col (static), B1Lamp_0..2, B1Lever (origin
#      on its pivot, arm hanging down), B1Plug_red/amber/teal (origin mid-body, prongs along local +X), empties
#      B1Socket_0..2 (local +X out of the panel), B1FeedLamp; MastSig2-col, B2Dial, B2Key, B2Lamp, B2Beacon;
#      MastSig3-col, B3Yaw > B3Tilt, B3Eye, B3Ember; MastSig4*-col, B4Wheel_*, B4Needle_*_1..3, B4Lever;
#      MastSig5-col, B5Screen, B5Seat; MastSig6-col, MastSig6Detail, MastSig6Guards-colonly, B6Cage, B6Lad1..5_bot/_top, B6Nest,
#      B6Roof, B6Perch.
# Run (no save needed; materials come from peak.blend):
#   D:\Blender\blender.exe --background art_src\peak.blend --python art_src\v19_mast_signal.py
exec(open(r"D:\Emberlight\art_src\gen_lib.py").read())
import json

L = json.load(open(os.path.join(PROJ, "art_src", "peak.json")))
P10 = L["P10"]
MX, MY = P10["mast"]
XF = Matrix.Translation((MX, MY, 0)) @ Matrix.Rotation(math.radians(P10["mast_yaw"]), 4, 'Z')
B1 = P10["bands"][0]
OUT = "S19_OUT"

flat_mat("M_SigRed", (0.6, 0.06, 0.04), rough=0.5, emit=(0.9, 0.12, 0.06), strength=0.7)
flat_mat("M_SigAmber", (0.7, 0.42, 0.05), rough=0.5, emit=(1.0, 0.6, 0.1), strength=0.7)
flat_mat("M_SigTeal", (0.05, 0.5, 0.48), rough=0.5, emit=(0.15, 0.9, 0.85), strength=0.7)
flat_mat("M_SigPaint", (0.62, 0.6, 0.52), rough=0.95)          # the pale stencil / diagram card
flat_mat("M_SigInk", (0.05, 0.05, 0.07), rough=0.9)            # dark paint, socket holes
flat_mat("M_SigLampOff", (0.12, 0.1, 0.06), rough=0.25, metal=0.2)

def sc(name):
    c = bpy.data.collections.get(name)
    if c is None:
        c = bpy.data.collections.new(name)
    if c.name not in bpy.context.scene.collection.children:
        bpy.context.scene.collection.children.link(c)
    for o in list(c.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    return c

def merge(name, cats, uv=True, xf=None):
    """Join every mesh in `cats` into one object `name`, world transform baked in, then xf (as v15)."""
    old = bpy.data.objects.get(name)
    if old: bpy.data.objects.remove(old, do_unlink=True)
    bpy.context.view_layer.update()
    bm = bmesh.new(); mats = []
    for cat in cats:
        for o in [o for o in bpy.data.collections[cat].objects if o.type == 'MESH']:
            n0 = len(bm.verts); f0 = len(bm.faces)
            bm.from_mesh(o.data); bm.verts.ensure_lookup_table(); bm.faces.ensure_lookup_table()
            bmesh.ops.transform(bm, matrix=(xf or Matrix.Identity(4)) @ o.matrix_world, verts=bm.verts[n0:])
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
    bpy.data.collections[OUT].objects.link(ob)
    if uv and me.materials: box_uv(ob)
    for cat in cats:
        for o in list(bpy.data.collections[cat].objects):
            bpy.data.objects.remove(o, do_unlink=True)
    return ob

def part(name, cat, loc, yaw=0.0):
    """A moving part: built round the origin in `cat`, placed at mast-local loc / yaw (deg)."""
    ob = merge(name, [cat])
    ob.matrix_world = XF @ Matrix.Translation(loc) @ Matrix.Rotation(math.radians(yaw), 4, 'Z')
    return ob

def empty(name, loc, yaw=0.0):
    old = bpy.data.objects.get(name)
    if old: bpy.data.objects.remove(old, do_unlink=True)
    e = bpy.data.objects.new(name, None); e.empty_display_size = 0.2
    bpy.data.collections[OUT].objects.link(e)
    e.matrix_world = XF @ Matrix.Translation(loc) @ Matrix.Rotation(math.radians(yaw), 4, 'Z')
    return e

def shape(cat, mat, kind, c, u, v, n, size, depth=0.008, name="stencil"):
    """A flat painted shape (circle / square / triangle / arrowhead) on a face: centre c, u right, v up, n out."""
    c, u, v, n = Vector(c), Vector(u), Vector(v), Vector(n)
    r = size / 2
    if kind == "circle":
        pts = [(r * math.cos(a * math.tau / 18), r * math.sin(a * math.tau / 18)) for a in range(18)]
    elif kind == "square":
        pts = [(-r, -r), (r, -r), (r, r), (-r, r)]
    elif kind == "triangle":
        pts = [(-r, -r * 0.85), (r, -r * 0.85), (0, r)]
    else:   # arrowhead pointing +u
        pts = [(-r * 0.6, -r), (r, 0), (-r * 0.6, r)]
    bm = bmesh.new()
    fr = [bm.verts.new(c + u * x + v * y + n * depth) for (x, y) in pts]
    bk = [bm.verts.new(c + u * x + v * y) for (x, y) in pts]
    bm.faces.new(fr); bm.faces.new(list(reversed(bk)))
    k = len(pts)
    for i in range(k):
        bm.faces.new((bk[i], bk[(i + 1) % k], fr[(i + 1) % k], fr[i]))
    bm.normal_update()
    return mk_obj(name, bm, mat, cat)

# ---------------------------------------------------------------------------------------------- band 1: POWER
CAB = dict(x0=11.5, x1=12.1, y0=5.3, y1=7.5, h=2.0)
SOCK_Y = (6.0, 6.6, 7.2)
SOCK_Z = 1.1
SHAPES = ("circle", "square", "triangle")             # stencilled over sockets 0, 1, 2 (south -> north)
PLUGS = (("red", "M_SigRed", "triangle", (13.25, 12.2, 0.075), 35.0),          # by the corner, where the stair is
         ("amber", "M_SigAmber", "circle", (12.95, 4.55, 0.075 + 0.04), 100.0),  # on the fallen door
         ("teal", "M_SigTeal", "square", (12.75, -3.55, 0.58 + 0.075), -20.0))  # on a crate by the gantry
LEVER = (CAB["x1"] + 0.06, 5.62, 1.25)

def band1():
    z = B1
    C, T = "S19_C", "S19_T"
    sc(C); sc(T)
    x0, x1, y0, y1, h = CAB["x0"], CAB["x1"], CAB["y0"], CAB["y1"], CAB["h"]
    # body: plinth, box (open front), roof hood, recessed panel
    boxmm(C, "M_Steel", x0 - 0.05, x1 + 0.05, y0 - 0.05, y1 + 0.05, z, z + 0.1, "cab_plinth", 0.01)
    boxmm(C, "M_RustSheet", x0, x0 + 0.06, y0, y1, z + 0.1, z + h, "cab_back", 0.01)
    for (ya, yb) in ((y0, y0 + 0.05), (y1 - 0.05, y1)):
        boxmm(C, "M_RustSheet", x0, x1, ya, yb, z + 0.1, z + h, "cab_side", 0.01)
    boxmm(C, "M_Steel", x0 - 0.08, x1 + 0.14, y0 - 0.1, y1 + 0.1, z + h, z + h + 0.08, "cab_hood", 0.01)
    boxmm(C, "M_Steel", x1 - 0.12, x1 - 0.06, y0 + 0.05, y1 - 0.05, z + 0.1, z + h, "cab_panel", 0.0)
    boxmm(C, "M_Hazard", x1 - 0.06, x1, y0 + 0.05, y1 - 0.05, z + h - 0.12, z + h - 0.04, "cab_band", 0.0)
    out = Vector((1, 0, 0)); right = Vector((0, 1, 0)); up = Vector((0, 0, 1))
    for i, y in enumerate(SOCK_Y):
        # socket boss + hole, the shape stencilled above on a pale card, a caged lamp above that
        cyl(C, "M_Steel", (x1 - 0.06, y, z + SOCK_Z), (x1 + 0.06, y, z + SOCK_Z), 0.12, 14, "sock_boss")
        cyl(C, "M_SigInk", (x1 + 0.06, y, z + SOCK_Z), (x1 + 0.065, y, z + SOCK_Z), 0.08, 14, "sock_hole")
        boxmm(C, "M_SigPaint", x1 - 0.06, x1 - 0.05, y - 0.18, y + 0.18, z + SOCK_Z + 0.2, z + SOCK_Z + 0.5, "sock_card", 0.0)
        shape(C, "M_SigInk", SHAPES[i], (x1 - 0.05, y, z + SOCK_Z + 0.35), right, up, out, 0.2)
        cyl(C, "M_Steel", (x1 - 0.06, y, z + 1.72), (x1 + 0.03, y, z + 1.72), 0.09, 12, "lamp_bezel")
        for s in (-1, 1):
            member(C, "M_Steel", (x1 + 0.03, y + s * 0.07, z + 1.72), (x1 + 0.13, y + s * 0.07, z + 1.72), 0.015, 0.015, "lamp_cage")
        member(C, "M_Steel", (x1 + 0.13, y - 0.08, z + 1.72), (x1 + 0.13, y + 0.08, z + 1.72), 0.015, 0.015, "lamp_cage")
        cyl(T, "M_SigLampOff", (0, 0, 0), (0.08, 0, 0), 0.065, 12, "lamp")
        part("B1Lamp_%d" % i, T, (x1 + 0.03, y, z + 1.72))
        empty("B1Socket_%d" % i, (x1 + 0.065, y, z + SOCK_Z))
    # the breaker: a base plate and a tag; the lever is its own part (OFF = hanging down and out)
    lx, ly, lz = LEVER
    boxmm(C, "M_Steel", x1 - 0.06, x1 + 0.03, ly - 0.14, ly + 0.14, z + lz - 0.55, z + lz + 0.12, "lever_plate", 0.01)
    boxmm(C, "M_Hazard", x1 + 0.03, x1 + 0.04, ly - 0.14, ly + 0.14, z + lz + 0.12, z + lz + 0.2, "lever_tag", 0.0)
    cyl(T, "M_Steel", (0, -0.08, 0), (0, 0.08, 0), 0.05, 10, "pivot")
    member(T, "M_Rust", (0, 0, 0), (0.1, 0, -0.42), 0.05, 0.05, "lever_arm")
    cyl(T, "M_SigInk", (0.1, -0.1, -0.42), (0.1, 0.1, -0.42), 0.04, 10, "lever_grip")
    part("B1Lever", T, (lx, ly, z + lz))
    # the north door hangs open, the wiring diagram inside it: hinge at (x1, y1), opened 105 deg
    D = "S19_DOOR"; sc(D)
    dw, dz0, dz1 = 1.1, 0.12, 1.92
    boxmm(D, "M_RustSheet", 0.0, dw, 0.0, 0.04, dz0, dz1, "door", 0.01)
    boxmm(D, "M_SigPaint", 0.07, dw - 0.07, -0.006, 0.0, 0.55, 1.8, "diagram_card", 0.0)
    boxmm(D, "M_Hazard", 0.07, dw - 0.07, -0.01, -0.006, 1.68, 1.78, "diagram_head", 0.0)
    dout = Vector((0, -1, 0)); dright = Vector((1, 0, 0))
    for row, (pn, pm, ps, _, _) in enumerate(PLUGS):
        zr = 1.45 - row * 0.36
        boxmm(D, pm, 0.13, 0.43, -0.014, -0.006, zr - 0.06, zr + 0.06, "diag_bar", 0.0)
        boxmm(D, "M_SigInk", 0.5, 0.66, -0.012, -0.006, zr - 0.015, zr + 0.015, "diag_shaft", 0.0)
        shape(D, "M_SigInk", "arrow", (0.69, -0.006, zr), dright, up, dout, 0.1)
        shape(D, "M_SigInk", ps, (0.88, -0.006, zr), dright, up, dout, 0.17)
    bpy.context.view_layer.update()
    for o in bpy.data.collections[D].objects:        # hinge
        o.matrix_world = Matrix.Translation((x1, y1, z)) @ Matrix.Rotation(math.radians(15.0), 4, 'Z') @ o.matrix_world
    for (a, b) in ((0.3, 0.42), (1.5, 1.62)):
        cyl(C, "M_Steel", (x1, y1, z + a), (x1, y1, z + b), 0.03, 8, "hinge")
    # the south door lies on the floor where it fell
    boxmm(C, "M_RustSheet", 12.35, 13.45, 3.9, 4.95, z, z + 0.04, "door_fallen", 0.01)
    # the feed: a conduit from the hood up to a junction box on the lattice leg
    cyl(C, "M_Steel", (11.8, 7.2, z + h + 0.08), (11.8, 7.2, z + h + 0.5), 0.05, 8, "conduit")
    member(C, "M_Steel", (11.8, 7.2, z + h + 0.5), (11.2, 10.3, z + h + 1.6), 0.08, 0.08, "conduit")
    boxmm(C, "M_RustSheet", 11.0, 11.4, 10.0, 10.5, z + h + 1.3, z + h + 1.9, "jbox", 0.02)
    # the crate the teal coupler sits on
    boxmm(C, "M_Rust", 12.45, 13.05, -3.85, -3.25, z, z + 0.58, "crate", 0.03)
    empty("B1FeedLamp", (12.2, 6.4, z + h + 0.35))
    # the plugs: a body, a colour band, a grip, two prongs (local +X), lying on their sides
    for (pn, pm, ps, (px, py, pz), yaw) in PLUGS:
        cyl(T, "M_Steel", (-0.16, 0, 0), (0.12, 0, 0), 0.07, 12, "plug_body")
        cyl(T, pm, (-0.06, 0, 0), (0.04, 0, 0), 0.078, 12, "plug_band")
        cyl(T, "M_SigInk", (-0.26, 0, 0), (-0.16, 0, 0), 0.055, 10, "plug_grip")
        for s in (-1, 1):
            boxmm(T, "M_Steel", 0.12, 0.21, s * 0.03 - 0.012, s * 0.03 + 0.012, -0.012, 0.012, "prong", 0.0)
        part("B1Plug_" + pn, T, (px, py, z + pz), yaw)
    merge("MastSig1-col", [C, D], xf=XF)

# ---------------------------------------------------------------------------------------------- band 2: FREQUENCY
# A tuning console on the band's west strip (the only place on band 2 that sees past the cabin to the end of its
# long boom). The call-sign lamp hangs off the boom's end and blinks the relay's call sign; the console's 8-step
# dial (B2Dial, pointer along local +Z, turns about local Y) picks the rhythm of the station lamp (B2Lamp, on a post).
# Match them, press the key (B2Key, pushes along local -Y). A placard on the post: up arrow, lamp = lamp.
B2 = P10["bands"][1]
CON = dict(x0=-10.9, x1=-9.7, y0=-1.8, y1=-1.2, h=1.0)
DIAL = (-10.45, 0.8)                 # x, height of the dial centre on the console front (y = y1)
KEY = (-9.98, 0.78)
POST = (-10.75, -1.6, 3.0)           # post x, y, height (the lamp sits on top)
BOOM_END = (-17.5, 3.4, 114.1)       # the cabin boom's west cap (v10_peak.py cabin(): zr + 0.85)

def band2():
    z = B2
    C, T = "S19_C2", "S19_T"
    sc(C); sc(T)
    x0, x1, y0, y1, h = CON["x0"], CON["x1"], CON["y0"], CON["y1"], CON["h"]
    boxmm(C, "M_Steel", x0 - 0.05, x1 + 0.05, y0 - 0.05, y1 + 0.05, z, z + 0.08, "con_plinth", 0.01)
    boxmm(C, "M_RustSheet", x0, x1, y0, y1, z + 0.08, z + h, "con_body", 0.02)
    boxmm(C, "M_Steel", x0 - 0.04, x1 + 0.04, y0 - 0.04, y1 + 0.06, z + h, z + h + 0.06, "con_top", 0.01)
    boxmm(C, "M_Hazard", x0, x1, y1, y1 + 0.01, z + h - 0.1, z + h - 0.03, "con_band", 0.0)
    out = Vector((0, 1, 0)); right = Vector((-1, 0, 0)); up = Vector((0, 0, 1))     # seen from the front (facing -y)
    dx, dz = DIAL
    cyl(C, "M_SigPaint", (dx, y1, z + dz), (dx, y1 + 0.01, z + dz), 0.24, 24, "dial_plate")
    for k in range(8):
        a = math.radians(45.0 * k)
        d = up * math.cos(a) + right * math.sin(a)
        c = Vector((dx, y1 + 0.01, z + dz)) + d * 0.19
        L = 0.07 if k == 0 else 0.045
        member(C, "M_SigInk", c - d * L / 2, c + d * L / 2, 0.012, 0.02 if k == 0 else 0.012, "dial_tick")
    cyl(T, "M_Steel", (0, 0, 0), (0, 0.07, 0), 0.075, 14, "knob")
    member(T, "M_SigInk", (0, 0.075, 0.0), (0, 0.075, 0.16), 0.03, 0.01, "pointer")
    part("B2Dial", T, (dx, y1 + 0.01, z + dz))
    kx, kz = KEY
    cyl(C, "M_Steel", (kx, y1, z + kz), (kx, y1 + 0.03, z + kz), 0.1, 14, "key_collar")
    cyl(T, "M_Steel", (0, 0, 0), (0, 0.1, 0), 0.03, 8, "key_stem")
    cyl(T, "M_SigRed", (0, 0.1, 0), (0, 0.14, 0), 0.07, 14, "key_cap")
    part("B2Key", T, (kx, y1 + 0.03, z + kz))
    # the post, the station lamp and the placard
    px, py, ph = POST
    cyl(C, "M_Steel", (px, py, z), (px, py, z + ph), 0.06, 10, "post")
    boxmm(C, "M_Steel", px - 0.2, px + 0.2, py - 0.2, py + 0.2, z, z + 0.05, "post_foot", 0.01)
    for s in (-1, 1):
        member(C, "M_Steel", (px + s * 0.13, py, z + ph), (px + s * 0.13, py, z + ph + 0.32), 0.015, 0.015, "lamp_cage")
        member(C, "M_Steel", (px, py + s * 0.13, z + ph), (px, py + s * 0.13, z + ph + 0.32), 0.015, 0.015, "lamp_cage")
    cyl(C, "M_Steel", (px, py, z + ph + 0.32), (px, py, z + ph + 0.36), 0.16, 12, "lamp_cap")
    cyl(T, "M_SigLampOff", (0, 0, -0.12), (0, 0, 0.12), 0.11, 12, "bulb")
    part("B2Lamp", T, (px, py, z + ph + 0.16))
    pc = Vector((px, py + 0.08, z + 1.95))
    boxmm(C, "M_SigPaint", px - 0.26, px + 0.26, py + 0.06, py + 0.08, z + 1.45, z + 2.45, "placard", 0.0)
    boxmm(C, "M_Hazard", px - 0.26, px + 0.26, py + 0.08, py + 0.085, z + 2.36, z + 2.44, "placard_head", 0.0)
    shape(C, "M_SigInk", "arrow", pc + up * 0.27, up, right, out, 0.16)            # up: look up
    shape(C, "M_SigInk", "circle", pc + up * 0.04 + right * -0.13, right, up, out, 0.12)
    for s in (-1, 1):                                                              # =
        boxmm(C, "M_SigInk", pc.x - 0.04, pc.x + 0.04, pc.y, pc.y + 0.008, pc.z + 0.04 + s * 0.025 - 0.008, pc.z + 0.04 + s * 0.025 + 0.008, "eq", 0.0)
    shape(C, "M_SigRed", "circle", pc + up * 0.04 + right * 0.13, right, up, out, 0.12)
    for k in range(5):            # rays round the red one: the beacon
        a = math.radians(72.0 * k + 18.0)
        d = up * math.cos(a) + right * math.sin(a)
        c = pc + up * 0.04 + right * 0.13 + d * 0.1
        member(C, "M_SigInk", c, c + d * 0.04, 0.008, 0.012, "ray")
    for k in range(3):            # a row of dots and dashes along the bottom
        boxmm(C, "M_SigInk", pc.x - 0.18 + k * 0.13, pc.x - 0.18 + k * 0.13 + (0.1 if k == 0 else 0.03), pc.y, pc.y + 0.008, pc.z - 0.33, pc.z - 0.3, "morse", 0.0)
    # the call-sign lamp off the boom's west cap: a bracket and a caged bulb hanging under its end
    bx, by, bz = BOOM_END
    member(C, "M_Steel", (bx, by, bz), (bx - 0.9, by, bz), 0.12, 0.12, "beacon_arm")
    member(C, "M_Steel", (bx - 0.9, by, bz), (bx - 0.9, by, bz - 0.35), 0.06, 0.06, "beacon_hanger")
    cyl(C, "M_Steel", (bx - 0.9, by, bz - 0.35), (bx - 0.9, by, bz - 0.42), 0.22, 12, "beacon_cap")
    cyl(T, "M_SigLampOff", (0, 0, -0.2), (0, 0, 0.2), 0.17, 12, "beacon_bulb")
    part("B2Beacon", T, (bx - 0.9, by, bz - 0.62))
    merge("MastSig2-col", [C], xf=XF)

# ---------------------------------------------------------------------------------------------- band 3: BEARING
# A steerable dish on the band's south strip (Ember lies that way, out along the cable line) and a sighting pedestal
# beside it. The pedestal's eyepiece shows what the dish sees (scripts/mast/band3_bearing.gd: a zoomed camera on the
# dish). Find Ember's lights, ~700 m out past the cable line's pylon, and lock. Parts: B3Yaw (turns about local Z,
# origin on the column top) with child B3Tilt (tilts about local X; the dish looks along local -Y at rest),
# empties B3Eye (the eyepiece) and B3Ember (where Ember's lights are, in the void).
B3 = P10["bands"][2]
DISH = (-1.6, -7.5)
YAW_Z, TILT_Z = 1.7, 2.55
PED = (-0.25, -7.15)
CABLE_BEAR, CABLE_OFF, EMBER_OUT, EMBER_Z = -50.0, 31.0, 700.0, 22.0       # v15_cable_station.py ORIGIN / BEAR
EMBER_SIDE = -60.0                   # off the line: the gap between two spires the dish can see through

def band3():
    z = B3
    C, T, U = "S19_C3", "S19_T", "S19_U"
    sc(C); sc(T); sc(U)
    dx, dy = DISH
    # column + turntable ring (static)
    cyl(C, "M_Steel", (dx, dy, z), (dx, dy, z + 0.12), 0.55, 16, "dish_foot")
    cyl(C, "M_RustSheet", (dx, dy, z + 0.12), (dx, dy, z + YAW_Z - 0.08), 0.22, 14, "dish_column")
    cyl(C, "M_Steel", (dx, dy, z + YAW_Z - 0.1), (dx, dy, z + YAW_Z), 0.38, 18, "turntable")
    # B3Yaw: the fork (local, round the origin at the column top)
    cyl(T, "M_Steel", (0, 0, 0), (0, 0, 0.12), 0.34, 18, "yaw_ring")
    boxmm(T, "M_Steel", -0.85, 0.85, -0.18, 0.18, 0.1, 0.22, "fork_base", 0.01)
    for s in (-1, 1):
        boxmm(T, "M_RustSheet", s * 0.78 - 0.07, s * 0.78 + 0.07, -0.15, 0.15, 0.1, TILT_Z - YAW_Z + 0.12, "fork_arm", 0.01)
    yaw = part("B3Yaw", T, (dx, dy, z + YAW_Z))
    # B3Tilt: the dish (opening along -Y), feed horn on struts, the trunnion, a counterweight behind
    bmd = bmesh.new()
    bmesh.ops.create_cone(bmd, cap_ends=False, segments=24, radius1=0.15, radius2=1.15, depth=0.5)
    bmesh.ops.rotate(bmd, verts=bmd.verts, cent=(0, 0, 0), matrix=Matrix.Rotation(math.radians(90), 3, 'X'))
    bmesh.ops.translate(bmd, verts=bmd.verts, vec=(0, -0.1, 0))
    mk_obj("dish", bmd, "M_PalePipe", U)
    cyl(U, "M_Steel", (0, -0.36, 0), (0, -0.4, 0), 1.17, 24, "dish_rim")
    cyl(U, "M_Steel", (-0.72, 0, 0), (0.72, 0, 0), 0.07, 8, "trunnion")
    for a in range(3):
        t = math.radians(120 * a + 90)
        member(U, "M_Steel", (1.0 * math.cos(t), -0.33, 1.0 * math.sin(t)), (0, -1.05, 0), 0.03, 0.03, "feed_strut")
    cyl(U, "M_SigInk", (0, -1.0, 0), (0, -1.15, 0), 0.08, 10, "feed_horn")
    boxmm(U, "M_Rust", -0.3, 0.3, 0.2, 0.55, -0.3, 0.3, "dish_weight", 0.03)
    cyl(U, "M_Steel", (0.0, 0.2, 0.0), (0.0, 0.42, 0.0), 0.12, 10, "dish_hub")
    tilt = part("B3Tilt", U, (dx, dy, z + TILT_Z))
    bpy.context.view_layer.update()
    tilt.parent = yaw
    tilt.matrix_parent_inverse = yaw.matrix_world.inverted()
    # the sighting pedestal: a hooded eyepiece on its east face, two cranks, the pictogram
    px, py = PED
    boxmm(C, "M_RustSheet", px - 0.25, px + 0.25, py - 0.35, py + 0.35, z, z + 1.25, "ped_body", 0.02)
    boxmm(C, "M_Steel", px - 0.3, px + 0.3, py - 0.4, py + 0.4, z + 1.25, z + 1.32, "ped_top", 0.01)
    cyl(C, "M_Steel", (px + 0.25, py, z + 1.52), (px + 0.45, py, z + 1.52), 0.07, 12, "eyepiece")
    cyl(C, "M_SigInk", (px + 0.45, py, z + 1.52), (px + 0.5, py, z + 1.52), 0.09, 12, "eyecup")
    member(C, "M_Steel", (px + 0.1, py, z + 1.32), (px + 0.25, py, z + 1.52), 0.08, 0.08, "eye_arm")
    member(C, "M_Cable", (px - 0.2, py - 0.3, z + 1.0), (dx + 0.2, dy, z + 0.4), 0.04, 0.04, "sight_cable")
    for s in (-1, 1):
        cyl(C, "M_Steel", (px + 0.25, py + s * 0.25, z + 0.95), (px + 0.33, py + s * 0.25, z + 0.95), 0.1, 10, "crank_wheel")
        member(C, "M_Steel", (px + 0.33, py + s * 0.25 + 0.08, z + 0.95), (px + 0.38, py + s * 0.25 + 0.08, z + 0.95), 0.025, 0.025, "crank_handle")
    out = Vector((1, 0, 0)); right = Vector((0, 1, 0)); up = Vector((0, 0, 1))      # seen from the east (facing -x)
    q = Vector((px + 0.251, py, z + 0.45))
    boxmm(C, "M_SigPaint", q.x - 0.001, q.x, py - 0.32, py + 0.32, z + 0.2, z + 0.7, "picto_card", 0.0)
    for k in (-1, 1):                         # two ropes sloping away, the car under them, an arrow on, Ember's lamp
        member(C, "M_SigInk", q + right * -0.28 + up * (0.12 + k * 0.025), q + right * 0.1 + up * (0.0 + k * 0.025), 0.006, 0.012, "picto_rope")
    boxmm(C, "M_SigInk", q.x, q.x + 0.006, py - 0.16, py - 0.08, z + 0.37, z + 0.45, "picto_car", 0.0)
    shape(C, "M_SigInk", "arrow", q + right * 0.16 + up * 0.0, right, up, out, 0.08)
    shape(C, "M_SigAmber", "circle", q + right * 0.26 + up * 0.0, right, up, out, 0.07)
    empty("B3Eye", (px + 0.5, py, z + 1.52))
    # Ember's lights: out along the cable line, past its pylon, in the haze (world coords, not mast-local)
    pk = Vector(L["P10"]["peak"])
    u = Vector((math.cos(math.radians(CABLE_BEAR)), math.sin(math.radians(CABLE_BEAR))))
    e = pk + u * (CABLE_OFF + EMBER_OUT) + Vector((-u.y, u.x)) * EMBER_SIDE
    em = bpy.data.objects.new("B3Ember", None); bpy.data.collections[OUT].objects.link(em)
    em.matrix_world = Matrix.Translation((e.x, e.y, EMBER_Z))
    merge("MastSig3-col", [C], xf=XF)

# ---------------------------------------------------------------------------------------------- band 4: GAIN
# Three attenuator valves on waveguide ducts round the band (N red, E amber, S teal) and a master board with the gain
# lever on the west strip. Every valve moves two of the three gain needles (scripts/mast/band4_gain.gd): get all
# three into the green, then throw the lever. Each station repeats the three gauges on a small board over its wheel.
# A station is built in its own frame (+Y = out towards the band edge, the side you work it from), then turned.
# Parts: B4Wheel_<red|amber|teal> (hub; spins about local Y), B4Needle_<station>_<1..3> (pointer along local +Z, turns
# about local Y), B4Lever (arm hanging down and out, turns about local X), empties none.
B4 = P10["bands"][3]
STATIONS = (("red", "M_SigRed", (1.0, 4.6), 0.0), ("amber", "M_SigAmber", (4.6, -0.8), -90.0),
            ("teal", "M_SigTeal", (-0.8, -4.6), 180.0))
MASTER = ((-4.6, -0.5), 90.0)

def gauge(C, T, name, c, r, frame):
    """A round gauge on a board facing +Y at c (station-local): face, ticks 0..8 (-80..+80 deg), the green at the top,
    and its needle as a part (frame = the station's world matrix)."""
    out = Vector((0, 1, 0)); right = Vector((-1, 0, 0)); up = Vector((0, 0, 1))
    c = Vector(c)
    cyl(C, "M_Steel", c - out * 0.01, c + out * 0.006, r * 1.12, 20, "gauge_bezel")
    cyl(C, "M_SigPaint", c + out * 0.006, c + out * 0.01, r, 20, "gauge_face")
    for k in range(9):
        a = math.radians((k - 4) * 20.0)
        d = up * math.cos(a) + right * math.sin(a)
        p = c + out * 0.011 + d * r * 0.82
        member(C, "M_SigTeal" if k == 4 else "M_SigInk", p - d * r * 0.1, p + d * r * 0.1, r * 0.06 if k == 4 else r * 0.03, 0.006, "gauge_tick")
    cyl(T, "M_SigInk", (0, 0, 0), (0, 0.012, 0), r * 0.12, 10, "needle_hub")
    member(T, "M_SigRed", (0, 0.012, -r * 0.15), (0, 0.012, r * 0.85), r * 0.05, 0.006, "needle")
    ob = merge(name, [T])
    ob.matrix_world = frame @ Matrix.Translation(c + out * 0.012)
    return ob

def station_frame(xy, yaw):
    return XF @ Matrix.Translation((xy[0], xy[1], B4)) @ Matrix.Rotation(math.radians(yaw), 4, 'Z')

def band4():
    T = "S19_T"; sc(T)
    for (sid, smat, xy, yaw) in STATIONS:
        C = "S19_C4" + sid; sc(C)
        F = station_frame(xy, yaw)
        # the duct: up from the floor, bent in towards the lattice at the top; the colour band names the valve
        boxmm(C, "M_RustSheet", -0.25, 0.25, -0.38, -0.05, 0.0, 2.35, "duct", 0.02)
        boxmm(C, "M_RustSheet", -0.25, 0.25, -1.3, -0.05, 2.1, 2.4, "duct_bend", 0.02)
        for zz in (0.5, 1.5, 2.25):
            boxmm(C, "M_Steel", -0.29, 0.29, -0.42, -0.01, zz, zz + 0.06, "duct_flange", 0.01)
        boxmm(C, smat, -0.26, 0.26, -0.39, -0.04, 0.72, 0.84, "duct_band", 0.0)
        cyl(C, "M_Steel", (0, -0.05, 1.15), (0, 0.06, 1.15), 0.07, 10, "valve_stem")
        # the wheel (its own part): rim, spokes, hub, a knob on the rim
        n = 14
        for k in range(n):
            a0, a1 = math.tau * k / n, math.tau * (k + 1) / n
            member(T, "M_Steel", (0.34 * math.cos(a0), 0, 0.34 * math.sin(a0)), (0.34 * math.cos(a1), 0, 0.34 * math.sin(a1)), 0.045, 0.045, "rim")
        for k in range(4):
            a = math.tau * k / 4 + 0.4
            member(T, "M_Steel", (0, 0, 0), (0.34 * math.cos(a), 0, 0.34 * math.sin(a)), 0.03, 0.03, "spoke")
        cyl(T, smat, (0, -0.03, 0), (0, 0.05, 0), 0.08, 12, "hub")
        cyl(T, "M_SigInk", (0.34, 0.0, 0), (0.34, 0.12, 0), 0.03, 8, "rim_knob")
        w = merge("B4Wheel_" + sid, [T]); w.matrix_world = F @ Matrix.Translation((0, 0.08, 1.15))
        # the repeater board over the wheel: three small gauges, dots under them (1, 2, 3)
        boxmm(C, "M_SigPaint", -0.48, 0.48, -0.05, -0.03, 1.58, 2.06, "board", 0.0)
        boxmm(C, "M_Hazard", -0.48, 0.48, -0.03, -0.025, 1.98, 2.05, "board_head", 0.0)
        for i in range(3):
            gx = 0.3 - 0.3 * i                       # gauge 1 on the viewer's left (+X is the viewer's left)
            gauge(C, T, "B4Needle_%s_%d" % (sid, i + 1), (gx, -0.03, 1.8), 0.11, F)
            for d in range(i + 1):
                boxmm(C, "M_SigInk", gx - 0.06 * i / 2 + 0.06 * d - 0.012, gx - 0.06 * i / 2 + 0.06 * d + 0.012, -0.03, -0.024, 1.63, 1.655, "dot", 0.0)
        merge("MastSig4%s-col" % sid, [C], xf=F)
    # the master board and the gain lever
    C = "S19_C4m"; sc(C)
    xy, yaw = MASTER
    F = station_frame(xy, yaw)
    for s in (-1, 1):
        member(C, "M_Steel", (s * 0.75, -0.2, 0.0), (s * 0.75, -0.2, 2.3), 0.1, 0.1, "board_post")
    boxmm(C, "M_RustSheet", -0.9, 0.9, -0.22, -0.18, 1.2, 2.3, "master_back", 0.01)
    boxmm(C, "M_SigPaint", -0.85, 0.85, -0.18, -0.16, 1.25, 2.25, "master_board", 0.0)
    boxmm(C, "M_Hazard", -0.85, 0.85, -0.16, -0.155, 2.14, 2.24, "master_head", 0.0)
    for i in range(3):
        gx = 0.52 - 0.52 * i
        gauge(C, T, "B4Needle_master_%d" % (i + 1), (gx, -0.16, 1.72), 0.2, F)
        for d in range(i + 1):
            boxmm(C, "M_SigInk", gx - 0.08 * i / 2 + 0.08 * d - 0.018, gx - 0.08 * i / 2 + 0.08 * d + 0.018, -0.16, -0.152, 1.36, 1.4, "dot", 0.0)
    # the lever on a plate right of the board (the viewer's right is -X)
    boxmm(C, "M_Steel", -1.25, -0.95, -0.22, -0.12, 0.6, 1.4, "lever_plate", 0.01)
    boxmm(C, "M_Hazard", -1.25, -0.95, -0.12, -0.11, 1.32, 1.4, "lever_tag", 0.0)
    member(C, "M_Steel", (-1.1, -0.2, 0.0), (-1.1, -0.2, 0.6), 0.1, 0.1, "lever_post")
    cyl(T, "M_Steel", (-0.08, 0, 0), (0.08, 0, 0), 0.05, 10, "pivot")
    member(T, "M_Rust", (0, 0, 0), (0, 0.1, -0.42), 0.05, 0.05, "lever_arm")
    cyl(T, "M_SigInk", (-0.1, 0.1, -0.42), (0.1, 0.1, -0.42), 0.04, 10, "lever_grip")
    lv = merge("B4Lever", [T]); lv.matrix_world = F @ Matrix.Translation((-1.1, -0.06, 1.25))
    merge("MastSig4m-col", [C], xf=F)

# ---------------------------------------------------------------------------------------------- the cabin: the relay
# The relay console at the west end of the radio cabin (v10_peak.py cabin(): room x -8..5.6, y +-5.8, door east),
# under the west windows: a desk, the CRT cabinet (B5Screen: its screen, a quad facing +X, drawn by a shader at
# runtime), three knobs, a chair. B5Seat: where you work it from (scripts/mast/cabin_console.gd).
ZC = P10["cabin"]

def cabin_console():
    z = ZC
    C, T = "S19_C5", "S19_T"
    sc(C); sc(T)
    boxmm(C, "M_Steel", -7.78, -6.85, -1.45, 1.45, z, z + 0.08, "desk_foot", 0.01)
    boxmm(C, "M_RustSheet", -7.78, -6.95, -1.4, 1.4, z + 0.08, z + 0.88, "desk_body", 0.02)
    boxmm(C, "M_Steel", -7.8, -6.75, -1.5, 1.5, z + 0.88, z + 0.95, "desk_top", 0.01)
    boxmm(C, "M_RustSheet", -7.78, -7.3, -1.05, 1.05, z + 0.95, z + 2.15, "crt_cabinet", 0.03)
    boxmm(C, "M_Steel", -7.82, -7.26, -1.1, 1.1, z + 2.15, z + 2.22, "crt_cap", 0.01)
    boxmm(C, "M_SigInk", -7.31, -7.29, -0.72, 0.72, z + 1.12, z + 1.98, "crt_bezel", 0.0)
    boxmm(C, "M_Hazard", -7.3, -7.29, -1.0, 1.0, z + 2.02, z + 2.1, "crt_band", 0.0)
    # the screen: a thin quad just proud of the bezel (its own part; the runtime swaps in the trace shader)
    bm = bmesh.new()
    vs = [bm.verts.new(v) for v in ((0, -0.62, -0.38), (0, 0.62, -0.38), (0, 0.62, 0.38), (0, -0.62, 0.38))]
    bm.faces.new(vs); bm.normal_update()
    sq = mk_obj("screen", bm, "M_SigInk", T)
    scr = merge("B5Screen", [T]); scr.matrix_world = XF @ Matrix.Translation((-7.285, 0.0, z + 1.55))
    # three knobs on the desk's front edge (FREQ, PHASE, GAIN) and a brass plate
    for i, y in enumerate((-0.5, 0.0, 0.5)):
        cyl(C, "M_Steel", (-6.9, y, z + 0.95), (-6.9, y, z + 1.0), 0.09, 14, "knob_base")
        cyl(C, ("M_SigTeal", "M_SigAmber", "M_SigRed")[i], (-6.9, y, z + 1.0), (-6.9, y, z + 1.07), 0.06, 12, "knob")
    boxmm(C, "M_SigAmber", -7.29, -7.28, -0.5, 0.5, z + 0.98, z + 1.06, "plate", 0.0)
    # a chair, pushed back
    boxmm(C, "M_Steel", -6.35, -5.85, -0.3, 0.2, z + 0.45, z + 0.52, "chair_seat", 0.01)
    boxmm(C, "M_Steel", -5.9, -5.85, -0.3, 0.2, z + 0.52, z + 1.05, "chair_back", 0.0)
    for (a, b) in ((-6.3, -0.25), (-5.9, -0.25), (-6.3, 0.15), (-5.9, 0.15)):
        member(C, "M_Steel", (a, b, z), (a, b, z + 0.45), 0.04, 0.04, "chair_leg")
    empty("B5Seat", (-6.75, 0.0, z + 1.1))
    merge("MastSig5-col", [C], xf=XF)

# ---------------------------------------------------------------------------------------------- the summit
# The way up from the cabin balcony to the very top, opened by the final tuning (mast_final). All on the south side
# (the boom fills the north of the roof deck): L1 a caged ladder up the cabin's south wall (B6Cage: its door, hinged
# on its west post, origin on the hinge), L2 up the upper storey, L3 up the top block, L4 the antenna's own ladder
# (v10 drew its rungs; here an invisible back plate) through a hatch into the crow's nest round the spike cap, L5
# a service ladder bracketed to the spike up to the perch under the tip beacon. Every ladder's climber faces north (stands on its south
# side). Empties B6Lad<k>_bot / _top on the rung line (local +Y = the climb normal), B6Nest / B6Roof (checkpoints),
# B6Perch (the launch). Invisible guards / backs: MastSig6Guards-colonly.
AX, AY = -0.4, -0.1                       # the antenna / spike axis (v10 cabin())
# (L1..L3 stand off their walls past the roof overhangs - a head under an overhang jams the climb; L5 stands 1.4 m off
# the spike, room for a body between its top and the spike)
LADDERS = ((-6.0, -6.15, 104.0, 109.3), (0.8, -4.85, 109.3, 113.25), (-1.6, -3.12, 113.25, 116.1),
           (0.75, -1.4, 116.1, 146.1), (AX, AY - 1.4, 146.35, 159.5))
NEST_Z, PERCH_Z = 146.1, 159.5         # (the perch: the tip beacon at 162 stays over your head)

def rungs(cat, x, y, z0, z1, w=0.5, mat="M_Steel"):
    for s in (-1, 1):
        member(cat, mat, (x + s * w / 2, y, z0), (x + s * w / 2, y, z1), 0.05, 0.05, "stile")
    k = 0
    while z0 + 0.3 + k * 0.32 < z1:
        z = z0 + 0.3 + k * 0.32
        member(cat, mat, (x - w / 2, y, z), (x + w / 2, y, z), 0.035, 0.035, "rung")
        k += 1

def summit():
    C, D, R, T = "S19_C6", "S19_D6", "S19_R6", "S19_T"
    sc(C); sc(D); sc(R); sc(T)
    for k, (x, y, z0, z1) in enumerate(LADDERS):
        if k in (0, 1, 2):
            rungs(D, x, y, z0, z1 + 0.9)
        elif k == 4:           # a service ladder clear of the spike (so its top steps forward onto the perch), on brackets
            rungs(D, x, y, z0, z1 + 0.9, w=0.45)
            zb = z0 + 1.0
            while zb < z1:
                member(D, "M_Steel", (x, y, zb), (AX, AY - 0.05, zb), 0.05, 0.05, "ladder_bracket")
                zb += 2.6
        # an invisible back plate just behind the rungs
        if True:
            boxmm(R, None, x - 0.32, x + 0.32, y + 0.1, y + 0.14, z0 + 0.2, z1 - 0.15, "ladder_back", 0.0)
        empty("B6Lad%d_bot" % (k + 1), (x, y, z0), 180.0)
        empty("B6Lad%d_top" % (k + 1), (x, y, z1), 180.0)
    # L1's cage: two side panels, a top hoop, and the door (its own part, hinged on the west post)
    x, y = LADDERS[0][0], LADDERS[0][1]
    z = 104.0
    # (the cage itself is visual only: a solid hoop catches the climber's head; only the door blocks)
    for sx in (-0.45, 0.45):
        for zz in (0.1, 0.8, 1.5, 2.2):
            member(D, "M_Steel", (x + sx, -5.8, z + zz), (x + sx, -6.95, z + zz), 0.04, 0.04, "cage_rail")
        member(D, "M_Steel", (x + sx, -6.95, z), (x + sx, -6.95, z + 2.4), 0.06, 0.06, "cage_post")
    member(D, "M_Steel", (x - 0.45, -6.95, z + 2.4), (x + 0.45, -6.95, z + 2.4), 0.06, 0.06, "cage_hoop")
    for (yy, zz) in ((-5.8, 0.3), (-5.8, 4.9)):     # stand-off brackets from the wall to the stiles
        for sx in (-0.25, 0.25):
            member(D, "M_Steel", (x + sx, yy, z + zz), (x + sx, y, z + zz), 0.04, 0.04, "standoff")
    for xx in (-0.3, -0.1, 0.1, 0.3):
        member(T, "M_Steel", (xx + 0.45, 0, 0.05), (xx + 0.45, 0, 2.25), 0.03, 0.03, "door_bar")
    for zz in (0.1, 1.15, 2.2):
        member(T, "M_Steel", (0.0, 0, zz), (0.9, 0, zz), 0.05, 0.05, "door_rail")
    boxmm(T, "M_Hazard", 0.05, 0.85, -0.02, 0.02, 1.0, 1.3, "door_sign", 0.0)
    boxmm(T, "M_Rust", 0.78, 0.92, -0.08, 0.0, 1.05, 1.25, "padlock", 0.01)
    boxmm(T, "M_Steel", 0.0, 0.9, -0.01, 0.01, 0.05, 2.25, "door_block", 0.0)        # (the bars' collision)
    cage = merge("B6Cage-col", [T]); cage.matrix_world = XF @ Matrix.Translation((x - 0.45, -6.95, z))
    # the crow's nest round the spike cap: a grate deck with the ladder well, railings with guards, struts
    nz = NEST_Z
    x0n, x1n, y0n, y1n = AX - 2.0, AX + 2.0, AY - 2.3, AY + 2.3
    wx0, wx1, wy0, wy1 = 0.2, 1.3, -2.2, -1.12                        # the well L4 comes up through
    for (a0, a1, b0, b1) in ((x0n, x1n, wy1, y1n), (x0n, wx0, y0n, wy1), (wx1, x1n, y0n, wy1)):
        boxmm(C, "M_Grate", a0, a1, b0, b1, nz - 0.12, nz, "nest_deck", 0.0)
    for (a, b) in (((x0n, y0n), (x1n, y0n)), ((x1n, y0n), (x1n, y1n)), ((x1n, y1n), (x0n, y1n)), ((x0n, y1n), (x0n, y0n))):
        member(C, "M_RustSheet", (a[0], a[1], nz - 0.3), (b[0], b[1], nz - 0.3), 0.12, 0.3, "nest_fascia")
        for t in (0.5, 1.0):
            member(C, "M_Steel", (a[0], a[1], nz + t), (b[0], b[1], nz + t), 0.04, 0.04, "nest_rail")
        member(R, None, (a[0], a[1], nz + 0.8), (b[0], b[1], nz + 0.8), 0.2, 1.8, "guard")
    for (cx_, cy_) in ((x0n, y0n), (x1n, y0n), (x1n, y1n), (x0n, y1n)):
        member(C, "M_Steel", (cx_, cy_, nz), (cx_, cy_, nz + 1.0), 0.05, 0.05, "nest_post")
        member(C, "M_Steel", (cx_, cy_, nz - 0.3), (AX + (0.4 if cx_ > AX else -0.4), AY + (0.4 if cy_ > AY else -0.4), nz - 3.5), 0.08, 0.08, "nest_strut")
    # the perch under the beacon: a small plate round the spike, its south edge just past L5's rungs (you step forward
    # onto it at the top), open on every side (you leave from here)
    boxmm(C, "M_Grate", AX - 0.9, AX + 0.9, AY - 1.33, AY + 1.3, PERCH_Z - 0.1, PERCH_Z, "perch", 0.0)
    member(C, "M_Hazard", (AX - 0.9, AY + 1.3, PERCH_Z - 0.05), (AX + 0.9, AY + 1.3, PERCH_Z - 0.05), 0.06, 0.08, "perch_edge")
    for s in (-1, 1):
        for ey in (AY + 1.25, AY - 1.25):
            member(D, "M_Steel", (AX + s * 0.85, ey, PERCH_Z - 0.1), (AX, AY + (0.1 if ey > AY else -0.1), PERCH_Z - 1.8), 0.05, 0.05, "perch_strut")
    member(C, "M_Steel", (AX, AY + 0.1, PERCH_Z - 0.05), (AX, AY + 0.1, PERCH_Z - 0.8), 0.06, 0.06, "perch_clamp")
    empty("B6Perch", (AX, AY + 0.8, PERCH_Z), 0.0)
    empty("B6Nest", (AX - 1.2, AY - 1.0, NEST_Z), 180.0)
    empty("B6Roof", (-2.5, -3.6, 113.25), 180.0)
    merge("MastSig6-col", [C], xf=XF)
    merge("MastSig6Detail", [D], xf=XF)
    g = merge("MastSig6Guards-colonly", [R], uv=False, xf=XF); g.data.materials.clear()

def build_all():
    sc(OUT)
    band1()
    band2()
    band3()
    band4()
    cabin_console()
    summit()
    print("mast signal built:", sorted(o.name for o in bpy.data.collections[OUT].objects))

def export_all():
    bpy.context.view_layer.update()
    objs = bpy.data.collections[OUT].objects
    for o in bpy.context.scene.objects:
        o.select_set(o.name in objs)
    bpy.ops.export_scene.gltf(filepath=os.path.join(PROJ, "assets", "level", "mast_signal.glb"), export_format='GLB',
                              use_selection=True, use_active_scene=True, export_apply=True, export_yup=True)
    print("exported mast_signal.glb")

build_all()
export_all()
