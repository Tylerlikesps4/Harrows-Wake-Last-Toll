extends Node3D
## Harrow's Wake: Last Toll - one night in the St. Agnes Orphanage.
## Find the bell rope, the clapper and the chapel key, then ring the chapel
## bell before the Bellman finds you. Level, items, UI and game flow live here;
## the Bellman's AI is in scripts/bellman.gd.

const PlayerScript := preload("res://scripts/player.gd")
const TouchScript := preload("res://scripts/touch.gd")
const POST_SHADER := preload("res://shaders/psx_post.gdshader")
const CELL := 2.0
const WALL_H := 3.0

# '#' wall, 'L' locked chapel door, 'S' start, 'W' the Bellman,
# 'r' bell rope, 'c' clapper, 'k' chapel key, 'B' chapel bell, 'n' note
const MAP := [
	"##########################",
	"#......#........#........#",
	"#..r...#........#....c...#",
	"#......#........#........#",
	"#......#........#........#",
	"###.#######.#########.####",
	"#........................#",
	"#.S.n....................#",
	"#........................#",
	"######.#####L######.######",
	"#..........#...#.........#",
	"#....k.....#...#.........#",
	"#..........#.B.#.....W...#",
	"#..........#...#.........#",
	"##########################",
]

# name, x0, y0, x1, y1 (cells, inclusive), floor tex, wall tint, light colour
const ROOMS := [
	["Dormitory", 1, 1, 6, 4, "old_wood_floor", Color(0.6, 0.62, 0.7)],
	["Refectory", 8, 1, 15, 4, "dirty_tiles", Color(0.7, 0.66, 0.55)],
	["Kitchen", 17, 1, 24, 4, "floor_tiles_06", Color(0.62, 0.66, 0.6)],
	["Main Hall", 1, 6, 24, 8, "dirty_carpet", Color(0.66, 0.55, 0.5)],
	["Matron's Office", 1, 10, 10, 13, "dark_wooden_planks", Color(0.6, 0.5, 0.42)],
	["Chapel", 12, 10, 14, 13, "concrete_floor_worn_001", Color(0.55, 0.55, 0.6)],
	["Infirmary", 16, 10, 24, 13, "dirty_tiles", Color(0.62, 0.7, 0.7)],
]

const ITEMS := {
	"r": ["rope", "Bell Rope", "A coil of chapel bell rope, cut clean. Someone didn't want the bell rung."],
	"c": ["clapper", "Bell Clapper", "The iron clapper from the chapel bell, wrapped in a dish rag."],
	"k": ["key", "Chapel Key", "A heavy iron key on a ribbon. The tag says CHAPEL - MATRON ONLY."],
}

# Hiding spots: kind, x, y (cell units, like _p), the yaw you look out along.
# Wardrobes stand against north walls and open south (+z); you can also slide
# under an infirmary bed.
const HIDE_SPOTS := [
	["wardrobe", 3.6, 1.42],
	["wardrobe", 22.0, 1.42],
	["wardrobe", 7.0, 10.42],
	["wardrobe", 20.6, 10.42],
	["bed", 17.0, 13.2],
]

const NOTE_TEXT := "Matron Agnes, 3rd Nov.\nWhen the hand bell rings in the halls, the children are not to leave their beds.\nOnly the great bell in the chapel sends him away. I have taken the rope and the clapper and locked the chapel. God forgive me. - M."

static var skip_title: bool = false
static var best_time: float = -1.0

var mode: String = "title"   # title, play, pause, read, dead, win
var env: Environment
var player
var bellman
var touch
var interactables: Array = []   # {id, kind, pos, node}
var inventory: Array = []
var chapel_open: bool = false
var door_node: Node3D
var run_time: float = 0.0
var start_pos := Vector3.ZERO
var sfx: Dictionary = {}
var heart_player: AudioStreamPlayer
var amb_player: AudioStreamPlayer
var post_mat: ShaderMaterial
var flicker_lights: Array = []
var fps_label: Label
var show_fps := false
var chase_on: bool = false
var near_it: Dictionary = {}
var hide_it: Dictionary = {}    # the spot the player is in, or empty
var bed_shade: ColorRect

# UI
var hud: CanvasLayer
var msg_label: Label
var prompt_label: Label
var obj_label: Label
var stamina_bar: ColorRect
var overlay: ColorRect
var overlay_label: Label
var msg_t: float = 0.0
var fade: float = 1.0


func _ready() -> void:
	randomize()
	_setup_input()
	_build_sfx()
	_build_environment()
	_build_level()
	if OS.has_feature("web"):
		Engine.max_fps = 60
	fps_label = Label.new()
	fps_label.position = Vector2(2, 2)
	fps_label.visible = false
	var fl := CanvasLayer.new()
	fl.layer = 100
	fl.add_child(fps_label)
	add_child(fl)
	_build_hiding_spots()
	_build_player()
	_build_bellman()
	_build_ui()
	if "--smoke" in OS.get_cmdline_user_args():
		add_child(load("res://tests/smoke.gd").new())
	if "--shots" in OS.get_cmdline_user_args():
		add_child(load("res://tests/shots.gd").new())
	if skip_title:
		skip_title = false
		start_game()
	else:
		_show_title()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		if touch != null:
			touch.release_all()
		if mode == "play":
			toggle_pause()


# ---------------------------------------------------------------- input
func _key(action: String, keys: Array, pad_buttons: Array = [], axes: Array = []) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.25)
	for k in keys:
		var e := InputEventKey.new()
		e.physical_keycode = k
		InputMap.action_add_event(action, e)
	for b in pad_buttons:
		var j := InputEventJoypadButton.new()
		j.button_index = b
		InputMap.action_add_event(action, j)
	for a in axes:
		var m := InputEventJoypadMotion.new()
		m.axis = a[0]
		m.axis_value = a[1]
		InputMap.action_add_event(action, m)


func _setup_input() -> void:
	if InputMap.has_action("move_forward"):
		return
	_key("move_forward", [KEY_W, KEY_UP], [JOY_BUTTON_DPAD_UP], [[JOY_AXIS_LEFT_Y, -1.0]])
	_key("move_back", [KEY_S, KEY_DOWN], [JOY_BUTTON_DPAD_DOWN], [[JOY_AXIS_LEFT_Y, 1.0]])
	_key("move_left", [KEY_A, KEY_LEFT], [JOY_BUTTON_DPAD_LEFT], [[JOY_AXIS_LEFT_X, -1.0]])
	_key("move_right", [KEY_D, KEY_RIGHT], [JOY_BUTTON_DPAD_RIGHT], [[JOY_AXIS_LEFT_X, 1.0]])
	_key("look_left", [], [], [[JOY_AXIS_RIGHT_X, -1.0]])
	_key("look_right", [], [], [[JOY_AXIS_RIGHT_X, 1.0]])
	_key("look_up", [], [], [[JOY_AXIS_RIGHT_Y, -1.0]])
	_key("look_down", [], [], [[JOY_AXIS_RIGHT_Y, 1.0]])
	_key("run", [KEY_SHIFT], [JOY_BUTTON_LEFT_STICK, JOY_BUTTON_B])
	_key("sneak", [KEY_CTRL, KEY_C], [JOY_BUTTON_RIGHT_STICK])
	_key("use", [KEY_E, KEY_SPACE, KEY_ENTER], [JOY_BUTTON_A])
	_key("light", [KEY_F], [JOY_BUTTON_LEFT_SHOULDER])
	_key("pause", [KEY_ESCAPE, KEY_P], [JOY_BUTTON_START])
	_key("fullscreen", [KEY_F11])


# ---------------------------------------------------------------- building
func cell_center(c: Vector2i) -> Vector3:
	return Vector3(c.x * CELL + CELL / 2.0, 0, c.y * CELL + CELL / 2.0)


func cell_of(p: Vector3) -> Vector2i:
	return Vector2i(floori(p.x / CELL), floori(p.z / CELL))


func room_name(p: Vector3) -> String:
	var c := cell_of(p)
	for r in ROOMS:
		if c.x >= r[1] and c.x <= r[3] and c.y >= r[2] and c.y <= r[4]:
			return r[0]
	return "Main Hall"


func box(parent: Node3D, size: Vector3, pos: Vector3, texname: String, col: Color, collide: bool = true, layer: int = 1, wscale: float = 0.5) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = Lib.mat(texname, col, true, wscale)
	mi.position = pos
	parent.add_child(mi)
	if collide:
		var sb := StaticBody3D.new()
		sb.collision_layer = layer
		sb.collision_mask = 0
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = size
		cs.shape = sh
		sb.add_child(cs)
		mi.add_child(sb)
	return mi


func _build_environment() -> void:
	var we := WorldEnvironment.new()
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0, 0, 0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.13, 0.13, 0.17)
	env.ambient_light_energy = 0.9
	env.fog_enabled = true
	env.fog_light_color = Color(0.03, 0.03, 0.04)
	env.fog_density = 0.09
	we.environment = env
	add_child(we)


func _build_level() -> void:
	var lvl := Node3D.new()
	lvl.name = "Level"
	add_child(lvl)
	var w: int = MAP[0].length()
	var h: int = MAP.size()
	# base floor + ceiling
	# floor + ceiling in chunks so a light only touches the chunks it reaches (GL Compatibility lights per object)
	var CH := 4
	for cy in range(0, h, CH):
		for cx in range(0, w, CH):
			var nx: int = mini(CH, w - cx)
			var nz: int = mini(CH, h - cy)
			var mx: float = (cx + nx / 2.0) * CELL
			var mz: float = (cy + nz / 2.0) * CELL
			box(lvl, Vector3(nx * CELL, 0.2, nz * CELL), Vector3(mx, -0.12, mz), "concrete_floor_worn_001", Color(0.5, 0.48, 0.45))
			box(lvl, Vector3(nx * CELL, 0.2, nz * CELL), Vector3(mx, WALL_H + 0.1, mz), "damaged_plaster", Color(0.4, 0.38, 0.36), false)
	# room floors + lights
	for r in ROOMS:
		var x0: float = r[1] * CELL
		var z0: float = r[2] * CELL
		var x1: float = (r[3] + 1) * CELL
		var z1: float = (r[4] + 1) * CELL
		box(lvl, Vector3(x1 - x0, 0.1, z1 - z0), Vector3((x0 + x1) / 2.0, -0.04, (z0 + z1) / 2.0), r[5], Color(0.75, 0.72, 0.68), false)
		var lt := OmniLight3D.new()
		lt.light_color = Color(1.0, 0.72, 0.45) if r[0] != "Chapel" else Color(0.6, 0.7, 1.0)
		lt.light_energy = 0.7
		lt.omni_range = maxf(x1 - x0, z1 - z0) * 0.55
		lt.position = Vector3((x0 + x1) / 2.0, WALL_H - 0.4, (z0 + z1) / 2.0)
		lt.set_meta("flicker", randf() < 0.5)
		if lt.get_meta("flicker"):
			flicker_lights.append(lt)
		lvl.add_child(lt)
	# walls: merge horizontal runs of '#' into single boxes
	for y in h:
		var row: String = MAP[y]
		var x := 0
		while x < w:
			if row[x] == "#":
				var x2 := x
				while x2 + 1 < w and row[x2 + 1] == "#":
					x2 += 1
				var n := x2 - x + 1
				box(lvl, Vector3(n * CELL, WALL_H, CELL), Vector3((x + n / 2.0) * CELL, WALL_H / 2.0, (y + 0.5) * CELL), "decrepit_wallpaper", Color(0.62, 0.58, 0.55))
				x = x2 + 1
			else:
				x += 1
	# cells with things in them
	for y in h:
		for x in w:
			var ch: String = MAP[y][x]
			var c := Vector2i(x, y)
			var p := cell_center(c)
			match ch:
				"S":
					start_pos = p
				"L":
					box(lvl, Vector3(CELL, WALL_H - 2.4, 0.6), p + Vector3(0, 2.4 + (WALL_H - 2.4) / 2.0, 0), "decrepit_wallpaper", Color(0.62, 0.58, 0.55), false)
					door_node = box(lvl, Vector3(CELL * 0.8, 2.4, 0.15), p + Vector3(0, 1.2, 0), "dark_wooden_planks", Color(0.6, 0.45, 0.35))
					interactables.append({"id": "door", "kind": "door", "pos": p + Vector3(0, 1.0, -0.4), "node": door_node})
				"r", "c", "k":
					var it: Array = ITEMS[ch]
					var n3 := _item_mesh(lvl, it[0], p + Vector3(0, 0.75, 0))
					interactables.append({"id": it[0], "kind": "item", "pos": p + Vector3(0, 0.75, 0), "node": n3})
				"B":
					var bell := _chapel_bell(lvl, p)
					interactables.append({"id": "bell", "kind": "bell", "pos": p + Vector3(0, 1.0, 0), "node": bell})
				"n":
					var paper := box(lvl, Vector3(0.3, 0.02, 0.4), p + Vector3(0, 0.76, 0), "plastered_wall_02", Color(0.9, 0.86, 0.75), false)
					paper.material_override = Lib.mat("plastered_wall_02", Color(0.9, 0.86, 0.75), false, 1.0, 0.4)
					Lib.prop(lvl, "desk", p, 0.0, 1.2)
					interactables.append({"id": "note", "kind": "note", "pos": p + Vector3(0, 0.75, 0), "node": paper})
	_dress_rooms(lvl)


func _item_mesh(parent: Node3D, id: String, pos: Vector3) -> Node3D:
	var root := Node3D.new()
	root.position = pos
	parent.add_child(root)
	var mi := MeshInstance3D.new()
	match id:
		"rope":
			var t := TorusMesh.new()
			t.inner_radius = 0.06
			t.outer_radius = 0.16
			mi.mesh = t
			mi.material_override = Lib.mat("dirty_carpet", Color(0.8, 0.65, 0.4), false, 1.0, 0.25)
		"clapper":
			var cy := CylinderMesh.new()
			cy.top_radius = 0.03
			cy.bottom_radius = 0.08
			cy.height = 0.4
			mi.mesh = cy
			mi.rotation.z = PI / 2
			mi.material_override = Lib.mat("rusty_metal_02", Color(0.6, 0.6, 0.6), false, 1.0, 0.25)
		_:
			var bm := BoxMesh.new()
			bm.size = Vector3(0.25, 0.04, 0.08)
			mi.mesh = bm
			mi.material_override = Lib.mat("rusty_metal_02", Color(0.9, 0.75, 0.4), false, 1.0, 0.35)
	root.add_child(mi)
	# a small pedestal/crate so items sit at hand height
	Lib.prop(parent, "cardboardBoxClosed", Vector3(pos.x, 0, pos.z), randf() * TAU, 0.7)
	# glint: emissive material instead of an extra light (cheaper on integrated GPUs)
	var gm = mi.material_override
	if gm is StandardMaterial3D:
		gm.emission_enabled = true
		gm.emission = Color(1.0, 0.85, 0.6)
		gm.emission_energy_multiplier = 0.6
	return root


func _chapel_bell(parent: Node3D, p: Vector3) -> Node3D:
	var root := Node3D.new()
	root.position = p
	parent.add_child(root)
	var mi := MeshInstance3D.new()
	var cy := CylinderMesh.new()
	cy.top_radius = 0.35
	cy.bottom_radius = 0.7
	cy.height = 0.9
	cy.radial_segments = 10
	mi.mesh = cy
	mi.position.y = 2.3
	mi.material_override = Lib.mat("rusty_metal_02", Color(0.75, 0.55, 0.3), false, 1.0)
	root.add_child(mi)
	var beam := box(root, Vector3(2.0, 0.2, 0.2), Vector3(0, 2.85, 0), "dark_wooden_planks", Color(0.5, 0.4, 0.3), false)
	beam.name = "beam"
	return root


func _p(lvl: Node3D, name: String, cx: float, cy: float, rot: float, size: float, by_h: bool = false) -> void:
	Lib.prop(lvl, name, Vector3(cx * CELL, 0, cy * CELL), rot, size, 2, Color(1, 1, 1), by_h)


func _dress_rooms(lvl: Node3D) -> void:
	# Dormitory
	_p(lvl, "bedBunk", 1.6, 1.6, 0.0, 2.0)
	_p(lvl, "bedBunk", 5.4, 1.6, 0.0, 2.0)
	_p(lvl, "bedBunk", 5.4, 4.4, PI, 2.0)
	# Refectory
	_p(lvl, "desk", 11.0, 2.5, 0.0, 2.4)
	_p(lvl, "desk", 13.5, 2.5, 0.0, 2.4)
	_p(lvl, "chair", 11.0, 3.4, PI, 0.9, true)
	_p(lvl, "chair", 13.5, 1.7, 0.0, 0.9, true)
	# Kitchen
	_p(lvl, "kitchenCabinetDrawer", 18.0, 1.4, 0.0, 1.0)
	_p(lvl, "kitchenCabinetDrawer", 19.0, 1.4, 0.0, 1.0)
	_p(lvl, "kitchenCabinetDrawer", 24.6, 3.0, -PI / 2, 1.0)
	# Matron's Office
	_p(lvl, "desk", 4.0, 12.0, 0.0, 1.6)
	_p(lvl, "chair", 4.0, 12.8, PI, 0.9, true)
	_p(lvl, "bookcaseClosedWide", 9.0, 10.4, 0.0, 1.8)
	# Chapel
	_p(lvl, "gy_bench", 13.5, 10.8, 0.0, 1.8)
	_p(lvl, "gy_bench", 13.5, 11.7, 0.0, 1.8)
	_p(lvl, "gy_altar-wood", 13.5, 13.6, 0.0, 1.4)
	_p(lvl, "gy_cross-wood", 13.5, 13.85, 0.0, 1.6, true)
	_p(lvl, "gy_candle-multiple", 12.4, 13.6, 0.0, 0.4)
	# Infirmary
	_p(lvl, "bedSingle", 17.0, 11.0, PI / 2, 2.0)
	_p(lvl, "bedSingle", 17.0, 13.2, PI / 2, 2.0)
	_p(lvl, "bedSingle", 24.0, 11.0, -PI / 2, 2.0)
	_p(lvl, "cabinetBedDrawer", 24.5, 13.5, 0.0, 0.6)


func _build_hiding_spots() -> void:
	var lvl: Node3D = $Level
	var i := 0
	for h in HIDE_SPOTS:
		var at := Vector3(h[1] * CELL, 0, h[2] * CELL)
		var it := {"id": "hide_%d" % i, "kind": "hide", "spot": h[0], "look_yaw": PI}
		if h[0] == "wardrobe":
			var w := Lib.prop(lvl, "bookcaseClosedDoors", at, 0.0, 2.2, 2, Color(0.75, 0.62, 0.5), true)
			it["node"] = w
			it["pos"] = at + Vector3(0, 1.1, 0.45)       # its doors
			it["inside"] = at + Vector3(0, 0, 0.5)         # just behind the doors
			it["out"] = at + Vector3(0, 0, 1.25)
			it["eye"] = 1.5
		else:
			# the bed itself is already in the infirmary; you slide under it
			it["node"] = null
			it["pos"] = at + Vector3(0.9, 0.4, 0)
			it["inside"] = at
			it["out"] = at + Vector3(1.6, 0, 0)
			it["eye"] = 0.28
			it["look_yaw"] = -PI / 2.0                      # look out east, into the ward
		interactables.append(it)
		i += 1


func hiding() -> bool:
	return not hide_it.is_empty()


func enter_hide(it: Dictionary) -> void:
	# He only knows where you went if he could see you get in.
	var seen: bool = bellman.state == "chase" or bellman.can_see_player()
	hide_it = it
	player.hidden = true
	player.hide_yaw = it["look_yaw"]
	player.hide_eye = it["eye"]
	player.global_position = it["inside"]
	player.set_look(it["look_yaw"], 0.0)
	if touch != null:
		touch.run_toggle = false
	play_sfx("creak", null, -8.0, 0.9)
	make_noise(player.global_position, 2.0)
	bellman.on_player_hid(it["inside"], seen)
	show_message("Hold Ctrl (BREATH) to hold your breath when he's close.
E / USE to get out." if it["spot"] == "wardrobe" else "Under the bed. Hold Ctrl (BREATH) when he's close.
E / USE to crawl out.", 4.0)


func leave_hide() -> void:
	if not hiding():
		return
	var it := hide_it
	hide_it = {}
	player.hidden = false
	player.holding_breath = false
	player.global_position = it["out"]
	player.set_look(it["look_yaw"], 0.0)
	play_sfx("creak", null, -8.0, 1.05)
	make_noise(player.global_position, 3.0)
	bellman.on_player_left_hiding()


## Ran out of breath inside a hiding spot.
func on_gasp() -> void:
	play_sfx("breath", null, 0.0)
	make_noise(player.global_position, 8.0)
	if hiding() and bellman.state != "dormant" and bellman.global_position.distance_to(player.global_position) < 8.0:
		bellman._hunt(hide_it["inside"])


## He found the hiding spot and opened it.
func dragged_out() -> void:
	if mode != "play" or not hiding():
		return
	var spot: String = hide_it["spot"]
	play_sfx("slam", null, -2.0)
	hide_it = {}
	player.hidden = false
	_die("THE BELLMAN TOOK YOU\n\n%s\n\n" % ("He opens the wardrobe doors, slowly. He knew." if spot == "wardrobe" else "A gloved hand reaches under the bed."))


func _build_player() -> void:
	player = CharacterBody3D.new()
	player.set_script(PlayerScript)
	player.name = "Player"
	player.main = self
	add_child(player)
	player.global_position = start_pos
	player.set_look(PI / 2.0 * -1.0, 0.0)   # face east down the hall


func _build_bellman() -> void:
	bellman = preload("res://scripts/bellman.gd").new()
	bellman.name = "Bellman"
	add_child(bellman)
	var rows := PackedStringArray(MAP)
	bellman.setup(rows, CELL, player, self, sfx["bell"], sfx["bell_muffled"])
	for y in MAP.size():
		var x: int = (MAP[y] as String).find("W")
		if x >= 0:
			bellman.global_position = cell_center(Vector2i(x, y))


func _build_sfx() -> void:
	for n in ["bell", "bell_muffled", "bell_toll", "bell_roar", "creak", "door", "pickup", "menu", "sting", "unlock", "flashlight", "slam", "breath", "hurt", "scream", "glitch"]:
		sfx[n] = load("res://assets/audio/%s.ogg" % n)
	for i in 3:
		sfx["step_%d" % i] = load("res://assets/audio/step_wood_%d.ogg" % i)
	amb_player = _loop("amb_orphanage", -10.0)
	heart_player = _loop("heart", -80.0)
	_loop("amb_rain", -20.0)


func _loop(n: String, vol: float) -> AudioStreamPlayer:
	var a := AudioStreamPlayer.new()
	var st: AudioStream = load("res://assets/audio/%s.ogg" % n)
	if st is AudioStreamOggVorbis:
		st = st.duplicate()
		st.loop = true
	a.stream = st
	a.volume_db = vol
	add_child(a)
	a.play()
	return a


func play_sfx(n: String, pos = null, vol: float = 0.0, pitch: float = 1.0) -> void:
	if not sfx.has(n) or sfx[n] == null:
		return
	if pos == null:
		var a := AudioStreamPlayer.new()
		a.stream = sfx[n]
		a.volume_db = vol
		a.pitch_scale = pitch
		add_child(a)
		a.play()
		a.finished.connect(a.queue_free)
	else:
		var a3 := AudioStreamPlayer3D.new()
		a3.stream = sfx[n]
		a3.volume_db = vol
		a3.pitch_scale = pitch
		a3.unit_size = 4.0
		add_child(a3)
		a3.global_position = pos
		a3.play()
		a3.finished.connect(a3.queue_free)


func play_step(pos: Vector3, vol: float) -> void:
	play_sfx("step_%d" % (randi() % 3), null, vol, randf_range(0.9, 1.1))


func make_noise(pos: Vector3, radius: float) -> void:
	if radius > 0.0 and bellman != null:
		bellman.hear(pos, radius)


# ---------------------------------------------------------------- UI
func _label(parent: Node, size: int, align: int) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	l.add_theme_constant_override("outline_size", 3)
	l.horizontal_alignment = align
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


func _build_ui() -> void:
	var post_layer := CanvasLayer.new()
	post_layer.layer = 1
	add_child(post_layer)
	var post := ColorRect.new()
	post.set_anchors_preset(Control.PRESET_FULL_RECT)
	post.mouse_filter = Control.MOUSE_FILTER_IGNORE
	post_mat = ShaderMaterial.new()
	post_mat.shader = POST_SHADER
	post.material = post_mat
	post_layer.add_child(post)
	bed_shade = ColorRect.new()
	bed_shade.color = Color(0.02, 0.015, 0.01, 0.97)
	bed_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bed_shade.visible = false
	post_layer.add_child(bed_shade)
	hud = CanvasLayer.new()
	hud.layer = 3
	add_child(hud)
	obj_label = _label(hud, 8, HORIZONTAL_ALIGNMENT_LEFT)
	obj_label.position = Vector2(6, 4)
	obj_label.size = Vector2(200, 40)
	obj_label.modulate = Color(0.85, 0.82, 0.75, 0.85)
	msg_label = _label(hud, 9, HORIZONTAL_ALIGNMENT_CENTER)
	msg_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	prompt_label = _label(hud, 9, HORIZONTAL_ALIGNMENT_CENTER)
	stamina_bar = ColorRect.new()
	stamina_bar.color = Color(0.8, 0.75, 0.6, 0.5)
	stamina_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(stamina_bar)
	var top := CanvasLayer.new()
	top.layer = 4
	add_child(top)
	overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.75)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(overlay)
	overlay_label = _label(top, 10, HORIZONTAL_ALIGNMENT_CENTER)
	overlay_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	touch = CanvasLayer.new()
	touch.set_script(TouchScript)
	add_child(touch)
	touch.main = self
	touch.player = player


func _layout_ui() -> void:
	var vs: Vector2 = get_viewport().get_visible_rect().size
	msg_label.position = Vector2(vs.x * 0.1, vs.y - 64)
	msg_label.size = Vector2(vs.x * 0.8, 30)
	prompt_label.position = Vector2(vs.x * 0.2, vs.y * 0.5 + 14)
	prompt_label.size = Vector2(vs.x * 0.6, 14)
	overlay_label.position = Vector2(vs.x * 0.08, 0)
	overlay_label.size = Vector2(vs.x * 0.84, vs.y)
	stamina_bar.position = Vector2(vs.x * 0.5 - 30, vs.y - 8)
	stamina_bar.size = Vector2(60.0 * player.stamina / 100.0, 2)
	stamina_bar.visible = mode == "play" and player.stamina < 99.0
	# under a bed: the slats and mattress fill the top of the view
	bed_shade.position = Vector2.ZERO
	bed_shade.size = Vector2(vs.x, vs.y * 0.42)
	bed_shade.visible = mode == "play" and hiding() and hide_it["spot"] == "bed"


func show_message(t: String, secs: float = 3.5) -> void:
	msg_label.text = t
	msg_t = secs


func _show_overlay(t: String, alpha: float = 0.75) -> void:
	overlay.visible = true
	overlay.color = Color(0, 0, 0, alpha)
	overlay_label.visible = true
	overlay_label.text = t


func _hide_overlay() -> void:
	overlay.visible = false
	overlay_label.visible = false


func objective() -> String:
	if "bell" in inventory:
		return ""
	if inventory.has("rope") and inventory.has("clapper") and chapel_open:
		return "Ring the chapel bell."
	var lines := ["Before dawn:"]
	for k in ["r", "c", "k"]:
		var it: Array = ITEMS[k]
		lines.append(("[x] " if inventory.has(it[0]) else "[ ] ") + it[1])
	if inventory.has("key") and not chapel_open:
		lines.append("Unlock the chapel.")
	return "\n".join(lines)


func _input_hint() -> String:
	return "Tap to begin" if touch.visible else "Press E / Enter / (A) to begin"


func _show_title() -> void:
	mode = "title"
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var best := "" if best_time < 0.0 else "\nBest escape: %s" % _fmt_time(best_time)
	_show_overlay("HARROW'S WAKE\nLAST TOLL\n\nOne night. One bell. Ring it before he finds you.\n\n%s%s\n\nWASD move  Shift run  Ctrl sneak  E use  F light  Esc pause" % [_input_hint(), best], 0.82)


func start_game() -> void:
	mode = "play"
	_hide_overlay()
	run_time = 0.0
	fade = 1.0
	if not touch.visible and DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	show_message("St. Agnes Orphanage. 3:12 AM.\nSomewhere upstairs, a hand bell rings once.", 5.0)
	play_sfx("bell", null, -14.0, 0.8)


func toggle_pause() -> void:
	if mode == "play":
		mode = "pause"
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_show_overlay("PAUSED\n\n%s\n\nEnter / tap: resume\nQ: quit to title" % objective())
	elif mode == "pause":
		_resume()


func _resume() -> void:
	mode = "play"
	_hide_overlay()
	if not touch.visible and DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func on_tap() -> void:
	match mode:
		"title": start_game()
		"pause", "read": _resume()
		"dead": restart()
		"win": _to_title()


func restart() -> void:
	skip_title = true
	get_tree().reload_current_scene()


func _to_title() -> void:
	skip_title = false
	get_tree().reload_current_scene()


func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("fullscreen"):
		var fs := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if fs else DisplayServer.WINDOW_MODE_FULLSCREEN)
		return
	if e is InputEventMouseButton and e.pressed and mode == "play" and not touch.visible:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	match mode:
		"title":
			if e.is_action_pressed("use") or (e is InputEventMouseButton and e.pressed):
				start_game()
		"play":
			if e.is_action_pressed("pause"):
				toggle_pause()
			elif e.is_action_pressed("use"):
				try_interact()
			elif e.is_action_pressed("light"):
				player.toggle_light()
		"pause":
			if e.is_action_pressed("use") or e.is_action_pressed("pause"):
				_resume()
			elif e is InputEventKey and e.pressed and e.physical_keycode == KEY_Q:
				_to_title()
		"read":
			if e.is_action_pressed("use") or e.is_action_pressed("pause"):
				_resume()
		"dead":
			if e.is_action_pressed("use"):
				restart()
		"win":
			if e.is_action_pressed("use"):
				_to_title()


# ---------------------------------------------------------------- interaction
func find_near() -> Dictionary:
	if hiding():
		return {}
	var best: Dictionary = {}
	var best_d := 2.2
	var eye: Vector3 = player.cam.global_position
	var fwd: Vector3 = -player.cam.global_transform.basis.z
	for it in interactables:
		var d: float = eye.distance_to(it["pos"])
		if d > 2.2:
			continue
		var to: Vector3 = (it["pos"] - eye).normalized()
		if fwd.dot(to) < 0.45 and d > 0.9:
			continue
		if d < best_d:
			best_d = d
			best = it
	return best


func prompt_for(it: Dictionary) -> String:
	match it["kind"]:
		"item":
			for k in ITEMS:
				if ITEMS[k][0] == it["id"]:
					return "Take the " + ITEMS[k][1].to_lower()
		"door":
			return "Unlock the chapel" if inventory.has("key") else "Chapel door (locked)"
		"bell":
			return "Ring the bell" if inventory.has("rope") and inventory.has("clapper") else "The chapel bell"
		"note":
			return "Read the note"
		"hide":
			return "Hide in the wardrobe" if it["spot"] == "wardrobe" else "Hide under the bed"
	return ""


func try_interact() -> void:
	if mode != "play":
		return
	if hiding():
		leave_hide()
		return
	var it := find_near()
	if it.is_empty():
		return
	interact(it["id"])


func interact(id: String) -> void:
	var it: Dictionary = {}
	for i in interactables:
		if i["id"] == id:
			it = i
	if it.is_empty():
		return
	match it["kind"]:
		"item":
			for k in ITEMS:
				if ITEMS[k][0] == id:
					inventory.append(id)
					show_message("%s\n%s" % [ITEMS[k][1], ITEMS[k][2]], 5.0)
			(it["node"] as Node3D).queue_free()
			interactables.erase(it)
			play_sfx("pickup", null, -4.0)
			make_noise(player.global_position, 6.0)
			if inventory.size() == 1:
				# the first thing taken wakes him
				bellman.wake()
				get_tree().create_timer(1.6).timeout.connect(func(): play_sfx("bell", bellman.global_position, 6.0, 0.85))
		"door":
			if not inventory.has("key"):
				play_sfx("creak", null, -6.0)
				show_message("Locked. Matron kept the chapel key.", 3.0)
				return
			chapel_open = true
			play_sfx("unlock", null, -2.0)
			play_sfx("door", null, -4.0)
			(it["node"] as Node3D).queue_free()
			interactables.erase(it)
			var c := cell_of(it["pos"])
			bellman.set_cell(c.x, c.y, ".")
			make_noise(player.global_position, 9.0)
			show_message("The chapel door groans open.", 3.0)
		"bell":
			if not (inventory.has("rope") and inventory.has("clapper")):
				show_message("The bell has no rope and no clapper.\nIt cannot ring like this.", 4.0)
				return
			_win()
		"hide":
			enter_hide(it)
		"note":
			mode = "read"
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			play_sfx("menu", null, -8.0)
			_show_overlay(NOTE_TEXT + "\n\n(continue)", 0.85)


# ---------------------------------------------------------------- outcomes
func on_chase_start() -> void:
	chase_on = true
	play_sfx("sting", null, -2.0)


func on_chase_end() -> void:
	chase_on = false


func caught() -> void:
	if mode != "play":
		return
	_die("THE BELLMAN TOOK YOU\n\nHe rings for one more child tonight.\n\n")


func _die(text: String) -> void:
	mode = "dead"
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	play_sfx("bell_roar", null, 0.0)
	play_sfx("scream", null, -6.0)
	bellman.rest()
	_show_overlay(text + ("Tap to try again" if touch.visible else "Press E / Enter to try again"), 0.9)


func _fmt_time(t: float) -> String:
	return "%d:%02d" % [int(t) / 60, int(t) % 60]


func _win() -> void:
	mode = "win"
	inventory.append("bell")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	bellman.rest()
	if best_time < 0.0 or run_time < best_time:
		best_time = run_time
	for i in 3:
		get_tree().create_timer(i * 1.6).timeout.connect(func(): play_sfx("bell_toll", null, 0.0, 0.8))
	_show_overlay("THE LAST TOLL\n\nThe great bell rings out over St. Agnes.\nIn the hall, a hand bell answers once, and falls silent.\n\nYou escaped in %s.\n\nA Super Free AI Game Jam #2 game. Made in Godot.\n%s" % [_fmt_time(run_time), "Tap for the title" if touch.visible else "Press E / Enter for the title"], 0.88)


# ---------------------------------------------------------------- loop
func _input(ev: InputEvent) -> void:
	if ev is InputEventKey and ev.pressed and not ev.echo and ev.keycode == KEY_F3:
		show_fps = not show_fps
		fps_label.visible = show_fps


func _process(delta: float) -> void:
	_layout_ui()
	var playing := mode == "play"
	obj_label.visible = playing
	msg_label.visible = playing and msg_t > 0.0
	if mode == "play":
		run_time += delta
		msg_t -= delta
		obj_label.text = objective()
		near_it = find_near()
		prompt_label.text = ("[ %s ]" % prompt_for(near_it)) if not near_it.is_empty() else ""
	if playing and hiding():
		prompt_label.text = "[ holding your breath ]" if player.holding_breath else "[ hidden ]"
	prompt_label.visible = playing and (not near_it.is_empty() or hiding())
	post_mat.set_shader_parameter("slit", 1.0 if playing and hiding() and hide_it["spot"] == "wardrobe" else 0.0)
	fade = maxf(0.0, fade - delta * 0.6)
	post_mat.set_shader_parameter("fade", fade if mode == "play" else 0.0)
	# dread: heartbeat and screen panic by distance to the Bellman
	var d := 99.0
	if bellman != null and bellman.state != "dormant":
		d = bellman.global_position.distance_to(player.global_position)
	var panic := clampf(1.0 - (d - 2.0) / 8.0, 0.0, 1.0) if mode == "play" else 0.0
	post_mat.set_shader_parameter("panic", panic)
	heart_player.volume_db = lerpf(-60.0, 0.0, panic) if panic > 0.01 else -80.0
	# flicker some room lights
	for n in flicker_lights:
		n.light_energy = 0.7 if randf() > 0.03 else 0.1
	if show_fps and fps_label != null:
		fps_label.text = "%d fps" % Engine.get_frames_per_second()
