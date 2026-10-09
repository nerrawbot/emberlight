# v20: grade the Ember Fields texture sets (Poly Haven, CC0, 2k jpg) into the warm dusk palette of the Ember Fields
# painting (dark maroon-brown iron, sun-bleached timber) and write art_src/tex/ef_<name>_{albedo,orm,normal}.jpg, same
# layout as v6_textures.py: luminance remapped onto a dark -> light ramp, `keep` of the original chroma kept,
# ORM = (R height from the displacement map, G roughness, B metal).
# Sources: download <id>_{diff,rough,disp,nor_gl}_2k.jpg from https://polyhaven.com (api.polyhaven.com/files/<id>) into
# one folder, then
#   D:\Blender\blender.exe --background --factory-startup --python art_src\v20_ef_textures.py -- <download folder>
import bpy, numpy as np, os, sys

SRC = sys.argv[sys.argv.index("--") + 1]
TEX = os.path.join(os.path.dirname(os.path.abspath(__file__)), "tex")

GRADES = [   # (poly haven id, out name, dark, light, keep chroma, gamma, metal)
    ("weathered_planks", "ef_planks", (0.07, 0.05, 0.045), (0.6, 0.5, 0.38), 0.35, 1.0, 0.0),
    ("rough_wood", "ef_timber", (0.06, 0.04, 0.035), (0.48, 0.37, 0.27), 0.35, 1.05, 0.0),
    ("wood_peeling_paint_weathered", "ef_paintwood", (0.13, 0.1, 0.09), (0.46, 0.41, 0.36), 0.3, 1.0, 0.0),
    ("rusty_metal_03", "ef_rust", (0.03, 0.025, 0.03), (0.33, 0.24, 0.21), 0.3, 1.15, 0.35),
    ("rusty_corrugated_iron", "ef_corr", (0.04, 0.036, 0.045), (0.38, 0.33, 0.32), 0.3, 1.05, 0.3),
    ("rusty_painted_metal", "ef_oxide", (0.04, 0.018, 0.022), (0.4, 0.15, 0.12), 0.35, 1.0, 0.25),
    ("rust_coarse_01", "ef_rustcoarse", (0.05, 0.03, 0.028), (0.52, 0.3, 0.2), 0.5, 1.0, 0.2),
]

def _load(path, cs):
    im = bpy.data.images.load(path)
    im.colorspace_settings.name = cs
    a = np.empty(im.size[0] * im.size[1] * 4, np.float32)
    im.pixels.foreach_get(a)
    w, h = im.size
    bpy.data.images.remove(im)
    return a.reshape(-1, 4), w, h

def _save(name, a, w, h, cs="sRGB"):
    im = bpy.data.images.new("_grade_tmp", w, h, alpha=False)
    im.colorspace_settings.name = cs
    im.pixels.foreach_set(np.ascontiguousarray(a, np.float32).ravel())
    im.filepath_raw = os.path.join(TEX, name)
    im.file_format = "JPEG"
    try:
        im.save(filepath=os.path.join(TEX, name), quality=90)
    except TypeError:
        im.save()
    bpy.data.images.remove(im)

def grade(src, out, dark, light, keep, gamma, metal):
    f = lambda k: os.path.join(SRC, "%s_%s_2k.jpg" % (src, k))
    a, w, h = _load(f("diff"), "sRGB")
    rgb = a[:, :3]
    L = rgb @ np.array([0.2126, 0.7152, 0.0722], np.float32)
    lo, hi = np.percentile(L, [1, 99])
    t = np.clip((L - lo) / max(1e-4, hi - lo), 0, 1) ** gamma
    dark = np.array(dark, np.float32); light = np.array(light, np.float32)
    o = dark + (light - dark) * t[:, None] + keep * (rgb - L[:, None])
    o = np.clip(np.concatenate([o, np.ones((len(o), 1), np.float32)], 1), 0, 1)
    _save(out + "_albedo.jpg", o, w, h)
    r = _load(f("rough"), "Non-Color")[0][:, 0]
    ht = _load(f("disp"), "Non-Color")[0][:, 0]
    _save(out + "_orm.jpg", np.stack([ht, r, np.full_like(r, metal), np.ones_like(r)], 1), w, h, "Non-Color")
    _save(out + "_normal.jpg", _load(f("nor_gl"), "Non-Color")[0], w, h, "Non-Color")
    return out

print("graded", [grade(*g) for g in GRADES])
