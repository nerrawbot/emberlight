
exec(open(r"D:\Emberlight\art_src\v2_creatures.py").read().split("T=\"TMP\"")[0])
T="TMP"
# ======================= LIFT CAR (local, platform top at z=0, faces +Y north) =======================
def car():
    boxmm(T,"M_Grate",-1.5,1.5,-1.5,1.5,-0.18,0.0,"floor",0.0)
    for s in (-1,1):
        member(T,"M_Steel",(-1.5,s*1.5,-0.15),(1.5,s*1.5,-0.15),0.12,0.3)
        member(T,"M_Steel",(s*1.5,-1.5,-0.15),(s*1.5,1.5,-0.15),0.12,0.3)
        for x in (-1.45,0,1.45): member(T,"M_Steel",(x,s*1.45,0),(x,s*1.45,2.9),0.09,0.09)
        member(T,"M_Steel",(-1.45,s*1.45,1.05),(1.45,s*1.45,1.05),0.06,0.06)
        member(T,"M_Steel",(-1.45,s*1.45,0.55),(1.45,s*1.45,0.55),0.04,0.04)
        member(T,"M_Steel",(-1.45,s*1.45,2.9),(1.45,s*1.45,2.9),0.12,0.2)
        boxmm(T,"M_Hazard",s*1.5-0.18,s*1.5+0.18,-1.45,1.45,0.0,0.015,"sill",0.0)
        member(T,"M_Corrugated",(-1.4,s*1.47,0.08),(1.4,s*1.47,0.08),0.02,0.5)
    member(T,"M_Steel",(0,-1.45,2.9),(0,1.45,2.9),0.3,0.3)
    cyl(T,"M_Rust",(0,0,2.9),(0,0,3.25),0.14,8,"hook")
    boxmm(T,"M_Rust",0.75,1.35,1.05,1.4,0.0,1.0,"ctrl",0.03)
part("LiftCar","PROPS",car,(0,0,0))
# ======================= CALL BOX =======================
def cbox():
    cyl(T,"M_Steel",(0,0,0),(0,0,1.0),0.05,8,"post")
    boxmm(T,"M_Rust",-0.18,0.18,-0.12,0.12,0.95,1.45,"box",0.03)
    boxmm(T,"M_Hazard",-0.16,0.16,-0.125,-0.12,1.3,1.42,"sign",0.0)
    cyl(T,"M_Steel",(0,-0.12,1.12),(0,-0.17,1.12),0.06,10,"bezel")
part("CallBox","PROPS",cbox,(0,0,0))
part("Button","PROPS",lambda: cyl(T,"M_Rubber",(0,-0.16,1.12),(0,-0.2,1.12),0.04,10,"btn"),(0,-0.17,1.12),parent="CallBox")
part("Lamp","PROPS",lambda: rockblob(T,(0,-0.13,1.36),(0.035,0.035,0.035),amp=0,seed=0,sub=1,mat="M_Indicator",name="l"),(0,-0.13,1.36),parent="CallBox")
# ======================= LEVER =======================
def lbase():
    boxmm(T,"M_Steel",-0.35,0.35,-0.25,0.25,0,0.08,"plate",0.01)
    boxmm(T,"M_Rust",-0.2,0.2,-0.15,0.15,0.08,0.95,"housing",0.02)
    boxmm(T,"M_Hazard",-0.2,0.2,-0.155,-0.15,0.55,0.7,"haz",0.0)
    cyl(T,"M_Steel",(-0.22,-0.18,0.78),(0.22,-0.18,0.78),0.05,10,"hinge")
part("LeverBase","PROPS",lbase,(0,0,0))
def lhandle():
    member(T,"M_Steel",(0,-0.18,0.78),(0,-0.55,1.42),0.06,0.06)
    cyl(T,"M_Rubber",(0,-0.53,1.39),(0,-0.62,1.55),0.06,8,"grip")
part("Handle","PROPS",lhandle,(0,-0.18,0.78),parent="LeverBase")
# ======================= VALVE =======================
def vbody():
    cyl(T,"M_Steel",(0,0,0),(0,0,2.05),0.13,10,"vp"); cyl(T,"M_Steel",(0,-0.05,2.05),(0,1.75,2.05),0.13,10,"vp2")
    boxmm(T,"M_Rust",-0.22,0.22,-0.22,0.22,0.9,1.35,"body",0.04)
    cyl(T,"M_Steel",(0,-0.2,1.12),(0,-0.45,1.12),0.04,6,"stem"); cyl(T,"M_Steel",(0,0,0),(0,0,0.06),0.25,10,"flange")
    cyl(T,"M_Rust",(0,0,1.8),(0,0,1.86),0.2,10,"fl2"); 
    cyl(T,"M_Steel",(0.13,0,1.5),(0.28,0,1.5),0.03,6,"gauge_st"); cyl(T,"M_Hazard",(0.28,0,1.5),(0.32,0,1.5),0.09,12,"gauge")
part("ValveBody","PROPS",vbody,(0,0,0))
def vwheel():
    for k in range(12):
        a0=k/12*2*math.pi; a1=(k+1)/12*2*math.pi
        member(T,"M_Rust",(0.3*math.cos(a0),-0.47,1.12+0.3*math.sin(a0)),(0.3*math.cos(a1),-0.47,1.12+0.3*math.sin(a1)),0.05,0.05)
    for k in range(3):
        a=k/3*2*math.pi; member(T,"M_Rust",(0,-0.47,1.12),(0.3*math.cos(a),-0.47,1.12+0.3*math.sin(a)),0.035,0.035)
part("Wheel","PROPS",vwheel,(0,-0.47,1.12),parent="ValveBody")
# counterweight block for the lift
def cw():
    boxmm(T,"M_Rust",-0.6,0.6,-0.25,0.25,-1.2,0.0,"cw",0.04)
    boxmm(T,"M_Hazard",-0.61,0.61,-0.26,-0.25,-1.0,-0.6,"cwh",0.0)
    cyl(T,"M_Steel",(0,0,0),(0,0,0.3),0.08,8,"eye")
part("Counterweight","PROPS",cw,(0,0,0))
print([o.name for o in bpy.data.collections["PROPS"].objects])
