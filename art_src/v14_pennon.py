# v14: the Pennon - a gliding wing (scripts/pennon_pickup.gd on the Peak annex plinth; held overhead while gliding,
# player.gd _glide). After the reference painting: a long blade of tapered maroon planks, wide and ragged at its
# left end, drawn out to a point on the right, streaked with tan and pink strokes; a double-rod V of struts lashed
# with rope down to a wrapped grip.
# Origin = the grip (where the hands go). Span along X, chord along Y (+Y = forward), the blade ~0.75 m above.
# Self-contained (no gen_lib). Builds into scene "Props14" / collection PENNON14 and exports assets/props/pennon.glb:
#   D:\Blender\blender.exe --background --factory-startup --python art_src\v14_pennon.py
# or in the open Blender: exec(open(r"D:\Emberlight\art_src\v14_pennon.py").read())
import bpy, bmesh, math, os, random
from mathutils import Vector

PROJ = r"D:\Emberlight"
OUT = os.path.join(PROJ, "assets", "props", "pennon.glb")
COLL = "PENNON14"
H = 0.75          # blade height above the grip

if "Props14" not in bpy.data.scenes:
    bpy.data.scenes.new("Props14")
SC = bpy.data.scenes["Props14"]
coll = bpy.data.collections.get(COLL) or bpy.data.collections.new(COLL)
if coll.name not in SC.collection.children:
    SC.collection.children.link(coll)
for o in list(coll.objects):
    bpy.data.objects.remove(o, do_unlink=True)

def mat(name, col, rough=0.8):
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    if not m.node_tree:
        m.use_nodes = True
    b = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    b.inputs["Base Color"].default_value = (*col, 1.0)
    b.inputs["Roughness"].default_value = rough
    return m

def srgb(h):
    c = [int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)]
    return tuple(x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c)

M = {"dark": mat("M_Pn_Dark", srgb("3e1410")), "rust": mat("M_Pn_Rust", srgb("6e2a1e")),
     "mid": mat("M_Pn_Mid", srgb("8e4a3c")), "tan": mat("M_Pn_Tan", srgb("b07a52")),
     "pink": mat("M_Pn_Pink", srgb("c48a80")), "grey": mat("M_Pn_Grey", srgb("8a8592")),
     "rope": mat("M_Pn_Rope", srgb("7a5446"))}

bm = bmesh.new()
mat_order = list(M.keys())

def _face(vs, m):
    f = bm.faces.new(vs)
    f.material_index = mat_order.index(m)
    f.smooth = False

def plank(x0, x1, y, z, w0, w1, th, m, curl=0.0, sag=0.03):
    """A tapered plank from x0 (chord w0) to x1 (chord w1). `curl` lifts the x0 end; `sag` bows the middle down."""
    n = 8
    rows = []
    for i in range(n + 1):
        t = i / n
        x = x0 + (x1 - x0) * t
        w = (w0 + (w1 - w0) * t) * 0.5
        zz = z + curl * (1 - t) ** 3 - sag * math.sin(t * math.pi)
        th2 = th * (1 - 0.7 * t)
        rows.append([bm.verts.new((x, y - w, zz)), bm.verts.new((x, y + w, zz)),
                     bm.verts.new((x, y + w, zz + th2)), bm.verts.new((x, y - w, zz + th2))])
    _face(rows[0][::-1], m)
    _face(rows[-1], m)
    for i in range(n):
        a, b = rows[i], rows[i + 1]
        for k in range(4):
            _face((a[k], b[k], b[(k + 1) % 4], a[(k + 1) % 4]), m)

def rod(p0, p1, r, m, seg=6):
    p0 = Vector(p0); p1 = Vector(p1)
    d = (p1 - p0).normalized()
    u = d.orthogonal().normalized(); v = d.cross(u)
    ring0 = []; ring1 = []
    for k in range(seg):
        a = 2 * math.pi * k / seg
        o = (u * math.cos(a) + v * math.sin(a)) * r
        ring0.append(bm.verts.new(p0 + o)); ring1.append(bm.verts.new(p1 + o))
    _face(ring0[::-1], m); _face(ring1, m)
    for k in range(seg):
        _face((ring0[k], ring0[(k + 1) % seg], ring1[(k + 1) % seg], ring1[k]), m)

def wrap(c, axis, r, length, m, turns=3):
    """Rope lashing: a few fat short rings along `axis` round point c."""
    c = Vector(c); a = Vector(axis).normalized()
    for k in range(turns):
        o = a * (length * (k / max(turns - 1, 1) - 0.5))
        rod(c + o - a * 0.012, c + o + a * 0.012, r, m, 8)

# ---------------------------------------------------------------------------------------------- the blade
random.seed(14)
# main planks, staggered across the chord; ragged left ends, drawn to a point on the right
for x0, x1, y, dz, w0, w1, m, curl in [
        (-1.50, 1.55, 0.06, 0.05, 0.17, 0.015, "dark", 0.07),
        (-1.32, 1.38, -0.10, 0.02, 0.16, 0.02, "dark", 0.04),
        (-1.18, 1.22, 0.22, 0.03, 0.13, 0.02, "rust", 0.03),
        (-1.05, 1.10, -0.25, 0.00, 0.14, 0.02, "dark", 0.02),
        (-0.70, 0.95, -0.38, -0.02, 0.10, 0.02, "rust", 0.0),
        (-0.85, 1.00, 0.34, 0.01, 0.09, 0.015, "dark", 0.0)]:
    plank(x0, x1, y, H + dz, w0, w1, 0.035, m, curl)
# stroke strips laid along the top: tan and pink highlights, a few mid-rust
for _ in range(11):
    x0 = random.uniform(-1.4, -0.3); x1 = x0 + random.uniform(0.9, 2.2)
    x1 = min(x1, 1.3)
    y = random.uniform(-0.32, 0.3)
    m = random.choice(["tan", "pink", "mid", "tan"])
    plank(x0, x1, y, H + 0.045, random.uniform(0.025, 0.045), 0.01, 0.008, m, 0.0, 0.025)
# cross lashings over the planks above each strut (the painting's diagonal ticks)
for xc in (-0.3, 0.4):
    for k in range(3):
        y0 = -0.4 + k * 0.05
        rod((xc - 0.12, y0, H + 0.06), (xc + 0.12, y0 + 0.75, H + 0.06), 0.012, "pink", 5)
# a darker spar under the blade, root to tip
rod((-1.35, 0.0, H - 0.02), (1.3, 0.0, H - 0.03), 0.03, "dark", 8)

# ---------------------------------------------------------------------------------------------- struts + grip
for xt, xb in ((-0.32, -0.05), (0.42, 0.05)):
    for dy in (-0.025, 0.025):
        rod((xt, dy, H - 0.03), (xb, dy, 0.0), 0.011, "rust", 6)
    top = Vector((xt, 0, H - 0.03)).lerp(Vector((xb, 0, 0.0)), 0.18)
    wrap(top, Vector((xb - xt, 0, -H)), 0.026, 0.07, "rope", 3)
    mid = Vector((xt, 0, H - 0.03)).lerp(Vector((xb, 0, 0.0)), 0.88)
    wrap(mid, Vector((xb - xt, 0, -H)), 0.024, 0.04, "rope", 2)
rod((-0.13, 0, 0), (0.13, 0, 0), 0.03, "grey", 10)          # the grip
for k in range(6):
    x = -0.11 + k * 0.044
    rod((x - 0.01, 0, 0), (x + 0.01, 0, 0), 0.04, "grey" if k % 2 else "rope", 10)

me = bpy.data.meshes.new("Pennon")
bm.normal_update()
bm.to_mesh(me); bm.free()
for k in mat_order:
    me.materials.append(M[k])
ob = bpy.data.objects.new("Pennon", me)
coll.objects.link(ob)
print("pennon built: %d verts" % len(me.vertices))

# ---------------------------------------------------------------------------------------------- export
# the exporter works on the active scene: in the open Blender switch to Props14 first (CLAUDE.md pitfall); in a
# --background run there's no window, so link the collection into the default scene instead
scene = bpy.context.scene
if bpy.app.background and scene != SC and coll.name not in scene.collection.children:
    scene.collection.children.link(coll)
assert bpy.app.background or scene == SC, "make Props14 the active scene, then run again to export"
for o in scene.objects:
    o.select_set(o.name == "Pennon")
bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", use_selection=True, use_active_scene=True,
                          export_apply=True, export_yup=True)
print("exported", OUT)
