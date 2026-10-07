
import bpy, bmesh, math, random, os
from mathutils import Vector, Matrix, Quaternion, noise
PROJ=r"D:\Emberlight"
TEX=os.path.join(PROJ,"art_src","tex")

def coll(name):
    if name in bpy.data.collections: return bpy.data.collections[name]
    c=bpy.data.collections.new(name); bpy.context.scene.collection.children.link(c); return c

def M(n): return bpy.data.materials[n]

def mk_obj(name, bm, mat, cat):
    me=bpy.data.meshes.new(name); bm.to_mesh(me); bm.free()
    ob=bpy.data.objects.new(name, me)
    if mat: me.materials.append(M(mat))
    coll(cat).objects.link(ob); return ob

def _bevel(bm, amt):
    if amt<=0: return
    try:
        bmesh.ops.bevel(bm, geom=list(bm.edges)+list(bm.verts), offset=amt, offset_type='OFFSET', segments=1, profile=0.5, affect='EDGES', clamp_overlap=True)
    except Exception as e:
        print("bevel fail",e)

def boxmm(cat, mat, x0,x1,y0,y1,z0,z1, name="box", bevel=0.03):
    bm=bmesh.new(); bmesh.ops.create_cube(bm,size=1)
    sx,sy,sz=abs(x1-x0),abs(y1-y0),abs(z1-z0)
    bmesh.ops.scale(bm,vec=(sx,sy,sz),verts=bm.verts)
    _bevel(bm, min(bevel, 0.3*min(sx,sy,sz)))
    ob=mk_obj(name,bm,mat,cat); ob.location=((x0+x1)/2,(y0+y1)/2,(z0+z1)/2); return ob

def track(d):
    d=Vector(d).normalized()
    up='Z' if abs(d.z)<0.98 else 'Y'
    return d.to_track_quat('X',up)

def member(cat, mat, p0, p1, sy, sz, name="member", bevel=0.0):
    p0=Vector(p0); p1=Vector(p1); L=(p1-p0).length
    bm=bmesh.new(); bmesh.ops.create_cube(bm,size=1)
    bmesh.ops.scale(bm,vec=(L,sy,sz),verts=bm.verts); _bevel(bm,bevel)
    ob=mk_obj(name,bm,mat,cat); ob.location=(p0+p1)/2
    ob.rotation_mode='QUATERNION'; ob.rotation_quaternion=track(p1-p0); return ob

def ibeam(cat, p0, p1, h=0.45, w=0.3, t=0.045, mat="M_Steel", name="ibeam"):
    p0=Vector(p0); p1=Vector(p1); L=(p1-p0).length
    bm=bmesh.new()
    for cy,cz,sy,sz in [(0,h/2-t/2,w,t),(0,-h/2+t/2,w,t),(0,0,t*1.3,h-2*t)]:
        r=bmesh.ops.create_cube(bm,size=1); vs=r['verts']
        bmesh.ops.scale(bm,vec=(L,sy,sz),verts=vs); bmesh.ops.translate(bm,vec=(0,cy,cz),verts=vs)
    ob=mk_obj(name,bm,mat,cat); ob.location=(p0+p1)/2
    ob.rotation_mode='QUATERNION'; ob.rotation_quaternion=track(p1-p0); return ob

def cyl(cat, mat, p0, p1, r, seg=10, name="cyl", r2=None):
    p0=Vector(p0); p1=Vector(p1); L=(p1-p0).length
    bm=bmesh.new()
    bmesh.ops.create_cone(bm,cap_ends=True,cap_tris=False,segments=seg,radius1=r,radius2=(r if r2 is None else r2),depth=L)
    ob=mk_obj(name,bm,mat,cat); ob.location=(p0+p1)/2
    d=(p1-p0).normalized(); up='Y' if abs(d.y)<0.98 else 'X'
    ob.rotation_mode='QUATERNION'; ob.rotation_quaternion=d.to_track_quat('Z',up); return ob

def truss(cat, p0, p1, height=1.2, mat="M_Steel", panel=1.6, sz=0.14):
    p0=Vector(p0); p1=Vector(p1); up=Vector((0,0,height))
    member(cat,mat,p0,p1,sz,sz*1.4); member(cat,mat,p0+up,p1+up,sz,sz*1.4)
    L=(p1-p0).length; n=max(1,int(L/panel))
    for i in range(n+1):
        a=p0.lerp(p1,i/n); member(cat,mat,a,a+up,sz*0.7,sz*0.7)
        if i<n:
            b=p0.lerp(p1,(i+1)/n)
            if i%2==0: member(cat,mat,a,b+up,sz*0.6,sz*0.6)
            else: member(cat,mat,a+up,b,sz*0.6,sz*0.6)

def railing(cat, p0, p1, h=1.1, mat="M_Steel", spacing=1.5, broken=0.0, seed=0):
    rnd=random.Random(seed)
    p0=Vector(p0); p1=Vector(p1); L=(p1-p0).length; n=max(1,int(round(L/spacing)))
    pts=[p0.lerp(p1,i/n) for i in range(n+1)]
    for i,a in enumerate(pts):
        if rnd.random()<broken*0.5: continue
        tilt=Vector((rnd.uniform(-1,1),rnd.uniform(-1,1),0))*0.08*(1 if rnd.random()<broken else 0)
        member(cat,mat,a,a+Vector((0,0,h))+tilt,0.07,0.07)
    for i in range(n):
        if rnd.random()<broken: 
            # sagging broken rail piece
            a=pts[i]+Vector((0,0,h)); b=pts[i+1]+Vector((0,0,h*0.35))
            member(cat,mat,a,b,0.05,0.05); continue
        member(cat,mat,pts[i]+Vector((0,0,h)),pts[i+1]+Vector((0,0,h)),0.06,0.06)
        member(cat,mat,pts[i]+Vector((0,0,h*0.5)),pts[i+1]+Vector((0,0,h*0.5)),0.04,0.04)

def stairs(cat, p0, p1, width=2.0, mat_tread="M_Grate", mat_str="M_Steel", rampcat="Ramps", step=0.22):
    p0=Vector(p0); p1=Vector(p1); d=p1-p0; rise=d.z; horiz=Vector((d.x,d.y,0)); run=horiz.length
    fwd=horiz.normalized(); side=Vector((-fwd.y,fwd.x,0))
    n=max(2,int(round(rise/step))); sh=rise/n; sd=run/n
    yaw=math.atan2(fwd.y,fwd.x)
    for i in range(n):
        c=p0+fwd*(sd*(i+0.5))+Vector((0,0,sh*(i+1)-0.03))
        ob=boxmm(cat,mat_tread,-sd*0.55,sd*0.55,-width/2,width/2,-0.03,0.03,"tread",0.0)
        ob.location=c; ob.rotation_euler=(0,0,yaw)
    for s in (-1,1):
        a=p0+side*(s*width/2)+Vector((0,0,-0.15)); b=p1+side*(s*width/2)+Vector((0,0,-0.15))
        member(cat,mat_str,a,b,0.08,0.35)
        railing(cat,a+Vector((0,0,0.15)),b+Vector((0,0,0.15)),h=1.0,mat=mat_str,spacing=1.8)
    # collision ramp (top surface through nosings)
    a=p0+Vector((0,0,0.0)); b=p1
    nrm=(b-a).cross(side).normalized()
    if nrm.z<0: nrm=-nrm
    ob=member(rampcat,None,a-nrm*0.06,b-nrm*0.06,width,0.12,"ramp")
    return ob

def displace(bm, amp, freq, seed=0, octaves=4, mode='normal'):
    off=Vector((seed*17.3,seed*-9.1,seed*5.7))
    bm.verts.ensure_lookup_table(); bm.normal_update()
    for v in bm.verts:
        p=v.co*freq+off
        n=noise.fractal(p,0.6,2.0,octaves,noise_basis='PERLIN_ORIGINAL')
        v.co+=v.normal*amp*n

def rockslab(cat, x0,x1,y0,y1,z0,z1, amp=0.8, freq=0.35, seed=1, spacing=1.3, mat="M_Rock", name="rock"):
    sx,sy,sz=abs(x1-x0),abs(y1-y0),abs(z1-z0)
    bm=bmesh.new(); bmesh.ops.create_cube(bm,size=1)
    bmesh.ops.scale(bm,vec=(sx,sy,sz),verts=bm.verts)
    bmesh.ops.translate(bm,vec=((x0+x1)/2,(y0+y1)/2,(z0+z1)/2),verts=bm.verts)
    # subdivide via grid edges by max dimension
    cuts=int(min(18,max(2,max(sx,sy,sz)/spacing)))
    bmesh.ops.subdivide_edges(bm,edges=bm.edges[:],cuts=cuts,use_grid_fill=True)
    bm.normal_update()
    # world-space displacement along vertex normal; also lateral jitter
    off=Vector((seed*13.1,seed*7.7,seed*-3.3))
    for v in bm.verts:
        p=v.co*freq+off
        nv=noise.fractal(p,0.55,2.0,5,noise_basis='PERLIN_ORIGINAL')
        v.co+=v.normal*amp*nv*1.6
    ob=mk_obj(name,bm,mat,cat); return ob

def rockblob(cat, c, s, amp=0.35, seed=1, sub=3, mat="M_Rock", name="boulder"):
    bm=bmesh.new(); bmesh.ops.create_icosphere(bm,subdivisions=sub,radius=1.0)
    bmesh.ops.scale(bm,vec=s,verts=bm.verts); bmesh.ops.translate(bm,vec=c,verts=bm.verts)
    bm.normal_update()
    off=Vector((seed*11.1,seed*3.7,seed*-6.3))
    for v in bm.verts:
        p=v.co*0.45+off
        v.co+=v.normal*amp*noise.fractal(p,0.6,2.0,4,noise_basis='PERLIN_ORIGINAL')*min(s)
    return mk_obj(name,bm,mat,cat)

# ---------- foliage ----------
def blade(bm, base, direction, length, width, droop, segs=6, twist=0.0):
    d=Vector(direction).normalized(); side=d.cross(Vector((0,0,1)))
    if side.length<1e-3: side=Vector((1,0,0))
    side.normalize()
    prev=None
    for i in range(segs+1):
        t=i/segs
        p=Vector(base)+d*(length*t)+Vector((0,0,-droop*t*t*length))
        w=width*(math.sin(math.pi*min(1,t*1.2+0.05))*0.9+0.1)*(1-t*0.7)
        a=bm.verts.new(p-side*w/2); b=bm.verts.new(p+side*w/2)
        if prev: bm.faces.new((prev[0],prev[1],b,a))
        prev=(a,b)

def fern(cat, c, scale=1.0, seed=0, n=9, mat="M_FoliageGlow", up=1.0, name="fern"):
    rnd=random.Random(seed); bm=bmesh.new()
    for i in range(n):
        ang=rnd.uniform(0,2*math.pi); el=rnd.uniform(0.35,1.0)*up
        d=Vector((math.cos(ang),math.sin(ang),el))
        blade(bm,c,d,scale*rnd.uniform(0.6,1.2),scale*rnd.uniform(0.12,0.22),rnd.uniform(0.4,1.1),segs=6)
    return mk_obj(name,bm,mat,cat)

def vine(cat, top, length, seed=0, mat="M_FoliageDark", leafmat="M_FoliageGlow", name="vine"):
    rnd=random.Random(seed); bm=bmesh.new(); bml=bmesh.new()
    segs=max(4,int(length/0.35)); pts=[]
    ph=rnd.uniform(0,6.28)
    for i in range(segs+1):
        t=i/segs
        pts.append(Vector(top)+Vector((math.sin(t*5+ph)*0.25*t, math.cos(t*4+ph)*0.2*t, -length*t)))
    for k in range(2):
        ax=Vector((1,0,0)) if k==0 else Vector((0,1,0))
        prev=None
        for i,p in enumerate(pts):
            w=0.05*(1-i/segs*0.6)
            a=bm.verts.new(p-ax*w); b=bm.verts.new(p+ax*w)
            if prev: bm.faces.new((prev[0],prev[1],b,a))
            prev=(a,b)
    for i,p in enumerate(pts[1:],1):
        if rnd.random()<0.55:
            ang=rnd.uniform(0,6.28)
            blade(bml,p,(math.cos(ang),math.sin(ang),rnd.uniform(-0.2,0.5)),rnd.uniform(0.18,0.4),rnd.uniform(0.08,0.14),0.5,segs=3)
    o1=mk_obj(name,bm,mat,cat); o2=mk_obj(name+"_lv",bml,leafmat,cat)
    return o1,o2


# ---------------- v2 helpers ----------------
def islands(ob):
    import bmesh
    bm=bmesh.new(); bm.from_mesh(ob.data); bm.verts.ensure_lookup_table(); bm.verts.index_update()
    seen=set(); out=[]
    for v in bm.verts:
        if v.index in seen: continue
        stack=[v]; isl=[]
        while stack:
            a=stack.pop()
            if a.index in seen: continue
            seen.add(a.index); isl.append(a)
            for e in a.link_edges:
                b=e.other_vert(a)
                if b.index not in seen: stack.append(b)
        out.append(isl)
    return bm,out

def remove_islands(ob, pred):
    import bmesh
    bm,isls=islands(ob); dead=[]; n=0
    for isl in isls:
        xs=[q.co.x for q in isl]; ys=[q.co.y for q in isl]; zs=[q.co.z for q in isl]
        mn=Vector((min(xs),min(ys),min(zs))); mx=Vector((max(xs),max(ys),max(zs)))
        if pred(mn,mx,(mn+mx)/2): dead+=isl; n+=1
    if dead: bmesh.ops.delete(bm,geom=dead,context='VERTS')
    bm.to_mesh(ob.data); bm.free(); ob.data.update(); return n

def join_into(target_name, coll_name, mat_tiles=None):
    """Join every mesh in coll_name into one object called target_name (box-projected UVs)."""
    import bmesh
    col=bpy.data.collections.get(coll_name)
    objs=[o for o in col.objects if o.type=='MESH']
    if not objs: return None
    bpy.ops.object.select_all(action='DESELECT')
    for o in objs: o.select_set(True)
    bpy.context.view_layer.objects.active=objs[0]
    bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
    if len(objs)>1: bpy.ops.object.join()
    ob=bpy.context.view_layer.objects.active
    old=bpy.data.objects.get(target_name)
    if old and old!=ob: bpy.data.objects.remove(old,do_unlink=True)
    ob.name=target_name; ob.data.name=target_name
    box_uv(ob)
    return ob

def box_uv(ob):
    import bmesh
    tiles={"M_Rock":3.2,"M_Concrete":2.4,"M_Steel":1.6,"M_Grate":1.8,"M_Rust":1.5,"M_Corrugated":2.0,"M_Hazard":1.0,
           "M_MesaCliff":9.0,"M_MesaGround":3.0,"M_Concrete2":2.1,"M_Concrete3":2.0,"M_RustSheet":2.0}
    me=ob.data; bm=bmesh.new(); bm.from_mesh(me); uv=bm.loops.layers.uv.verify()
    mats=[m.name if m else "" for m in me.materials]
    for f in bm.faces:
        t=tiles.get(mats[f.material_index] if f.material_index<len(mats) else "",2.0)
        n=f.normal; ax=max(range(3),key=lambda i:abs(n[i]))
        for l in f.loops:
            c=l.vert.co
            if ax==0: u,v=c.y*(1 if n.x>0 else -1),c.z
            elif ax==1: u,v=c.x*(-1 if n.y>0 else 1),c.z
            else: u,v=c.x,c.y*(1 if n.z>0 else -1)
            l[uv].uv=(u/t,v/t)
    bm.to_mesh(me); bm.free()

def carve_box(ob, lo, hi, pad=1.5):
    """Cut an axis-aligned box hole (world coords) into a mesh: bisect along the box planes near it, delete faces inside."""
    import bmesh
    bm=bmesh.new(); bm.from_mesh(ob.data); inv=ob.matrix_world.inverted()
    a=inv@Vector(lo); b=inv@Vector(hi)
    lo_l=Vector([min(a[i],b[i]) for i in range(3)]); hi_l=Vector([max(a[i],b[i]) for i in range(3)])
    def near(f):
        mn=[min(v.co[i] for v in f.verts) for i in range(3)]; mx=[max(v.co[i] for v in f.verts) for i in range(3)]
        return all(mx[i]>lo_l[i]-pad and mn[i]<hi_l[i]+pad for i in range(3))
    for axis in range(3):
        for val in (lo_l[axis],hi_l[axis]):
            faces=[f for f in bm.faces if near(f)]
            if not faces: continue
            edges=list({e for f in faces for e in f.edges}); verts=list({v for f in faces for v in f.verts})
            no=Vector((0,0,0)); no[axis]=1.0; co=Vector((0,0,0)); co[axis]=val
            bmesh.ops.bisect_plane(bm,geom=verts+edges+faces,plane_co=co,plane_no=no,dist=1e-4)
    dead=[f for f in bm.faces if all(lo_l[i]+1e-3<f.calc_center_median()[i]<hi_l[i]-1e-3 for i in range(3))]
    bmesh.ops.delete(bm,geom=dead,context='FACES')
    bm.to_mesh(ob.data); bm.free(); ob.data.update()
    return len(dead)

def cable_pts(p0,p1,sag,n=40):
    p0=Vector(p0);p1=Vector(p1)
    return [p0.lerp(p1,i/n)-Vector((0,0,sag*4*(i/n)*(1-i/n))) for i in range(n+1)]


def _img(name, cs):
    p=os.path.join(TEX,name); i=bpy.data.images.load(p, check_existing=True); i.colorspace_settings.name=cs; return i

def pbr_mat(name, alb, ormk, nrmk, normal_strength=1.0):
    if name in bpy.data.materials: return bpy.data.materials[name]
    m=bpy.data.materials.new(name); m.use_nodes=True; nt=m.node_tree; nt.nodes.clear()
    out=nt.nodes.new("ShaderNodeOutputMaterial"); bsdf=nt.nodes.new("ShaderNodeBsdfPrincipled")
    nt.links.new(bsdf.outputs[0],out.inputs[0])
    ta=nt.nodes.new("ShaderNodeTexImage"); ta.image=_img(alb,"sRGB")
    to=nt.nodes.new("ShaderNodeTexImage"); to.image=_img(ormk,"Non-Color")
    tn=nt.nodes.new("ShaderNodeTexImage"); tn.image=_img(nrmk,"Non-Color")
    sep=nt.nodes.new("ShaderNodeSeparateColor"); nm=nt.nodes.new("ShaderNodeNormalMap"); nm.inputs["Strength"].default_value=normal_strength
    nt.links.new(ta.outputs["Color"],bsdf.inputs["Base Color"]); nt.links.new(to.outputs["Color"],sep.inputs[0])
    nt.links.new(sep.outputs[1],bsdf.inputs["Roughness"]); nt.links.new(sep.outputs[2],bsdf.inputs["Metallic"])
    nt.links.new(tn.outputs["Color"],nm.inputs["Color"]); nt.links.new(nm.outputs[0],bsdf.inputs["Normal"])
    return m

def flat_mat(name, base, rough=0.9, emit=None, strength=0.0, metal=0.0, double=False, alpha=None):
    if name in bpy.data.materials: return bpy.data.materials[name]
    m=bpy.data.materials.new(name); m.use_nodes=True; b=m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value=(*base,1); b.inputs["Roughness"].default_value=rough; b.inputs["Metallic"].default_value=metal
    if emit:
        b.inputs["Emission Color"].default_value=(*emit,1); b.inputs["Emission Strength"].default_value=strength
    m.use_backface_culling = not double; m.diffuse_color=(*base,1)
    return m
