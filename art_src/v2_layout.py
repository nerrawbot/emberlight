
exec(open(r"D:\Emberlight\art_src\gen_lib.py").read())
import json
S2="S2"; D2="D2"; P2="P2"; R2="R2"
for c in (S2,D2,P2,R2): coll(c)
# ---------- lift shaft (static guides) ----------
POSTS=[(18.9,-4.7),(22.5,-4.7),(18.9,-1.1),(22.5,-1.1)]
for x,y in POSTS: ibeam(S2,(x,y,0),(x,y,28.6),0.45,0.4,0.05)
for y in (-4.7,-1.1):
    for z0 in (2,8,14,20):
        z1=z0+5.5
        member(D2,"M_Steel",(18.9,y,z0),(22.5,y,z1),0.08,0.12); member(D2,"M_Steel",(22.5,y,z0),(18.9,y,z1),0.08,0.12)
    member(D2,"M_Steel",(18.9,y,27.6),(22.5,y,27.6),0.3,0.4)
for x in (18.9,22.5): ibeam(D2,(x,-4.9,27.9),(x,-0.9,27.9),0.5,0.35)
cyl(D2,"M_Rust",(20.0,-2.9,28.5),(21.4,-2.9,28.5),0.85,18,"pulley")
cyl(D2,"M_Steel",(19.6,-2.9,28.5),(21.8,-2.9,28.5),0.12,8,"axle")
boxmm(D2,"M_Rust",21.7,23.3,-3.7,-2.1,27.9,29.3,"winch_motor",0.06)
boxmm(D2,"M_Hazard",18.55,19.15,-4.4,-1.4,18.0,18.025,"haz_top",0.0)
boxmm(D2,"M_Hazard",22.3,23.4,-4.4,-1.4,0.0,0.03,"haz_bot",0.0)
# ---------- ladder to mezzanine ----------
for x in (11.7,12.3):
    member(D2,"M_Steel",(x,6.22,18.0),(x,6.22,24.5),0.06,0.06)
    member(D2,"M_Steel",(x,6.22,24.5),(x,6.75,24.05),0.06,0.06)
for i in range(18): member(D2,"M_Rust",(11.7,6.22,18.3+i*0.3),(12.3,6.22,18.3+i*0.3),0.04,0.04)
for z in (19.2,21.0,22.8): member(D2,"M_Steel",(11.7,6.22,z),(11.7,6.42,z),0.05,0.05); member(D2,"M_Steel",(12.3,6.22,z),(12.3,6.42,z),0.05,0.05)
boxmm(P2,None,11.35,12.65,6.30,6.42,18.0,23.36,"ladder_back",0.0)
# ---------- shaft balcony + sagging catwalk bridge (mezz -> C deck) ----------
P=[Vector((18.3,7.5,23.5)),Vector((27.5,7.0,23.25)),Vector((36.4,6.6,25.0))]
for a,b in ((P[0],P[1]),(P[1],P[2])):
    n=4
    for i in range(n):
        p0=a.lerp(b,i/n); p1=a.lerp(b,(i+1)/n)
        member(S2,"M_Grate",p0-Vector((0,0,0.05)),p1-Vector((0,0,0.05)),1.8,0.1,"bridge_deck")
    side=Vector((-(b-a).y,(b-a).x,0)).normalized()
    for s in (-1,1):
        member(D2,"M_Steel",a+side*s*0.95-Vector((0,0,0.3)),b+side*s*0.95-Vector((0,0,0.3)),0.14,0.45)
    railing(S2,a+side*0.9,b+side*0.9,h=1.05,spacing=1.6,broken=0.25,seed=int(a.x))
    railing(S2,a-side*0.9,b-side*0.9,h=1.05,spacing=1.6,broken=0.1,seed=int(a.x)+7)
    L=(b-a).length; k=int(L/2.2)
    for i in range(1,k):
        q=a.lerp(b,i/k); member(D2,"M_Steel",q+side*1.0-Vector((0,0,0.55)),q-side*1.0-Vector((0,0,0.55)),0.08,0.08)
for x in (22.0,27.5,32.5):
    t=(x-P[0].x)/(P[1].x-P[0].x) if x<P[1].x else (x-P[1].x)/(P[2].x-P[1].x)
    q=P[0].lerp(P[1],t) if x<P[1].x else P[1].lerp(P[2],t)
    for s in (-1,1):
        cyl(D2,"M_Cable",q+Vector((0,s*0.95,0)),Vector((q.x+0.3,q.y+s*1.3,29.8)),0.03,5,"susp")
# kinked support strut from the left frame
ibeam(D2,(18.4,8.6,19.2),(22.0,8.0,23.0),0.3,0.2)
# ---------- low-ledge stair ----------
stairs(D2,(18.4,-7.5,0.0),(13.0,-7.5,1.6),2.0,rampcat=R2)
# ---------- breaker cabinet beside the lever ----------
boxmm(S2,"M_Rust",72.15,72.75,1.0,3.0,19.0,21.3,"breaker",0.05)
boxmm(D2,"M_Hazard",72.1,72.16,1.2,2.8,20.6,21.1,"breaker_sign",0.0)
cyl(D2,"M_Steel",(72.45,2.6,21.3),(72.45,2.6,30.5),0.07,8,"conduit")
cyl(D2,"M_Steel",(72.45,1.4,21.3),(72.45,1.4,30.5),0.05,8,"conduit2")
# ---------- collision proxies ----------
for x in (28,36,44,52,60,68): boxmm(P2,None,x-1.4,x+1.4,12.1,14.9,0,30,"bgp",0.0)
boxmm(P2,None,48.8,51.6,-10.4,-8.2,0,31,"fgp",0.0)
boxmm(P2,None,13.5,15.5,-10.6,-8.6,0,30,"fgp2",0.0)
boxmm(P2,None,31,41,-12.4,-9.2,-1,3.4,"fgr",0.0)
boxmm(P2,None,57,77,-12.4,-8.4,-1,5.5,"fgr2",0.0)
for (x0,x1,y0,y1) in ((-12,-11,-32,42),(91,92,-32,42),(-12,92,-32,-31),(-12,92,41,42)):
    boxmm(P2,None,x0,x1,y0,y1,34.3,40,"surf_wall",0.0)
