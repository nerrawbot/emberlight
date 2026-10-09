# v20: Ember Fields building kit - the ruined farm array that rings the city of Emberlight (the old world's industrial hub).
# Styled after the Ember Fields painting: heavy dark plated iron, stacked decks on X-braced frames, oxide-red panels,
# lattice masts with dangling cable, round machine drums, a few ember-lit slits still smouldering; everything toppled,
# tilted or half sunk in the field. Pieces (each its own object + "<Name>-colonly" child, origin on the ground, Z up):
#   FarmProcessor     stacked processing block, tilted and sunk: drum, hopper, stacks, broken conveyor arm  (~33 x 15 x 24 m)
#   SowerBoomFallen   the long slab boom tipped up on its frame, head block at the high end                (~29 x 7 x 14 m)
#   CommTowerFallen   lattice comm tower snapped at 9 m, the top lying across the field, dishes, cables     (~40 x 8 x 10 m)
#   CommTowerLeaning  lattice tower leaning on its guys, platform, dishes, snapped mast top hanging          (~34 x 34 x 38 m)
#   GrainSilos        three banded silos (one crumpled, its roof in the grass), elevator leg, gantry         (~28 x 12 x 29 m)
#   PivotSpan         centre-pivot irrigation arm: two spans standing, the third tower down, the rest lying (~60 x 8 x 6 m)
#   CollectorRow      one row of the collector array: tracker panels on posts, one gone, one hanging         (~17 x 4 x 3 m)
#   PumpHouse         small plated pump/relay hut, caved corrugated roof, pipe manifold, door ajar          (~9 x 7 x 7 m)
#   FieldBarn         timber-framed barn, plank siding, rusted roof with a fallen end bay, door off its track  (~13 x 9 x 7 m)
#   WaterTower        wooden stave tank on a steel stand, iron hoops, burst staves, ladder                  (~7 x 7 x 17 m)
#   FieldMarker07/12/03  the hexagonal plot markers of the array sequence (03 is tipped and chipped)       (~1.7 x 0.8 x 1.5 m)
# Materials keep the surface's names where they share a texture (M_Steel, M_Concrete2/3, M_Grate, M_Hazard) so
# painterly_world.gd's TUNE applies; new ones: M_EF_Iron (the rifle's er_iron map), the v20 sets graded by
# v20_ef_textures.py (M_EF_Oxide, M_EF_Rust, M_EF_RustCoarse, M_EF_Corr, M_EF_Planks, M_EF_Timber, M_EF_PaintWood),
# M_EF_Glow (ember slits; emissive, so the painterly pass skips it), M_EF_Lamp, M_EF_Panel, M_EF_Cable, M_EF_Paint,
# M_EF_Rubber, M_EF_Dark.
# Self-contained. Starts from an empty file, builds scene "EmberFields20" (a collection per piece under EMBER_FIELDS20,
# plus EF_Showcase: ground, sun, camera - not exported), saves art_src/ember_fields.blend (texture paths relative) and
# exports assets/props/ember_fields.glb (the pieces are laid out in a row; node translations are layout only):
#   D:\Blender\blender.exe --background --factory-startup --python art_src\v20_ember_fields.py
# Set EF_PREVIEW=<folder> to also render a look at each piece there (Cycles, CPU). In a fresh worktree run
# `git lfs checkout art_src/tex` first (the textures are LFS).
import bpy, bmesh, math, os, random
from mathutils import Vector, Matrix, noise

HERE = os.path.dirname(os.path.abspath(__file__))
PROJ = os.path.dirname(HERE)
TEX = os.path.join(HERE, "tex")
OUT_GLB = os.path.join(PROJ, "assets", "props", "ember_fields.glb")
OUT_BLEND = os.path.join(HERE, "ember_fields.blend")
PREVIEW = os.environ.get("EF_PREVIEW")
if os.path.getsize(os.path.join(TEX, "steel_albedo.jpg")) < 1000:
    raise SystemExit("art_src/tex holds LFS pointers: run `git lfs checkout art_src/tex` first")

bpy.ops.wm.read_factory_settings(use_empty=True)
SC = bpy.context.scene
SC.name = "EmberFields20"
ROOT = bpy.data.collections.new("EMBER_FIELDS20")
SC.collection.children.link(ROOT)

# ---------------------------------------------------------------------------------------------- materials
def _img(name, cs):
    i = bpy.data.images.load(os.path.join(TEX, name), check_existing=True)
    i.colorspace_settings.name = cs
    return i

def _bsdf(m):
    if not m.node_tree:
        m.use_nodes = True
    return next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")

def pbr(name, key, normal_strength=1.0):
    """Poly Haven set art_src/tex/<key>_{albedo,orm,normal}.jpg (already graded to the palette)."""
    m = bpy.data.materials.new(name)
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

def albedo(name, file, rough, metal):
    """A single graded colour map (the rifle's er_* plates, the hazard stripes)."""
    m = bpy.data.materials.new(name)
    b = _bsdf(m)
    tn = m.node_tree.nodes.new("ShaderNodeTexImage"); tn.image = _img(file, "sRGB")
    m.node_tree.links.new(tn.outputs["Color"], b.inputs["Base Color"])
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    return m

def flat(name, col, rough=0.9, metal=0.0, emit=None, strength=0.0, double=False):
    m = bpy.data.materials.new(name)
    b = _bsdf(m)
    b.inputs["Base Color"].default_value = (*col, 1.0)
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    if emit:
        b.inputs["Emission Color"].default_value = (*emit, 1.0)
        b.inputs["Emission Strength"].default_value = strength
    m.diffuse_color = (*col, 1.0)
    m.use_backface_culling = not double
    return m

MAT = {
    "iron": albedo("M_EF_Iron", "er_iron.png", 0.62, 0.45),        # dark plated hull iron
    "oxide": pbr("M_EF_Oxide", "ef_oxide"),                        # faded oxide-red paint (v20 set)
    "rust": pbr("M_EF_Rust", "ef_rust"),                          # v20 sets (v20_ef_textures.py)
    "coarse": pbr("M_EF_RustCoarse", "ef_rustcoarse"),
    "corr": pbr("M_EF_Corr", "ef_corr"),
    "planks": pbr("M_EF_Planks", "ef_planks"),
    "timber": pbr("M_EF_Timber", "ef_timber"),
    "paintwood": pbr("M_EF_PaintWood", "ef_paintwood"),
    "steel": pbr("M_Steel", "steel"),
    "conc": pbr("M_Concrete2", "concrete2"),
    "conc3": pbr("M_Concrete3", "concrete3", 0.8),
    "grate": pbr("M_Grate", "grate"),
    "hazard": albedo("M_Hazard", "hazard_albedo.jpg", 0.7, 0.0),
    "glow": flat("M_EF_Glow", (0.35, 0.09, 0.02), 0.5, emit=(1.0, 0.42, 0.12), strength=4.0),
    "lamp": flat("M_EF_Lamp", (0.2, 0.08, 0.03), 0.4, emit=(1.0, 0.45, 0.15), strength=0.7),
    "panel": flat("M_EF_Panel", (0.05, 0.06, 0.11), 0.22, 0.55),
    "cable": flat("M_EF_Cable", (0.035, 0.03, 0.035), 0.75),
    "paint": flat("M_EF_Paint", (0.62, 0.58, 0.5), 0.85),
    "rubber": flat("M_EF_Rubber", (0.045, 0.045, 0.05), 0.9),
    "dark": flat("M_EF_Dark", (0.02, 0.018, 0.022), 0.95),          # door voids, recesses
}
MAT["corr"].use_backface_culling = False
TILE = {"M_EF_Iron": 6.0, "M_EF_Oxide": 2.4, "M_EF_Rust": 2.2, "M_EF_RustCoarse": 2.5, "M_EF_Corr": 2.0,
        "M_EF_Planks": 2.4, "M_EF_Timber": 1.6, "M_EF_PaintWood": 2.0, "M_Steel": 1.6,
        "M_Concrete2": 2.4, "M_Concrete3": 2.0, "M_Grate": 1.8, "M_Hazard": 1.0}

# ---------------------------------------------------------------------------------------------- mesh builder
I4 = Matrix.Identity(4)
def T(x, y, z): return Matrix.Translation((x, y, z))
def Rx(d): return Matrix.Rotation(math.radians(d), 4, "X")
def Ry(d): return Matrix.Rotation(math.radians(d), 4, "Y")
def Rz(d): return Matrix.Rotation(math.radians(d), 4, "Z")

class Mesh:
    """One piece: a bmesh with a material list and a transform stack (push/pop); parts are added in piece space."""
    def __init__(self):
        self.bm = bmesh.new()
        self.mats = []
        self.stack = [I4]

    def push(self, m): self.stack.append(self.stack[-1] @ m)
    def pop(self): self.stack.pop()
    def xf(self, p): return self.stack[-1] @ Vector(p)        # piece-space point of a local point

    def add(self, src, mat, m=None):
        xf = self.stack[-1] @ m if m is not None else self.stack[-1]
        if mat not in self.mats:
            self.mats.append(mat)
        mi = self.mats.index(mat)
        vm = {v: self.bm.verts.new(xf @ v.co) for v in src.verts}
        for f in src.faces:
            try:
                nf = self.bm.faces.new([vm[v] for v in f.verts])
            except ValueError:
                continue
            nf.material_index = mi
            nf.smooth = f.smooth
        src.free()

    def obj(self, name, coll, loc=(0, 0, 0)):
        me = bpy.data.meshes.new(name)
        visual = self.mats and self.mats[0] is not None
        if visual:
            for k in self.mats:
                me.materials.append(MAT[k])
        bm = self.bm
        bm.normal_update()
        if visual:
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
        ob = bpy.data.objects.new(name, me)
        ob.location = loc
        coll.objects.link(ob)
        return ob

# ---------------------------------------------------------------------------------------------- primitives (bmesh)
def cube(size, c=(0, 0, 0)):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=size, verts=bm.verts)
    bmesh.ops.translate(bm, vec=c, verts=bm.verts)
    return bm

def block(size, c=(0, 0, 0), bev=0.07):
    """Cube with chamfered edges (the chamfers catch the low sun like the painting's lit edges)."""
    bm = cube(size, c)
    b = min(bev, 0.3 * min(size))
    if b > 0.002:
        bmesh.ops.bevel(bm, geom=list(bm.edges), offset=b, offset_type="OFFSET", segments=1, profile=0.5,
                        affect="EDGES", clamp_overlap=True)
    return bm

def basis(c, x, y):
    """4x4 with origin c, X along x, Y along y (orthogonalised), Z = X x Y (right-handed)."""
    x = Vector(x).normalized(); y = Vector(y); y = (y - x * y.dot(x)).normalized()
    return Matrix.Translation(c) @ Matrix((x, y, x.cross(y))).transposed().to_4x4()

def obox(p0, p1, side, w, t):
    """Plate/bar from p0 to p1: w wide along `side`, t thick across it (flat bars, flanges, sheets)."""
    p0 = Vector(p0); p1 = Vector(p1)
    bm = cube(((p1 - p0).length, w, t))
    bmesh.ops.transform(bm, matrix=basis((p0 + p1) / 2, p1 - p0, side), verts=bm.verts)
    return bm

def _aim(d, axis):
    """Rotation taking local `axis` onto d (with a sensible up)."""
    d = d.normalized()
    if axis == "X":
        up = "Z" if abs(d.z) < 0.98 else "Y"
    else:
        up = "Y" if abs(d.y) < 0.98 else "X"
    return d.to_track_quat(axis, up).to_matrix().to_4x4()

def beam(p0, p1, w, h=None):
    """Box member from p0 to p1, w wide, h tall (h defaults to w)."""
    p0 = Vector(p0); p1 = Vector(p1)
    d = p1 - p0
    bm = cube((max(d.length, 0.01), w, h or w))
    bmesh.ops.transform(bm, matrix=Matrix.Translation((p0 + p1) / 2) @ _aim(d, "X"), verts=bm.verts)
    return bm

def cyl(p0, p1, r, seg=12, r2=None, caps=True, smooth=True):
    p0 = Vector(p0); p1 = Vector(p1)
    d = p1 - p0
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=caps, cap_tris=False, segments=seg, radius1=r,
                          radius2=r if r2 is None else r2, depth=max(d.length, 0.005))
    for f in bm.faces:
        f.smooth = smooth and len(f.verts) == 4
    bmesh.ops.transform(bm, matrix=Matrix.Translation((p0 + p1) / 2) @ _aim(d, "Z"), verts=bm.verts)
    return bm

def lathe(prof, seg=20, smooth=True):
    """Closed (r, z) loop spun about Z."""
    bm = bmesh.new()
    rings = [[bm.verts.new((r * math.cos(2 * math.pi * i / seg), r * math.sin(2 * math.pi * i / seg), z))
              for i in range(seg)] for r, z in prof]
    m = len(rings)
    for j in range(m):
        a, b = rings[j], rings[(j + 1) % m]
        for i in range(seg):
            f = bm.faces.new((a[i], a[(i + 1) % seg], b[(i + 1) % seg], b[i]))
            f.smooth = smooth
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm

def tube(r_out, r_in, length, seg=20):
    """Open pipe / ring along Z, centred."""
    h = length / 2
    return lathe([(r_out, -h), (r_out, h), (r_in, h), (r_in, -h)], seg)

def torus(R, r, seg=24, rseg=6):
    bm = bmesh.new()
    ring = [[bm.verts.new(((R + r * math.cos(b)) * math.cos(a), (R + r * math.cos(b)) * math.sin(a), r * math.sin(b)))
             for b in (2 * math.pi * k / rseg for k in range(rseg))]
            for a in (2 * math.pi * i / seg for i in range(seg))]
    for i in range(seg):
        for k in range(rseg):
            a, b = ring[i], ring[(i + 1) % seg]
            f = bm.faces.new((a[k], b[k], b[(k + 1) % rseg], a[(k + 1) % rseg]))
            f.smooth = True
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm

def prism(poly, y0, y1, bevel=0.0):
    """Polygon (x, z) extruded along Y from y0 to y1; optional chamfer on the y0 face."""
    bm = bmesh.new()
    c = Vector((sum(p[0] for p in poly) / len(poly), sum(p[1] for p in poly) / len(poly)))
    def ring(y, inset):
        out = []
        for x, z in poly:
            p = Vector((x, z)); q = c + (p - c) * (1 - inset / max((p - c).length, 1e-6))
            out.append(bm.verts.new((q.x, y, q.y)))
        return out
    rings = [ring(y0, bevel), ring(y0 + bevel, 0.0), ring(y1, 0.0)] if bevel > 0 else [ring(y0, 0.0), ring(y1, 0.0)]
    n = len(poly)
    for a, b in zip(rings, rings[1:]):
        for i in range(n):
            bm.faces.new((a[i], a[(i + 1) % n], b[(i + 1) % n], b[i]))
    bm.faces.new(rings[0]); bm.faces.new(list(reversed(rings[-1])))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm

def chop(bm, rnd, cuts, depth=0.3):
    """Fracture: slice off `cuts` random corners (flat cut faces, like broken concrete)."""
    for _ in range(cuts):
        vs = [v.co.copy() for v in bm.verts]
        lo = Vector([min(c[i] for c in vs) for i in range(3)])
        hi = Vector([max(c[i] for c in vs) for i in range(3)])
        n = Vector((rnd.uniform(-1, 1), rnd.uniform(-1, 1), rnd.uniform(-0.3, 1))).normalized()
        far = max(vs, key=lambda c: c.dot(n))
        co = far - n * (hi - lo).length * rnd.uniform(0.08, depth)
        res = bmesh.ops.bisect_plane(bm, geom=list(bm.verts) + list(bm.edges) + list(bm.faces), plane_co=co,
                                     plane_no=n, clear_outer=True)
        cut = [e for e in res["geom_cut"] if isinstance(e, bmesh.types.BMEdge)]
        if cut:
            bmesh.ops.holes_fill(bm, edges=cut, sides=0)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm

# ---------------------------------------------------------------------------------------------- assemblies
def lattice(M, mat, h, w0, w1, n, leg=0.26, girt=0.14, br=0.1, rnd=None, broken=0.0):
    """Square tapered lattice tower, base centred on the local origin, up +Z; broken braces dangle or go missing."""
    SG = ((-1, -1), (1, -1), (1, 1), (-1, 1))
    lv = []
    for i in range(n + 1):
        t = i / n; w = (w0 + (w1 - w0) * t) / 2
        lv.append([Vector((sx * w, sy * w, h * t)) for sx, sy in SG])
    ft = max(0.03, leg * 0.16)
    for i in range(n):                                   # legs: angle iron, flanges turned in from the corner
        for k, (sx, sy) in enumerate(SG):
            p, q = lv[i][k], lv[i + 1][k]
            for side in (Vector((sx, 0, 0)), Vector((0, sy, 0))):
                o = -side * (leg / 2)
                M.add(obox(p + o, q + o, side, leg, ft), mat)
    def nrm(k):
        a, b = lv[0][k], lv[0][(k + 1) % 4]
        m = (a + b) / 2; return Vector((m.x, m.y, 0)).normalized()
    def bar(p, q, k, w):                                 # flat bar lying in face k
        d = (q - p).normalized()
        M.add(obox(p, q, nrm(k).cross(d), w, ft * 0.8), mat)
    for i in range(n + 1):
        for k in range(4):
            if rnd and 0 < i < n and rnd.random() < broken * 0.5:
                continue
            a, b = lv[i][k], lv[i][(k + 1) % 4]
            M.add(obox(a, b, Vector((0, 0, 1)), girt * 1.3, ft), mat)
            for p, q in ((a, b), (b, a)):                # gusset plates at the joints
                u = (q - p).normalized()
                M.add(obox(p + u * 0.05, p + u * (0.05 + leg * 2.2), Vector((0, 0, 1)), leg * 1.9, ft * 0.7), mat)
    for i in range(n):
        for k in range(4):
            a, b = lv[i][k], lv[i][(k + 1) % 4]
            c, d = lv[i + 1][(k + 1) % 4], lv[i + 1][k]
            for p, q in ((a, c), (b, d)):
                if rnd and rnd.random() < broken:
                    if rnd.random() < 0.5:                       # snapped brace hanging off its bottom bolt
                        M.add(beam(p, p.lerp(q, rnd.uniform(0.3, 0.6)) - Vector((0, 0, rnd.uniform(0.4, 1.2))), br), mat)
                    continue
                bar(p, q, k, br * 1.5)
    return lv

def boxtruss(M, mat, L, w, h, panel=2.0, chord=0.2, br=0.09, rnd=None, broken=0.0):
    """Box truss along +X from 0 to L, centred on y, from z 0 to h."""
    n = max(1, int(round(L / panel)))
    def P(i, sy, sz): return Vector((L * i / n, sy * w / 2, sz * h))
    for sy in (-1, 1):
        for sz in (0, 1):
            M.add(beam(P(0, sy, sz), P(n, sy, sz), chord), mat)
    for i in range(n + 1):
        for sy in (-1, 1):
            M.add(beam(P(i, sy, 0), P(i, sy, 1), br), mat)
        for sz in (0, 1):
            M.add(beam(P(i, -1, sz), P(i, 1, sz), br), mat)
    for i in range(n):
        for sy in (-1, 1):
            if rnd and rnd.random() < broken:
                continue
            a, b = (P(i, sy, 0), P(i + 1, sy, 1)) if i % 2 == 0 else (P(i, sy, 1), P(i + 1, sy, 0))
            M.add(beam(a, b, br), mat)
        if not rnd or rnd.random() >= broken:
            M.add(beam(P(i, -1, 1), P(i + 1, 1, 1), br), mat)

def cable(M, p0, p1, sag, r=0.035, n=14, lie=None):
    """Hanging cable p0 -> p1 (piece space, outside any push) with a parabolic sag; `lie` adds slack on the ground."""
    p0 = Vector(p0); p1 = Vector(p1)
    pts = [p0.lerp(p1, i / n) - Vector((0, 0, sag * 4 * (i / n) * (1 - i / n))) for i in range(n + 1)]
    if lie:
        d = Vector(lie); q = p1.copy()
        for k in range(4):
            q = q + d / 4 + Vector((math.sin(k * 1.7) * 0.25, math.cos(k * 1.3) * 0.25, 0))
            pts.append(Vector((q.x, q.y, 0.04)))
    for a, b in zip(pts, pts[1:]):
        M.add(beam(a, b, r * 2), "cable")

def dish(M, mat, r, depth):
    """Parabolic dish opening up +Z (local), rim at z = depth, feed on three struts, back hub."""
    t = 0.07
    prof = [(r * k / 6 + 0.12, depth * (k / 6) ** 2) for k in range(7)]
    loop = prof + [(r + 0.05, depth + 0.04)] + [(rr, z + t) for rr, z in reversed(prof)]
    M.add(lathe(loop, 22), mat)
    f = Vector((0, 0, depth + r * 0.55))
    for a in (90, 210, 330):
        rim = Vector((r * 0.95 * math.cos(math.radians(a)), r * 0.95 * math.sin(math.radians(a)), depth))
        M.add(beam(rim, f, 0.05), "steel")
    M.add(cyl(f - Vector((0, 0, 0.18)), f + Vector((0, 0, 0.12)), 0.11, 8), "steel")
    M.add(cyl((0, 0, -0.45), (0, 0, 0.1), 0.2, 10), "steel")

def slit(M, c, length, face, z_hood=0.22):
    """Ember slit on a wall: glowing strip with a rusty hood above. face: 'x+', 'x-', 'y+', 'y-'."""
    x, y, z = c
    s = 1 if face[1] == "+" else -1
    if face[0] == "y":
        M.add(cube((length, 0.08, 0.2), (x, y + s * 0.07, z)), "glow")
        M.add(block((length + 0.2, 0.45, 0.12), (x, y + s * 0.27, z + z_hood), 0.03), "oxide")
    else:
        M.add(cube((0.08, length, 0.2), (x + s * 0.07, y, z)), "glow")
        M.add(block((0.45, length + 0.2, 0.12), (x + s * 0.27, y, z + z_hood), 0.03), "oxide")

def railing(M, p0, p1, h=1.1, spacing=1.6, rnd=None, broken=0.0):
    p0 = Vector(p0); p1 = Vector(p1)
    n = max(1, int(round((p1 - p0).length / spacing)))
    pts = [p0.lerp(p1, i / n) for i in range(n + 1)]
    up = Vector((0, 0, h))
    for i, a in enumerate(pts):
        if rnd and rnd.random() < broken * 0.4:
            continue
        M.add(beam(a, a + up, 0.07), "steel")
    for a, b in zip(pts, pts[1:]):
        if rnd and rnd.random() < broken:
            M.add(beam(a + up, b + up * 0.3, 0.05), "steel")        # rail torn off one post, hanging
            continue
        M.add(beam(a + up, b + up, 0.06), "steel")
        M.add(beam(a + up * 0.5, b + up * 0.5, 0.045), "steel")

def wheel(M, c, R=0.55, r=0.22):
    m = T(*c) @ Rx(90)
    M.add(torus(R, r, 18, 8), "rubber", m)
    M.add(cyl((0, 0, -0.14), (0, 0, 0.14), R - 0.12, 12), "steel", m)
    M.add(cyl((0, 0, -0.25), (0, 0, 0.25), 0.1, 8), "steel", m)

def valve_wheel(M, c, R=0.3):
    M.add(torus(R, 0.035, 18, 5), "oxide", T(*c))
    for a in (0, 120, 240):
        M.add(beam(c, Vector(c) + Vector((R * math.cos(math.radians(a)), R * math.sin(math.radians(a)), 0)), 0.04), "steel")

SEG7 = {0: "abcdef", 1: "bc", 2: "abged", 3: "abgcd", 4: "fgbc", 5: "afgcd", 6: "afgedc", 7: "abc", 8: "abcdefg", 9: "abcdfg"}
def digit(M, n, c, w=0.3, h=0.56, s=0.07, y=0.0):
    """Seven-segment numeral standing in the XZ plane at c (its front at y)."""
    cx, cz = c
    seg = {"a": (0, h / 2 - s / 2, 1), "d": (0, -h / 2 + s / 2, 1), "g": (0, 0, 1),
           "b": (w / 2 - s / 2, h / 4, 0), "c": (w / 2 - s / 2, -h / 4, 0),
           "e": (-w / 2 + s / 2, -h / 4, 0), "f": (-w / 2 + s / 2, h / 4, 0)}
    for k in SEG7[n]:
        x, z, horiz = seg[k]
        size = (w, 0.03, s) if horiz else (s, 0.03, h / 2)
        M.add(cube(size, (cx + x, y, cz + z)), "paint")

def clad(M, size, c, mat, rnd, panel=(2.0, 1.5), missing=0.05, loose=0.06, holes=(), t=0.05, gap=0.07, faces="xXyY"):
    """Hang plates with seams over the four sides of a box (size, centre c); some plates gone, some swung loose off
    their top bolts. holes: (lo, hi) boxes kept clear (doors, slits)."""
    sx, sy, sz = size
    up = Vector((0, 0, 1))
    for f in faces:
        n = Vector({"x": (-1, 0, 0), "X": (1, 0, 0), "y": (0, -1, 0), "Y": (0, 1, 0)}[f])
        L, off = (sy, sx / 2) if f in "xX" else (sx, sy / 2)
        u = n.cross(up)
        nu = max(1, int(round(L / panel[0]))); nv = max(1, int(round(sz / panel[1])))
        pw, ph = L / nu, sz / nv
        for i in range(nu):
            for j in range(nv):
                ctr = Vector(c) + n * (off + t / 2) + u * (-L / 2 + pw * (i + 0.5)) + up * (-sz / 2 + ph * (j + 0.5))
                if any(all(lo[k] <= ctr[k] <= hi[k] for k in range(3)) for lo, hi in holes):
                    continue
                r = rnd.random()
                if r < missing:
                    continue
                m = basis(ctr, u, up)                 # X along the wall, Y up, Z into the wall
                if r < missing + loose:               # swung loose off the top bolts (bottom edge out)
                    m = m @ T(0, ph / 2, 0) @ Rx(rnd.uniform(8, 25)) @ T(0, -ph / 2, 0)
                M.add(cube((pw - gap, ph - gap, t)), mat, m)

def boards(M, a, b, z0, ztop, mat, rnd, w=0.26, gap=0.035, t=0.04, out=None, missing=0.06, sag=0.0):
    """Vertical boards along the wall line a -> b (z = 0 plane points), from z0 up to ztop(s) (s 0..1 along the wall)."""
    a = Vector(a); b = Vector(b); L = (b - a).length; u = (b - a) / L
    n = out if out is not None else Vector((u.y, -u.x, 0))
    k = max(1, int(L / (w + gap)))
    for i in range(k):
        s = (i + 0.5) / k
        if rnd.random() < missing:
            continue
        top = ztop(s) - (rnd.uniform(0.3, 1.4) if rnd.random() < 0.08 else 0.0)
        bot = z0 + (rnd.uniform(0.2, 0.9) if rnd.random() < 0.1 else 0.0)
        p = a + u * (L * s) + n * (t / 2)
        lean = rnd.uniform(-0.03, 0.03)
        M.add(obox((p.x, p.y, bot), (p.x + u.x * lean, p.y + u.y * lean, top), u, w * rnd.uniform(0.85, 1.0), t), mat)

def crate(M, c, s=1.0, yaw=0.0, h=None):
    m = T(*c) @ Rz(yaw)
    h = h or s
    M.add(cube((s * 0.94, s * 0.94, h * 0.94), (0, 0, h / 2)), "planks", m)
    for x in (-1, 1):
        for y in (-1, 1):
            M.add(cube((0.08, 0.08, h), (x * s * 0.47, y * s * 0.47, h / 2)), "timber", m)
    for z in (0.04, h - 0.04):
        for y in (-1, 1): M.add(cube((s, 0.08, 0.08), (0, y * s * 0.47, z)), "timber", m)
        for x in (-1, 1): M.add(cube((0.08, s, 0.08), (x * s * 0.47, 0, z)), "timber", m)
    M.add(obox((-s * 0.45, -s * 0.48, 0.1), (s * 0.45, -s * 0.48, h - 0.1), Vector((0, 0, 1)), 0.1, 0.03), "timber", m)

def pallet(M, c, yaw=0.0, z=0.0):
    m = T(c[0], c[1], z) @ Rz(yaw)
    for y in (-0.5, 0.0, 0.5): M.add(cube((1.2, 0.1, 0.1), (0, y, 0.05)), "timber", m)
    for k in range(7): M.add(cube((0.11, 1.15, 0.025), (-0.54 + k * 0.18, 0, 0.115)), "planks", m)

def cribbing(M, c, layers=5, L=2.2, yaw=0.0):
    """Timber cribbing stack (blocking under heavy wreckage)."""
    m = T(*c) @ Rz(yaw)
    for i in range(layers):
        for k in (-1, 0, 1):
            off = k * (L / 2 - 0.15)
            size, ctr = ((L, 0.25, 0.22), (0, off, 0.11 + i * 0.22)) if i % 2 == 0 else ((0.25, L, 0.22), (off, 0, 0.11 + i * 0.22))
            M.add(block(size, ctr, 0.03), "timber", m)

# ---------------------------------------------------------------------------------------------- pieces
def farm_processor():
    """The big stacked processing block (the painting's right-hand ruin), tilted and sunk on one corner."""
    M, C = Mesh(), Mesh(); rnd = random.Random(3)
    tilt = T(0, 0, -2.2) @ Ry(-11) @ Rx(5.5)
    M.push(tilt); C.push(tilt)
    # base frame 20 x 14, z 0..4.2, plated core inside
    xs, ys = [-10, -5, 0, 5, 10], [-7, 0, 7]
    M.add(cube((15, 10, 4.2), (0, 0, 2.1)), "iron")
    for x in xs:
        for y in ys:
            if x in (-10, 10) or y in (-7, 7):
                M.add(block((0.7, 0.7, 4.2), (x, y, 2.1)), "steel")
    for y in (-7, 7):
        for a, b in zip(xs, xs[1:]):
            M.add(beam((a, y, 0.4), (b, y, 3.9), 0.26), "steel"); M.add(beam((b, y, 0.4), (a, y, 3.9), 0.26), "steel")
        M.add(beam((-10, y, 0.3), (10, y, 0.3), 0.5), "steel")
    for x in (-10, 10):
        for a, b in zip(ys, ys[1:]):
            M.add(beam((x, a, 0.4), (x, b, 3.9), 0.26), "steel"); M.add(beam((x, b, 0.4), (x, a, 3.9), 0.26), "steel")
        M.add(beam((x, -7, 0.3), (x, 7, 0.3), 0.5), "steel")
    M.add(block((21, 15, 0.7), (0, 0, 4.55), 0.1), "iron")
    for y in (-7.55, 7.55): M.add(cube((21.2, 0.35, 0.95), (0, y, 4.5)), "oxide")
    for x in (-10.55, 10.55): M.add(cube((0.35, 15.4, 0.95), (x, 0, 4.5)), "oxide")
    C.add(cube((21, 15, 4.9), (0, 0, 2.45)), None)
    # mid block 16 x 11, z 4.9..11: ribs, a band, two rows of ember slits, a big loading door
    M.add(block((16, 11, 6.1), (0.5, 0.5, 7.95), 0.12), "iron")
    clad(M, (16, 11, 6.1), (0.5, 0.5, 7.95), "rust", rnd, (2.0, 1.55), holes=[((-6.8, -7, 4.5), (-2.2, -4, 9.0))])
    for x in range(-7, 9, 2):
        for y in (-5.15, 6.15): M.add(cube((0.28, 0.32, 6.1), (x + 0.5, y, 7.95)), "steel")
    for y in range(-4, 6, 2):
        M.add(cube((0.32, 0.28, 6.1), (8.65, y + 0.5, 7.95)), "steel")
        M.add(cube((0.32, 0.28, 6.1), (-7.65, y + 0.5, 7.95)), "steel")
    M.add(cube((16.6, 11.6, 0.45), (0.5, 0.5, 8.3)), "oxide")
    for z in (6.4, 9.7):
        for x in ((-0.5, 1.5, 3.5, 5.5, 7.5) if z < 8 else (-4.5, -2.5, 1.5, 3.5, 5.5)):
            slit(M, (x, -5.0, z), 1.5, "y-")
    for y in (-2.5, -0.5, 1.5, 3.5): slit(M, (8.5, y + 0.5, 9.7), 1.5, "x+")
    M.add(cube((3.6, 0.12, 3.6), (-4.5, -5.02, 6.75)), "dark")
    M.add(cube((4.2, 0.3, 0.4), (-4.5, -5.15, 8.75)), "hazard")
    for x in (-6.5, -2.5): M.add(cube((0.3, 0.3, 3.8), (x, -5.15, 6.8)), "hazard")
    C.add(cube((16, 11, 6.1), (0.5, 0.5, 7.95)), None)
    # upper deck z 11..11.7 on brackets, railing along the front (part of it torn)
    M.add(block((19, 13, 0.7), (0.5, 0.5, 11.35), 0.1), "iron")
    for y in (-6.0, 7.0): M.add(cube((19.2, 0.3, 0.8), (0.5, y, 11.3)), "oxide")
    for x in (-6, -2, 2, 6):
        M.add(beam((x, -5.0, 9.0), (x, -5.9, 11.0), 0.3), "steel")
        M.add(beam((x + 1, 6.0, 9.0), (x + 1, 6.9, 11.0), 0.3), "steel")
    for y in (-3, 1, 5): M.add(beam((8.5, y, 9.0), (9.8, y, 11.0), 0.3), "steel")
    railing(M, (-8.5, -5.8, 11.7), (9.5, -5.8, 11.7), rnd=rnd, broken=0.3)
    C.add(cube((19, 13, 0.7), (0.5, 0.5, 11.35)), None)
    # top housing (oxide panels, sloped roof, a lit window strip) and a squat side block with vents
    M.add(block((8, 7, 4.6), (3, 1.5, 14.0)), "iron")
    clad(M, (8, 7, 4.6), (3, 1.5, 14.0), "oxide", rnd, (1.6, 1.15), missing=0.08, holes=[((-0.5, -3, 14.6), (6.5, -1, 15.4))])
    for x in (-1.0, 7.0):
        for y in (-2.0, 5.0): M.add(cube((0.35, 0.35, 4.7), (x, y, 14.0)), "iron")
    M.add(block((8.8, 7.8, 0.4)), "iron", T(3, 1.5, 16.6) @ Rx(-7))
    slit(M, (3, -2.0, 15.0), 5.5, "y-")
    M.add(chop(cube((5, 5, 3), (-5, 2.0, 13.2)), rnd, 2, 0.2), "iron")
    for k in range(3): M.add(cube((0.9, 0.4, 0.5), (-6.2 + k * 1.2, -0.6, 13.6)), "rust")
    C.add(cube((8, 7, 4.8), (3, 1.5, 14.1)), None); C.add(cube((5, 5, 3), (-5, 2.0, 13.2)), None)
    # antenna cluster on the housing, cables strung down to the deck corners
    for a, b in (((5.0, 3.0, 16.9), (5.6, 3.6, 24.5)), ((6.2, 1.5, 16.9), (7.6, 0.8, 22.5)), ((3.8, 4.3, 16.9), (3.0, 5.4, 21.0))):
        M.add(cyl(a, b, 0.12, 8), "steel")
    for zz in (19.0, 21.5):
        M.add(beam((4.6, 3.1, zz), (6.8, 2.7, zz), 0.1), "steel")
    M.add(beam((5.6, 3.6, 24.5), (6.4, 2.6, 26.0), 0.07), "steel")              # bent tip
    c1 = (M.xf((5.6, 3.6, 24.0)), M.xf((-8.5, -5.9, 11.9)))
    c2 = (M.xf((7.6, 0.8, 22.3)), M.xf((9.6, -6.0, 11.9)))
    # big drum on the +X face (round machinery with an ember ring inside)
    dm = T(9.15, 0.0, 7.95) @ Ry(90)
    M.add(tube(2.9, 2.45, 1.3, 28), "oxide", dm)
    M.add(cyl((0, 0, -0.65), (0, 0, -0.25), 2.5, 28), "iron", dm)
    M.add(cyl((0, 0, -0.3), (0, 0, 0.95), 0.7, 14), "steel", dm)
    M.add(torus(1.75, 0.09, 28, 5), "glow", dm @ T(0, 0, -0.22))
    for k in range(8):
        if k == 5: continue                                                      # one spoke gone
        a = math.radians(k * 45 + 10)
        M.add(beam((0.6 * math.cos(a), 0.6 * math.sin(a), 0.35), (2.5 * math.cos(a), 2.5 * math.sin(a), 0.35), 0.24, 0.3), "iron", dm)
    C.add(cube((1.3, 5.8, 5.8), (9.15, 0, 7.95)), None)
    # crates and a pallet left on the base deck's front strip
    crate(M, (6.0, -6.3, 4.9), 1.1, 8); crate(M, (7.4, -6.1, 4.9), 0.9, -14); crate(M, (6.1, -6.25, 6.0), 0.8, 25)
    pallet(M, (3.4, -6.4), 80, 4.9); pallet(M, (3.4, -6.4), 74, 5.03)
    # hopper on the upper deck, chute down into the block
    M.add(cyl((-6.0, -2.5, 14.0), (-6.0, -2.5, 17.6), 0.8, 16, r2=3.0), "oxide")
    M.add(tube(3.05, 2.85, 1.0, 16), "iron", T(-6.0, -2.5, 18.1))
    for k in range(4):
        a = math.radians(45 + k * 90)
        M.add(beam((-6.0 + 2.6 * math.cos(a), -2.5 + 2.6 * math.sin(a), 11.7), (-6.0 + 2.9 * math.cos(a), -2.5 + 2.9 * math.sin(a), 17.7), 0.3), "steel")
    M.add(cyl((-6.0, -2.5, 11.6), (-6.0, -2.5, 14.1), 0.5, 10), "iron")
    C.add(cube((6, 6, 6.6), (-6.0, -2.5, 15.0)), None)
    # conveyor arm off the side block (out along -X, rising), broken: the outer section hangs from the tip
    M.push(T(-7.4, 1.0, 13.8) @ Rz(180) @ Ry(-13))
    boxtruss(M, "steel", 11.0, 1.6, 1.5, 1.8, rnd=rnd, broken=0.15)
    for k in range(26): M.add(cube((0.36, 1.25, 0.05), (0.2 + k * 0.42, 0, 0.12)), "planks")
    M.push(T(11.0, 0, 0.0) @ Ry(13 + 58) @ Rz(-12))
    boxtruss(M, "steel", 8.0, 1.6, 1.5, 1.8, rnd=rnd, broken=0.3)
    M.pop(); M.pop()
    # pipes up the back face, stacks on the deck smouldering at the mouth
    for x in (-4.0, -2.8, 5.5):
        M.add(cyl((x, 6.6, -0.5), (x, 6.6, 10.4), 0.32, 10), "oxide")
        M.add(cyl((x, 6.6, 10.4), (x, 4.5, 10.4), 0.32, 10), "oxide")
        for z in (2.0, 5.5, 8.5): M.add(cyl((x, 6.6, z - 0.1), (x, 6.6, z + 0.1), 0.42, 10), "steel")
    for x, h in ((-2.0, 19.5), (-0.2, 18.0)):
        M.add(cyl((x, 4.6, 11.7), (x, 4.6, h), 0.75, 16), "iron")
        M.add(torus(0.78, 0.1, 16, 5), "oxide", T(x, 4.6, h - 0.1))
        M.add(torus(0.78, 0.08, 16, 5), "oxide", T(x, 4.6, 14.5))
        M.add(cyl((x, 4.6, h - 0.35), (x, 4.6, h - 0.3), 0.62, 14), "glow")
        C.add(cube((1.5, 1.5, h - 11.7), (x, 4.6, (h + 11.7) / 2)), None)
    M.pop(); C.pop()
    cable(M, c1[0], c1[1], 2.0, 0.03, 20)
    cable(M, c2[0], c2[1], 1.2, 0.03, 12)
    return M, C

def sower_boom():
    """The long slab boom of a sowing rig, tipped up on its crushed under-frame (the painting's left-hand ruin)."""
    M, C = Mesh(), Mesh(); rnd = random.Random(7)
    # crushed under-frame it slid off
    M.push(T(5.5, 0.2, -0.3) @ Rz(8) @ Ry(-5))
    lattice(M, "steel", 2.6, 6.0, 5.6, 2, leg=0.4, girt=0.3, br=0.18, rnd=rnd, broken=0.3)
    M.add(block((6.4, 6.4, 0.5), (0, 0, 2.7)), "iron")
    M.pop()
    C.add(cube((6.4, 6.4, 3.0), (5.5, 0.2, 1.2)), None)
    B = T(-11, 0, -1.3) @ Ry(-24)
    M.push(B); C.push(B)
    M.add(block((26, 6, 2.4), (13, 0, 0), 0.12), "iron")
    clad(M, (26, 6, 2.4), (13, 0, 0), "rust", rnd, (2.2, 1.2), missing=0.07, faces="yY")
    for y in (-0.75, 0.75): M.add(cube((23.0, 0.16, 0.2), (12.5, y, 1.32)), "timber")
    for k in range(52):
        if rnd.random() < 0.07: continue
        M.add(cube((0.38, 1.8, 0.05), (1.3 + k * 0.44, rnd.uniform(-0.05, 0.05), 1.45)), "planks")
    for x in range(1, 26, 2): M.add(cube((0.3, 6.3, 0.25), (x, 0, 1.3)), "steel")
    for y in (-3.1, 3.1): M.add(cube((26.2, 0.5, 0.6), (13, y, 1.0)), "oxide")
    for y in (-3.1, 3.1): M.add(cube((26.2, 0.45, 0.5), (13, y, -1.0)), "steel")
    for x in range(4, 23, 2): slit(M, (x + 0.5, -3.0, 0.1), 1.4, "y-", 0.25)
    M.add(cube((8.0, 0.15, 0.6), (9.0, -3.05, -0.7)), "hazard")
    M.push(T(4.0, 0, -3.8)); boxtruss(M, "steel", 18.0, 5.0, 2.6, 2.2, chord=0.32, br=0.16, rnd=rnd, broken=0.12); M.pop()
    # head block at the high end: oxide panels, round port, stub mast with a cable
    M.add(chop(block((4.5, 7.0, 4.6), (26.5, 0, 0.5), 0.12), rnd, 2, 0.15), "iron")
    for y in (-3.55, 3.55):
        for x in (25.2, 27.4): M.add(cube((1.7, 0.12, 2.6), (x, y, 0.3)), "oxide")
        M.add(cube((4.7, 0.3, 0.4), (26.5, y, 2.0)), "steel")
    slit(M, (26.3, -3.5, 2.6), 3.2, "y-", 0.25)
    pm = T(28.8, 0, 0.5) @ Ry(90)
    M.add(tube(1.5, 1.1, 0.5, 22), "coarse", pm)
    M.add(cyl((0, 0, -0.3), (0, 0, 0.05), 1.15, 22), "dark", pm)
    M.add(torus(0.7, 0.07, 22, 5), "glow", pm @ T(0, 0, 0.08))
    M.add(cyl((25.0, 2.0, 2.8), (24.0, 2.6, 8.0), 0.13, 8), "steel")
    M.add(beam((24.4, 1.5, 6.0), (24.8, 3.7, 6.2), 0.08), "steel")
    C.add(cube((26, 6, 2.4), (13, 0, 0)), None); C.add(cube((4.5, 7.0, 4.6), (26.5, 0, 0.5)), None)
    top = M.xf((24.0, 2.6, 7.8))
    M.pop(); C.pop()
    cable(M, top, Vector((14.0, 5.5, 0.05)), 1.5, 0.03, 18, lie=(-3.5, 1.5, 0))
    # timber cribbing they were jacking it on, one stack knocked over; crates
    cribbing(M, (-3.5, -5.6, 0.0), 5, 2.2, 12)
    M.push(T(-0.5, 5.5, 0.6) @ Ry(70)); cribbing(M, (0, 0, 0), 3, 2.0, 0); M.pop()
    crate(M, (8.5, -5.4, 0.0), 1.2, 30); crate(M, (9.8, -6.0, 0.0), 1.0, 5); pallet(M, (7.4, -7.2), 40)
    # a few plates shed from the boom lying in the grass
    for k, (x, y, a) in enumerate(((-2.0, -5.0, 20), (3.5, -6.5, -35), (12.0, 4.8, 60))):
        M.add(chop(cube((2.4, 1.5, 0.12)), rnd, 1, 0.2), "iron", T(x, y, 0.08) @ Rz(a) @ Rx(5 * (k - 1)))
    return M, C

def comm_tower_fallen():
    """Lattice comm tower snapped at the 9 m girt; the upper 31 m lies across the field with its dishes."""
    M, C = Mesh(), Mesh(); rnd = random.Random(21)
    for sx in (-1, 1):
        for sy in (-1, 1):
            M.add(chop(cube((1.7, 1.7, 1.3)), rnd, 2, 0.15), "conc", T(sx * 2.5, sy * 2.5, 0.15))
    lv = lattice(M, "steel", 9.0, 5.0, 4.0, 4, rnd=rnd, broken=0.2)
    for c in lv[-1]:                                     # torn leg stubs at the break
        d = Vector((rnd.uniform(0.3, 1.0), rnd.uniform(-0.4, 0.4), rnd.uniform(0.4, 1.0)))
        M.add(beam(c, c + d, 0.24), "steel")
    C.add(cube((5.2, 5.2, 9.3), (0, 0, 4.6)), None)
    F = T(2.2, 0, 8.4) @ Ry(105) @ Rz(14)
    M.push(F); C.push(F)
    lattice(M, "steel", 31.0, 3.8, 1.0, 14, leg=0.22, rnd=rnd, broken=0.1)
    for zz, L in ((19.5, 2.4), (25.5, 1.8)):
        M.add(beam((-L, 0, zz), (L, 0, zz), 0.16), "steel"); M.add(beam((0, -L, zz), (0, L, zz), 0.16), "steel")
    M.push(T(0, -1.6, 19.5) @ Rx(90)); dish(M, "steel", 1.5, 0.45); M.pop()
    M.push(T(1.2, 1.3, 25.5) @ Rx(-90) @ Ry(20)); dish(M, "iron", 0.9, 0.3); M.pop()
    M.add(cyl((0, 0, 31.0), (0, 0, 33.4), 0.1, 8), "steel")
    M.add(cyl((0, 0, 33.4), (-1.4, 0.5, 34.9), 0.07, 6), "steel")       # whip bent up off the ground
    M.add(cube((0.5, 0.5, 0.5), (0, 0, 31.0)), "lamp")
    C.add(cube((2.9, 2.9, 31.0), (0, 0, 15.5)), None)
    hang = [M.xf((1.0, 1.0, 6.0)), M.xf((0.6, -0.9, 13.0)), M.xf((-0.2, 0.5, 21.0))]
    M.pop(); C.pop()
    for p in hang:
        cable(M, p, p + Vector((rnd.uniform(-1, 1), rnd.uniform(1.5, 3.0), -p.z + 0.04)), 0.6, 0.03, 10,
              lie=(rnd.uniform(-2, 2), rnd.uniform(1, 3), 0))
    cable(M, (2.0, 2.0, 8.8), (1.0, 7.5, 0.04), 1.4, 0.04, 14, lie=(-3, 2, 0))
    # the dish that came off, face down in the grass
    M.push(T(16.0, -6.0, 0.9) @ Rx(115) @ Rz(30)); dish(M, "steel", 1.6, 0.5); M.pop()
    # equipment hut at the base, cable tray to the tower
    M.add(cube((3.1, 2.3, 2.6), (-5.0, -4.2, 1.2)), "dark")              # timber hut: plank skin on a dark core
    for a, b in (((-6.55, -5.35), (-3.45, -5.35)), ((-3.45, -3.05), (-6.55, -3.05)), ((-6.55, -3.05), (-6.55, -5.35)), ((-3.45, -5.35), (-3.45, -3.05))):
        boards(M, (*a, 0), (*b, 0), -0.1, lambda s_: 2.5, "planks", rnd, missing=0.05)
    for x in (-6.55, -3.45):
        for y in (-5.35, -3.05): M.add(cube((0.16, 0.16, 2.6), (x, y, 1.2)), "timber")
    M.add(block((3.7, 2.9, 0.22), (-5.0, -4.2, 2.6), 0.04), "iron", T(-5.0, -4.2, 2.6) @ Rx(-4) @ T(5.0, 4.2, -2.6))
    M.add(cube((0.9, 0.06, 1.9), (0, 0, 0)), "paintwood", T(-5.15, -5.5, 0.95) @ Rz(-35) @ T(0.45, 0, 0))
    M.add(cube((0.3, 0.12, 0.2), (-4.7, -5.45, 2.2)), "lamp")
    M.add(beam((-3.4, -4.0, 2.2), (-2.3, -2.3, 2.2), 0.35, 0.12), "steel")
    C.add(cube((3.2, 2.4, 2.7), (-5.0, -4.2, 1.25)), None)
    return M, C

def comm_tower_leaning():
    """Lattice comm tower still standing but leaning on its guys; platform, dishes, the mast top snapped and hanging."""
    M, C = Mesh(), Mesh(); rnd = random.Random(31)
    M.add(chop(cube((7.0, 7.0, 1.6)), rnd, 2, 0.1), "conc", T(0, 0, -0.35))
    C.add(cube((7, 7, 1.6), (0, 0, -0.35)), None)
    TM = Ry(8) @ Rx(-3)
    M.push(TM); C.push(TM)
    lattice(M, "steel", 30.0, 4.6, 1.3, 12, rnd=rnd, broken=0.07)
    C.add(cube((3.6, 3.6, 30), (0, 0, 15)), None)
    # platform at 21 m
    M.add(cube((4.8, 4.8, 0.12), (0, 0, 21.0)), "grate")
    for k in range(4):
        a = math.radians(k * 90)
        M.add(beam((1.15 * math.cos(a), 1.15 * math.sin(a), 19.8), (2.3 * math.cos(a), 2.3 * math.sin(a), 20.92), 0.14), "steel")
    rail = [(-2.4, -2.4), (2.4, -2.4), (2.4, 2.4), (-2.4, 2.4)]
    for k in range(4):
        a, b = rail[k], rail[(k + 1) % 4]
        railing(M, (a[0], a[1], 21.06), (b[0], b[1], 21.06), spacing=1.2, rnd=rnd, broken=0.5 if k == 1 else 0.05)
    # mast and arms; the top snapped and hangs from the bent stub
    M.add(cyl((0, 0, 29.5), (0, 0, 36.0), 0.17, 10), "steel")
    for zz, L in ((31.5, 1.6), (33.5, 1.0)):
        M.add(beam((-L, 0, zz), (L, 0, zz), 0.1), "steel"); M.add(beam((0, -L * 0.6, zz), (0, L * 0.6, zz), 0.08), "steel")
    M.add(cyl((0, 0, 36.0), (0.9, -0.4, 37.9), 0.12, 8), "steel")
    M.add(cyl((0.9, -0.4, 37.9), (2.0, -0.7, 30.8), 0.1, 8), "steel")
    M.add(cube((0.28, 0.28, 0.32), (2.0, -0.7, 30.7)), "lamp")
    M.push(T(1.4, -1.2, 17.8) @ Rx(80) @ Rz(25)); dish(M, "steel", 1.4, 0.42); M.pop()
    M.push(T(-1.0, 0.8, 25.2) @ Ry(-85)); dish(M, "iron", 0.9, 0.28); M.pop()
    for zz in (8.0, 16.0): M.add(cube((0.5, 0.5, 0.7), (1.9 - zz * 0.055, -1.9 + zz * 0.055, zz)), "oxide")
    tower_pts = [M.xf((sx * 1.4, sy * 1.4, 20.0)) for sx, sy in ((1, 1), (-1, 1), (0, -1.0))]
    top_pt = M.xf((2.0, -0.7, 37.0))
    M.pop(); C.pop()
    cable(M, top_pt, top_pt + Vector((0.8, -2.5, -top_pt.z + 0.05)), 0.5, 0.025, 16, lie=(2.0, -3.0, 0))
    for k, (p, a) in enumerate(zip(tower_pts, (40, 150, 270))):
        g = Vector((17 * math.cos(math.radians(a)), 17 * math.sin(math.radians(a)), 0.4))
        M.add(chop(cube((1.4, 1.4, 1.0)), rnd, 2, 0.12), "conc", Matrix.Translation(g - Vector((0, 0, 0.3))))
        C.add(cube((1.4, 1.4, 1.0), g - Vector((0, 0, 0.3))), None)
        if k == 2:                                    # snapped guy: hangs from the tower, the rest lies in the grass
            drop = p.lerp(g, 0.25); drop.z = 0.05
            cable(M, p, drop, 1.0, 0.03, 16, lie=(g - p) * 0.4 * Vector((1, 1, 0)))
            M.add(beam(g, g + Vector((1.5, 0.6, 0.6)), 0.06), "cable")
        else:
            cable(M, p, g, 0.25, 0.03, 10)
    return M, C

def silo(M, C, cx, cy, r, h, rnd, crumple=0.0):
    seg = 28
    M.add(cyl((cx, cy, -0.6), (cx, cy, 0.5), r + 0.45, seg, smooth=False), "conc")
    M.add(torus(r + 0.02, 0.09, seg, 4), "rust", T(cx, cy, 0.55))
    prof = [(r, float(z)) for z in range(int(h) + 1)]
    wall = lathe(prof + [(r - 0.18, z) for _, z in reversed(prof)], seg)
    jag = [rnd.uniform(0.0, 1.0) for _ in range(seg)]
    for v in wall.verts:
        a = math.atan2(v.co.y, v.co.x); z = v.co.z
        if crumple > 0 and z > h * 0.5:
            f = ((z / h - 0.5) / 0.5) ** 1.5
            n = noise.noise(Vector((math.cos(a) * 2.5, math.sin(a) * 2.5, z * 0.45)))
            s = 1 - f * crumple * 0.45 * (0.6 + 0.6 * n)
            v.co.x *= s; v.co.y *= s
            v.co.x += f * crumple * 1.4
        if crumple > 0 and z > h - 3:
            i = int(round(a / (2 * math.pi) * seg)) % seg
            v.co.z -= jag[i] * crumple * 6 * (z - (h - 3)) / 3
    M.add(wall, "corr", T(cx, cy, 0))
    top = h - (4 if crumple else 0)
    for z in [k * 2.5 + 1.5 for k in range(int(top / 2.5))]:
        M.add(torus(r + 0.06, 0.08, seg, 4), "steel", T(cx, cy, z))
    if not crumple:
        M.add(cyl((cx, cy, h), (cx, cy, h + r * 0.55), r + 0.15, seg, r2=0.5), "oxide")
        M.add(cyl((cx, cy, h + r * 0.55 - 0.1), (cx, cy, h + r * 0.55 + 0.6), 0.55, 10), "iron")
        M.add(cyl((cx, cy, h + r * 0.55 + 0.6), (cx, cy, h + r * 0.55 + 0.8), 0.8, 10), "iron")
    # ladder up the front
    ly = cy - r - 0.35
    for sx in (-0.3, 0.3):
        M.add(beam((cx + sx, ly, 0.4), (cx + sx, ly, top - 0.3), 0.06), "steel")
    for z in [0.8 + 0.4 * k for k in range(int((top - 1.2) / 0.4))]:
        M.add(beam((cx - 0.3, ly, z), (cx + 0.3, ly, z), 0.035), "steel")
    M.add(cube((1.2, 0.12, 2.0), (cx + 1.2, cy - r + 0.05, 1.4)), "dark")
    M.add(cube((1.5, 0.18, 0.2), (cx + 1.2, cy - r - 0.02, 2.5)), "hazard")
    C.add(cyl((cx, cy, -0.5), (cx, cy, top), r, 12, smooth=False), None)

def grain_silos():
    M, C = Mesh(), Mesh(); rnd = random.Random(41)
    R, H = 3.2, 17.0
    for k, cx in enumerate((-4.0, 3.0, 10.0)):
        silo(M, C, cx, 0.0, R, H, rnd, crumple=0.45 if k == 2 else 0.0)
    # the crumpled silo's roof, lying in the grass
    M.add(cyl((0, 0, 0), (0, 0, R * 0.55), R + 0.15, 28, r2=0.5), "oxide", T(16.5, -4.5, 1.3) @ Ry(70) @ Rz(15))
    C.add(cube((2, 6.5, 6.5), (16.5, -4.5, 1.3)), None)
    # elevator leg tower and head house
    M.push(T(-11.0, 0.0, 0.0))
    lattice(M, "steel", 25.0, 3.2, 2.8, 10, leg=0.24, rnd=rnd, broken=0.05)
    M.add(cube((4.6, 3.8, 3.4), (0, 0, 26.7)), "oxide")
    M.add(cube((5.0, 4.2, 0.3)), "iron", T(0, 0, 28.5) @ Rx(-6))
    M.add(cyl((0.4, 0.4, 0.0), (0.4, 0.4, 25.0), 0.45, 10), "oxide")
    M.add(cyl((-0.6, -0.4, 0.0), (-0.6, -0.4, 25.0), 0.35, 10), "iron")
    slit(M, (0.0, -1.9, 27.2), 3.0, "y-")
    M.add(cube((1.3, 0.12, 2.2), (0.9, -1.75, 1.1)), "dark")
    M.add(cube((0.3, 0.12, 0.25), (0.9, -1.8, 2.5)), "lamp")
    M.pop()
    C.add(cube((3.4, 3.4, 25.0), (-11, 0, 12.5)), None); C.add(cube((4.6, 3.8, 3.4), (-11, 0, 26.7)), None)
    # gantry over the roofs, broken over the crumpled silo (the end section hangs)
    M.push(T(-8.8, 0, 19.8)); boxtruss(M, "steel", 15.5, 1.4, 1.5, 1.9, rnd=rnd, broken=0.1); M.pop()
    M.add(cube((15.5, 1.2, 0.08), (-1.05, 0, 19.9)), "grate")
    M.push(T(6.7, 0, 19.8) @ Ry(55)); boxtruss(M, "steel", 6.5, 1.4, 1.5, 1.9, rnd=rnd, broken=0.3); M.pop()
    for cx in (-4.0, 3.0):
        M.add(cyl((cx, 0, H + R * 0.55 + 0.6), (cx, 0, 19.8), 0.35, 10), "iron")
    C.add(cube((15.5, 1.4, 1.5), (-1.05, 0, 20.55)), None)
    # ground manifold along the front
    M.add(cyl((-12.5, -4.2, 0.9), (11.0, -4.2, 0.9), 0.35, 12), "rust")
    for cx in (-4.0, 3.0, 10.0):
        M.add(cyl((cx - 1.2, -4.2, 0.9), (cx - 1.2, -3.1, 0.9), 0.3, 10), "rust")
        valve_wheel(M, (cx - 1.2, -4.2, 1.5))
        M.add(cyl((cx - 1.2, -4.2, 0.9), (cx - 1.2, -4.2, 1.5), 0.05, 6), "steel")
    for x in (-10.0, -2.0, 6.0):
        M.add(cube((0.5, 0.5, 0.9), (x, -4.2, 0.35)), "conc3")
    return M, C

def pivot_span():
    """Centre-pivot irrigation arm (a farm-array waterer): pivot, spans on wheeled A-frame towers, the far end down."""
    M, C = Mesh(), Mesh()
    # pivot
    M.add(cube((4.0, 4.0, 0.7), (0, 0, 0.0)), "conc")
    for sx in (-1, 1):
        for sy in (-1, 1):
            M.add(beam((sx * 1.6, sy * 1.6, 0.35), (sx * 0.35, sy * 0.35, 4.6), 0.18), "steel")
    M.add(cyl((0, 0, 0.3), (0, 0, 5.4), 0.25, 12), "steel")
    M.add(cube((1.0, 1.0, 0.7), (0, 0, 4.9)), "oxide")
    M.add(cube((0.8, 0.5, 1.2), (1.2, -1.6, 0.95)), "oxide")
    M.add(cube((0.2, 0.08, 0.14), (1.2, -1.87, 1.3)), "lamp")
    C.add(cube((4, 4, 5.5), (0, 0, 2.6)), None)

    def span(a, b, arch=0.5, depth=1.5, down=(0, 0, -1), n=8):
        a = Vector(a); b = Vector(b); dn = Vector(down).normalized()
        P = [a.lerp(b, i / n) + Vector((0, 0, arch * 4 * (i / n) * (1 - i / n))) for i in range(n + 1)]
        K = [a.lerp(b, i / n) + dn * depth * 4 * (i / n) * (1 - i / n) for i in range(n + 1)]
        for p, q in zip(P, P[1:]): M.add(cyl(p, q, 0.16, 10), "steel")
        for p, q in zip(K[1:-1], K[2:-1]): M.add(beam(p, q, 0.08), "steel")
        for i in range(1, n):
            M.add(beam(P[i], K[i], 0.06), "steel")
            M.add(beam(P[i - 1], K[i], 0.05), "steel"); M.add(beam(P[i + 1], K[i], 0.05), "steel")
            if i % 2 and dn.z < -0.5:                                    # drop hoses with nozzles
                q = P[i] + Vector((0, 0, -2.3))
                M.add(cyl(P[i], q, 0.03, 6), "rubber"); M.add(cyl(q, q - Vector((0, 0, 0.18)), 0.07, 8), "steel")
        for p, q in zip(P, P[1:]): C.add(beam(p, q, 0.5), None)

    def tower(x, y, ztop):
        M.add(beam((x, y - 0.25, ztop - 0.15), (x, y - 2.2, 0.75), 0.16), "steel")
        M.add(beam((x, y + 0.25, ztop - 0.15), (x, y + 2.2, 0.75), 0.16), "steel")
        M.add(beam((x, y - 1.3, 2.5), (x, y + 1.3, 2.5), 0.1), "steel")
        M.add(beam((x, y - 2.5, 0.75), (x, y + 2.5, 0.75), 0.26), "steel")
        for s in (-1, 1): wheel(M, (x, y + s * 2.5, 0.75))
        M.add(cube((0.6, 0.5, 0.45), (x, y, 1.05)), "oxide")
        C.add(cube((0.6, 5.5, 1.6), (x, y, 0.8)), None)

    H = 4.2
    M.add(cyl((0, 0, 5.4), (0.6, 0, 5.4), 0.2, 10), "steel")
    span((0.6, 0, 5.3), (14, 0, H))
    tower(14, 0, H)
    span((14, 0, H), (28, 0, H))
    tower(28, 0, H)
    span((28, 0, H), (41, 1.2, 0.95), arch=0.15, depth=1.3, down=(0, 0.6, -0.8))
    fall = T(41.3, 0.6, 0) @ Rx(80) @ T(-41.3, -0.6, 0)                  # third tower fallen on its side
    M.push(fall); C.push(fall)
    tower(41.3, 0.6, H)
    M.pop(); C.pop()
    span((41, 1.2, 0.95), (54, 3.6, 0.55), arch=0.05, depth=1.4, down=(0, 1, 0.15))
    M.add(cyl((54, 3.6, 0.55), (59.5, 4.8, 0.35), 0.12, 8), "steel")    # overhang, end gun
    M.add(cyl((59.5, 4.8, 0.35), (60.2, 5.0, 0.55), 0.09, 8, r2=0.05), "steel")
    for k in range(5):                                                   # broken-off hoses in the grass
        x = 44 + k * 2.3
        M.add(cyl((x, 3.0 - k * 0.3, 0.05), (x + 1.6, 3.5 - k * 0.2, 0.05), 0.03, 6), "rubber")
    return M, C

def collector_row():
    """One row of the collector array: tracker panels on a torque tube; panel 3 gone, panel 6 hanging, one post bent."""
    M, C = Mesh(), Mesh(); rnd = random.Random(61)
    for x in (0, 4, 8, 12, 16):
        if x == 12:
            M.add(beam((x, 0, -0.4), (x, 0, 1.0), 0.22), "steel"); M.add(beam((x, 0, 1.0), (x + 0.3, -0.25, 2.2), 0.22), "steel")
        else:
            M.add(beam((x, 0, -0.4), (x, 0, 2.2), 0.22), "steel")
        M.add(cube((0.5, 0.5, 0.4), (x, 0, 2.3)), "oxide")
        C.add(cube((0.3, 0.3, 2.4), (x, 0, 1.1)), None)
    M.add(cyl((-0.6, 0, 2.42), (16.6, 0, 2.42), 0.12, 10), "steel")
    for i in range(8):
        xc = 1.0 + i * 2.0
        if i == 2:                                     # panel gone, purlins left
            for dx in (-0.8, 0.8): M.add(cube((0.06, 3.3, 0.09), (dx, 0, -0.06)), "steel", T(xc, 0, 2.6) @ Rx(-28))
            continue
        m = T(xc, 0, 2.6) @ Rx(-28)
        if i == 5: m = T(xc, -0.2, 2.25) @ Rx(-82) @ T(0, 1.6, 0) @ Rz(5)        # hanging off its lower edge
        if i == 6: m = m @ Rz(4) @ Ry(3)
        for dx in (-0.8, 0.8): M.add(cube((0.06, 3.3, 0.09), (dx, 0, -0.06)), "steel", m)
        M.add(cube((1.9, 3.4, 0.06), (0, 0, 0.03)), "panel", m)
        for y in (-1.7, 1.7): M.add(cube((1.95, 0.05, 0.08), (0, y, 0.04)), "steel", m)
        for x in (-0.95, 0.95): M.add(cube((0.05, 3.45, 0.08), (x, 0, 0.04)), "steel", m)
        for y in (-0.57, 0.57): M.add(cube((1.9, 0.025, 0.07), (0, y, 0.04)), "steel", m)
        if i == 6: M.add(chop(cube((1.0, 1.2, 0.04)), rnd, 1), "panel", T(xc + 0.6, -2.4, 0.03) @ Rz(30))
    C.add(cube((17, 3.2, 0.3), (0, 0, 0)), None, T(8, 0, 2.6) @ Rx(-28))
    # junction box on the first post, sequence plate, cable into the grass
    M.add(cube((0.6, 0.3, 0.8), (0.0, -0.3, 1.2)), "oxide")
    M.add(cube((0.12, 0.05, 0.08), (0.15, -0.47, 1.45)), "lamp")
    M.add(cube((0.5, 0.05, 0.22), (0.0, -0.47, 0.65)), "hazard")
    cable(M, (-0.1, -0.35, 0.8), (-1.6, -0.6, 0.04), 0.1, 0.025, 6, lie=(-4.0, -0.5, 0))
    pallet(M, (6.0, -2.9), 8)
    M.add(chop(cube((1.9, 3.4, 0.06)), rnd, 1), "panel", T(6.0, -2.9, 0.18) @ Rz(80))          # a spare panel on it
    crate(M, (8.2, -3.0, 0), 0.9, -12)
    for x in (-1.5, 18.0):                                                                  # timber row-end posts
        M.add(block((0.2, 0.2, 1.6), (x, -2.2, 0.6), 0.02), "timber")
    return M, C

def pump_house():
    """Small plated pump / relay hut: caved corrugated roof, door ajar, pipe manifold and valve wheels."""
    M, C = Mesh(), Mesh(); rnd = random.Random(71)
    M.add(block((7.4, 6.4, 0.9), (0, 0, 0.05), 0.1), "conc")
    C.add(cube((7.4, 6.4, 0.9), (0, 0, 0.05)), None)
    z0, z1, t = 0.5, 4.1, 0.25
    walls = [((-3.0, -0.6), -2.5, "y"), ((0.9, 3.0), -2.5, "y"), ((-3.0, 3.0), 2.5, "y"), ((-2.5, 2.5), -3.0, "x"), ((-2.5, 2.5), 3.0, "x")]
    for (a, b), c, ax in walls:
        size = (b - a, t, z1 - z0) if ax == "y" else (t, b - a, z1 - z0)
        ctr = ((a + b) / 2, c, (z0 + z1) / 2) if ax == "y" else (c, (a + b) / 2, (z0 + z1) / 2)
        M.add(cube(size, ctr), "iron"); C.add(cube(size, ctr), None)
    M.add(cube((1.5, t, z1 - 2.7), (0.15, -2.5, (2.7 + z1) / 2)), "iron")
    M.add(cube((1.9, 0.3, 0.25), (0.15, -2.55, 2.75)), "hazard")
    for x in (-3.0, 3.0):
        for y in (-2.5, 2.5): M.add(cube((0.32, 0.32, 3.8), (x, y, 2.3)), "steel")
    for y in (-2.5, 2.5): M.add(cube((6.3, 0.34, 0.3), (0, y, 0.75)), "oxide")
    for x in (-3.0, 3.0): M.add(cube((0.34, 5.3, 0.3), (x, 0, 0.75)), "oxide")
    clad(M, (6.25, 5.25, 3.6), (0, 0, 2.3), "rust", rnd, (1.55, 1.2), missing=0.04, loose=0.08,
         holes=[((-0.8, -4, 0), (1.1, -2, 2.85)), ((2.5, -0.4, 2.7), (4, 2.0, 3.35))])
    dm = T(-0.6, -2.62, 1.6) @ Rz(-70)                                                       # plank door ajar on its hinge
    for k in range(5): M.add(cube((0.27, 0.06, 2.15), (0.16 + k * 0.28, 0, 0)), "paintwood", dm)
    for z in (-0.75, 0.75): M.add(cube((1.36, 0.05, 0.14), (0.7, -0.05, z)), "paintwood", dm)
    M.add(obox((0.1, -0.06, -0.75), (1.3, -0.06, 0.75), Vector((0, 0, 1)), 0.14, 0.05), "paintwood", dm)
    # timber lean-to on the -X side: posts, rafters off the wall, a patchy plank roof; crates and pallets under it
    for y in (-2.2, 0.0, 2.2):
        M.add(block((0.18, 0.18, 2.6), (-5.3, y, 1.3), 0.02), "timber")
        M.add(obox((-3.1, y, 3.55), (-5.5, y, 2.6), Vector((0, 1, 0)), 0.14, 0.2), "timber")
    M.add(block((0.2, 4.9, 0.2), (-5.3, 0, 2.62), 0.02), "timber")
    M.add(obox((-5.3, -2.2, 0.3), (-5.3, -1.2, 2.5), Vector((1, 0, 0)), 0.12, 0.08), "timber")
    for k in range(17):
        if rnd.random() < 0.15: continue
        y = -2.4 + k * 0.3
        M.add(obox((-3.15, y, 3.68), (-5.7, y, 2.68 - rnd.uniform(0, 0.08)), Vector((0, 1, 0)), 0.27, 0.035), "planks")
    C.add(obox((-3.15, 0, 3.6), (-5.6, 0, 2.6), Vector((0, 1, 0)), 5.0, 0.2), None)
    crate(M, (-4.4, -1.4, 0.0), 1.0, 10); crate(M, (-4.5, -0.2, 0.0), 0.9, -6); crate(M, (-4.3, -1.3, 1.0), 0.75, 30)
    pallet(M, (-4.6, 1.4), 90); pallet(M, (-4.6, 1.4), 84, 0.13); pallet(M, (-4.55, 1.4), 93, 0.26)
    slit(M, (3.0, 0.8, 3.0), 1.8, "x+", 0.2)
    # inside: a pump tank, glimpsed through the door
    M.add(cyl((-1.2, 0.6, 0.5), (-1.2, 0.6, 2.4), 0.9, 14), "oxide")
    M.add(cyl((-1.2, 0.6, 1.6), (1.5, 0.6, 1.6), 0.18, 8), "steel")
    # roof: purlins, three corrugated sheets falling to the front; the middle one caved in
    for y in (-2.6, 0.0, 2.6):
        z = z1 + 0.25 + (y + 2.6) * 0.09
        M.add(beam((-3.3, y, z), (3.3, y, z), 0.16), "steel")
    roof = T(0, 0, z1 + 0.6) @ Rx(5.2)
    for k, x in enumerate((-2.2, 0.0, 2.2)):
        if k == 1:
            M.add(cube((2.2, 3.4, 0.05), (0, -1.7, 0)), "corr", roof @ T(x, 3.2, 0) @ Rx(24))
            continue
        M.add(cube((2.25, 6.6, 0.05), (x, 0, 0)), "corr", roof)
    C.add(cube((6.6, 6.0, 0.3), (0, 0, z1 + 0.55)), None)
    # vent stack, door lamp
    M.add(cyl((2.0, 1.6, z1), (2.0, 1.6, 7.2), 0.3, 10), "iron")
    M.add(cyl((2.0, 1.6, 7.2), (2.0, 1.6, 7.45), 0.45, 10, r2=0.15), "iron")
    M.add(beam((0.15, -2.6, 3.5), (0.15, -3.1, 3.5), 0.06), "steel")
    M.add(cube((0.25, 0.25, 0.18), (0.15, -3.15, 3.4)), "lamp")
    # pipe manifold out of the +X wall into the ground, valve wheels on stems
    for y in (-1.2, 0.4):
        M.add(cyl((3.0, y, 1.3), (5.0, y, 1.3), 0.2, 10), "rust")
        M.add(cyl((5.0, y, 1.3), (5.0, y, -0.4), 0.2, 10), "rust")
        M.add(cyl((4.95, y, 1.3), (5.05, y, 1.3), 0.3, 10), "steel")      # elbow collar
        M.add(cyl((4.0, y, 1.3), (4.0, y, 1.85), 0.05, 6), "steel")
        valve_wheel(M, (4.0, y, 1.9), 0.25)
    M.add(cube((0.5, 0.5, 0.8), (5.0, 2.0, 0.4)), "conc3")
    return M, C

def field_marker(digits, tipped=False, seed=0):
    """Hexagonal plot marker of the array sequence (the painting's foreground block): numbered disc on the hex face."""
    M, C = Mesh(), Mesh(); rnd = random.Random(seed)
    R, D, zc = 0.85, 0.75, 0.62
    hexp = [(R * math.cos(math.radians(a)), zc + R * math.sin(math.radians(a))) for a in range(0, 360, 60)]
    if tipped:
        M.push(T(0, 0.15, -0.12) @ Rx(-16) @ Ry(11)); C.push(T(0, 0.15, -0.12) @ Rx(-16) @ Ry(11))
    body = prism(hexp, -D / 2, D / 2, bevel=0.05)
    if tipped: body = chop(body, rnd, 2, 0.12)
    M.add(body, "conc3")
    for x, z in hexp:                                  # corner bolts
        q = Vector((0, zc)) + (Vector((x, z)) - Vector((0, zc))) * 0.84
        M.add(cyl((q.x, -D / 2 - 0.02, q.y), (q.x, -D / 2 + 0.02, q.y), 0.05, 8), "steel")
    M.add(cyl((0, -D / 2 - 0.012, zc), (0, -D / 2 + 0.01, zc), 0.58, 28), "iron")
    M.add(torus(0.58, 0.025, 28, 5), "steel", T(0, -D / 2 - 0.01, zc) @ Rx(90))
    s = str(digits)
    for k, ch in enumerate(s):
        digit(M, int(ch), ((k - (len(s) - 1) / 2) * 0.38, zc), y=-D / 2 - 0.025)
    C.add(prism(hexp, -D / 2, D / 2), None)
    return M, C

def field_barn():
    """Timber-framed field barn: plank siding with gaps and lost boards, rusted corrugated roof (the far end bay
    collapsed), sliding door off its track, hay-loft hoist beam on the gable."""
    M, C = Mesh(), Mesh(); rnd = random.Random(81)
    W, D, HW, RZ = 10.0, 7.0, 4.2, 6.6               # width (x), depth (y), wall plate, ridge
    hx, hy = W / 2, D / 2
    M.add(block((W + 0.6, D + 0.6, 0.6), (0, 0, 0.0), 0.08), "conc3")
    C.add(cube((W + 0.6, D + 0.6, 0.6), (0, 0, 0.0)), None)
    xs = [-5.0, -2.5, 0.0, 2.5, 5.0]
    for x in xs:
        for y in (-hy, hy):
            if (x, y) == (5.0, hy): continue                                   # this corner post is gone
            M.add(block((0.26, 0.26, HW - 0.3), (x, y, 0.3 + (HW - 0.3) / 2), 0.03), "timber")
    for y in (-1.75, 1.75):
        for x in (-hx, hx): M.add(block((0.26, 0.26, HW + 1.2), (x, y, 0.3 + (HW + 0.9) / 2), 0.03), "timber")
    M.add(block((W + 0.3, 0.28, 0.3), (0, -hy, HW), 0.03), "timber")
    M.add(obox((-hx - 0.15, hy, HW), (hx - 0.4, hy, HW - 0.55), Vector((0, 1, 0)), 0.28, 0.3), "timber")   # sagging plate
    for x in (-hx, hx): M.add(block((0.28, D + 0.3, 0.3), (x, 0, HW), 0.03), "timber")
    for x in xs[:-1]:                                                           # knee braces
        for y in (-hy, hy):
            M.add(obox((x + 0.1, y, HW - 1.1), (x + 1.0, y, HW - 0.15), Vector((0, 1, 0)), 0.16, 0.14), "timber")
    # siding: vertical boards on all four walls (gables up to the roof line); the sliding-door opening left clear
    gable = lambda s_: HW + (RZ - HW) * (1 - abs(s_ * 2 - 1))
    boards(M, (-hx, -hy, 0), (-2.6, -hy, 0), 0.3, lambda s_: HW, "planks", rnd)
    boards(M, (1.6, -hy, 0), (hx, -hy, 0), 0.3, lambda s_: HW, "planks", rnd)
    boards(M, (hx, hy, 0), (-hx, hy, 0), 0.3, lambda s_: HW - 0.35 * (1 - s_), "planks", rnd, missing=0.12)
    boards(M, (-hx, hy, 0), (-hx, -hy, 0), 0.3, gable, "paintwood", rnd, missing=0.05)
    boards(M, (hx, -hy, 0), (hx, hy, 0), 0.3, lambda s_: min(gable(s_), HW + 0.4), "planks", rnd, missing=0.2)
    for x in (-hx, hx):
        for z in (1.2, 3.0): M.add(cube((0.12, D, 0.14), (x, 0, z)), "timber")
    for z in (1.2, 3.0):
        M.add(cube((W, 0.12, 0.14), (0, -hy, z)), "timber"); M.add(cube((W, 0.12, 0.14), (0, hy, z)), "timber")
    C.add(cube((W, 0.3, HW), (0, hy, HW / 2)), None)
    C.add(cube((0.3, D, HW), (-hx, 0, HW / 2)), None); C.add(cube((0.3, D, HW), (hx, 0, HW / 2)), None)
    C.add(cube((2.4, 0.3, HW), (-3.8, -hy, HW / 2)), None); C.add(cube((3.4, 0.3, HW), (3.3, -hy, HW / 2)), None)
    # sliding door: off its top track, leaning against the wall; track rail above the opening
    M.add(cube((4.6, 0.1, 0.12), (-0.5, -hy - 0.2, HW - 0.25)), "steel")
    dm = T(-1.9, -hy - 0.55, 0.3) @ Rx(-7) @ Rz(-4)
    for k in range(9): M.add(cube((0.3, 0.06, 3.5), (k * 0.32, 0, 1.75)), "paintwood", dm)
    for z in (0.3, 1.75, 3.2): M.add(cube((2.85, 0.07, 0.18), (1.28, -0.06, z)), "paintwood", dm)
    M.add(obox((0.1, -0.07, 0.35), (2.5, -0.07, 1.7), Vector((0, 0, 1)), 0.18, 0.05), "paintwood", dm)
    M.add(obox((0.1, -0.07, 1.8), (2.5, -0.07, 3.15), Vector((0, 0, 1)), 0.18, 0.05), "paintwood", dm)
    # hay loft door + hoist beam with pulley and rope on the -X gable
    M.add(cube((0.08, 1.4, 1.3), (-hx - 0.12, 0, 5.0)), "dark")
    M.add(block((2.2, 0.24, 0.26), (-hx - 0.9, 0, 6.15), 0.03), "timber")
    M.add(torus(0.16, 0.04, 12, 4), "steel", T(-hx - 1.8, 0, 5.9) @ Rx(90))
    cable(M, (-hx - 1.8, 0.0, 5.8), (-hx - 2.0, 0.3, 0.1), 0.05, 0.02, 6, lie=(-0.8, 0.6, 0))
    # roof: rafters, purlins, corrugated sheets; the +X end bay has fallen in
    for x in [-5.2 + k * 1.3 for k in range(9)]:
        if x > 3.8: continue
        for sy in (-1, 1):
            M.add(obox((x, sy * (hy + 0.4), HW - 0.1), (x, 0, RZ + 0.05), Vector((1, 0, 0)), 0.12, 0.2), "timber")
    M.add(block((9.4, 0.22, 0.26), (-0.5, 0, RZ + 0.05), 0.03), "timber")
    for sy in (-1, 1):
        for f in (0.33, 0.66):
            y = sy * hy * (1 - f); z = HW + (RZ - HW) * f + 0.2
            M.add(cube((9.4, 0.12, 0.12), (-0.5, y, z)), "timber")
    for sy in (-1, 1):
        for k in range(10):
            x = -5.5 + k * 1.1 + 0.55
            if x > 3.6 and not (sy < 0 and k == 8): continue
            if rnd.random() < 0.08: continue
            p0 = Vector((x, sy * (hy + 0.55), HW - 0.05)); p1 = Vector((x, sy * 0.05, RZ + 0.25))
            slip = (p1 - p0).normalized() * (rnd.uniform(0.3, 0.9) if rnd.random() < 0.15 else 0.0)
            M.add(obox(p0 - slip, p1 - slip, Vector((1, 0, 0)), 1.12, 0.04), "corr")
        C.add(obox((-0.5, sy * (hy + 0.5), HW + 0.1), (-0.5, 0, RZ + 0.3), Vector((1, 0, 0)), 10.0, 0.25), None)
    # the collapsed end: rafters and sheets slumped into the bay, a broken corner post
    for k in range(3):
        M.add(obox((4.2 + k * 0.4, -2.4 + k * 1.9, 1.0 + k * 0.4), (4.6 + k * 0.3, -0.2 + k * 1.2, RZ - 1.6 - k * 0.6),
                   Vector((1, 0, 0)), 0.12, 0.2), "timber")
    M.add(obox((4.0, 1.0, 0.4), (4.9, 3.3, 2.8), Vector((1, 0, 0)), 2.2, 0.04), "corr")
    M.add(obox((4.6, -3.0, 2.2), (5.2, -0.5, 4.6), Vector((1, 0, 0)), 1.1, 0.04), "corr")
    M.add(block((0.26, 0.26, 2.4)), "timber", T(5.7, hy + 0.9, 0.18) @ Ry(84) @ Rz(20))
    # leftovers outside
    crate(M, (-3.6, -hy - 1.6, 0), 1.1, 12); crate(M, (-4.8, -hy - 1.3, 0), 0.9, -20)
    pallet(M, (3.6, -hy - 1.4), 15); pallet(M, (3.7, -hy - 1.45), 22, 0.13)
    cribbing(M, (-6.8, 2.6, 0), 3, 1.8, 30)
    return M, C

def water_tower():
    """Wooden stave water tank on a steel lattice stand: iron hoops, a few staves burst, shingled cone roof, ladder."""
    M, C = Mesh(), Mesh(); rnd = random.Random(91)
    for sx in (-1, 1):
        for sy in (-1, 1):
            M.add(chop(block((1.3, 1.3, 1.1), (sx * 3.0, sy * 3.0, 0.1)), rnd, 1, 0.12), "conc")
    lattice(M, "steel", 10.0, 6.0, 4.6, 3, leg=0.3, rnd=rnd, broken=0.12)
    C.add(cube((6, 6, 10), (0, 0, 5)), None)
    M.push(T(0, 0, 10.0) @ Rx(2.5) @ Ry(-1.5)); C.push(T(0, 0, 10.0) @ Rx(2.5) @ Ry(-1.5))   # the top has settled
    for y in (-1.4, 0.0, 1.4): M.add(block((5.4, 0.3, 0.36), (0, y, 0.18), 0.03), "timber")
    for k in range(18):
        if rnd.random() < 0.06: continue
        M.add(cube((0.3, 5.6, 0.06), (-2.6 + k * 0.31, 0, 0.39)), "planks")
    for a, b in (((-2.8, -2.8), (2.8, -2.8)), ((2.8, -2.8), (2.8, 2.8)), ((2.8, 2.8), (-2.8, 2.8)), ((-2.8, 2.8), (-2.8, -2.8))):
        railing(M, (*a, 0.42), (*b, 0.42), 1.0, 1.4, rnd, 0.25)
    R, H, n = 2.4, 4.4, 34
    M.add(cyl((0, 0, 0.42), (0, 0, H + 0.2), R - 0.12, 24), "dark")             # inner face seen through burst staves
    for k in range(n):
        a = 2 * math.pi * (k + 0.5) / n
        if k in (5, 6, 19): continue                                             # burst staves
        top = H + 0.45 - (rnd.uniform(0.4, 1.4) if k in (7, 18) else 0.0)
        c = Vector((math.cos(a) * R, math.sin(a) * R, 0))
        M.add(obox((c.x, c.y, 0.42), (c.x, c.y, top), Vector((-math.sin(a), math.cos(a), 0)), 2 * math.pi * R / n * 0.95, 0.1),
              "paintwood" if k % 9 else "planks")
    M.add(obox((math.cos(0.95) * (R + 1.0), math.sin(0.95) * (R + 1.0), 0.48), (math.cos(1.1) * (R + 0.3), math.sin(1.1) * (R + 0.3), 1.9),
               Vector((0, 0, 1)), 0.4, 0.1), "paintwood")                       # a burst stave fallen against the rail
    for z in (0.9, 1.9, 2.9, 3.9):
        M.add(torus(R + 0.07, 0.035, 34, 4), "rust", T(0, 0, z))
    M.add(cyl((0, 0, H + 0.4), (0, 0, H + 2.0), R + 0.35, 24, r2=0.18, smooth=False), "planks")
    M.add(cyl((0, 0, H + 1.9), (0, 0, H + 2.6), 0.08, 6), "steel")
    M.add(cube((0.5, 0.06, 0.5), (0, 0, H + 2.45)), "steel")                  # weather vane, rusted fast
    C.add(cyl((0, 0, 0.42), (0, 0, H + 1.4), R + 0.1, 12, smooth=False), None)
    C.add(cube((5.6, 5.6, 0.45), (0, 0, 0.22)), None)
    spout = M.xf((0, -R - 0.1, 0.9))
    M.pop(); C.pop()
    # outlet pipe down the middle, a swing spout, the ladder up the -Y side
    M.add(cyl((0, 0, 0.0), (0, 0, 10.0), 0.22, 10), "rust")
    M.add(cyl(spout, spout + Vector((0.3, -1.6, -0.8)), 0.15, 8), "rust")
    for x in (-0.3, 0.3):
        M.add(beam((x + 0.6, -3.15, 0.0), (x + 0.6, -2.6, 11.2), 0.06), "steel")
    for k in range(27):
        z = 0.4 + k * 0.4; y = -3.15 + 0.55 * z / 11.2
        M.add(beam((0.3, y, z), (0.9, y, z), 0.035), "steel")
    crate(M, (2.0, -4.6, 0), 1.0, 20); pallet(M, (-3.6, -4.2), -10)
    return M, C

# ---------------------------------------------------------------------------------------------- build
PIECES = [
    ("FarmProcessor", farm_processor, (0, 0)),
    ("SowerBoomFallen", sower_boom, (55, 0)),
    ("CommTowerFallen", comm_tower_fallen, (95, -5)),
    ("CommTowerLeaning", comm_tower_leaning, (160, 0)),
    ("GrainSilos", grain_silos, (215, 0)),
    ("PivotSpan", pivot_span, (250, 30)),
    ("CollectorRow", collector_row, (255, -15)),
    ("PumpHouse", pump_house, (285, -15)),
    ("FieldBarn", field_barn, (285, 20)),
    ("WaterTower", water_tower, (310, 20)),
    ("FieldMarker07", lambda: field_marker(7, seed=1), (300, -18)),
    ("FieldMarker12", lambda: field_marker(12, seed=2), (304, -18)),
    ("FieldMarker03", lambda: field_marker(3, tipped=True, seed=3), (308, -18)),
]
built = []
for name, fn, (x, y) in PIECES:
    c = bpy.data.collections.new("EF_" + name)
    ROOT.children.link(c)
    vis, col = fn()
    ob = vis.obj(name, c, (x, y, 0))
    co = col.obj(name + "-colonly", c)
    co.parent = ob
    co.display_type = "WIRE"
    co.hide_render = True
    built += [ob, co]
    zmin = min(v.co.z for v in ob.data.vertices)
    print("%-18s %6d faces  %4d collision faces  zmin %.2f" % (name, len(ob.data.polygons), len(co.data.polygons), zmin))

# ---------------------------------------------------------------------------------------------- showcase (not exported)
show = bpy.data.collections.new("EF_Showcase")
SC.collection.children.link(show)
bm = bmesh.new(); bmesh.ops.create_grid(bm, x_segments=1, y_segments=1, size=1200)
gme = bpy.data.meshes.new("ShowGround"); bm.to_mesh(gme); bm.free()
gme.materials.append(flat("M_EF_ShowGround", (0.42, 0.3, 0.1), 0.95))
g = bpy.data.objects.new("ShowGround", gme); g.location = (150, 0, -0.02); show.objects.link(g)
sun_d = bpy.data.lights.new("ShowSun", "SUN"); sun_d.energy = 3.2; sun_d.color = (1.0, 0.8, 0.6); sun_d.angle = math.radians(2)
sun = bpy.data.objects.new("ShowSun", sun_d); show.objects.link(sun)
sun.rotation_mode = "QUATERNION"; sun.rotation_quaternion = Vector((0.85, 0.75, -0.42)).to_track_quat("-Z", "Y")
cam = bpy.data.objects.new("ShowCam", bpy.data.cameras.new("ShowCam")); show.objects.link(cam)
cam.data.lens = 35; cam.data.clip_end = 3000
SC.camera = cam
w = bpy.data.worlds.new("EF_Sky"); SC.world = w
if not w.node_tree: w.use_nodes = True
bg = next(n for n in w.node_tree.nodes if n.type == "BACKGROUND")
bg.inputs[0].default_value = (0.2, 0.36, 0.45, 1.0); bg.inputs[1].default_value = 0.9

def frame(ob, dirv=(-0.62, -1.0, 0.45), k=2.3):
    bpy.context.view_layer.update()
    pts = [ob.matrix_world @ Vector(c) for c in ob.bound_box]
    ctr = sum(pts, Vector()) / 8
    rad = max((p - ctr).length for p in pts)
    cam.location = ctr + Vector(dirv).normalized() * rad * k
    cam.rotation_mode = "QUATERNION"; cam.rotation_quaternion = (ctr - cam.location).to_track_quat("-Z", "Y")

frame(built[0])

# ---------------------------------------------------------------------------------------------- export, save
names = {o.name for o in built}
for o in SC.objects:
    o.select_set(o.name in names)
bpy.ops.export_scene.gltf(filepath=OUT_GLB, export_format="GLB", use_selection=True, use_active_scene=True,
                          export_apply=True, export_yup=True)
print("exported", OUT_GLB)
bpy.ops.wm.save_as_mainfile(filepath=OUT_BLEND, compress=True)
bpy.ops.file.make_paths_relative()
bpy.ops.wm.save_as_mainfile(filepath=OUT_BLEND, compress=True)
print("saved", OUT_BLEND, sorted({i.filepath for i in bpy.data.images}))

if PREVIEW:
    os.makedirs(PREVIEW, exist_ok=True)
    SC.render.engine = "CYCLES"                  # CPU only: Eevee in --background has crashed the Intel GPU driver
    SC.cycles.device = "CPU"
    SC.cycles.samples = 24
    SC.cycles.use_denoising = True
    SC.render.resolution_x, SC.render.resolution_y = 1280, 720
    for o in built:
        if o.name.endswith("-colonly"): continue
        frame(o)
        SC.render.filepath = os.path.join(PREVIEW, o.name + ".png")
        bpy.ops.render.render(write_still=True)
        print("rendered", o.name)
