extends Node
## Screenshot tour: xvfb-run -s "-screen 0 1280x960x24" godot -- --shots
## Writes PNGs to user://shots (or the folder given with --out=DIR).

var m
var out := "user://shots/"


func _ready() -> void:
	m = get_parent()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
	DirAccess.make_dir_recursive_absolute(out)
	_run.call_deferred()


func snap(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.resize(img.get_width() * 3, img.get_height() * 3, Image.INTERPOLATE_NEAREST)
	img.save_png(out.path_join(name + ".png"))
	print("SHOT ", name)


func wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


func view(pos: Vector3, yaw: float, pitch: float = 0.0) -> void:
	m.player.global_position = pos
	m.player.set_look(yaw, pitch)
	m.fade = 0.0
	m.msg_t = 0.0
	await wait(0.4)


func _run() -> void:
	await wait(1.0)
	await snap("01_title")
	m.start_game()
	m.fade = 0.0
	await wait(0.6)
	await snap("02_start_hall")
	await view(Vector3(5.0, 0, 7.0), PI * 0.75)
	await snap("03_dormitory")
	await view(Vector3(27.0, 0, 21.0), PI, 0.15)
	m.chapel_open = true
	await snap("04_chapel")
	m.bellman.global_position = Vector3(12.0, 0, 15.0)
	m.bellman.rotation.y = -PI / 2
	await view(Vector3(16.0, 0, 15.0), PI / 2)
	await snap("05_bellman_hall")
	await view(Vector3(42.0, 0, 5.0), -PI / 2, -0.3)
	await snap("06_kitchen_clapper")
	# hiding: the dormitory wardrobe from outside, then peeking out, then under a bed
	var w: Dictionary = m.interactables.filter(func(i): return i["id"] == "hide_0")[0]
	await view(w["out"] + Vector3(0, 0, 2.0), 0.0, -0.05)
	await snap("07_wardrobe")
	m.enter_hide(w)
	m.msg_t = 0.0
	m.bellman.rest()
	m.bellman.global_position = w["out"] + Vector3(0.3, 0, 1.6)
	m.bellman.rotation.y = 0.0
	await wait(0.5)
	await snap("08_wardrobe_peek")
	m.leave_hide()
	var b: Dictionary = m.interactables.filter(func(i): return i["id"] == "hide_4")[0]
	await view(b["out"] + Vector3(1.0, 0, 0.0), PI / 2, -0.25)
	await snap("09_infirmary_bed")
	m.enter_hide(b)
	m.msg_t = 0.0
	await wait(0.5)
	await snap("10_under_bed")
	m.leave_hide()
	# the Bellman up close, lit by the torch
	m.bellman.global_position = Vector3(16.0, 0, 15.0)
	m.bellman.rotation.y = -PI / 2
	await view(Vector3(13.2, 0, 15.0), PI / 2, 0.0)
	await snap("11_bellman_close")
	# a phone: wide screen with touch controls
	m.touch.visible = true
	get_window().size = Vector2i(1600, 720)
	await view(Vector3(8.0, 0, 15.0), -PI / 2)
	await wait(0.3)
	await snap("12_touch_phone")
	m.touch.visible = false
	get_window().size = Vector2i(1280, 960)
	# lights-out scare
	m.scare("lights")
	await wait(0.5)
	await snap("13_lights_out")
	m.lights_out_t = 0.0
	m.brightness_i = 1
	get_tree().quit()
