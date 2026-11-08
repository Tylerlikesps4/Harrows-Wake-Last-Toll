class_name Lib
extends RefCounted
## Asset helpers: PSX materials from the CC0 texture set, and CC0 props
## (Kenney Furniture Kit / Graveyard Kit) re-skinned with the PSX shader.

const PSX_SHADER := preload("res://shaders/psx.gdshader")

static var _tex: Dictionary = {}
static var _mat: Dictionary = {}
static var _scenes: Dictionary = {}

# Kenney material name -> (texture, tint). Bright toy colours become grimy.
const PROP_LOOK := {
	"wood": ["dark_wooden_planks", Color(0.75, 0.55, 0.42)],
	"woodDark": ["dark_wooden_planks", Color(0.45, 0.33, 0.26)],
	"carpet": ["dirty_carpet", Color(0.55, 0.22, 0.2)],
	"carpetWhite": ["plastered_wall_02", Color(0.62, 0.6, 0.55)],
	"carpetBlue": ["dirty_carpet", Color(0.25, 0.3, 0.42)],
	"carpetDarker": ["dirty_carpet", Color(0.3, 0.25, 0.22)],
	"metal": ["rusty_metal_02", Color(0.55, 0.57, 0.55)],
	"metalMedium": ["rusty_metal_02", Color(0.35, 0.37, 0.36)],
	"metalDark": ["rusty_metal_02", Color(0.2, 0.2, 0.2)],
	"fur": ["dirty_carpet", Color(0.55, 0.4, 0.28)],
	"lamp": ["plastered_wall_02", Color(1.0, 0.9, 0.6)],
	"glass": ["plastered_wall_02", Color(0.3, 0.35, 0.38)],
	"plant": ["dirty_carpet", Color(0.25, 0.3, 0.18)],
	"paper": ["plastered_wall_02", Color(0.8, 0.78, 0.7)],
}


static func tex(name: String) -> Texture2D:
	if _tex.has(name):
		return _tex[name]
	var t: Texture2D = load("res://assets/tex/%s.png" % name)
	_tex[name] = t
	return t


static func mat(texname: String, col: Color, world: bool = true, wscale: float = 0.5, emission: float = 0.0, tex_mix: float = 1.0) -> ShaderMaterial:
	var key := "%s_%s_%s_%.2f_%.2f_%.2f" % [texname, col.to_html(), world, wscale, emission, tex_mix]
	if _mat.has(key):
		return _mat[key]
	var m := ShaderMaterial.new()
	m.shader = PSX_SHADER
	m.set_shader_parameter("albedo_tex", tex(texname))
	m.set_shader_parameter("albedo_color", col)
	m.set_shader_parameter("world_uv", world)
	m.set_shader_parameter("world_scale", wscale)
	m.set_shader_parameter("emission", emission)
	m.set_shader_parameter("tex_mix", tex_mix)
	_mat[key] = m
	return m


static func _psxify(n: Node, colormap: bool, tint: Color) -> void:
	if n is MeshInstance3D:
		var mi: MeshInstance3D = n
		for i in mi.mesh.get_surface_count():
			var src: Material = mi.mesh.surface_get_material(i)
			var nm: String = src.resource_name if src != null else ""
			var m: ShaderMaterial
			if colormap:
				var key := "colormap_%s" % tint.to_html()
				if _mat.has(key):
					m = _mat[key]
				else:
					m = ShaderMaterial.new()
					m.shader = PSX_SHADER
					var tx: Texture2D = null
					if src is BaseMaterial3D:
						tx = (src as BaseMaterial3D).albedo_texture
					m.set_shader_parameter("albedo_tex", tx)
					m.set_shader_parameter("albedo_color", tint)
					m.set_shader_parameter("tex_mix", 1.0)
					_mat[key] = m
			else:
				var look: Array = PROP_LOOK.get(nm, [])
				if look.is_empty():
					var c := Color(0.5, 0.5, 0.5)
					if src is BaseMaterial3D:
						c = (src as BaseMaterial3D).albedo_color.darkened(0.35)
					look = ["plastered_wall_02", c]
				var e := 0.6 if nm == "lamp" else 0.0
				m = mat(look[0], look[1] * tint, true, 1.2, e, 0.8)
			mi.set_surface_override_material(i, m)
	for c in n.get_children():
		_psxify(c, colormap, tint)


static func _aabb(n: Node, xf: Transform3D, acc: Array) -> void:
	if n is Node3D:
		xf = xf * (n as Node3D).transform
	if n is MeshInstance3D:
		var b: AABB = xf * (n as MeshInstance3D).get_aabb()
		if acc.is_empty():
			acc.append(b)
		else:
			acc[0] = (acc[0] as AABB).merge(b)
	for c in n.get_children():
		_aabb(c, xf, acc)


## Places a prop centred on pos (floor at pos.y). size is the target length
## along its longest horizontal axis in metres; negative means uniform scale.
## Returns the pivot node.
static func prop(parent: Node3D, name: String, pos: Vector3, rot_y: float = 0.0, size: float = -2.0, collide_layer: int = 2, tint := Color(1, 1, 1), by_height: bool = false) -> Node3D:
	var path := "res://assets/props/%s.glb" % name
	if not _scenes.has(path):
		_scenes[path] = load(path)
	var ps: PackedScene = _scenes[path]
	if ps == null:
		return null
	var inst: Node3D = ps.instantiate()
	_psxify(inst, name.begins_with("gy_"), tint)
	var acc: Array = []
	_aabb(inst, Transform3D.IDENTITY, acc)
	var bb: AABB = acc[0] if not acc.is_empty() else AABB(Vector3.ZERO, Vector3.ONE)
	var sc: float = -size
	if size > 0.0:
		sc = size / maxf(0.01, bb.size.y if by_height else maxf(bb.size.x, bb.size.z))
	var pivot := Node3D.new()
	pivot.name = name
	parent.add_child(pivot)
	pivot.position = pos
	pivot.rotation.y = rot_y
	pivot.scale = Vector3.ONE * sc
	inst.position = -Vector3(bb.position.x + bb.size.x / 2.0, bb.position.y, bb.position.z + bb.size.z / 2.0)
	pivot.add_child(inst)
	if collide_layer > 0:
		var sb := StaticBody3D.new()
		sb.collision_layer = collide_layer
		sb.collision_mask = 0
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = Vector3(maxf(0.05, bb.size.x * 0.92), bb.size.y, maxf(0.05, bb.size.z * 0.92))
		cs.shape = sh
		cs.position = Vector3(0, bb.size.y / 2.0, 0)
		sb.add_child(cs)
		pivot.add_child(sb)
	pivot.set_meta("size", bb.size * sc)
	return pivot
