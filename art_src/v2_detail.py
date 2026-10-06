
exec(open(r"C:\Users\Pigeon\Documents\UnderworksCavern\art_src\gen_lib.py").read())
from mathutils import Euler
import json
S2="S2"; D2="D2"; L2="Lamps2"; W2="Water"
for c in (S2,D2,L2,W2): coll(c)
rk=bpy.data.objects["Rock-col"]
from mathutils.bvhtree import BVHTree
_me=rk.data
BVH=BVHTree.FromPolygons([rk.matrix_world@v.co for v in _me.vertices],[tuple(p.vertices) for p in _me.polygons])
class _RK:
    def ray_cast(self,o,d):
        loc,n,i,dist=BVH.ray_cast(o,d)
        return (loc is not None), (loc if loc is not None else Vector()), n, i
rk=_RK()
def fz(x,y,top=40.0):
    hit,loc,n,i=rk.ray_cast(Vector((x,y,top)),Vector((0,0,-1)))
    return loc.z if hit else 0.0
def floor_z(x,y):
    hit,loc,n,i=rk.ray_cast(Vector((x,y,3.0)),Vector((0,0,-1)))
    return loc.z if hit else 0.0
R=random.Random(77)
def barrel(x,y,z,tip=False,mat="M_Rust",r=0.32,h=0.9):
    if tip:
        a=R.uniform(0,6.28); d=Vector((math.cos(a),math.sin(a),0))
        p0=Vector((x,y,z+r))-d*h/2; p1=p0+d*h
        cyl(S2,mat,p0,p1,r,12,"barrel")
        for t in (0.15,0.85): cyl(D2,"M_Steel",p0.lerp(p1,t-0.02),p0.lerp(p1,t+0.02),r+0.025,12,"rim")
    else:
        cyl(S2,mat,(x,y,z),(x,y,z+h),r,12,"barrel")
        for t in (0.15,0.85): cyl(D2,"M_Steel",(x,y,z+h*t-0.02),(x,y,z+h*t+0.02),r+0.025,12,"rim")
def crate(x,y,z,s=1.0,yaw=0.0):
    o=boxmm(S2,"M_Rust",-s/2,s/2,-s/2,s/2,0,s,"crate",0.03); o.location=(x,y,z); o.rotation_euler=(0,0,yaw)
    for k in (-1,1):
        m=member(D2,"M_Steel",(x-s/2,y+k*s/2,z+0.05),(x+s/2,y+k*s/2,z+s-0.05),0.05,0.05)
def scrap_pile(cx,cy,rad=2.2,n=14,seed=0):
    r=random.Random(seed); base=floor_z(cx,cy)
    rockblob(S2,(cx,cy,base-0.2),(rad*0.8,rad*0.6,0.7),seed=seed,amp=0.5,sub=2,mat="M_Rust",name="heap")
    for i in range(n):
        a=r.uniform(0,6.28); d=r.uniform(0,rad); p=Vector((cx+math.cos(a)*d,cy+math.sin(a)*d,base+r.uniform(0.0,0.6)*(1-d/rad)+0.1))
        k=r.random()
        tgt=p+Vector((r.uniform(-1,1),r.uniform(-1,1),r.uniform(-0.3,0.6))).normalized()*r.uniform(0.8,2.8)
        if k<0.35: ibeam(D2,p,tgt,0.22,0.16,0.03)
        elif k<0.6: cyl(D2,"M_Steel",p,tgt,r.uniform(0.08,0.2),8,"spipe")
        elif k<0.8: member(D2,r.choice(["M_Corrugated","M_Rust","M_Grate"]),p,tgt,r.uniform(0.5,1.1),0.03)
        else: member(D2,"M_Steel",p,tgt,0.06,0.06)
# ---------- floor clutter ----------
for (cx,cy,sd) in ((31,-7,1),(56,-7.5,2),(73,12,3),(40,10.8,4),(17,11,5),(64,-9.5,6)):
    scrap_pile(cx,cy,2.4,16,sd)
for (cx,cy) in ((45,-6.5),(63.5,-0.5),(27,3.5),(74,-2),(26,11.5),(16.8,-11)):
    for i in range(R.randint(2,4)):
        x=cx+R.uniform(-1,1); y=cy+R.uniform(-1,1)
        barrel(x,y,floor_z(x,y)-0.02,tip=R.random()<0.3)
for (x,y,s) in ((52,-7.2,1.2),(53.2,-6.6,0.9),(57,5,1.1),(35,1.8,1.0),(70,10.2,1.3),(16.5,-6.0,0.9)):
    crate(x,y,floor_z(x,y)-0.02,s,R.uniform(-0.4,0.4))
crate(3.2,-6.4,1.6,1.0,0.3); barrel(1.4,-7.0,1.6); barrel(1.0,-8.0,1.6,tip=True)
# ---------- mine track ----------
xs=[24+i*1.0 for i in range(53)]
pts=[(x,floor_z(x,-1.5)) for x in xs]
for i,(x,z) in enumerate(pts):
    if i%1==0: boxmm(D2,"M_Rust",x-0.15,x+0.15,-2.6,-0.4,z-0.02,z+0.1,"sleeper",0.01)
for yy in (-2.2,-0.8):
    for i in range(len(pts)-1):
        (xa,za),(xb,zb)=pts[i],pts[i+1]
        if 47<xa<48: continue  # broken rail
        member(D2,"M_Steel",(xa,yy,za+0.17),(xb,yy,zb+0.17),0.07,0.12)
def cart(x,y,z,roll=0.0,yaw=0.0):
    parts=[]
    parts.append(boxmm(D2,"M_Rust",-0.9,0.9,-0.6,0.6,0.35,0.42,"cb",0.02))
    for s in (-1,1):
        parts.append(boxmm(D2,"M_Rust",-0.95,0.95,s*0.6-0.04,s*0.6+0.04,0.35,1.2,"cs",0.02))
        parts.append(boxmm(D2,"M_Rust",s*0.9-0.04,s*0.9+0.04,-0.6,0.6,0.35,1.2,"ce",0.02))
        for xx in (-0.55,0.55): parts.append(cyl(D2,"M_Steel",(xx,s*0.75,0.25),(xx,s*0.62,0.25),0.25,10,"wheel"))
    for o in parts:
        o.location=Matrix.Rotation(yaw,4,'Z')@Matrix.Rotation(roll,4,'X')@o.location+Vector((x,y,z))
        o.rotation_mode='XYZ' if o.rotation_mode!='QUATERNION' else 'QUATERNION'
        if o.rotation_mode=='QUATERNION': o.rotation_quaternion=(Quaternion((0,0,1),yaw)@Quaternion((1,0,0),roll))@o.rotation_quaternion
        else: o.rotation_euler=(roll,0,yaw)
cart(37,-1.5,floor_z(37,-1.5))
cart(60.5,2.2,floor_z(60.5,2.2)+0.05,roll=1.75,yaw=0.4)
# ---------- puddles ----------
puddles=[]
for i in range(260):
    x=R.uniform(16,75); y=R.uniform(-10,11)
    if 18.3<x<23.6 and -5<y<-0.6: continue
    zs=[floor_z(x+dx,y+dy) for dx in (-1.5,0,1.5) for dy in (-1.5,0,1.5)]
    c=zs[4]
    if c < sorted(zs)[2] and max(zs)-c>0.12:
        lvl=c+min(0.09,(sorted(zs)[4]-c)*0.6)
        if all((Vector((x,y))-Vector(p[:2])).length>5 for p in puddles):
            bm=bmesh.new(); bmesh.ops.create_circle(bm,cap_ends=True,segments=20,radius=2.2)
            o=mk_obj("puddle",bm,"M_Water",W2); o.location=(x,y,lvl); puddles.append((x,y,lvl))
    if len(puddles)>=9: break
# ---------- corrugated cladding ----------
def panels(p0,p1,z0,z1,normal_axis,seed,miss=0.25,w=1.15):
    r=random.Random(seed); p0=Vector(p0); p1=Vector(p1); L=(p1-p0).length; n=int(L/w)
    d=(p1-p0).normalized(); ang=math.atan2(d.y,d.x)
    for i in range(n):
        if r.random()<miss: continue
        c=p0+d*((i+0.5)*w)
        top=z1-(r.uniform(0.3,1.4) if r.random()<0.3 else 0)
        o=boxmm(S2,"M_Corrugated",-w/2+0.03,w/2-0.03,-0.02,0.02,0,top-z0,"panel",0.0)
        o.location=(c.x,c.y,z0+(top-z0)/2); o.rotation_euler=(r.uniform(-0.03,0.03),0,ang+r.uniform(-0.03,0.03))
panels((50,8.32,0),(61.8,8.32,0),13.05,18.4,'y',11)
panels((0.6,9.25,0),(18.3,9.25,0),18.0,23.2,'y',12,miss=0.3)
panels((72.65,-4,0),(72.65,8.0,0),19.05,24.2,'x',13,miss=0.35)
panels((46.2,8.45,0),(61.8,8.45,0),19.05,24.0,'y',14,miss=0.4)
# a few fallen panels
for (x,y) in ((42,-6),(66,11),(29,9),(19.5,10)):
    member(D2,"M_Corrugated",(x,y,floor_z(x,y)+0.25),(x+1.8,y+0.6,floor_z(x,y)+0.6),1.1,0.04)
# ---------- stalactites / stalagmites ----------
for i in range(55):
    x=R.uniform(-3,78); y=R.uniform(-11,16)
    if 29<x<48 and -1<y<9: continue
    if 18<x<24 and -6<y<0: continue
    top=fz(x,y,29.0) if False else None
    hit,loc,n,ii=rk.ray_cast(Vector((x,y,20)),Vector((0,0,1)))
    if not hit or loc.z<26: continue
    ln=R.uniform(1.0,4.5); r0=R.uniform(0.25,0.8)
    cyl("Rock","M_Rock",(x,y,loc.z+0.6),(x+R.uniform(-0.2,0.2),y+R.uniform(-0.2,0.2),loc.z-ln),r0,7,"stal",r2=0.03)
for i in range(30):
    x=R.uniform(15,76); y=R.choice([R.uniform(-12,-9.5),R.uniform(15,17)])
    z=floor_z(x,y); ln=R.uniform(0.6,2.2)
    cyl("Rock","M_Rock",(x,y,z-0.3),(x,y,z+ln),R.uniform(0.3,0.7),7,"stalag",r2=0.05)
# ---------- wall pipes + junction boxes ----------
for z,r in ((2.6,0.28),(3.3,0.2)):
    cyl(D2,"M_Steel",(14,16.2,z),(76,16.2,z),r,12,"wallpipe")
for x in range(16,76,5):
    cyl(D2,"M_Rust",(x-0.06,16.2,2.6),(x+0.06,16.2,2.6),0.36,12,"flange")
    member(D2,"M_Steel",(x,16.2,0),(x,16.2,3.6),0.12,0.12)
for (x,z) in ((30,4.5),(47,5.0),(61,4.2)):
    boxmm(D2,"M_Rust",x-0.5,x+0.5,15.75,16.15,z,z+1.2,"jbox",0.03)
    cyl(D2,"M_Steel",(x,15.95,z+1.2),(x,15.95,29),0.05,6,"conduit")
for (x,y,z) in ((46.3,-4.6,4),(64.3,8.6,6),(22.8,-1.0,1.2)):
    boxmm(D2,"M_Rust",x-0.25,x+0.25,y-0.15,y+0.15,z,z+0.7,"jbox_s",0.02)
# ---------- extra lamps ----------
lamps2=[]
def cage_lamp(p, kind="normal", hang=1.1):
    p=Vector(p)
    cyl(L2,"M_Cable",p+Vector((0,0,0.5)),p+Vector((0,0,0.5+hang)),0.015,4,"wire")
    if kind=="normal": cyl(L2,"M_Lamp",p,p+Vector((0,0,0.35)),0.12,8,"bulb")
    cyl(L2,"M_Steel",p+Vector((0,0,0.35)),p+Vector((0,0,0.55)),0.28,8,"shade",r2=0.1)
    for k in range(4):
        a=k*math.pi/2; o=Vector((math.cos(a)*0.17,math.sin(a)*0.17,0))
        member(L2,"M_Steel",p+o+Vector((0,0,-0.08)),p+o+Vector((0,0,0.37)),0.02,0.02)
    lamps2.append({"pos":list(p),"kind":kind})
cage_lamp((35,2,10.4),"normal",0.6)
cage_lamp((47,9.8,10.5),"normal",0.6)
cage_lamp((20.7,-2.9,26.0),"normal",0.5)
cage_lamp((7,-7,6.2),"flicker",1.2)
cage_lamp((55,4.6,27.2),"normal",1.0)
cage_lamp((31.5,-4.3,11.0),"flicker",0.6)
cage_lamp((68,6,24.5),"flicker",1.2)
cage_lamp((28,8.3,22.0),"normal",0.6)
d=json.load(open(os.path.join(PROJ,"art_src","lights.json")))
d["lamps2"]=lamps2; d["puddles"]=[list(p) for p in puddles]
json.dump(d,open(os.path.join(PROJ,"art_src","lights.json"),"w"),indent=1)
print("puddles",len(puddles))
