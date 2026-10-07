# v11: loot crates for the surface (surface.tscn "Loot/Crate_*", scripts/supply_crate.gd).
# Two small variants in the works' palette, so they sit beside the static crates and drums of v5_surface.py:
#   supply_crate.glb - painted steel crate (blue-grey rust sheet panels, steel frame + cross braces, carry handles)
#   parts_case.glb   - squat steel parts case with a hazard band and ribbed lid
# Each is split into separate nodes so Godot can pry the lid open or burst the crate apart. Node names carry a
# variant prefix (Blender names are global): <P>_Floor, <P>_Side_F (+Y, latch side = front), <P>_Side_B, <P>_Side_L,
# <P>_Side_R, <P>_Lid (origin on the hinge, back top edge); P = SC (supply crate) / PC (parts case).
# Blender scene "Props11", collections CRATE11_<variant>. Y forward (Godot -Z), Z up, origin at the floor centre.
# Run: exec(open(r"D:\Emberlight\art_src\v11_crates.py").read()); build_crates()  then  export_crates()
exec(open(r"D:\Emberlight\art_src\gen_lib.py").read())
PROJ = r"D:\Emberlight"
TEX = os.path.join(PROJ, "art_src", "tex")

if "Props11" not in bpy.data.scenes:
    bpy.data.scenes.new("Props11")
P11 = bpy.data.scenes["Props11"]
TMP11 = "C11_TMP"
VARIANTS = (("supply_crate", "SC"), ("parts_case", "PC"))

def _c11(name):
    c = bpy.data.collections.get(name)
    if c is None:
        c = bpy.data.collections.new(name)
    if c.name not in P11.collection.children:
        P11.collection.children.link(c)
    return c

def piece(coll_name, name, build, pivot=(0, 0, 0)):
    """build() makes meshes in TMP11; they're merged into one object `name` (in coll_name) whose origin is `pivot`."""
    old = bpy.data.objects.get(name)
    if old: bpy.data.objects.remove(old, do_unlink=True)
    tmp = _c11(TMP11)
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
    for m in mats: me.materials.append(m)
    ob = bpy.data.objects.new(name, me)
    _c11(coll_name).objects.link(ob)
    box_uv(ob)                    # world-space box UVs, before the pivot shift
    me.transform(Matrix.Translation(-Vector(pivot)))
    ob.location = pivot
    return ob

def build_supply_crate():
    """0.78 x 0.52 x 0.48: blue-grey sheet panels in a steel angle frame, an X brace on the long sides."""
    V = "CRATE11_supply_crate"; T = TMP11; P = "SC_"
    c = _c11(V)
    for o in list(c.objects): bpy.data.objects.remove(o, do_unlink=True)
    W, D, H, t, f = 0.39, 0.26, 0.48, 0.022, 0.035      # half width, half depth, height, panel, frame bar
    def floor():
        boxmm(T, "M_RustSheet", -W, W, -D, D, 0.035, 0.035 + t, "floor", 0.004)
        for x in (-W + 0.07, W - 0.07):                 # skids
            boxmm(T, "M_Steel", x - 0.03, x + 0.03, -D, D, 0.0, 0.035, "skid", 0.006)
    piece(V, P + "Floor", floor)
    for nm, sy in (("Side_F", 1), ("Side_B", -1)):
        def side(sy=sy):
            y = sy * (D - t / 2)
            boxmm(T, "M_RustSheet", -W + f, W - f, y - t / 2, y + t / 2, 0.035, H - 0.03, "panel", 0.003)
            yo = sy * (D - f / 2 + 0.004)
            for z in (0.035 + f / 2, H - f / 2 - 0.03):
                member(T, "M_Steel", (-W, yo, z), (W, yo, z), f, f, "fx")
            for x in (-W + f / 2, W - f / 2):
                member(T, "M_Steel", (x, yo, 0.035), (x, yo, H - 0.03), f, f, "fz")
            yb = sy * (D + 0.004)
            member(T, "M_Steel", (-W + f, yb, 0.035 + f), (W - f, yb, H - 0.03 - f), 0.022, 0.012, "brace")
            member(T, "M_Steel", (-W + f, yb, H - 0.03 - f), (W - f, yb, 0.035 + f), 0.022, 0.012, "brace")
            if sy > 0:                                  # hasp + a hazard label on the front
                boxmm(T, "M_Steel", -0.045, 0.045, yb, yb + 0.02, H - 0.13, H - 0.05, "hasp", 0.004)
                boxmm(T, "M_Hazard", -0.13, 0.13, yb - 0.002, yb + 0.004, 0.11, 0.17, "label", 0.0)
        piece(V, P + nm, side)
    for nm, sx in (("Side_L", -1), ("Side_R", 1)):
        def end(sx=sx):
            x = sx * (W - t / 2)
            boxmm(T, "M_RustSheet", x - t / 2, x + t / 2, -D + f, D - f, 0.035, H - 0.03, "end", 0.003)
            xo = sx * (W + 0.03)
            boxmm(T, "M_Steel", xo - 0.012, xo + 0.012, -0.11, 0.11, H - 0.15, H - 0.12, "grip", 0.004)   # carry handle
            for yy in (-0.1, 0.1):
                member(T, "M_Steel", (sx * W, yy, H - 0.135), (xo, yy, H - 0.135), 0.024, 0.024, "grip_lug")
        piece(V, P + nm, end)
    def lid():
        z = H - 0.03
        boxmm(T, "M_RustSheet", -W - 0.01, W + 0.01, -D - 0.01, D + 0.01, z, z + 0.026, "lid", 0.006)
        boxmm(T, "M_Steel", -W - 0.012, W + 0.012, -D - 0.012, D + 0.012, z - 0.012, z + 0.004, "lid_rim", 0.0)
        for x in (-W * 0.55, W * 0.55):                 # two straps over the top
            boxmm(T, "M_Steel", x - 0.025, x + 0.025, -D - 0.014, D + 0.014, z + 0.026, z + 0.034, "strap", 0.002)
        boxmm(T, "M_Steel", -0.03, 0.03, D + 0.008, D + 0.022, z - 0.07, z + 0.02, "lid_tab", 0.003)
        boxmm(T, "M_Steel", -0.09, 0.09, -0.06, 0.06, z + 0.026, z + 0.032, "nameplate", 0.003)
    piece(V, P + "Lid", lid, (0.0, -D, H - 0.03))
    return c

def build_parts_case():
    """0.62 x 0.40 x 0.34: squat steel case, hazard band round the body, ribbed lid, side clasps."""
    V = "CRATE11_parts_case"; T = TMP11; P = "PC_"
    c = _c11(V)
    for o in list(c.objects): bpy.data.objects.remove(o, do_unlink=True)
    W, D, H, t = 0.31, 0.2, 0.30, 0.02
    foot = "M_Rubber" if "M_Rubber" in bpy.data.materials else "M_Steel"
    def floor():
        boxmm(T, "M_Steel", -W, W, -D, D, 0.012, 0.042, "base", 0.008)
        for x in (-W + 0.05, W - 0.05):
            for y in (-D + 0.05, D - 0.05):
                cyl(T, foot, (x, y, 0.0), (x, y, 0.012), 0.022, 8, "foot")
    piece(V, P + "Floor", floor)
    for nm, sy in (("Side_F", 1), ("Side_B", -1)):
        def side(sy=sy):
            y = sy * (D - t / 2)
            boxmm(T, "M_Corrugated", -W, W, y - t / 2, y + t / 2, 0.042, H, "wall", 0.004)
            yb = sy * (D + 0.003)
            boxmm(T, "M_Hazard", -W, W, yb - 0.004, yb + 0.002, H - 0.11, H - 0.06, "band", 0.0)
            if sy > 0:
                for x in (-W * 0.6, W * 0.6):           # clasps
                    boxmm(T, "M_Steel", x - 0.03, x + 0.03, yb, yb + 0.022, H - 0.09, H - 0.02, "clasp", 0.004)
        piece(V, P + nm, side)
    for nm, sx in (("Side_L", -1), ("Side_R", 1)):
        def end(sx=sx):
            x = sx * (W - t / 2)
            boxmm(T, "M_Corrugated", x - t / 2, x + t / 2, -D + t, D - t, 0.042, H, "end", 0.004)
            xb = sx * (W + 0.003)
            boxmm(T, "M_Hazard", xb - 0.004, xb + 0.002, -D + t, D - t, H - 0.11, H - 0.06, "band", 0.0)
            cyl(T, "M_Steel", (sx * (W + 0.03), -0.08, H - 0.16), (sx * (W + 0.03), 0.08, H - 0.16), 0.012, 8, "handle")
            for yy in (-0.08, 0.08):
                member(T, "M_Steel", (sx * W, yy, H - 0.16), (sx * (W + 0.03), yy, H - 0.16), 0.016, 0.016, "handle_lug")
        piece(V, P + nm, end)
    def lid():
        boxmm(T, "M_Steel", -W - 0.008, W + 0.008, -D - 0.008, D + 0.008, H, H + 0.04, "lid", 0.01)
        for k in range(5):                              # stiffening ribs
            x = -W + 0.08 + k * (2 * W - 0.16) / 4
            boxmm(T, "M_Steel", x - 0.012, x + 0.012, -D + 0.02, D - 0.02, H + 0.04, H + 0.055, "rib", 0.003)
        boxmm(T, "M_Hazard", -W + 0.02, -W + 0.12, -D + 0.04, D - 0.04, H + 0.04, H + 0.043, "tag", 0.0)
    piece(V, P + "Lid", lid, (0.0, -D, H))
    return c

def build_crates():
    win = bpy.context.window
    if win: win.scene = P11
    a = build_supply_crate(); b = build_parts_case()
    for o in b.objects: o.location.x += 1.2              # side by side in the Props11 scene
    for o in list(_c11(TMP11).objects): bpy.data.objects.remove(o, do_unlink=True)
    print("crates:", [(o.name, len(o.data.vertices)) for c in (a, b) for o in c.objects])

def export_crates():
    sc = bpy.context.scene
    assert sc.name == "Props11", "make Props11 the active scene first"
    for i, (v, _p) in enumerate(VARIANTS):
        objs = list(bpy.data.collections["CRATE11_" + v].objects)
        off = 1.2 * i
        for o in objs: o.location.x -= off              # back to the origin for the export
        names = {o.name for o in objs}
        for o in sc.objects:
            o.select_set(o.name in names)
        bpy.ops.export_scene.gltf(filepath=os.path.join(PROJ, "assets", "props", v + ".glb"), export_format='GLB',
                                  use_selection=True, use_active_scene=True, export_apply=True, export_yup=True)
        for o in objs: o.location.x += off
        print("exported", v, sorted(names))