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
	get_tree().quit()
