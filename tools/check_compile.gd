extends SceneTree
## Compile check: loads every script passed (or all of scripts/ + tools/) and reports the ones that fail.
##   tools\godot.cmd --headless --script res://tools/check_compile.gd [-- res://scripts/a.gd ...]

func _init() -> void:
	var paths: Array[String] = []
	for a in OS.get_cmdline_user_args():
		paths.append(a)
	if paths.is_empty():
		for d in ["res://scripts", "res://scripts/creatures", "res://scripts/dialogue", "res://tools"]:
			for f in DirAccess.get_files_at(d):
				if f.ends_with(".gd"):
					paths.append(d + "/" + f)
	var bad := 0
	for p in paths:
		var s := load(p) as Script
		if s == null or not s.can_instantiate():
			bad += 1
			print("FAIL ", p)
	print("check_compile: %d scripts, %d failed" % [paths.size(), bad])
	quit(1 if bad > 0 else 0)