import bpy, math
from mathutils import Vector, Euler
def view(loc, rot_deg, lens=20):
    for a in bpy.context.screen.areas:
        if a.type=='VIEW_3D':
            sp=a.spaces.active; r=sp.region_3d
            r.view_perspective='PERSP'; sp.lens=lens
            r.view_rotation=Euler([math.radians(v) for v in rot_deg]).to_quaternion()
            r.view_location=Vector(loc); r.view_distance=0.01
            sp.shading.type='MATERIAL'; sp.overlay.show_overlays=False; sp.clip_start=0.05; sp.clip_end=500
