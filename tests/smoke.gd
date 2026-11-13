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
	ok(m.title_player != null and m.title_player.stream != null, "title music is loaded on the title screen")
	m.start_game()
	await wait(0.3)
	ok(m.mode == "play", "game starts")
	ok(m.player.is_on_floor() or m.player.global_position.y < 0.2, "player stands on the floor")
	ok(m.bellman.state == "dormant", "Bellman dormant before the first pickup")
	ok(m.interactables.size() == 15, "15 interactables (3 items, door, bell, 5 notes, 5 hiding spots): %d" % m.interactables.size())

	# walking moves the player and doesn't clip through walls
	var p0: Vector3 = m.player.global_position
	Input.action_press("move_forward")
	await wait(1.0)
	Input.action_release("move_forward")
	ok(m.player.global_position.distance_to(p0) > 1.0, "player walks forward")

	# notes: every one opens the reader with its own text, and a mouse click closes it
	m.interact("note")
	ok(m.mode == "read", "note opens the reader")
	m.on_tap()
	ok(m.mode == "play", "reader closes")
	for nid in ["note_a", "note_b", "note_m", "note_i"]:
		m.interact(nid)
		ok(m.mode == "read" and m.overlay_label.text.length() > 60 and m.notes_read.has(nid), "%s opens with its own text" % nid)
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = true
		m._unhandled_input(click)
		ok(m.mode == "play", "a mouse click closes %s" % nid)
	ok(m.notes_read.size() == 5, "all five notes can be found (%d)" % m.notes_read.size())
	# pause: a click resumes (the browser releases the mouse on Esc), B changes the brightness
	m.toggle_pause()
	ok(m.mode == "pause", "pause menu opens")
	var amb0: float = m.env.ambient_light_energy
	m.cycle_brightness()
	ok(absf(m.env.ambient_light_energy - amb0) > 0.05, "brightness setting changes the ambient light")
	m.cycle_brightness()
	m.cycle_brightness()
	m.cycle_brightness()
	var click2 := InputEventMouseButton.new()
	click2.button_index = MOUSE_BUTTON_LEFT
	click2.pressed = true
	m._unhandled_input(click2)
	ok(m.mode == "play", "a click resumes from the pause menu")
	# the Bellman has his real model (animated mannequin)
	ok(m.bellman.model != null and m.bellman.model.anim != null and m.bellman.model.anim.has_animation("Walk_Formal") and m.bellman.model.anim.has_animation("Jog_Fwd") and m.bellman.model.anim.has_animation("Idle_Torch"), "Bellman uses the animated model with walk, jog and idle")
	# scares
	m.scare("lights")
	ok(m.lights_out_t > 3.0, "the lights-out scare starts")
	m.lights_out_t = 0.0
	m.scare("bunk")
	m.scare("slam")
	ok(m.scares_done.size() == 3, "scares are recorded as done")

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

	await _hiding_tests()

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
	m.on_tap()
	ok(m.mode == "dead", "the death screen ignores a tap in its first second (no accidental restart)")
	m.mode = "play"
	m.bellman.rest()
	m.bellman.global_position = Vector3(45, 0, 3)

	m.interact("bell")
	ok(m.mode == "win", "ringing the bell wins")
	ok(m.overlay_label.text.contains("Notes found: 5 / 5"), "win screen shows the stats")
	ok(m.run_time > 0.0, "run time recorded")
	await _bell_audio_tests()
	print("SMOKE DONE")
	get_tree().quit()


func _hiding_tests() -> void:
	var w := item("hide_0")
	ok(not w.is_empty() and w["spot"] == "wardrobe", "dormitory wardrobe is a hiding spot")
	ok(m.bellman.path_length_to(w["inside"]) > 0, "Bellman can reach the wardrobe")
	# unseen: hide while he wanders far away
	m.bellman.rest()
	m.bellman.global_position = Vector3(45, 0, 25)
	m.bellman.wake()
	m.bellman.state = "wander"
	m.player.global_position = w["out"]
	m.player.set_look(0.0, 0.0)
	await wait(0.1)
	ok(m.find_near().get("id", "") == "hide_0", "wardrobe prompt in reach")
	m.try_interact()
	ok(m.hiding() and m.player.hidden, "player hides in the wardrobe")
	ok(m.bellman.hunt_spot == null, "he didn't see you get in")
	# he walks right up to the wardrobe and can't see in
	m.bellman.rest()
	m.bellman.global_position = w["out"] + Vector3(0, 0, 0.6)
	m.bellman.look_at(Vector3(w["inside"].x, m.bellman.global_position.y, w["inside"].z), Vector3.UP)
	m.bellman.wake()
	m.bellman.state = "wander"
	ok(not m.bellman.can_see_player(), "Bellman can't see a hidden player")
	# holding your breath drains stamina and keeps you unheard
	Input.action_press("sneak")
	await wait(1.0)
	ok(m.player.holding_breath and m.player.stamina < 95.0, "holding breath drains stamina (%.0f)" % m.player.stamina)
	ok(m.mode == "play" and m.bellman.hunt_spot == null, "he can't hear you hold your breath")
	Input.action_release("sneak")
	# breathing next to him gives you away
	m.bellman.global_position = w["out"] + Vector3(0.0, 0, 1.5)
	m.bellman.state = "investigate"   # standing right outside, listening
	m.bellman.path.clear()
	m.bellman.idle_t = -5.0
	await wait(2.6)
	ok(m.bellman.hunt_spot != null or m.mode == "dead", "he hears you breathing up close")
	m.bellman.rest()
	if m.mode == "dead":
		m.mode = "play"
	if not m.hiding():
		m.enter_hide(w)
	m.leave_hide()
	ok(not m.player.hidden and m.player.global_position.distance_to(w["out"]) < 0.5, "player leaves the wardrobe")
	# seen getting in: he opens it
	m.bellman.global_position = w["out"] + Vector3(0, 0, 3.0)
	m.bellman.look_at(Vector3(w["out"].x, 0, w["out"].z - 1.0), Vector3.UP)
	m.bellman.wake()
	m.bellman.state = "investigate"   # standing still, looking at the wardrobe
	m.bellman.path.clear()
	m.bellman.idle_t = -5.0
	m.player.global_position = w["out"]
	await wait(0.1)
	ok(m.bellman.can_see_player(), "Bellman sees the player by the wardrobe")
	m.enter_hide(w)
	ok(m.bellman.hunt_spot != null, "he saw you get in")
	await wait(3.0)
	ok(m.mode == "dead" and not m.hiding(), "he opens the wardrobe and takes you")
	m.mode = "play"
	m.bellman.rest()
	m.bellman.global_position = Vector3(45, 0, 3)
	# under the bed
	var b := item("hide_4")
	m.enter_hide(b)
	await wait(0.1)
	ok(m.hiding() and m.hide_it["spot"] == "bed" and m.player.cam.global_position.y < 0.6, "player can hide under the infirmary bed")
	m.touch.run_toggle = true
	m.leave_hide()
	ok(not m.hiding(), "player crawls out from under the bed")
	ok(not m.touch.run_toggle, "BREATH toggle does not turn into a sprint after leaving a hiding spot")
	m.player.stamina = 100.0
	m.player.exhausted = false


func _bell_audio_tests() -> void:
	# The bell is clear in sight and muffled through a wall.
	m.mode = "play"
	m.bellman.rest()
	m.player.global_position = Vector3(3.0, 0, 15.0)    # main hall, west end
	m.bellman.global_position = Vector3(16.0, 0, 15.0)  # same hall
	await wait(0.1)
	ok(not m.bellman.wall_between(), "bell heard clearly in the same hall")
	m.bellman.global_position = Vector3(3.0, 0, 5.0)    # dormitory, through the wall
	await wait(0.1)
	ok(m.bellman.wall_between(), "bell muffled through a wall")
	m.bellman.state = "wander"
	var slow: float = m.bellman.bell_interval()
	m.bellman.state = "chase"
	var fast: float = m.bellman.bell_interval()
	ok(fast < slow, "bell rings faster in a chase (%.2f s vs %.2f s)" % [fast, slow])
	m.bellman.rest()
	# settings (pause menu)
	m.adjust_settings(-0.3, 0.5)
	ok(absf(m.master_vol - 0.7) < 0.01 and m.player.mouse_sens > 0.0025, "pause settings change volume and sensitivity")
	m.adjust_settings(0.3, -0.5)
