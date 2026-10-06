extends RefCounted
## Cross-scene state (weapon, health, grid power, gates, lift hand-over). Kept as metadata on the
## scene-tree root, like the spawn_point hand-over in exit_zone.gd, so it survives change_scene_to_file()
## without needing an autoload. Use it through a preload:
##   const GameState := preload("res://scripts/game_state.gd")
##   GameState.get_value("has_weapon", false)

static func _store() -> Dictionary:
	var root := (Engine.get_main_loop() as SceneTree).root
	if not root.has_meta("game_state"):
		root.set_meta("game_state", {})
	return root.get_meta("game_state")

static func get_value(key: String, default: Variant = null) -> Variant:
	return _store().get(key, default)

static func set_value(key: String, value: Variant) -> void:
	_store()[key] = value

## Read a one-shot hand-over value and clear it.
static func take(key: String, default: Variant = null) -> Variant:
	var s := _store()
	var v: Variant = s.get(key, default)
	s.erase(key)
	return v

static func merge(values: Dictionary) -> void:
	_store().merge(values, true)
