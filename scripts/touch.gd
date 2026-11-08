extends CanvasLayer
## Phone controls: drag on the left half to walk (floating stick), drag on the
## right half to look, and buttons for USE / RUN / LIGHT / PAUSE.

var main = null
var player = null
var stick_id: int = -1
var stick_origin := Vector2.ZERO
var look_id: int = -1
var look_last := Vector2.ZERO
var buttons: Dictionary = {}   # name -> Control
var run_toggle: bool = false
var root: Control
var stick_base: Control
var stick_knob: Control


func _ready() -> void:
	layer = 5
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	stick_base = _circle(28.0, Color(1, 1, 1, 0.12))
	stick_knob = _circle(12.0, Color(1, 1, 1, 0.3))
	stick_base.visible = false
	stick_knob.visible = false
	_button("pause", "II", Vector2(-26, 6), Vector2(20, 16))
	_button("use", "USE", Vector2(-50, -64), Vector2(42, 26))
	_button("run", "RUN", Vector2(-98, -38), Vector2(42, 26))
	_button("light", "LIGHT", Vector2(-50, -32), Vector2(42, 22))
	visible = DisplayServer.is_touchscreen_available() or "--touch" in OS.get_cmdline_user_args()


func _circle(r: float, c: Color) -> Control:
	var p := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = c
	sb.set_corner_radius_all(int(r))
	p.add_theme_stylebox_override("panel", sb)
	p.size = Vector2(r * 2, r * 2)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(p)
	return p


func _button(id: String, text: String, ofs: Vector2, sz: Vector2) -> void:
	var b := Label.new()
	b.text = text
	b.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	b.add_theme_font_size_override("font_size", 8)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.35)
	sb.border_color = Color(1, 1, 1, 0.35)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	b.add_theme_stylebox_override("normal", sb)
	b.size = sz
	b.set_meta("ofs", ofs)
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(b)
	buttons[id] = b


func _process(_d: float) -> void:
	if not visible:
		return
	var vs: Vector2 = get_viewport().get_visible_rect().size
	for id in buttons:
		var b: Control = buttons[id]
		var o: Vector2 = b.get_meta("ofs")
		b.position = Vector2(vs.x + o.x if o.x < 0 else o.x, vs.y + o.y if o.y < 0 else o.y)
	var playing: bool = main != null and main.mode == "play"
	for id in ["use", "run", "light"]:
		buttons[id].visible = playing
	(buttons["run"] as Label).modulate = Color(1, 0.6, 0.5) if run_toggle else Color(1, 1, 1)
	if player != null:
		player.touch_run = run_toggle


func _hit(id: String, pos: Vector2) -> bool:
	var b: Control = buttons[id]
	return b.visible and Rect2(b.position - Vector2(4, 4), b.size + Vector2(8, 8)).has_point(pos)


func release_all() -> void:
	stick_id = -1
	look_id = -1
	stick_base.visible = false
	stick_knob.visible = false
	if player != null:
		player.touch_move = Vector2.ZERO


func _input(e: InputEvent) -> void:
	if not visible or main == null:
		return
	if e is InputEventScreenTouch:
		var pos: Vector2 = e.position
		if e.pressed:
			if main.mode != "play":
				main.on_tap()
				return
			for id in ["pause", "use", "run", "light"]:
				if _hit(id, pos):
					match id:
						"pause": main.toggle_pause()
						"use": main.try_interact()
						"run": run_toggle = not run_toggle
						"light": player.toggle_light()
					get_viewport().set_input_as_handled()
					return
			var vs: Vector2 = get_viewport().get_visible_rect().size
			if pos.x < vs.x * 0.45 and stick_id == -1:
				stick_id = e.index
				stick_origin = pos
				stick_base.visible = true
				stick_knob.visible = true
				stick_base.position = pos - stick_base.size / 2
				stick_knob.position = pos - stick_knob.size / 2
			elif look_id == -1:
				look_id = e.index
				look_last = pos
		else:
			if e.index == stick_id:
				stick_id = -1
				stick_base.visible = false
				stick_knob.visible = false
				if player != null:
					player.touch_move = Vector2.ZERO
			elif e.index == look_id:
				look_id = -1
	elif e is InputEventScreenDrag:
		if e.index == stick_id and player != null:
			var d: Vector2 = (e.position - stick_origin).limit_length(28.0)
			stick_knob.position = stick_origin + d - stick_knob.size / 2
			player.touch_move = d / 28.0
		elif e.index == look_id and player != null:
			player.touch_look += (e.position - look_last) * 4.0
			look_last = e.position
