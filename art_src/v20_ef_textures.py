# v20: the Ember Fields texture sets. Poly Haven (CC0, 2k jpg) graded into the region's palette - browns, ochre
# yellow, tarnished gold and worn steel under a dusk sun (not the Forsaken Debris slate/blue set in art_src/tex) - and
# written to art_src/tex/ef_<name>_{albedo,orm,normal}.jpg, same layout as v6_textures.py: luminance remapped onto a
# dark -> light ramp, `keep` of the original chroma kept, ORM = (R height from the displacement map, G roughness, B metal).
# ef_hazard (gold/black stripes) is generated here, grimed with rust_coarse_01.
# Sources: download <id>_{diff,rough,disp,nor_gl}_2k.jpg from https://polyhaven.com (api.polyhaven.com/files/<id>) into
# one folder, then (CPU only, no GPU work here):
#   D:\Blender\blender.exe --background --factory-startup --python art_src\v20_ef_textures.py -- <download folder>
import bpy, numpy as np, os, sys

SRC = sys.argv[sys.argv.index("--") + 1]
TEX = os.path.join(os.path.dirname(os.path.abspath(__file__)), "tex")

BROWN_D, BROWN_L = (0.05, 0.034, 0.022), (0.44, 0.31, 0.18)
GRADES = [   # (poly haven id, out name, dark, light, keep chroma, gamma, metal)
    # metals
    ("green_metal_rust", "ef_steel", (0.07, 0.068, 0.066), (0.5, 0.48, 0.45), 0.08, 1.0, 0.6),          # worn steel
    ("rusty_metal_04", "ef_iron", (0.04, 0.03, 0.022), (0.36, 0.27, 0.18), 0.25, 1.1, 0.4),             # dark brown hull plate
    ("rusty_metal_03", "ef_rust", BROWN_D, BROWN_L, 0.3, 1.1, 0.35),                                    # brown rust
    ("rusty_metal_05", "ef_brass", (0.09, 0.065, 0.025), (0.74, 0.57, 0.27), 0.25, 1.0, 0.7),          # tarnished gold trim
    ("rust_coarse_01", "ef_ochre", (0.3, 0.2, 0.06), (0.72, 0.55, 0.2), 0.1, 0.8, 0.2),                # ochre machine paint, mottled (no directional streaks)
    ("rusty_corrugated_iron", "ef_corr", (0.05, 0.04, 0.03), (0.46, 0.37, 0.25), 0.25, 1.05, 0.3),
    ("rust_coarse_01", "ef_rustcoarse", (0.06, 0.04, 0.02), (0.55, 0.38, 0.18), 0.35, 1.0, 0.2),
    ("metal_grate_rusty", "ef_deck", (0.05, 0.04, 0.03), (0.42, 0.33, 0.22), 0.25, 1.0, 0.4),          # tread-plate decks
    # concrete
    ("rough_concrete", "ef_concrete", (0.16, 0.13, 0.09), (0.66, 0.58, 0.44), 0.15, 1.0, 0.0),         # sandy, sun-bleached
    ("concrete_floor_worn_001", "ef_concrete2", (0.12, 0.1, 0.075), (0.56, 0.49, 0.38), 0.15, 1.0, 0.0),
    # wood
    ("weathered_planks", "ef_planks", (0.07, 0.05, 0.03), (0.62, 0.5, 0.32), 0.3, 1.0, 0.0),
    ("rough_wood", "ef_timber", (0.06, 0.04, 0.025), (0.5, 0.37, 0.22), 0.3, 1.05, 0.0),
    ("wood_peeling_paint_weathered", "ef_paintwood", (0.24, 0.17, 0.08), (0.6, 0.5, 0.3), 0.1, 0.85, 0.0),   # faded yellow paint, flattened
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

def _src(src, k): return os.path.join(SRC, "%s_%s_2k.jpg" % (src, k))

def grade(src, out, dark, light, keep, gamma, metal):
    a, w, h = _load(_src(src, "diff"), "sRGB")
    rgb = a[:, :3]
    L = rgb @ np.array([0.2126, 0.7152, 0.0722], np.float32)
    lo, hi = np.percentile(L, [1, 99])
    t = np.clip((L - lo) / max(1e-4, hi - lo), 0, 1) ** gamma
    dark = np.array(dark, np.float32); light = np.array(light, np.float32)
    o = dark + (light - dark) * t[:, None] + keep * (rgb - L[:, None])
    o = np.clip(np.concatenate([o, np.ones((len(o), 1), np.float32)], 1), 0, 1)
    _save(out + "_albedo.jpg", o, w, h)
    r = _load(_src(src, "rough"), "Non-Color")[0][:, 0]
    ht = _load(_src(src, "disp"), "Non-Color")[0][:, 0]
    _save(out + "_orm.jpg", np.stack([ht, r, np.full_like(r, metal), np.ones_like(r)], 1), w, h, "Non-Color")
    _save(out + "_normal.jpg", _load(_src(src, "nor_gl"), "Non-Color")[0], w, h, "Non-Color")
    return out

def hazard():
    """Gold / black diagonal stripes (4 per tile), worn through to rust where rust_coarse_01 is dark."""
    g, w, h = _load(_src("rust_coarse_01", "diff"), "sRGB")
    L = (g[:, :3] @ np.array([0.2126, 0.7152, 0.0722], np.float32)).reshape(h, w)
    lo, hi = np.percentile(L, [2, 98]); L = np.clip((L - lo) / (hi - lo), 0, 1)
    y, x = np.mgrid[0:h, 0:w].astype(np.float32)
    band = (((x + y) / w * 4.0) % 1.0) < 0.5
    gold = np.array((0.78, 0.58, 0.16), np.float32); black = np.array((0.05, 0.045, 0.04), np.float32)
    rust = np.array((0.32, 0.19, 0.09), np.float32)
    paint = np.where(band[..., None], gold, black) * (0.75 + 0.25 * L[..., None])
    worn = np.clip((0.35 - L) / 0.2, 0, 1)[..., None]              # paint gone where the grime map is darkest
    o = paint * (1 - worn) + rust * worn * (0.6 + 0.6 * L[..., None])
    o = np.concatenate([o.reshape(-1, 3), np.ones((w * h, 1), np.float32)], 1)
    _save("ef_hazard_albedo.jpg", np.clip(o, 0, 1), w, h)
    return "ef_hazard"

print("graded", [grade(*g) for g in GRADES] + [hazard()])
