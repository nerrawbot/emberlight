# v12: floating-part check for the mesa works (v5_surface.py), after v10_peak.py's floaters().
# Builds the structures WITHOUT merging, then lists every part not connected (by contact, through other parts) to the
# ground: below the mesa surface (ground_h + 0.12), deep under grade (z < G - 6: cliff faces, the cove), touching a
# rock part, the lift headframe (Lift3-col), or inside the collapse plug's box.
# Run: exec(open(r"D:\Emberlight\art_src\v12_floaters.py").read()); fl = check_works()
#      ... fix v5_surface.py ...; then build_all(); export_all() as usual (with Surface5 active).
exec(open(r"D:\Emberlight\art_src\v5_surface.py").read())
PROJ = r"D:\Emberlight"
TEX = os.path.join(PROJ, "art_src", "tex")

ROCK_NAMES = ("rock", "boulder", "stack", "outcrop", "spire", "crown", "break", "spur", "slab")

def _parts(colls, eps):
    parts = []
    for c in colls:
        for o in bpy.data.collections[c].objects:
            if o.type != 'MESH' or not o.data.vertices: continue
            rot = o.rotation_quaternion if o.rotation_mode == 'QUATERNION' else o.rotation_euler.to_quaternion()
            mb = Matrix.LocRotScale(o.location, rot, o.scale)
            me = o.data
            lo = Vector([min(v.co[i] for v in me.vertices) for i in range(3)]) - Vector((eps,) * 3)
            hi = Vector([max(v.co[i] for v in me.vertices) for i in range(3)]) + Vector((eps,) * 3)
            pts = [mb @ v.co for v in me.vertices] + [mb @ ((me.vertices[e.vertices[0]].co + me.vertices[e.vertices[1]].co) / 2) for e in me.edges]
            if len(pts) > 600: pts = pts[::max(1, len(pts) // 600)]
            wmn = Vector([min(p[i] for p in pts) for i in range(3)]); wmx = Vector([max(p[i] for p in pts) for i in range(3)])
            parts.append(dict(o=o, inv=mb.inverted(), lo=lo, hi=hi, pts=pts, mn=wmn, mx=wmx, rock=o.name.lower().startswith(ROCK_NAMES)))
    return parts

def surface_floaters(colls, eps=0.08):
    parts = _parts(colls, eps)
    lift = bpy.data.objects.get("Lift3-col")
    lift_bb = None
    if lift:
        ws = [lift.matrix_world @ Vector(c) for c in lift.bound_box]
        lift_bb = (Vector([min(w[i] for w in ws) for i in range(3)]), Vector([max(w[i] for w in ws) for i in range(3)]))
    def inside(q, p):
        l = p["inv"] @ q
        return all(p["lo"][i] <= l[i] <= p["hi"][i] for i in range(3))
    def grounded(p):
        if p["rock"]: return True
        for q in p["pts"]:
            if q.z < G - 6.0: return True
            th = math.atan2(q.y - CENTER.y, q.x - CENTER.x)
            if math.hypot(q.x - CENTER.x, q.y - CENTER.y) < rim_radius(th) - 0.3 and q.z <= ground_h(q.x, q.y) + 0.12: return True
            if lift_bb and all(lift_bb[0][i] - 0.05 <= q[i] <= lift_bb[1][i] + 0.05 for i in range(3)): return True
        return False
    cell = 6.0; grid = {}
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
    out = []
    for k in range(len(parts)):
        if k in seen: continue
        p = parts[k]
        gap = min(q.z - ground_h(q.x, q.y) for q in p["pts"])
        out.append((p["o"].name, tuple(round(v, 1) for v in (p["mn"] + p["mx"]) / 2), round(gap, 2),
                    tuple(round(v, 1) for v in (p["mx"] - p["mn"]))))
    return out

def check_works():
    """Rebuild the works/detail parts (not merged; plants skipped) and list the floating ones."""
    win = bpy.context.window
    if win: win.scene = S5
    C, D, R = "S5_WorksC", "S5_DetailC", "S5_RampsC"
    for c in (C, D, R): s5coll(c)
    mats5()
    stairwell(C, D, R)
    lift_collar(C, D)
    works(C, D, R)
    cove(C, D, R)
    scatter(C, D)
    ruins(C, D)
    fl = surface_floaters([C, D])
    print("floating parts:", len(fl))
    for f in sorted(fl, key=lambda f: f[1]): print("  ", f)
    return fl