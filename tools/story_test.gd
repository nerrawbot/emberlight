extends SceneTree
## v11 checks: the watchers' dialogue, supply crates (pry / smash / loot), the drone's voltaic-core repair.
##   tools\godot.cmd --headless --script res://tools/story_test.gd
## Starts in main.tscn (SENTINEL-07), then surface.tscn. Prints PASS/FAIL per check and a total.

const GameState := preload("res://scripts/game_state.gd")

var fails := 0
var checks := 0

func _initialize() -> void:
	create_timer(300.0).timeout.connect(func():
		print("story_test: TIMED OUT after %d checks" % checks)
		quit(1))
	_run()

func ok(label: String, cond: bool) -> void:
	checks += 1
	if not cond:
		fails += 1
	print("%s  %s" % ["PASS" if cond else "FAIL", label])

func frames(n: int) -> void:
	for i in n:
		await physics_frame

func secs(t: float) -> void:
	await create_timer(t).timeout

func load_scene(path: String) -> Node:
	var before := current_scene
	change_scene_to_file(path)
	for i in 600:
		await process_frame
		if current_scene and current_scene != before and get_first_node_in_group("player"):
			break
	await frames(6)
	return current_scene

## Stand the player `dist` m from `target` (on its floor) looking at `look_y` above it; return what the ray picks.
func face(p: Node3D, target: Node3D, dist: float, look_y: float, from_dir := Vector3(0, 0, -1)) -> Node:
	var at := target.global_position + from_dir.normalized() * dist
	p.global_position = at
	p.velocity = Vector3.ZERO
	var aim := target.global_position + Vector3.UP * look_y
	var eye := at + Vector3.UP * 1.62
	var d := aim - eye
	p.rotation.y = atan2(-d.x, -d.z)
	(p.get_node("Head") as Node3D).rotation.x = atan2(d.y, Vector2(d.x, d.z).length())
	await frames(3)
	return p.call("_get_interactable")

## Click through a dialogue: [E] on every line, choosing `picks` in order when choices come up.
func talk(box: Node, picks: Array) -> Array:
	var seen := []
	var guard := 0
	while box.get("active") and guard < 80:
		guard += 1
		var ch: Array = box.get("_choices")
		if not ch.is_empty():
			seen.append(ch.map(func(c): return str(c["text"])))
			if picks.is_empty():
				box.call("stop")
				break
			box.call("_pick", int(picks.pop_front()))
		else:
			box.call("_advance")     # finish the typing
			box.call("_advance")     # next line
		await process_frame
	return seen

func _run() -> void:
	# ---------------------------------------------------------------- main.tscn: SENTINEL-07
	var main := await load_scene("res://scenes/main.tscn")
	var p := get_first_node_in_group("player") as Node3D
	p.set("input_enabled", false)
	var w7 := main.get_node("Creatures/Watchers/Watcher_00") as Node3D
	var hit := await face(p, w7, 1.6, 0.4, w7.global_transform.basis.z * -1.0)
	ok("main: the ray finds SENTINEL-07's Talk area", hit != null and hit.name == "Talk")
	p.set("input_enabled", true)
	if hit:
		hit.call("interact", p)
	var box := p.get("_dialogue") as Node
	ok("main: [E] opens the dialogue box", box != null and box.get("active") and box.visible)
	ok("main: the watcher locks on while talking", w7.get("talking") == true)
	ok("main: player can't move while talking", p.get("input_enabled") == false)
	await talk(box, [])
	await secs(0.2)
	ok("main: talk ends, control returns", not box.get("active") and p.get("input_enabled") == true and w7.get("talking") == false)
	ok("main: met_watcher_07 set", GameState.get_value("met_watcher_07", false) == true)
	p.call("start_dialogue", "sentinel_07", "SENTINEL-07", null)
	var seen: Array = await talk(box, [1])
	ok("main: second talk offers the repeat menu", seen.size() == 1 and (seen[0] as Array).size() == 2)
	await secs(0.2)

	# ---------------------------------------------------------------- surface.tscn
	var surf := await load_scene("res://scenes/surface.tscn")
	p = get_first_node_in_group("player") as Node3D
	box = p.get("_dialogue") as Node
	var loot := surf.get_node("Loot")
	ok("surface: 16 crates", loot.get_child_count() == 16)
	var cores := 0
	for c in loot.get_children():
		cores += int(c.get("voltaic_core"))
	ok("surface: 5 voltaic cores in crates", cores == 5)
	ok("surface: the Lookout banner is gone", surf.get_node_or_null("Lookout") == null)

	# pry: the lift-landing crate
	var c1 := loot.get_node("Crate_LiftLanding") as Node3D
	hit = await face(p, c1, 1.4, 0.3, -c1.global_transform.basis.z)
	ok("surface: the ray finds a crate", hit == c1)
	ok("surface: crate prompt", str(c1.call("get_prompt")) == "Pry the crate open")
	c1.call("interact", p)
	await secs(1.6)
	ok("surface: pried crate pays out (12 tokens, 2 scrap)", p.call("item_count", "tokens") == 12 and p.call("item_count", "scrap") == 2)
	var lid := c1.get("_lid") as Node3D
	ok("surface: the lid swings open", lid != null and lid.rotation.x > 1.5)
	ok("surface: an opened crate has no prompt", str(c1.call("get_prompt")) == "")
	c1.call("interact", p)
	await secs(1.0)
	ok("surface: a pried crate pays out only once", p.call("item_count", "tokens") == 12)
	var feed := p.get("_feed") as Node
	ok("surface: pickup popups shown", feed != null and feed.get_child_count() >= 2)

	# smash: the block C crate (a core)
	var c2 := loot.get_node("Crate_BlockC") as Node3D
	await face(p, c2, 1.6, 0.3, -c2.global_transform.basis.z)
	p.call("give_weapon", true)
	p.set("_attack_cd", 0.0)
	var swung: bool = await p.call("attack")
	ok("surface: the shaft hits the crate", swung)
	await secs(0.3)
	ok("surface: the smashed crate bursts into its panels", c2.get_node("Model").find_children("*", "MeshInstance3D", true, false).is_empty())
	await secs(1.5)
	ok("surface: smashed crate pays out (core + 6 tokens)", p.call("item_count", "voltaic_core") == 1 and p.call("item_count", "tokens") == 18)
	await secs(2.0)
	ok("surface: the smashed crate is gone", not is_instance_valid(c2))
	ok("surface: opened crates remembered", (GameState.get_value("opened_crates", {}) as Dictionary).size() == 2)

	# inventory panel
	var inv := p.get("_inventory") as Control
	inv.call("toggle")
	await process_frame
	var txt := ""
	for l in inv.find_children("*", "Label", true, false):
		txt += (l as Label).text + "\n"
	ok("surface: [I] panel shows weapon, tokens, materials", inv.visible and "Steel shaft" in txt and "18" in txt and "Voltaic core" in txt and "Scrap" in txt)
	ok("surface: [I] pauses the game", paused)
	inv.call("toggle")
	ok("surface: closing [I] unpauses", not paused and not inv.visible)

	# the drone, before the hint
	var drone := surf.get_node("DronePickup")
	ok("surface: drone prompt doesn't name cores", str(drone.call("get_prompt")) == "Inspect the broken drone")
	drone.call("interact", p)
	await secs(0.3)
	ok("surface: inspecting the drone sets drone_inspected", GameState.get_value("drone_inspected", false) == true)
	ok("surface: one core doesn't repair it", not GameState.get_value("has_drone", false) and p.call("item_count", "voltaic_core") == 1)

	# SENTINEL-09: greet (no relay? - met_watcher_07 is set from main), hub with the drone topic
	var w9 := surf.get_node("SiloWatcher") as Node3D
	hit = await face(p, w9, 1.6, 0.4, Vector3(0, 0, -1))
	ok("surface: the ray finds SENTINEL-09", hit != null and hit.name == "Talk")
	if hit:
		hit.call("interact", p)
	seen = await talk(box, [2, 3])         # the drone topic, then [Leave] (index after the drone topic is gone? no: still shown)
	ok("surface: hub offers the drone topic after inspecting it", seen.size() >= 1 and "The broken drone on the tower..." in (seen[0] as Array))
	ok("surface: drone topic gives the hint", GameState.get_value("drone_hint", false) == true)
	await secs(0.2)
	GameState.set_value("met_watcher_09", true)

	# repair with 3 cores
	p.call("add_item", "voltaic_core", 2)
	ok("surface: with 3 cores the prompt offers the repair", "voltaic cores" in str(drone.call("get_prompt")))
	drone.call("interact", p)
	await secs(3.0)
	ok("surface: the drone is repaired and joins", GameState.get_value("has_drone", false) == true and p.get("has_drone") == true)
	ok("surface: the 3 cores are used up", p.call("item_count", "voltaic_core") == 0)
	p.call("start_dialogue", "sentinel_09", "SENTINEL-09", null)
	seen = await talk(box, [])
	ok("surface: hub swaps the drone topic for 'The drone flies again.'", seen.size() == 1 and "The drone flies again." in (seen[0] as Array) and not ("The broken drone on the tower..." in (seen[0] as Array)))

	await _station_and_passes(surf, p)
	print("story_test: %d checks, %d fails" % [checks, fails])

## v12: pass drops from spawned mobs (6th kill = the sealed pass, then pass_chance), Patrol Station 4, the [I] sections.
func _station_and_passes(surf: Node, p: CharacterBody3D) -> void:
	var spawner := surf.get_node("Enemies")
	spawner.set("enabled", false)
	for e in spawner.get_children():
		e.queue_free()
	await frames(2)
	GameState.set_value("mob_kills", 0)
	var st := surf.get_node("PatrolStation") as Node3D
	var fwd := -st.global_transform.basis.z          # out along the bridge
	var before := st.global_position - fwd * 2.2 + Vector3.UP * 0.3
	var reader := st.get_node("Reader")
	# the gate holds without a pass, and the side guards hold past it
	p.global_position = before
	p.velocity = Vector3.ZERO
	await frames(3)
	var lifted := p.global_transform
	lifted.origin += Vector3.UP * 0.35          # clear of the threshold plate's lip: only the gate can stop this
	ok("station: the gate blocks the bridge", p.test_move(lifted, fwd * 4.0))
	ok("station: reader prompt without a pass", str(reader.call("get_prompt")) == "Use the pass reader")
	reader.call("interact", p)
	await secs(0.2)
	ok("station: no pass, no entry", not st.get("is_open"))

	# kill spawned mobs at the player's feet: nothing for five, the sealed pass on the sixth
	var drops := func() -> Array: return get_nodes_in_group("pass_drop").filter(func(d): return is_instance_valid(d) and not d.get("_taken"))
	var kill := func() -> void:
		var e: Node3D = spawner.call("_spawn", 0, p.global_position + p.global_transform.basis.x * 2.0 + Vector3.UP * 0.5)
		await frames(2)
		e.call("die", true)
		await frames(2)
	spawner.set("pass_chance", 1.0)
	for i in 5:
		await kill.call()
	ok("drops: five kills, no pass yet", drops.call().is_empty() and int(GameState.get_value("mob_kills", 0)) == 5)
	await kill.call()
	var d: Array = drops.call()
	ok("drops: the sixth kill drops the sealed pass", d.size() == 1 and d[0].get("item_id") == "station_pass_sealed")
	await kill.call()
	d = drops.call()
	ok("drops: later kills roll pass_chance for a plain pass", d.size() == 2 and d.any(func(x): return x.get("item_id") == "station_pass"))
	spawner.set("pass_chance", 0.0)
	await kill.call()
	ok("drops: pass_chance 0 drops nothing", drops.call().size() == 2)
	await secs(1.2)        # let them land
	for x in drops.call():
		p.global_position = (x as Node3D).global_position
		await frames(4)
	await secs(0.3)
	ok("drops: walking over them picks them up", p.call("item_count", "station_pass_sealed") == 1 and p.call("item_count", "station_pass") == 1)
	await kill.call()
	ok("drops: the sealed pass doesn't drop twice", drops.call().is_empty())

	# the inventory's sections
	var inv := p.get("_inventory") as Control
	inv.call("open")
	await process_frame
	var txt := ""
	for l in inv.find_children("*", "Label", true, false):
		txt += (l as Label).text + "\n"
	ok("inventory: key item + valuable listed", "Sealed station pass" in txt and "Station pass" in txt and "KEY ITEMS" in txt and "VALUABLES" in txt)
	inv.call("close")

	# a plain pass is refused, the sealed one opens the gate for good
	p.call("use_item", "station_pass_sealed", 1)
	p.global_position = before
	await frames(2)
	reader.call("interact", p)
	await secs(0.2)
	ok("station: a broken-seal pass is refused", not st.get("is_open"))
	p.call("add_item", "station_pass_sealed", 1, true)
	ok("station: prompt offers the sealed pass", str(reader.call("get_prompt")) == "Present the sealed station pass")
	reader.call("interact", p)
	await secs(3.4)
	ok("station: the sealed pass opens the gate", st.get("is_open") and GameState.get_value("station_gate_open", false))
	# (lifted 0.35 m over the threshold plate's lip and the deck's rise, which a flat slide would catch on)
	var xf := p.global_transform
	xf.origin += Vector3.UP * 0.35
	var c := KinematicCollision3D.new()
	var blocked := p.test_move(xf, fwd * 4.0, c)
	if blocked:
		print("   (blocked by %s at %s)" % [c.get_collider().get_path() if c.get_collider() else "?", c.get_position()])
	ok("station: the gate's collision went up with it", not blocked)
	ok("station: the sealed pass is kept", p.call("item_count", "station_pass_sealed") == 1)
	var side := st.global_transform.basis.x
	p.global_position = st.global_position + fwd * 4.0 + Vector3.UP * 0.4
	await frames(2)
	ok("station: guards line the stub past the gate", p.test_move(p.global_transform, -side * 3.0) and p.test_move(p.global_transform, side * 3.0))
	quit()