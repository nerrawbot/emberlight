extends Node
## Debug helper: run the project with `-- --shots` to render a fixed camera tour into res://shots and quit.
## `-- --walktest` runs tools/walk_test.gd instead.

const SHOTS := [
	{"pos": Vector3(3, 18.05, -1.5), "yaw": -90.0, "pitch": -4.0},
	{"pos": Vector3(-8.6, 1.62, 8.7), "yaw": -90.0, "pitch": -2.0},
	{"pos": Vector3(9.0, 1.62, 9.6), "yaw": 80.0, "pitch": 4.0},
	{"pos": Vector3(12, 18.05, -2.6), "yaw": 15.0, "pitch": 28.0},
	{"pos": Vector3(24, 23.45, -7.3), "yaw": -92.0, "pitch": -4.0},
	{"pos": Vector3(34, 25.05, -6.7), "yaw": -143.0, "pitch": -4.0},
	{"pos": Vector3(36.5, 0.3, -1.0), "yaw": -61.0, "pitch": -6.0},
	{"pos": Vector3(31, 0.2, 2.0), "yaw": -75.0, "pitch": 3.0},
	{"pos": Vector3(68.8, 19.05, -1.0), "yaw": -80.0, "pitch": 4.0},
	{"pos": Vector3(31, 0.2, 2.0), "yaw": -75.0, "pitch": 3.0, "power": true},
	{"pos": Vector3(13.5, 18.05, 2.6), "yaw": -95.0, "pitch": 8.0, "power": true},
	{"pos": Vector3(55, 19.05, -3.2), "yaw": 12.0, "pitch": 12.0, "power": true},
	{"pos": Vector3(68.8, 19.05, -1.0), "yaw": -80.0, "pitch": 4.0, "power": true},
	{"pos": Vector3(29.5, 34.35, 5.5), "yaw": 55.0, "pitch": 10.0, "power": true},
	{"pos": Vector3(30.5, 34.35, -3.2), "yaw": -90.0, "pitch": -8.0, "power": true},
	{"pos": Vector3(21.0, 18.05, 9.0), "yaw": 0.0, "pitch": 55.0, "power": true},
]

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	# the test lives on the root so it survives scene changes (start.tscn -> main.tscn)
	if "--walktest" in args and ResourceLoader.exists("res://tools/walk_test.gd") and not get_tree().root.has_node("WalkTest"):
		var t := Node.new()
		t.name = "WalkTest"
		t.set_script(load("res://tools/walk_test.gd"))
		get_tree().root.add_child.call_deferred(t)
	if "--enemytest" in args and ResourceLoader.exists("res://tools/enemy_test.gd") and not get_tree().root.has_node("EnemyTest"):
		var et := Node.new()
		et.name = "EnemyTest"
		et.set_script(load("res://tools/enemy_test.gd"))
		get_tree().root.add_child.call_deferred(et)
	if not "--shots" in args or get_parent().name != "Main":
		queue_free()
		return
	_run.call_deferred()

func _run() -> void:
	var player = get_tree().get_first_node_in_group("player")
	player.input_enabled = false
	player.set_physics_process(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var dir := ProjectSettings.globalize_path("res://shots")
	DirAccess.make_dir_recursive_absolute(dir)
	for i in SHOTS.size():
		var s: Dictionary = SHOTS[i]
		if s.get("power", false):
			get_tree().get_first_node_in_group("power_grid").set_powered(true)
		player.global_position = s.pos
		player.rotation = Vector3(0, deg_to_rad(s.yaw), 0)
		player.get_node("Head").rotation = Vector3(deg_to_rad(s.pitch), 0, 0)
		for f in 150:
			await get_tree().process_frame
		var img := get_viewport().get_texture().get_image()
		img.save_png(dir.path_join("shot_%02d.png" % i))
		print("saved shot ", i)
	for f in get_tree().current_scene.get_node("Lights/Floodlights").get_children():
		print("flood ", f.name, " vis=", f.visible, " e=", f.light_energy)
	get_tree().quit()
