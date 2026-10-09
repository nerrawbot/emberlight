# v16: the Ember rifle - a furnace long-gun from Emberlight (debug-only kit for now: player.gd v16, scripts/ember_rifle.gd).
# Silhouette after the reference (skeletal stock, pistol grip, boxy receiver with a drum on top, ribbed shroud, long thin
# barrel, rod under the barrel); themed as a furnace: oxblood-enamelled iron, brass fittings, dark wood, a caged ember
# chamber in the drum, glowing vents between the shroud ribs, a small flue stack in place of the reference knob.
# Origin = the grip (trigger). Barrel along +Y (= Godot -Z), up +Z. Rear sight notch at z 0.158, front post top z 0.122, muzzle at y 0.862.
# Objects (separate glTF nodes): Rifle (body), Lever (bolt handle, origin at its pivot; swings for the reload),
# Coal (the chamber ember, M_ER_Coal), Vents (glow rings between the ribs, M_ER_Vent), Muzzle (empty at the bore).
# Self-contained. Builds into scene "Props16" / collection RIFLE16 and exports assets/props/ember_rifle.glb:
#   D:\Blender\blender.exe --background --factory-startup --python art_src\v16_ember_rifle.py
import bpy, bmesh, math, os
from mathutils import Vector

PROJ = r"D:\Emberlight"
OUT = os.path.join(PROJ, "assets", "props", "ember_rifle.glb")
COLL = "RIFLE16"
AX = 0.05          # barrel / shroud axis height
TEX = os.path.join(PROJ, "art_src", "tex")
UVS = 2.4          # box-projected UVs: texture tiles per metre (one tile ~ 0.42 m)

if "Props16" not in bpy.data.scenes:
    bpy.data.scenes.new("Props16")
SC = bpy.data.scenes["Props16"]
coll = bpy.data.collections.get(COLL) or bpy.data.collections.new(COLL)
if coll.name not in SC.collection.children:
    SC.collection.children.link(coll)
for o in list(coll.objects):
    bpy.data.objects.remove(o, do_unlink=True)

def srgb(h):
    c = [int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)]
    return tuple(x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c)

def mat(name, hexcol, rough=0.6, metal=0.0, emit=None, tex=None):
    """tex: a palette-graded Poly Haven map in art_src/tex (already in the material colour; base colour then stays white
    and Godot reads the texture: ember_rifle.gd paints with it through the mesh UVs)."""
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    if not m.node_tree:
        m.use_nodes = True
    nt = m.node_tree
    b = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    for n in [n for n in nt.nodes if n.type == "TEX_IMAGE"]:
        nt.nodes.remove(n)
    if tex:
        im = bpy.data.images.load(os.path.join(TEX, tex + ".png"), check_existing=True)
        tn = nt.nodes.new("ShaderNodeTexImage")
        tn.image = im
        nt.links.new(tn.outputs["Color"], b.inputs["Base Color"])
    b.inputs["Base Color"].default_value = (*srgb(hexcol), 1.0)
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    if emit:
        b.inputs["Emission Color"].default_value = (*srgb(emit), 1.0)
        b.inputs["Emission Strength"].default_value = 3.0
    return m

# textures: rusty_metal_02 (enamel), blue_metal_plate (brass scuffs), metal_plate_02 (iron), dark_wooden_planks (wood);
# Poly Haven, CC0, graded to these colours in the open Blender (see the er_*.png notes in CLAUDE.md)
M = {"red": mat("M_ER_Red", "5c1616", 0.45, 0.3, tex="er_red"), "redhi": mat("M_ER_RedHi", "8a2a1e", 0.45, 0.3),
     "iron": mat("M_ER_Iron", "26211f", 0.55, 0.6, tex="er_iron"), "brass": mat("M_ER_Brass", "b48a46", 0.35, 0.8, tex="er_brass"),
     "wood": mat("M_ER_Wood", "4a2a1a", 0.7, tex="er_wood"), "wooddk": mat("M_ER_WoodDark", "2e1a12", 0.75, tex="er_wooddk"),
     "face": mat("M_ER_Face", "d8c8a4", 0.6),
     "coal": mat("M_ER_Coal", "ff7a2a", 0.9, 0.0, "ff6a1a"), "vent": mat("M_ER_Vent", "ff5a1e", 0.9, 0.0, "ff4a14")}

class Mesh:
    def __init__(self, keys):
        self.bm = bmesh.new()
        self.keys = keys

    def face(self, vs, m):
        f = self.bm.faces.new(vs)
        f.material_index = self.keys.index(m)
        f.smooth = False

    def box(self, a, b, m):
        """Axis-aligned box from corner a to corner b."""
        (x0, y0, z0), (x1, y1, z1) = a, b
        v = [self.bm.verts.new(p) for p in ((x0, y0, z0), (x1, y0, z0), (x1, y1, z0), (x0, y1, z0),
                                             (x0, y0, z1), (x1, y0, z1), (x1, y1, z1), (x0, y1, z1))]
        for q in ((0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)):
            self.face([v[i] for i in q], m)

    def rod(self, p0, p1, r, m, seg=8, r1=None, rot=0.0):
        p0 = Vector(p0); p1 = Vector(p1)
        d = (p1 - p0).normalized()
        u = (Vector((0, 0, 1)) if abs(d.z) < 0.9 else Vector((1, 0, 0))).cross(d).normalized()
        v = d.cross(u)
        r1 = r if r1 is None else r1
        a0 = []; a1 = []
        for k in range(seg):
            t = 2 * math.pi * k / seg + rot
            o = u * math.cos(t) + v * math.sin(t)
            a0.append(self.bm.verts.new(p0 + o * r)); a1.append(self.bm.verts.new(p1 + o * r1))
        self.face(a0[::-1], m); self.face(a1, m)
        for k in range(seg):
            self.face((a0[k], a0[(k + 1) % seg], a1[(k + 1) % seg], a1[k]), m)

    def prism(self, pts_yz, w, m, x0=0.0):
        """A side profile (list of (y, z)) extruded across X, centred on x0."""
        L = [self.bm.verts.new((x0 - w / 2, y, z)) for y, z in pts_yz]
        R = [self.bm.verts.new((x0 + w / 2, y, z)) for y, z in pts_yz]
        self.face(R, m); self.face(L[::-1], m)
        n = len(pts_yz)
        for i in range(n):
            j = (i + 1) % n
            self.face((L[i], L[j], R[j], R[i]), m)

    def obj(self, name, origin=(0, 0, 0), bevel=0.0):
        me = bpy.data.meshes.new(name)
        bmesh.ops.recalc_face_normals(self.bm, faces=self.bm.faces)
        self.bm.normal_update()
        # box-projected UVs (world scale, before the origin shift), nudged per material so parts don't share a patch
        uv = self.bm.loops.layers.uv.new("UVMap")
        for f in self.bm.faces:
            n = f.normal
            ax = max(range(3), key=lambda i: abs(n[i]))
            off = 0.37 * f.material_index
            for l in f.loops:
                co = l.vert.co
                u, v = ((co.y, co.z), (co.x, co.z), (co.x, co.y))[ax]
                l[uv].uv = (u * UVS + off, v * UVS + off * 0.61)
        bmesh.ops.translate(self.bm, verts=self.bm.verts, vec=-Vector(origin))
        self.bm.to_mesh(me); self.bm.free()
        for k in self.keys:
            me.materials.append(M[k])
        ob = bpy.data.objects.new(name, me)
        ob.location = origin
        coll.objects.link(ob)
        if bevel > 0.0:      # small chamfers catch the rim light on every edge (applied by the exporter)
            bv = ob.modifiers.new("Bevel", "BEVEL")
            bv.width = bevel
            bv.segments = 1
            bv.limit_method = "ANGLE"
            bv.angle_limit = math.radians(35)
        return ob

# ---------------------------------------------------------------------------------------------- body
B = Mesh(["red", "redhi", "iron", "brass", "wood", "wooddk", "face"])
# receiver: an oxblood box, a brass seam along its top edge
B.box((-0.031, -0.03, 0.0), (0.031, 0.21, 0.07), "red")
B.box((-0.033, -0.03, 0.066), (0.033, 0.21, 0.074), "brass")
B.box((-0.026, 0.03, -0.018), (0.026, 0.15, 0.0), "redhi")                   # belly plate
# the firebox drum on top (the reference big cylinder), brass bands at both ends and round its middle
B.rod((0, 0.0, 0.1), (0, 0.205, 0.1), 0.042, "red", 12)
for y in (0.0, 0.1, 0.19):
    B.rod((0, y, 0.1), (0, y + 0.016, 0.1), 0.046, "brass", 12)
# rear: a furnace door (what you look past when aiming): iron plate in a brass ring, a brass grille over glowing slits
# (the slits are in Coal), a latch on the right
B.rod((0, -0.006, 0.1), (0, 0.0, 0.1), 0.036, "iron", 12)
B.rod((0, -0.009, 0.1), (0, -0.004, 0.1), 0.041, "brass", 12, None, 0.0)
B.rod((0, -0.01, 0.1), (0, -0.005, 0.1), 0.031, "iron", 12)
for k in range(4):
    z = 0.081 + k * 0.0125
    B.box((-0.024, -0.0135, z - 0.0018), (0.024, -0.009, z + 0.0018), "brass")
B.box((0.026, -0.016, 0.094), (0.036, -0.008, 0.106), "brass")
B.rod((0.031, -0.02, 0.1), (0.031, -0.016, 0.1), 0.006, "iron", 6)
# pressure gauge on the left of the drum: brass bezel, cream face, an iron needle
B.rod((-0.036, 0.15, 0.104), (-0.052, 0.15, 0.104), 0.017, "brass", 12)
B.rod((-0.052, 0.15, 0.104), (-0.054, 0.15, 0.104), 0.0135, "face", 12)
B.box((-0.0555, 0.1455, 0.103), (-0.0542, 0.1565, 0.105), "iron")
B.rod((-0.02, 0.15, 0.104), (-0.036, 0.15, 0.104), 0.006, "iron", 6)
# rivets: two rows down each side of the receiver, and round the drum bands
for x in (-0.0335, 0.0335):
    for z in (0.012, 0.056):
        for k in range(6):
            y = -0.01 + k * 0.042
            B.rod((x * 0.92, y, z), (x * 1.09, y, z), 0.0034, "brass", 6)
for y in (0.008, 0.108, 0.198):
    for k in range(8):
        a = 2 * math.pi * k / 8 + 0.2
        c = Vector((0, y, 0.1)); o = Vector((math.cos(a), 0, math.sin(a)))
        B.rod(c + o * 0.044, c + o * 0.05, 0.0028, "iron", 6)
# chamber cage on the right side: an iron window frame with brass bars (the Coal object glows behind it)
B.box((0.036, 0.03, 0.074), (0.046, 0.034, 0.126), "iron")
B.box((0.036, 0.096, 0.074), (0.046, 0.1, 0.126), "iron")
for k in range(4):
    y = 0.044 + k * 0.016
    B.rod((0.047, y, 0.072), (0.047, y, 0.128), 0.0035, "brass", 6)
# flue stack (in place of the reference knob) with a cap
B.rod((0, 0.06, 0.135), (0, 0.06, 0.178), 0.011, "iron", 8)
B.rod((0, 0.06, 0.178), (0, 0.06, 0.186), 0.017, "brass", 8)
# rear sight on the drum: two posts, the notch at z 0.158 (just clears the drum bands)
B.box((-0.012, -0.004, 0.138), (-0.004, 0.012, 0.166), "brass")
B.box((0.004, -0.004, 0.138), (0.012, 0.012, 0.166), "brass")
B.box((-0.012, -0.004, 0.138), (0.012, 0.012, 0.152), "brass")
# trigger guard (brass) + trigger
B.rod((0, -0.005, -0.004), (0, -0.01, -0.04), 0.004, "brass", 6)
B.rod((0, -0.01, -0.04), (0, 0.06, -0.042), 0.004, "brass", 6)
B.rod((0, 0.06, -0.042), (0, 0.075, -0.016), 0.004, "brass", 6)
B.rod((0, 0.026, -0.002), (0, 0.032, -0.03), 0.004, "iron", 6)
# ribbed shroud: iron tube, rings proud of it (the Vents glow in the gaps)
B.rod((0, 0.21, AX), (0, 0.43, AX), 0.03, "iron", 12)
for k in range(9):
    y = 0.222 + k * 0.024
    B.rod((0, y, AX), (0, y + 0.01, AX), 0.036, "iron", 12)
B.rod((0, 0.425, AX), (0, 0.445, AX), 0.035, "brass", 12)                   # front band
# barrel, muzzle collar, front post (top at z 0.122: ember_rifle.gd tips the gun up to line it with the notch)
B.rod((0, 0.445, AX), (0, 0.83, AX), 0.012, "iron", 10)
B.rod((0, 0.80, AX), (0, 0.855, AX), 0.018, "iron", 10)
B.rod((0, 0.846, AX), (0, 0.858, AX), 0.02, "brass", 10)
# a flame crown: six brass prongs flaring off the muzzle
for k in range(6):
    a = 2 * math.pi * k / 6 + 0.26
    o = Vector((math.cos(a), 0, math.sin(a)))
    B.rod(Vector((0, 0.852, AX)) + o * 0.015, Vector((0, 0.882, AX)) + o * 0.026, 0.0038, "brass", 5, 0.0015)
B.box((-0.003, 0.812, AX + 0.012), (0.003, 0.83, 0.122), "brass")
B.box((-0.009, 0.808, AX + 0.01), (0.009, 0.834, AX + 0.026), "iron")
# the rod under the barrel with its hanger and foot (as in the reference)
B.box((-0.008, 0.43, AX - 0.04), (0.008, 0.45, AX - 0.018), "iron")
B.rod((0, 0.44, AX - 0.034), (0, 0.72, AX - 0.034), 0.006, "brass", 6)
B.rod((0, 0.70, AX - 0.012), (0, 0.70, AX - 0.06), 0.005, "iron", 6)
B.box((-0.02, 0.69, AX - 0.068), (0.02, 0.712, AX - 0.058), "iron")
# pistol grip (dark wood) and the skeletal stock (wood), brass butt plate and a brass wrap at the wrist
B.prism([(0.012, 0.0), (-0.034, 0.0), (-0.07, -0.112), (-0.032, -0.118)], 0.032, "wooddk")
B.prism([(-0.03, 0.07), (-0.03, 0.022), (-0.36, 0.046), (-0.36, 0.108)], 0.032, "wood")       # comb
B.prism([(-0.045, -0.002), (-0.06, -0.044), (-0.36, -0.084), (-0.36, -0.04)], 0.028, "wood")  # lower strut
B.prism([(-0.355, 0.112), (-0.355, -0.088), (-0.395, -0.096), (-0.395, 0.118)], 0.034, "wooddk")
B.box((-0.019, -0.408, -0.1), (0.019, -0.395, 0.122), "brass")
B.box((-0.02, -0.06, 0.02), (0.02, -0.04, 0.074), "brass")
# brass diamond inlays on both sides of the comb, ribs on the butt plate, sling swivels under the butt and barrel band
for sgn in (-1, 1):
    B.prism([(-0.17, 0.068), (-0.2, 0.082), (-0.23, 0.07), (-0.2, 0.056)], 0.004, "brass", sgn * 0.0165)
for k in range(5):
    z = -0.07 + k * 0.042
    B.box((-0.017, -0.413, z), (0.017, -0.406, z + 0.012), "brass")
B.rod((0, -0.33, -0.084), (0, -0.33, -0.1), 0.004, "iron", 6)
B.rod((-0.008, -0.34, -0.1), (0.008, -0.34, -0.1), 0.008, "iron", 6)
B.rod((0, 0.435, AX - 0.036), (0, 0.435, AX - 0.05), 0.004, "iron", 6)
B.obj("Rifle", bevel=0.0016)

# ---------------------------------------------------------------------------------------------- moving + glowing parts
LV = Mesh(["iron", "brass"])
piv = (0.033, 0.16, 0.035)
LV.rod(piv, (0.07, 0.15, 0.03), 0.005, "iron", 6)
LV.rod((0.066, 0.15, 0.03), (0.082, 0.146, 0.028), 0.011, "brass", 8)
LV.obj("Lever", piv)

CO = Mesh(["coal"])
CO.rod((0.03, 0.036, 0.1), (0.03, 0.094, 0.1), 0.024, "coal", 8, None, 0.3)
for k in range(3):
    z = 0.0872 + k * 0.0125
    CO.box((-0.021, -0.0115, z - 0.0035), (0.021, -0.0095, z + 0.0035), "coal")
CO.obj("Coal")

VE = Mesh(["vent"])
for k in range(8):
    y = 0.232 + k * 0.024
    VE.rod((0, y, AX), (0, y + 0.014, AX), 0.0325, "vent", 12)
VE.obj("Vents")

mz = bpy.data.objects.new("Muzzle", None)
mz.location = (0, 0.862, AX)
coll.objects.link(mz)

names = ["Rifle", "Lever", "Coal", "Vents", "Muzzle"]
print("rifle built:", {n: len(bpy.data.objects[n].data.vertices) for n in names if bpy.data.objects[n].data})

# ---------------------------------------------------------------------------------------------- export
scene = bpy.context.scene
if bpy.app.background and scene != SC and coll.name not in scene.collection.children:
    scene.collection.children.link(coll)
assert bpy.app.background or scene == SC, "make Props16 the active scene, then run again to export"
for o in scene.objects:
    o.select_set(o.name in names)
bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", use_selection=True, use_active_scene=True,
                          export_apply=True, export_yup=True)
print("exported", OUT)
