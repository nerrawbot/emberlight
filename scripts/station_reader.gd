extends "res://scripts/interactable.gd"
## v12: the pass reader on Patrol Station 4 (a child of patrol_station.gd, which does the checking).

func get_prompt() -> String:
	var st := get_parent()
	return str(st.call("reader_prompt")) if st and st.has_method("reader_prompt") else ""

func _on_interact(by: Node) -> void:
	var st := get_parent()
	if st and st.has_method("present"):
		st.call("present", by)