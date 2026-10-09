extends RefCounted
## Drawing helpers for the "industrial relic" UI (inventory_panel.gd): hexagons, chamfered plates with brushy rough
## edges, dry-brush outlines, hex bolts, hazard stripes, and the two scene palettes. No rounded corners anywhere.

const BRUSH := preload("res://assets/creatures/sph_paint_brush.png")

# cool steel + lilac down in the caverns, gold + rust up on the surface
const CAVERN := {
	"ink": Color(0.03, 0.035, 0.062), "ink2": Color(0.075, 0.08, 0.125), "metal": Color(0.36, 0.4, 0.54),
	"accent": Color(0.66, 0.7, 0.95), "glow": Color(0.62, 0.76, 1.0), "hazard": Color(0.78, 0.6, 0.32),
	"text": Color(0.9, 0.89, 0.86), "dim": Color(0.54, 0.56, 0.66), "faint": Color(0.4, 0.42, 0.52),
}
const SURFACE := {
	"ink": Color(0.06, 0.045, 0.035), "ink2": Color(0.13, 0.095, 0.07), "metal": Color(0.56, 0.42, 0.28),
	"accent": Color(0.96, 0.76, 0.44), "glow": Color(1.0, 0.82, 0.5), "hazard": Color(0.74, 0.3, 0.17),
	"text": Color(0.96, 0.91, 0.81), "dim": Color(0.68, 0.61, 0.52), "faint": Color(0.5, 0.44, 0.37),
}

static func palette_for(scene_path: String) -> Dictionary:
	return SURFACE if scene_path.contains("surface") else CAVERN

static func hash1(x: float) -> float:
	return fract(sin(x * 127.1 + 311.7) * 43758.5453)

static func fract(x: float) -> float:
	return x - floor(x)

## flat-topped hexagon (points at left / right)
static func hex(c: Vector2, r: float, rot := 0.0) -> PackedVector2Array:
	var p := PackedVector2Array()
	for i in 6:
		var a := rot + TAU * i / 6.0
		p.append(c + Vector2(cos(a), sin(a)) * r)
	return p

## largest flat-topped hexagon that fits a size
static func hex_radius(s: Vector2) -> float:
	return minf(s.x * 0.5, s.y / 1.7320508)

## rect with cut corners: cuts = [top-left, top-right, bottom-right, bottom-left]
static func chamfer(r: Rect2, cuts: Array) -> PackedVector2Array:
	var a := r.position
	var b := r.end
	return PackedVector2Array([
		Vector2(a.x + cuts[0], a.y), Vector2(b.x - cuts[1], a.y), Vector2(b.x, a.y + cuts[1]),
		Vector2(b.x, b.y - cuts[2]), Vector2(b.x - cuts[2], b.y), Vector2(a.x + cuts[3], b.y),
		Vector2(a.x, b.y - cuts[3]), Vector2(a.x, a.y + cuts[0])])

## resample a closed polygon every `step` px, nudging points along the edge normal (a hand-cut, brushy edge)
static func rough(pts: PackedVector2Array, step: float, amp: float, seed: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	var n := pts.size()
	var k := 0.0
	for i in n:
		var p0 := pts[i]
		var p1 := pts[(i + 1) % n]
		var e := p1 - p0
		var steps := maxi(1, int(e.length() / step))
		var nrm := Vector2(e.y, -e.x).normalized()
		for s in steps:
			k += 1.0
			var j := 0.0 if s == 0 else (hash1(k + seed) - 0.5) * 2.0 * amp
			out.append(p0 + e * (float(s) / steps) + nrm * j)
	return out

static func closed(pts: PackedVector2Array) -> PackedVector2Array:
	var c := pts.duplicate()
	c.append(pts[0])
	return c

## the polygon filled with a vertical gradient, then the brush map laid over it (needs texture_repeat on the item)
static func painted_fill(ci: CanvasItem, pts: PackedVector2Array, top: Color, bottom: Color, grain: Color, uv_scale := 1.0 / 300.0) -> void:
	var y0 := INF
	var y1 := -INF
	for p in pts:
		y0 = minf(y0, p.y)
		y1 = maxf(y1, p.y)
	var cols := PackedColorArray()
	var uvs := PackedVector2Array()
	for p in pts:
		cols.append(top.lerp(bottom, (p.y - y0) / maxf(1.0, y1 - y0)))
		uvs.append(p * uv_scale)
	ci.draw_polygon(pts, cols)
	if grain.a > 0.0:
		ci.draw_colored_polygon(pts, grain, uvs, BRUSH)

## an outline as if dragged with a dry brush: the main stroke and two faint offset passes
static func dry_outline(ci: CanvasItem, pts: PackedVector2Array, col: Color, width: float, seed: float) -> void:
	var c := closed(pts)
	ci.draw_polyline(c, col, width)
	for k in 2:
		var off := Vector2(hash1(seed + k * 3.1) - 0.5, hash1(seed + k * 7.7) - 0.5) * 2.4
		var shifted := PackedVector2Array()
		for p in c:
			shifted.append(p + off)
		ci.draw_polyline(shifted, Color(col, col.a * 0.3), maxf(1.0, width * 0.7))

## a hex bolt head
static func bolt(ci: CanvasItem, c: Vector2, r: float, metal: Color) -> void:
	ci.draw_colored_polygon(hex(c + Vector2(0.8, 1.2), r), Color(0, 0, 0, 0.55))
	ci.draw_colored_polygon(hex(c, r, 0.3), metal.darkened(0.35))
	ci.draw_colored_polygon(hex(c + Vector2(-0.4, -0.5), r * 0.55, 0.3), metal.lightened(0.15))

## diagonal hazard stripes in a rect (parallelograms, clipped to the rect's height)
static func hazard(ci: CanvasItem, r: Rect2, a: Color, b: Color, w := 7.0) -> void:
	ci.draw_rect(r, b)
	var h := r.size.y
	var x := r.position.x - h
	var i := 0
	while x < r.end.x:
		if i % 2 == 0:
			var x0 := maxf(x, r.position.x)
			var p := PackedVector2Array([Vector2(x + h, r.position.y), Vector2(x + h + w, r.position.y),
				Vector2(x + w, r.end.y), Vector2(x, r.end.y)])
			for k in p.size():
				p[k].x = clampf(p[k].x, r.position.x, r.end.x)
			if x0 < r.end.x:
				ci.draw_colored_polygon(p, a)
		x += w
		i += 1
