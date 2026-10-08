extends SceneTree
## v18: draws the surface's decal textures procedurally into res://assets/decals/*.png (stains, leaks, worn hazard
## stripes, stencilled codes, posters, arrows); tools/bake_decals.gd sticks them on the works' walls.
## tools\godot.cmd --headless --script res://tools/make_decals.gd   (then --import)

const DIR := "res://assets/decals/"
const RUST := Color(0.36, 0.19, 0.11)
const SOOT := Color(0.11, 0.09, 0.11)
const DAMP := Color(0.16, 0.19, 0.12)
const PAINT_RED := Color(0.52, 0.16, 0.12)
const PAINT_CREAM := Color(0.86, 0.81, 0.68)
const HAZ_YELLOW := Color(0.82, 0.64, 0.16)
const STENCIL_WHITE := Color(0.88, 0.86, 0.8)

## 5x7 glyphs (rows top -> bottom, "#" = on)
const FONT := {
	"0": [".###.", "#...#", "#..##", "#.#.#", "##..#", "#...#", ".###."],
	"1": ["..#..", ".##..", "..#..", "..#..", "..#..", "..#..", ".###."],
	"2": [".###.", "#...#", "....#", "...#.", "..#..", ".#...", "#####"],
	"3": ["####.", "....#", "....#", ".###.", "....#", "....#", "####."],
	"4": ["...#.", "..##.", ".#.#.", "#..#.", "#####", "...#.", "...#."],
	"5": ["#####", "#....", "####.", "....#", "....#", "#...#", ".###."],
	"6": [".###.", "#....", "#....", "####.", "#...#", "#...#", ".###."],
	"7": ["#####", "....#", "...#.", "..#..", ".#...", ".#...", ".#..."],
	"8": [".###.", "#...#", "#...#", ".###.", "#...#", "#...#", ".###."],
	"9": [".###.", "#...#", "#...#", ".####", "....#", "....#", ".###."],
	"A": [".###.", "#...#", "#...#", "#####", "#...#", "#...#", "#...#"],
	"B": ["####.", "#...#", "#...#", "####.", "#...#", "#...#", "####."],
	"C": [".###.", "#...#", "#....", "#....", "#....", "#...#", ".###."],
	"D": ["####.", "#...#", "#...#", "#...#", "#...#", "#...#", "####."],
	"E": ["#####", "#....", "#....", "####.", "#....", "#....", "#####"],
	"K": ["#...#", "#..#.", "#.#..", "##...", "#.#..", "#..#.", "#...#"],
	"L": ["#....", "#....", "#....", "#....", "#....", "#....", "#####"],
	"N": ["#...#", "##..#", "#.#.#", "#..##", "#...#", "#...#", "#...#"],
	"O": [".###.", "#...#", "#...#", "#...#", "#...#", "#...#", ".###."],
	"P": ["####.", "#...#", "#...#", "####.", "#....", "#....", "#...."],
	"R": ["####.", "#...#", "#...#", "####.", "#.#..", "#..#.", "#...#"],
	"S": [".####", "#....", "#....", ".###.", "....#", "....#", "####."],
	"T": ["#####", "..#..", "..#..", "..#..", "..#..", "..#..", "..#.."],
	"Y": ["#...#", "#...#", ".#.#.", "..#..", "..#..", "..#..", "..#.."],
	"-": [".....", ".....", ".....", "#####", ".....", ".....", "....."],
	" ": [".....", ".....", ".....", ".....", ".....", ".....", "....."],
}

var noise := FastNoiseLite.new()
var rng := RandomNumberGenerator.new()

func _initialize() -> void:
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.fractal_octaves = 4
	rng.seed = 18
	DirAccess.make_dir_recursive_absolute(DIR)
	_save(_stain(256, SOOT, 1), "stain_soot")
	_save(_stain(256, RUST, 2), "stain_rust")
	_save(_stain(256, DAMP, 3), "stain_damp")
	_save(_leak(128, 512, RUST, 4), "leak_rust")
	_save(_leak(128, 512, SOOT, 5), "leak_soot")
	_save(_hazard(512, 128, 6), "hazard")
	for code in ["B2", "K9", "04", "17", "C3", "NO ENTRY", "KEEP CLEAR"]:
		_save(_stencil(code, STENCIL_WHITE if code.length() < 4 else PAINT_RED, 10 + code.length()), "stencil_" + code.to_lower().replace(" ", "_"))
	_save(_poster(256, 360, PAINT_RED, 20), "poster_red")
	_save(_poster(256, 360, Color(0.22, 0.3, 0.42), 21), "poster_blue")
	_save(_arrow(256, 128, HAZ_YELLOW, 22), "arrow")
	quit()

func _save(img: Image, n: String) -> void:
	img.save_png(DIR + n + ".png")
	print("decal ", n, " ", img.get_size())

func _n(x: float, y: float, f: float, sd: int) -> float:
	noise.seed = sd
	noise.frequency = f
	return noise.get_noise_2d(x, y) * 0.5 + 0.5

## soft, ragged blotch fading out from the middle
func _stain(s: int, col: Color, sd: int) -> Image:
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	for y in s:
		for x in s:
			var d := Vector2(x - s / 2.0, y - s / 2.0).length() / (s / 2.0)
			var n := _n(x, y, 0.02, sd)
			var fine := _n(x, y, 0.09, sd + 100)
			var a := clampf((1.0 - d * (0.9 + n * 0.7)) * 2.2, 0.0, 1.0) * (0.55 + 0.45 * fine)
			a *= smoothstep(0.3, 0.6, n + 0.25 * (1.0 - d))
			img.set_pixel(x, y, Color(col.r * (0.8 + 0.4 * fine), col.g * (0.8 + 0.4 * fine), col.b, a * 0.85))
	return img

## drips running down from a source at the top: dense under it, thinning and narrowing lower down
func _leak(w: int, h: int, col: Color, sd: int) -> Image:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var drips := []
	for k in 9:
		drips.append([rng.randf_range(0.2, 0.8) * w, rng.randf_range(0.35, 1.0) * h, rng.randf_range(2.0, 7.0)])
	for y in h:
		var t := float(y) / h
		for x in w:
			var a := clampf(1.0 - Vector2((x - w / 2.0) / (w * 0.42), y / (h * 0.12)).length(), 0.0, 1.0) * 0.9
			for d in drips:
				if y < d[1]:
					var wob: float = (_n(y, d[0], 0.03, sd) - 0.5) * 10.0
					var wd: float = d[2] * (1.0 - 0.6 * t)
					var dist: float = absf(x - d[0] - wob)
					var fade: float = 1.0 - smoothstep(d[1] * 0.6, d[1], y)
					a = maxf(a, clampf(1.0 - dist / wd, 0.0, 1.0) * fade * 0.8)
			a *= 0.6 + 0.4 * _n(x, y, 0.08, sd + 7)
			img.set_pixel(x, y, Color(col.r, col.g, col.b, a))
	return img

## worn diagonal yellow/black band: paint chipped by noise
func _hazard(w: int, h: int, sd: int) -> Image:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var stripe := fmod(float(x + y) / 64.0, 1.0) < 0.5
			var c: Color = HAZ_YELLOW if stripe else Color(0.08, 0.07, 0.07)
			var wear := _n(x, y, 0.025, sd) * 0.7 + _n(x, y, 0.12, sd + 1) * 0.3
			var edge := minf(minf(x, w - 1 - x), minf(y, h - 1 - y)) / 10.0
			var a := smoothstep(0.38, 0.5, wear) * clampf(edge, 0.0, 1.0)
			img.set_pixel(x, y, Color(c.r * (0.85 + 0.3 * wear), c.g * (0.85 + 0.3 * wear), c.b, a * 0.95))
	return img

## stencilled code: blocky glyph cells with stencil gaps, worn
func _stencil(text: String, col: Color, sd: int) -> Image:
	var cell := 12
	var gw := 6 * cell
	var w := int(text.length() * gw + cell * 2)
	var h := 9 * cell
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(col.r, col.g, col.b, 0.0))
	for i in text.length():
		var g: Array = FONT.get(text[i], FONT[" "])
		for r in 7:
			for c in 5:
				if g[r][c] != "#":
					continue
				var x0 := cell + i * gw + c * cell
				var y0 := cell + r * cell
				for y in range(y0 + 1, y0 + cell - 1):
					for x in range(x0 + 1, x0 + cell - 1):
						var wear := _n(x, y, 0.05, sd) * 0.6 + _n(x, y, 0.2, sd + 3) * 0.4
						img.set_pixel(x, y, Color(col.r, col.g, col.b, smoothstep(0.3, 0.45, wear) * 0.9))
	return img

## faded notice poster: paper, colour band, emblem, text lines, torn corner, stains
func _poster(w: int, h: int, band: Color, sd: int) -> Image:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var tear := rng.randf_range(0.18, 0.32)
	for y in h:
		for x in w:
			var u := float(x) / w
			var v := float(y) / h
			var c := PAINT_CREAM
			if v > 0.06 and v < 0.2 and u > 0.06 and u < 0.94:
				c = band
			var dc := Vector2(u - 0.5, (v - 0.45) * h / w).length()
			if dc < 0.2 and dc > 0.13:
				c = band
			elif dc < 0.08:
				c = band.darkened(0.3)
			if v > 0.68 and v < 0.92 and u > 0.1 and u < 0.9 and fmod(v * 40.0, 1.6) < 0.7 and _n(x, y * 0.2, 0.08, sd + 5) > 0.35:
				c = Color(0.18, 0.15, 0.15)
			var stain := _n(x, y, 0.015, sd)
			c = c.lerp(Color(0.45, 0.38, 0.28), smoothstep(0.55, 0.85, stain) * 0.7)
			var a := 1.0
			if u + v * 0.6 > 1.6 - tear + (_n(x, y, 0.1, sd + 9) - 0.5) * 0.08:
				a = 0.0          # torn corner (bottom right)
			var edge := minf(minf(u, 1.0 - u), minf(v, 1.0 - v))
			a *= smoothstep(0.0, 0.015 + 0.02 * _n(x, y, 0.2, sd + 2), edge)
			a *= 0.75 + 0.25 * _n(x, y, 0.05, sd + 4)
			img.set_pixel(x, y, Color(c.r * 0.85, c.g * 0.85, c.b * 0.85, a))
	return img

## painted direction arrow
func _arrow(w: int, h: int, col: Color, sd: int) -> Image:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var u := float(x) / w
			var v := float(y) / h - 0.5
			var on := (u > 0.08 and u < 0.62 and absf(v) < 0.14) or (u >= 0.6 and u < 0.92 and absf(v) < (0.92 - u) * 1.3)
			var wear := _n(x, y, 0.06, sd) * 0.7 + _n(x, y, 0.25, sd + 1) * 0.3
			img.set_pixel(x, y, Color(col.r, col.g, col.b, (0.9 if on else 0.0) * smoothstep(0.32, 0.46, wear)))
	return img