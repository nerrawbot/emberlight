
# v9: the warden drone - a small scrap drone branched from the cavern moth (v2_creatures.py "CR_Moth"): the same cage
# body round a glowing core and tin wings, but ~60% the size, with a pale band, a sensor lens at the front, an antenna,
# side thrusters, paired fore + hind wings in blue-grey paint, and a floating emitter ring (its shield projector).
# Found broken on the K-tower's top deck in surface.tscn (drone_pickup.gd); once repaired it orbits the player
# (drone_companion.gd) and keeps a one-block shield up (player.gd).
# Built in Blender scene "Props9" (collection DRONE9); Y forward, Z up. Parts (separate nodes, origins at their pivots):
#   DBody, DCore (core + lens, emissive), DRing (spins), DWing_L / DWing_R (hinged at the body).
# Run: exec(open(r"...\art_src\v9_drone.py").read()); build_drone()  then, with Props9 active, export_drone()
exec(open(r"C:\Users\Pigeon\Documents\UnderworksCavern\art_src\gen_lib.py").read())

if "Props9" not in bpy.data.scenes:
    bpy.data.scenes.new("Props9")
P9 = bpy.data.scenes["Props9"]
D9, TMP9 = "DRONE9", "D9_TMP"

def _p9coll(name):
    c = bpy.data.collections.get(name)
    if c is None:
        c = bpy.data.collections.new(name)
    if c.name not in P9.collection.children:
        P9.collection.children.link(c)
    return c

def piece(name, build, pivot=(0, 0, 0)):
    """build() makes meshes in TMP9; they're merged into one object `name` whose origin is `pivot`."""
    old = bpy.data.objects.get(name)
    if old: bpy.data.objects.remove(old, do_unlink=True)
    tmp = _p9coll(TMP9)
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
    bmesh.ops.translate(bm, vec=-Vector(pivot), verts=bm.verts)
    for o in objs: bpy.data.objects.remove(o, do_unlink=True)
    me = bpy.data.meshes.new(name); bm.to_mesh(me); bm.free()
    for m in mats: me.materials.append(m)
    ob = bpy.data.objects.new(name, me); ob.location = pivot
    _p9coll(D9).objects.link(ob)
    box_uv(ob)
    return ob

def wing_plate(cat, pts, sx, z, mat):
    bm = bmesh.new()
    vs = [bm.verts.new((sx * x, y, z)) for x, y in pts]
    bm.faces.new(vs if sx > 0 else list(reversed(vs)))
    mk_obj("wing", bm, mat, cat)

def build_drone():
    flat_mat("M_DroneCore", (0.62, 0.9, 1.0), rough=0.3, emit=(0.55, 0.88, 1.0), strength=6.0)
    T = TMP9
    _p9coll(T); c = _p9coll(D9)
    for o in list(c.objects): bpy.data.objects.remove(o, do_unlink=True)
    def body():
        # the moth's cage, shrunk: two caps, struts round the core
        cyl(T, "M_Steel", (0, 0, 0.075), (0, 0, 0.1), 0.075, 12, "capt")
        cyl(T, "M_Steel", (0, 0, -0.1), (0, 0, -0.075), 0.075, 12, "capb")
        for k in range(6):
            a = k / 6 * 6.283
            member(T, "M_Steel", (0.064 * math.cos(a), 0.064 * math.sin(a), -0.08), (0.064 * math.cos(a), 0.064 * math.sin(a), 0.08), 0.011, 0.011)
        cyl(T, "M_PalePipe", (0, 0, -0.012), (0, 0, 0.012), 0.08, 14, "band")          # pale paint band
        cyl(T, "M_Steel", (0, 0.06, 0.0), (0, 0.125, 0.0), 0.03, 10, "sensor")        # short sensor barrel (the moth's snout)
        cyl(T, "M_Rust", (0, 0.118, 0.0), (0, 0.13, 0.0), 0.036, 10, "sensor_rim")
        member(T, "M_Steel", (0, -0.02, 0.1), (0, -0.07, 0.25), 0.007, 0.007, "antenna")
        rockblob(T, (0, -0.07, 0.255), (0.013, 0.013, 0.013), amp=0, seed=0, sub=1, mat="M_Hazard", name="antenna_tip")
        member(T, "M_Corrugated", (0, -0.07, 0.0), (0, -0.2, 0.045), 0.005, 0.07, "fin")  # tail fin
        for s in (-1, 1):                                                              # side thruster pods
            cyl(T, "M_Rust", (0.098 * s, 0.0, -0.075), (0.098 * s, 0.0, -0.005), 0.024, 8, "pod")
            cyl(T, "M_Steel", (0.098 * s, 0.0, -0.095), (0.098 * s, 0.0, -0.075), 0.016, 8, "nozzle", r2=0.024)
            member(T, "M_Steel", (0.06 * s, 0.0, -0.04), (0.086 * s, 0.0, -0.04), 0.012, 0.012, "pod_arm")
        boxmm(T, "M_Hazard", -0.04, 0.04, -0.03, 0.03, -0.106, -0.1, "belly", 0.0)
        member(T, "M_Steel", (0, -0.06, 0.09), (0, -0.06, 0.13), 0.02, 0.012, "hook")    # the moth's hang hook, cut short
    piece("DBody", body)
    def core():
        rockblob(T, (0, 0, 0), (0.045, 0.045, 0.055), amp=0, seed=0, sub=2, mat="M_DroneCore", name="core")
        cyl(T, "M_DroneCore", (0, 0.125, 0.0), (0, 0.134, 0.0), 0.022, 10, "lens")
    piece("DCore", core)
    def ring():
        n = 18; r = 0.155
        for k in range(n):
            a0 = k / n * 6.283; a1 = (k + 1) / n * 6.283
            member(T, "M_Steel", (r * math.cos(a0), r * math.sin(a0), 0.0), (r * math.cos(a1), r * math.sin(a1), 0.0), 0.024, 0.01, "ring")
        for k in range(3):        # three emitter nubs
            a = k / 3 * 6.283 + 0.5
            rockblob(T, (r * math.cos(a), r * math.sin(a), 0.0), (0.014, 0.014, 0.014), amp=0, seed=0, sub=1, mat="M_DroneCore", name="nub")
    piece("DRing", ring)
    for side, sx in (("L", -1), ("R", 1)):
        def w(sx=sx):
            wing_plate(T, [(0.075, 0.03), (0.22, 0.1), (0.33, 0.08), (0.34, 0.02), (0.2, -0.01), (0.075, 0.0)], sx, 0.05, "M_RustSheet")
            wing_plate(T, [(0.075, -0.015), (0.2, -0.04), (0.25, -0.1), (0.17, -0.105), (0.075, -0.05)], sx, 0.048, "M_RustSheet")
            member(T, "M_Steel", (sx * 0.075, 0.015, 0.052), (sx * 0.33, 0.07, 0.054), 0.012, 0.012, "spar")
            member(T, "M_Steel", (sx * 0.075, -0.03, 0.05), (sx * 0.24, -0.09, 0.052), 0.009, 0.009, "spar2")
            boxmm(T, "M_Steel", sx * 0.065 - 0.012, sx * 0.065 + 0.012, -0.02, 0.02, 0.04, 0.062, "hinge", 0.0)
        piece(f"DWing_{side}", w, (sx * 0.075, 0, 0.05))
    print("drone parts:", [(o.name, len(o.data.vertices)) for o in bpy.data.collections[D9].objects])

def export_drone():
    sc = bpy.context.scene
    names = [o.name for o in bpy.data.collections[D9].objects]
    for o in sc.objects:
        o.select_set(o.name in names)
    bpy.ops.export_scene.gltf(filepath=os.path.join(PROJ, "assets", "props", "drone.glb"), export_format='GLB',
                              use_selection=True, use_active_scene=True, export_apply=True, export_yup=True)
    print("exported drone.glb from", sc.name, names)
