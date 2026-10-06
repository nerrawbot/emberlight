extends Resource
## A scene's baked floor plan for the minimap (written by tools/bake_map.gd, loaded by scripts/minimap.gd).
## `heights` holds up to 4 walkable floors per texel, highest first in R, G, B, A:
## 0 = no floor, 1..255 = y_min .. y_min + y_span (Godot world Y).

@export var title := ""
## The wider area the scene is part of, shown above the title.
@export var region := ""
@export var heights: Texture2D
## World (x, z) of the texture's top-left corner; +x right, +z down the image.
@export var origin := Vector2.ZERO
## Metres per texel.
@export var texel := 0.25
@export var y_min := 0.0
@export var y_span := 1.0

func size_m() -> Vector2:
	return Vector2(heights.get_width(), heights.get_height()) * texel
