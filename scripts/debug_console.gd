extends CanvasLayer
## Playtest console. ` (backquote) or F1 opens it (the game pauses), Enter runs a line, Esc / ` closes it.
## Added to the player by player.gd. `help` lists the commands. Launch flag: `-- --boss` jumps straight to the
## Peak hall (as the `boss` command) on start-up.
##   tools\godot.cmd res://scenes/start.tscn -- --boss

const GameState := preload("res://scripts/game_state.gd")
const SCENES := {"start": "res://scenes/start.tscn", "main": "res://scenes/main.tscn", "surface": "res://scenes/surface.tscn"}
const HELP := """boss            surface, outside the Peak hall: weapon, drone, full health/shield, fresh boss
god             toggle: no damage
fly [speed]     toggle: free flight (Space up, Ctrl down, Shift x3); `fly 25` sets the speed
noclip          toggle: fly through walls
heal            full health + shield
weapon / drone  give the shaft / the warden drone (shield)
pennon          give the Pennon (glide: [Space] mid-air from 3 m up)
annex           boss already beaten, doors open: stand in the annex by the Pennon's plinth
station         stand in the cable car at the Peak's station (surface)
give <id> [n]   add an item (tokens, scrap, bars, voltaic_core, station_pass_sealed, station_pass)
tp <node>       stand on a node by name (CP_HallEntrance, AtMast, FromLift...)  |  tp <x> <y> <z>
pos             print your position
bosshp <pct>    set the boss's health % (runs its phase / seize-up checks; start the fight first)
fight           start the boss fight now (you must be on the surface)
kill            kill every hostile but the boss
scene <name>    start | main | surface
clear           clear this log"""

var player: CharacterBody3D
var _panel: PanelContainer
var _log: RichTextLabel
var _line: LineEdit
var _was_paused := false
var _history: PackedStringArray = []
var _hist_i := 0

func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_panel.visible = false
	var goto: Variant = GameState.take("debug_goto")
	if goto != null:
		_tp_node.call_deferred(str(goto))
	if OS.get_cmdline_user_args().has("--boss") and not GameState.get_value("debug_cli_done", false):
		GameState.set_value("debug_cli_done", true)
		_run.call_deferred("boss")

func _build() -> void:
	_panel = PanelContainer.new()
	_panel.anchor_right = 1.0
	_panel.offset_bottom = 300
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.04, 0.09, 0.88)
	sb.border_color = Color(0.45, 0.4, 0.7, 0.8)
	sb.border_width_bottom = 2
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	_panel.add_theme_stylebox_override("panel", sb)
	add_child(_panel)
	var vb := VBoxContainer.new()
	_panel.add_child(vb)
	_log = RichTextLabel.new()
	_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log.scroll_following = true
	_log.selection_enabled = true
	_log.add_theme_font_size_override("normal_font_size", 14)
	vb.add_child(_log)
	_line = LineEdit.new()
	_line.placeholder_text = "command (help)"
	_line.add_theme_font_size_override("font_size", 15)
	_line.text_submitted.connect(_on_submit)
	vb.add_child(_line)
	_print("[color=#a9a7c4]Debug console - type help[/color]")

func _input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var k := (event as InputEventKey).keycode
	if k == KEY_QUOTELEFT or k == KEY_F1 or (k == KEY_ESCAPE and _panel.visible):
		toggle()
		get_viewport().set_input_as_handled()
	elif _panel.visible and (k == KEY_UP or k == KEY_DOWN) and not _history.is_empty():
		_hist_i = clampi(_hist_i + (-1 if k == KEY_UP else 1), 0, _history.size())
		_line.text = _history[_hist_i] if _hist_i < _history.size() else ""
		_line.caret_column = _line.text.length()
		get_viewport().set_input_as_handled()

func toggle() -> void:
	_panel.visible = not _panel.visible
	if _panel.visible:
		_was_paused = get_tree().paused
		get_tree().paused = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_line.clear()
		_line.grab_focus()
	else:
		get_tree().paused = _was_paused
		_line.release_focus()
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _print(s: String) -> void:
	_log.append_text(s + "\n")

func _on_submit(text: String) -> void:
	_line.clear()
	text = text.strip_edges()
	if text == "":
		return
	_history.append(text)
	_hist_i = _history.size()
	_print("[color=#7a7498]> %s[/color]" % text)
	_run(text)

func _run(text: String) -> void:
	var a := text.split(" ", false)
	var cmd := a[0].to_lower()
	match cmd:
		"help":
			_print(HELP)
		"clear":
			_log.clear()
		"boss":
			_boss()
		"god":
			player.set("god", not player.get("god"))
			_print("god mode " + ("on" if player.get("god") else "off"))
		"fly", "noclip":
			if a.size() > 1:
				player.set("fly_speed", maxf(1.0, float(a[1])))
			var through := cmd == "noclip"
			var same: bool = player.get("flying") and player.get("noclip") == through
			var on := a.size() > 1 or not same
			player.call("set_flying", on, through)
			_print("%s on (speed %.0f)" % [cmd, float(player.get("fly_speed"))] if on else "%s off" % cmd)
		"heal":
			player.call("_set_health", float(player.get("max_health")))
			if player.get("has_drone"):
				player.call("_set_shield", float(player.get("shield_max")))
			_print("healed")
		"weapon":
			if not player.get("has_weapon"):
				player.call("give_weapon")
			_print("shaft in hand")
		"drone":
			if not player.get("has_drone"):
				player.call("give_drone")
			_print("drone + shield")
		"pennon":
			player.call("give_pennon")
			_print("Pennon in hand: [Space] mid-air from a height")
		"annex":
			_annex()
		"station":
			if get_tree().current_scene and get_tree().current_scene.find_child("CableStation", false, false):
				_tp_node("FromCableCar")
			else:
				GameState.take("car_ride")
				GameState.set_value("debug_goto", "FromCableCar")
				_change(SCENES["surface"])
		"give":
			if a.size() < 2:
				_print("give <id> [n]")
				return
			player.call("add_item", a[1], int(a[2]) if a.size() > 2 else 1)
			_print("gave %s" % a[1])
		"tp":
			if a.size() == 4:
				_put(Vector3(float(a[1]), float(a[2]), float(a[3])), player.rotation.y)
			elif a.size() == 2:
				_tp_node(a[1])
			else:
				_print("tp <node>  |  tp <x> <y> <z>")
		"pos":
			_print(str(player.global_position.snappedf(0.01)))
		"bosshp":
			_boss_hp(float(a[1]) if a.size() > 1 else 50.0)
		"fight":
			var f := _fight()
			if f:
				f.call("start_fight")
				_print("fight started")
		"kill":
			var n := 0
			for e in get_tree().get_nodes_in_group("enemies"):
				if e.has_method("die") and not e.has_method("is_down") and not e.get("dead"):
					e.call("die", true)
					n += 1
			_print("killed %d" % n)
		"scene":
			if a.size() < 2 or not SCENES.has(a[1]):
				_print("scene start | main | surface")
				return
			_change(SCENES[a[1]])
		_:
			_print("[color=#e06050]unknown: %s[/color] (help)" % cmd)

## Everything the Peak fight needs, a fresh boss, and the surface scene with you outside the hall's gate.
func _boss() -> void:
	GameState.merge({"has_weapon": true, "has_drone": true, "health": float(player.get("max_health")),
		"shield": float(player.get("shield_max")), "station_gate_open": true, "peak_boss_down": false})
	GameState.take("peak_boss_husk")
	GameState.take("car_ride")
	GameState.set_value("debug_goto", "CP_HallEntrance")
	_change(SCENES["surface"])

## After the fight: the Sphaeroid unpowered (husk in the middle), all doors open, the Pennon back on its plinth.
func _annex() -> void:
	GameState.merge({"has_weapon": true, "peak_boss_down": true, "has_pennon": false, "station_gate_open": true})
	GameState.take("peak_boss_husk")
	GameState.take("car_ride")
	GameState.set_value("debug_goto", "AnnexStand")
	_change(SCENES["surface"])

func _change(path: String) -> void:
	if _panel.visible:
		toggle()
	get_tree().paused = false
	get_tree().call_deferred("change_scene_to_file", path)

func _fight() -> Node:
	var f := get_tree().current_scene.get_node_or_null("PeakArena/BossFight") if get_tree().current_scene else null
	if f == null:
		_print("no boss fight in this scene (boss)")
	return f

func _boss_hp(pct: float) -> void:
	var f := _fight()
	var b: Node = f.get("boss") if f else null
	if b == null or not is_instance_valid(b):
		return
	if int(b.get("state")) == 0:
		_print("it's dormant: walk in or `fight` first")
		return
	# land one hit's worth above the target through take_hit, so phase 2 / the seize-up trigger as in play
	var mx := float(b.get("max_health"))
	var dmg := float(player.get("attack_damage"))
	b.set("health", clampf(mx * pct / 100.0 + dmg, 0.0, mx))
	b.call("take_hit", player, -player.global_basis.z)
	_print("boss health %.0f / %.0f" % [float(b.get("health")), mx])

func _tp_node(node_name: String) -> void:
	if node_name == "AnnexStand":         # just inside the annex doorway, facing the plinth
		var pk := get_tree().current_scene.find_child("PennonPickup", true, false) as Node3D if get_tree().current_scene else null
		if pk:
			var to_door := -pk.global_basis.z.normalized()      # the pickup faces the doorway
			_put(pk.global_position + to_door * 1.3 + Vector3(0, -0.85, 0), pk.global_rotation.y + PI)
			player.set("spawn_transform", player.global_transform)
			_print("in the annex")
			return
	var n := get_tree().current_scene.find_child(node_name, true, false) as Node3D if get_tree().current_scene else null
	if n == null:
		_print("no node named %s here" % node_name)
		return
	_put(n.global_position + Vector3.UP * 0.1, n.global_rotation.y)
	player.set("spawn_transform", player.global_transform)
	_print("at %s" % node_name)

func _put(at: Vector3, yaw: float) -> void:
	player.global_transform = Transform3D(Basis(Vector3.UP, yaw), at)
	player.velocity = Vector3.ZERO
	if player.has_method("reset_fall"):
		player.call("reset_fall")
