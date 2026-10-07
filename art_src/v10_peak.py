
# v10: the Peak (first boss arena) + the radio mast, off the south-west rim of the mesa (surface.tscn).
#   Approach: mesa rim -> natural rock arch (broken) -> fallen slab -> trestle A + a sagging span of the old bridge ->
#             trestle B -> a girder on a slender pylon -> far arch stub -> the plateau. ~55 m, six jumps.
#   Peak:     a smaller plateau (~40 m radius) standing out of the haze: rises, boulders and a few ruins to walk round.
#             On it, the Hall (the arena): a ruined concrete building on an irregular footprint, its roof gone (a few
#             trusses still span it). Level 1 floor, a level-2 gallery round five walls with two stairs up, BossGate in
#             the entrance, ExitGate on the gallery, and a sealed annex (the hidden room) behind HiddenDoor.
#   Mast:     ExitGate -> landing -> truss gantry -> band 1 -> a square spiral of stairs, hops, beams and ladders round
#             the outside of the lattice, 4 bands (checkpoints), up to the cabin. The tallest thing on the surface.
# Source: art_src/peak.blend, scene "Peak10" (the mesa is appended in REF_Mesa as a reference only, never exported).
# Run:    exec(open(r"...\art_src\v10_peak.py").read()); build_all(); export_all()
# Out:    assets/level/peak.glb  +  art_src/peak.json (layout, ladders, checkpoints, lamps; Blender coords)
exec(open(r"D:\Emberlight\art_src\v5_surface.py").read())
import json

# v5_surface.py makes a "Surface5" scene if the file has none: here everything lives in "Peak10"
if "Peak10" not in bpy.data.scenes:
    bpy.data.scenes.new("Peak10")
_s5 = bpy.data.scenes.get("Surface5")
if _s5 is not None and not _s5.objects and len(bpy.data.scenes) > 1:
    bpy.data.scenes.remove(_s5)
S5 = bpy.data.scenes["Peak10"]          # s5coll() links new collections to S5

P10 = dict(
    bearing=-130.07,                    # mesa centre -> plateau centre (deg)
    dist=185.0,                         #   ... and how far
    rim=40.0,                           # plateau radius (mean)
    ground=38.0,                        # plateau top (flat pads) = hall floor
    gallery=44.5,                       # hall level 2 = exit door = band 1
    hall_off=12.0, hall_yaw=205.0,      # hall centre from the plateau centre, and its +X (towards the mast)
    mast_off=44.6,                      # hall centre -> mast axis along hall_yaw: exit landing 18.7 + gantry ~12 + band 1 half 13.9
    foot=22.0,                          # top of the mast's rock foot
    bands=(44.5, 61.0, 76.0, 90.0),     # mast platform rings (checkpoints)
    cabin=104.0,                        # cabin floor = end of the climb
    tip=162.0,                          # antenna tip (spires top out at ~154)
)
G2, ZG = P10["ground"], P10["gallery"]
ZB = -85.0                              # bottom of the rock (deep in the haze)

def _pn(a, b, c):
    return noise.fractal(Vector((a, b, c)), 0.55, 2.0, 3, noise_basis='PERLIN_ORIGINAL')

def angd(a, b):
    """a - b in degrees, wrapped to -180..180."""
    return (a - b + 180.0) % 360.0 - 180.0

def pdir(th):
    t = math.radians(th)
    return Vector((math.cos(t), math.sin(t), 0.0))

_u = pdir(P10["bearing"])
PX, PY = CENTER.x + P10["dist"] * _u.x, CENTER.y + P10["dist"] * _u.y
BYAW = P10["hall_yaw"]
BX, BY = PX + P10["hall_off"] * pdir(BYAW).x, PY + P10["hall_off"] * pdir(BYAW).y
MX, MY = BX + P10["mast_off"] * pdir(BYAW).x, BY + P10["mast_off"] * pdir(BYAW).y
MYAW = BYAW - 180.0                                                      # mast local +X faces the hall
ENTRY_TH = math.degrees(math.atan2(CENTER.y - PY, CENTER.x - PX))      # plateau bearing that faces the mesa
BXF = Matrix.Translation((BX, BY, 0)) @ Matrix.Rotation(math.radians(BYAW), 4, 'Z')
P10.update(peak=(round(PX, 2), round(PY, 2)), hall=(round(BX, 2), round(BY, 2)), mast=(round(MX, 2), round(MY, 2)),
           mast_yaw=round(MYAW, 2), entry_th=round(ENTRY_TH, 2))

def ppt(th, r, z):
    d = pdir(th)
    return Vector((PX + r * d.x, PY + r * d.y, z))

def bw(p):
    """Hall-local -> world."""
    return BXF @ Vector((p[0], p[1], p[2] if len(p) > 2 else 0.0))

def xf_obj(o, xf):
    """Move a freshly made object by xf. (Its matrix_world is still identity until the depsgraph updates, so build
    the basis from loc/rot/scale.)"""
    rot = o.rotation_quaternion if o.rotation_mode == 'QUATERNION' else o.rotation_euler.to_quaternion()
    o.matrix_basis = xf @ Matrix.LocRotScale(o.location, rot, o.scale)

def move_all(src, dst, xf):
    for o in list(bpy.data.collections[src].objects):
        if xf is not None: xf_obj(o, xf)
        bpy.data.collections[src].objects.unlink(o); bpy.data.collections[dst].objects.link(o)
    bpy.data.collections.remove(bpy.data.collections[src])

def set_origin(ob, c):
    c = Vector(c)
    ob.data.transform(Matrix.Translation(-c)); ob.location = c

def own_object(name, tmp, origin):
    """Merge temp collection tmp into its own object (a moving part for Godot), origin at origin, linked to the scene."""
    ob = merge_into(name, tmp)
    set_origin(ob, origin)
    bpy.data.collections.remove(bpy.data.collections[tmp])
    S5.collection.objects.link(ob)
    return ob

def oriented_box(cat, mat, c, yaw, size, name="obox", bevel=0.02):
    """Box centred on c, turned to yaw deg (size: along, across, height)."""
    ob = boxmm(cat, mat, -size[0] / 2, size[0] / 2, -size[1] / 2, size[1] / 2, -size[2] / 2, size[2] / 2, name, bevel)
    ob.location = c; ob.rotation_euler = (0, 0, math.radians(yaw))
    return ob

def prism(cat, mat, pts, z0, z1, name="prism"):
    """Vertical prism over a convex-ish 2D polygon (counter-clockwise)."""
    bm = bmesh.new()
    lo = [bm.verts.new((p[0], p[1], z0)) for p in pts]; hi = [bm.verts.new((p[0], p[1], z1)) for p in pts]
    bm.faces.new(list(reversed(lo))); bm.faces.new(hi)
    n = len(pts)
    for k in range(n):
        bm.faces.new((lo[k], lo[(k + 1) % n], hi[(k + 1) % n], hi[k]))
    return mk_obj(name, bm, mat, cat)

# ---------------------------------------------------------------- the plateau (rings like the mesa, smaller)
def p_rim(th):
    t = math.radians(th)
    r = P10["rim"] + 5.5 * _pn(math.cos(t) * 1.3 + 17.0, math.sin(t) * 1.3, 2.2)
    return r - 3.0 * smooth(40.0, 10.0, abs(angd(th, BYAW)))      # pulled in on the mast side (legs clear the edge)

LAND = Vector((PX, PY, 0)) + pdir(ENTRY_TH) * (p_rim(ENTRY_TH) - 4.0)     # where the approach arrives
HALL_DOOR = bw((-13.4, -9.8))                                              # in front of the entrance (hall s7)

def _seg_dist(p, a, b):
    ab = b - a; t = max(0.0, min(1.0, (p - a).dot(ab) / max(1e-6, ab.length_squared)))
    return (p - (a + ab * t)).length

def p_flat(x, y):
    """1 = free terrain, 0 = flat pad: the hall (+ a walk round it), the landing, and the path between them."""
    p = Vector((x, y, 0))
    d = min((p - Vector((BX, BY, 0))).length - 21.0, (p - LAND).length - 6.0, _seg_dist(p, LAND, HALL_DOOR) - 3.0)
    return smooth(0.0, 7.0, d)

def p_ground(x, y, rr=None):
    if rr is None:
        rr = math.hypot(x - PX, y - PY) / p_rim(math.degrees(math.atan2(y - PY, x - PX)))
    m = p_flat(x, y)
    n = _pn(x * 0.045, y * 0.045, 5.5); n2 = _pn(x * 0.11, y * 0.11, 9.1)
    t = max(0.0, 5.0 * n + 1.3) + 3.0 * max(0.0, n2)
    k = t / 1.4; fl = math.floor(k)
    t += ((fl + smooth(0.3, 0.7, k - fl)) * 1.4 - t) * 0.6         # strata terraces
    h = G2 + 0.15 * _pn(x * 0.2, y * 0.2, 2.2) * (0.2 + m) + t * m
    lip = max(0.0, rr - 0.88) / 0.12
    return h + lip * lip * 1.8 * m

def plateau(C):
    bm = bmesh.new()
    N = 160; nr = 30
    fr = [0.0] + [1.0 - (1.0 - i / nr) ** 1.25 for i in range(1, nr + 1)]
    rims = [p_rim(360.0 * k / N) for k in range(N)]
    top = []
    for f in fr:
        ring = []
        for k in range(N):
            th = 2 * math.pi * k / N; r = rims[k] * f
            x = PX + r * math.cos(th); y = PY + r * math.sin(th)
            ring.append(bm.verts.new((x, y, p_ground(x, y, f))))
            if f == 0.0: break
        top.append(ring)
    drops = [0.6, 1.8, 3.5, 6.0, 9.0, 13.0, 18.0, 24.0, 31.0, 40.0, 52.0, 68.0, 90.0, 123.0]
    cliff = [top[-1]]
    for dz in drops:
        ring = []
        for k in range(N):
            th = 2 * math.pi * k / N
            z = top[-1][k].co.z - dz
            st = _pn(math.cos(th) * 2.5 + 40.0, math.sin(th) * 2.5, z * 0.09)
            r = rims[k] + 1.5 * st + 0.9 * math.sin(z * 0.55 + st * 2.0) - (0.7 if dz < 2.0 else 0.0) + max(0.0, dz - 14.0) * 0.22
            ring.append(bm.verts.new((PX + r * math.cos(th), PY + r * math.sin(th), z)))
        cliff.append(ring)
    def bridge(a, b):
        for k in range(N):
            if len(a) == 1: bm.faces.new((a[0], b[k], b[(k + 1) % N]))
            else: bm.faces.new((a[k], a[(k + 1) % N], b[(k + 1) % N], b[k]))
    for i in range(len(top) - 1): bridge(top[i], top[i + 1])
    for i in range(len(cliff) - 1): bridge(cliff[i], cliff[i + 1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    for f in bm.faces:
        f.smooth = True
        f.material_index = 0 if f.normal.z > 0.8 else 1
    ob = mk_obj("plateau", bm, "M_MesaGround", C); ob.data.materials.append(M("M_MesaCliff"))
    return ob

def plateau_dressing(C, W, D):
    """Things to find walking round: boulders and crags on the rises, a shed by the landing, an old survey mast on
    the high ground, drums and crates by the hall, a lamp post at the landing."""
    rnd = random.Random(12)
    n = 0
    for i in range(400):
        if n >= 34: break
        th = rnd.uniform(0, 360); r = p_rim(th) * math.sqrt(rnd.uniform(0.02, 0.93))
        p = ppt(th, r, 0)
        if p_flat(p.x, p.y) < 0.7: continue
        s = rnd.uniform(0.8, 2.8)
        rockblob(C, (p.x, p.y, p_ground(p.x, p.y) + s * 0.15), (s * rnd.uniform(1.0, 1.5), s * rnd.uniform(0.8, 1.3), s * rnd.uniform(0.6, 1.4)),
                 amp=0.45, seed=1500 + i, sub=2, mat="M_MesaCliff", name="boulder")
        n += 1
    # the high point (sampled): a survey lattice with a broken top and a ruined hut at its foot
    best = max(((p_ground(*ppt(th, r, 0).to_2d()), th, r) for th in range(0, 360, 6) for r in (12.0, 20.0, 28.0)
                if p_flat(*ppt(th, r, 0).to_2d()) > 0.9), default=None)
    out = {}
    if best:
        h, th, r = best
        p = ppt(th, r, 0)
        lattice(W, D, p.x, p.y, p_ground(p.x, p.y) - 0.4, 11.0, 1.2, 0.45, 151)
        tz = p_ground(p.x, p.y) - 0.4 + 11.0      # off the top of a leg, bent over
        member(D, "M_Steel", (p.x - 0.45, p.y - 0.45, tz), (p.x + 1.6, p.y + 0.2, tz - 1.6), 0.08, 0.08, "bent_top")
        q = ppt(th + 9, r, 0); hz = p_ground(q.x, q.y)
        boxmm(W, "M_Concrete", q.x - 2.0, q.x + 2.0, q.y - 1.6, q.y - 1.3, hz - 0.5, hz + 2.2, "ruin_wall", 0.03)
        boxmm(W, "M_Concrete", q.x + 1.7, q.x + 2.0, q.y - 1.6, q.y + 1.8, hz - 0.5, hz + 1.4, "ruin_wall", 0.03)
        out["survey"] = (round(p.x, 2), round(p.y, 2), round(h, 2))
    # shed by the landing (open front facing the path), lamp post
    sd = pdir(ENTRY_TH + 90.0); sc = LAND + sd * 6.5 - pdir(ENTRY_TH) * 3.0
    yaw = ENTRY_TH + 90.0; hz = p_ground(sc.x, sc.y)
    for (a, b) in (((-1.8, -1.4), (1.8, -1.4)), ((1.8, -1.4), (1.8, 1.4)), ((-1.8, -1.4), (-1.8, 1.4))):
        pa = sc + sd * a[0] + pdir(ENTRY_TH) * a[1]; pb = sc + sd * b[0] + pdir(ENTRY_TH) * b[1]
        member(W, "M_Corrugated", (pa.x, pa.y, hz + 1.2), (pb.x, pb.y, hz + 1.2), 0.12, 2.8, "shed_wall")
    ob = oriented_box(W, "M_RustSheet", Vector((sc.x, sc.y, hz + 2.7)), yaw, (4.2, 3.4, 0.14), "shed_roof", 0.0)
    ob.rotation_euler = (math.radians(6), 0, math.radians(yaw))
    crate(W, sc.x - sd.x * 0.6, sc.y - sd.y * 0.6, hz, 0.9, 0.3, 2); barrel(W, sc.x + sd.x * 1.0, sc.y + sd.y * 1.0, hz, 4)
    lp = LAND - sd * 3.2; hz = p_ground(lp.x, lp.y)
    cyl(W, "M_Steel", (lp.x, lp.y, hz - 0.3), (lp.x, lp.y, hz + 4.2), 0.1, 8, "lamppost")
    member(W, "M_Steel", (lp.x, lp.y, hz + 4.2), (lp.x + sd.x * 0.9, lp.y + sd.y * 0.9, hz + 4.2), 0.08, 0.08, "lamparm")
    lpos = Vector((lp.x + sd.x * 0.9, lp.y + sd.y * 0.9, hz + 4.0))
    cyl(D, "M_Lamp", lpos + Vector((0, 0, 0.15)), lpos - Vector((0, 0, 0.05)), 0.22, 10, "lampshade", r2=0.1)
    out["landing_lamp"] = tuple(round(v, 2) for v in lpos)
    # drums and crates by the hall entrance, a cable drum
    e = HALL_DOOR
    for i, (dx, dy) in enumerate(((-3.5, 1.0), (-4.2, 2.2), (3.8, -1.2))):
        q = e + bw((dx, dy)) - bw((0, 0)); barrel(W, q.x, q.y, G2, i)
    q = e + bw((-4.0, -1.5)) - bw((0, 0)); crate(W, q.x, q.y, G2, 1.1, 0.4, 0)
    return out

# ---------------------------------------------------------------- the Hall (built hall-local, +X towards the mast)
BV = [(16.0, -6.0), (16.0, 6.0), (11.0, 12.0), (2.0, 13.5), (-6.0, 12.0), (-13.0, 9.0), (-16.0, 2.0), (-15.0, -6.0),
      (-9.0, -12.0), (0.0, -13.0), (9.0, -11.0)]                   # outline, counter-clockwise; segment i = V[i] -> V[i+1]
NBV = len(BV)
WALL_T = 1.0
GAL = (9, 10, 0, 1, 2)                                              # segments with the level-2 gallery
DOORS = {7: [(2.0, 6.5, G2 - 1.0, G2 + 5.2)],                       # entrance (BossGate)
         0: [(4.8, 7.2, ZG, ZG + 3.0)],                             # exit to the mast (ExitGate)
         6: [(3.3, 5.0, G2 - 1.0, G2 + 2.5)]}                       # the hidden annex (HiddenDoor)

def bv(i):
    return Vector(BV[i % NBV])

def slen(i):
    return (bv(i + 1) - bv(i)).length

def sdir(i):
    return (bv(i + 1) - bv(i)).normalized()

def snrm(i):
    d = sdir(i); return Vector((-d.y, d.x))                         # inwards

def inset(i, d):
    """Vertex i moved d inwards (mitred)."""
    n1, n2 = snrm(i - 1), snrm(i)
    m = (n1 + n2).normalized()
    return bv(i) + m * (d / max(0.3, m.dot(n1)))

def wpt(i, t, off, z):
    p = bv(i) + sdir(i) * t + snrm(i) * off
    return Vector((p.x, p.y, z))

def ys_at(x):
    """(south, north) wall-line y where the vertical line X = x crosses the outline."""
    ys = []
    for i in range(NBV):
        a, b = bv(i), bv(i + 1)
        if (a.x - x) * (b.x - x) <= 0 and abs(b.x - a.x) > 1e-6:
            ys.append(a.y + (b.y - a.y) * (x - a.x) / (b.x - a.x))
    return min(ys), max(ys)

def hall_walls(C, D):
    """Concrete walls (broken, uneven tops), pilasters at the corners, buttresses, string courses and slot windows."""
    rnd = random.Random(21)
    tops = {}
    for i in range(NBV):
        L = slen(i); base = 12.2 + rnd.uniform(-0.6, 1.6)
        n = max(2, int(round(L / 2.2)))
        chunks = []
        for k in range(n):
            t0, t1 = L * k / n, L * (k + 1) / n
            bite = rnd.random() < 0.3
            top = G2 + base + (rnd.uniform(-3.5, -1.2) if bite else rnd.uniform(-0.5, 0.5))
            chunks.append((t0, t1, top))
            cuts = [(t0, t1, G2 - 0.6, top)]
            for (d0, d1, z0, z1) in DOORS.get(i, ()):
                nxt = []
                for (a, b, za, zb) in cuts:
                    if b <= d0 or a >= d1:
                        nxt.append((a, b, za, zb)); continue
                    if a < d0: nxt.append((a, d0, za, zb))
                    if b > d1: nxt.append((d1, b, za, zb))
                    m0, m1 = max(a, d0), min(b, d1)
                    if z0 > za + 0.01: nxt.append((m0, m1, za, z0))
                    if zb > z1 + 0.01: nxt.append((m0, m1, z1, zb))
                cuts = nxt
            for (a, b, za, zb) in cuts:
                member(C, "M_Concrete2", wpt(i, a, WALL_T / 2, (za + zb) / 2), wpt(i, b, WALL_T / 2, (za + zb) / 2), WALL_T, zb - za, "wall")
                if bite and zb > G2 + 6:      # rebar out of the broken tops
                    for r_ in range(3):
                        q = wpt(i, rnd.uniform(a, b), WALL_T / 2 + rnd.uniform(-0.3, 0.3), zb)
                        member(D, "M_Rust", q, q + Vector((rnd.uniform(-0.3, 0.3), rnd.uniform(-0.3, 0.3), rnd.uniform(0.4, 1.1))), 0.03, 0.03, "rebar")
        tops[i] = chunks
        # slot windows high up (outside and in), only where the wall still stands above them
        for k in range(max(1, int(L / 3.2))):
            t = L * (k + 0.5) / max(1, int(L / 3.2))
            if any(d0 - 0.6 < t < d1 + 0.6 for (d0, d1, _, _) in DOORS.get(i, ())): continue
            ctop = next(c[2] for c in chunks if c[0] <= t <= c[1])
            if ctop < G2 + 11.4: continue
            for off in (-0.03, WALL_T + 0.03):
                member(D, "M_Silhouette", wpt(i, t - 0.35, off, G2 + 9.9), wpt(i, t + 0.35, off, G2 + 9.9), 0.05, 1.5, "slot")
        # string courses (outside); the low one stops at the entrance
        for zc in (G2 + 4.4, G2 + 9.6):
            spans = [(0.0, L)]
            for (d0, d1, z0, z1) in DOORS.get(i, ()):
                if z0 - 0.2 < zc - G2 + G2 < z1 + 0.2:
                    spans = [(a, b) for (a, b) in [(s0, min(s1, d0)) for (s0, s1) in spans] + [(max(s0, d1), s1) for (s0, s1) in spans] if b - a > 0.3]
            for (a, b) in spans:
                if min(c[2] for c in chunks if c[1] > a and c[0] < b) > zc + 0.4:
                    member(D, "M_Concrete", wpt(i, a, -0.12, zc), wpt(i, b, -0.12, zc), 0.45, 0.35, "course")
        # a buttress halfway along the long walls
        tm = L / 2
        if L > 8.0 and not any(d0 - 1.5 < tm < d1 + 1.5 for (d0, d1, _, _) in DOORS.get(i, ())) and i != 6:
            member(C, "M_Concrete2", wpt(i, tm, 0.0, G2 + 3.4), wpt(i, tm, -1.5, G2 + 3.4), 1.3, 7.6, "buttress")
            member(C, "M_Concrete2", wpt(i, tm, 0.0, G2 + 8.2), wpt(i, tm, -0.8, G2 + 8.2), 1.1, 2.2, "buttress_top")
    for i in range(NBV):      # corner pilasters, a little taller than the walls they join
        h = max(max(c[2] for c in tops[i]), max(c[2] for c in tops[(i - 1) % NBV])) + 0.5
        n = (snrm(i - 1) + snrm(i)).normalized()
        c = bv(i) + n * 0.5
        oriented_box(C, "M_Concrete", Vector((c.x, c.y, (G2 - 0.6 + h) / 2)), math.degrees(math.atan2(n.y, n.x)), (2.0, 2.0, h - G2 + 0.6), "pilaster", 0.04)
    return tops

def hall_inside(C, D, R):
    """Floor, the gallery with its columns/rails, the two stairs, roof trusses, cover, lamps."""
    prism(C, "M_Concrete", BV, G2 - 0.6, G2 + 0.12, "hall_floor")
    for i in GAL:
        pts = [inset(i, WALL_T), inset(i + 1, WALL_T), inset(i + 1, 5.0), inset(i, 5.0)]
        prism(C, "M_Concrete", [(p.x, p.y) for p in pts], ZG - 0.4, ZG, "gallery")
        a, b = inset(i, 4.8), inset(i + 1, 4.8)
        member(C, "M_Steel", (a.x, a.y, ZG - 0.65), (b.x, b.y, ZG - 0.65), 0.3, 0.5, "gal_beam")
        rail(D, R, inset(i, 5.0), inset(i + 1, 5.0), ZG)
    for v in (9, 10, 0, 1, 2, 3):
        p = inset(v, 4.6)
        ibeam(C, (p.x, p.y, G2 + 0.12), (p.x, p.y, ZG - 0.4), h=0.4, w=0.36, name="gal_col")
    # stairs up to the gallery ends, along the walls (s3 and s8)
    d3, d8 = sdir(3).to_3d(), sdir(8).to_3d()
    topA = inset(3, 3.0).to_3d() - d3 * 0.5; botA = topA + d3 * 9.4
    topB = inset(9, 3.0).to_3d() + d8 * 0.5; botB = topB - d8 * 9.4
    stairs_out = []
    for (bot, top) in ((botA, topA), (botB, topB)):
        gflight(D, R, (bot.x, bot.y, G2 + 0.12), (top.x, top.y, ZG), width=2.0)
        stairs_out.append(((bot.x, bot.y, G2 + 0.12), (top.x, top.y, ZG)))
    # roof trusses: two still span the hall, a third has come down and leans on the north wall; purlins between
    ztr = G2 + 11.2
    for x in (8.0, 0.0):
        ys, yn = ys_at(x)
        truss(C, Vector((x, ys + 0.5, ztr)), Vector((x, yn - 0.5, ztr)), height=1.8, mat="M_Rust", panel=1.6, sz=0.18)
    ys, yn = ys_at(-8.0)
    # the third has torn loose at the south end and hangs from the north wall, well clear of the floor
    truss(D, Vector((-8.4, yn - 0.6, ztr - 0.4)), Vector((-7.2, 3.5, G2 + 7.5)), height=1.6, mat="M_Rust", panel=1.6, sz=0.18)
    member(D, "M_Cable", (-7.2, 3.5, G2 + 9.0), (0.0, 3.0, ztr), 0.04, 0.04, "truss_cable")
    for y in (-6.0, 0.0, 6.0):
        member(D, "M_Steel", (8.0, y, ztr + 1.8), (0.0, y, ztr + 1.8), 0.14, 0.2, "purlin")
    member(D, "M_Steel", (0.0, 3.0, ztr + 1.8), (-3.5, 3.4, ztr - 2.2), 0.14, 0.2, "purlin_hang")
    lamps = []
    for (x, y) in ((8.0, -3.5), (8.0, 4.0), (0.0, -5.0), (0.0, 5.5)):
        cyl(D, "M_Cable", (x, y, ztr), (x, y, ztr - 2.6), 0.03, 6, "lamp_chain")
        cyl(D, "M_Lamp", (x, y, ztr - 2.6), (x, y, ztr - 2.9), 0.35, 10, "lamp_shade", r2=0.1)
        lamps.append((x, y, ztr - 3.1))
    # the floor is left clear for the boss's rolling attack: one flat slab, nothing on it but the gallery columns and
    # the stair feet. The clutter lives up on the gallery instead (crates, the old transmitter cabinet, scrap).
    rnd = random.Random(22)
    for k, (i, f) in enumerate(((9, 0.3), (0, 0.22), (2, 0.35), (2, 0.5))):
        p = wpt(i, slen(i) * f, WALL_T + 0.9, ZG)
        crate(C, p.x, p.y, ZG, rnd.uniform(0.8, 1.05), rnd.uniform(-0.4, 0.4), k)
    p = wpt(1, slen(1) * 0.5, WALL_T + 0.8, ZG)
    ob = oriented_box(C, "M_Steel", Vector((p.x, p.y, ZG + 1.1)), math.degrees(math.atan2(sdir(1).y, sdir(1).x)), (2.6, 0.9, 2.2), "transmitter", 0.05)
    return dict(stairs=stairs_out, lamps=lamps)

def hall_gates(C, D):
    """Entrance shutter (BossGate) and exit shutter (ExitGate), each on guides on the inner face so they slide up."""
    out = {}
    for (name, i, d0, d1, z0, z1) in (("BossGate-col", 7, 2.0, 6.5, G2 + 0.12, G2 + 5.2), ("ExitGate-col", 0, 4.8, 7.2, ZG, ZG + 3.0)):
        off = WALL_T + 0.25
        for t in (d0 - 0.45, d1 + 0.45):
            p = wpt(i, t, off, 0)
            ibeam(C, (p.x, p.y, z0 - 0.1), (p.x, p.y, z1 + (z1 - z0) + 0.6), h=0.4, w=0.34, name="gate_guide")
        a = wpt(i, d0 - 0.45, off, z1 + (z1 - z0) + 0.6); b = wpt(i, d1 + 0.45, off, z1 + (z1 - z0) + 0.6)
        member(C, "M_Steel", a, b, 0.45, 0.6, "gate_head")
        member(D, "M_Hazard", a - Vector((0, 0, 0.42)), b - Vector((0, 0, 0.42)), 0.47, 0.18, "gate_stripe")
        tmp = "P10_TmpGate"; s5coll(tmp)
        h = z1 - z0 + 0.2
        c = wpt(i, (d0 + d1) / 2, off, z0)
        member(tmp, "M_RustSheet", wpt(i, d0 - 0.25, off, z0 + h / 2), wpt(i, d1 + 0.25, off, z0 + h / 2), 0.2, h, "shutter")
        for k in range(int(h / 1.0) + 1):
            zz = z0 + 0.35 + k * 1.0
            if zz > z0 + h - 0.2: break
            member(tmp, "M_Steel", wpt(i, d0 - 0.25, off + 0.14, zz), wpt(i, d1 + 0.25, off + 0.14, zz), 0.1, 0.18, "shutter_rib")
        member(tmp, "M_Hazard", wpt(i, d0 - 0.25, off - 0.12, z0 + 0.12), wpt(i, d1 + 0.25, off - 0.12, z0 + 0.12), 0.03, 0.2, "shutter_edge")
        for o in bpy.data.collections[tmp].objects: xf_obj(o, BXF)
        own_object(name, tmp, bw(c))
        out[name] = dict(bottom=tuple(round(v, 2) for v in bw(c)), lift=round(h + 0.3, 2))
    # the entrance from outside: a steel portal with hazard paint
    for t in (1.7, 6.8):
        p = wpt(7, t, -0.25, 0)
        ibeam(C, (p.x, p.y, G2 - 0.3), (p.x, p.y, G2 + 5.9), h=0.5, w=0.4, name="portal")
    member(C, "M_Steel", wpt(7, 1.4, -0.25, G2 + 5.75), wpt(7, 7.1, -0.25, G2 + 5.75), 0.5, 0.5, "portal_head")
    member(D, "M_Hazard", wpt(7, 1.4, -0.52, G2 + 5.75), wpt(7, 7.1, -0.52, G2 + 5.75), 0.04, 0.35, "portal_paint")
    # the exit: a landing outside the gallery door, on brackets, railed at the sides (the gantry meets its end)
    boxmm(C, "M_Grate", 16.0, 18.7, -1.7, 1.7, ZG - 0.1, ZG, "exit_landing", 0.0)
    for y in (-1.7, 1.7):
        member(C, "M_Steel", (16.0, y, ZG - 0.3), (18.7, y, ZG - 0.3), 0.14, 0.3, "exit_edge")
        member(D, "M_Steel", (16.0, y, ZG - 3.0), (18.6, y, ZG - 0.35), 0.14, 0.14, "exit_bracket")
        rail(D, "P10_TmpHallR", (16.0, y), (18.7, y), ZG)
    return out

def hall_annex(C, D):
    """The hidden room: a windowless concrete block on the outside of wall s6, entered only through the wall (the
    patched section = HiddenDoor). Seen from outside it is just a block with no door."""
    i = 6; z0 = G2
    zc = z0 + 1.7
    member(C, "M_Concrete2", wpt(i, 2.0, -2.0, z0 - 0.3), wpt(i, 6.4, -2.0, z0 - 0.3), 4.3, 0.84, "ax_floor")
    member(C, "M_Concrete2", wpt(i, 1.9, -2.05, z0 + 3.55), wpt(i, 6.5, -2.05, z0 + 3.55), 4.5, 0.5, "ax_roof")
    for t in (2.2, 6.2):
        member(C, "M_Concrete2", wpt(i, t, 0.0, zc), wpt(i, t, -4.2, zc), 0.4, 3.9, "ax_side")
    member(C, "M_Concrete2", wpt(i, 2.0, -4.0, zc), wpt(i, 6.4, -4.0, zc), 0.4, 3.9, "ax_back")
    member(D, "M_Rust", wpt(i, 3.6, -4.22, z0 + 2.6), wpt(i, 4.6, -4.22, z0 + 2.6), 0.04, 0.6, "ax_grille")
    cyl(C, "M_Steel", wpt(i, 5.4, -2.6, z0 + 3.8), wpt(i, 5.4, -2.6, z0 + 4.8), 0.22, 10, "ax_vent")
    # inside: radio consoles on the back wall, a plinth for the reward, a hanging lamp
    for k in range(3):
        t = 2.9 + k * 1.15
        member(C, "M_Steel", wpt(i, t, -3.75, z0 + 0.55), wpt(i, t, -3.0, z0 + 0.55), 1.0, 1.1, "ax_console")
        member(D, "M_Indicator", wpt(i, t, -3.02, z0 + 0.95), wpt(i, t, -2.99, z0 + 0.95), 0.7, 0.15, "ax_lamps")
    member(C, "M_Concrete", wpt(i, 4.15, -1.2, z0 + 0.5), wpt(i, 4.15, -2.0, z0 + 0.5), 0.8, 1.0, "ax_plinth")
    lamp = wpt(i, 4.15, -2.0, z0 + 2.7)
    cyl(D, "M_Cable", lamp + Vector((0, 0, 0.6)), lamp + Vector((0, 0, 0.2)), 0.02, 6, "ax_cord")
    cyl(D, "M_Lamp", lamp + Vector((0, 0, 0.2)), lamp, 0.22, 10, "ax_shade", r2=0.08)
    # the patched section of wall that plugs the doorway (its own object; Godot breaks / slides it)
    tmp = "P10_TmpDoor"; s5coll(tmp)
    c = wpt(i, 4.15, WALL_T / 2, z0 + 1.25)
    member(tmp, "M_Concrete", wpt(i, 3.25, WALL_T / 2, c.z), wpt(i, 5.05, WALL_T / 2, c.z), 0.9, 2.6, "patch")
    for k in range(3):     # a few cracks on the inner face: the hint
        a = wpt(i, 3.6 + k * 0.45, 0.97, z0 + 0.4 + k * 0.6)
        member(tmp, "M_Silhouette", a, a + Vector((0, 0, 0.7)) + sdir(i).to_3d() * 0.3, 0.02, 0.04, "crack")
    for o in bpy.data.collections[tmp].objects: xf_obj(o, BXF)
    own_object("HiddenDoor-col", tmp, bw(c))
    return dict(door=tuple(round(v, 2) for v in bw(c)), inside=tuple(round(v, 2) for v in bw(wpt(i, 4.15, -2.0, z0))),
                lamp=tuple(round(v, 2) for v in bw(lamp)))

def slab4(cat, mat, pts, th, name="slab4"):
    """A slab of thickness th under the quad pts (any slope; counter-clockwise from above)."""
    bm = bmesh.new()
    top = [bm.verts.new(p) for p in pts]; bot = [bm.verts.new(Vector(p) - Vector((0, 0, th))) for p in pts]
    bm.faces.new(top); bm.faces.new(list(reversed(bot)))
    for k in range(4):
        bm.faces.new((bot[k], bot[(k + 1) % 4], top[(k + 1) % 4], top[k]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return mk_obj(name, bm, mat, cat)

def _door_clear(i, t, z, pad=0.6):
    """True if (t, z) on segment i is clear of every doorway (with pad)."""
    return not any(d0 - pad < t < d1 + pad and z0 - pad < z < z1 + pad for (d0, d1, z0, z1) in DOORS.get(i, ()))

def run_along(D, i, off, z, mat, r, name, clamp_every=2.2, t0=0.3, t1=None):
    """A pipe on the inner face of segment i at height z, split round doorways, on clamps back to the wall."""
    t1 = slen(i) - 0.3 if t1 is None else t1
    spans = [(t0, t1)]
    for (d0, d1, z0, z1) in DOORS.get(i, ()):
        if z0 - r - 0.3 < z < z1 + r + 0.3:
            spans = [s for (a, b) in spans for s in ((a, min(b, d0 - 0.4)), (max(a, d1 + 0.4), b)) if s[1] - s[0] > 0.5]
    for (a, b) in spans:
        cyl(D, mat, wpt(i, a, off, z), wpt(i, b, off, z), r, 10, name)
        for k in range(int((b - a) / clamp_every) + 1):
            t = a + 0.3 + k * clamp_every
            if t > b - 0.2: break
            member(D, "M_Steel", wpt(i, t, WALL_T - 0.02, z), wpt(i, t, off + r + 0.04, z), 0.08, 0.16, name + "_clamp")

def hall_details(C, D):
    """Old radio station inside (pipes, cable trays, caged wall lamps, junction boxes, a waveguide from the mast, the
    control booth on the gallery, signage); weathered outside (rain streaks, downpipes, vents, a lean-to, a low scaffold,
    a dish on a pilaster aimed at the mast, rubble). Nothing new on the arena floor."""
    rnd = random.Random(23)
    lamps = []
    for i in range(NBV):
        L = slen(i); gal = i in GAL
        # pipes: two runs on the level-1 walls (above head height), one under the gallery
        if not gal:
            run_along(D, i, WALL_T + 0.22, G2 + 3.3, "M_PalePipe", 0.17, "pipe")
            run_along(D, i, WALL_T + 0.18, G2 + 3.75, "M_Rust", 0.11, "pipe2")
        else:
            run_along(D, i, WALL_T + 0.2, ZG - 1.3, "M_PalePipe", 0.15, "pipe")
        # cable tray high on every wall (ladder tray: two rails + rungs), cables sagging out of it now and then
        z = G2 + 9.2
        a, b = wpt(i, 0.4, WALL_T + 0.35, z), wpt(i, L - 0.4, WALL_T + 0.35, z)
        a2, b2 = wpt(i, 0.4, WALL_T + 0.05, z), wpt(i, L - 0.4, WALL_T + 0.05, z)
        member(D, "M_Steel", a, b, 0.05, 0.12, "tray"); member(D, "M_Steel", a2, b2, 0.05, 0.12, "tray")
        for k in range(int(L / 0.6)):
            t = 0.5 + k * 0.6
            if t > L - 0.4: break
            member(D, "M_Steel", wpt(i, t, WALL_T + 0.02, z - 0.05), wpt(i, t, WALL_T + 0.38, z - 0.05), 0.04, 0.03, "tray_rung")
        if rnd.random() < 0.6:
            t = rnd.uniform(1.0, L - 1.0)
            wires(D, [tuple(wpt(i, t - 0.8, WALL_T + 0.2, z - 0.1)), tuple(wpt(i, t + 0.8, WALL_T + 0.2, z - 0.1))], sag=18.0, n=10, r=0.03)
        # caged bulkhead lamps
        lz = (ZG + 2.4) if gal else (G2 + 4.6)
        t = L * 0.5
        if _door_clear(i, t, lz):
            p = wpt(i, t, WALL_T + 0.2, lz)
            member(D, "M_Steel", wpt(i, t, WALL_T - 0.03, lz), wpt(i, t, WALL_T + 0.24, lz), 0.36, 0.44, "lamp_back")
            cyl(D, "M_Lamp", wpt(i, t, WALL_T + 0.2, lz), wpt(i, t, WALL_T + 0.42, lz), 0.13, 8, "lamp_bulb")
            for s in (-0.1, 0.1):
                member(D, "M_Steel", wpt(i, t + s, WALL_T + 0.2, lz - 0.16), wpt(i, t + s, WALL_T + 0.45, lz + 0.16), 0.02, 0.02, "lamp_cage")
            lamps.append(tuple(wpt(i, t, WALL_T + 0.7, lz)))
        # junction boxes and breaker panels (on the walls, between head height and the pipes)
        for k in range(1 if L < 8 else 2):
            t = L * (0.25 + 0.5 * k) + rnd.uniform(-0.5, 0.5)
            zb_ = (ZG + 1.4) if gal else (G2 + 2.2)
            if not _door_clear(i, t, zb_, 0.9) or abs(t - L * 0.5) < 0.8: continue
            member(D, "M_Steel", wpt(i, t - 0.35, WALL_T + 0.15, zb_), wpt(i, t + 0.35, WALL_T + 0.15, zb_), 0.3, 0.9, "jbox")
            member(D, "M_Hazard", wpt(i, t - 0.36, WALL_T + 0.31, zb_ + 0.3), wpt(i, t + 0.36, WALL_T + 0.31, zb_ + 0.3), 0.02, 0.1, "jbox_tag")
            cyl(D, "M_Rust", wpt(i, t, WALL_T + 0.12, zb_ + 0.45), wpt(i, t, WALL_T + 0.12, G2 + 3.2 if not gal else ZG + 2.9), 0.04, 6, "conduit")
        # outside: rain streaks down from the (broken) top, a few rust runs
        for k in range(int(L * 0.9)):
            t = rnd.uniform(0.5, L - 0.5); l = rnd.uniform(1.5, 6.0); zt = G2 + rnd.uniform(9.5, 11.5)
            member(D, "M_Silhouette" if rnd.random() < 0.75 else "M_Rust", wpt(i, t - 0.04, -0.02, zt - l / 2), wpt(i, t + 0.04, -0.02, zt - l / 2), 0.02, l, "streak")
    # hazard stripe along the gallery edge
    for i in GAL:
        a, b = inset(i, 5.02), inset(i + 1, 5.02)
        member(D, "M_Hazard", (a.x, a.y, ZG - 0.2), (b.x, b.y, ZG - 0.2), 0.03, 0.22, "gal_stripe")
    # the waveguide: a rectangular duct in through the wall above the exit (from the mast) and along the gallery walls
    zw = ZG + 4.6
    member(C, "M_RustSheet", (17.3, 2.6, zw), (16.0 - WALL_T - 0.4, 2.6, zw), 0.6, 0.45, "waveguide")     # cables carry on to the mast
    for x in (16.15, 17.3):
        member(D, "M_Steel", (x + 0.12, 2.6, zw), (x - 0.12, 2.6, zw), 0.8, 0.65, "waveguide_flange")
    p1 = wpt(1, 0.0, WALL_T + 0.4, zw)
    member(C, "M_RustSheet", (16.0 - WALL_T - 0.4, 2.6, zw), (p1.x, p1.y, zw), 0.6, 0.45, "waveguide")
    member(C, "M_RustSheet", p1, wpt(1, slen(1) - 0.5, WALL_T + 0.4, zw), 0.6, 0.45, "waveguide")
    for t in (1.0, 3.5, 6.0):
        member(D, "M_Steel", wpt(1, t, WALL_T, zw), wpt(1, t, WALL_T + 0.75, zw), 0.1, 0.7, "wg_hanger")
    # the control booth on the gallery (segment 10): low wall + window frames + roof, open at the south end
    i = 10; L = slen(i); ta, tb = 1.4, L - 0.6; oa, ob = WALL_T, WALL_T + 2.2; zt = ZG + 2.8
    member(C, "M_Corrugated", wpt(i, ta, ob, ZG + 0.55), wpt(i, tb, ob, ZG + 0.55), 0.12, 1.1, "booth_front")
    member(C, "M_Corrugated", wpt(i, tb, oa, ZG + 1.4), wpt(i, tb, ob, ZG + 1.4), 0.12, 2.8, "booth_end")
    member(C, "M_Steel", wpt(i, ta - 0.1, oa, zt + 0.1), wpt(i, tb + 0.1, oa, zt + 0.1), 2.5, 0.2, "booth_roof")
    for k in range(5):
        t = ta + (tb - ta) * k / 4
        member(D, "M_Steel", wpt(i, t, ob, ZG + 1.1), wpt(i, t, ob, zt), 0.08, 0.08, "booth_mullion")
    member(D, "M_Steel", wpt(i, ta, ob, ZG + 1.1), wpt(i, tb, ob, ZG + 1.1), 0.1, 0.1, "booth_sill")
    member(C, "M_Steel", wpt(i, ta + 0.4, oa + 0.45, ZG + 0.45), wpt(i, tb - 0.4, oa + 0.45, ZG + 0.45), 0.8, 0.9, "booth_desk")
    for k in range(3):
        t = ta + 0.9 + k * 1.6
        member(D, "M_Indicator", wpt(i, t - 0.5, oa + 0.86, ZG + 0.75), wpt(i, t + 0.5, oa + 0.86, ZG + 0.75), 0.02, 0.12, "booth_lamps")
        member(D, "M_Steel", wpt(i, t - 0.4, oa + 0.15, ZG + 1.3), wpt(i, t + 0.4, oa + 0.15, ZG + 1.3), 0.3, 0.75, "booth_rack")
    lamps.append(tuple(wpt(i, (ta + tb) / 2, oa + 1.1, zt - 0.3)))
    # signage: faded panels high on the level-1 walls
    for (i, f) in ((4, 0.5), (5, 0.45), (8, 0.35)):
        t = slen(i) * f
        member(D, "M_PalePipe", wpt(i, t - 1.4, WALL_T + 0.03, G2 + 6.8), wpt(i, t + 1.4, WALL_T + 0.03, G2 + 6.8), 0.04, 1.3, "sign")
        member(D, "M_Hazard", wpt(i, t - 1.4, WALL_T + 0.06, G2 + 6.35), wpt(i, t + 1.4, WALL_T + 0.06, G2 + 6.35), 0.02, 0.3, "sign_band")
        member(D, "M_Silhouette", wpt(i, t - 1.0, WALL_T + 0.06, G2 + 7.05), wpt(i, t + 0.6, WALL_T + 0.06, G2 + 7.05), 0.02, 0.35, "sign_text")
    # ---- outside
    for v in (2, 5, 9):          # downpipes beside three pilasters
        n = (snrm(v - 1) + snrm(v)).normalized()
        p = bv(v) - n * 0.25 + sdir(v) * 1.25
        cyl(D, "M_Rust", (p.x, p.y, G2 - 0.2), (p.x, p.y, G2 + 10.5), 0.12, 8, "dpipe")
        for z in (G2 + 1.5, G2 + 4.5, G2 + 7.5, G2 + 10.0):
            cyl(D, "M_Steel", (p.x, p.y, z - 0.06), (p.x, p.y, z + 0.06), 0.17, 8, "dpipe_clamp")
    for (i, f) in ((1, 0.35), (4, 0.6), (8, 0.7)):     # louvred vents
        t = slen(i) * f
        member(C, "M_Steel", wpt(i, t - 0.6, -0.15, G2 + 6.0), wpt(i, t + 0.6, -0.15, G2 + 6.0), 0.3, 0.9, "vent")
        for k in range(4):
            member(D, "M_Silhouette", wpt(i, t - 0.5, -0.31, G2 + 5.7 + k * 0.2), wpt(i, t + 0.5, -0.31, G2 + 5.7 + k * 0.2), 0.02, 0.06, "louvre")
    # lean-to against the north wall (s3): posts, a sloping corrugated roof, junk under it
    i = 3; t0_, t1_ = 1.2, slen(i) - 1.2
    for t in (t0_, (t0_ + t1_) / 2, t1_):
        member(C, "M_Steel", wpt(i, t, -3.1, G2 - 0.2), wpt(i, t, -3.1, G2 + 2.6), 0.14, 0.14, "lean_post")
    slab4(C, "M_Corrugated", [wpt(i, t0_ - 0.2, -0.05, G2 + 3.6), wpt(i, t1_ + 0.2, -0.05, G2 + 3.6),
                              wpt(i, t1_ + 0.2, -3.5, G2 + 2.6), wpt(i, t0_ - 0.2, -3.5, G2 + 2.6)], 0.12, "lean_roof")
    for k, (t, o) in enumerate(((2.0, -1.2), (2.8, -1.4), (5.2, -1.0))):
        q = wpt(i, t, o, G2)
        (barrel if k < 2 else crate)(C, q.x, q.y, G2, *((k,) if k < 2 else (0.9, 0.3, 2)))
    # a low scaffold on the south wall (s9): two lifts only, so it never reaches the broken wall tops
    i = 9; L = slen(i)
    for t in (1.5, 3.5, 5.5, 7.5):
        for o in (-0.4, -1.6):
            member(C, "M_Steel", wpt(i, t, o, G2 - 0.2), wpt(i, t, o, G2 + 5.4), 0.07, 0.07, "scaff_pole")
    for z in (G2 + 2.2, G2 + 4.4):
        for o in (-0.4, -1.6):
            member(C, "M_Steel", wpt(i, 1.3, o, z), wpt(i, 7.7, o, z), 0.06, 0.06, "scaff_ledger")
        member(C, "M_Rust", wpt(i, 1.4, -1.0, z + 0.05), wpt(i, 7.6 if z < G2 + 3 else 4.4, -1.0, z + 0.05), 1.1, 0.06, "scaff_plank")
    member(D, "M_Rust", wpt(i, 4.6, -1.0, G2 + 4.45), wpt(i, 6.4, -1.4, G2 + 3.2), 1.0, 0.05, "scaff_plank_fallen")
    for t in (1.5, 5.5):
        member(D, "M_Steel", wpt(i, t, -1.6, G2), wpt(i, t + 2.0, -1.6, G2 + 4.4), 0.05, 0.05, "scaff_brace")
    # a dish on the north-east pilaster, aimed at the mast
    v = 1; n = (snrm(v - 1) + snrm(v)).normalized(); p = bv(v) + n * 0.5
    cyl(C, "M_Steel", (p.x, p.y, G2 + 12.0), (p.x, p.y, G2 + 14.2), 0.12, 8, "pil_dish_post")
    bmd = bmesh.new()
    bmesh.ops.create_cone(bmd, cap_ends=False, segments=20, radius1=0.12, radius2=1.3, depth=0.55)
    ob_ = mk_obj("pil_dish", bmd, "M_PalePipe", C); ob_.location = (p.x + 0.25, p.y, G2 + 14.3); ob_.rotation_euler = (0, math.radians(70), 0)
    # rubble round the outside base (clear of the entrance, the annex and the lean-to)
    n_ = 0
    while n_ < 40:
        i = rnd.randrange(NBV); t = rnd.uniform(0.3, slen(i) - 0.3)
        if i in (6, 7, 3) or (i == 9 and 1.0 < t < 8.0): continue
        q = wpt(i, t, -rnd.uniform(0.2, 1.8), G2)
        s = rnd.uniform(0.25, 0.8)
        rockblob(C, (q.x, q.y, G2 + s * 0.1), (s * 1.4, s, s * 0.6), amp=0.4, seed=1800 + n_, sub=1, mat="M_Concrete", name="rubble_out")
        n_ += 1
    return lamps

def build_hall(C, D, R):
    tC, tD, tR = "P10_TmpHallC", "P10_TmpHallD", "P10_TmpHallR"
    for c in (tC, tD, tR): s5coll(c)
    hall_walls(tC, tD)
    inside = hall_inside(tC, tD, tR)
    gates = hall_gates(tC, tD)
    annex = hall_annex(tC, tD)
    wall_lamps = hall_details(tC, tD)
    # floodlights on four pilaster tops, aimed into the hall
    floods = []
    for v in (1, 4, 7, 10):
        p = bv(v) + (snrm(v - 1) + snrm(v)).normalized() * 0.5
        hd = Vector((p.x, p.y, G2 + 13.0))
        aim = (Vector((0, 0, G2)) - hd).normalized()
        cyl(tD, "M_Lamp", hd, hd + aim * 0.4, 0.25, 10, "flood", r2=0.3)
        floods.append((hd + aim * 0.6, aim))
    move_all(tC, C, BXF); move_all(tD, D, BXF); move_all(tR, R, BXF)
    rot = BXF.to_3x3()
    return dict(stairs=[[tuple(round(v, 2) for v in bw(p)) for p in s] for s in inside["stairs"]],
                lamps=[tuple(round(v, 2) for v in bw(p)) for p in inside["lamps"]],
                wall_lamps=[tuple(round(v, 2) for v in bw(p)) for p in wall_lamps],
                floods=[(tuple(round(v, 2) for v in bw(p)), tuple(round(v, 3) for v in rot @ a)) for (p, a) in floods],
                gates=gates, annex=annex, centre=(round(BX, 2), round(BY, 2), G2),
                exit_landing=tuple(round(v, 2) for v in bw((18.7, 0.0, ZG))))

# ---------------------------------------------------------------- approach: broken arch, slab, trestles, girder
def arch_stub(C, a, b, zd0, zd1, depth0, depth1, seed, name):
    """Natural rock arch stub swept a -> b: walkable deck (zd0 -> zd1) on a body whose underside dives depth0 below
    the deck at a and depth1 at b (deep end = root in the cliff, shallow end = broken tip)."""
    a = Vector(a); b = Vector(b)
    fwd = (b - a).normalized(); side = Vector((-fwd.y, fwd.x, 0))
    L = (b - a).length; n = max(4, int(L / 0.9))
    bm = bmesh.new(); rings = []
    hw = 1.6
    for i in range(n + 1):
        t = i / n
        p = a.lerp(b, t)
        zd = zd0 + (zd1 - zd0) * t
        dep = depth0 + (depth1 - depth0) * smooth(0.0, 1.0, t)
        sec = []
        for l in (-1.0, -0.5, 0.0, 0.5, 1.0):
            sec.append((l * hw, zd + 0.04 * _pn(p.x * 0.7 + l, p.y * 0.7, seed)))
        sec += [(hw + 0.45, zd - 0.5), (hw + 0.9, zd - 1.5), (hw + 0.8, zd - dep * 0.5), (0.5 * hw + 0.3, zd - dep), (0.0, zd - dep - 0.4),
                (-0.5 * hw - 0.3, zd - dep), (-hw - 0.8, zd - dep * 0.5), (-hw - 0.9, zd - 1.5), (-hw - 0.45, zd - 0.5)]
        ring = []
        for j, (l, z) in enumerate(sec):
            q = p + side * l
            v = Vector((q.x, q.y, z))
            if j >= 5:          # rough the sides and underside only (the deck stays walkable)
                nz = _pn(v.x * 0.35 + seed, v.y * 0.35, v.z * 0.35)
                v += side * (math.copysign(1.0, l) if abs(l) > 0.01 else 0.0) * 0.9 * nz + Vector((0, 0, 0.6 * nz if j in (9, 10, 11) else 0.0))
            ring.append(bm.verts.new(v))
        rings.append(ring)
    K = len(rings[0])
    for i in range(n):
        for j in range(K):
            bm.faces.new((rings[i][j], rings[i][(j + 1) % K], rings[i + 1][(j + 1) % K], rings[i + 1][j]))
    bm.faces.new(list(reversed(rings[0]))); bm.faces.new(rings[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    for f in bm.faces:
        f.smooth = True
        f.material_index = 1 if f.normal.z > 0.85 else 0
    ob = mk_obj(name, bm, "M_MesaCliff", C); ob.data.materials.append(M("M_MesaGround"))
    return ob

def trestle(C, D, c, top, half0=1.5, half1=4.5, bottom=-40.0, u=Vector((1, 0, 0))):
    """An old four-legged steel trestle rising out of the haze, square to the bridge heading u."""
    legs = []
    u = Vector((u.x, u.y, 0)).normalized(); v = Vector((-u.y, u.x, 0))
    for (sx, sy) in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
        a = c.copy(); a.z = 0
        a = a + u * (sx * (half0 - 0.15)) + v * (sy * half0); a.z = top - 0.25          # top runs into the cap girders
        b = c.copy(); b.z = 0
        b = b + u * (sx * half1) + v * (sy * half1); b.z = bottom
        ibeam(C, b, a, h=0.42, w=0.36, mat="M_Rust", name="tr_leg"); legs.append((a, b))
    for z in [top - 0.5 - 6.0 * k for k in range(13) if top - 0.5 - 6.0 * k > bottom + 2]:
        t = (top - 0.4 - z) / (top - 0.4 - bottom)
        ring = [la.lerp(lb, t) for (la, lb) in legs]
        for k in range(4):
            member(C if z > top - 8 else D, "M_Rust", ring[k], ring[(k + 1) % 4], 0.18, 0.22, "tr_ring")
        t2 = min(1.0, t + 6.0 / (top - 0.4 - bottom))
        ring2 = [la.lerp(lb, t2) for (la, lb) in legs]
        for k in range(4):
            member(D, "M_Rust", ring[k], ring2[(k + 1) % 4], 0.1, 0.1, "tr_x")
            member(D, "M_Rust", ring[(k + 1) % 4], ring2[k], 0.1, 0.1, "tr_x")

def deck_piece(C, D, c, u, yaw, length, z_from, z_to, width=3.0, name="deck"):
    """Grating deck (tilted from z_from to z_to along u) with side girders."""
    side = Vector((-u.y, u.x, 0))
    mid = Vector((c.x, c.y, (z_from + z_to) / 2 - 0.06))
    ob = oriented_box(C, "M_Grate", mid, yaw, (length, width, 0.12), name, 0.0)
    ob.rotation_euler = (0, -math.atan2(z_to - z_from, length), math.radians(yaw))
    a = Vector((c.x, c.y, z_from)) - u * (length / 2); b = Vector((c.x, c.y, z_to)) + u * (length / 2)
    for s in (-1, 1):
        member(C, "M_Rust", a + side * (s * width / 2) - Vector((0, 0, 0.3)), b + side * (s * width / 2) - Vector((0, 0, 0.3)), 0.2, 0.45, name + "_girder")
    return a, b, side

def approach(C, W, D, R):
    """mesa rim -> plateau landing: ~55 m, six jumps (2.3 .. 2.6 m, each up 0.3 .. 0.6 m)."""
    u = Vector((PX - CENTER.x, PY - CENTER.y, 0)).normalized()
    th_u = math.atan2(u.y, u.x); yaw = math.degrees(th_u)
    rim = CENTER.to_3d() + u * rim_radius(th_u)
    s0 = Vector((rim.x - u.x * 4.0, rim.y - u.y * 4.0, 0))
    end = Vector((PX, PY, 0)) - u * (p_rim(ENTRY_TH) - 2.0)
    L = (end - s0).length
    z0 = ground_h(s0.x, s0.y) + 0.1
    P = lambda s, z=0.0: Vector((s0.x + u.x * s, s0.y + u.y * s, z))
    side = Vector((-u.y, u.x, 0))
    # layout along the line: (start, end) of each piece
    stub2_len = 9.0
    seq = [("slab", 2.2, 2.5), ("capA", 3.0, 2.6), ("span", 7.0, 0.0), ("capB", 3.0, 2.4), ("girder", 6.0, 2.3), ("stub2", stub2_len, 2.4)]
    s_stub1 = L - sum(l + g for (_, l, g) in seq)
    s = s_stub1; pos = {}
    for (k, l, g) in seq:
        s += g; pos[k] = (s, s + l); s += l
    zt = dict(stub1=z0 + 0.3, slab=z0 + 0.6, capA=z0 + 0.9, span_end=z0 + 0.6, capB=z0 + 1.2, girder0=z0 + 1.5, girder1=z0 + 2.0, stub2=z0 + 2.3)
    arch_stub(C, P(-6.0), P(s_stub1), z0 - 0.4, zt["stub1"], 34.0, 3.0, 3.0, "arch1")
    arch_stub(C, P(pos["stub2"][0]), P(L + 3.0), zt["stub2"], G2 + 0.03, 3.2, 30.0, 7.0, "arch2")
    rnd = random.Random(31)
    for (sx, z, sgn) in ((s_stub1, zt["stub1"], 1), (pos["stub2"][0], zt["stub2"], -1)):
        for k in range(4):        # jagged chunks under the breaks
            q = P(sx - sgn * rnd.uniform(0.2, 1.2)) + side * rnd.uniform(-1.4, 1.4)
            sz = rnd.uniform(0.6, 1.3)
            rockblob(C, (q.x, q.y, z - rnd.uniform(1.5, 3.5)), (sz, sz * 1.1, sz * 1.6), amp=0.5, seed=1200 + k + (10 if sgn < 0 else 0),
                     sub=2, mat="M_MesaCliff", name="break")
    # trestle A: cap deck + the sagging span of the old bridge (one side truss left, the other torn off)
    ca = P(sum(pos["capA"]) / 2, zt["capA"])
    trestle(W, D, ca, zt["capA"] - 0.12, u=u)
    deck_piece(W, D, ca, u, yaw, 3.0, zt["capA"], zt["capA"], name="capA")
    sp = P(sum(pos["span"]) / 2)
    a, b, _ = deck_piece(W, D, sp, u, yaw, 7.0, zt["capA"], zt["span_end"], width=2.6, name="span")
    truss(D, a + side * 1.3 - Vector((0, 0, 0.2)), b + side * 1.3 - Vector((0, 0, 0.2)), height=1.1, mat="M_Rust", panel=1.4, sz=0.1)
    member(D, "M_Rust", b - side * 1.3 - Vector((0, 0, 0.3)), b - side * 1.5 + u * 0.8 - Vector((0, 0, 3.8)), 0.2, 0.42, "span_torn")
    for k in range(4):
        q = b + side * rnd.uniform(-1.2, 1.2)
        member(D, "M_Rust", q - Vector((0, 0, 0.1)), q + u * rnd.uniform(0.2, 0.6) + Vector((0, 0, rnd.uniform(-0.8, 0.3))), 0.04, 0.04, "torn_bar")
    # the fallen slab, held on a bracket off trestle A
    sc = P(sum(pos["slab"]) / 2, zt["slab"] - 0.22)
    ob = oriented_box(W, "M_Concrete", sc, yaw, (2.2, 2.6, 0.44), "fallen_slab", 0.04)
    ob.rotation_euler = (math.radians(2.5), math.radians(-3.0), math.radians(yaw + 4))
    arm0 = ca - u * 1.5 - Vector((0, 0, 0.5))
    member(W, "M_Rust", arm0, sc - u * 0.6 - Vector((0, 0, 0.35)), 0.3, 0.3, "slab_arm")
    member(D, "M_Rust", arm0 - Vector((0, 0, 3.5)), sc - u * 0.3 - Vector((0, 0, 0.4)), 0.16, 0.16, "slab_strut")
    for k in range(5):
        q = sc + u * rnd.uniform(-1.0, 1.0) + side * rnd.choice((-1.3, 1.3))
        member(D, "M_Rust", q, q + Vector((rnd.uniform(-0.3, 0.3), rnd.uniform(-0.3, 0.3), rnd.uniform(-0.9, 0.5))), 0.03, 0.03, "rebar")
    # trestle B
    cb = P(sum(pos["capB"]) / 2, zt["capB"])
    trestle(W, D, cb, zt["capB"] - 0.12, bottom=-46.0, u=u)
    deck_piece(W, D, cb, u, yaw, 3.0, zt["capB"], zt["capB"], name="capB")
    railing(D, cb + side * 1.5 - u * 1.4, cb + side * 1.5 + u * 1.4, h=1.0, spacing=1.4, broken=0.6, seed=4)
    member(D, "M_Rust", cb + u * 1.5 + side * 1.0 - Vector((0, 0, 0.35)), cb + u * 2.4 + side * 1.2 - Vector((0, 0, 6.5)), 0.2, 0.42, "girder_hang")
    # the girder: rests on a slender lattice pylon at its far end, hangs off a cable at its near end
    g0 = P(pos["girder"][0], zt["girder0"]); g1 = P(pos["girder"][1], zt["girder1"])
    ibeam(W, g0 - Vector((0, 0, 0.35)), g1 - Vector((0, 0, 0.35)), h=0.7, w=0.75, mat="M_Rust", name="walkgirder")
    gp = g1 - u * 0.6
    lattice(D, D, gp.x, gp.y, -40.0, gp.z - 0.7 + 40.0, 1.4, 0.45, 77)
    member(W, "M_Rust", gp - side * 0.6 - Vector((0, 0, 0.75)), gp + side * 0.6 - Vector((0, 0, 0.75)), 0.3, 0.3, "pylon_cap")
    member(D, "M_Cable", g0 + Vector((0, 0, -0.1)), cb + u * 1.4 + Vector((0, 0, 3.5)), 0.035, 0.035, "girder_cable")
    member(D, "M_Rust", cb + u * 1.3 + side * 1.2, cb + u * 1.3 + side * 1.2 + Vector((0, 0, 3.6)), 0.14, 0.14, "cable_post")
    member(D, "M_Rust", P(pos["stub2"][0] + 0.8, zt["stub2"] - 0.5) - side * 1.1, P(pos["stub2"][0] - 2.2, zt["stub2"] - 2.4) - side * 1.6, 0.2, 0.42, "girder_bent")
    r2 = lambda v: round(v, 2)
    return dict(start=tuple(r2(v) for v in P(0, z0)), end=tuple(r2(v) for v in Vector((end.x, end.y, G2))), length=r2(L), dir=(round(u.x, 4), round(u.y, 4)),
                pieces={k: (r2(a_), r2(b_)) for k, (a_, b_) in dict(stub1=(0.0, s_stub1), **pos).items()}, heights={k: r2(v) for k, v in zt.items()})

# ---------------------------------------------------------------- the mast (built in its own frame, +X towards the peak)
W0, WN, ZN = 15.0, 3.6, 88.0         # leg half-spread at the foot, at the neck, and where the neck starts
CAB = dict(west=-9.5, east=7.0, half_y=7.2, ladder_y=4.6)    # cabin balcony (mast-local); the last ladder is on the east edge

def w_at(z):
    """Half-width of the leg square: the A-frame splay below ZN, the straight neck above."""
    return W0 + (WN - W0) * (min(z, ZN) - P10["foot"]) / (ZN - P10["foot"])

def R_at(z):
    return w_at(z) + 4.3

MAST_XF = Matrix.Translation((MX, MY, 0)) @ Matrix.Rotation(math.radians(MYAW), 4, 'Z')
def mw(p):
    return MAST_XF @ Vector(p)

FACES = dict(N=((1, 1), (-1, 0), (0, 1)), W=((-1, 1), (0, -1), (-1, 0)), S=((-1, -1), (1, 0), (0, -1)), E=((1, -1), (0, 1), (1, 0)))
NEXT = dict(N="W", W="S", S="E", E="N")
CORNER_AFTER = dict(N=(-1, 1), W=(-1, -1), S=(1, -1), E=(1, 1))     # corner at the end of each face

def fpos(face, t, z, off=0.0):
    """Point on the route square at height z: t metres along the face from its start corner, off = outwards."""
    (cx, cy), (dx, dy), (nx, ny) = FACES[face]
    R = R_at(z)
    return Vector((cx * R + dx * t + nx * off, cy * R + dy * t + ny * off, z))

ROUTE = dict(ladders=[], checkpoints=[], pieces=[])

def mast_levels():
    """Heights of the girder rings (the band ones sit under the band floors so they don't trip anyone)."""
    zb, zc = P10["foot"], P10["cabin"]
    return sorted(set([zb + 7.33 * k for k in range(1, 10) if all(abs(zb + 7.33 * k - b) > 2.5 for b in P10["bands"])] +
                      [b - 0.7 for b in P10["bands"]] + [96.0, 100.0, zc - 0.7]))

def face_point(p, face, z):
    """The point on the lattice face plane at height z, level with p along the face (kept between the legs), so that
    supports always end on a girder ring."""
    (_, _), (dx, dy), (nx, ny) = FACES[face]
    w = w_at(z)
    t = max(-w + 0.4, min(w - 0.4, p.x * dx + p.y * dy))
    return Vector((nx * w + dx * t, ny * w + dy * t, z))

def arm(D, p, face, z):
    """Support for a route piece: a horizontal arm back towards the lattice, and a diagonal strut from it down to the
    nearest girder ring below (so nothing hangs in the air)."""
    (_, _), (_, _), (nx, ny) = FACES[face]
    n = Vector((nx, ny, 0))
    q = Vector((p.x, p.y, z - 0.3))
    below = [l for l in mast_levels() if l < z - 1.0]
    zg = below[-1] if below else P10["foot"] + 0.5
    inner = face_point(q, face, z - 0.3)
    member(D, "M_Steel", q - n * 0.2, inner + n * 0.3, 0.14, 0.2, "arm")
    member(D, "M_Steel", q - n * 1.2, face_point(q, face, zg), 0.12, 0.12, "strut")

def hangers(D, c, face, z, along, half=0.7):
    """Two cables from a hanging platform's ends up to the girder ring above."""
    above = [l for l in mast_levels() if l > z + 1.5]
    if not above: return
    for s in (-half, half):
        q = c + along * s
        member(D, "M_Cable", (q.x, q.y, z - 0.05), face_point(q, face, above[0]), 0.04, 0.04, "hanger")

def plat(C, D, c, sx, sy, z, name="plat", rails=(), mat="M_Grate"):
    boxmm(C, mat, c.x - sx / 2, c.x + sx / 2, c.y - sy / 2, c.y + sy / 2, z - 0.1, z, name, 0.0)
    for (a, b) in (((-1, -1), (1, -1)), ((1, -1), (1, 1)), ((1, 1), (-1, 1)), ((-1, 1), (-1, -1))):
        member(C, "M_Steel", (c.x + a[0] * sx / 2, c.y + a[1] * sy / 2, z - 0.22), (c.x + b[0] * sx / 2, c.y + b[1] * sy / 2, z - 0.22), 0.12, 0.24, "plat_edge")
    for (a, b, broken) in rails:
        railing(D, (c.x + a[0] * sx / 2, c.y + a[1] * sy / 2, z), (c.x + b[0] * sx / 2, c.y + b[1] * sy / 2, z), h=1.0, spacing=1.2, broken=broken, seed=int(z * 7))

def corner_plat(C, D, corner, z, grow=(0.0, 0.0)):
    """Landing on a route corner. grow = extra size outwards along x / y (for ladder feet)."""
    R = R_at(z); cx, cy = corner
    c = Vector((cx * (R + grow[0] / 2), cy * (R + grow[1] / 2), z))
    plat(C, D, c, 2.6 + grow[0], 2.6 + grow[1], z, "corner")
    member(D, "M_Steel", Vector((c.x, c.y, z - 0.3)), Vector((cx * w_at(z), cy * w_at(z), z - 0.3)), 0.16, 0.22, "corner_arm")
    member(D, "M_Steel", Vector((c.x, c.y, z - 0.3)), Vector((cx * w_at(z - 3), cy * w_at(z - 3), z - 3.0)), 0.12, 0.12, "corner_strut")
    ROUTE["pieces"].append(("corner", tuple(round(v, 2) for v in c)))
    return c

def face_ends(face, z0, z1):
    """Route line along a face, from the edge of the start corner landing (at z0) to the edge of the end one (at z1)."""
    return fpos(face, 1.3, z0), fpos(face, 2 * R_at(z1) - 1.3, z1)

OUTER = (-1,)    # stair_guards side: travelling counter-clockwise, the right-hand side is the outside

def mv_stair(C, D, R, face, z0, rise, broken=False):
    lo, hi = face_ends(face, z0, z0 + rise)
    if not broken:
        stairs(D, lo, hi, width=2.0, rampcat=R)
        stair_guards(R, lo, hi, 2.0, sides=OUTER)
        pieces = [(lo, hi)]
    else:           # a 2 m bite out of the middle: jump it
        d = hi - lo
        m0 = lo + d * 0.5 - d.normalized() * 1.0; m1 = lo + d * 0.5 + d.normalized() * 1.0
        stairs(D, lo, m0, width=2.0, rampcat=R); stairs(D, m1, hi, width=2.0, rampcat=R)
        stair_guards(R, lo, m0, 2.0, sides=OUTER); stair_guards(R, m1, hi, 2.0, sides=OUTER)
        pieces = [(lo, m0), (m1, hi)]
        member(D, "M_Steel", m0 - Vector((0, 0, 0.2)), m0 + d.normalized() * 0.6 - Vector((0, 0, 0.9)), 0.08, 0.35, "torn_stringer")
    for (a, b) in pieces:
        for t in (0.15, 0.85):
            arm(D, a.lerp(b, t), face, a.lerp(b, t).z)
    ROUTE["pieces"].append(("stair" if not broken else "broken_stair", tuple(round(v, 2) for v in lo), tuple(round(v, 2) for v in hi)))
    return z0 + rise

def mv_hops(C, D, face, z0, rise, target_gap=2.6):
    """Hanging platforms evenly spaced along the face, each a little higher; the last jump lands on the end corner."""
    lo, hi = face_ends(face, z0, z0 + rise)
    d = Vector((hi.x - lo.x, hi.y - lo.y, 0)); span = d.length; d.normalize()
    plen = 1.8
    n = max(1, math.ceil((span - target_gap) / (plen + target_gap)))      # gaps never wider than target_gap
    gap = (span - n * plen) / (n + 1)
    (_, _), (dx, dy), _ = FACES[face]
    for k in range(n):
        z = z0 + rise * (k + 1) / (n + 1)
        c = lo + d * (gap * (k + 1) + plen * k + plen / 2); c = Vector((c.x, c.y, z))
        sx, sy = (plen, 2.0) if dx else (2.0, plen)
        plat(C, D, c, sx, sy, z, "hop")
        arm(D, c, face, z)
        hangers(D, c, face, z, d)
        ROUTE["pieces"].append(("hop", tuple(round(v, 2) for v in c), round(gap, 2)))
    return z0 + rise

def mv_beam(C, D, face, z0, rise=0.0, width=0.8):
    """A bare girder from corner to corner (inclined when rise > 0): walk the top flange."""
    a, b = face_ends(face, z0, z0 + rise)
    ibeam(C, a - Vector((0, 0, 0.35)), b - Vector((0, 0, 0.35)), h=0.7, w=width, mat="M_Rust", name="walkbeam")
    for t in (0.25, 0.5, 0.75):
        p = a.lerp(b, t); arm(D, p, face, p.z - 0.4)
    ROUTE["pieces"].append(("beam", tuple(round(v, 2) for v in a), tuple(round(v, 2) for v in b)))
    return z0 + rise

def mv_ladder(C, D, R, face_in, z0, h):
    """Ladder at the corner where face_in ends. The upper landing is the normal corner; the lower one is grown outwards
    along the next face's normal so the climber stands outside the ladder, facing in, and steps forward at the top."""
    corner = CORNER_AFTER[face_in]
    nxt = NEXT[face_in]
    (nx, ny) = FACES[nxt][2]
    corner_plat(C, D, corner, z0, (2.2 if nx else 0.0, 2.2 if ny else 0.0))
    up = corner_plat(C, D, corner, z0 + h)
    nrm = Vector((nx, ny, 0))
    along = Vector((FACES[nxt][1][0], FACES[nxt][1][1], 0))
    base = Vector((up.x + nx * 1.3, up.y + ny * 1.3, z0)) + along * 0.3      # under the upper landing's outer edge
    # backing plate (ladder_back) hanging from the upper landing's edge to the lower landing
    plate_c = base - nrm * 0.05
    sx, sy = (0.1, 0.9) if nx else (0.9, 0.1)
    boxmm(C, "M_Steel", plate_c.x - sx / 2, plate_c.x + sx / 2, plate_c.y - sy / 2, plate_c.y + sy / 2, z0, z0 + h - 0.1, "ladder_back", 0.0)
    rung = base + nrm * 0.12
    ladder_vis(D, rung.x, rung.y, z0, z0 + h + 1.0, 'y' if nx else 'x', w=0.55)
    ROUTE["ladders"].append(dict(bottom=tuple(round(v, 2) for v in rung), top=round(z0 + h + 0.05, 2), normal=(nx, ny)))
    return z0 + h

def band(C, D, R, z, corners, name, side_gaps=()):
    """A platform level round the tower: full grate floor (the legs pass through it), deep box fascia, railing + guard
    round the edge except at the route corners (list of (cx, cy)) and side_gaps (list of (side, from, to) in metres
    from the side's centre)."""
    w = w_at(z); o = w + 2.8
    boxmm(C, "M_Grate", -o, o, -o, o, z - 0.1, z, name, 0.0)
    for (a, b) in (((-o, -o), (o, -o)), ((o, -o), (o, o)), ((o, o), (-o, o)), ((-o, o), (-o, -o))):
        member(C, "M_RustSheet", (a[0], a[1], z - 0.45), (b[0], b[1], z - 0.45), 0.25, 0.8, "fascia")
    for (cx, cy) in ((1, 1), (-1, 1), (-1, -1), (1, -1)):
        member(D, "M_Steel", (cx * w, cy * w, z - 4.0), (cx * o, cy * o, z - 0.85), 0.2, 0.2, "band_strut")
    # rails: walk each side, leaving 3.2 m openings at route corners
    for side, (a, b) in dict(S=((-o, -o), (o, -o)), E=((o, -o), (o, o)), N=((o, o), (-o, o)), W=((-o, o), (-o, -o))).items():
        cuts = []
        for (cx, cy) in corners:
            for end, q in ((0, a), (1, b)):
                if (math.copysign(1, q[0]) == cx) and (math.copysign(1, q[1]) == cy):
                    cuts.append((0.0, 3.2) if end == 0 else (2 * o - 3.2, 2 * o))
        for g in side_gaps:
            if g[0] == side:
                cuts.append((g[1] + o, g[2] + o))
        segs = []; cur = 0.0
        for (c0, c1) in sorted(cuts):
            if c0 > cur + 0.05: segs.append((cur, c0))
            cur = max(cur, c1)
        if 2 * o > cur + 0.05: segs.append((cur, 2 * o))
        A = Vector((a[0], a[1], z)); B = Vector((b[0], b[1], z)); d = (B - A).normalized()
        for (s0, s1) in segs:
            rail(D, R, A + d * s0, A + d * s1, z)
    # checkpoint: on the corner landing where the next stage leaves, facing along it (not mid-band: the core pipes)
    cx, cy = corners[0]
    face = next(f for f, v in FACES.items() if v[0] == (cx, cy))
    ROUTE["checkpoints"].append(((cx * R_at(z), cy * R_at(z), z), FACES[face][1]))

def mast_frame(C, D):
    """Four big tube legs splayed like an A-frame, two fat core pipes up the middle, the big crossed tubes on the
    north and south faces (the X in the reference), girder rings and lighter X bracing between them."""
    zb = P10["foot"]; zc = P10["cabin"]
    lp = lambda cx, cy, z: Vector((cx * w_at(z), cy * w_at(z), z))
    for (cx, cy) in ((1, 1), (-1, 1), (-1, -1), (1, -1)):
        cyl(C, "M_Steel", lp(cx, cy, zb - 0.8), lp(cx, cy, ZN), 0.85, 14, "leg")
        cyl(C, "M_Steel", lp(cx, cy, ZN), lp(cx, cy, zc - 0.2), 0.7, 14, "leg_top")
        p = lp(cx, cy, zb)
        boxmm(C, "M_Concrete", p.x - 2.0, p.x + 2.0, p.y - 2.0, p.y + 2.0, zb - 1.5, zb + 1.2, "footing", 0.06)
        for z in range(int(zb) + 6, int(zc), 10):        # flange collars on the legs
            q = lp(cx, cy, z)
            cyl(D, "M_Rust", q - Vector((0, 0, 0.2)), q + Vector((0, 0, 0.2)), 1.02 if z < ZN else 0.86, 14, "collar")
    for sy in (-1, 1):       # the central pipes (the two inner columns of the reference)
        cyl(C, "M_Rust", (0.0, sy * 1.6, zb - 0.8), (0.0, sy * 1.6, zc - 0.2), 1.0, 16, "core")
        for z in range(int(zb) + 4, int(zc), 8):
            cyl(D, "M_Steel", (0.0, sy * 1.6, z - 0.15), (0.0, sy * 1.6, z + 0.15), 1.12, 16, "core_band")
    for sy in (-1, 1):       # the crossed tubes
        cyl(C, "M_Steel", lp(-1, sy, zb + 1.0), lp(1, sy, 70.0), 0.55, 12, "x_tube")
        cyl(C, "M_Steel", lp(1, sy, zb + 1.0), lp(-1, sy, 70.0), 0.55, 12, "x_tube")
    levels = mast_levels()
    prev = zb + 0.5
    for z in levels:
        w = w_at(z)
        ring = [(w, w), (-w, w), (-w, -w), (w, -w)]
        for k in range(4):
            a, b = ring[k], ring[(k + 1) % 4]
            member(C, "M_Steel", (a[0], a[1], z), (b[0], b[1], z), 0.4, 0.6, "girder")
            member(D, "M_Steel", (a[0], a[1], z), (0.0, math.copysign(1.6, a[1]), z), 0.2, 0.26, "tie")
        wp = w_at(prev)
        ringp = [(wp, wp), (-wp, wp), (-wp, -wp), (wp, -wp)]
        for k in range(4):           # X bracing on the east/west faces (north/south carry the big X)
            if k in (0, 2) and z < 70: continue
            a, b = ring[k], ring[(k + 1) % 4]; ap, bp = ringp[k], ringp[(k + 1) % 4]
            member(D, "M_Steel", (ap[0], ap[1], prev), (b[0], b[1], z), 0.22, 0.22, "brace")
            member(D, "M_Steel", (bp[0], bp[1], prev), (a[0], a[1], z), 0.22, 0.22, "brace")
        prev = z

def cabin(C, D, R):
    """The radio cabin on top of the neck (the end of the climb): balcony, enterable room with a door on the east side,
    a closed upper storey, the long boom, a lattice antenna and the spike."""
    z = P10["cabin"]
    bxw, bx, by = CAB["west"], CAB["east"], CAB["half_y"]
    boxmm(C, "M_Grate", bxw, bx, -by, by, z - 0.12, z, "balcony", 0.0)
    for (a, b) in (((bxw, -by), (bx, -by)), ((bx, -by), (bx, by)), ((bx, by), (bxw, by)), ((bxw, by), (bxw, -by))):
        member(C, "M_RustSheet", (a[0], a[1], z - 0.7), (b[0], b[1], z - 0.7), 0.3, 1.2, "bal_fascia")
    for (cx, cy) in ((1, 1), (-1, 1), (-1, -1), (1, -1)):
        member(D, "M_Steel", (cx * WN, cy * WN, z - 7.0), ((bx if cx > 0 else bxw) - cx * 0.3, cy * (by - 0.3), z - 1.3), 0.32, 0.32, "bal_strut")
    # railing + guard round the balcony, open where the last ladder arrives (east side)
    lad_y = CAB["ladder_y"]
    rail(D, R, (bx, -by), (bx, lad_y - 0.7), z)
    rail(D, R, (bx, by), (bxw, by), z); rail(D, R, (bxw, by), (bxw, -by), z); rail(D, R, (bxw, -by), (bx, -by), z)
    rail(D, R, (bx, lad_y + 0.7), (bx, by), z)
    # the room: walls with a door on +X, windows all round
    x0, x1, y0, y1, h = -8.0, 5.6, -5.8, 5.8, 5.0
    t = 0.22
    boxmm(C, "M_Corrugated", x0, x1, y0, y0 + t, z, z + h, "cab_wall", 0.02)
    boxmm(C, "M_Corrugated", x0, x1, y1 - t, y1, z, z + h, "cab_wall", 0.02)
    boxmm(C, "M_Corrugated", x0, x0 + t, y0, y1, z, z + h, "cab_wall", 0.02)
    boxmm(C, "M_Corrugated", x1 - t, x1, y0, -0.8, z, z + h, "cab_wall", 0.02)
    boxmm(C, "M_Corrugated", x1 - t, x1, 0.8, y1, z, z + h, "cab_wall", 0.02)
    boxmm(C, "M_Corrugated", x1 - t, x1, -0.8, 0.8, z + 2.4, z + h, "cab_wall", 0.02)
    boxmm(C, "M_Steel", x0 - 0.15, x1 + 0.15, y0 - 0.15, y1 + 0.15, z + h, z + h + 0.3, "cab_roof", 0.02)
    boxmm(C, "M_Steel", x0, x1, y0, y1, z, z + 0.06, "cab_floor", 0.0)
    boxmm(D, "M_Hazard", x1, x1 + 0.05, -0.95, 0.95, z + 2.4, z + 2.6, "cab_door_head", 0.0)
    windows(D, 'x', y0, x0 + 0.6, x1 - 0.6, z + 2.4, z + 3.6, 5, 1, w=1.3, h=0.8, seed=101, face=-1, skip=0.0)
    windows(D, 'x', y1, x0 + 0.6, x1 - 0.6, z + 2.4, z + 3.6, 5, 1, w=1.3, h=0.8, seed=102, face=1, skip=0.0)
    windows(D, 'y', x0, y0 + 0.6, y1 - 0.6, z + 2.4, z + 3.6, 4, 1, w=1.3, h=0.8, seed=103, face=-1, skip=0.0)
    for k in range(5):       # inside: radio benches along the north wall, a map table
        boxmm(C, "M_Steel", x0 + 0.6 + k * 2.5, x0 + 2.6 + k * 2.5, y1 - 1.0, y1 - t, z, z + 0.95, "bench", 0.03)
        boxmm(D, "M_Indicator", x0 + 0.8 + k * 2.5, x0 + 2.4 + k * 2.5, y1 - 1.02, y1 - 1.0, z + 0.6, z + 0.8, "bench_lamps", 0.0)
        boxmm(C, "M_Steel", x0 + 0.7 + k * 2.5, x0 + 2.5 + k * 2.5, y1 - 0.6, y1 - t, z + 0.95, z + 2.2, "rack", 0.03)
    boxmm(C, "M_Rust", -2.5, 0.5, -3.4, -1.6, z + 0.85, z + 0.92, "map_table", 0.01)
    for (a, b) in ((-2.4, -3.3), (0.4, -3.3), (-2.4, -1.7), (0.4, -1.7)):
        member(C, "M_Steel", (a, b, z), (a, b, z + 0.85), 0.06, 0.06, "table_leg")
    cyl(D, "M_Cable", (-1.0, 0, z + h), (-1.0, 0, z + h - 0.8), 0.02, 6, "cab_cord")
    cyl(D, "M_Lamp", (-1.0, 0, z + h - 0.8), (-1.0, 0, z + h - 1.05), 0.3, 10, "cab_shade", r2=0.08)
    # upper storeys (closed): a block, a smaller block on it set back, a little deck on the west end
    zu = z + h + 0.3
    boxmm(C, "M_RustSheet", -6.2, 3.8, -4.4, 4.4, zu, zu + 3.6, "cab_upper", 0.03)
    windows(D, 'x', -4.4, -5.6, 3.2, zu + 1.6, zu + 2.6, 5, 1, w=1.0, h=0.6, seed=104, face=-1, skip=0.0)
    windows(D, 'x', 4.4, -5.6, 3.2, zu + 1.6, zu + 2.6, 5, 1, w=1.0, h=0.6, seed=105, face=1, skip=0.0)
    for zz in (zu + 0.9, zu + 3.0):
        member(D, "M_Hazard", (-6.25, -4.45, zz), (3.85, -4.45, zz), 0.04, 0.12, "cab_trim")
    boxmm(C, "M_Steel", -6.5, 4.1, -4.7, 4.7, zu + 3.6, zu + 3.95, "cab_upper_roof", 0.02)
    zr = zu + 3.95
    boxmm(C, "M_Corrugated", -3.0, 2.2, -2.8, 2.6, zr, zr + 2.6, "cab_top", 0.03)
    boxmm(C, "M_Steel", -3.2, 2.4, -3.0, 2.8, zr + 2.6, zr + 2.85, "cab_top_roof", 0.02)
    railing(D, (-6.5, -4.7, zr), (-6.5, 4.7, zr), h=1.0, spacing=1.3, broken=0.2, seed=9)
    # the long boom across the top (the horizontal tube of the reference), on saddles, with a stay up to the antenna
    cyl(C, "M_PalePipe", (-17.0, 3.4, zr + 0.85), (6.0, 3.4, zr + 0.85), 0.85, 16, "boom")
    cyl(C, "M_Steel", (-17.0, 3.4, zr + 0.85), (-17.5, 3.4, zr + 0.85), 0.96, 16, "boom_cap")
    for x in (-5.5, 0.5, 4.5):
        boxmm(C, "M_Steel", x - 0.35, x + 0.35, 2.6, 4.2, zr, zr + 0.45, "boom_saddle", 0.02)
    railing(D, (-17.0, 2.3, zr + 0.4), (-6.5, 2.3, zr + 0.4), h=0.9, spacing=1.4, broken=0.3, seed=10)
    boxmm(C, "M_Steel", 2.6, 4.0, -3.6, -1.6, zr, zr + 1.4, "winch", 0.04)
    cyl(C, "M_Rust", (3.3, -3.7, zr + 0.85), (3.3, -1.5, zr + 0.85), 0.5, 12, "winch_drum")
    # lattice antenna on the top block; a cap plate carries the spike, the cross arms clamp onto the spike
    ax, ay = -0.4, -0.1
    zl, lh, lw0, lw1 = zr + 2.85, 30.0, 1.5, 0.4
    lattice(C, D, ax, ay, zl, lh, lw0, lw1, 131)
    ladder_vis(D, ax + 1.15, ay - 1.3, zl, zl + lh - 1.0, 'x', w=0.45)
    ws = lw0 + (lw1 - lw0) * 12.0 / lh            # the boom's stay ties onto a lattice leg 12 m up
    member(D, "M_Cable", (-16.4, 3.4, zr + 1.7), (ax - ws, ay + ws, zl + 12.0), 0.05, 0.05, "boom_stay")
    top = zl + lh
    boxmm(C, "M_Steel", ax - lw1 - 0.15, ax + lw1 + 0.15, ay - lw1 - 0.15, ay + lw1 + 0.15, top - 0.1, top + 0.25, "spike_cap", 0.02)
    top += 0.25
    cyl(C, "M_Steel", (ax, ay, top), (ax, ay, P10["tip"]), 0.16, 8, "spike", r2=0.05)
    for (zz, half) in ((top + 2.0, 2.6), (top + 6.0, 1.6), (top + 11.0, 1.0)):
        member(D, "M_Steel", (ax - half, ay, zz), (ax + half, ay, zz), 0.1, 0.1, "xarm")
        for s in (-1, 1):
            cyl(D, "M_PalePipe", (ax + s * half, ay, zz), (ax + s * half, ay, zz - 0.8), 0.07, 6, "dipole")
    lamps = [(ax, ay, P10["tip"] + 0.2), (ax, ay, top - 0.2), (0.0, 0.0, z + h - 1.0)]
    cyl(D, "M_Lamp", (ax, ay, P10["tip"]), (ax, ay, P10["tip"] + 0.35), 0.16, 8, "beacon")
    cyl(D, "M_Lamp", (ax + 0.4, ay, top - 0.3), (ax + 0.4, ay, top), 0.13, 8, "beacon2")
    return dict(door=(x1 + 0.3, 0.0, z), lamps=lamps, ladder_y=lad_y)

def mast_route(C, D, R):
    """Square spiral round the outside of the lattice (counter-clockwise seen from above). Each stage leaves a band at
    one corner and arrives at the next band's corner."""
    b1, b2, b3, b4 = P10["bands"]
    # stage 1: band 1 (NE) -> band 2 (SE)
    z = b1
    corner_plat(C, D, (1, 1), z)
    z = mv_stair(C, D, R, "N", z, 5.0)
    z = mv_ladder(C, D, R, "N", z, 5.0)
    z = mv_hops(C, D, "W", z, 1.2)
    corner_plat(C, D, (-1, -1), z)
    z = mv_stair(C, D, R, "S", z, b2 - z, broken=True)
    corner_plat(C, D, (1, -1), z)
    # stage 2: band 2 (SE) -> band 3 (SW)
    z = mv_hops(C, D, "E", z, 1.0)
    corner_plat(C, D, (1, 1), z)
    z = mv_beam(C, D, "N", z, 3.0)
    z = mv_ladder(C, D, R, "N", z, 5.0)
    z = mv_stair(C, D, R, "W", z, b3 - z)
    corner_plat(C, D, (-1, -1), z)
    # stage 3: band 3 (SW) -> band 4 (NW)
    z = mv_hops(C, D, "S", z, 1.0)
    z = mv_ladder(C, D, R, "S", z, 5.0)
    z = mv_stair(C, D, R, "E", z, 4.0, broken=True)
    corner_plat(C, D, (1, 1), z)
    z = mv_stair(C, D, R, "N", z, b4 - z)
    corner_plat(C, D, (-1, 1), z)
    # stage 4: band 4 (NW) -> cabin
    z = mv_stair(C, D, R, "W", z, 4.0, broken=True)
    z = mv_ladder(C, D, R, "W", z, 4.0)
    z = mv_hops(C, D, "S", z, 0.6)
    corner_plat(C, D, (1, -1), z)
    z = mv_stair(C, D, R, "E", z, 2.4)
    # last landing on the east face under the balcony edge, ladder up onto the balcony
    zc = P10["cabin"]
    Rz = R_at(z)
    ex, ly = CAB["east"], CAB["ladder_y"]
    plat(C, D, Vector((max(Rz - 0.2, ex + 1.2), ly + 1.6, z)), 2.4, 5.6, z, "last_landing")
    member(D, "M_Steel", (Rz - 0.2, ly, z - 0.3), (WN, ly, z - 0.3), 0.16, 0.22, "arm")
    boxmm(C, "M_Steel", ex, ex + 0.1, ly - 0.45, ly + 0.45, z, zc - 0.1, "ladder_back", 0.0)
    ladder_vis(D, ex + 0.22, ly, z, zc + 1.0, 'y', w=0.55)
    ROUTE["ladders"].append(dict(bottom=(ex + 0.22, ly, round(z, 2)), top=round(zc + 0.05, 2), normal=(1, 0)))
    return z

def build_mast(C, D, R):
    """Mast parts are built round the origin (+X = towards the peak) in temp collections, then moved into place."""
    tC, tD, tR = "P10_TmpMastC", "P10_TmpMastD", "P10_TmpMastR"
    for c in (tC, tD, tR): s5coll(c)
    ROUTE["ladders"].clear(); ROUTE["checkpoints"].clear(); ROUTE["pieces"].clear()
    mast_frame(tC, tD)
    b1, b2, b3, b4 = P10["bands"]
    o1 = w_at(b1) + 2.8
    band(tC, tD, tR, b1, [(1, 1)], "band1", side_gaps=[("E", -1.6, 1.6)])
    band(tC, tD, tR, b2, [(1, -1)], "band2")
    band(tC, tD, tR, b3, [(-1, -1)], "band3")
    band(tC, tD, tR, b4, [(-1, 1)], "band4")
    top = mast_route(tC, tD, tR)
    cab = cabin(tC, tD, tR)
    # equipment on the bands: cabinets, cable drums, a dish on band 3
    for (z, x, y) in ((b1, -6.0, -9.5), (b2, 7.0, 5.0), (b3, -5.0, 5.5), (b4, 4.5, -4.8)):
        boxmm(tC, "M_Steel", x - 0.6, x + 0.6, y - 0.4, y + 0.4, z, z + 1.7, "cabinet", 0.03)
        cyl(tC, "M_Rust", (x + 1.1, y - 0.6, z + 0.55), (x + 1.1, y + 0.6, z + 0.55), 0.55, 12, "drum")
    bmd = bmesh.new()
    bmesh.ops.create_cone(bmd, cap_ends=False, segments=20, radius1=0.12, radius2=1.4, depth=0.6)
    ob = mk_obj("dish", bmd, "M_PalePipe", tC); ob.location = (6.2, -6.2, b3 + 2.2); ob.rotation_euler = (math.radians(75), 0, math.radians(-40))
    cyl(tC, "M_Steel", (6.0, -6.0, b3), (6.0, -6.0, b3 + 1.8), 0.12, 8, "dish_post")
    # the foot: equipment shack between the legs, cable trough
    zb = P10["foot"]
    boxmm(tC, "M_Concrete3", -5.5, 0.5, 2.0, 7.0, zb - 0.5, zb + 3.6, "shack", 0.05)
    boxmm(tC, "M_RustSheet", -5.8, 0.8, 1.7, 7.3, zb + 3.6, zb + 3.9, "shack_roof", 0.03)
    boxmm(tD, "M_Silhouette", 0.5, 0.53, 3.8, 5.0, zb, zb + 2.2, "shack_door", 0.0)
    for c in (tC, tD, tR):
        for o in bpy.data.collections[c].objects:
            xf_obj(o, MAST_XF)
    for src, dst in ((tC, C), (tD, D), (tR, R)):
        for o in list(bpy.data.collections[src].objects):
            bpy.data.collections[src].objects.unlink(o); bpy.data.collections[dst].objects.link(o)
        bpy.data.collections.remove(bpy.data.collections[src])
    # guy wires from the neck down to the foot rock and across to the peak's crown
    for (lx, ly, lz, gx, gy, gz) in ((3.2, -3.2, 98.0, 20.0, -18.0, 20.0), (-3.2, 3.2, 98.0, -20.0, 17.0, 18.0), (-3.2, -3.2, 80.0, -19.0, -19.0, 19.0)):
        wires(D, [tuple(mw((lx, ly, lz))), tuple(mw((gx, gy, gz)))], sag=1.5)
    wires(D, [tuple(mw((WN, WN, 96.0))), tuple(bw((bv(1).x, bv(1).y, G2 + 13.0)))], sag=2.0)     # down to the hall's NE pilaster
    zl = 55.0                    # the waveguide's cables: from the duct end over the hall exit to the nearest leg
    for dy in (-0.15, 0.15):
        # (the mast frame is turned 180 deg from the hall's, so hall +Y is mast -Y: the near leg is (+w, -w))
        wires(D, [tuple(bw((17.3, 2.6 + dy, ZG + 4.6))), tuple(mw((w_at(zl), -w_at(zl) + dy, zl)))], sag=1.6)
    rot3 = MAST_XF.to_3x3()
    return dict(cabin_door=tuple(round(v, 2) for v in mw(cab["door"])),
                lamps=[tuple(round(v, 2) for v in mw(p)) for p in cab["lamps"]],
                ladders=[dict(bottom=tuple(round(v, 2) for v in mw(l["bottom"])), top=l["top"],
                              normal=tuple(round(v, 4) for v in (MAST_XF.to_3x3() @ Vector((l["normal"][0], l["normal"][1], 0)))[:2]))
                         for l in ROUTE["ladders"]],
                checkpoints=[dict(pos=tuple(round(v, 2) for v in mw(p)), dir=tuple(round(v, 4) for v in (rot3 @ Vector((d[0], d[1], 0)))[:2]))
                             for (p, d) in ROUTE["checkpoints"] + [((CAB["east"] - 0.6, CAB["ladder_y"], P10["cabin"]), (0, -1))]],
                cabin=dict(centre=tuple(round(v, 2) for v in mw((-1.2, 0.0, P10["cabin"]))), yaw_dir=tuple(round(v, 4) for v in (rot3 @ Vector((1, 0, 0)))[:2]),
                           door_inside=tuple(round(v, 2) for v in mw((3.7, 0.0, P10["cabin"])))),
                route=list(ROUTE["pieces"]), band1_e=tuple(round(v, 2) for v in mw((o1, 0, b1))))

def gantry(C, D, R):
    """Hall exit landing (gallery level) -> band 1's east face: a truss bridge."""
    ZL = ZG
    a = bw((18.7, 0.0, ZG))
    b = mw((w_at(ZL) + 2.8 - 0.05, 0.0, ZL))
    d = (b - a); fwd = Vector((d.x, d.y, 0)).normalized(); side = Vector((-fwd.y, fwd.x, 0))
    yaw = math.degrees(math.atan2(fwd.y, fwd.x))
    L = Vector((d.x, d.y, 0)).length
    oriented_box(C, "M_Grate", (a + b) / 2 - Vector((0, 0, 0.05)), yaw, (L, 2.4, 0.1), "gantry_deck", 0.0)
    for s in (-1, 1):
        p0 = a + side * (s * 1.25) - Vector((0, 0, 1.6)); p1 = b + side * (s * 1.25) - Vector((0, 0, 1.6))
        truss(D, p0, p1, height=1.5, mat="M_Steel", panel=1.6, sz=0.14)
        guard(R, (a + side * (s * 1.25)).to_2d(), (b + side * (s * 1.25)).to_2d(), ZL)
        railing(D, a + side * (s * 1.25), b + side * (s * 1.25), h=1.1, spacing=1.6)
    for k in range(int(L / 1.6) + 1):
        p = a + fwd * (1.6 * k)
        member(C, "M_Steel", p - side * 1.3 - Vector((0, 0, 0.2)), p + side * 1.3 - Vector((0, 0, 0.2)), 0.12, 0.22, "gantry_x")
    return dict(a=tuple(round(v, 2) for v in a), b=tuple(round(v, 2) for v in b))

def mast_foot(C):
    """The mast stands on a rock spur leaning off the plateau's flank: a stack, buttressed by big lumps on the plateau
    side and broken up round its top so it doesn't read as a cylinder."""
    zf = P10["foot"]
    rock_stack(C, MX, MY, zf, 22.0, 93)
    rnd = random.Random(94)
    to_p = Vector((PX - MX, PY - MY, 0)).normalized()
    for k in range(7):          # a ridge of rock joining the spur to the plateau cliff
        t = (k + 0.5) / 7
        c = Vector((MX, MY, 0)).lerp(Vector((PX, PY, 0)) - to_p * 30.0, t) + Vector((-to_p.y, to_p.x, 0)) * rnd.uniform(-5, 5)
        s = rnd.uniform(7.0, 11.0)
        rockblob(C, (c.x, c.y, zf - 6.0 - rnd.uniform(0, 8)), (s * 1.3, s, s * 1.6), amp=0.5, seed=1700 + k, sub=3, mat="M_MesaCliff", name="spur")
    for k in range(12):         # lumps round the top edge (kept clear of the four footings)
        a = 2 * math.pi * (k + rnd.uniform(-0.3, 0.3)) / 12
        if min(abs(angd(math.degrees(a) - MYAW, q)) for q in (45, 135, 225, 315)) < 14: continue
        r = 21.0 + rnd.uniform(-1.0, 2.0); s = rnd.uniform(2.5, 5.0)
        rockblob(C, (MX + r * math.cos(a), MY + r * math.sin(a), zf - rnd.uniform(1.0, 3.5)), (s * 1.3, s, s * 1.2), amp=0.5,
                 seed=1720 + k, sub=2, mat="M_MesaCliff", name="spur_lump")
    for k in range(6):          # and a few falling away down its sides
        a = rnd.uniform(0, 2 * math.pi); z = zf - rnd.uniform(10, 45); r = 24.0 + (zf - z) * 0.07
        s = rnd.uniform(3.0, 6.0)
        rockblob(C, (MX + r * math.cos(a), MY + r * math.sin(a), z), (s, s * 1.2, s * 1.8), amp=0.5, seed=1740 + k, sub=2, mat="M_MesaCliff", name="spur_rib")

# ---------------------------------------------------------------- debug: parts that touch nothing (floating)
def floaters(colls, eps=0.08):
    """Before merging: every part that isn't connected (by contact, through other parts) to the ground. Contact =
    a vertex or edge midpoint of one part inside the other's (local) box, grown by eps. Ground = below the plateau,
    mesa or foot-rock surface, deep in the haze (z < 0), or touching a rock object."""
    rock_names = ("arch", "boulder", "break", "spur", "stack", "crown", "outcrop")
    parts = []
    for c in colls:
        for o in bpy.data.collections[c].objects:
            if o.type != 'MESH' or o.name.startswith("plateau"): continue
            rot = o.rotation_quaternion if o.rotation_mode == 'QUATERNION' else o.rotation_euler.to_quaternion()
            mb = Matrix.LocRotScale(o.location, rot, o.scale)
            me = o.data
            if not me.vertices: continue
            lo = Vector([min(v.co[i] for v in me.vertices) for i in range(3)]) - Vector((eps,) * 3)
            hi = Vector([max(v.co[i] for v in me.vertices) for i in range(3)]) + Vector((eps,) * 3)
            pts = [mb @ v.co for v in me.vertices] + [mb @ ((me.vertices[e.vertices[0]].co + me.vertices[e.vertices[1]].co) / 2) for e in me.edges]
            if len(pts) > 400: pts = pts[::max(1, len(pts) // 400)]
            wmn = Vector([min(p[i] for p in pts) for i in range(3)]); wmx = Vector([max(p[i] for p in pts) for i in range(3)])
            parts.append(dict(o=o, inv=mb.inverted(), lo=lo, hi=hi, pts=pts, mn=wmn, mx=wmx, rock=o.name.startswith(rock_names)))
    def inside(q, p):
        l = p["inv"] @ q
        return all(p["lo"][i] <= l[i] <= p["hi"][i] for i in range(3))
    def grounded(p):
        if p["rock"]: return True
        for q in p["pts"]:
            if q.z < 0.0: return True
            if math.hypot(q.x - MX, q.y - MY) < 21.0 and q.z <= P10["foot"] + 0.15: return True
            if math.hypot(q.x - PX, q.y - PY) < p_rim(math.degrees(math.atan2(q.y - PY, q.x - PX))) - 0.5 and q.z <= p_ground(q.x, q.y) + 0.12: return True
            th = math.atan2(q.y - CENTER.y, q.x - CENTER.x)
            if math.hypot(q.x - CENTER.x, q.y - CENTER.y) < rim_radius(th) - 0.5 and q.z <= ground_h(q.x, q.y) + 0.12: return True
        return False
    cell = 6.0
    grid = {}
    for k, p in enumerate(parts):
        for gx in range(int(math.floor(p["mn"].x / cell)), int(math.floor(p["mx"].x / cell)) + 1):
            for gy in range(int(math.floor(p["mn"].y / cell)), int(math.floor(p["mx"].y / cell)) + 1):
                for gz in range(int(math.floor(p["mn"].z / cell)), int(math.floor(p["mx"].z / cell)) + 1):
                    grid.setdefault((gx, gy, gz), []).append(k)
    nb = [set() for _ in parts]
    for ks in grid.values():
        for a in ks:
            pa = parts[a]
            for b in ks:
                if b <= a or b in nb[a]: continue
                pb = parts[b]
                if any(pa["mn"][i] > pb["mx"][i] + eps or pb["mn"][i] > pa["mx"][i] + eps for i in range(3)): continue
                if any(inside(q, pb) for q in pa["pts"]) or any(inside(q, pa) for q in pb["pts"]):
                    nb[a].add(b); nb[b].add(a)
    seen = set(k for k, p in enumerate(parts) if grounded(p))
    stack = list(seen)
    while stack:
        a = stack.pop()
        for b in nb[a]:
            if b not in seen:
                seen.add(b); stack.append(b)
    return [(parts[k]["o"].name, tuple(round(v, 1) for v in (parts[k]["mn"] + parts[k]["mx"]) / 2)) for k in range(len(parts)) if k not in seen]

# ---------------------------------------------------------------- terrain mask (same layers as the mesa shader)
def paint_peak_mask(ob):
    me = ob.data
    if "TerrainMask" in me.color_attributes:
        me.color_attributes.remove(me.color_attributes["TerrainMask"])
    attr = me.color_attributes.new("TerrainMask", 'FLOAT_COLOR', 'POINT')
    for v in me.vertices:
        x, y, z = v.co
        na = noise.fractal(Vector((x * 0.045, y * 0.045, 21.0)), 0.5, 2.0, 3, noise_basis='PERLIN_ORIGINAL')
        nb = noise.fractal(Vector((x * 0.03, y * 0.03, 33.0)), 0.5, 2.0, 3, noise_basis='PERLIN_ORIGINAL')
        nc = noise.fractal(Vector((x * 0.022, y * 0.022, 47.0)), 0.5, 2.0, 3, noise_basis='PERLIN_ORIGINAL')
        walk = 1.0 - p_flat(x, y) if abs(z - G2) < 0.4 else 0.0          # trodden pads round the hall + the path
        gravel = min(1.0, 0.7 * walk + 0.4 * smooth(0.2, 0.45, na))
        dirt = smooth(0.0, 0.3, nb) * (1.0 - 0.6 * gravel)
        moss = smooth(0.08, 0.4, nc) * 0.5
        strata = smooth(-0.25, 0.25, math.sin(z * 0.23 + nb * 3.0))
        attr.data[v.index].color = (gravel, moss, dirt, strata)
    me.color_attributes.active_color = attr

# ---------------------------------------------------------------- build + export
def build_all(check_floaters=False):
    C, W, D, R = "P10_RockC", "P10_WorksC", "P10_DetailC", "P10_RampsC"
    for c in (C, W, D, R): s5coll(c)
    for n in ("BossGate-col", "ExitGate-col", "HiddenDoor-col"):
        if n in bpy.data.objects: bpy.data.objects.remove(bpy.data.objects[n], do_unlink=True)
    plateau(C)
    mast_foot(C)
    scenery = plateau_dressing(C, W, D)
    app = approach(C, W, D, R)
    hall = build_hall(W, D, R)
    gan = gantry(W, D, R)
    for c in ("P10_MastC", "P10_MastD", "P10_MastR"): s5coll(c)
    mast = build_mast("P10_MastC", "P10_MastD", "P10_MastR")
    if check_floaters:
        fl = floaters([C, W, D, "P10_MastC", "P10_MastD"])
        print("floating parts:", len(fl))
        for f in fl: print("  ", f)
    ob = merge_into("Peak-col", C)
    for p in ob.data.polygons:      # boulders too: flat-shaded icospheres read as low-poly (as on the mesa)
        p.use_smooth = True
    paint_peak_mask(ob)
    merge_into("PeakWorks-col", W)
    merge_into("PeakDetail", D)
    rr = merge_into("PeakRamps-colonly", R, uv=False); rr.data.materials.clear()
    merge_into("Mast-col", "P10_MastC")
    merge_into("MastDetail", "P10_MastD")
    mr = merge_into("MastRamps-colonly", "P10_MastR", uv=False); mr.data.materials.clear()
    near = [(round(s[0], 1), round(s[1], 1), round(s[2], 1)) for s in spire_layout()
            if min(math.hypot(s[0] - PX, s[1] - PY) - p_rim(0) - s[3], math.hypot(s[0] - MX, s[1] - MY) - 20 - s[3]) < 15.0]
    if near: print("WARNING spires crowd the peak/mast:", near)
    layout = dict(P10=P10, approach=app, hall=hall, scenery=scenery, gantry=gan, mast=mast, spires_too_close=near)
    with open(os.path.join(PROJ, "art_src", "peak.json"), "w") as f:
        json.dump(layout, f, indent=1)
    print("peak built:", [(o.name, len(o.data.vertices)) for o in S5.objects if o.type == 'MESH' and not o.name.startswith("S5_")])
    return layout

EXPORT = ["Peak-col", "PeakWorks-col", "PeakDetail", "PeakRamps-colonly", "Mast-col", "MastDetail", "MastRamps-colonly",
          "BossGate-col", "ExitGate-col", "HiddenDoor-col"]

def export_all():
    sc = bpy.data.scenes["Peak10"]
    for o in sc.objects:
        o.select_set(o.name in EXPORT)
    bpy.ops.export_scene.gltf(filepath=os.path.join(PROJ, "assets", "level", "peak.glb"), export_format='GLB', use_selection=True,
                              use_active_scene=True, export_apply=True, export_yup=True,
                              export_vertex_color='NAME', export_vertex_color_name='TerrainMask')
    print("exported peak.glb")
