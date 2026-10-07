
# v5: the player's weapon - a heavy steel shaft (improvised from pipe fittings).
# Built in its own Blender scene "Props5", exported to assets/props/shaft.glb.
# Local frame: the shaft runs along +Z (Godot +Y), origin = where the hand grips it.
#   butt cap z -0.22 .. leather-wrapped grip .. hex collar z 0.11 .. bare shaft .. bolted coupling head .. tip z 0.86
# Run: exec(open(r"...\art_src\v5_weapon.py").read()); build_shaft(); export_shaft()
exec(open(r"D:\Emberlight\art_src\gen_lib.py").read())

if "Props5" not in bpy.data.scenes:
    bpy.data.scenes.new("Props5")
P5 = bpy.data.scenes["Props5"]

def p5coll(name):
    c = bpy.data.collections.get(name)
    if c is None:
        c = bpy.data.collections.new(name); P5.collection.children.link(c)
    elif c.name not in P5.collection.children:
        P5.collection.children.link(c)
    for o in list(c.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    return c

UV_TILE = 0.45      # metres of shaft per texture repeat (the texture is close to the camera)

def _mats():
    steel = pbr_mat("M_ShaftSteel", "shaft_albedo.jpg", "shaft_orm.jpg", "shaft_normal.jpg", 0.8)
    wrap = flat_mat("M_ShaftWrap", (0.035, 0.03, 0.04), rough=0.85)
    dark = flat_mat("M_ShaftDark", (0.05, 0.055, 0.07), rough=0.45, metal=0.9)
    return steel, wrap, dark

def _sharpen(bm, deg=35.0):
    lim = math.radians(deg)
    for f in bm.faces:
        f.smooth = True
    for e in bm.edges:
        if len(e.link_faces) == 2 and e.calc_face_angle(0.0) > lim:
            e.smooth = False

def _cyl_uv(bm):
    uv = bm.loops.layers.uv.verify()
    for f in bm.faces:
        cap = abs(f.normal.z) > 0.7
        # keep the seam from wrapping: unwrap each face relative to its first corner's angle
        a0 = math.atan2(f.loops[0].vert.co.y, f.loops[0].vert.co.x)
        for l in f.loops:
            c = l.vert.co
            if cap:
                l[uv].uv = (c.x / UV_TILE * 4, c.y / UV_TILE * 4)
                continue
            a = math.atan2(c.y, c.x)
            while a - a0 > math.pi: a -= 2 * math.pi
            while a - a0 < -math.pi: a += 2 * math.pi
            r = max(0.005, Vector((c.x, c.y)).length)
            l[uv].uv = (a * r / UV_TILE, c.z / UV_TILE)

def lathe(name, prof, seg, mat, C, rot=0.0):
    """Revolve a (radius, z) profile around Z. prof runs bottom -> top; r=0 ends are closed with a pole."""
    bm = bmesh.new(); rings = []
    for (r, z) in prof:
        if r <= 1e-5:
            rings.append([bm.verts.new((0, 0, z))]); continue
        rings.append([bm.verts.new((r * math.cos(rot + 2 * math.pi * k / seg), r * math.sin(rot + 2 * math.pi * k / seg), z)) for k in range(seg)])
    for i in range(len(rings) - 1):
        a, b = rings[i], rings[i + 1]
        if len(a) == 1 and len(b) == 1: continue
        for k in range(seg):
            if len(a) == 1:
                bm.faces.new((a[0], b[k], b[(k + 1) % seg]))
            elif len(b) == 1:
                bm.faces.new((a[k], a[(k + 1) % seg], b[0]))
            else:
                bm.faces.new((a[k], a[(k + 1) % seg], b[(k + 1) % seg], b[k]))
    if len(rings[0]) > 1: bm.faces.new(list(reversed(rings[0])))
    if len(rings[-1]) > 1: bm.faces.new(rings[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    _sharpen(bm); _cyl_uv(bm)
    me = bpy.data.meshes.new(name); bm.to_mesh(me); bm.free()
    ob = bpy.data.objects.new(name, me); me.materials.append(mat)
    bpy.data.collections[C].objects.link(ob)
    return ob

def helix_wrap(name, r, z0, z1, pitch, width, thick, mat, C, steps_per_turn=20):
    """Leather strap wound round the grip: a thin flat ribbon following a helix (slightly overlapping turns)."""
    bm = bmesh.new()
    turns = (z1 - z0) / pitch; n = int(turns * steps_per_turn)
    prev = None
    for i in range(n + 1):
        t = i / n; a = t * turns * 2 * math.pi; z = z0 + (z1 - z0) * t
        wob = 1.0 + 0.04 * math.sin(a * 3.7)          # hand-wound: not perfectly even
        rr = [r * wob, (r + thick) * wob]
        ring = []
        for (dz, ri) in ((-width / 2, rr[0]), (-width / 2, rr[1]), (width / 2, rr[1]), (width / 2, rr[0])):
            ring.append(bm.verts.new((ri * math.cos(a), ri * math.sin(a), z + dz)))
        if prev:
            for k in range(4):
                bm.faces.new((prev[k], prev[(k + 1) % 4], ring[(k + 1) % 4], ring[k]))
        else:
            bm.faces.new(list(reversed(ring)))
        prev = ring
    bm.faces.new(prev)
    # the loose tail end of the strap, hanging off the bottom
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    _sharpen(bm, 50.0); _cyl_uv(bm)
    me = bpy.data.meshes.new(name); bm.to_mesh(me); bm.free()
    ob = bpy.data.objects.new(name, me); me.materials.append(mat)
    bpy.data.collections[C].objects.link(ob)
    return ob

def strap_tail(name, mat, C):
    bm = bmesh.new()
    pts = [(0.0205, 0.0, -0.165), (0.0245, -0.003, -0.185), (0.027, -0.007, -0.21), (0.0265, -0.012, -0.236)]
    w = 0.0085; prev = None
    for (x, y, z) in pts:
        a = bm.verts.new((x, y - w, z)); b = bm.verts.new((x, y + w, z))
        a2 = bm.verts.new((x + 0.0025, y - w, z)); b2 = bm.verts.new((x + 0.0025, y + w, z))
        ring = [a, b, b2, a2]
        if prev:
            for k in range(4):
                bm.faces.new((prev[k], prev[(k + 1) % 4], ring[(k + 1) % 4], ring[k]))
        prev = ring
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    _sharpen(bm, 50.0); _cyl_uv(bm)
    me = bpy.data.meshes.new(name); bm.to_mesh(me); bm.free()
    ob = bpy.data.objects.new(name, me); me.materials.append(mat)
    bpy.data.collections[C].objects.link(ob)
    return ob

def hexbolt(name, mat, C, pos, normal, r=0.0058, h=0.006):
    ob = lathe(name, [(0, -0.001), (r * 1.25, -0.001), (r * 1.25, 0.0008), (r, 0.0012), (r, h), (r * 0.8, h + 0.0012), (0, h + 0.0012)], 6, mat, C)
    ob.location = pos
    ob.rotation_mode = 'QUATERNION'; ob.rotation_quaternion = Vector(normal).to_track_quat('Z', 'Y')
    return ob

def build_shaft():
    steel, wrap, dark = _mats()
    C = "P5_Shaft"; p5coll(C)
    S = 16
    # butt cap + ferrule
    lathe("butt", [(0, -0.222), (0.012, -0.221), (0.019, -0.217), (0.0225, -0.21), (0.0235, -0.2), (0.0235, -0.178), (0.0205, -0.175), (0.0185, -0.175)], S, steel, C)
    # grip core (under the strap)
    lathe("grip", [(0.0185, -0.176), (0.0185, 0.108)], S, dark, C)
    helix_wrap("wrap", 0.0186, -0.168, 0.098, 0.0175, 0.019, 0.0028, wrap, C)
    strap_tail("wrap_tail", wrap, C)
    # top ferrule, washer, hex collar
    lathe("ferrule", [(0.0182, 0.098), (0.0215, 0.1), (0.0215, 0.112), (0.023, 0.114), (0.023, 0.118)], S, steel, C)
    lathe("collar", [(0.0, 0.118), (0.029, 0.118), (0.029, 0.121), (0.0275, 0.122), (0.0275, 0.142), (0.024, 0.146), (0.0, 0.146)], 6, steel, C, rot=math.pi / 6)
    # main shaft with two raised weld bands
    prof = [(0.0165, 0.146)]
    for zc in (0.33, 0.47):
        prof += [(0.0165, zc - 0.006), (0.0178, zc - 0.003), (0.0178, zc + 0.003), (0.0165, zc + 0.006)]
    prof += [(0.0165, 0.615)]
    lathe("shaft", prof, S, steel, C)
    # coupling head: flared neck, heavy sleeve with grooves, hex nut, chamfered tip
    lathe("head", [(0.0165, 0.612), (0.0195, 0.628), (0.0255, 0.642), (0.0262, 0.646), (0.0262, 0.71), (0.0245, 0.713), (0.0245, 0.719),
                   (0.0262, 0.722), (0.0262, 0.795), (0.0, 0.795)], S, steel, C)
    lathe("nut", [(0.0, 0.795), (0.0295, 0.795), (0.0295, 0.828), (0.026, 0.833), (0.0, 0.833)], 6, steel, C)
    lathe("tip", [(0.0, 0.832), (0.023, 0.832), (0.021, 0.85), (0.017, 0.858), (0.0, 0.86)], S, dark, C)
    # bolts through the sleeve (two rings of three, staggered)
    for k in range(3):
        for (z, off) in ((0.675, 0.0), (0.765, math.pi / 3)):
            a = 2 * math.pi * k / 3 + off
            n = Vector((math.cos(a), math.sin(a), 0.0))
            hexbolt("bolt", steel, C, n * 0.0255 + Vector((0, 0, z)), n)
    # merge in bmesh (join_into() would re-project the UVs as boxes, and these objects aren't in the context view layer)
    objs = [o for o in bpy.data.collections[C].objects if o.type == 'MESH']
    mats = []; bm = bmesh.new()
    for o in objs:
        nv, nf = len(bm.verts), len(bm.faces)
        bm.from_mesh(o.data)
        bm.verts.ensure_lookup_table(); bm.faces.ensure_lookup_table()
        # (matrix_world isn't evaluated for objects outside the context view layer, so build it here)
        rot = o.rotation_quaternion if o.rotation_mode == 'QUATERNION' else o.rotation_euler.to_quaternion()
        bmesh.ops.transform(bm, matrix=Matrix.LocRotScale(o.location, rot, o.scale), verts=bm.verts[nv:])
        remap = []
        for m in o.data.materials:
            if m not in mats: mats.append(m)
            remap.append(mats.index(m))
        for f in bm.faces[nf:]:
            f.material_index = remap[f.material_index]
    old = bpy.data.objects.get("Shaft")
    if old: bpy.data.objects.remove(old, do_unlink=True)
    me = bpy.data.meshes.new("Shaft"); bm.to_mesh(me); bm.free()
    for m in mats: me.materials.append(m)
    for o in objs: bpy.data.objects.remove(o, do_unlink=True)
    ob = bpy.data.objects.new("Shaft", me); bpy.data.collections[C].objects.link(ob)
    print("Shaft", len(ob.data.vertices), "verts", [m.name for m in ob.data.materials])
    return ob

def export_shaft():
    # same trick as v4 _export: the exporter works on bpy.context.scene, so link into it for the export only
    sc = bpy.context.scene
    tmp = bpy.data.collections.new("_EXPORT_TMP"); sc.collection.children.link(tmp)
    ob = P5.objects["Shaft"]
    tmp.objects.link(ob)
    bpy.context.view_layer.update()
    for o in sc.objects:
        o.select_set(o.name == "Shaft")
    bpy.ops.export_scene.gltf(filepath=os.path.join(PROJ, "assets", "props", "shaft.glb"), export_format='GLB', use_selection=True,
                              use_active_scene=True, export_apply=True, export_yup=True)
    sc.collection.children.unlink(tmp); bpy.data.collections.remove(tmp)
    print("exported shaft.glb")
