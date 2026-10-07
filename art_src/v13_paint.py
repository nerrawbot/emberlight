# v13b: hand-painted look for the Sphaeroid. Paints its albedo maps stroke by stroke (numpy) after the reference
# painting: drip streaks down the indigo hull, lavender pylon with a misty band and rust runs, a charcoal cannon with
# long pale strokes along the barrel, a mottled maroon star; plus a grey "brush" map that breaks up the light/shadow
# edge in scripts/creatures/painterly.gdshader. The shader projects them in each part's local space (sphaeroid.gd
# _paint_model()), so the model's UVs don't matter and the drips always run down.
# Writes assets/creatures/sph_paint_{hull,leg,cannon,steel,star,brush}.png. Needs no .blend:
#   D:\Blender\blender.exe --background --factory-startup --python art_src\v13_paint.py
import os, math
import numpy as np
import bpy

PROJ = r"D:\Emberlight"
OUT = os.path.join(PROJ, "assets", "creatures")
rng = np.random.default_rng(13)

def C(hexs):
    return np.array([int(hexs[i:i + 2], 16) / 255.0 for i in (0, 2, 4)], np.float32)

def smooth(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3 - 2 * t)

def value_noise(h, w, cells_y, cells_x, seed):
    """Tileable smooth noise in [0, 1]."""
    r = np.random.default_rng(seed).random((cells_y, cells_x)).astype(np.float32)
    y = np.linspace(0, cells_y, h, endpoint=False); x = np.linspace(0, cells_x, w, endpoint=False)
    y0 = np.floor(y).astype(int); x0 = np.floor(x).astype(int)
    fy = smooth(0, 1, y - y0)[:, None]; fx = smooth(0, 1, x - x0)[None, :]
    y1 = (y0 + 1) % cells_y; x1 = (x0 + 1) % cells_x
    a = r[np.ix_(y0, x0)]; b = r[np.ix_(y0, x1)]; c = r[np.ix_(y1, x0)]; d = r[np.ix_(y1, x1)]
    return (a * (1 - fx) + b * fx) * (1 - fy) + (c * (1 - fx) + d * fx) * fy

def fbm(h, w, base_y, base_x, seed, octaves=4):
    out = np.zeros((h, w), np.float32); amp = 0.5; tot = 0.0
    for o in range(octaves):
        out += value_noise(h, w, base_y * 2 ** o, base_x * 2 ** o, seed + o) * amp
        tot += amp; amp *= 0.5
    return out / tot

def blur_x(a, k):
    """Box blur along x (wrapping), k passes of 3 taps."""
    for _ in range(k):
        a = (np.roll(a, 1, 1) + a + np.roll(a, -1, 1)) / 3.0
    return a

def blur_y(a, k):
    for _ in range(k):
        b = a.copy()
        b[1:-1] = (a[:-2] + a[1:-1] + a[2:]) / 3.0
        a = b
    return a

def stroke(img, x0, y0, x1, y1, w0, w1, col, alpha, wrap_y=False, dry=0.5, blob=0.0):
    """One brush stroke from (x0,y0) to (x1,y1) (pixels), width w0 -> w1, over-blended into img (H, W, 3).
    Wraps in x (and y if wrap_y). `dry`: how much the bristles skip (streaky alpha). `blob`: round drop at the end."""
    H, W, _ = img.shape
    pad = max(w0, w1, blob) + 2
    xa, xb = int(math.floor(min(x0, x1) - pad)), int(math.ceil(max(x0, x1) + pad))
    ya, yb = int(math.floor(min(y0, y1) - pad)), int(math.ceil(max(y0, y1) + pad))
    xs = np.arange(xa, xb); ys = np.arange(ya, yb)
    if not wrap_y:
        ys = ys[(ys >= 0) & (ys < H)]
        if ys.size == 0:
            return
    X, Y = np.meshgrid(xs.astype(np.float32), ys.astype(np.float32))
    dx, dy = x1 - x0, y1 - y0
    L2 = max(dx * dx + dy * dy, 1e-6); L = math.sqrt(L2)
    t = np.clip(((X - x0) * dx + (Y - y0) * dy) / L2, 0.0, 1.0)
    px = x0 + dx * t; py = y0 + dy * t
    d = np.sqrt((X - px) ** 2 + (Y - py) ** 2)
    w = (w0 + (w1 - w0) * t) * 0.5
    a = 1.0 - smooth(w * 0.55, w + 0.8, d)
    if blob > 0:
        db = np.sqrt((X - x1) ** 2 + (Y - y1) ** 2)
        a = np.maximum(a, 1.0 - smooth(blob * 0.5, blob + 0.8, db))
    # bristle streaks: noise across the stroke, stretched along it
    across = ((X - px) * -dy + (Y - py) * dx) / L
    ph1, ph2 = rng.random() * 6.3, rng.random() * 6.3
    bristle = 0.5 + 0.5 * np.sin(across * 2.3 + ph1) * np.sin(across * 0.9 + t * 3.0 + ph2)
    a *= 1.0 - dry * smooth(0.55, 0.95, bristle) * smooth(0.0, 0.6, t)
    a *= alpha * (0.85 + 0.15 * smooth(0.0, 0.08, t))
    ci = xs % W
    ri = ys % H if wrap_y else ys
    reg = img[np.ix_(ri, ci)]
    img[np.ix_(ri, ci)] = reg * (1 - a[..., None]) + np.asarray(col, np.float32) * a[..., None]

def jitter(col, amt):
    return np.clip(col * (1 + rng.normal(0, amt, 3).astype(np.float32)), 0, 1)

def base_fill(H, W, dark, light, cells, seed, streak=4):
    """Mottled ground: fbm lerp between two colours, smeared along x a little (a dragged brush)."""
    n = fbm(H, W, cells[0], cells[1], seed)
    n = blur_x(n, streak)
    n = smooth(0.25, 0.75, n)
    return dark[None, None, :] * (1 - n[..., None]) + light[None, None, :] * n[..., None]

def save(name, img):
    H, W, _ = img.shape
    px = np.ones((H, W, 4), np.float32)
    px[..., :3] = np.clip(img, 0, 1)
    px = px[::-1]                 # Blender images are bottom-up
    im = bpy.data.images.new(name, W, H, alpha=False)
    im.pixels.foreach_set(px.ravel())
    im.filepath_raw = os.path.join(OUT, name + ".png"); im.file_format = "PNG"
    im.save()
    bpy.data.images.remove(im)
    print("wrote", name, W, H)

# ---------------------------------------------------------------------------------------------- hull
def paint_hull():
    """u = once round the ball (11 m), v = top -> bottom (3.6 m). Dark indigo, long drips from the crown and the
    seams, a few lighter violet runs catching the light, darker pooling low."""
    H, W = 512, 1024
    img = base_fill(H, W, C("17142a"), C("2c2747"), (3, 6), 1, streak=2)
    grad = np.linspace(0, 1, H, dtype=np.float32)[:, None, None]
    img *= 1.08 - 0.35 * grad                     # darker underneath
    cap = 0.25 * smooth(0.0, 0.25, 1 - grad)      # a lighter crown
    img = img * (1 - cap) + C("3a3458") * cap
    # broad vertical washes first, then many thin drips
    for _ in range(40):
        x = rng.uniform(0, W); y = rng.uniform(-40, H * 0.45); L = rng.uniform(120, 380)
        col = jitter(C("2f2a4c") if rng.random() < 0.6 else C("120f22"), 0.08)
        w = rng.uniform(14, 34)
        stroke(img, x, y, x + rng.normal(0, 3), y + L, w, w * 0.6, col, rng.uniform(0.25, 0.45), dry=0.7)
    starts = (lambda: rng.uniform(-20, 60), lambda: rng.uniform(0.18, 0.25) * H,
              lambda: rng.uniform(0.72, 0.8) * H, lambda: rng.uniform(0, H * 0.7))
    for _ in range(150):
        x = rng.uniform(0, W)
        y = starts[int(rng.integers(0, 4))]()
        L = rng.uniform(40, 300)
        r = rng.random()
        col = C("3f3a60") if r < 0.22 else C("524c78") if r < 0.28 else C("0b0916") if r < 0.85 else C("231d3a")
        w = rng.uniform(4.0, 14.0)
        stroke(img, x, y, x + rng.normal(0, 1.2), y + L, w, w * rng.uniform(0.3, 0.6), jitter(col, 0.06),
               rng.uniform(0.35, 0.75), dry=0.55, blob=w * 0.55 if rng.random() < 0.4 else 0.0)
    # a few soft dragged highlights across the crown (the painting's lighter smears)
    for _ in range(10):
        x = rng.uniform(0, W); y = rng.uniform(0.05, 0.35) * H; L = rng.uniform(60, 200)
        stroke(img, x, y, x + L, y + rng.normal(0, 3), 18, 10, jitter(C("443e64"), 0.05), 0.3, dry=0.85)
    img = blur_x(img, 2)
    img = (img + blur_y(img, 1)) * 0.5
    save("sph_paint_hull", img)

# ---------------------------------------------------------------------------------------------- leg / skid
def paint_leg():
    """Box-projected sides (u along the face, ~0.7 m per tile), v = top -> bottom of the pylon (2.7 m). Pale
    lavender, cooler and darker at the top, a misty whitish band two thirds down, thin rust runs."""
    H, W = 512, 256
    img = base_fill(H, W, C("7e7ca0"), C("a9a7c4"), (4, 2), 7, streak=1)
    g = np.linspace(0, 1, H, dtype=np.float32)
    top = (0.55 * smooth(0.55, 1.0, 1 - g))[:, None, None]
    img = img * (1 - top) + C("4a4868") * top
    # the mist band: soft horizontal strokes
    for _ in range(26):
        y = rng.uniform(0.52, 0.66) * H; x = rng.uniform(0, W); L = rng.uniform(60, 200)
        stroke(img, x, y, x + L, y + rng.normal(0, 4), rng.uniform(10, 26), rng.uniform(6, 18),
               jitter(C("d6d4e4"), 0.03), rng.uniform(0.25, 0.5), dry=0.85)
    # darker vertical bristle strokes from the top
    for _ in range(40):
        x = rng.uniform(0, W); y = rng.uniform(-10, H * 0.3); L = rng.uniform(40, 220)
        stroke(img, x, y, x + rng.normal(0, 1), y + L, rng.uniform(3, 8), 2, jitter(C("5d5b80"), 0.05),
               rng.uniform(0.3, 0.6), dry=0.6)
    # rust runs (the painting's thin orange-brown lines)
    for _ in range(5):
        x = rng.uniform(0, W); y = rng.uniform(0.0, 0.4) * H; L = rng.uniform(80, 260)
        stroke(img, x, y, x + rng.normal(0, 1.5), y + L, 2.6, 1.4, jitter(C("6a3422"), 0.08), 0.6, dry=0.4,
               blob=1.8)
    save("sph_paint_leg", img)

# ---------------------------------------------------------------------------------------------- cannon
def paint_cannon():
    """u = along the barrel (2.5 m), v = round it. Charcoal violet with long pale strokes laid along the tube
    (strongest on its top: v ~ 0.25 faces up), shadow strokes underneath."""
    H, W = 256, 1024
    img = base_fill(H, W, C("1a1726"), C("2c2840"), (2, 8), 21, streak=6)
    v = np.linspace(0, 1, H, dtype=np.float32)
    up = (0.5 + 0.5 * np.cos((v - 0.25) * 2 * math.pi))[:, None, None]       # 1 on the top of the tube
    img = img * (0.75 + 0.35 * up)
    for _ in range(140):
        y = ((0.25 + rng.normal(0, 0.16)) % 1.0) * H; x = rng.uniform(0, W); L = rng.uniform(80, 420)
        r = rng.random()
        col = C("5e5878") if r < 0.45 else C("7a7498") if r < 0.6 else C("0e0c16")
        w = rng.uniform(3, 10)
        stroke(img, x, y, x + L, y + rng.normal(0, 2.5), w, w * 0.5, jitter(col, 0.06),
               rng.uniform(0.35, 0.8), wrap_y=True, dry=0.75)
    for _ in range(40):
        y = ((0.75 + rng.normal(0, 0.12)) % 1.0) * H; x = rng.uniform(0, W); L = rng.uniform(100, 400)
        stroke(img, x, y, x + L, y + rng.normal(0, 2), 12, 6, C("0b0912"), 0.5, wrap_y=True, dry=0.5)
    save("sph_paint_cannon", img)

# ---------------------------------------------------------------------------------------------- steel (frame, bands)
def paint_steel():
    """Hubs, arms, bands: a cooler slate violet, short drips, some lighter dabs."""
    H, W = 256, 512
    img = base_fill(H, W, C("2a2840"), C("454262"), (3, 6), 33, streak=3)
    for _ in range(90):
        x = rng.uniform(0, W); y = rng.uniform(-10, H); L = rng.uniform(15, 90)
        col = C("14121f") if rng.random() < 0.6 else C("625e86")
        stroke(img, x, y, x + rng.normal(0, 1), y + L, rng.uniform(2, 6), 1.5, jitter(col, 0.05),
               rng.uniform(0.4, 0.8), wrap_y=True, dry=0.4)
    save("sph_paint_steel", img)

# ---------------------------------------------------------------------------------------------- star
def paint_star():
    """Planar on the faceplate (~4 m across): rust maroon, mottled, with radial strokes out along the points."""
    H = W = 512
    img = base_fill(H, W, C("3e1610"), C("62261a"), (5, 5), 41, streak=1)
    cx = cy = W / 2
    for _ in range(220):
        a = int(rng.integers(0, 4)) * 0.5 * math.pi + rng.normal(0, 0.12)
        r0 = rng.uniform(30, 160); r1 = r0 + rng.uniform(40, 120)
        col = C("7c3826") if rng.random() < 0.5 else C("2a0d09")
        stroke(img, cx + math.cos(a) * r0, cy + math.sin(a) * r0, cx + math.cos(a) * r1, cy + math.sin(a) * r1,
               rng.uniform(4, 12), 3, jitter(col, 0.06), rng.uniform(0.3, 0.7), wrap_y=True, dry=0.6)
    save("sph_paint_star", img)

# ---------------------------------------------------------------------------------------------- brush
def paint_brush():
    """Grey hatching (0.5 = neutral): short strokes in a few directions, tileable. Breaks the shadow edge."""
    H = W = 512
    img = np.full((H, W, 3), 0.5, np.float32)
    dirs = (0.2, 0.9, 2.1)
    for _ in range(900):
        x = rng.uniform(0, W); y = rng.uniform(0, H)
        a = dirs[int(rng.integers(0, 3))] + rng.normal(0, 0.15)
        L = rng.uniform(20, 70)
        v = float(rng.uniform(0.0, 1.0))
        stroke(img, x, y, x + math.cos(a) * L, y + math.sin(a) * L, rng.uniform(4, 10), 3, (v, v, v),
               rng.uniform(0.5, 0.9), wrap_y=True, dry=0.5)
    save("sph_paint_brush", img)

paint_hull()
paint_leg()
paint_cannon()
paint_steel()
paint_star()
paint_brush()
