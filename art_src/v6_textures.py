# v6: grade Poly Haven textures (CC0) into the surface palette and write them to art_src/tex/.
# The sources are downloaded through the Blender MCP (download_polyhaven_asset, 2k), which packs them into materials
# named after the asset id. grade() remaps luminance onto a dark -> light ramp (slate/charcoal with a hint of blue,
# pale cream for painted concrete), keeps `keep` of the original chroma (moss, rust), and writes
#   <out>_albedo.jpg, <out>_orm.jpg (R = height from the displacement map, G = roughness, B = metal), <out>_normal.jpg (GL).
# The terrain set (mesa_*) is also copied to assets/tex/ for the Godot terrain shader (shaders/mesa_terrain.gdshader).
#
# Run in Blender: exec(open(r"...\art_src\v6_textures.py").read()); grade_all()
import bpy, numpy as np, os
TEX = r"C:\Users\Pigeon\Documents\UnderworksCavern\art_src\tex"

GRADES = [   # (poly haven id, out name, dark, light, keep chroma, gamma)
    ("gravel_stones", "mesa_gravel", (0.09, 0.095, 0.115), (0.58, 0.58, 0.62), 0.15, 0.85),
    ("dry_ground_rocks", "mesa_dirt", (0.07, 0.07, 0.09), (0.46, 0.45, 0.5), 0.08, 1.0),
    ("aerial_rocks_04", "mesa_moss", (0.05, 0.06, 0.08), (0.48, 0.5, 0.52), 0.3, 0.9),
    ("dark_rock_02", "mesa_cliff2", (0.035, 0.04, 0.065), (0.38, 0.39, 0.47), 0.1, 1.0),
    ("concrete_slab_wall_02", "concrete2", (0.13, 0.13, 0.145), (0.62, 0.62, 0.63), 0.12, 1.0),
    ("concrete_wall_004", "concrete3", (0.22, 0.21, 0.2), (0.74, 0.71, 0.65), 0.3, 1.2),
    ("rusty_metal_sheet", "rustsheet", (0.05, 0.05, 0.06), (0.55, 0.55, 0.6), 0.75, 1.0),
]

def _px(img):
    a = np.empty(img.size[0] * img.size[1] * 4, np.float32); img.pixels.foreach_get(a); return a.reshape(-1, 4)

def _save(name, a, w, h, cs='sRGB'):
    im = bpy.data.images.get("_grade_tmp")
    if im: bpy.data.images.remove(im)
    im = bpy.data.images.new("_grade_tmp", w, h, alpha=False)
    im.colorspace_settings.name = cs
    im.pixels.foreach_set(np.ascontiguousarray(a, np.float32).ravel())
    im.filepath_raw = os.path.join(TEX, name); im.file_format = 'JPEG'
    try: im.save(filepath=os.path.join(TEX, name), quality=90)
    except TypeError: im.save()
    bpy.data.images.remove(im)

def grade(src, out, dark, light, keep, gamma=1.0, metal=0.0):
    imgs = {n.image.name.split(src + "_")[1]: n.image for n in bpy.data.materials[src].node_tree.nodes if n.type == 'TEX_IMAGE' and n.image}
    d = imgs["Diffuse"]; w, h = d.size
    a = _px(d); rgb = a[:, :3]; L = rgb @ np.array([0.2126, 0.7152, 0.0722], np.float32)
    lo, hi = np.percentile(L, [1, 99]); t = np.clip((L - lo) / max(1e-4, hi - lo), 0, 1) ** gamma
    dark = np.array(dark, np.float32); light = np.array(light, np.float32)
    o = dark + (light - dark) * t[:, None] + keep * (rgb - L[:, None])
    o = np.clip(np.concatenate([o, np.ones((len(o), 1), np.float32)], 1), 0, 1)
    _save(out + "_albedo.jpg", o, w, h)
    r = _px(imgs["Rough"])[:, 0]; ht = _px(imgs["Displacement"])[:, 0]
    _save(out + "_orm.jpg", np.stack([ht, r, np.full_like(r, metal), np.ones_like(r)], 1), w, h, 'Non-Color')
    _save(out + "_normal.jpg", _px(imgs["nor_gl"]), w, h, 'Non-Color')
    return out

def grade_all(only=None):
    done = [grade(s, o, d, l, k, g) for (s, o, d, l, k, g) in GRADES if only is None or o in only]
    print("graded", done)
