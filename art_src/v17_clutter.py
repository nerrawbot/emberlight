# v17: ground clutter kit for the surface (the mesa looked empty between the works): boulders, pebbles, concrete rubble,
# broken slabs with rebar, oil drums, a fallen girder, a concrete pipe section, scrap sheet, a tyre, planks, a cable reel
# and grass tufts. Each piece is its own object/glTF node, built at the origin standing on z = 0 (sunk a little below
# so it sits in the ground on slopes); tools/bake_clutter.gd scatters them over the terrain collision as MultiMeshes and
# writes scenes/surface_clutter.tscn. Materials keep the surface's names (M_Concrete2, M_RustSheet, M_Steel, M_Corrugated ...)
# so painterly_world.gd's TUNE applies.
# Self-contained. Builds into scene "Props17" / collection CLUTTER17 and exports assets/props/clutter.glb:
#   D:\Blender\blender.exe --background --factory-startup --python art_src\v17_clutter.py
import bpy, bmesh, math, os, random
from mathutils import Vector, Matrix, noise

PROJ = r"D:\Emberlight"
OUT = os.path.join(PROJ, "assets", "props", "clutter.glb")
TEX = os.path.join(PROJ, "art_src", "tex")
COLL = "CLUTTER17"

if "Props17" not in bpy.data.scenes:
    bpy.data.scenes.new("Props17")
SC = bpy.data.scenes["Props17"]
coll = bpy.data.collections.get(COLL) or bpy.data.collections.new(COLL)
if coll.name not in SC.collection.children:
    SC.collection.children.link(coll)
for o in list(coll.objects):
    bpy.data.objects.remove(o, do_unlink=True)

# ---------------------------------------------------------------------------------------------- materials
def _img(name, cs):
    i = bpy.data.images.load(os.path.join(TEX, name), check_existing=True)
    i.colorspace_settings.name = cs
    return i

def pbr(name, key, normal_strength=1.0):
    """Poly Haven set art_src/tex/<key>_{albedo,orm,normal}.jpg (already graded to the palette)."""
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    b = nt.nodes.new("ShaderNodeBsdfPrincipled")
    nt.links.new(b.outputs[0], out.inputs[0])
    ta = nt.nodes.new("ShaderNodeTexImage"); ta.image = _img(key + "_albedo.jpg", "sRGB")
    to = nt.nodes.new("ShaderNodeTexImage"); to.image = _img(key + "_orm.jpg", "Non-Color")
    tn = nt.nodes.new("ShaderNodeTexImage"); tn.image = _img(key + "_normal.jpg", "Non-Color")
    sep = nt.nodes.new("ShaderNodeSeparateColor")
    nm = nt.nodes.new("ShaderNodeNormalMap"); nm.inputs["Strength"].default_value = normal_strength
    nt.links.new(ta.outputs["Color"], b.inputs["Base Color"])
    nt.links.new(to.outputs["Color"], sep.inputs[0])
    nt.links.new(sep.outputs[1], b.inputs["Roughness"])
    nt.links.new(sep.outputs[2], b.inputs["Metallic"])
    nt.links.new(tn.outputs["Color"], nm.inputs["Color"])
    nt.links.new(nm.outputs[0], b.inputs["Normal"])
    return m

def flat(name, col, rough=0.9, metal=0.0, double=False):
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.use_nodes = True
    b = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    b.inputs["Base Color"].default_value = (*col, 1.0)
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    m.diffuse_color = (*col, 1.0)
    m.use_backface_culling = not double
    return m

MAT = {
    "rock": pbr("M_ClutterRock", "mesa_cliff"),
    "conc": pbr("M_Concrete2", "concrete2"),
    "conc3": pbr("M_Concrete3", "concrete3", 0.8),
    "rust": pbr("M_RustSheet", "rustsheet"),
    "steel": pbr("M_Steel", "steel"),
    "corr": pbr("M_Corrugated", "corr"),
    "wood": flat("M_WoodOld", (0.25, 0.2, 0.16), 0.85),
    "rubber": flat("M_Rubber", (0.05, 0.05, 0.06), 0.9),
    "rebar": flat("M_Rebar", (0.2, 0.11, 0.07), 0.7, 0.3),
    # tufts get their own, duller grass than the surface's leafy M_Grass (thousands of them read as a glowing carpet)
    "grass": flat("M_TuftGreen", (0.2, 0.27, 0.09), 0.85, double=True),
    "dry": flat("M_TuftDry", (0.36, 0.31, 0.15), 0.9, double=True),
}
MAT["corr"].use_backface_culling = False       # the scrap sheet is a single skin
TILE = {"M_ClutterRock": 2.2, "M_Concrete2": 1.6, "M_Concrete3": 1.6, "M_RustSheet": 1.1, "M_Steel": 1.2,
        "M_Corrugated": 1.4}

# ---------------------------------------------------------------------------------------------- mesh builder
class Mesh:
    """One clutter piece: a bmesh with a material slot list; parts are added in object space."""
    def __init__(self, mats):
        self.bm = bmesh.new()
        self.mats = list(mats)

    def add(self, other_bm, mat, matrix=None):
        """Merge a temporary bmesh (freed) into this one with material `mat`."""
        if matrix is not None:
            bmesh.ops.transform(other_bm, matrix=matrix, verts=other_bm.verts)
        for f in other_bm.faces:
            f.material_index = self.mats.index(mat)
        me = bpy.data.meshes.new("_tmp")
        other_bm.to_mesh(me); other_bm.free()
        self.bm.from_mesh(me)
        bpy.data.meshes.remove(me)

    def obj(self, name, x):
        me = bpy.data.meshes.new(name)
        for k in self.mats:
            me.materials.append(MAT[k])
        bm = self.bm
        bm.normal_update()
        uv = bm.loops.layers.uv.verify()
        for f in bm.faces:
            t = TILE.get(me.materials[f.material_index].name, 1.0)
            n = f.normal
            ax = max(range(3), key=lambda i: abs(n[i]))
            for l in f.loops:
                c = l.vert.co
                if ax == 0: u, v = c.y * (1 if n.x > 0 else -1), c.z
                elif ax == 1: u, v = c.x * (-1 if n.y > 0 else 1), c.z
                else: u, v = c.x, c.y * (1 if n.z > 0 else -1)
                l[uv].uv = (u / t, v / t)
        bm.to_mesh(me); bm.free()
        for p in me.polygons:
            p.use_smooth = False
        ob = bpy.data.objects.new(name, me)
        ob.location = (x, 0, 0)          # laid out in a row for a look in Blender; the bake only reads the mesh
        coll.objects.link(ob)
        return ob

def cube(size, center=(0, 0, 0)):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=size, verts=bm.verts)
    bmesh.ops.translate(bm, vec=center, verts=bm.verts)
    return bm

def chop(bm, rnd, cuts, depth=0.3):
    """Fracture: slice off `cuts` random corners/edges (flat cut faces, like broken concrete or split stone)."""
    for _ in range(cuts):
        vs = [v.co.copy() for v in bm.verts]
        lo = Vector([min(c[i] for c in vs) for i in range(3)])
        hi = Vector([max(c[i] for c in vs) for i in range(3)])
        n = Vector((rnd.uniform(-1, 1), rnd.uniform(-1, 1), rnd.uniform(-0.3, 1))).normalized()
        far = max(vs, key=lambda c: c.dot(n))
        co = far - n * (hi - lo).length * rnd.uniform(0.08, depth)
        geom = list(bm.verts) + list(bm.edges) + list(bm.faces)
        res = bmesh.ops.bisect_plane(bm, geom=geom, plane_co=co, plane_no=n, clear_outer=True)
        cut_edges = [e for e in res["geom_cut"] if isinstance(e, bmesh.types.BMEdge)]
        if cut_edges:
            bmesh.ops.holes_fill(bm, edges=cut_edges, sides=0)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm

def chunk(rnd, s):
    """A broken concrete lump about s metres across."""
    bm = cube((s * rnd.uniform(0.8, 1.4), s * rnd.uniform(0.7, 1.1), s * rnd.uniform(0.45, 0.8)))
    return chop(bm, rnd, rnd.randint(3, 5), 0.35)

def stone(rnd, size, sub=2, amp=0.22, facets=4):
    """Boulder: a displaced icosphere, then a few flat facets cut off (reads like the faceted spires)."""
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=sub, radius=1.0)
    bmesh.ops.scale(bm, vec=size, verts=bm.verts)
    bm.normal_update()
    off = Vector((rnd.uniform(-50, 50), rnd.uniform(-50, 50), rnd.uniform(-50, 50)))
    m = min(size)
    for v in bm.verts:
        v.co += v.normal * amp * m * noise.fractal(v.co * 1.3 + off, 0.6, 2.0, 3, noise_basis="PERLIN_ORIGINAL")
    return chop(bm, rnd, facets, 0.18)

def rod(p0, p1, r, seg=6):
    p0 = Vector(p0); p1 = Vector(p1)
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=seg, radius1=r, radius2=r, depth=(p1 - p0).length)
    q = (p1 - p0).normalized().to_track_quat("Z", "Y")
    bmesh.ops.transform(bm, matrix=Matrix.Translation((p0 + p1) / 2) @ q.to_matrix().to_4x4(), verts=bm.verts)
    return bm

def bent_rebar(M, rnd, base, length):
    """A bent rebar stub sticking out of broken concrete."""
    d = Vector((rnd.uniform(-0.6, 0.6), rnd.uniform(-0.6, 0.6), 1)).normalized()
    mid = Vector(base) + d * length * 0.55
    d2 = (d + Vector((rnd.uniform(-1, 1), rnd.uniform(-1, 1), -0.4))).normalized()
    M.add(rod(base, mid, 0.012), "rebar")
    M.add(rod(mid, mid + d2 * length * 0.45, 0.012), "rebar")

def tube(r_out, r_in, length, seg=16):
    """Open pipe along X, centred."""
    bm = bmesh.new()
    rings = []
    for x in (-length / 2, length / 2):
        for r in (r_out, r_in):
            rings.append([bm.verts.new((x, r * math.cos(2 * math.pi * i / seg), r * math.sin(2 * math.pi * i / seg)))
                          for i in range(seg)])
    o0, i0, o1, i1 = rings
    for i in range(seg):
        j = (i + 1) % seg
        bm.faces.new((o0[i], o0[j], o1[j], o1[i]))      # outside
        bm.faces.new((i0[j], i0[i], i1[i], i1[j]))      # inside
        bm.faces.new((o0[j], o0[i], i0[i], i0[j]))      # end rings
        bm.faces.new((o1[i], o1[j], i1[j], i1[i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm

def torus(R, r, seg=18, rseg=8):
    bm = bmesh.new()
    ring = []
    for i in range(seg):
        a = 2 * math.pi * i / seg
        ring.append([bm.verts.new(((R + r * math.cos(b)) * math.cos(a), (R + r * math.cos(b)) * math.sin(a), r * math.sin(b)))
                     for b in (2 * math.pi * k / rseg for k in range(rseg))])
    for i in range(seg):
        for k in range(rseg):
            a, b = ring[i], ring[(i + 1) % seg]
            bm.faces.new((a[k], b[k], b[(k + 1) % rseg], a[(k + 1) % rseg]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm

def Rz(deg): return Matrix.Rotation(math.radians(deg), 4, "Z")
def Ry(deg): return Matrix.Rotation(math.radians(deg), 4, "Y")
def Rx(deg): return Matrix.Rotation(math.radians(deg), 4, "X")
def T(x, y, z): return Matrix.Translation((x, y, z))

built = []
X = [0.0]
def done(M, name, width):
    built.append(M.obj(name, X[0] + width / 2))
    X[0] += width + 0.8
# ---------------------------------------------------------------------------------------------- rocks
for name, size, seed, sink in (("RockA", (0.8, 0.65, 0.55), 1, 0.12), ("RockB", (0.45, 0.4, 0.35), 2, 0.08),
                               ("RockC", (0.95, 0.6, 0.22), 3, 0.05)):
    rnd = random.Random(seed)
    M = Mesh(["rock"])
    M.add(stone(rnd, size, facets=5), "rock", T(0, 0, size[2] * 0.75 - sink))
    done(M, name, size[0] * 2)

rnd = random.Random(4)                       # pebbles: a loose spread of small stones, no collision
M = Mesh(["rock"])
for k in range(9):
    s = rnd.uniform(0.06, 0.16)
    a = rnd.uniform(0, 2 * math.pi); d = rnd.uniform(0.0, 0.9)
    M.add(stone(rnd, (s * 1.3, s, s * 0.7), sub=1, facets=2), "rock",
          T(math.cos(a) * d, math.sin(a) * d, s * 0.35) @ Rz(rnd.uniform(0, 360)))
done(M, "Pebbles", 2.0)

# ---------------------------------------------------------------------------------------------- concrete
rnd = random.Random(11)                      # rubble heap: big lumps at the bottom, smaller on top, rebar
M = Mesh(["conc", "conc3", "rebar"])
for k in range(13):
    t = k / 13.0
    s = 0.55 - t * 0.33
    a = rnd.uniform(0, 2 * math.pi); d = (1.0 - t) * rnd.uniform(0.3, 0.9)
    z = t * 0.45 + s * 0.15
    M.add(chunk(rnd, s), "conc" if rnd.random() < 0.75 else "conc3",
          T(math.cos(a) * d, math.sin(a) * d, z) @ Rz(rnd.uniform(0, 360)) @ Rx(rnd.uniform(-25, 25)))
for k in range(3):
    a = rnd.uniform(0, 2 * math.pi)
    bent_rebar(M, rnd, (math.cos(a) * 0.3, math.sin(a) * 0.3, 0.35), rnd.uniform(0.5, 0.9))
done(M, "RubbleA", 2.2)

rnd = random.Random(12)                      # rubble scatter: low lumps, ankle-high (walkable, no collision)
M = Mesh(["conc", "conc3"])
for k in range(7):
    s = rnd.uniform(0.12, 0.28)
    a = rnd.uniform(0, 2 * math.pi); d = rnd.uniform(0.0, 1.1)
    M.add(chunk(rnd, s), "conc" if k % 3 else "conc3", T(math.cos(a) * d, math.sin(a) * d, s * 0.18) @ Rz(rnd.uniform(0, 360)))
done(M, "RubbleB", 2.4)

rnd = random.Random(13)                      # broken floor slab propped on a lump, rebar out of the broken edge
M = Mesh(["conc", "rebar"])
slab = chop(cube((2.2, 1.4, 0.18)), rnd, 3, 0.3)
M.add(chunk(rnd, 0.35), "conc", T(0.7, 0.0, 0.1))
M.add(slab, "conc", T(0.0, 0.0, 0.32) @ Ry(-11) @ Rx(4))
for k in range(4):
    y = -0.5 + k * 0.33
    bent_rebar(M, rnd, (-1.0, y, 0.12), rnd.uniform(0.35, 0.6))
done(M, "SlabA", 2.6)

rnd = random.Random(14)                      # cut stone / kerb blocks: low, sit along walls
M = Mesh(["conc3"])
M.add(chop(cube((1.1, 0.35, 0.3)), rnd, 2, 0.2), "conc3", T(0, 0, 0.12))
M.add(chop(cube((0.6, 0.35, 0.3)), rnd, 2, 0.2), "conc3", T(0.95, 0.1, 0.1) @ Rz(14))
done(M, "Kerb", 2.0)

# ---------------------------------------------------------------------------------------------- metal and wood
def drum():
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=16, radius1=0.29, radius2=0.29, depth=0.88)
    for z in (-0.44, 0.44, -0.15, 0.15):     # rims and rolling hoops
        r = bmesh.ops.create_cone(bm, cap_ends=False, segments=16, radius1=0.302, radius2=0.302, depth=0.035)
        bmesh.ops.translate(bm, vec=(0, 0, z), verts=r["verts"])
    bm.normal_update()
    return bm

def dent(bm, c, r, depth):
    c = Vector(c)
    for v in bm.verts:
        d = (v.co - c).length
        if d < r:
            v.co -= c.normalized() * depth * (1 - d / r)

M = Mesh(["rust"])                           # standing drum
bm = drum(); dent(bm, (0.29, 0, 0.1), 0.25, 0.05)
M.add(bm, "rust", T(0, 0, 0.44))
done(M, "DrumUp", 0.7)

M = Mesh(["rust"])                           # drum on its side, slightly sunk
bm = drum(); dent(bm, (0, 0.29, -0.2), 0.3, 0.07)
M.add(bm, "rust", T(0, 0, 0.26) @ Ry(90) @ Rz(20))
done(M, "DrumSide", 1.0)

M = Mesh(["steel"])                          # fallen I-beam
L = 3.6
for cy, cz, sy, sz in ((0, 0.2, 0.28, 0.04), (0, -0.2, 0.28, 0.04), (0, 0, 0.04, 0.38)):
    M.add(cube((L, sy, sz), (0, cy, cz)), "steel", T(0, 0, 0.17) @ Ry(-4))
done(M, "Girder", 3.8)

M = Mesh(["conc"])                           # concrete culvert section lying on its side
M.add(tube(0.6, 0.48, 2.0, 18), "conc", T(0, 0, 0.55))
done(M, "PipeSeg", 2.2)

bm = bmesh.new()                             # bent corrugated scrap sheet: single skin, no collision
nx, ny = 28, 6
W, D = 1.9, 0.95
vs = []
for j in range(ny + 1):
    row = []
    for i in range(nx + 1):
        x = -W / 2 + W * i / nx; y = -D / 2 + D * j / ny
        z = 0.025 * math.sin(i / nx * W / 0.14 * 2 * math.pi)
        z += 0.25 * max(0.0, (x + 0.4) / (W / 2 + 0.4)) ** 2 * (0.6 + 0.4 * j / ny)    # curls up at one end
        z += 0.05 * noise.noise(Vector((x * 2, y * 2, 3.0)))
        row.append(bm.verts.new((x, y, z + 0.03)))
    vs.append(row)
for j in range(ny):
    for i in range(nx):
        bm.faces.new((vs[j][i], vs[j][i + 1], vs[j + 1][i + 1], vs[j + 1][i]))
M = Mesh(["corr"])
M.add(bm, "corr", Rz(8))
done(M, "Sheet", 2.0)

M = Mesh(["rubber"])                         # tyre, half sunk and tipped
M.add(torus(0.36, 0.14, 18, 8), "rubber", T(0, 0, 0.12) @ Rx(-18))
done(M, "Tyre", 1.0)

rnd = random.Random(41)                      # a few loose planks (flat on the ground: no collision)
M = Mesh(["wood"])
for k in range(4):
    M.add(chop(cube((rnd.uniform(1.4, 2.0), 0.17, 0.035)), rnd, 1, 0.12), "wood",
          T(rnd.uniform(-0.3, 0.3), rnd.uniform(-0.4, 0.4), 0.02 + k * 0.035) @ Rz(rnd.uniform(-35, 35)) @ Rx(rnd.uniform(-3, 3)))
done(M, "Planks", 2.2)

M = Mesh(["wood", "steel"])                  # cable reel stood on its rim
for y in (-0.36, 0.36):
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=16, radius1=0.52, radius2=0.52, depth=0.05)
    M.add(bm, "wood", T(0, y, 0.5) @ Rx(90))
bm = bmesh.new()
bmesh.ops.create_cone(bm, cap_ends=True, segments=12, radius1=0.3, radius2=0.3, depth=0.68)
M.add(bm, "steel", T(0, 0, 0.5) @ Rx(90))
done(M, "Reel", 1.2)

# ---------------------------------------------------------------------------------------------- grass tufts
def tuft(seed, n, h, spread):
    rnd = random.Random(seed)
    bm = bmesh.new()
    for k in range(n):
        a = rnd.uniform(0, 2 * math.pi)
        out = Vector((math.cos(a), math.sin(a), 0))
        base = out * rnd.uniform(0, spread)
        lean = out * rnd.uniform(0.15, 0.5)
        side = Vector((-math.sin(a + 0.8), math.cos(a + 0.8), 0))
        L = h * rnd.uniform(0.6, 1.1)
        w = rnd.uniform(0.025, 0.045)
        prev = None
        for s in range(4):
            t = s / 3
            c = base + lean * L * t * t + Vector((0, 0, L * t * (1 - 0.25 * t)))
            ww = w * (1 - t) + 0.002
            pair = (bm.verts.new(c - side * ww), bm.verts.new(c + side * ww))
            if prev:
                bm.faces.new((prev[0], prev[1], pair[1], pair[0]))
            prev = pair
    return bm

M = Mesh(["grass"])
M.add(tuft(51, 14, 0.42, 0.12), "grass")
done(M, "TuftA", 0.6)
M = Mesh(["dry"])
M.add(tuft(52, 18, 0.55, 0.16), "dry")
done(M, "TuftB", 0.7)
M = Mesh(["dry", "grass"])                   # a wider low clump mixing both
M.add(tuft(53, 22, 0.3, 0.35), "dry")
M.add(tuft(54, 10, 0.36, 0.2), "grass")
done(M, "TuftC", 0.9)

names = [o.name for o in built]
print("clutter built:", {o.name: len(o.data.polygons) for o in built})

# ---------------------------------------------------------------------------------------------- export
scene = bpy.context.scene
if bpy.app.background and scene != SC and coll.name not in scene.collection.children:
    scene.collection.children.link(coll)
assert bpy.app.background or scene == SC, "make Props17 the active scene, then run again to export"
for o in scene.objects:
    o.select_set(o.name in names)
bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", use_selection=True, use_active_scene=True,
                          export_apply=True, export_yup=True)
print("exported", OUT)