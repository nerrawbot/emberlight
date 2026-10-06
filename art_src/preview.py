
import bpy, numpy as np, os, math
from mathutils import Vector, Euler
def preview(files, cols=2, w=800, h=450):
    imgs=[]
    for f in files:
        im=bpy.data.images.load(f, check_existing=False)
        im.scale(w,h); a=np.empty(w*h*4,np.float32); im.pixels.foreach_get(a); imgs.append(a.reshape(h,w,4)); bpy.data.images.remove(im)
    rows=math.ceil(len(imgs)/cols); sheet=np.zeros((rows*h,cols*w,4),np.float32); sheet[...,3]=1
    for i,a in enumerate(imgs):
        r=rows-1-i//cols; c=i%cols; sheet[r*h:(r+1)*h, c*w:(c+1)*w]=a
    name="__sheet"
    if name in bpy.data.images: bpy.data.images.remove(bpy.data.images[name])
    im=bpy.data.images.new(name,cols*w,rows*h); im.pixels.foreach_set(sheet.ravel())
    sc=bpy.data.scenes.get("Preview") or bpy.data.scenes.new("Preview")
    for o in list(sc.objects): bpy.data.objects.remove(o,do_unlink=True)
    me=bpy.data.meshes.new("pv"); W=cols*w/100; H=rows*h/100
    me.from_pydata([(-W/2,-H/2,0),(W/2,-H/2,0),(W/2,H/2,0),(-W/2,H/2,0)],[],[(0,1,2,3)])
    me.uv_layers.new(); uv=me.uv_layers[0].data
    for i,c in enumerate([(0,0),(1,0),(1,1),(0,1)]): uv[i].uv=c
    mat=bpy.data.materials.get("pvmat") or bpy.data.materials.new("pvmat"); mat.use_nodes=True
    nt=mat.node_tree; tex=nt.nodes.get("pvtex") or nt.nodes.new("ShaderNodeTexImage"); tex.name="pvtex"; tex.image=im
    nt.links.new(tex.outputs[0], nt.nodes["Principled BSDF"].inputs["Base Color"])
    me.materials.append(mat)
    ob=bpy.data.objects.new("pv",me); sc.collection.objects.link(ob)
    bpy.context.window.scene=sc
    for a in bpy.context.screen.areas:
        if a.type=='VIEW_3D':
            sp=a.spaces.active; r3=sp.region_3d
            r3.view_perspective='ORTHO'; r3.view_rotation=Euler((0,0,0)).to_quaternion()
            r3.view_location=Vector((0,0,0)); r3.view_distance=max(W,H*1.6)*0.62
            sp.shading.type='SOLID'; sp.shading.light='FLAT'; sp.shading.color_type='TEXTURE'
            sp.overlay.show_overlays=False; sp.show_gizmo=False
            sp.shading.show_xray=False
    return (cols*w, rows*h)
