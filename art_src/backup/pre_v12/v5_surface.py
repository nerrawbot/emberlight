
# v5/v6: the surface - a dark-blue mesa under cream haze (after the reference painting: industrial ruins on a
# plateau, tall misty spires behind). Built in its own Blender scene "Surface5", exported to assets/level/surface.glb.
# Shares main.tscn's coordinate frame around the lift headframe (Lift3-col is reused as-is) and the stair-3 gate,
# so arriving by lift or by the stairs lines up with the cavern below.
#
# Route (Blender coords, Z up; ground G = 34.3):
#   lift landing (24, -3) -> east across the plateau -> stair 1 up to the gallery deck Z40 (X 50..62, Y 9..24)
#   -> link deck south along bunker A -> K-braced tower, stair 2 up to Z46 -> gantry catwalk south (X 57..59)
#   -> block C roof Z46 (X 54..67, Y -38..-27), the old lookout over the cove
#   v6: -> bridge 1 south over the cove -> the pinnacle deck Z46 (rock stack, hut, jib crane)
#   -> bridge 2 east -> silo landing Z46 (cantilevered over the cliff) -> flight A north up the silo's west face (Z52)
#   -> flight B east along its north face -> silo roof Z56: the end of the line (for now).
#   Stair 3 pit (X 34.3..46.2, Y 0.68..5.72) leads back down to the cavern (scene change a few steps down).
#
# v6 also: mesa radius ~96 m with a rugged, terraced top (ridges + outcrops; the route and building pads stay flat),
# scattered ruins (frame ruin, water tower, pump house, tower block, pylons, power lines), more detail on the works,
# and every walkable edge guarded through rail()/guard()/gflight() (1.8 m invisible boxes: the jump apex is ~1.4 m).
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
    # v6: past the old lookout
    bridge1=(64.6, 66.4, -55.5, -38.0, 46.0),
    pinnacle=(68.0, -60.0, 45.6),                        # rock stack in the cove: centre + top
    pin_deck=(63.5, 72.5, -64.5, -55.5, 46.0),
    bridge2=(72.5, 86.0, -59.0, -57.0, 46.0),
    silo_deck=(86.0, 98.0, -60.0, -50.0, 46.0),          # cantilevered over the cliff
    silo=(90.0, 98.0, -50.0, -38.0, 56.0),               # core footprint + roof
    flightA=((89.0, -50.0, 46.0), (89.0, -38.0, 52.0)),
    landA=(88.0, 90.0, -38.0, -36.0, 52.0),
    flightB=((90.0, -37.0, 52.0), (96.0, -37.0, 56.0)),
    landB=(96.0, 98.0, -38.0, -36.0, 56.0),
    lookout=(94.0, -46.0, 56.0),                         # end banner on the silo roof
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
    # v6: more variety on the buildings (art_src/v6_textures.py grades these from Poly Haven)
    pbr_mat("M_Concrete2", "concrete2_albedo.jpg", "concrete2_orm.jpg", "concrete2_normal.jpg", 1.0)     # precast panels, cool grey
    pbr_mat("M_Concrete3", "concrete3_albedo.jpg", "concrete3_orm.jpg", "concrete3_normal.jpg", 0.8)     # pale painted concrete
    pbr_mat("M_RustSheet", "rustsheet_albedo.jpg", "rustsheet_orm.jpg", "rustsheet_normal.jpg", 1.0)     # blue-grey paint, rust
    flat_mat("M_Grass", (0.42, 0.56, 0.16), rough=0.8, double=True)
    flat_mat("M_GrassDry", (0.55, 0.52, 0.22), rough=0.85, double=True)
    flat_mat("M_PalePipe", (0.52, 0.5, 0.56), rough=0.55, metal=0.2)
    flat_mat("M_Spire", (0.12, 0.13, 0.2), rough=0.95)
    # (flat_mat keeps an existing material: push the tuned values every build)
    for n, col in (("M_Grass", (0.5, 0.7, 0.16)), ("M_GrassDry", (0.66, 0.62, 0.24)), ("M_PalePipe", (0.4, 0.39, 0.42)),
                   ("M_Spire", (0.2, 0.2, 0.23))):
        b = next(x for x in M(n).node_tree.nodes if x.type == 'BSDF_PRINCIPLED')
        b.inputs["Base Color"].default_value = (*col, 1); M(n).diffuse_color = (*col, 1)

# ---------------------------------------------------------------- guarded edges (hitboxes)
GUARD_H = 1.8       # invisible wall height above the walking surface: taller than the jump apex (~1.4 m)

def guard(R, a, b, z, h=GUARD_H, t=0.2):
    """Invisible collision box along a walkable edge a -> b (x, y) standing on height z."""
    member(R, None, (a[0], a[1], z + h / 2 - 0.1), (b[0], b[1], z + h / 2 - 0.1), t, h, "guard")

def rail(D, R, a, b, z, h=1.1, spacing=1.6, broken=0.0, seed=0):
    """Visible railing + its guard box. Use this for every railing the player can reach."""
    railing(D, (a[0], a[1], z), (b[0], b[1], z), h=h, spacing=spacing, broken=broken, seed=seed)
    guard(R, a, b, z)

def stair_guards(R, lo, hi, width, sides=(-1, 1)):
    lo = Vector(lo); hi = Vector(hi)
    d = hi - lo; fwd = Vector((d.x, d.y, 0)).normalized(); side = Vector((-fwd.y, fwd.x, 0))
    for s in sides:
        o = side * (s * (width / 2 + 0.06)) + Vector((0, 0, 0.8))
        member(R, None, lo + o, hi + o, 0.2, GUARD_H, "guard")

def gflight(D, R, lo, hi, width=2.0, sides=(-1, 1)):
    """Stairs (visual treads + collision ramp) with guard boxes along the open sides."""
    stairs(D, lo, hi, width=width, rampcat=R)
    stair_guards(R, lo, hi, width, sides)

# ---------------------------------------------------------------- terrain helpers
def smooth(a, b, t):
    t = min(1.0, max(0.0, (t - a) / (b - a)))
    return t * t * (3 - 2 * t)

def rim_radius(th):
    """Mesa outline (distance from CENTER). A deep cove in the south-east puts the cliff right below block C."""
    n = noise.fractal(Vector((math.cos(th) * 1.3, math.sin(th) * 1.3, 4.2)), 0.6, 2.0, 3, noise_basis='PERLIN_ORIGINAL')
    r = 96.0 + 13.0 * n
    a = math.atan2(math.sin(th + 0.95), math.cos(th + 0.95))       # centred on -54 deg
    return r - 41.0 * math.exp(-(a / 0.34) ** 2)

# flat pads: (x0, x1, y0, y1, falloff). The route, the works and every building sit on one; ridges rise between them.
FLAT = [(8, 30, -12, 6, 18), (30, 50, -3, 10, 18), (40, 76, -42, 28, 18),       # landing, stair well, the works
        (78, 104, -56, -30, 12),                                                 # silo
        (-46, -22, -4, 16, 10), (2, 14, 44, 56, 8), (85, 101, 12, 26, 10),       # frame ruin, water tower, pump house
        (-25, -15, 31, 41, 8), (-12, -4, -50, -42, 6), (102, 110, -32, -24, 6)]  # tower block, pylons

def flat_mask(x, y):
    m = 1.0
    for (x0, x1, y0, y1, fall) in FLAT:
        dx = max(x0 - x, 0, x - x1); dy = max(y0 - y, 0, y - y1)
        m = min(m, smooth(0.0, fall, math.hypot(dx, dy)))
    return m

def ridge(x, y):
    """Ridged noise, ~0..1 with sharp crests near 1."""
    s = 0.0; a = 1.0; f = 0.014; tot = 0.0
    for o in range(4):
        v = 1.0 - abs(noise.noise(Vector((x * f + o * 13.1, y * f - o * 7.7, 2.3 + o * 1.9)), noise_basis='PERLIN_ORIGINAL'))
        s += v * v * a; tot += a; a *= 0.5; f *= 2.05
    return s / tot

def ground_h(x, y, rr=None):
    """Height of the plateau top. rr = r / rim radius (0 centre .. 1 rim)."""
    if rr is None:
        rr = math.hypot(x - CENTER.x, y - CENTER.y) / rim_radius(math.atan2(y - CENTER.y, x - CENTER.x))
    m = flat_mask(x, y)
    n = noise.fractal(Vector((x * 0.035, y * 0.035, 1.7)), 0.55, 2.0, 4, noise_basis='PERLIN_ORIGINAL')
    small = noise.fractal(Vector((x * 0.16, y * 0.16, 7.3)), 0.5, 2.0, 2, noise_basis='PERLIN_ORIGINAL')
    out = smooth(0.1, 0.6, rr)
    mtn = 28.0 * min(1.0, max(0.0, (ridge(x, y) - 0.55) / 0.4)) ** 1.4 * (0.25 + 0.75 * out)
    t = max(0.0, 2.2 * n + 0.6) + mtn
    k = t / 2.6; fl = math.floor(k)
    t += ((fl + smooth(0.3, 0.7, k - fl)) * 2.6 - t) * 0.6      # strata terraces
    h = G + 0.25 * small * (0.3 + m) + t * m
    lip = max(0.0, rr - 0.88) / 0.12          # rocky lip rising at the rim
    h += lip * lip * 2.5 * (0.6 + 0.8 * max(0.0, n + 0.3)) * m
    return h

def slope(x, y):
    return math.hypot(ground_h(x + 0.8, y) - ground_h(x - 0.8, y), ground_h(x, y + 0.8) - ground_h(x, y - 0.8)) / 1.6

# ---------------------------------------------------------------- the plateau + cliffs
def mesa():
    C = "S5_MesaC"; s5coll(C)
    bm = bmesh.new()
    N = 256
    fr = [0.0] + [1.0 - (1.0 - i / 44.0) ** 1.25 for i in range(1, 45)]
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
        if f.material_index == 0 and f.normal.z < 0.8:       # steep ridge flanks show bare cliff rock
            f.material_index = 1
    me = bpy.data.meshes.new("plateau"); bm.to_mesh(me); bm.free()
    me.materials.append(M("M_MesaGround")); me.materials.append(M("M_MesaCliff"))
    ob = bpy.data.objects.new("plateau", me); bpy.data.collections[C].objects.link(ob)
    # holes: lift shaft and the stair-3 well
    lx0, lx1, ly0, ly1 = L5["lift"]
    carve_box(ob, (lx0 + 0.02, ly0 + 0.02, G - 3.0), (lx1 - 0.02, ly1 - 0.02, G + 3.0), pad=3.0)
    px0, px1, py0, py1 = L5["pit"]
    carve_box(ob, (px0, py0, G - 3.0), (px1, py1, G + 3.0), pad=3.0)
    # outcrops along the rim, crags on the ridge crests and a few boulders (none on the route)
    rnd = random.Random(5)
    for i in range(70):
        k = rnd.randrange(N); th = 2 * math.pi * k / N
        r = rims[k] * rnd.uniform(0.9, 0.99)
        x = CENTER.x + r * math.cos(th); y = CENTER.y + r * math.sin(th)
        if flat_mask(x, y) < 0.6: continue
        s = rnd.uniform(1.6, 4.6)
        rockblob(C, (x, y, ground_h(x, y) + s * 0.2), (s * rnd.uniform(0.8, 1.6), s * rnd.uniform(0.8, 1.4), s * rnd.uniform(0.6, 1.3)),
                 amp=0.45, seed=200 + i, sub=2, mat="M_MesaCliff", name="outcrop")
    n_crag = 0
    for i in range(900):
        if n_crag >= 75: break
        th = rnd.uniform(0, 2 * math.pi); r = rim_radius(th) * math.sqrt(rnd.uniform(0.05, 0.85))
        x = CENTER.x + r * math.cos(th); y = CENTER.y + r * math.sin(th)
        h = ground_h(x, y)
        if flat_mask(x, y) < 0.9 or h < G + 6.0 or ridge(x, y) < 0.72: continue
        s = rnd.uniform(1.5, 3.8)
        rockblob(C, (x, y, h + s * 0.15), (s * rnd.uniform(0.7, 1.2), s * rnd.uniform(0.7, 1.2), s * rnd.uniform(1.0, 1.9)),
                 amp=0.5, seed=600 + i, sub=2, mat="M_MesaCliff", name="crag")
        n_crag += 1
    for i, (x, y, s) in enumerate([(4, 14, 2.4), (-6, -16, 3.0), (12, -26, 1.8), (30, 22, 2.0), (2, 30, 3.4), (80, 4, 2.6), (80, 30, 2.2),
                                   (36, -30, 2.0), (-14, 6, 2.8), (46, 34, 1.6), (88, -14, 3.0), (22, 34, 1.4), (-30, -20, 2.6),
                                   (60, 50, 2.2), (-40, 30, 3.2), (110, 0, 2.4)]):
        rockblob(C, (x, y, ground_h(x, y) + s * 0.2), (s * 1.3, s, s * 0.7), amp=0.45, seed=300 + i, sub=2, mat="M_MesaCliff", name="boulder")
    rock_stack(C, *L5["pinnacle"], 5.4, 71)
    ob = merge_into("S5_Mesa-col", C)
    for p in ob.data.polygons:      # crags + boulders too: flat-shaded icospheres read as low-poly
        p.use_smooth = True
    paint_mask(ob)
    return ob

def paint_mask(ob):
    """Vertex colour 'TerrainMask' for shaders/mesa_terrain.gdshader (Godot blends the layers; slope picks rock):
    R = gravel (trodden pads round the route + buildings, and patches), G = moss (crests, patches away from the route),
    B = cracked dirt patches, A = strata: which of the two cliff rocks shows."""
    me = ob.data
    if "TerrainMask" in me.color_attributes:
        me.color_attributes.remove(me.color_attributes["TerrainMask"])
    attr = me.color_attributes.new("TerrainMask", 'FLOAT_COLOR', 'POINT')
    for v in me.vertices:
        x, y, z = v.co
        m = flat_mask(x, y)
        na = noise.fractal(Vector((x * 0.045, y * 0.045, 21.0)), 0.5, 2.0, 3, noise_basis='PERLIN_ORIGINAL')
        nb = noise.fractal(Vector((x * 0.03, y * 0.03, 33.0)), 0.5, 2.0, 3, noise_basis='PERLIN_ORIGINAL')
        nc = noise.fractal(Vector((x * 0.022, y * 0.022, 47.0)), 0.5, 2.0, 3, noise_basis='PERLIN_ORIGINAL')
        gravel = min(1.0, 0.6 * (1.0 - m) * smooth(-0.15, 0.3, na) + 0.7 * smooth(0.2, 0.45, na))
        dirt = smooth(0.0, 0.3, nb) * (1.0 - 0.6 * gravel)
        moss = min(1.0, smooth(0.08, 0.4, nc) * (0.2 + 0.6 * m) + 0.3 * smooth(G + 5.0, G + 16.0, z) * m)
        strata = smooth(-0.25, 0.25, math.sin(z * 0.23 + nb * 3.0))
        attr.data[v.index].color = (gravel, moss, dirt, strata)
    me.color_attributes.active_color = attr

def rock_stack(C, cx, cy, top, r_top, seed):
    """A sheer rock stack rising out of the haze (the pinnacle in the cove): banded strata, flaring towards the bottom."""
    bm = bmesh.new(); N = 28
    zs = [top, top - 0.4] + [top - 1.5 - k * 2.6 for k in range(48)]
    rings = []
    for z in zs:
        depth = top - z
        ring = []
        for k in range(N):
            th = 2 * math.pi * k / N
            st = noise.fractal(Vector((math.cos(th) * 1.6 + seed, math.sin(th) * 1.6, z * 0.07)), 0.55, 2.0, 3, noise_basis='PERLIN_ORIGINAL')
            r = r_top + depth * 0.07 + 1.3 * st + 0.5 * math.sin(z * 0.6 + st * 2.0) + (-0.6 if depth < 0.1 else 0.0)
            ring.append(bm.verts.new((cx + r * math.cos(th) * 1.08, cy + r * math.sin(th), z)))
        rings.append(ring)
    cap = bm.faces.new(rings[0]); cap.material_index = 1
    for i in range(len(rings) - 1):
        for k in range(N):
            bm.faces.new((rings[i][k], rings[i][(k + 1) % N], rings[i + 1][(k + 1) % N], rings[i + 1][k]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    for f in bm.faces: f.smooth = True
    ob = mk_obj("stack", bm, "M_MesaCliff", C); ob.data.materials.append(M("M_MesaGround"))
    rnd = random.Random(seed)
    for i in range(9):      # a crown of broken rock round the deck
        th = rnd.uniform(0, 2 * math.pi); s = rnd.uniform(1.0, 2.0)
        rr = r_top + rnd.uniform(-0.2, 0.8)
        rockblob(C, (cx + rr * math.cos(th) * 1.08, cy + rr * math.sin(th), top - rnd.uniform(0.4, 2.5)), (s * 1.3, s, s * 0.9),
                 amp=0.5, seed=seed * 10 + i, sub=2, mat="M_MesaCliff", name="crown")

# ---------------------------------------------------------------- stair-3 well (back down to the cavern)
def stairwell(C, D, R):
    x0, x1, y0, y1 = L5["pit"]; fz = L5["pit_floor"]
    t = 0.3
    boxmm(C, "M_Concrete", x0, x1 + t, y0 - t, y0, fz - 0.5, G + 0.12, "pit_s", 0.02)
    boxmm(C, "M_Concrete", x0, x1 + t, y1, y1 + t, fz - 0.5, G + 0.12, "pit_n", 0.02)
    boxmm(C, "M_Concrete", x1, x1 + t, y0, y1, fz - 0.5, G + 0.12, "pit_e", 0.02)
    # v8: the well is choked by the collapse (art_src/v8_collapse.py, assets/level/collapse.glb) a metre or so below grade;
    # the closed floor + end wall keep the pinholes in it from looking into the void
    boxmm(C, "M_Concrete", x0 - 0.3, x1, y0, y1, fz - 0.5, fz, "pit_f", 0.0)
    boxmm(C, "M_Concrete", x0 - 0.3, x0, y0, y1, fz - 0.5, G - 2.0, "pit_w", 0.0)
    flight_lo = (x1 - 0.2, (y0 + y1) / 2, fz); flight_hi = (x0, (y0 + y1) / 2, G)
    stairs(D, flight_lo, flight_hi, width=3.0, rampcat=R)
    # curb + railings round the well (the gate closes the west end; guards are StairGuard in build_surface.gd)
    for (a, b) in (((x0, y0 - t), (x1 + t, y0 - t)), ((x0, y1 + t), (x1 + t, y1 + t)), ((x1 + t, y0 - t), (x1 + t, y1 + t))):
        railing(D, (a[0], a[1], G + 0.12), (b[0], b[1], G + 0.12), h=1.1, spacing=1.6)

# ---------------------------------------------------------------- v8: lift landing collar
def lift_collar(C, D):
    """Steel plates flush with the car floor, filling the hole round the parked car (the hole is 4.2 x 5.0, the car
    3.0 x 3.0): nothing left to slip through into the shaft. The car model's footprint (x 19.02..22.38, y -4.46..-1.34,
    wider than its collision) stays open so it can run; the east side already has the landing sill (x 22.42..)."""
    lx0, lx1, ly0, ly1 = L5["lift"]
    cx0, cx1, cy0, cy1 = 18.99, 22.42, -4.49, -1.31
    top = G - 0.004                 # just under the curb + sill (both at G) so nothing z-fights
    for (a0, a1, b0, b1, n) in ((lx0, lx1, ly0, cy0, "collar_s"), (lx0, lx1, cy1, ly1, "collar_n"), (lx0, cx0, cy0, cy1, "collar_w")):
        boxmm(C, "M_Grate", a0, a1, b0, b1, top - 0.1, top, n, 0.0)
        boxmm(C, "M_Steel", a0, a1, b0, b1, top - 0.4, top - 0.1, n + "_frame", 0.0)     # under-frame, seen from the shaft
    # hazard edging round the car opening
    for (a0, a1, b0, b1) in ((cx0 - 0.1, cx1, cy0 - 0.1, cy0), (cx0 - 0.1, cx1, cy1, cy1 + 0.1), (cx0 - 0.1, cx0, cy0, cy1)):
        boxmm(D, "M_Hazard", a0, a1, b0, b1, top, top + 0.008, "collar_edge", 0.0)

# ---------------------------------------------------------------- building helpers
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

def streaks_x(D, x, y0, y1, z0, z1, n, seed, face=-1):
    """streaks() for a wall facing along X (x = wall plane)."""
    rnd = random.Random(seed)
    for i in range(n):
        y = rnd.uniform(y0, y1); l = rnd.uniform(1.5, (z1 - z0) * 0.7)
        boxmm(D, "M_Silhouette", x + face * 0.02, x + face * 0.035, y - 0.04, y + 0.04, z1 - l, z1 - 0.2, "streak", 0.0)

def windows(D, axis, plane, a0, a1, z0, z1, cols, rows, w=0.9, h=1.3, seed=0, face=1, skip=0.15):
    """A grid of dark window slots with sills on a wall. axis 'x': wall plane y = plane, windows spread along x;
    axis 'y': wall plane x = plane. face = which side of the plane the wall faces (+1/-1)."""
    rnd = random.Random(seed)
    for i in range(cols):
        a = a0 + (a1 - a0) * (i + 0.5) / cols
        for j in range(rows):
            if rnd.random() < skip: continue
            z = z0 + (z1 - z0) * (j + 0.5) / rows
            p = plane + face * 0.03
            mat = "M_Rust" if rnd.random() < 0.18 else "M_Silhouette"        # some shuttered
            if axis == 'x':
                boxmm(D, mat, a - w / 2, a + w / 2, min(p, plane), max(p, plane), z - h / 2, z + h / 2, "win", 0.0)
                boxmm(D, "M_Concrete", a - w / 2 - 0.12, a + w / 2 + 0.12, min(plane, plane + face * 0.18), max(plane, plane + face * 0.18),
                      z - h / 2 - 0.14, z - h / 2, "sill", 0.0)
            else:
                boxmm(D, mat, min(p, plane), max(p, plane), a - w / 2, a + w / 2, z - h / 2, z + h / 2, "win", 0.0)
                boxmm(D, "M_Concrete", min(plane, plane + face * 0.18), max(plane, plane + face * 0.18), a - w / 2 - 0.12, a + w / 2 + 0.12,
                      z - h / 2 - 0.14, z - h / 2, "sill", 0.0)

def bands(C, x0, x1, y0, y1, zs, out=0.14, t=0.3):
    """Projecting concrete string courses round a block."""
    for z in zs:
        boxmm(C, "M_Concrete", x0 - out, x1 + out, y0 - out, y1 + out, z, z + t, "band", 0.02)

def downpipe(D, x, y, z0, z1, r=0.11):
    cyl(D, "M_Rust", (x, y, z0), (x, y, z1), r, 8, "dpipe")
    for z in [z0 + 1.0 + k * 3.0 for k in range(int((z1 - z0 - 1.0) / 3.0) + 1)]:
        cyl(D, "M_Steel", (x, y, z - 0.06), (x, y, z + 0.06), r + 0.05, 8, "clamp")

def vent(C, x, y, z, s=1.0, seed=0):
    rnd = random.Random(seed)
    if rnd.random() < 0.5:
        boxmm(C, "M_Steel", x - 0.6 * s, x + 0.6 * s, y - 0.45 * s, y + 0.45 * s, z, z + 0.7 * s, "acbox", 0.03)
        cyl(C, "M_Silhouette", (x, y, z + 0.7 * s), (x, y, z + 0.72 * s), 0.32 * s, 12, "fan")
    else:
        cyl(C, "M_Steel", (x, y, z), (x, y, z + 1.2 * s), 0.22 * s, 10, "vstack")
        cyl(C, "M_Rust", (x, y, z + 1.2 * s), (x, y, z + 1.45 * s), 0.38 * s, 10, "vcap", r2=0.08 * s)

def ladder_vis(D, x, y, z0, z1, along='x', w=0.5):
    """Visual ladder (two stiles + rungs) against a wall."""
    ox = Vector((w / 2, 0, 0)) if along == 'x' else Vector((0, w / 2, 0))
    a = Vector((x, y, z0)); b = Vector((x, y, z1))
    for s in (-1, 1):
        member(D, "M_Steel", a + ox * s, b + ox * s, 0.05, 0.05)
    for k in range(int((z1 - z0) / 0.32)):
        z = z0 + 0.3 + k * 0.32
        member(D, "M_Steel", Vector((x, y, z)) - ox, Vector((x, y, z)) + ox, 0.035, 0.035)

def wires(D, pts, sag=1.0, n=24, r=0.025):
    """Sagging cables through a list of points."""
    for p0, p1 in zip(pts[:-1], pts[1:]):
        c = cable_pts(p0, p1, sag * (Vector(p0) - Vector(p1)).length / 20.0, n)
        for a, b in zip(c[:-1], c[1:]):
            member(D, "M_Cable", a, b, r, r)

def crate(C, x, y, z, s=1.0, rot=0.0, seed=0):
    ob = boxmm(C, ("M_Rust", "M_Corrugated", "M_RustSheet")[seed % 3], -0.6 * s, 0.6 * s, -0.5 * s, 0.5 * s, 0, 0.9 * s, "crate", 0.04)
    ob.location = (x, y, z + 0.45 * s); ob.rotation_euler = (0, 0, rot)

def barrel(C, x, y, z, seed=0):
    cyl(C, "M_Rust" if seed % 3 else "M_Hazard", (x, y, z), (x, y, z + 1.0), 0.32, 12, "barrel")
    cyl(C, "M_Steel", (x, y, z + 0.3), (x, y, z + 0.36), 0.335, 12, "hoop")

# ---------------------------------------------------------------- the works (the painting's centrepiece)
def works(C, D, R):
    # --- gallery: long deck on columns (left of the painting), roof slab with railings, pale pipes beneath
    gx0, gx1, gy0, gy1, gz = L5["gallery"]
    deck5(C, gx0, gx1, gy0, gy1, gz)
    legs(C, gx0, gx1, gy0, gy1, gz)
    for (a, b) in (((gx0, gy1), (gx1, gy1)), ((gx0, 13.0), (gx0, gy1)), ((gx0, gy0), (gx0, 11.0)), ((gx0, gy0), (57.5, gy0)),
                   ((gx1, gy0), (gx1, gy1))):          # (v6: the east edge was open)
        rail(D, R, a, b, gz, spacing=1.8)
    # roof slab over the back half, on posts; railing round the top, grass on it
    boxmm(C, "M_Concrete", 53.0, gx1, 15.0, gy1, gz + 3.6, gz + 4.1, "groof", 0.05)
    for x in (53.3, 57.5, 61.7):
        for y in (15.3, 23.7):
            ibeam(C, (x, y, gz), (x, y, gz + 3.6), h=0.3, w=0.24)
    railing(D, (53.0, 15.0, gz + 4.1), (53.0, gy1, gz + 4.1), h=1.0, spacing=1.6, broken=0.3, seed=3)
    railing(D, (53.0, gy1, gz + 4.1), (gx1, gy1, gz + 4.1), h=1.0, spacing=1.6, broken=0.2, seed=4)
    for i in range(6):        # cross-braces between the legs (truss look; solid: they're at walking height)
        x = gx0 + 2.0 * i
        member(C, "M_Steel", (x, gy0, G + 0.5), (x + 2.0, gy0, gz - 0.4), 0.08, 0.08)
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
    # v6 gallery clutter: crates + drums in the back corner (off the stair -> link line), hanging lamp, roof vents
    for i, (x, y, s, rt) in enumerate(((60.6, 22.6, 1.0, 0.1), (59.2, 22.8, 0.9, -0.2), (60.4, 21.3, 0.8, 0.4), (60.5, 22.6, 0.7, 0.8))):
        crate(C, x, y, gz + (0.9 if i == 3 else 0.0), s, rt, i)
    for i, (x, y) in enumerate(((51.0, 23.0), (51.8, 23.2), (51.2, 22.2))):
        barrel(C, x, y, gz, i)
    cyl(D, "M_Cable", (57.5, 19.5, gz + 3.6), (57.5, 19.5, gz + 2.6), 0.02, 6, "lampcord")
    cyl(D, "M_Steel", (57.5, 19.5, gz + 2.6), (57.5, 19.5, gz + 2.3), 0.3, 12, "lampshade", r2=0.08)
    for i, (x, y) in enumerate(((55.0, 17.0), (59.8, 20.5), (55.5, 22.0))):
        vent(C, x, y, gz + 4.1, 0.9, 40 + i)
    # stair 1: ground -> gallery
    lo, hi = L5["stair1"]
    gflight(D, R, lo, hi, width=2.0)
    boxmm(C, "M_Concrete", lo[0] - 1.0, lo[0] + 0.05, lo[1] - 1.3, lo[1] + 1.3, G - 0.6, G + 0.05, "stair_pad", 0.03)

    # --- link deck along bunker A's west face, down to the tower
    lx0, lx1, ly0, ly1, lz = L5["link"]
    deck5(C, lx0, lx1, ly0, ly1, lz)
    legs(C, lx0, lx1, ly0, ly1, lz, step=4.6)
    rail(D, R, (lx0, ly0 + 0.2), (lx0, gy0), lz, spacing=1.8)

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
    boxmm(C, "M_Concrete2", 61.0, 73.5, -11.5, -0.2, G - 1.0, 56.0, "bunkerB", 0.08)
    boxmm(C, "M_Concrete", 60.6, 74.0, -12.0, 0.3, 56.0, 56.6, "capB", 0.05)
    boxmm(C, "M_RustSheet", 64.0, 70.0, -9.0, -3.0, 56.6, 59.6, "headhouse", 0.05)
    cyl(C, "M_Steel", (71.5, -2.0, 56.6), (71.5, -2.0, 66.0), 0.08, 6, "antenna")
    member(C, "M_Steel", (70.6, -2.0, 64.0), (72.4, -2.0, 64.0), 0.06, 0.06)
    streaks(D, 61.6, 72.8, -0.2 + 9.2, 34.5, 44.0, 14, 11, face=1)
    streaks(D, 61.2, 73.3, -11.5, 34.5, 56.0, 18, 12, face=-1)
    for (x, y) in ((61.0, -6.0), (61.0, 4.0)):      # dark window slots
        boxmm(D, "M_Silhouette", x - 0.06, x, y - 1.6, y + 1.6, 49.0 if y < 0 else 41.5, 50.2 if y < 0 else 42.5, "slot", 0.0)
    # v6 detail: bunker A - plinth, string course, door, slots, downpipes; bunker B - window rows, bands, roof clutter
    boxmm(C, "M_Concrete", 61.3, 73.2, -0.2, 9.3, G - 0.5, G + 0.7, "plinthA", 0.04)
    boxmm(C, "M_Concrete", 73.0, 73.25, -0.2, 9.0, 38.6, 38.9, "bandA_e", 0.0)
    boxmm(C, "M_Concrete", 61.5, 73.0, 9.0, 9.22, 38.6, 38.9, "bandA_n", 0.0)
    boxmm(D, "M_Silhouette", 66.0, 68.4, 9.0, 9.04, G + 0.7, G + 3.3, "doorA", 0.0)
    boxmm(C, "M_Concrete", 65.6, 68.8, 9.0, 10.2, G + 3.4, G + 3.65, "canopyA", 0.03)
    windows(D, 'x', 9.0, 62.5, 72.0, 39.6, 42.8, 6, 1, w=1.1, h=0.9, seed=31, face=1)
    windows(D, 'y', 73.0, 0.6, 8.4, G + 1.5, 43.0, 4, 2, w=1.0, h=1.4, seed=32, face=1)
    downpipe(D, 62.0, 9.2, G, 44.0); downpipe(D, 72.6, 9.2, G, 44.0)
    windows(D, 'y', 73.5, -10.8, -0.9, 37.0, 55.0, 4, 5, w=1.2, h=1.6, seed=33, face=1)
    windows(D, 'x', -11.5, 61.8, 72.6, 47.5, 55.0, 5, 2, w=1.1, h=1.5, seed=34, face=-1)
    windows(D, 'x', -0.2, 62.0, 72.5, 50.5, 55.0, 4, 1, w=1.2, h=1.6, seed=35, face=1)
    bands(C, 61.0, 73.5, -11.5, -0.2, (44.6, 50.3))
    boxmm(C, "M_RustSheet", 73.5, 74.4, -8.5, -4.5, 41.0, 44.0, "ventbox", 0.04)            # duct box on the east face
    cyl(C, "M_Rust", (73.95, -6.5, 44.0), (73.95, -6.5, 55.4), 0.4, 12, "duct")
    downpipe(D, 73.7, -11.3, G, 56.0); downpipe(D, 73.7, -0.4, G, 49.5)
    for i, (x, y) in enumerate(((62.2, -10.6), (72.4, -1.2), (62.0, -1.0))):
        vent(C, x, y, 56.6, 1.1, 50 + i)
    cyl(C, "M_RustSheet", (71.2, -9.6, 56.6), (71.2, -9.6, 59.4), 1.1, 14, "roof_tank")
    for (dx, dy) in ((-0.7, -0.7), (0.7, -0.7), (-0.7, 0.7), (0.7, 0.7)):
        member(C, "M_Steel", (71.2 + dx, -9.6 + dy, 56.6), (71.2 + dx, -9.6 + dy, 57.2), 0.12, 0.12)
    railing(D, (60.8, -11.8, 56.6), (60.8, 0.1, 56.6), h=1.0, spacing=1.8, broken=0.35, seed=7)
    ladder_vis(D, 64.0, -9.2, 56.6, 59.6, 'x')

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
        member(C, "M_Steel", (tx0, ty0, z0), (tx0, ym, z1), 0.14, 0.14)      # K on the west face
        member(C, "M_Steel", (tx0, ty1, z0), (tx0, ym, z1), 0.14, 0.14)
        xbrace(C, (tx0, ty0), (tx1, ty0), z0, z1, 0.12)
    deck5(C, tx0, tx1, ty0, ty1, 40.0)
    tdx0, tdx1, tdy0, tdy1, tdz = L5["top_deck"]
    deck5(C, tdx0, tdx1, tdy0, tdy1, tdz)
    lo2, hi2 = L5["stair2"]
    gflight(D, R, lo2, hi2, width=2.0)
    rail(D, R, (tx0, ty1), (tx0, ty0), 40.0, spacing=1.8)
    rail(D, R, (tx0, ty0), (tx1, ty0), 40.0, spacing=1.8)
    rail(D, R, (tx0, tdy1), (tx0, tdy0), tdz)
    for (a, b) in ((tx0, 56.9), (59.1, tx1)):     # either side of the stairhead
        rail(D, R, (a, tdy1), (b, tdy1), tdz, spacing=1.2)
    railing(D, (tx1, tdy1, tdz), (tx1, tdy0, tdz), h=1.1, spacing=1.6)     # east side of the top deck (bunker B is behind)
    rail(D, R, (tx0, tdy0), (L5["gantry"][0], tdy0), tdz)
    rail(D, R, (L5["gantry"][1], tdy0), (tx1, tdy0), tdz)
    # lamp mast on the tower top + sign board
    boxmm(C, "M_Rust", tx0 + 0.4, tx1 - 0.4, ty0 + 0.5, ty0 + 0.62, 50.0, 52.4, "sign", 0.02)
    boxmm(D, "M_Hazard", tx0 + 0.5, tx1 - 0.5, ty0 + 0.45, ty0 + 0.5, 50.1, 50.5, "sign_haz", 0.0)
    cyl(C, "M_Rust", (55.9, -1.2, 40.0), (55.9, -1.2, 40.9), 0.55, 14, "spool")        # cable drum on the Z40 deck
    for z in (40.0, 40.9):
        cyl(C, "M_Steel", (55.9, -1.2, z - 0.02), (55.9, -1.2, z + 0.02), 0.75, 14, "spool_rim")

    # --- gantry: catwalk truss + two big pipes, from the tower south to block C
    ax0, ax1, ay0, ay1, az = L5["gantry"]
    boxmm(C, "M_Grate", ax0, ax1, ay0, ay1, az - 0.08, az, "gdeck", 0.0)
    for x in (ax0, ax1):
        truss(D, Vector((x, ay0, az - 0.2)), Vector((x, ay1, az - 0.2)), height=1.25, mat="M_Steel", panel=1.6, sz=0.09)
        guard(R, (x, ay0), (x, ay1), az)
    for k in range(int(ay1 - ay0) // 2 + 1):
        y = ay0 + 2.0 * k
        member(C, "M_Steel", (ax0, y, az - 0.3), (ax1 + 2.4, y, az - 0.3), 0.14, 0.24)
    for (x, z, r) in ((60.1, az + 0.3, 0.58), (61.4, az + 1.5, 0.46)):
        cyl(C, "M_PalePipe", (x, -11.2, z), (x, -27.2, z), r, 16, "gpipe")
        for y in (-14.0, -19.0, -24.0):
            cyl(C, "M_Steel", (x, y - 0.1, z), (x, y + 0.1, z), r + 0.07, 16, "gflange")
    for x in (ax0, ax1 + 2.4):    # mid pier
        ibeam(C, (x, -19.0, G - 1.0), (x, -19.0, az - 0.4), h=0.38, w=0.3)
    xbrace(C, (ax0, -19.0), (ax1 + 2.4, -19.0), G, az - 0.5, 0.12)

    # --- block C (right of the painting): flat roof, vertical pipes, tank. v6: the route carries on south over bridge 1
    cx0, cx1, cy0, cy1, cz = L5["blockC"]
    bx0, bx1 = L5["bridge1"][0], L5["bridge1"][1]
    boxmm(C, "M_Concrete3", cx0, cx1, cy0, cy1, G - 1.0, cz, "blockC", 0.08)
    for (a, b) in (((cx0, cy0), (cx0, cy1)), ((cx0 + 5.0, cy1), (cx1, cy1)), ((cx0, cy1), (ax0, cy1))):   # (v6: 54..57 was open)
        boxmm(C, "M_Concrete", min(a[0], b[0]) - 0.17, max(a[0], b[0]) + 0.17, min(a[1], b[1]) - 0.17, max(a[1], b[1]) + 0.17, cz, cz + 0.9, "parapet", 0.03)
        guard(R, a, b, cz)
    # south + east: a low curb and a railing, so you can see down over the edge; bridge 1 leaves from the south side
    for (a, b) in (((cx0, cy0), (bx0, cy0)), ((bx1, cy0), (cx1, cy0)), ((cx1, cy0), (cx1, cy1))):
        boxmm(C, "M_Concrete", min(a[0], b[0]) - 0.17, max(a[0], b[0]) + 0.17, min(a[1], b[1]) - 0.17, max(a[1], b[1]) + 0.17, cz, cz + 0.25, "curb", 0.03)
        railing(D, (a[0], a[1], cz + 0.25), (b[0], b[1], cz + 0.25), h=1.0, spacing=1.6)
        guard(R, a, b, cz)
    cyl(C, "M_RustSheet", (61.5, -31.0, cz), (61.5, -31.0, cz + 4.2), 2.0, 18, "tank")
    cyl(C, "M_Steel", (61.5, -31.0, cz + 4.2), (61.5, -31.0, cz + 4.5), 2.15, 18, "tank_lid")
    ladder_vis(D, 61.5, -33.05, cz, cz + 4.2, 'x')
    for (x, top) in ((56.0, cz + 1.6), (58.0, cz + 3.0), (62.0, cz + 2.2)):
        cyl(C, "M_PalePipe", (x, cy0 - 0.6, G - 1.0), (x, cy0 - 0.6, top), 0.35, 12, "vpipe")
        cyl(C, "M_Steel", (x, cy0 - 0.6, top), (x, cy0 - 0.6, top + 0.2), 0.45, 12, "vpipe_cap")
        for z in (G + 3.0, G + 7.0, cz - 1.0):
            member(C, "M_Steel", (x, cy0 - 0.6, z), (x, cy0 + 0.02, z), 0.12, 0.12)
    streaks(D, cx0 + 0.2, cx1 - 0.2, cy0, 34.5, cz, 16, 13, face=-1)
    streaks(D, cx0 + 0.2, cx1 - 0.2, cy1, 34.5, cz, 10, 14, face=1)
    boxmm(D, "M_Silhouette", cx1, cx1 + 0.03, -34.0, -31.0, G, G + 2.6, "doorC", 0.0)
    windows(D, 'y', cx0, cy0 + 0.8, cy1 - 0.8, G + 3.0, cz - 1.0, 4, 2, w=1.0, h=1.4, seed=36, face=-1)
    windows(D, 'y', cx1, cy0 + 0.8, cy1 - 0.8, G + 4.0, cz - 1.0, 3, 2, w=1.0, h=1.4, seed=37, face=1)
    bands(C, cx0, cx1, cy0, cy1, (G + 0.0, 40.4), out=0.12)
    for i, (x, y) in enumerate(((55.2, -28.2), (66.0, -28.4))):
        vent(C, x, y, cz, 0.9, 60 + i)
    boxmm(C, "M_Steel", 54.6, 56.0, -36.8, -35.2, cz, cz + 0.35, "hatch", 0.03)

    # --- the thin tall mast (far left of the painting): carries the power line off to the west
    member(C, "M_Steel", (40.0, 30.0, G - 0.5), (40.0, 30.0, 62.0), 0.32, 0.32)
    member(C, "M_Steel", (38.4, 30.0, 59.5), (41.6, 30.0, 59.5), 0.14, 0.14)
    member(C, "M_Steel", (38.9, 30.0, 61.0), (41.1, 30.0, 61.0), 0.12, 0.12)

# ---------------------------------------------------------------- v6: past the lookout - the cove, the pinnacle, the silo
def deck_rails(D, R, x0, x1, y0, y1, z, gaps=(), spacing=1.6):
    """Rail + guard round a deck, skipping gaps: list of (side, a0, a1) with side in 'N','S','E','W'."""
    sides = dict(S=((x0, y0), (x1, y0)), N=((x0, y1), (x1, y1)), W=((x0, y0), (x0, y1)), E=((x1, y0), (x1, y1)))
    for s, (a, b) in sides.items():
        horiz = s in "NS"
        lo, hi = (a[0], b[0]) if horiz else (a[1], b[1])
        cuts = sorted((g[1], g[2]) for g in gaps if g[0] == s)
        segs = []; cur = lo
        for (g0, g1) in cuts:
            if g0 > cur + 0.05: segs.append((cur, g0))
            cur = max(cur, g1)
        if hi > cur + 0.05: segs.append((cur, hi))
        for (u0, u1) in segs:
            p0 = (u0, a[1]) if horiz else (a[0], u0); p1 = (u1, a[1]) if horiz else (a[0], u1)
            rail(D, R, p0, p1, z, spacing=spacing)

def catwalk(C, D, R, x0, x1, y0, y1, z, along='y', pipe_side=None):
    """Bridge: grating deck, under-girders, cross beams, truss sides with guards."""
    boxmm(C, "M_Grate", x0, x1, y0, y1, z - 0.08, z, "bdeck", 0.0)
    if along == 'y':
        for x in (x0, x1):
            truss(D, Vector((x, y0, z - 0.2)), Vector((x, y1, z - 0.2)), height=1.25, mat="M_Steel", panel=1.6, sz=0.09)
            guard(R, (x, y0), (x, y1), z)
            ibeam(C, (x + 0.15 * (1 if x == x0 else -1), y0, z - 0.55), (x + 0.15 * (1 if x == x0 else -1), y1, z - 0.55), h=0.6, w=0.3)
        for k in range(int((y1 - y0) / 1.8) + 1):
            y = y0 + 1.8 * k
            member(C, "M_Steel", (x0, y, z - 0.3), (x1, y, z - 0.3), 0.12, 0.2)
    else:
        for y in (y0, y1):
            truss(D, Vector((x0, y, z - 0.2)), Vector((x1, y, z - 0.2)), height=1.25, mat="M_Steel", panel=1.6, sz=0.09)
            guard(R, (x0, y), (x1, y), z)
            ibeam(C, (x0, y + 0.15 * (1 if y == y0 else -1), z - 0.55), (x1, y + 0.15 * (1 if y == y0 else -1), z - 0.55), h=0.6, w=0.3)
        for k in range(int((x1 - x0) / 1.8) + 1):
            x = x0 + 1.8 * k
            member(C, "M_Steel", (x, y0, z - 0.3), (x, y1, z - 0.3), 0.12, 0.2)

def cove(C, D, R):
    z = 46.0
    # bridge 1: block C -> pinnacle, on a trestle at the cove's lip; a pale pipe runs alongside
    bx0, bx1, by0, by1, bz = L5["bridge1"]
    catwalk(C, D, R, bx0, bx1, by0, by1, bz, 'y')
    for x in (bx0 - 0.3, bx1 + 0.3):
        ibeam(C, (x, -43.5, G - 1.0), (x, -43.5, bz - 0.6), h=0.4, w=0.32)
    xbrace(C, (bx0 - 0.3, -43.5), (bx1 + 0.3, -43.5), G + 0.5, bz - 1.0, 0.12)
    member(C, "M_Steel", (bx0 - 0.5, -43.5, bz - 0.7), (bx1 + 0.5, -43.5, bz - 0.7), 0.3, 0.3)
    cyl(C, "M_PalePipe", (bx1 + 0.75, by1 - 0.4, bz - 0.15), (bx1 + 0.75, by0 + 0.6, bz - 0.15), 0.4, 14, "bpipe")
    cyl(C, "M_PalePipe", (bx1 + 0.75, by0 + 0.6, bz - 0.15), (bx1 + 0.75, by0 + 0.6, bz - 3.5), 0.4, 14, "bpipe_dn")
    for y in (-41.0, -46.0, -51.0):
        cyl(C, "M_Steel", (bx1 + 0.75, y - 0.1, bz - 0.15), (bx1 + 0.75, y + 0.1, bz - 0.15), 0.47, 14, "bflange")
        member(C, "M_Steel", (bx1, y, bz - 0.55), (bx1 + 1.2, y, bz - 0.55), 0.1, 0.1)
    # the pinnacle deck: concrete pad on the rock with steel brackets under the corners
    px0, px1, py0, py1, pz = L5["pin_deck"]
    pcx, pcy, ptop = L5["pinnacle"]
    boxmm(C, "M_Concrete2", px0, px1, py0, py1, ptop - 0.8, pz, "pindeck", 0.05)
    for (x, y) in ((px0, py0), (px1, py0), (px0, py1), (px1, py1)):
        member(C, "M_Steel", (x, y, pz - 0.5), (pcx + (x - pcx) * 0.55, pcy + (y - pcy) * 0.55, pz - 4.5), 0.22, 0.22)
    deck_rails(D, R, px0, px1, py0, py1, pz, gaps=(("N", bx0, bx1), ("E", L5["bridge2"][2], L5["bridge2"][3])))
    # the hut (corrugated, door facing the bridge), jib crane over the drop, lamp post, crates
    boxmm(C, "M_Corrugated", 64.0, 68.0, -64.0, -60.6, pz, pz + 2.7, "hut", 0.03)
    boxmm(C, "M_RustSheet", 63.8, 68.3, -64.2, -60.3, pz + 2.7, pz + 2.95, "hut_roof", 0.03)
    boxmm(D, "M_Silhouette", 65.3, 66.6, -60.6, -60.57, pz, pz + 2.1, "hut_door", 0.0)
    boxmm(D, "M_Silhouette", 68.0, 68.03, -63.0, -61.8, pz + 1.3, pz + 2.0, "hut_win", 0.0)
    cyl(C, "M_Steel", (67.2, -62.0, pz + 2.95), (67.2, -62.0, pz + 4.2), 0.12, 8, "hut_flue")
    mx, my = 71.3, -63.3
    ibeam(C, (mx, my, pz), (mx, my, pz + 8.5), h=0.36, w=0.3)
    jib_end = Vector((76.5, -68.0, pz + 8.0))
    truss(D, Vector((mx, my, pz + 7.6)), jib_end, height=0.7, mat="M_Rust", panel=1.2, sz=0.1)
    member(D, "M_Cable", (mx, my, pz + 8.5), jib_end + Vector((0, 0, 0.7)), 0.03, 0.03)
    member(D, "M_Cable", jib_end, jib_end - Vector((0, 0, 7.0)), 0.03, 0.03)
    boxmm(D, "M_Rust", jib_end.x - 0.25, jib_end.x + 0.25, jib_end.y - 0.12, jib_end.y + 0.12, jib_end.z - 7.6, jib_end.z - 7.0, "hook", 0.02)
    boxmm(C, "M_Steel", mx - 0.7, mx + 0.7, my - 0.5, my + 0.5, pz, pz + 1.1, "winch", 0.04)
    cyl(C, "M_Steel", (63.9, -56.0, pz), (63.9, -56.0, pz + 4.0), 0.09, 8, "lamppost")
    member(C, "M_Steel", (63.9, -56.0, pz + 4.0), (64.8, -56.0, pz + 4.0), 0.08, 0.08)
    cyl(D, "M_Lamp", (64.8, -56.0, pz + 3.95), (64.8, -56.0, pz + 3.75), 0.22, 10, "lampshade2", r2=0.1)
    crate(C, 64.3, -59.2, pz, 0.9, 0.3, 1); barrel(C, 64.4, -58.0, pz, 2)
    # bridge 2: pinnacle -> silo landing (deep truss, an older pipe slung below)
    qx0, qx1, qy0, qy1, qz = L5["bridge2"]
    catwalk(C, D, R, qx0, qx1, qy0, qy1, qz, 'x')
    for y in (qy0 - 0.1, qy1 + 0.1):
        truss(D, Vector((qx0, y, qz - 2.6)), Vector((qx1, y, qz - 2.6)), height=2.0, mat="M_Steel", panel=2.2, sz=0.12)
    cyl(C, "M_PalePipe", (qx0 - 1.0, qy0 - 0.9, qz - 3.4), (qx1 + 1.0, qy0 - 0.9, qz - 4.4), 0.45, 14, "slungpipe")
    # silo landing: cantilevered deck on struts from the cliff face; legs to the ground under its back edge
    sx0, sx1, sy0, sy1, sz = L5["silo_deck"]
    deck5(C, sx0, sx1, sy0, sy1, sz)
    for x in (sx0, sx0 + 4.0, sx0 + 8.0, sx1):
        member(C, "M_Steel", (x, sy0, sz - 0.4), (x, -53.5, sz - 11.0), 0.3, 0.3)
        member(C, "M_Steel", (x, sy0, sz - 0.4), (x, sy1, sz - 0.4), 0.2, 0.36)
        ibeam(C, (x, -51.0, G - 1.0), (x, -51.0, sz - 0.5), h=0.36, w=0.3)
    s_ax0, s_ax1 = L5["flightA"][0][0] - 1.0, L5["flightA"][0][0] + 1.0
    deck_rails(D, R, sx0, sx1, sy0, sy1, sz, gaps=(("W", qy0, qy1), ("N", s_ax0, sx1)))
    boxmm(D, "M_Silhouette", 92.5, 95.5, -50.04, -50.0, sz, sz + 2.6, "silo_door", 0.0)
    boxmm(C, "M_Hazard", 92.3, 95.7, -50.25, -50.0, sz + 2.6, sz + 2.8, "silo_lintel", 0.0)
    crate(C, 97.0, -51.2, sz, 1.0, 0.15, 3); crate(C, 96.9, -52.3, sz, 0.8, -0.3, 4); barrel(C, 87.2, -59.0, sz, 5)
    silo(C, D, R)

def silo(C, D, R):
    """The tall tower at the end of the line (centre-right of the painting): concrete core with string courses and
    slot windows, external stair (flights A + B) round its west and north faces, a tank and dish on the roof."""
    x0, x1, y0, y1, top = L5["silo"]
    boxmm(C, "M_Concrete2", x0, x1, y0, y1, G - 1.0, top, "silo_core", 0.08)
    bands(C, x0, x1, y0, y1, (G + 0.0, 40.0, 46.2, 51.0, top - 0.3), out=0.16)
    boxmm(C, "M_Concrete", x0 - 0.3, x1 + 0.3, y0 - 0.3, y1 + 0.3, top - 0.1, top, "silo_cap", 0.03)
    windows(D, 'y', x1, y0 + 1.0, y1 - 1.0, G + 2.0, top - 1.5, 4, 5, w=0.8, h=1.5, seed=81, face=1)
    windows(D, 'x', y0, x0 + 1.0, x1 - 1.0, 47.5, top - 1.5, 3, 2, w=0.8, h=1.5, seed=82, face=-1)
    windows(D, 'x', y0, x0 + 1.0, x1 - 1.0, G + 2.0, 44.5, 3, 2, w=0.8, h=1.5, seed=85, face=-1)
    windows(D, 'y', x0, y0 + 2.0, y1 - 1.0, G + 2.0, 44.5, 3, 2, w=0.8, h=1.5, seed=83, face=-1)
    streaks(D, x0 + 0.2, x1 - 0.2, y0, G, top, 14, 84, face=-1)
    streaks_x(D, x1, y0 + 0.2, y1 - 0.2, G, top, 14, 86, face=1)
    downpipe(D, x1 + 0.2, y1 - 0.3, G, top)
    boxmm(D, "M_Silhouette", x1, x1 + 0.03, -45.5, -43.0, G, G + 2.7, "silo_gdoor", 0.0)
    # flight A: landing -> NW landing (Z52), up the west face
    loA, hiA = L5["flightA"]
    gflight(D, R, loA, hiA, width=2.0, sides=(1,))       # the east side is the silo wall
    ax0_, ax1_, ay0_, ay1_, az_ = L5["landA"]
    deck5(C, ax0_, ax1_, ay0_, ay1_, az_)
    rail(D, R, (ax0_, ay0_), (ax0_, ay1_), az_)
    rail(D, R, (ax0_, ay1_), (ax1_, ay1_), az_)
    # flight B: along the north face -> NE landing at roof level
    loB, hiB = L5["flightB"]
    gflight(D, R, loB, hiB, width=2.0, sides=(1,))       # the south side is the silo wall
    bx0_, bx1_, by0_, by1_, bz_ = L5["landB"]
    deck5(C, bx0_, bx1_, by0_, by1_, bz_)
    rail(D, R, (bx0_, by1_), (bx1_, by1_), bz_)
    rail(D, R, (bx1_, by0_), (bx1_, by1_), bz_)
    # scaffold under the stair: posts + braces down to the ground
    for (x, y, zt) in ((88.0, -49.6, 46.0), (88.0, -44.0, 49.0), (88.0, -38.0, 52.0), (88.0, -36.0, 52.0), (90.0, -36.0, 52.0),
                       (93.0, -36.0, 54.0), (96.0, -36.0, 56.0), (98.0, -36.0, 56.0)):
        ibeam(C, (x, y, G - 1.0), (x, y, zt - 0.3), h=0.3, w=0.26)
    xbrace(C, (88.0, -49.6), (88.0, -44.0), G + 0.5, 45.0, 0.1)
    xbrace(C, (88.0, -44.0), (88.0, -38.0), G + 0.5, 48.0, 0.1)
    xbrace(C, (90.0, -36.0), (96.0, -36.0), G + 0.5, 51.0, 0.1)
    # roof: parapet curb + railing, gap to landing B; tank, dish, mast
    rz = top
    for (a, b) in (((x0, y0), (x1, y0)), ((x0, y0), (x0, y1)), ((x1, y0), (x1, y1)), ((x0, y1), (bx0_, y1))):
        boxmm(C, "M_Concrete", min(a[0], b[0]) - 0.15, max(a[0], b[0]) + 0.15, min(a[1], b[1]) - 0.15, max(a[1], b[1]) + 0.15, rz, rz + 0.2, "scurb", 0.02)
        rail(D, R, a, b, rz + 0.2)
    tkx, tky = 93.2, -43.0       # (clear of the landing B -> lookout walk along x 97)
    cyl(C, "M_RustSheet", (tkx, tky, rz), (tkx, tky, rz + 4.6), 1.9, 18, "stank")
    cyl(C, "M_Steel", (tkx, tky, rz + 4.6), (tkx, tky, rz + 5.0), 2.05, 18, "stank_lid", r2=1.0)
    for z in (rz + 1.4, rz + 3.0):
        cyl(C, "M_Steel", (tkx, tky, z), (tkx, tky, z + 0.12), 1.97, 18, "stank_hoop")
    ladder_vis(D, tkx + 1.95, tky, rz, rz + 4.6, 'y')
    # dish antenna on a stub, south-east corner
    cyl(C, "M_Steel", (97.0, -49.0, rz), (97.0, -49.0, rz + 2.2), 0.14, 8, "dish_post")
    bmd = bmesh.new()
    bmesh.ops.create_cone(bmd, cap_ends=False, segments=20, radius1=0.15, radius2=1.3, depth=0.55)
    ob = mk_obj("dish", bmd, "M_PalePipe", C)
    ob.location = (97.3, -49.4, rz + 2.6); ob.rotation_mode = 'XYZ'; ob.rotation_euler = (math.radians(70), 0, math.radians(-145))
    # lattice mast on the north-west corner (taller than anything: it reads from the landing)
    lattice(C, D, x0 + 1.3, y1 - 1.3, rz, 13.0, 0.9, 0.3, 91)
    # sagging cables off the mast into the haze
    wires(D, [(x0 + 1.3, y1 - 1.3, rz + 12.5), (140.0, -10.0, 70.0)], sag=3.0)

def lattice(C, D, x, y, z0, h, w0, w1, seed):
    """Tapering 4-legged lattice tower (pylon / mast)."""
    pts = lambda z, w: [(x - w, y - w, z), (x + w, y - w, z), (x + w, y + w, z), (x - w, y + w, z)]
    lo = pts(z0, w0); hi = pts(z0 + h, w1)
    for a, b in zip(lo, hi):
        member(C, "M_Steel", a, b, 0.14, 0.14)
    n = max(2, int(h / 2.6))
    for i in range(n + 1):
        t0 = i / n; w = w0 + (w1 - w0) * t0; z = z0 + h * t0
        ring = pts(z, w)
        for k in range(4):
            member(D, "M_Steel", ring[k], ring[(k + 1) % 4], 0.07, 0.07)
        if i < n:
            t1 = (i + 1) / n; w_ = w0 + (w1 - w0) * t1; ring2 = pts(z0 + h * t1, w_)
            for k in range(4):
                member(D, "M_Steel", ring[k], ring2[(k + 1) % 4], 0.05, 0.05)
                member(D, "M_Steel", ring[(k + 1) % 4], ring2[k], 0.05, 0.05)

# ---------------------------------------------------------------- v6: scattered ruins on the mesa (scenery, solid)
def frame_ruin(C, D, cx, cy, seed=1):
    """A collapsed concrete frame building: column grid, broken floor slabs, a few infill walls, rebar, rubble."""
    rnd = random.Random(seed)
    xs = [cx - 7.5, cx - 2.5, cx + 2.5, cx + 7.5]; ys = [cy - 5.0, cy, cy + 5.0]
    zg = G
    for i, x in enumerate(xs):
        for j, y in enumerate(ys):
            hgt = rnd.choice((4.5, 9.0, 9.0, 13.5, 6.2, 2.4)) if (i + j) % 3 else 13.5
            boxmm(C, "M_Concrete", x - 0.3, x + 0.3, y - 0.3, y + 0.3, zg - 1.0, zg + hgt, "col", 0.03)
            if hgt not in (4.5, 9.0, 13.5):
                for k in range(3):     # rebar from the broken top
                    a = Vector((x + rnd.uniform(-0.2, 0.2), y + rnd.uniform(-0.2, 0.2), zg + hgt))
                    member(D, "M_Rust", a, a + Vector((rnd.uniform(-0.4, 0.4), rnd.uniform(-0.4, 0.4), rnd.uniform(0.6, 1.4))), 0.03, 0.03)
    # slabs: storey 1 nearly whole (a hole), storey 2 half, storey 3 a hanging fragment
    boxmm(C, "M_Concrete", xs[0] - 0.4, xs[2] + 0.4, ys[0] - 0.4, ys[2] + 0.4, zg + 4.5, zg + 4.85, "slab1", 0.03)
    boxmm(C, "M_Concrete", xs[2] - 0.4, xs[3] + 0.4, ys[0] - 0.4, ys[1] + 0.4, zg + 4.5, zg + 4.85, "slab1b", 0.03)
    boxmm(C, "M_Concrete", xs[0] - 0.4, xs[1] + 0.4, ys[0] - 0.4, ys[2] + 0.4, zg + 9.0, zg + 9.35, "slab2", 0.03)
    ob = boxmm(C, "M_Concrete", -2.4, 2.4, -2.5, 2.5, -0.17, 0.17, "slab_hang", 0.03)          # collapsed corner
    ob.location = (xs[2] + 2.0, ys[2] - 1.0, zg + 2.6); ob.rotation_euler = (math.radians(28), math.radians(-12), 0)
    boxmm(C, "M_Concrete", xs[0] - 0.4, xs[0] + 3.0, ys[1] - 0.4, ys[2] + 0.4, zg + 13.5, zg + 13.8, "slab3", 0.03)
    # infill walls with window holes (built as piers)
    for (y, x_a, x_b, z0) in ((ys[0] - 0.1, xs[0], xs[1], zg), (ys[0] - 0.1, xs[1], xs[2], zg + 4.85), (ys[2] + 0.1, xs[0], xs[1], zg + 4.85)):
        boxmm(C, "M_Concrete", x_a + 0.3, x_a + 1.4, y - 0.12, y + 0.12, z0, z0 + 3.6, "pier", 0.02)
        boxmm(C, "M_Concrete", x_b - 1.4, x_b - 0.3, y - 0.12, y + 0.12, z0, z0 + 3.6, "pier", 0.02)
        boxmm(C, "M_Concrete", x_a + 1.4, x_b - 1.4, y - 0.12, y + 0.12, z0, z0 + 1.0, "spandrel", 0.02)
        boxmm(C, "M_Concrete", x_a + 1.4, x_b - 1.4, y - 0.12, y + 0.12, z0 + 3.0, z0 + 3.6, "lintel", 0.02)
    streaks(D, xs[0], xs[1], ys[0] - 0.24, zg, zg + 3.6, 5, seed + 3)
    for i in range(10):      # rubble heaps
        s = rnd.uniform(0.5, 1.4)
        rockblob(C, (cx + rnd.uniform(-9, 10), cy + rnd.uniform(-7, 7), zg + s * 0.1), (s * 1.4, s, s * 0.6),
                 amp=0.4, seed=seed * 40 + i, sub=1, mat="M_Concrete", name="rubble")
    railing(D, (xs[0], ys[2] + 0.4, zg + 9.35), (xs[1], ys[2] + 0.4, zg + 9.35), h=1.0, spacing=1.4, broken=0.6, seed=seed)

def water_tower(C, D, cx, cy, seed=2):
    zg = G; legh = 12.0; w = 2.6
    corners = [(cx - w, cy - w), (cx + w, cy - w), (cx + w, cy + w), (cx - w, cy + w)]
    for (x, y) in corners:
        ibeam(C, (x, y, zg - 0.6), (x, y, zg + legh), h=0.34, w=0.3)
        boxmm(C, "M_Concrete", x - 0.6, x + 0.6, y - 0.6, y + 0.6, zg - 0.4, zg + 0.5, "footing", 0.04)
    for k in range(4):
        a, b = corners[k], corners[(k + 1) % 4]
        for (z0, z1) in ((zg + 0.5, zg + 6.0), (zg + 6.0, zg + legh)):
            xbrace(C, a, b, z0, z1, 0.08)
        member(C, "M_Steel", (a[0], a[1], zg + 6.0), (b[0], b[1], zg + 6.0), 0.12, 0.16)
    boxmm(C, "M_Grate", cx - w - 0.9, cx + w + 0.9, cy - w - 0.9, cy + w + 0.9, zg + legh, zg + legh + 0.12, "twdeck", 0.0)
    railing(D, (cx - w - 0.9, cy - w - 0.9, zg + legh + 0.12), (cx + w + 0.9, cy - w - 0.9, zg + legh + 0.12), h=1.0, spacing=1.2, broken=0.3, seed=seed)
    railing(D, (cx + w + 0.9, cy - w - 0.9, zg + legh + 0.12), (cx + w + 0.9, cy + w + 0.9, zg + legh + 0.12), h=1.0, spacing=1.2, broken=0.2, seed=seed + 1)
    cyl(C, "M_RustSheet", (cx, cy, zg + legh + 0.12), (cx, cy, zg + legh + 5.2), 3.3, 20, "wtank")
    cyl(C, "M_Rust", (cx, cy, zg + legh + 5.2), (cx, cy, zg + legh + 6.6), 3.45, 20, "wroof", r2=0.5)
    for z in (zg + legh + 1.6, zg + legh + 3.4):
        cyl(C, "M_Steel", (cx, cy, z), (cx, cy, z + 0.14), 3.36, 20, "whoop")
    cyl(C, "M_Steel", (cx, cy, zg - 0.5), (cx, cy, zg + legh), 0.3, 10, "wriser")
    ladder_vis(D, cx + w + 0.35, cy, zg + 0.2, zg + legh, 'y')
    streaks(D, cx - 3.0, cx + 3.0, cy - 3.3, zg + legh, zg + legh + 5.0, 8, seed + 7)

def pump_house(C, D, cx, cy, seed=3):
    """Low concrete pump house with a corrugated mono-pitch roof; a big pipe runs west on saddles to bunker A."""
    zg = G; x0, x1, y0, y1 = cx - 5.0, cx + 5.0, cy - 3.5, cy + 3.5
    boxmm(C, "M_Concrete3", x0, x1, y0, y1, zg - 1.0, zg + 5.0, "pump", 0.06)
    bmw = bmesh.new()
    vs = [bmw.verts.new(v) for v in ((x0 - 0.4, y0 - 0.5, zg + 5.0), (x1 + 0.4, y0 - 0.5, zg + 5.0), (x1 + 0.4, y1 + 0.5, zg + 7.2),
                                     (x0 - 0.4, y1 + 0.5, zg + 7.2), (x0 - 0.4, y1 + 0.5, zg + 5.0), (x1 + 0.4, y1 + 0.5, zg + 5.0))]
    for f in ((0, 1, 2, 3), (0, 4, 5, 1), (4, 3, 2, 5), (0, 3, 4), (1, 5, 2)):
        bmw.faces.new([vs[i] for i in f])
    bmesh.ops.recalc_face_normals(bmw, faces=bmw.faces)
    mk_obj("proof", bmw, "M_Corrugated", C)
    boxmm(D, "M_Silhouette", cx - 1.2, cx + 1.2, y0 - 0.03, y0, zg, zg + 3.0, "pdoor", 0.0)
    windows(D, 'x', y0, x0 + 0.5, x1 - 0.5, zg + 3.5, zg + 4.5, 4, 1, w=1.0, h=0.7, seed=seed, face=-1, skip=0.0)
    streaks(D, x0 + 0.3, x1 - 0.3, y0, zg, zg + 5.0, 8, seed + 1)
    cyl(C, "M_Steel", (x1 - 1.5, cy + 1.0, zg + 6.6), (x1 - 1.5, cy + 1.0, zg + 10.0), 0.35, 10, "pchimney")
    # the pipe: out of the west wall, over to bunker A's east face (73, 4)
    py = cy - 1.2; r = 0.55
    pts = [(x0, py, zg + 1.6), (80.0, py, zg + 1.6), (78.0, 4.0, zg + 1.6), (73.2, 4.0, zg + 1.6)]
    for a, b in zip(pts[:-1], pts[1:]):
        cyl(C, "M_PalePipe", a, b, r, 14, "ppipe")
    for (a, b) in zip(pts[:-1], pts[1:]):
        L = (Vector(b) - Vector(a)).length
        for k in range(1, int(L / 4.0) + 1):
            p = Vector(a).lerp(Vector(b), k / (int(L / 4.0) + 1))
            cyl(C, "M_Steel", (p.x, p.y, zg + 1.6 - r - 0.1), (p.x, p.y, ground_h(p.x, p.y) - 0.6), 0.12, 8, "psaddle")
    cyl(C, "M_Steel", (73.6, 4.0, zg + 1.6), (73.2, 4.0, zg + 1.6), r + 0.12, 14, "pcollar")

def tower_block(C, D, cx, cy, seed=4):
    """Tall ruined tower block (the painting's background towers, brought close): window grid, bands, broken top."""
    zg = G; w, d, h = 7.0, 6.0, 20.0
    x0, x1, y0, y1 = cx - w / 2, cx + w / 2, cy - d / 2, cy + d / 2
    boxmm(C, "M_Concrete2", x0, x1, y0, y1, zg - 2.0, zg + h, "tblock", 0.08)
    rnd = random.Random(seed)
    for k in range(5):          # broken, stepped top
        bx = rnd.uniform(x0, x1 - 2.0); by = rnd.uniform(y0, y1 - 2.0)
        boxmm(C, "M_Concrete2", bx, bx + rnd.uniform(1.5, 3.0), by, by + rnd.uniform(1.5, 3.0), zg + h, zg + h + rnd.uniform(0.8, 3.6), "tbits", 0.05)
    bands(C, x0, x1, y0, y1, [zg + 3.6 * i for i in range(1, 6)], out=0.12, t=0.25)
    for (axis, plane, a0, a1, face, s) in (('x', y0, x0, x1, -1, 1), ('x', y1, x0, x1, 1, 2), ('y', x0, y0, y1, -1, 3), ('y', x1, y0, y1, 1, 4)):
        windows(D, axis, plane, a0 + 0.4, a1 - 0.4, zg + 1.0, zg + h - 1.0, 3, 5, w=0.9, h=1.6, seed=seed * 10 + s, face=face, skip=0.2)
    for k in range(3):
        member(D, "M_Rust", (x0 - 0.6, y0 + 1.0 + k * 2.0, zg + h - 2.0 - k * 3.0), (x1 + 0.6, y0 + 1.0 + k * 2.0, zg + h - 2.0 - k * 3.0), 0.18, 0.18)
    streaks(D, x0 + 0.3, x1 - 0.3, y0, zg, zg + h, 9, seed + 20, face=-1)
    streaks_x(D, x1, y0 + 0.3, y1 - 0.3, zg, zg + h, 7, seed + 21, face=1)
    member(C, "M_Steel", (x0 + 1.0, y1 - 1.0, zg + h), (x0 + 1.0, y1 - 1.0, zg + h + 9.0), 0.16, 0.16)

def pole(C, D, x, y, h=10.0):
    z = ground_h(x, y) - 0.5
    cyl(C, "M_Rust", (x, y, z), (x, y, z + h), 0.17, 8, "pole")
    member(C, "M_Steel", (x - 1.3, y, z + h - 0.6), (x + 1.3, y, z + h - 0.6), 0.12, 0.14)
    for dx in (-1.1, 0.0, 1.1):
        cyl(D, "M_PalePipe", (x + dx, y, z + h - 0.53), (x + dx, y, z + h - 0.25), 0.06, 6, "insul")
    return [(x + dx, y, z + h - 0.3) for dx in (-1.1, 0.0, 1.1)]

def scatter(C, D):
    frame_ruin(C, D, -34.0, 6.0, 11)
    water_tower(C, D, 8.0, 50.0, 12)
    pump_house(C, D, 93.0, 19.0, 13)
    tower_block(C, D, -20.0, 36.0, 14)
    # two lattice pylons, their cables running off the edge into the haze
    for (x, y, far, s) in ((-8.0, -46.0, (-70.0, -150.0, 20.0), 15), (106.0, -28.0, (190.0, 40.0, 30.0), 16)):
        z = ground_h(x, y) - 0.5
        lattice(C, D, x, y, z, 18.0, 2.0, 0.5, s)
        member(C, "M_Steel", (x - 3.2, y, z + 16.5), (x + 3.2, y, z + 16.5), 0.18, 0.22)
        for dx in (-2.8, 2.8):
            wires(D, [(x + dx, y, z + 16.2), (far[0] + dx, far[1], far[2])], sag=2.2)
    # power line: gallery roof -> tall mast -> poles over the ridges -> tower block -> frame ruin
    poles = [pole(C, D, x, y) for (x, y) in ((24.0, 40.0), (6.0, 41.0), (-12.0, 30.5), (-26.0, 17.0))]
    mast = [(38.9, 30.0, 59.5), (40.0, 30.0, 59.6), (41.1, 30.0, 59.5)]
    start = [(53.3, 23.7, 45.4), (55.5, 23.7, 45.4), (57.5, 23.7, 45.4)]
    for k in range(3):
        wires(D, [start[k], mast[k]], sag=1.2)
        wires(D, [mast[k]] + [p[k] for p in poles], sag=1.6)
    wires(D, [poles[-1][1], (-26.5, 1.0, G + 13.5)], sag=1.0)          # onto the frame ruin's tallest column

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
    for i in range(6): pts.append((rnd.choice((rnd.uniform(54.2, 64.4), 66.7)), -37.85, 46.25, 0.5))     # lookout curb
    for i in range(5): pts.append((54.0, rnd.uniform(-37.5, -27.5), 46.9, 0.5))      # west parapet
    for i in range(8): pts.append((rnd.uniform(gx0, gx1), rnd.choice((gy0 + 0.05, gy1 - 0.05)), gz, 0.4))
    # v6: the pinnacle crown, the silo ledges and the ruins
    pcx, pcy, ptop = L5["pinnacle"]
    for i in range(16):
        th = rnd.uniform(0, 2 * math.pi); r = rnd.uniform(5.0, 6.4)
        pts.append((pcx + r * math.cos(th) * 1.08, pcy + r * math.sin(th), ptop - rnd.uniform(0.2, 1.5), rnd.uniform(0.6, 1.1)))
    for i in range(6): pts.append((rnd.choice((63.7, 72.3)), rnd.uniform(-64.3, -60.0), 46.0, 0.45))
    x0, x1, y0, y1, top = L5["silo"]
    for z in (40.3, 46.5, 51.3):
        for i in range(4): pts.append((x1 + 0.12, rnd.uniform(y0, y1), z, 0.5))
    for i in range(6): pts.append((rnd.uniform(x0, x1), y0 - 0.1, 46.5, 0.45))
    for i in range(8): pts.append((rnd.uniform(-41.5, -31.5), rnd.uniform(1.0, 11.0), G + 4.85, 0.6))     # frame ruin slab
    for i in range(5): pts.append((rnd.uniform(-41.5, -36.5), rnd.uniform(1.0, 11.0), G + 9.35, 0.5))
    for i in range(6): pts.append((rnd.uniform(-23.2, -16.8), rnd.uniform(33.2, 38.8), G + 20.0, 0.6))    # tower block top
    # ground: clumps scattered over the plateau where it isn't steep (off the route's middle), more at the foot of walls
    n = 0
    while n < 520:
        th = rnd.uniform(0, 2 * math.pi); r = rim_radius(th) * math.sqrt(rnd.uniform(0.02, 0.97))
        x = CENTER.x + r * math.cos(th); y = CENTER.y + r * math.sin(th)
        if 18.0 < x < 25.5 and -6.5 < y < 0.0: continue          # lift
        if 33.5 < x < 47.0 and 0.0 < y < 6.5: continue           # stair well
        if slope(x, y) > 0.55: continue
        pts.append((x, y, ground_h(x, y) - 0.05, rnd.uniform(0.55, 1.25))); n += 1
    for i in range(60):     # along the foot of the works
        x = rnd.uniform(48, 75); y = rnd.uniform(-40, 26)
        pts.append((x, y, ground_h(x, y) - 0.05, rnd.uniform(0.6, 1.3)))
    for (bx, by, rad) in ((-34.0, 6.0, 10.0), (8.0, 50.0, 5.0), (93.0, 19.0, 7.0), (-20.0, 36.0, 5.5), (94.0, -44.0, 7.0)):
        for i in range(14):
            th = rnd.uniform(0, 2 * math.pi); x = bx + rad * math.cos(th) * rnd.uniform(0.9, 1.15); y = by + rad * math.sin(th) * rnd.uniform(0.9, 1.15)
            pts.append((x, y, ground_h(x, y) - 0.05, rnd.uniform(0.6, 1.2)))
    return pts

def grass():
    C = "S5_GrassC"; s5coll(C)
    rnd = random.Random(9)
    for i, (x, y, z, s) in enumerate(grass_spots()):
        fern(C, (x, y, z), scale=s * 1.25, seed=900 + i, n=rnd.randint(6, 11), mat=("M_Grass" if rnd.random() < 0.7 else "M_GrassDry"), up=1.6)
    return merge_into("S5_Grass", C, uv=False)

# ---------------------------------------------------------------- v8: plants - ivy on the buildings, shrubs, gnarled trees
# All leaf cards (no collision, double-sided flat colours, like the grass). Three objects so Godot can treat them apart:
# S5_Ivy + S5_Shrubs cast no shadows; S5_Trees do. Tree trunks get invisible collision posts (S5_Ramps-colonly).
WIND = Vector((0.85, 0.35, 0.0)).normalized()       # the trees lean away from the west wind

def mats8():
    # (darker + cooler than they look in Blender: the deep-gold sun pushes greens towards yellow)
    for n, col, r in (("M_Ivy", (0.07, 0.16, 0.07), 0.75), ("M_IvyLight", (0.14, 0.26, 0.08), 0.7), ("M_Shrub", (0.1, 0.2, 0.08), 0.8),
                      ("M_ShrubDry", (0.3, 0.28, 0.12), 0.85), ("M_TreeLeaf", (0.12, 0.24, 0.08), 0.75), ("M_Bark", (0.1, 0.085, 0.09), 0.9)):
        flat_mat(n, col, rough=r, double=True)
        b = next(x for x in M(n).node_tree.nodes if x.type == 'BSDF_PRINCIPLED')
        b.inputs["Base Color"].default_value = (*col, 1); M(n).diffuse_color = (*col, 1)

def leaf(bm, c, nrm, size, rnd, tip=None, mi=0):
    """One leaf card: a diamond centred on c, facing nrm, pointing along tip (random in-plane if None)."""
    n = Vector(nrm).normalized()
    if tip is None:
        a = n.orthogonal().normalized()
        tip = Matrix.Rotation(rnd.uniform(0, 2 * math.pi), 3, n) @ a
    t = (Vector(tip) - n * Vector(tip).dot(n)).normalized()
    s = n.cross(t)
    L = size; W = size * 0.55
    vs = [bm.verts.new(c - t * L * 0.35), bm.verts.new(c + s * W * 0.5 + t * L * 0.1),
          bm.verts.new(c + t * L * 0.65), bm.verts.new(c - s * W * 0.5 + t * L * 0.1)]
    f = bm.faces.new(vs); f.material_index = mi
    return f

def strip(bm, pts, w, nrm, mi=0):
    """Flat ribbon along pts (stems), facing nrm."""
    prev = None
    for k, p in enumerate(pts):
        d = (pts[min(k + 1, len(pts) - 1)] - pts[max(k - 1, 0)]).normalized()
        s = d.cross(Vector(nrm)).normalized() * w * (1.0 - 0.6 * k / max(1, len(pts) - 1))
        a = bm.verts.new(p - s); b = bm.verts.new(p + s)
        if prev:
            f = bm.faces.new((prev[0], prev[1], b, a)); f.material_index = mi
        prev = (a, b)

def ivy_wall(bm, axis, plane, a0, a1, z_top, z_bot, face, seed, hang=True, ragged=0.65, density=50.0):
    """A sheet of ivy on a wall: 'x' walls run along x at y = plane, 'y' walls along y at x = plane; face = +-1 is the
    side it grows on. hang: drips from z_top with a ragged lower edge; else climbs from z_bot with a ragged top."""
    rnd = random.Random(seed)
    nrm = Vector((0, face, 0)) if axis == 'x' else Vector((face, 0, 0))
    along = Vector((1, 0, 0)) if axis == 'x' else Vector((0, 1, 0))
    H = z_top - z_bot
    def reach(u):     # how far the sheet reaches at u (0..H)
        v = noise.fractal(Vector((u * 0.55 + seed, seed * 0.3, 1.7)), 0.5, 2.0, 3, noise_basis='PERLIN_ORIGINAL')
        return H * max(0.08, min(1.0, 1.0 - ragged * (0.5 - v)))
    def at(u, v, off):
        x = (a0 + u) if axis == 'x' else plane + face * off
        y = plane + face * off if axis == 'x' else (a0 + u)
        z = (z_top - v) if hang else (z_bot + v)
        return Vector((x, y, z))
    W = a1 - a0
    n = int(density * W * H * 0.55)
    for k in range(n):
        u = rnd.uniform(0, W); r = reach(u)
        v = r * (1.0 - math.sqrt(rnd.random()))         # denser near the root
        p = at(u, v, rnd.uniform(0.03, 0.14))
        lean = Vector((rnd.uniform(-0.5, 0.5), rnd.uniform(-0.5, 0.5), rnd.uniform(-0.2, 0.6)))
        tip = Vector((rnd.uniform(-0.6, 0.6), rnd.uniform(-0.6, 0.6), -1.0 if hang else rnd.uniform(-0.3, 1.0)))
        leaf(bm, p, nrm + lean, rnd.uniform(0.2, 0.36), rnd, tip, 0 if rnd.random() < 0.65 else 1)
    for k in range(max(2, int(W / 1.2))):     # stems
        u = rnd.uniform(0, W); r = reach(u)
        pts = []
        for i in range(9):
            v = r * i / 8 * 1.05
            p = at(u + 0.25 * math.sin(i * 1.3 + k), v, 0.025)
            pts.append(p)
        strip(bm, pts, 0.025, nrm, 2)

def ivy_post(bm, x, y, z0, h, rad, seed, density=75.0):
    """Ivy wound round a leg / column / pole of radius rad from z0 up to (ragged) z0 + h."""
    rnd = random.Random(seed)
    n = int(density * 2 * math.pi * (rad + 0.1) * h * 0.6)
    for k in range(n):
        th = rnd.uniform(0, 2 * math.pi)
        hh = h * (0.6 + 0.4 * math.sin(th * 2 + seed)) * (1.0 - math.sqrt(rnd.random()))
        o = Vector((math.cos(th), math.sin(th), 0))
        p = Vector((x, y, z0 + hh)) + o * (rad + rnd.uniform(0.02, 0.1))
        leaf(bm, p, o + Vector((0, 0, rnd.uniform(-0.2, 0.6))), rnd.uniform(0.18, 0.32), rnd, None, 0 if rnd.random() < 0.6 else 1)
    pts = [Vector((x + (rad + 0.03) * math.cos(t * 0.9), y + (rad + 0.03) * math.sin(t * 0.9), z0 + h * 0.8 * t / 9)) for t in range(10)]
    strip(bm, pts, 0.025, Vector((0, 0, 1)), 2)

def leaf_cloud(bm, c, r, rz, rnd, density=55.0, mi=0, mi2=None, size=(0.16, 0.3)):
    """Leaves filling an ellipsoid (r, r, rz) round c, facing out (shrubs, tree crowns)."""
    n = int(density * r * r * (rz / max(r, 0.01)) * 1.4) + 12
    for k in range(n):
        d = Vector((rnd.gauss(0, 1), rnd.gauss(0, 1), rnd.gauss(0, 1))).normalized()
        f = rnd.random() ** 0.35
        p = c + Vector((d.x * r, d.y * r, d.z * rz)) * f
        mi_ = mi if (mi2 is None or rnd.random() < 0.7) else mi2
        leaf(bm, p, d + Vector((0, 0, 0.4)), rnd.uniform(*size), rnd, None, mi_)

def tube(bm, pts, radii, sides=6, mi=0):
    """Tapered tube along pts (parallel-transported frame: no twisting)."""
    rings = []; a = None
    for k, p in enumerate(pts):
        d = (pts[min(k + 1, len(pts) - 1)] - pts[max(k - 1, 0)]).normalized()
        if a is None:
            a = d.orthogonal().normalized()
        else:
            a = (a - d * a.dot(d)).normalized()
        b = d.cross(a)
        rings.append([bm.verts.new(p + (a * math.cos(2 * math.pi * i / sides) + b * math.sin(2 * math.pi * i / sides)) * radii[k])
                      for i in range(sides)])
    for k in range(len(rings) - 1):
        for i in range(sides):
            f = bm.faces.new((rings[k][i], rings[k][(i + 1) % sides], rings[k + 1][(i + 1) % sides], rings[k + 1][i]))
            f.material_index = mi

def branch(bmB, p0, d, length, r0, depth, rnd, tips):
    n = max(3, int(length / 0.45))
    pts = [Vector(p0)]; radii = [r0]; dr = Vector(d).normalized()
    for i in range(1, n + 1):
        dr = (dr + Vector((rnd.uniform(-0.38, 0.38), rnd.uniform(-0.38, 0.38), rnd.uniform(-0.12, 0.2))) + WIND * 0.1).normalized()
        pts.append(pts[-1] + dr * (length / n)); radii.append(max(0.018, r0 * (1.0 - 0.82 * i / n)))
    tube(bmB, pts, radii, 6 if depth == 0 else 5, 0)
    if depth < 2:
        for k in range(rnd.randint(2, 3) if depth == 0 else rnd.randint(1, 3)):
            idx = int(rnd.uniform(0.45, 0.92) * n)
            th = rnd.uniform(0, 2 * math.pi)
            nd = (dr * 0.35 + Vector((math.cos(th), math.sin(th), 0)) + Vector((0, 0, 0.45)) + WIND * 0.35).normalized()
            branch(bmB, pts[idx], nd, length * rnd.uniform(0.42, 0.62), radii[idx] * 0.72, depth + 1, rnd, tips)
    tips.append((pts[-1], depth))

def gnarled_tree(bmB, bmL, x, y, h, seed, leafy=True):
    rnd = random.Random(seed)
    z = ground_h(x, y)
    tips = []
    lean = Vector((0, 0, 1)) + WIND * rnd.uniform(0.25, 0.6)
    branch(bmB, (x, y, z - 0.4), lean, h * 0.62, rnd.uniform(0.26, 0.4), 0, rnd, tips)
    if leafy:
        for (p, depth) in tips:
            if depth == 0 and rnd.random() < 0.5: continue
            r = rnd.uniform(0.9, 1.7) * (1.0 if depth else 1.3)
            leaf_cloud(bmL, p + Vector((0, 0, r * 0.2)) + WIND * 0.2, r, r * 0.6, rnd, density=48.0, mi=0, mi2=1, size=(0.22, 0.38))
    return z

def shrub(bm, x, y, r, seed, dry=False, z=None):
    rnd = random.Random(seed)
    z = ground_h(x, y) if z is None else z
    rz = r * rnd.uniform(0.55, 0.85)
    m0 = 1 if dry else 0
    for k in range(rnd.randint(1, 3)):        # a few lobes
        c = Vector((x + rnd.uniform(-r, r) * 0.45, y + rnd.uniform(-r, r) * 0.45, z + rz * 0.55))
        leaf_cloud(bm, c, r * rnd.uniform(0.6, 0.9), rz * rnd.uniform(0.7, 1.0), rnd, density=60.0, mi=m0, mi2=(1 if not dry else 0))
    for k in range(5):                         # twigs poking out
        th = rnd.uniform(0, 2 * math.pi)
        a = Vector((x, y, z - 0.05)); b = a + Vector((math.cos(th) * r * 1.1, math.sin(th) * r * 1.1, rz * rnd.uniform(1.0, 1.7)))
        tube(bm, [a, a.lerp(b, 0.5) + Vector((0, 0, 0.1)), b], [0.03, 0.02, 0.01], 4, 2)

# where nothing grows: the route's main lines, the lift landing, the stair well, building footprints
KEEP_CLEAR_SEGS = [((24.0, -3.0), (43.0, 12.0), 3.2), ((18.0, -3.0), (30.0, -3.0), 4.5), ((43.0, 12.0), (50.0, 12.0), 2.2)]
KEEP_CLEAR_BOXES = [(50.0, 62.5, 8.5, 24.5), (61.0, 74.5, -12.0, 9.5), (54.5, 61.5, -11.5, 0.3), (53.5, 67.5, -38.5, -26.5),
                    (89.5, 98.5, -50.5, -37.5), (87.5, 98.5, 15.0, 23.0), (-24.0, -16.0, 32.5, 39.5), (-42.5, -25.5, 0.0, 12.0),
                    (4.0, 12.0, 46.0, 54.0), (17.0, 24.5, -7.0, 0.5), (32.5, 48.0, -0.5, 7.0), (85.5, 98.5, -60.5, -49.5),
                    (56.5, 59.5, -27.0, -11.0), (63.0, 73.0, -65.0, -55.0)]

def clear_spot(x, y, pad=0.0):
    for (x0, x1, y0, y1) in KEEP_CLEAR_BOXES:
        if x0 - pad < x < x1 + pad and y0 - pad < y < y1 + pad: return False
    p = Vector((x, y))
    for (a, b, r) in KEEP_CLEAR_SEGS:
        a = Vector(a); b = Vector(b); ab = b - a
        t = max(0.0, min(1.0, (p - a).dot(ab) / ab.length_squared))
        if (a + ab * t - p).length < r + pad: return False
    th = math.atan2(y - CENTER.y, x - CENTER.x)
    return (p - CENTER).length < rim_radius(th) * 0.93

def ivy(bm):
    W = ivy_wall
    # bunker A: hanging from the roof edge along the north face, climbing at both ends (the door stays clear)
    W(bm, 'x', 9.0, 61.5, 73.0, 44.0, 38.9, 1, 101, hang=True, ragged=0.8)
    W(bm, 'x', 9.0, 61.6, 65.4, G + 9.0, G, 1, 102, hang=False)
    W(bm, 'x', 9.0, 69.2, 72.9, G + 7.5, G, 1, 103, hang=False)
    W(bm, 'y', 73.0, 0.0, 8.8, G + 8.0, G, 1, 104, hang=False, ragged=0.8)
    W(bm, 'y', 61.5, 0.2, 8.8, G + 4.6, G, -1, 105, hang=False)
    # bunker B: a big sheet up the south face, a curtain off the cap, the east face
    W(bm, 'x', -11.5, 61.2, 73.3, G + 13.0, G, -1, 111, hang=False, ragged=0.9, density=22.0)
    W(bm, 'x', -11.5, 62.0, 72.5, 56.0, 51.0, -1, 112, hang=True)
    W(bm, 'y', 73.5, -11.3, -0.4, G + 10.0, G, 1, 113, hang=False, ragged=0.9)
    W(bm, 'y', 61.0, -11.3, -6.0, G + 6.0, G, -1, 114, hang=False)
    # block C: west face (both ways), off the south parapet over the cove, north face, east face either side of the door
    W(bm, 'y', 54.0, -38.0, -27.0, G + 8.0, G, -1, 121, hang=False, ragged=0.9)
    W(bm, 'y', 54.0, -38.0, -29.0, 46.9, 42.5, -1, 122, hang=True)
    W(bm, 'x', -38.0, 54.2, 66.8, 46.25, 40.0, -1, 123, hang=True, ragged=0.85)
    W(bm, 'x', -27.0, 59.5, 66.8, G + 6.0, G, 1, 124, hang=False)
    W(bm, 'y', 67.0, -37.8, -34.5, G + 7.0, G, 1, 125, hang=False)
    W(bm, 'y', 67.0, -30.5, -27.2, G + 9.0, G, 1, 126, hang=False)
    # the silo: east face (door clear), under the landing on the south face
    W(bm, 'y', 98.0, -49.6, -46.0, G + 15.0, G, 1, 131, hang=False, ragged=0.9)
    W(bm, 'y', 98.0, -41.8, -38.4, G + 11.0, G, 1, 132, hang=False)
    W(bm, 'x', -50.0, 90.3, 92.2, G + 9.5, G, -1, 133, hang=False)
    W(bm, 'x', -50.0, 95.8, 97.8, G + 8.0, G, -1, 134, hang=False)
    # pump house: north + east faces nearly covered, a strip on the west
    W(bm, 'x', 22.5, 88.0, 98.0, G + 5.0, G, 1, 141, hang=False, ragged=0.5)
    W(bm, 'y', 98.0, 15.5, 22.5, G + 5.0, G, 1, 142, hang=False, ragged=0.5)
    W(bm, 'y', 88.0, 19.0, 22.4, G + 4.0, G, -1, 143, hang=False)
    # tower block: overgrown on every face
    for k, (axis, plane, a0, a1, face) in enumerate((('x', 33.0, -23.5, -16.5, -1), ('x', 39.0, -23.5, -16.5, 1),
                                                     ('y', -23.5, 33.0, 39.0, -1), ('y', -16.5, 33.0, 39.0, 1))):
        zb = ground_h((a0 + a1) / 2 if axis == 'x' else plane, plane if axis == 'x' else (a0 + a1) / 2) - 0.3
        W(bm, axis, plane, a0, a1, zb + rnd_h(k), zb, face, 151 + k, hang=False, ragged=0.9, density=22.0)
        W(bm, axis, plane, a0 + 0.5, a1 - 0.5, G + 20.0, G + 15.5, face, 155 + k, hang=True)
    # frame ruin: curtains off the broken slabs, ivy up the columns
    W(bm, 'x', 0.6, -41.9, -31.1, G + 4.5, G + 1.8, -1, 161, hang=True, ragged=0.8)
    W(bm, 'x', 11.4, -41.9, -36.1, G + 9.0, G + 6.6, 1, 162, hang=True, ragged=0.8)
    W(bm, 'y', -41.9, 1.0, 11.0, G + 9.0, G + 6.0, -1, 163, hang=True, ragged=0.8)
    for k, (x, y, h) in enumerate(((-41.5, 1.0, 7.0), (-36.5, 6.0, 4.0), (-31.5, 11.0, 5.5), (-26.5, 1.0, 8.0), (-41.5, 11.0, 9.0))):
        ivy_post(bm, x, y, ground_h(x, y) - 0.2, h, 0.3, 170 + k)
    # gallery: drips off the deck edge and the roof slab (kept short over the walkway)
    W(bm, 'x', 24.0, 50.0, 62.0, 40.0, 36.8, 1, 181, hang=True, ragged=0.85)
    W(bm, 'x', 15.0, 53.0, 62.0, 44.1, 42.9, -1, 182, hang=True, ragged=0.5)
    W(bm, 'x', 24.0, 53.0, 62.0, 44.1, 41.6, 1, 183, hang=True, ragged=0.8)
    W(bm, 'y', 62.0, 15.0, 24.0, 44.1, 42.0, 1, 184, hang=True, ragged=0.8)
    # legs: the K tower, the water tower, the lift headframe, power poles, the tall mast
    for k, (x, y, h, r) in enumerate(((55.0, -11.0, 9.0, 0.24), (61.0, -11.0, 6.0, 0.24), (55.0, -0.2, 5.0, 0.24),
                                      (5.4, 47.4, 8.0, 0.22), (10.6, 52.6, 6.0, 0.22), (10.6, 47.4, 4.5, 0.22),
                                      (18.1, -6.3, 3.6, 0.32), (23.3, -6.3, 2.6, 0.32), (18.1, -0.3, 2.2, 0.32),
                                      (24.0, 40.0, 6.0, 0.2), (-12.0, 30.5, 7.5, 0.2), (40.0, 30.0, 11.0, 0.2))):
        ivy_post(bm, x, y, ground_h(x, y) - 0.2, h, r, 190 + k)

def rnd_h(k):
    return (11.0, 15.0, 9.0, 13.0)[k % 4]

def plants(R):
    mats8()
    C = "S5_FloraC"; s5coll(C)
    # ivy
    bm = bmesh.new(); ivy(bm)
    ob = mk_obj("S5_Ivy", bm, "M_Ivy", C); ob.data.materials.append(M("M_IvyLight")); ob.data.materials.append(M("M_Bark"))
    # shrubs: at the foot of the buildings, among the boulders and ruins, scattered over the plateau, a few in the collapse
    rnd = random.Random(808)
    bm = bmesh.new(); spots = []
    feet = [((61.5, 73.0), 9.0, 'x', 1), ((73.0, 0.0, 9.0), None, 'y', 1), ((61.0, 73.5), -11.5, 'x', -1), ((54.0, -38.0, -27.0), None, 'y', -1),
            ((54.0, 67.0), -27.0, 'x', 1), ((98.0, -50.0, -38.0), None, 'y', 1), ((88.0, 98.0), 22.5, 'x', 1), ((98.0, 15.5, 22.5), None, 'y', 1),
            ((-23.5, -16.5), 39.0, 'x', 1), ((-16.5, 33.0, 39.0), None, 'y', 1), ((-23.5, -16.5), 33.0, 'x', -1)]
    for (span, plane, axis, face) in feet:
        for k in range(4):
            if axis == 'x':
                x = rnd.uniform(span[0] + 0.5, span[1] - 0.5); y = plane + face * rnd.uniform(0.7, 1.5)
            else:
                x = span[0] + face * rnd.uniform(0.7, 1.5); y = rnd.uniform(span[1] + 0.5, span[2] - 0.5)
            spots.append((x, y, rnd.uniform(0.6, 1.2)))
    for (x, y, s) in [(4, 14, 2.4), (-6, -16, 3.0), (12, -26, 1.8), (30, 22, 2.0), (2, 30, 3.4), (80, 4, 2.6), (80, 30, 2.2),
                      (36, -30, 2.0), (-14, 6, 2.8), (46, 34, 1.6), (88, -14, 3.0), (22, 34, 1.4), (-30, -20, 2.6)]:
        for k in range(2):      # beside the boulders
            th = rnd.uniform(0, 2 * math.pi)
            spots.append((x + math.cos(th) * (s * 1.3 + 0.6), y + math.sin(th) * (s + 0.6), rnd.uniform(0.6, 1.2)))
    for k in range(10):         # round the frame ruin
        spots.append((-34.0 + rnd.uniform(-10, 10), 6.0 + rnd.uniform(-8, 8), rnd.uniform(0.5, 1.1)))
    n = 0
    while n < 70:
        th = rnd.uniform(0, 2 * math.pi); r = rim_radius(th) * math.sqrt(rnd.uniform(0.02, 0.9))
        x = CENTER.x + r * math.cos(th); y = CENTER.y + r * math.sin(th)
        if slope(x, y) > 0.45: continue
        spots.append((x, y, rnd.uniform(0.7, 1.7))); n += 1
    n_feet = len(feet) * 4      # building-foot spots sit just inside the footprint boxes' margins: exempt
    kept = 0
    for i, (x, y, s) in enumerate(spots):
        if i >= n_feet and not clear_spot(x, y, 0.3): continue
        if slope(x, y) > 0.6: continue
        shrub(bm, x, y, s, 2000 + i, dry=rnd.random() < 0.3); kept += 1
    for i, (x, y) in enumerate(((36.4, 4.9), (45.3, 1.3), (39.0, 5.2))):      # weeds on the collapse heap in the well
        shrub(bm, x, y, 0.4, 2900 + i, z=G - 0.8)
    ob = mk_obj("S5_Shrubs", bm, "M_Shrub", C); ob.data.materials.append(M("M_ShrubDry")); ob.data.materials.append(M("M_Bark"))
    # trees: gnarled, wind-bent, some dead
    bmB = bmesh.new(); bmL = bmesh.new()
    cands = [(-28.0, 14.0, 7.0), (-45.0, -2.0, 6.0), (14.5, 55.0, 6.5), (1.0, 45.0, 5.0), (101.0, 27.0, 7.5), (85.0, 26.0, 5.0),
             (-11.0, 41.0, 6.0), (-27.0, 29.0, 7.0), (10.0, 20.0, 5.5), (28.0, 27.0, 6.5), (-6.0, -21.0, 7.0), (19.0, -28.0, 5.0),
             (78.0, -1.0, 6.0), (71.0, -31.0, 5.5), (83.0, -45.0, 5.0), (-18.0, -6.0, 6.5), (46.0, 30.0, 5.0), (-40.0, 22.0, 6.0)]
    rnd = random.Random(909); planted = []
    for i, (x, y, h) in enumerate(cands):
        if not clear_spot(x, y, 1.0) or slope(x, y) > 0.5:
            print("tree skipped", (x, y)); continue
        z = gnarled_tree(bmB, bmL, x, y, h * rnd.uniform(1.25, 1.55), 3000 + i, leafy=(i % 4 != 3))
        cyl(R, None, (x, y, z - 0.5), (x, y, z + 2.2), 0.42, 8, "trunk_col")
        planted.append((x, y))
    T = "S5_TreesC"; s5coll(T)
    mk_obj("tree_bark", bmB, "M_Bark", T)
    lv = mk_obj("tree_leaves", bmL, "M_TreeLeaf", T); lv.data.materials.append(M("M_IvyLight"))
    merge_into("S5_Trees", T, uv=False)
    print("plants:", kept, "shrubs,", len(planted), "trees")

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

def spire_layout():
    rnd = random.Random(42)
    out = []
    for i in range(44):
        th = rnd.uniform(0, 2 * math.pi)
        d = rnd.uniform(170.0, 620.0)
        if i < 7:         # a few nearer ones off the cove (south-east) and behind the works (east)
            th = rnd.uniform(-1.5, 0.35); d = rnd.uniform(140.0, 230.0)
        d += 30.0         # v6: the mesa is ~1.5x wider
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
def build_structures():
    C, D, R = "S5_WorksC", "S5_DetailC", "S5_RampsC"
    for c in (C, D, R): s5coll(c)
    stairwell(C, D, R)
    lift_collar(C, D)
    works(C, D, R)
    cove(C, D, R)
    scatter(C, D)
    plants(R)                  # v8 (trunk collision posts go into R)
    merge_into("S5_Works-col", C)
    merge_into("S5_Detail", D)
    ramps = merge_into("S5_Ramps-colonly", R, uv=False)
    ramps.data.materials.clear()

def build_all():
    mats5()
    mesa()
    build_structures()
    grass(); spires()
    # the lift headframe is shared with the cavern (Lift3-col, built by v3_lift_tunnel.py)
    if "Lift3-col" not in S5.collection.objects:
        S5.collection.objects.link(bpy.data.objects["Lift3-col"])
    with open(os.path.join(PROJ, "art_src", "surface.json"), "w") as f:
        json.dump({"layout": L5, "spires": [list(s[:4]) for s in spire_layout()]}, f, indent=1)
    print("surface built:", [(o.name, len(o.data.vertices)) for o in S5.objects if o.type == 'MESH'])

def export_all():
    names = ["S5_Mesa-col", "S5_Works-col", "S5_Detail", "S5_Ramps-colonly", "S5_Grass", "S5_Spires", "Lift3-col",
             "S5_Ivy", "S5_Shrubs", "S5_Trees"]
    sc = bpy.context.scene
    tmp = bpy.data.collections.new("_EXPORT_TMP"); sc.collection.children.link(tmp)
    for n in names:
        if n not in sc.objects:
            tmp.objects.link(bpy.data.objects[n])
    bpy.context.view_layer.update()
    for o in sc.objects:
        o.select_set(o.name in names)
    bpy.ops.export_scene.gltf(filepath=os.path.join(PROJ, "assets", "level", "surface.glb"), export_format='GLB', use_selection=True,
                              use_active_scene=True, export_apply=True, export_yup=True,
                              export_vertex_color='NAME', export_vertex_color_name='TerrainMask')   # the mesa's layer mask
    sc.collection.children.unlink(tmp); bpy.data.collections.remove(tmp)
    print("exported surface.glb")
