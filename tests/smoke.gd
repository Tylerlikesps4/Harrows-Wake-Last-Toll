extends Node
## Automated playthrough: godot --headless -- --smoke
## Prints PASS/FAIL lines and SMOKE DONE; CI greps them.

var m


func ok(cond: bool, what: String) -> void:
	print(("PASS " if cond else "FAIL ") + what)


func wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


func item(id: String) -> Dictionary:
	for it in m.interactables:
		if it["id"] == id:
			return it
	return {}


func stand_at(id: String) -> void:
	var it := item(id)
	var p: Vector3 = it["pos"]
	m.player.global_position = Vector3(p.x - 1.0, 0.0, p.z)
	m.player.set_look(-PI / 2.0, -0.4)   # look east (towards +x), down a little


func _ready() -> void:
	m = get_parent()
	Engine.max_fps = 60
	_run.call_deferred()


func _run() -> void:
	await wait(0.5)
	ok(m.mode == "title", "starts on the title screen")
	m.start_game()
	await wait(0.3)
	ok(m.mode == "play", "game starts")
	ok(m.player.is_on_floor() or m.player.global_position.y < 0.2, "player stands on the floor")
	ok(m.bellman.state == "dormant", "Bellman dormant before the first pickup")
	ok(m.interactables.size() == 6, "6 interactables (3 items, door, bell, note): %d" % m.interactables.size())

	# walking moves the player and doesn't clip through walls
	var p0: Vector3 = m.player.global_position
	Input.action_press("move_forward")
	await wait(1.0)
	Input.action_release("move_forward")
	ok(m.player.global_position.distance_to(p0) > 1.0, "player walks forward")

	# note
	m.interact("note")
	ok(m.mode == "read", "note opens the reader")
	m.on_tap()
	ok(m.mode == "play", "reader closes")

	# chapel is locked without the key
	m.interact("bell")
	ok(not m.chapel_open, "chapel starts locked")
	m.interact("door")
	ok(not m.chapel_open, "door stays locked without the key")

	# the Bellman can reach the player through the halls (path exists everywhere)
	for id in ["rope", "clapper", "key"]:
		var it := item(id)
		ok(m.bellman.path_length_to(it["pos"]) > 0, "Bellman can path to the %s" % id)

	# pick up the rope: he wakes
	stand_at("rope")
	await wait(0.1)
	ok(m.find_near().get("id", "") == "rope", "rope is in reach and in view")
	m.try_interact()
	ok(m.inventory.has("rope"), "took the rope")
	ok(m.bellman.state != "dormant", "first pickup wakes the Bellman")

	# he walks, and investigates a noise
	var b0: Vector3 = m.bellman.global_position
	m.bellman.hear(m.player.global_position, 99.0)
	await wait(2.0)
	ok(m.bellman.global_position.distance_to(b0) > 1.0, "Bellman moves towards a noise (%.1f m)" % m.bellman.global_position.distance_to(b0))
	m.bellman.rest()

	for id in ["clapper", "key"]:
		stand_at(id)
		await wait(0.1)
		m.try_interact()
		ok(m.inventory.has(id), "took the %s" % id)
		m.bellman.rest()

	m.interact("door")
	ok(m.chapel_open, "key unlocks the chapel")
	ok(m.bellman.path_length_to(item("bell")["pos"]) > 0, "Bellman can enter the open chapel")
	ok(m.objective() == "Ring the chapel bell.", "objective updates to the bell")

	# caught: put him right next to the player and let him close in
	m.bellman.global_position = m.player.global_position + Vector3(0.8, 0, 0)
	m.bellman.wake()
	m.bellman.state = "wander"
	await wait(0.5)
	ok(m.mode == "dead", "the Bellman catches the player")
	m.mode = "play"
	m.bellman.rest()
	m.bellman.global_position = Vector3(45, 0, 3)

	m.interact("bell")
	ok(m.mode == "win", "ringing the bell wins")
	ok(m.run_time > 0.0, "run time recorded")
	print("SMOKE DONE")
	get_tree().quit()
