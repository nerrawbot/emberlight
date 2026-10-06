
# v4: the starting room ("lower workings"). A tall, irregular rock shaft, built in its own Blender scene
# "StartRoom" and exported to assets/level/start.glb (+ assets/props/drawbridge.glb).
# Route (Blender coords, Z up):
#   spawn platform Z38 (left) -> catwalk -> rock shelf with boiler (right) -> top landing
#   -> flight1 west along the back wall -> landing L1 Z31 -> flight2 east -> pipe-machinery ledge Z24 (right)
#   -> [valve lowers the drawbridge] -> left landing Z24 -> ladder -> broken-arch ledge Z13
#   -> flight4 east -> bottom bridge Z5 over water -> tunnel east -> door to the cavern.
# Re-runnable: every collection is rebuilt from scratch.
exec(open(r"C:\Users\Pigeon\Documents\UnderworksCavern\art_src\gen_lib.py").read())
import json

if "StartRoom" not in bpy.data.scenes:
    bpy.data.scenes.new("StartRoom")
SR = bpy.data.scenes["StartRoom"]
if bpy.context.window:          # absent when run with blender --background
    bpy.context.window.scene = SR

# ---------------------------------------------------------------- layout (single source of truth)
L = dict(
    top=38.0, l1=31.0, mid=24.0, arch=13.0, bottom=5.0, water=0.3,
    spawn_plat=(-9.5, -2.0, -4.0, 3.0),          # x0,x1,y0,y1 at top
    shelf=(3.0, 11.5, -8.5, 2.2),               # rock shelf top-right
    top_land=(3.6, 8.0, 2.0, 6.6),              # steel landing at the head of flight1
    f1=((3.8, 5.5), (-4.6, 5.5)),               # top -> l1, along the back wall
    l1_rect=(-7.8, -4.4, 1.4, 6.8),
    f2=((-4.4, 2.5), (4.2, 2.5)),               # l1 -> mid
    mid_ledge=(4.0, 11.5, -8.0, 4.6),
    mach=(7.0, 10.8, -5.0, 1.0),
    valve=(6.55, -1.2),
    bridge_y=(-5.2, -2.8), hinge_x=4.0, bridge_len=7.0,
    left_land=(-9.4, -3.0, -6.4, -2.4),
    ladder=(-6.0, -2.22),                      # x, y (the player stands north of it, +Y)
    arch_ledge=(-12.5, -3.0, -9.5, -0.6),
    f4=((-3.0, -3.6), (6.5, -3.6)),             # arch -> bottom
    bridge=(-9.0, 13.0, -2.2, 0.2),             # bottom bridge x0,x1,y0,y1
    tunnel=(12.0, 19.5, -2.3, 0.3),
)

def ccoll(name):
    c = bpy.data.collections.get(name)
    if c is None:
        c = bpy.data.collections.new(name); SR.collection.children.link(c)
    elif c.name not in SR.collection.children:
        SR.collection.children.link(c)
    for o in list(c.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    return c

# ---------------------------------------------------------------- rock shell
def shell():
    C = "SR_RockC"; ccoll(C)
    bm = bmesh.new()
    N = 56
    zs = [-3.0 + i * 1.25 for i in range(int((50.0 + 3.0) / 1.25) + 1)]
    rings = []
    off = Vector((3.1, -7.7, 1.9))
    for z in zs:
        rx = 12.6 + 1.4 * math.sin(z * 0.11 + 1.0) + (0.8 if z < 9 else 0.0)
        ry = 10.2 + 0.9 * math.cos(z * 0.09 + 0.4)
        s = 1.0
        if z > 43.0:
            s = math.sqrt(max(0.04, 1.0 - ((z - 43.0) / 8.5) ** 2))
        cx = 0.7 * math.sin(z * 0.07); cy = 0.5 * math.cos(z * 0.09)
        ring = []
        for k in range(N):
            th = 2 * math.pi * k / N
            n = noise.fractal(Vector((math.cos(th) * 1.8, math.sin(th) * 1.8, z * 0.13)) + off, 0.6, 2.0, 4, noise_basis='PERLIN_ORIGINAL')
            r_add = 1.7 * n
            ring.append(bm.verts.new((cx + (rx * s + r_add) * math.cos(th), cy + (ry * s + r_add) * math.sin(th), z)))
        rings.append(ring)
    for i in range(len(rings) - 1):
        for k in range(N):
            a, b = rings[i][k], rings[i][(k + 1) % N]
            c, d = rings[i + 1][(k + 1) % N], rings[i + 1][k]
            bm.faces.new((a, b, c, d))
    top = bm.verts.new((0.0, 0.0, 51.8)); bot = bm.verts.new((0.0, 0.0, -3.5))
    for k in range(N):
        bm.faces.new((rings[-1][k], rings[-1][(k + 1) % N], top))
        bm.faces.new((rings[0][(k + 1) % N], rings[0][k], bot))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bmesh.ops.reverse_faces(bm, faces=bm.faces)          # inward
    bmesh.ops.subdivide_edges(bm, edges=bm.edges[:], cuts=1, use_grid_fill=True)
    bm.normal_update()
    off2 = Vector((5.5, 2.2, -1.3))
    for v in bm.verts:
        p = v.co * 0.42 + off2
        v.co += v.normal * 0.55 * noise.fractal(p, 0.55, 2.0, 4, noise_basis='PERLIN_ORIGINAL')
    ob = mk_obj("shell", bm, "M_Rock", C)
    # ledges growing out of the walls
    sx0, sx1, sy0, sy1 = L["shelf"]
    rockslab(C, sx0, sx1 + 2.5, sy0 - 2.0, sy1, L["top"] - 4.5, L["top"] - 0.2, amp=0.18, freq=0.4, seed=41, name="shelf")
    boxmm(C, "M_Concrete", sx0 + 0.3, sx1, sy0 + 0.3, sy1, L["top"] - 0.4, L["top"], "shelf_pad", 0.05)
    mx0, mx1, my0, my1 = L["mid_ledge"]
    rockslab(C, mx0, mx1 + 2.5, my0 - 2.0, my1 + 1.5, L["mid"] - 4.0, L["mid"] - 0.2, amp=0.18, freq=0.4, seed=42, name="midledge")
    boxmm(C, "M_Concrete", mx0, mx1, my0 + 0.3, my1, L["mid"] - 0.4, L["mid"], "mid_pad", 0.05)
    ax0, ax1, ay0, ay1 = L["arch_ledge"]
    rockslab(C, ax0 - 2.0, ax1, ay0 - 2.0, ay1, L["arch"] - 4.5, L["arch"] - 0.2, amp=0.18, freq=0.4, seed=43, name="archledge")
    boxmm(C, "M_Concrete", ax0 + 0.6, ax1, ay0 + 0.6, ay1, L["arch"] - 0.4, L["arch"], "arch_pad", 0.05)
    # broken masonry arch on the arch ledge (lower left in the reference): two piers, half an arch, fallen blocks
    A = L["arch"]; ay = -7.4
    for px in (-10.6, -6.4):
        boxmm(C, "M_Concrete", px - 0.45, px + 0.45, ay - 0.45, ay + 0.45, A - 0.2, A + 3.6 - (1.4 if px > -8 else 0.0), "pier", 0.08)
    cxr, r = -8.5, 2.1
    for k in range(5):     # only the left half survives
        a0 = math.pi - k * math.pi / 9; a1 = math.pi - (k + 1) * math.pi / 9
        member(C, "M_Concrete", (cxr + r * math.cos(a0), ay, A + 3.6 + r * math.sin(a0)), (cxr + r * math.cos(a1), ay, A + 3.6 + r * math.sin(a1)), 0.85, 0.6, "voussoir", 0.06)
    for i, (x, y, rz) in enumerate([(-7.3, -5.9, 0.5), (-5.6, -8.2, -0.3), (-8.9, -5.4, 1.1)]):
        ob = boxmm(C, "M_Concrete", -0.45, 0.45, -0.3, 0.3, -0.3, 0.3, "fallen", 0.08)
        ob.location = (x, y, A + 0.25); ob.rotation_euler = (0.3 * i, 0.2, rz)
    # big boulder on the shelf (top-right silhouette) and some rubble
    rockblob(C, (10.4, -6.0, L["top"] + 2.6), (2.9, 2.6, 3.4), amp=0.45, seed=44, sub=3, name="boulder")
    rockblob(C, (-11.2, 5.0, 20.0), (2.0, 3.5, 5.0), amp=0.5, seed=45, sub=3, name="pillar")
    rockblob(C, (2.0, 8.8, 14.0), (4.5, 2.0, 6.0), amp=0.5, seed=46, sub=3, name="bulge")
    for i, (c, s) in enumerate([((-6.5, -8.5, L["arch"] + 0.4), (1.0, 0.8, 0.7)), ((10.5, 3.6, L["mid"] + 0.4), (0.9, 0.7, 0.6)),
                                ((-2.3, -7.8, L["arch"] + 0.3), (0.7, 0.6, 0.5)), ((10.8, -7.6, L["top"] + 0.3), (0.8, 0.7, 0.5))]):
        rockblob(C, c, s, amp=0.3, seed=50 + i, sub=2, name="rubble")
    # tunnel mouth through the east wall at the bottom bridge
    t0, t1, ty0, ty1 = L["tunnel"]
    for o in list(bpy.data.collections[C].objects):
        if o.type == 'MESH':
            carve_box(o, (t0 - 4.0, ty0, L["bottom"] - 0.05), (t1 + 2.0, ty1, L["bottom"] + 3.6))
    return join_into("SR_Rock-col", C)


# ---------------------------------------------------------------- steel structure, stairs, catwalks
def deck(C, x0, x1, y0, y1, z, mat="M_Grate", edge=True):
    boxmm(C, mat, x0, x1, y0, y1, z - 0.06, z, "deck", 0.0)
    if edge:
        for (a, b) in (((x0, y0), (x1, y0)), ((x0, y1), (x1, y1)), ((x0, y0), (x0, y1)), ((x1, y0), (x1, y1))):
            member(C, "M_Steel", (a[0], a[1], z - 0.2), (b[0], b[1], z - 0.2), 0.14, 0.28)

def column(C, x, y, z0, z1):
    ibeam(C, (x, y, z0), (x, y, z1), h=0.36, w=0.3)

def xrail(C, p0, p1, z, h=1.1):
    """X-braced railing panel run (the look in the reference image)."""
    truss(C, Vector((p0[0], p0[1], z)), Vector((p1[0], p1[1], z)), height=h, mat="M_Steel", panel=1.4, sz=0.07)

def flight(D, R, lo, hi, width=2.0):
    """Stairs whose treads/rails are visual only (in D): the smooth collision ramp (in R) is the walking
    surface, so the player glides down instead of tripping on nosings. Invisible rails line the ramp."""
    stairs(D, lo, hi, width=width, rampcat=R)
    lo = Vector(lo); hi = Vector(hi); d = hi - lo
    fwd = Vector((d.x, d.y, 0)).normalized(); side = Vector((-fwd.y, fwd.x, 0))
    for s in (-1, 1):
        o = side * (s * (width / 2 + 0.03)) + Vector((0, 0, 0.6))
        member(R, None, lo + o, hi + o, 0.06, 1.2, "guardrail")

def structure():
    C = "SR_StructC"; ccoll(C)
    R = "SR_RampsC"; ccoll(R)
    D = "SR_DetailC"; ccoll(D)
    T, M, A, B = L["top"], L["mid"], L["arch"], L["bottom"]
    # spawn platform + columns (also carry landing L1 and the overhead girder)
    x0, x1, y0, y1 = L["spawn_plat"]
    deck(C, x0, x1, y0, y1, T)
    for x in (-9.0, -2.5):
        for y in (-1.8, 0.8):
            column(C, x, y, L["water"] - 1.0, 44.5)
    for x in (-9.0, -2.5):
        ibeam(C, (x, -4.5, 44.5), (x, 3.5, 44.5), h=0.4, w=0.3)
    ibeam(C, (-11.5, -1.8, 44.5), (9.0, -1.8, 44.5), h=0.45, w=0.3)       # long girder across the shaft
    for x in (-6.0, 3.0, 8.5):
        member(C, "M_Steel", (x, -1.8, 44.5), (x + 0.3, -1.8, 50.5), 0.18, 0.18)  # hangers into the roof
    for x in (-9.0, -2.5):                                                  # cross bracing between columns
        member(C, "M_Steel", (x, -1.8, 26.0), (x, 0.8, 36.0), 0.09, 0.09)
        member(C, "M_Steel", (x, 0.8, 26.0), (x, -1.8, 36.0), 0.09, 0.09)
    xrail(C, (x0, y0), (x1, y0), T)
    xrail(C, (x0, y1), (x1, y1), T)
    xrail(C, (x1, y0), (x1, -1.4), T)
    xrail(C, (x1, 0.4), (x1, y1), T)
    xrail(C, (x0, y0), (x0, y1), T)
    # catwalk to the shelf
    deck(C, x1, L["shelf"][0] + 0.4, -1.4, 0.4, T)
    xrail(C, (x1, -1.4), (L["shelf"][0] + 0.4, -1.4), T)
    xrail(C, (x1, 0.4), (L["shelf"][0] + 0.4, 0.4), T)
    member(C, "M_Steel", (0.5, -0.5, T - 0.3), (0.5, -0.5, L["water"] - 1.0), 0.16, 0.16)  # prop under the catwalk
    # top landing (shelf -> flight1)
    a0, a1, b0, b1 = L["top_land"]
    deck(C, a0, a1, b0, b1, T)
    xrail(C, (a1, b0), (a1, b1), T)
    xrail(C, (a0 + 0.2, b1), (a1, b1), T)
    xrail(C, (a0, b0 + 0.2), (a0, L["f1"][0][1] - 1.05), T)
    column(C, a1 - 0.2, b1 - 0.2, M, T)
    # flight1 (back wall, westward) + landing L1 + flight2 (eastward)
    (fx0, fy), (fx1, _) = L["f1"]
    flight(D, R, (fx1, fy, L["l1"]), (fx0, fy, T))          # stairs() builds bottom -> top
    l0, l1x, m0, m1 = L["l1_rect"]
    deck(C, l0, l1x, m0, m1, L["l1"])
    xrail(C, (l0, m0), (l0, m1), L["l1"])
    xrail(C, (l0, m1), (l1x, m1), L["l1"])
    xrail(C, (l0, m0), (l1x, m0), L["l1"])
    for (x, y) in ((l0 + 0.2, m1 - 0.2), (l0 + 0.2, m0 + 0.2)):
        member(C, "M_Steel", (x, y, L["l1"] - 0.2), (x - 1.2, y, L["l1"] - 2.4), 0.12, 0.12)   # wall brackets
    (gx0, gy), (gx1, _) = L["f2"]
    flight(D, R, (gx1, gy, M), (gx0, gy, L["l1"]))
    # left landing (bridge target) on its own columns, with the ladder well on its north edge
    q0, q1, r0, r1 = L["left_land"]
    deck(C, q0, q1, r0, r1, M)
    for (x, y) in ((q0 + 0.2, r0 + 0.2), (q1 - 0.2, r0 + 0.2)):
        column(C, x, y, A - 2.0, M)
    xrail(C, (q0, r0), (q1, r0), M)
    xrail(C, (q0, r0), (q0, r1), M)
    xrail(C, (q0, r1), (L["ladder"][0] - 0.7, r1), M)
    xrail(C, (L["ladder"][0] + 0.7, r1), (q1, r1), M)
    # ladder down to the arch ledge (+ the plate behind it the climber leans on)
    lx, ly = L["ladder"]
    for dx in (-0.46, 0.46):     # wide enough for the player to step between the hand-rails at the top
        member(C, "M_Steel", (lx + dx, ly, A), (lx + dx, ly, M + 1.05), 0.06, 0.06)
    z = A + 0.3
    while z < M:
        member(C, "M_Steel", (lx - 0.46, ly, z), (lx + 0.46, ly, z), 0.035, 0.035)
        z += 0.32
    boxmm(C, "M_Steel", lx - 0.6, lx + 0.6, ly - 0.2, ly - 0.12, A, M - 0.25, "ladder_back", 0.0)
    # mid ledge: railing on the west edge except where the drawbridge lands
    by0, by1 = L["bridge_y"]
    hx = L["hinge_x"]
    xrail(C, (hx, L["mid_ledge"][2] + 0.4), (hx, by0 - 0.15), M)
    xrail(C, (hx, by1 + 0.15), (hx, gy - 1.05), M)
    xrail(C, (hx, gy + 1.05), (hx, L["mid_ledge"][3] - 0.2), M)
    boxmm(C, "M_Steel", hx - 0.25, hx + 0.6, by0 - 0.2, by1 + 0.2, M - 0.3, M, "hinge_plate", 0.0)
    for y in (by0 - 0.1, by1 + 0.1):
        cyl(C, "M_Rust", (hx, y, M - 0.1), (hx, y + (0.25 if y > (by0 + by1) / 2 else -0.25), M - 0.1), 0.16, 10, "hinge_knuckle")
    cyl(C, "M_Steel", (hx + 0.6, by0 - 0.35, M - 2.6), (hx + 0.1, by0 - 0.35, M - 0.2), 0.14, 10, "ram")   # hydraulic ram
    cyl(C, "M_Rust", (hx + 0.7, by0 - 0.35, M - 3.2), (hx + 0.6, by0 - 0.35, M - 2.4), 0.2, 10, "ram_body")
    # far side of the bridge: stop + hazard edge on the left landing
    boxmm(C, "M_Hazard", q1 - 0.3, q1, by0, by1, M, M + 0.01, "bridge_haz", 0.0)
    # flight4 from the arch ledge down to the bottom bridge, landing pad, and the bridge itself
    (hx0, hy), (hx1, _) = L["f4"]
    flight(D, R, (hx1, hy, B), (hx0, hy, A))
    deck(C, hx1, hx1 + 2.2, hy - 1.0, L["bridge"][2], B)
    xrail(C, (hx1, hy - 1.0), (hx1 + 2.2, hy - 1.0), B)
    xrail(C, (hx1 + 2.2, hy - 1.0), (hx1 + 2.2, L["bridge"][2]), B)
    b0x, b1x, b0y, b1y = L["bridge"]
    deck(C, b0x, b1x, b0y, b1y, B)
    xrail(C, (b0x, b1y), (b1x, b1y), B)
    xrail(C, (b0x, b0y), (hx1, b0y), B)
    xrail(C, (hx1 + 2.2, b0y), (b1x, b0y), B)
    xrail(C, (b0x, b0y), (b0x, b1y), B)
    for x in range(int(b0x) + 1, int(b1x), 4):
        for y in (b0y + 0.1, b1y - 0.1):
            member(C, "M_Steel", (x, y, B - 0.2), (x, y, L["water"] - 1.0), 0.18, 0.18)   # piers into the water
    # pipe machinery on the mid ledge
    c0, c1, d0, d1 = L["mach"]
    boxmm(C, "M_Rust", c0, c1, d0, d1, M, M + 4.6, "housing", 0.06)
    for (p, q) in (((c0 - 0.02, d0, M), (c0 - 0.02, d1, M + 4.6)), ((c0 - 0.02, d1, M), (c0 - 0.02, d0, M + 4.6))):
        member(C, "M_Steel", p, q, 0.08, 0.12)
    for z in (M + 0.1, M + 4.5):
        member(C, "M_Steel", (c0 - 0.05, d0, z), (c0 - 0.05, d1, z), 0.14, 0.18)
    cyl(C, "M_Steel", (c0 + 1.6, d0 - 0.9, M + 5.6), (c0 + 1.6, d0 - 0.9, L["water"] - 1.0), 0.55, 14, "downpipe")
    cyl(C, "M_Rust", (c0 + 1.6, d0 - 0.9, M + 5.6), (c0 + 1.6, d1 + 6.0, M + 5.6), 0.55, 14, "header")
    cyl(C, "M_Rust", (c0 + 1.6, d0 - 0.9, M + 5.6), (c0 + 1.6, d0 - 0.9, M + 6.6), 0.7, 14, "elbow")
    for z in (M + 1.5, 15.0, 8.0):
        cyl(C, "M_Steel", (c0 + 1.6, d0 - 0.9, z), (c0 + 1.6, d0 - 0.9, z + 0.25), 0.72, 14, "flange")
    cyl(C, "M_Steel", (c0, L["valve"][1], M + 1.2), (L["valve"][0] + 0.25, L["valve"][1], M + 1.2), 0.12, 8, "valve_feed")
    boxmm(C, "M_Hazard", c0 - 0.03, c0 - 0.01, d0 + 0.5, d1 - 0.5, M + 3.4, M + 3.8, "mach_haz", 0.0)
    # boiler on the shelf (the hunched machine top right)
    cyl(C, "M_Rust", (6.6, -6.8, T + 1.25), (6.6, -2.4, T + 1.25), 1.2, 16, "boiler")
    cyl(C, "M_Steel", (6.6, -6.9, T + 1.25), (6.6, -6.7, T + 1.25), 1.28, 16, "boiler_ring")
    cyl(C, "M_Steel", (6.6, -2.5, T + 1.25), (6.6, -2.3, T + 1.25), 1.28, 16, "boiler_ring")
    cyl(C, "M_Rust", (6.6, -3.4, T + 2.2), (6.6, -3.4, T + 5.6), 0.32, 10, "stack")
    boxmm(C, "M_Steel", 5.4, 7.8, -7.0, -2.2, T, T + 0.3, "saddle", 0.03)
    ob = join_into("SR_Struct-col", C)
    ramps = join_into("SR_Ramps-colonly", R)
    ramps.data.materials.clear()
    det = join_into("SR_Detail", D)
    return ob, ramps, det


# ---------------------------------------------------------------- tunnel to the cavern + water + foliage + lamps
def tunnel():
    C = "SR_TunnelC"; ccoll(C)
    t0, t1, y0, y1 = L["tunnel"]
    B = L["bottom"]; H = 3.5
    boxmm(C, "M_Concrete", t0 - 0.5, t1, y0, y1, B - 0.35, B, "tfloor", 0.0)
    rockslab(C, t0 - 2.0, t1 + 0.3, y0 - 1.0, y0 - 0.1, B - 0.6, B + H + 0.8, amp=0.2, freq=0.55, seed=61, spacing=0.9, name="tws")
    rockslab(C, t0 - 2.0, t1 + 0.3, y1 + 0.1, y1 + 1.0, B - 0.6, B + H + 0.8, amp=0.2, freq=0.55, seed=62, spacing=0.9, name="twn")
    rockslab(C, t0 - 2.0, t1 + 0.3, y0 - 0.9, y1 + 0.9, B + H + 0.1, B + H + 1.0, amp=0.2, freq=0.55, seed=63, spacing=0.9, name="twc")
    x = t0 + 0.6
    while x < t1 - 1.0:
        for y in (y0 + 0.12, y1 - 0.12):
            ibeam(C, (x, y, B), (x, y, B + H - 0.1), h=0.22, w=0.16, mat="M_Rust")
        ibeam(C, (x, y0 + 0.05, B + H - 0.1), (x, y1 - 0.05, B + H - 0.1), h=0.24, w=0.18, mat="M_Rust")
        x += 2.0
    # bulkhead + doorway at the far end (the scene change happens in the doorway)
    bx = t1 - 0.4
    boxmm(C, "M_Concrete", bx, bx + 0.5, y0 - 0.2, -1.55, B - 0.3, B + H + 0.3, "bh_s", 0.03)
    boxmm(C, "M_Concrete", bx, bx + 0.5, -0.45, y1 + 0.2, B - 0.3, B + H + 0.3, "bh_n", 0.03)
    boxmm(C, "M_Concrete", bx, bx + 0.5, -1.55, -0.45, B + 2.35, B + H + 0.3, "bh_t", 0.03)
    for y in (-1.6, -0.4):
        member(C, "M_Steel", (bx - 0.05, y, B), (bx - 0.05, y, B + 2.4), 0.14, 0.14)
    boxmm(C, "M_Hazard", bx - 0.07, bx - 0.05, -1.55, -0.45, B + 2.4, B + 2.6, "bh_haz", 0.0)
    boxmm(C, "M_Silhouette", bx + 2.6, bx + 2.8, -2.0, 0.1, B - 0.3, B + 2.8, "void_back", 0.0)
    boxmm(C, "M_Silhouette", bx + 0.45, bx + 2.7, -2.0, -1.8, B - 0.3, B + 2.8, "void_s", 0.0)
    boxmm(C, "M_Silhouette", bx + 0.45, bx + 2.7, -0.1, 0.1, B - 0.3, B + 2.8, "void_n", 0.0)
    boxmm(C, "M_Silhouette", bx + 0.45, bx + 2.7, -2.0, 0.1, B + 2.6, B + 2.8, "void_t", 0.0)
    boxmm(C, "M_Concrete", bx + 0.45, bx + 2.7, -2.0, 0.1, B - 0.3, B, "void_f", 0.0)
    # portal at the mouth
    boxmm(C, "M_Concrete", t0 - 0.6, t0, y0 - 0.6, y0 + 0.02, B - 0.4, B + H + 0.5, "pp_s", 0.05)
    boxmm(C, "M_Concrete", t0 - 0.6, t0, y1 - 0.02, y1 + 0.6, B - 0.4, B + H + 0.5, "pp_n", 0.05)
    boxmm(C, "M_Concrete", t0 - 0.65, t0 + 0.05, y0 - 0.6, y1 + 0.6, B + H - 0.05, B + H + 0.9, "lintel", 0.05)
    boxmm(C, "M_Hazard", t0 - 0.67, t0 - 0.65, y0 + 0.1, y1 - 0.1, B + H + 0.05, B + H + 0.35, "haz", 0.0)
    # cage lamps
    for xx in (t0 + 1.6, t1 - 2.4):
        boxmm(C, "M_Steel", xx - 0.12, xx + 0.12, -1.12, -0.88, B + H - 0.42, B + H - 0.22, "lh", 0.01)
        boxmm(C, "M_Lamp", xx - 0.08, xx + 0.08, -1.08, -0.92, B + H - 0.47, B + H - 0.42, "lg", 0.0)
    return join_into("SR_Tunnel-col", C)

def water():
    C = "SR_WaterC"; ccoll(C)
    boxmm(C, "M_Water", -16, 16, -14, 14, L["water"] - 0.02, L["water"], "water", 0.0)
    return join_into("SR_Water", C)

FERNS = [(-8.6, 2.4, 38.0, 1.3), (-3.0, -3.4, 38.0, 1.0), (3.6, -7.8, 38.0, 1.2), (10.4, 1.4, 38.0, 1.1),
         (-7.2, 6.2, 31.0, 1.0), (5.2, 4.0, 24.0, 1.1), (10.6, -6.6, 24.0, 1.3), (-11.0, -7.4, 13.0, 1.4),
         (-4.0, -8.4, 13.0, 1.0), (-1.9, -1.4, 13.0, 0.9), (11.2, -2.9, 5.0, 1.0), (-8.4, 0.9, 5.0, 0.8),
         # bigger masses, like the reference: on the girder, the machinery roof, by the boulder, on the arch
         (-6.0, -1.8, 44.75, 1.5), (2.8, -1.8, 44.75, 1.3), (-9.3, -3.7, 38.0, 1.5), (8.6, -8.2, 38.3, 1.5),
         (8.6, -2.2, 28.6, 1.6), (10.2, 0.4, 28.6, 1.2), (-9.0, -6.0, 24.0, 1.2), (-10.6, -7.4, 16.65, 1.1),
         (-11.6, 3.5, 24.5, 1.4), (11.6, 5.0, 31.0, 1.3)]
VINES = [(-6.0, 6.5, 50.0, 9.0), (2.0, 7.5, 49.0, 12.0), (8.5, -1.8, 44.3, 6.0), (-9.0, -4.4, 37.8, 5.5),
         (-2.6, 3.0, 37.8, 4.0), (-11.0, -3.0, 46.0, 14.0), (10.5, 4.6, 23.8, 7.0), (6.0, -8.0, 33.0, 10.0),
         (-4.0, -9.0, 30.0, 9.0), (0.0, -1.8, 44.3, 7.5)]

def foliage():
    C = "SR_FoliageC"; ccoll(C)
    for i, (x, y, z, s) in enumerate(FERNS):
        for j in range(3):
            fern(C, (x + math.cos(j * 2.1) * 0.6 * s, y + math.sin(j * 2.1) * 0.5 * s, z), scale=s * random.Random(i * 7 + j).uniform(0.7, 1.2), seed=i * 7 + j)
    for i, (x, y, z, l) in enumerate(VINES):
        vine(C, (x, y, z), l, seed=100 + i)
    ob = join_into("SR_Foliage", C)
    return ob

LAMPS = [(-2.5, 0.45, 40.6), (7.6, 1.45, 27.4), (-3.0, -0.2, 7.2), (6.0, -0.2, 7.2), (-7.6, -4.6, 27.0)]
def lamps():
    C = "SR_LampsC"; ccoll(C)
    for (x, y, z) in LAMPS:
        boxmm(C, "M_Steel", x - 0.16, x + 0.16, y - 0.16, y + 0.16, z, z + 0.3, "cage", 0.02)
        boxmm(C, "M_Lamp", x - 0.1, x + 0.1, y - 0.1, y + 0.1, z - 0.12, z, "bulb", 0.0)
        member(C, "M_Steel", (x, y, z + 0.3), (x, y, z + 1.4), 0.03, 0.03)
    return join_into("SR_Lamps", C)


# ---------------------------------------------------------------- moving prop: drawbridge (origin = hinge, extends -X)
def drawbridge():
    C = "SR_PropC"; ccoll(C)
    ln = L["bridge_len"]; w = (L["bridge_y"][1] - L["bridge_y"][0]) / 2
    boxmm(C, "M_Grate", -ln, 0.0, -w, w, -0.08, 0.0, "deck", 0.0)
    for y in (-w, w):
        member(C, "M_Steel", (-ln, y, -0.22), (0.0, y, -0.22), 0.14, 0.3)
        truss(C, Vector((-ln + 0.1, y, 0.0)), Vector((-0.2, y, 0.0)), height=1.0, mat="M_Steel", panel=1.4, sz=0.06)
    for x in (-ln + 0.3, -ln / 2, -0.4):
        member(C, "M_Steel", (x, -w, -0.22), (x, w, -0.22), 0.12, 0.2)
    boxmm(C, "M_Hazard", -ln, -ln + 0.3, -w, w, 0.0, 0.012, "lip", 0.0)
    ob = join_into("SR_Drawbridge", C)
    return ob


def write_lights():
    data = {"layout": {k: v for k, v in L.items()},
            "ferns": [list(f) for f in FERNS], "lamps": [list(l) for l in LAMPS]}
    with open(os.path.join(PROJ, "art_src", "start_room.json"), "w") as f:
        json.dump(data, f, indent=1)


def _export(names, path):
    # The exporter works on bpy.context.scene, which can still be the main "Scene" inside a script (and
    # temp_override(scene=...) crashes it). So link the objects into the active scene for the export only.
    sc = bpy.context.scene
    tmp = bpy.data.collections.new("_EXPORT_TMP"); sc.collection.children.link(tmp)
    for n in names:
        tmp.objects.link(SR.objects[n])
    bpy.context.view_layer.update()
    for o in sc.objects:
        o.select_set(o.name in names)
    # use_active_scene: without it the exporter walks every scene in the file (Preview, Scene, StartRoom)
    bpy.ops.export_scene.gltf(filepath=path, export_format='GLB', use_selection=True, use_active_scene=True,
                              export_apply=True, export_yup=True)
    sc.collection.children.unlink(tmp); bpy.data.collections.remove(tmp)

def export_all():
    _export(["SR_Rock-col", "SR_Struct-col", "SR_Detail", "SR_Ramps-colonly", "SR_Tunnel-col", "SR_Water", "SR_Foliage", "SR_Lamps"],
            os.path.join(PROJ, "assets", "level", "start.glb"))
    _export(["SR_Drawbridge"], os.path.join(PROJ, "assets", "props", "drawbridge.glb"))


def build_all():
    shell(); structure(); tunnel(); water(); foliage(); lamps(); drawbridge(); write_lights()
    print("start room built:", [(o.name, len(o.data.vertices)) for o in SR.objects if o.type == 'MESH'])
