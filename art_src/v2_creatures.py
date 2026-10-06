
exec(open(r"C:\Users\Pigeon\Documents\UnderworksCavern\art_src\gen_lib.py").read())
sc=bpy.data.scenes["Scene"]
def ccoll(name):
    c=bpy.data.collections.get(name)
    if not c:
        c=bpy.data.collections.new(name); sc.collection.children.link(c)
    return c
def part(name, coll_name, build, pivot=(0,0,0), parent=None, smooth=False):
    """build() creates pieces in TMP; join them into one object `name` with origin at pivot."""
    old=bpy.data.objects.get(name)
    if old: bpy.data.objects.remove(old,do_unlink=True)
    tmp=ccoll("TMP")
    for o in list(tmp.objects): bpy.data.objects.remove(o,do_unlink=True)
    build()
    objs=list(tmp.objects)
    bpy.ops.object.select_all(action='DESELECT')
    for o in objs: o.select_set(True)
    bpy.context.view_layer.objects.active=objs[0]
    bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
    if len(objs)>1: bpy.ops.object.join()
    ob=bpy.context.view_layer.objects.active; ob.name=name; ob.data.name=name
    sc.cursor.location=pivot
    bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
    tmp.objects.unlink(ob); ccoll(coll_name).objects.link(ob)
    if smooth:
        for p in ob.data.polygons: p.use_smooth=True
    box_uv_local(ob)
    if parent:
        mw=ob.matrix_world.copy(); ob.parent=bpy.data.objects[parent]; ob.matrix_world=mw
    sc.cursor.location=(0,0,0)
    return ob
def box_uv_local(ob, t=0.6):
    me=ob.data; bm=bmesh.new(); bm.from_mesh(me); uv=bm.loops.layers.uv.verify()
    for f in bm.faces:
        n=f.normal; ax=max(range(3),key=lambda i:abs(n[i]))
        for l in f.loops:
            c=l.vert.co
            u,v=((c.y,c.z) if ax==0 else (c.x,c.z) if ax==1 else (c.x,c.y))
            l[uv].uv=(u/t,v/t)
    bm.to_mesh(me); bm.free()
T="TMP"
# ======================= SCUTTLER =======================
def sc_body():
    cyl(T,"M_Rust",(0,-0.38,0.46),(0,0.32,0.46),0.24,12,"drum")
    for y in (-0.36,-0.1,0.18,0.3): cyl(T,"M_Steel",(0,y-0.02,0.46),(0,y+0.02,0.46),0.255,12,"band")
    rockblob(T,(0,-0.02,0.66),(0.27,0.42,0.12),amp=0.0,seed=1,sub=2,mat="M_Corrugated",name="shell")
    boxmm(T,"M_Steel",-0.15,0.15,0.3,0.56,0.33,0.58,"head",0.03)
    cyl(T,"M_Steel",(0,0.55,0.47),(0,0.62,0.47),0.1,12,"eyering")
    member(T,"M_Steel",(0.08,0.45,0.58),(0.2,0.1,0.98),0.015,0.015); member(T,"M_Steel",(-0.08,0.45,0.58),(-0.22,0.12,0.92),0.015,0.015)
    cyl(T,"M_Steel",(0.12,-0.35,0.6),(0.14,-0.5,0.8),0.035,6,"exhaust")
    boxmm(T,"M_Hazard",-0.12,0.12,-0.2,0.2,0.2,0.25,"belly",0.01)
    for i in range(6):
        a=i/6*6.283; member(T,"M_Cable",(0.1*math.cos(a),-0.4,0.42+0.1*math.sin(a)),(0.15*math.cos(a),-0.62,0.3+0.12*math.sin(a)),0.012,0.012)
part("Body","CR_Scuttler",sc_body,(0,0,0.45))
part("Eye","CR_Scuttler",lambda: cyl(T,"M_Eye",(0,0.6,0.47),(0,0.635,0.47),0.075,12,"lens"),(0,0.62,0.47))
HIPS=[(0.2,0.24),(0.22,0.0),(0.2,-0.24)]
for side,sx in (("L",-1),("R",1)):
    for i,(hx,hy) in enumerate(HIPS):
        hip=Vector((sx*hx,hy,0.42)); spread=(0.25,0.0,-0.25)[i]
        knee=Vector((sx*0.48,hy+spread*0.6,0.68)); foot=Vector((sx*0.66,hy+spread*1.0,0.0))
        def b(hip=hip,knee=knee,foot=foot):
            member(T,"M_Steel",hip,knee,0.05,0.06)
            cyl(T,"M_Rust",hip+(knee-hip)*0.3,hip+(knee-hip)*0.7,0.045,6,"piston")
            rockblob(T,knee,(0.055,0.055,0.055),amp=0,seed=0,sub=1,mat="M_Rust",name="kj")
            member(T,"M_Steel",knee,foot+Vector((0,0,0.05)),0.035,0.04)
            cyl(T,"M_Rubber",foot,foot+Vector((0,0,0.06)),0.05,6,"pad")
        part(f"Leg_{side}{i}","CR_Scuttler",b,tuple(hip))
# ======================= MOTH DRONE =======================
def m_body():
    cyl(T,"M_Steel",(0,0,0.13),(0,0,0.17),0.12,10,"capt"); cyl(T,"M_Steel",(0,0,-0.17),(0,0,-0.13),0.12,10,"capb")
    for k in range(5):
        a=k/5*6.283; member(T,"M_Steel",(0.1*math.cos(a),0.1*math.sin(a),-0.14),(0.1*math.cos(a),0.1*math.sin(a),0.14),0.018,0.018)
    cyl(T,"M_Steel",(0,0,0.17),(0,0,0.3),0.025,6,"hook")
    member(T,"M_Steel",(0,-0.1,0),(0,-0.5,0.03),0.03,0.03)
    member(T,"M_Corrugated",(0,-0.38,0.0),(0,-0.55,0.1),0.012,0.14)
    cyl(T,"M_Rust",(0,0.1,0.0),(0,0.22,0.0),0.05,8,"snout")
    for s in (-1,1): member(T,"M_Steel",(0.04*s,0.2,0.04),(0.16*s,0.42,0.16),0.01,0.01)
part("MBody","CR_Moth",m_body,(0,0,0))
part("Core","CR_Moth",lambda: rockblob(T,(0,0,0),(0.075,0.075,0.1),amp=0,seed=0,sub=2,mat="M_Eye",name="core"),(0,0,0))
for side,sx in (("L",-1),("R",1)):
    def w(sx=sx):
        bm=bmesh.new()
        pts=[(0.11,0.08),(0.55,0.2),(0.62,-0.05),(0.35,-0.2),(0.11,-0.08)]
        vs=[bm.verts.new((sx*x,y,0.06)) for x,y in pts]; bm.faces.new(vs if sx>0 else list(reversed(vs)))
        mk_obj("wing",bm,"M_Corrugated",T)
        member(T,"M_Steel",(sx*0.1,0.0,0.06),(sx*0.6,0.12,0.07),0.02,0.02)
        member(T,"M_Steel",(sx*0.3,0.0,0.06),(sx*0.5,-0.15,0.07),0.015,0.015)
    part(f"Wing_{side}","CR_Moth",w,(sx*0.1,0,0.06))
# ======================= WATCHER =======================
def wt_base():
    boxmm(T,"M_Rust",-0.3,0.3,-0.3,0.3,0,0.06,"plate",0.02)
    for x in (-0.22,0.22):
        for y in (-0.22,0.22): cyl(T,"M_Steel",(x,y,0.06),(x,y,0.1),0.03,6,"bolt")
    cyl(T,"M_Steel",(0,0,0.06),(0,0,0.2),0.12,10,"turret")
part("Base","CR_Watcher",wt_base,(0,0,0))
def wt_neck():
    cyl(T,"M_Steel",(0,0,0.2),(0,0,0.55),0.06,8,"n1")
    rockblob(T,(0,0,0.58),(0.08,0.08,0.08),amp=0,seed=0,sub=1,mat="M_Rust",name="j1")
    cyl(T,"M_Steel",(0,0,0.6),(0.0,0.05,0.92),0.05,8,"n2")
    cyl(T,"M_Rust",(0,0,0.3),(0,0,0.45),0.08,8,"collar")
    for s in (-1,1): member(T,"M_Cable",(0.07*s,0,0.22),(0.06*s,0.06,0.9),0.015,0.015)
part("Neck","CR_Watcher",wt_neck,(0,0,0.2),parent="Base")
def wt_head():
    boxmm(T,"M_Rust",-0.16,0.16,-0.22,0.24,0.86,1.12,"cam",0.03)
    boxmm(T,"M_Steel",-0.19,0.19,-0.05,0.34,1.12,1.15,"hood",0.0)
    cyl(T,"M_Steel",(0,0.24,0.99),(0,0.34,0.99),0.09,12,"barrel")
    boxmm(T,"M_Hazard",0.16,0.17,-0.15,0.15,0.9,1.08,"stripe",0.0)
    member(T,"M_Steel",(-0.1,-0.15,1.12),(-0.15,-0.3,1.45),0.012,0.012)
    cyl(T,"M_Steel",(0.17,0,0.95),(0.27,0,0.95),0.05,8,"ear")
part("Head","CR_Watcher",wt_head,(0,0.0,0.95),parent="Neck")
part("Lens","CR_Watcher",lambda: cyl(T,"M_Eye",(0,0.34,0.99),(0,0.355,0.99),0.07,12,"lens"),(0,0.35,0.99),parent="Head")
print([o.name for c in ("CR_Scuttler","CR_Moth","CR_Watcher") for o in bpy.data.collections[c].objects])
