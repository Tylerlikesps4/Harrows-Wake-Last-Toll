extends Node3D
## Animated character on Quaternius' CC0 mannequins (Universal Animation Library).
## Clothes are baked into vertex colours, PSX shader on top, and it interpolates
## after its physics body so it stays smooth on 90/120 Hz screens.

const PSX_SHADER := preload("res://shaders/psx.gdshader")
const BASE := "res://assets/models/mannequin.glb"
const ZOMBIE := "res://assets/models/mannequin_zombie.glb"

var style: String = "jenny"
var anim: AnimationPlayer = null
var skel: Skeleton3D = null
var body: Node3D = null
var cur_anim: String = ""
var _prev: Transform3D
var _cur: Transform3D
var _have: bool = false
var lean: float = 0.0          # extra pitch used for stagger / stun poses
var y_off: float = 0.0
var inner: Node3D = null
var extras: Dictionary = {}    # named attachments (gun, bell, ...)

static var _mesh_cache: Dictionary = {}


func setup(p_style: String, p_body: Node3D) -> void:
	style = p_style
	body = p_body
	top_level = true
	inner = Node3D.new()
	inner.rotation.y = PI  # glTF faces +Z, Godot actors face -Z
	add_child(inner)
	var src: String = ZOMBIE if style == "tallow" else BASE
	var sc: Node3D = load(src).instantiate()
	inner.add_child(sc)
	anim = sc.get_node("AnimationPlayer")
	skel = sc.find_child("Skeleton3D", true, false)
	var mi: MeshInstance3D = sc.find_child("Mannequin", true, false)
	match style:
		"jenny":
			inner.scale = Vector3(0.86, 0.86, 0.86)
		"dana":
			inner.scale = Vector3(0.97, 0.97, 0.97)
		"bellman":
			inner.scale = Vector3(1.0, 1.27, 1.0) * 1.04
		"tallow":
			inner.scale = Vector3(1.12, 0.98, 1.12)
	if mi != null:
		mi.mesh = _baked_mesh(mi.mesh, style)
		var m := ShaderMaterial.new()
		m.shader = PSX_SHADER
		m.set_shader_parameter("albedo_tex", load("res://assets/tex/dirty_carpet.png"))
		m.set_shader_parameter("use_vcolor", true)
		m.set_shader_parameter("tex_mix", 0.35 if style != "tallow" else 0.6)
		m.set_shader_parameter("uv_scale", 3.0)
		m.set_shader_parameter("albedo_color", Color(1, 1, 1))
		for i in mi.mesh.get_surface_count():
			mi.set_surface_override_material(i, m)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_accessories()
	_face()
	play_anim(idle_name())


func idle_name() -> String:
	match style:
		"tallow":
			return "Zombie_Idle"
		"bellman":
			return "Idle_Torch"
	return "Idle"


func play_anim(n: String, blend: float = 0.2, spd: float = 1.0) -> void:
	if anim == null or not anim.has_animation(n):
		return
	anim.speed_scale = spd
	if n == cur_anim and anim.is_playing():
		return
	cur_anim = n
	anim.play(n, blend)


func play_once(n: String, blend: float = 0.1, spd: float = 1.0) -> void:
	if anim == null or not anim.has_animation(n):
		return
	cur_anim = n
	anim.speed_scale = spd
	anim.play(n, blend)
	anim.seek(0.0, true)


func anim_length(n: String) -> float:
	if anim == null or not anim.has_animation(n):
		return 0.0
	return anim.get_animation(n).length


func _physics_process(_d: float) -> void:
	if body == null:
		return
	_prev = _cur if _have else body.global_transform
	_cur = body.global_transform
	_have = true


func snap() -> void:
	if body != null:
		_cur = body.global_transform
		_prev = _cur
		_have = true
		global_transform = _cur


func _process(_d: float) -> void:
	if body == null or not _have:
		return
	var f: float = Engine.get_physics_interpolation_fraction()
	var t: Transform3D = _prev.interpolate_with(_cur, f)
	# teleports (room change, survivor swap) snap instead of sliding
	if _prev.origin.distance_to(_cur.origin) > 2.0:
		t = _cur
	global_transform = t
	inner.rotation.x = lean
	inner.position.y = y_off
	visible = body.visible


# ------------------------------------------------------------ clothing bake

static func _region_color(st: String, p: Vector3, front: float, rng: float) -> Color:
	var v: float = p.y / 1.83
	var ax: float = absf(p.x)
	var fz: float = p.z * front           # > 0 = front of the body
	var skin := Color(0.78, 0.6, 0.5)
	var is_arm: bool = ax > 0.2 and v > 0.66
	var is_hand: bool = ax > 0.70 and v > 0.66
	var is_head: bool = v > 0.835 and not is_arm
	var c := Color(0.5, 0.5, 0.5)
	match st:
		"jenny":
			# Pale nightgown to the knee, cardigan sleeves, dark long hair.
			skin = Color(0.86, 0.7, 0.62)
			if is_hand:
				c = skin
			elif is_arm:
				c = Color(0.36, 0.28, 0.34) if ax < 0.62 else skin
			elif is_head:
				c = skin
				if v > 0.955 or (fz < 0.02 and v > 0.85) or (ax > 0.06 and v > 0.88):
					c = Color(0.16, 0.1, 0.07)
			elif v > 0.74 and fz < -0.02 and ax < 0.17:
				c = Color(0.16, 0.1, 0.07)       # hair down the back
			elif v > 0.3:
				c = Color(0.74, 0.76, 0.8)       # nightgown
				if v < 0.34:
					c = Color(0.6, 0.6, 0.66)
			elif v < 0.05:
				c = Color(0.3, 0.2, 0.18)        # slippers
			else:
				c = skin
		"dana":
			# Navy police shirt, dark trousers, black boots, short brown hair.
			if is_hand:
				c = skin
			elif is_arm:
				c = Color(0.16, 0.2, 0.34)
			elif is_head:
				c = skin
				if v > 0.965 or (fz < -0.01 and v > 0.87) or (ax > 0.07 and v > 0.92):
					c = Color(0.22, 0.13, 0.08)
			elif v > 0.49:
				c = Color(0.16, 0.2, 0.34)
				if v > 0.5 and v < 0.53:
					c = Color(0.05, 0.05, 0.05)  # duty belt
				if fz > 0.05 and v > 0.7 and v < 0.74 and p.x * front > 0.04:
					c = Color(0.85, 0.7, 0.3)    # badge
			elif v < 0.06:
				c = Color(0.04, 0.04, 0.04)
			else:
				c = Color(0.09, 0.09, 0.11)
		"bellman":
			# Long black undertaker's coat to the shins, grey-white dead skin.
			skin = Color(0.72, 0.72, 0.68)
			if is_hand:
				c = Color(0.62, 0.6, 0.55)
			elif is_arm:
				c = Color(0.06, 0.05, 0.05)
			elif is_head:
				c = skin
				if fz > 0.0 and v > 0.915 and v < 0.94 and absf(p.x) > 0.015 and absf(p.x) < 0.07:
					c = Color(0.02, 0.02, 0.02)  # hollow eyes
				if fz > 0.0 and v > 0.86 and v < 0.875 and absf(p.x) < 0.05:
					c = Color(0.25, 0.08, 0.08)  # sewn mouth
			elif v > 0.17:
				c = Color(0.07, 0.06, 0.06)
				if v > 0.8:
					c = Color(0.55, 0.53, 0.5)   # stiff collar
			else:
				c = Color(0.03, 0.03, 0.03)
		"tallow":
			# Melted candle-wax skin with darker drips and torn grey clothes.
			var wax := Color(0.86, 0.78, 0.58).lerp(Color(0.62, 0.48, 0.34), rng)
			c = wax
			if v > 0.3 and v < 0.78 and not is_arm and rng > 0.45:
				c = Color(0.3, 0.3, 0.28)
			if v < 0.3 and rng > 0.3:
				c = Color(0.22, 0.2, 0.18)
			if is_head and fz > 0.0 and v > 0.915 and v < 0.94 and absf(p.x) > 0.015 and absf(p.x) < 0.07:
				c = Color(0.12, 0.04, 0.02)
	return c


static func _baked_mesh(src: Mesh, st: String) -> Mesh:
	var key := st
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var out := ArrayMesh.new()
	# work out which way is front from the toes
	var zsum := 0.0
	var zn := 0
	for s in src.get_surface_count():
		var arr: Array = src.surface_get_arrays(s)
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		for vtx in verts:
			if vtx.y < 0.05:
				zsum += vtx.z
				zn += 1
	var front: float = 1.0 if (zn == 0 or zsum / zn >= 0.0) else -1.0
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(st)
	for s in src.get_surface_count():
		var arr: Array = src.surface_get_arrays(s)
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var cols := PackedColorArray()
		cols.resize(verts.size())
		for i in verts.size():
			var p: Vector3 = verts[i]
			var n := fposmod(sin(p.x * 41.0 + p.y * 17.0) * 43758.5 + cos(p.z * 29.0) * 1531.0, 1.0)
			var c := _region_color(st, p, front, n)
			c = c.darkened(n * 0.12)
			cols[i] = c
		arr[Mesh.ARRAY_COLOR] = cols
		var flags := 0
		var bones = arr[Mesh.ARRAY_BONES]
		if bones != null and bones is PackedInt32Array and verts.size() > 0 and bones.size() == verts.size() * 8:
			flags = Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr, [], {}, flags)
	_mesh_cache[key] = out
	return out


# ------------------------------------------------------------ attachments

func _mat(col: Color, emission: float = 0.0, texname: String = "rusty_metal_02") -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = PSX_SHADER
	m.set_shader_parameter("albedo_tex", load("res://assets/tex/%s.png" % texname))
	m.set_shader_parameter("albedo_color", col)
	m.set_shader_parameter("emission", emission)
	m.set_shader_parameter("tex_mix", 0.4)
	return m


func _attach(bone: String, nm: String) -> BoneAttachment3D:
	if skel == null or skel.find_bone(bone) < 0:
		return null
	var ba := BoneAttachment3D.new()
	ba.name = nm
	ba.bone_name = bone
	skel.add_child(ba)
	return ba


func _mesh(parent: Node3D, mesh: Mesh, pos: Vector3, mat: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi


static func _cyl(top: float, bottom: float, h: float, segs: int = 8) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = h
	c.radial_segments = segs
	c.rings = 0
	return c


static func _box(s: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = s
	return b


func _accessories() -> void:
	var head := "Head" if style == "tallow" else "DEF-head"
	var hand_r := "hand_r" if style == "tallow" else "DEF-hand.R"
	var hand_l := "hand_l" if style == "tallow" else "DEF-hand.L"
	match style:
		"bellman":
			var h := _attach(head, "Hat")
			if h:
				var hm := _mat(Color(0.05, 0.045, 0.04), 0.0, "dirty_carpet")
				_mesh(h, _cyl(0.3, 0.3, 0.02, 10), Vector3(0, 0.2, 0), hm)
				_mesh(h, _cyl(0.13, 0.15, 0.24, 8), Vector3(0, 0.32, 0), hm)
				# faint eye-shine so he reads in the dark
				var em := _mat(Color(1.0, 0.85, 0.55), 3.0, "plastered_wall_02")
				for sx in [-0.03, 0.03]:
					var s := SphereMesh.new()
					s.radius = 0.014
					s.height = 0.028
					s.radial_segments = 4
					s.rings = 2
					_mesh(h, s, Vector3(sx, 0.118, 0.118), em)
				extras["eyes"] = em
			var b := _attach(hand_l, "Bell")
			if b:
				var bm := _mat(Color(0.85, 0.65, 0.3), 0.15)
				_mesh(b, _cyl(0.025, 0.08, 0.13, 8), Vector3(0, 0.18, 0), bm, Vector3(PI, 0, 0))
				_mesh(b, _cyl(0.015, 0.015, 0.14, 4), Vector3(0, 0.07, 0), _mat(Color(0.25, 0.15, 0.08), 0.0, "dark_wooden_planks"))
				extras["bell"] = b
			var sh := _attach(hand_r, "Shears")
			if sh:
				var sm := _mat(Color(0.7, 0.7, 0.72), 0.1)
				_mesh(sh, _box(Vector3(0.02, 0.55, 0.035)), Vector3(0.01, 0.3, 0.02), sm, Vector3(0, 0, 0.06))
				_mesh(sh, _box(Vector3(0.02, 0.55, 0.035)), Vector3(-0.01, 0.3, 0.02), sm, Vector3(0, 0, -0.06))
		"dana":
			var g := _attach(hand_r, "Gun")
			if g:
				var gm := _mat(Color(0.12, 0.12, 0.13), 0.0)
				_mesh(g, _box(Vector3(0.04, 0.2, 0.06)), Vector3(0.0, 0.12, 0.05), gm)
				_mesh(g, _box(Vector3(0.035, 0.05, 0.12)), Vector3(0.0, 0.05, 0.0), gm)
				extras["gun"] = g
				g.visible = false
		"tallow":
			# Fused wax lumps: a second half-melted head and shoulder masses.
			var wm := _mat(Color(0.8, 0.7, 0.5), 0.05, "damaged_plaster")
			var sp := _attach("spine_03", "Lumps")
			if sp:
				for d in [[Vector3(0.18, 0.18, -0.08), 0.17], [Vector3(-0.2, 0.08, -0.1), 0.14], [Vector3(0.05, 0.3, -0.14), 0.12]]:
					var s := SphereMesh.new()
					s.radius = d[1]
					s.height = d[1] * 1.7
					s.radial_segments = 6
					s.rings = 3
					_mesh(sp, s, d[0], wm)


# ------------------------------------------------------------ faces
# 32x40 painted faces on a quad stuck to the head bone, PS1 style.
# row 0 = +0.19 m, row 40 = -0.03 m (eyes ~13, mouth ~31)

static var _face_cache: Dictionary = {}


static func _px(img: Image, x: int, y: int, c: Color) -> void:
	if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
		img.set_pixel(x, y, c)


static func _rectpx(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	for yy in h:
		for xx in w:
			_px(img, x + xx, y + yy, c)


static func face_image(st: String) -> Image:
	var img := Image.create(32, 40, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var dark := Color(0.08, 0.05, 0.04)
	var white := Color(0.86, 0.84, 0.8)
	match st:
		"jenny", "dana":
			var brow := Color(0.16, 0.1, 0.07) if st == "jenny" else Color(0.2, 0.12, 0.07)
			var iris := Color(0.22, 0.3, 0.38) if st == "jenny" else Color(0.26, 0.17, 0.1)
			var lip := Color(0.62, 0.32, 0.32) if st == "jenny" else Color(0.5, 0.3, 0.27)
			var shade := Color(0.55, 0.4, 0.36, 1.0) if st == "jenny" else Color(0.52, 0.38, 0.32, 1.0)
			for ex in [9, 19]:
				_rectpx(img, ex, 12, 4, 2, white)       # eye whites
				_rectpx(img, ex + 1, 12, 2, 2, iris)   # iris
				_px(img, ex + 1, 12, dark)              # pupil
				_rectpx(img, ex, 11, 4, 1, dark)       # lash line
				_rectpx(img, ex - (1 if st == "dana" else 0), 8, 5, 1 if st == "jenny" else 2, brow)
				_rectpx(img, ex, 14, 4, 1, shade)      # tired under-eyes
			_rectpx(img, 15, 17, 1, 6, shade)          # nose ridge shadow
			_rectpx(img, 14, 23, 3, 1, shade)
			_rectpx(img, 13, 29, 6, 1, lip)
			_rectpx(img, 14, 30, 4, 1, lip.darkened(0.25))
			if st == "jenny":
				_rectpx(img, 6, 22, 3, 2, Color(0.82, 0.55, 0.5))   # cold-flushed cheeks
				_rectpx(img, 23, 22, 3, 2, Color(0.82, 0.55, 0.5))
				# a few strands of fringe over the brow
				for x in [8, 9, 12, 13, 17, 21, 22]:
					_rectpx(img, x, 3, 1, 4 + (x % 3), brow)
		"bellman":
			# cracked porcelain mask, mouth sewn shut
			var mask := Color(0.88, 0.86, 0.8)
			for y in 40:
				for x in 32:
					var dx := (x + 0.5 - 16.0) / 13.0
					var dy := (y + 0.5 - 19.0) / 19.5
					if dx * dx + dy * dy <= 1.0:
						var c := mask.darkened(0.06 * float((x * 7 + y * 13) % 3))
						if dx * dx + dy * dy > 0.82:
							c = c.darkened(0.35)
						img.set_pixel(x, y, c)
			for ex in [8, 19]:
				_rectpx(img, ex, 11, 5, 4, Color(0.01, 0.01, 0.01))
				_rectpx(img, ex + 1, 15, 3, 1, Color(0.3, 0.05, 0.05))   # weeping red
				_rectpx(img, ex + 2, 16, 1, 3, Color(0.35, 0.04, 0.04))
			_rectpx(img, 9, 30, 14, 1, Color(0.12, 0.03, 0.03))         # seam
			for x in range(10, 23, 3):
				_rectpx(img, x, 28, 1, 5, Color(0.02, 0.02, 0.02))     # stitches
			# crack from the brow down the cheek
			for i in 12:
				_px(img, 22 + int(i * 0.4), 2 + i * 2, Color(0.25, 0.22, 0.2))
				_px(img, 22 + int(i * 0.4), 3 + i * 2, Color(0.25, 0.22, 0.2))
		"tallow":
			# melted face: uneven sockets, gaping mouth, drips
			var sock := Color(0.12, 0.05, 0.02)
			_rectpx(img, 8, 12, 5, 4, sock)
			_rectpx(img, 9, 16, 3, 3, sock)
			_rectpx(img, 19, 15, 5, 3, sock)
			_rectpx(img, 20, 18, 2, 4, sock)
			_px(img, 10, 13, Color(0.9, 0.85, 0.5))
			_rectpx(img, 12, 26, 8, 6, Color(0.1, 0.03, 0.02))
			_rectpx(img, 13, 32, 5, 3, Color(0.1, 0.03, 0.02))
			for x in [7, 14, 24]:
				_rectpx(img, x, 20, 2, 12, Color(0.55, 0.42, 0.28))
	return img


func _face() -> void:
	var head := "Head" if style == "tallow" else "DEF-head"
	var ba := _attach(head, "Face")
	if ba == null:
		return
	if not _face_cache.has(style):
		var m := StandardMaterial3D.new()
		m.albedo_texture = ImageTexture.create_from_image(face_image(style))
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		m.alpha_scissor_threshold = 0.5
		m.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
		m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
		if style == "bellman":
			m.emission_enabled = true
			m.emission_texture = m.albedo_texture
			m.emission = Color(1, 1, 1)
			m.emission_energy_multiplier = 0.18
		_face_cache[style] = m
	var q := QuadMesh.new()
	q.size = Vector2(0.17, 0.22) if style != "bellman" else Vector2(0.19, 0.24)
	var mi := MeshInstance3D.new()
	mi.mesh = q
	mi.material_override = _face_cache[style]
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = Vector3(0, 0.08, 0.121 if style != "bellman" else 0.128)
	mi.rotation.x = -0.12   # follow the brow's slope a little
	ba.add_child(mi)
	extras["face"] = mi
