extends RefCounted
## Item table for the inventory (player.gd add_item/item_count/use_item, GameState "items": {id: count}).
## Tokens are the currency; the rest are key items, valuables (sellable: `value` in tokens) and materials.
## Used by the pickup feed, the [I] panel, supply crates and mob drops (pass_drop.gd).
## Icons: `abbr` + `color` draw a placeholder tile in the panel until assets/icons/<id>.png exists (picked up
## automatically by icon_texture()).

const INFO := {
	"tokens": {"name": "Token", "plural": "Tokens", "color": Color(1.0, 0.82, 0.42), "kind": "currency", "abbr": "Tk",
		"desc": "Works scrip, stamped brass. Still good, somewhere."},
	"scrap": {"name": "Scrap", "plural": "Scrap", "color": Color(0.72, 0.75, 0.8), "kind": "material", "abbr": "Sc",
		"desc": "Bent plate, bolts, offcuts."},
	"bars": {"name": "Bar", "plural": "Bars", "color": Color(0.92, 0.62, 0.38), "kind": "material", "abbr": "Br",
		"desc": "Refined bar stock from the old foundry. Rare."},
	"voltaic_core": {"name": "Voltaic core", "plural": "Voltaic cores", "color": Color(0.55, 0.88, 1.0), "kind": "material",
		"abbr": "VC", "desc": "A sealed cell. It hums faintly against your palm."},
	# v12: station passes. The first pass a mob gives up (the 6th spawned mob you beat) is the sealed one, a key item
	# the Peak bridge checkpoint honours (patrol_station.gd). Later drops (7.5% a kill) are plain passes, to sell.
	"station_pass_sealed": {"name": "Sealed station pass", "plural": "Sealed station passes", "color": Color(1.0, 0.72, 0.34),
		"kind": "key", "abbr": "SP",
		"desc": "A relay-station pass under an unbroken wax seal, countersigned by a warden. The checkpoint on the Peak bridge will honour it."},
	"station_pass": {"name": "Station pass", "plural": "Station passes", "color": Color(0.74, 0.84, 0.92),
		"kind": "valuable", "abbr": "SP", "value": 25,
		"desc": "A relay-station pass, its seal long broken. Void at the checkpoint, but someone will still pay for it."},
}

## Panel sections, in order. The weapon and the companion have their own column (inventory_panel.gd).
const KEY_ITEMS := ["station_pass_sealed"]
const VALUABLES := ["station_pass"]
const MATERIALS := ["scrap", "bars", "voltaic_core"]

static func label(id: String, n: int) -> String:
	var i: Dictionary = INFO.get(id, {})
	if i.is_empty():
		return id
	return str(i["name"] if n == 1 else i["plural"])

static func color(id: String) -> Color:
	return INFO.get(id, {}).get("color", Color(0.85, 0.85, 0.85))

static func kind(id: String) -> String:
	return str(INFO.get(id, {}).get("kind", "material"))

static func abbr(id: String) -> String:
	return str(INFO.get(id, {}).get("abbr", "?"))

## A real icon once one is dropped into assets/icons/, else null (the panel draws the placeholder tile).
static func icon_texture(id: String) -> Texture2D:
	var p := "res://assets/icons/%s.png" % id
	if ResourceLoader.exists(p):
		return load(p) as Texture2D
	return null