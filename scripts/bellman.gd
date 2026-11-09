extends CharacterBody3D
## The Bellman: stalks the orphanage on a grid, rings his hand bell as he walks
## (faster when he is hunting), turns towards noises and chases on sight.
## Ported from the day-0 C# version (csharp/Bellman.cs) with the same behaviour,
## so the whole project is plain GDScript and can export to the web.

const DIRS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

var state := "dormant" # dormant, wander, investigate, chase, search
var walk_speed := 1.35
var chase_speed := 3.15
var catch_range := 1.05
var sight_range := 13.0

var grid: Array = [] # Array of rows, each an Array of one-char Strings
var cell := 2.0
var player: Node3D
var main: Node
var path: Array[Vector3] = []
var goal := Vector3.ZERO
var last_seen := Vector3.ZERO
var repath_t := 0.0
var bell_t := 0.0
var lost_t := 0.0
var search_t := 0.0
var idle_t := 0.0
var rng := RandomNumberGenerator.new()
var bell: AudioStreamPlayer3D
var body: Node3D


func setup(rows, cell_size: float, player_node: Node3D, main_node: Node, bell_stream: AudioStream) -> void:
	grid.clear()
	for r in rows:
		var chars := []
		for i in String(r).length():
			chars.append(String(r)[i])
		grid.append(chars)
	cell = cell_size
	player = player_node
	main = main_node
	rng.randomize()
	collision_layer = 4
	collision_mask = 1
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 2.1
	cs.shape = cap
	cs.position = Vector3(0, 1.05, 0)
	add_child(cs)
	_build_body()
	bell = AudioStreamPlayer3D.new()
	bell.stream = bell_stream
	bell.unit_size = 4.0
	bell.max_distance = 40.0
	bell.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	bell.position = Vector3(0.45, 1.1, 0)
	bell.bus = "SFX"
	add_child(bell)


func _mat(col: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	return m


func _cyl(top: float, bottom: float, h: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = h
	c.radial_segments = 8
	return c


func _part(mesh: Mesh, mat: Material, pos: Vector3) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	body.add_child(mi)


## Greybox body: a tall coat, a pale mask and the hand bell. Real model later.
func _build_body() -> void:
	body = Node3D.new()
	add_child(body)
	var coat := _mat(Color(0.07, 0.06, 0.06))
	var mask := _mat(Color(0.85, 0.82, 0.74))
	mask.emission_enabled = true
	mask.emission = Color(0.12, 0.11, 0.1)
	var brass := _mat(Color(0.55, 0.42, 0.18))
	brass.metallic = 0.6
	_part(_cyl(0.22, 0.42, 1.75), coat, Vector3(0, 0.875, 0))
	var head := BoxMesh.new()
	head.size = Vector3(0.3, 0.38, 0.26)
	_part(head, mask, Vector3(0, 1.98, -0.02))
	_part(_cyl(0.2, 0.2, 0.32), coat, Vector3(0, 2.3, 0))
	_part(_cyl(0.36, 0.36, 0.03), coat, Vector3(0, 2.15, 0))
	_part(_cyl(0.04, 0.12, 0.18), brass, Vector3(0.45, 1.05, -0.1))


func wake() -> void:
	if state == "dormant":
		state = "wander"
		_pick_wander()


func rest() -> void:
	state = "dormant"
	path.clear()
	velocity = Vector3.ZERO


func set_cell(x: int, y: int, ch: String) -> void:
	if y >= 0 and y < grid.size() and x >= 0 and x < grid[y].size() and ch.length() > 0:
		var row: Array = grid[y]
		row[x] = ch[0]


func hear(pos: Vector3, radius: float) -> void:
	if state == "dormant" or state == "chase":
		return
	if global_position.distance_to(pos) > radius:
		return
	state = "investigate"
	_go_to(pos)


# ------------------------------------------------------------- grid
func walkable(x: int, y: int) -> bool:
	if y < 0 or y >= grid.size() or x < 0 or x >= grid[y].size():
		return false
	var ch: String = grid[y][x]
	return ch != "#" and ch != "L" and ch != " "


func cell_of(p: Vector3) -> Vector2i:
	return Vector2i(floori(p.x / cell), floori(p.z / cell))


func center(c: Vector2i) -> Vector3:
	return Vector3(c.x * cell + cell / 2.0, 0, c.y * cell + cell / 2.0)


func path_length_to(to: Vector3) -> int:
	var p = _bfs(cell_of(global_position), cell_of(to))
	return -1 if p == null else p.size()


func _bfs(from: Vector2i, to: Vector2i):
	if not walkable(to.x, to.y):
		return null
	var prev := {from: from}
	var q: Array[Vector2i] = [from]
	var head := 0
	while head < q.size():
		var c: Vector2i = q[head]
		head += 1
		if c == to:
			break
		for d in DIRS:
			var n: Vector2i = c + d
			if not walkable(n.x, n.y) or prev.has(n):
				continue
			prev[n] = c
			q.append(n)
	if not prev.has(to):
		return null
	var res: Array[Vector2i] = []
	var cur := to
	while cur != from:
		res.append(cur)
		cur = prev[cur]
	res.reverse()
	return res


func _go_to(p: Vector3) -> void:
	goal = p
	path.clear()
	var cells = _bfs(cell_of(global_position), cell_of(p))
	if cells == null:
		return
	for c in cells:
		path.append(center(c))
	if path.size() > 0:
		path[path.size() - 1] = Vector3(p.x, 0, p.z)


## Wandering stays loosely near the player so the bell never goes quiet for long.
func _pick_wander() -> void:
	var pc := cell_of(player.global_position)
	for tries in 40:
		var x: int
		var y: int
		if rng.randf() < 0.55:
			x = pc.x + rng.randi_range(-6, 6)
			y = pc.y + rng.randi_range(-5, 5)
		else:
			y = rng.randi_range(0, grid.size() - 1)
			x = rng.randi_range(0, grid[y].size() - 1)
		if walkable(x, y) and Vector2i(x, y) != cell_of(global_position):
			_go_to(center(Vector2i(x, y)))
			if path.size() > 0:
				return


# ------------------------------------------------------------- senses
func can_see_player() -> bool:
	if player == null or player.get("hidden"):
		return false
	var eye := global_position + Vector3(0, 1.9, 0)
	var target := player.global_position + Vector3(0, 1.4, 0)
	var d := eye.distance_to(target)
	var lit: bool = player.get("light_on")
	var rng_max := sight_range * 1.4 if lit else sight_range
	if d > rng_max:
		return false
	var fwd := -global_transform.basis.z
	var to := (target - eye).normalized()
	if d > 2.5 and fwd.dot(to) < 0.35:
		return false
	var q := PhysicsRayQueryParameters3D.create(eye, target, 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	return hit.is_empty()


func _physics_process(delta: float) -> void:
	var dt := delta
	if state == "dormant" or player == null:
		return
	if main.get("mode") != "play":
		velocity = Vector3.ZERO
		return
	var sees := can_see_player()
	if sees:
		last_seen = player.global_position
		lost_t = 0.0
		if state != "chase":
			state = "chase"
			main.call("on_chase_start")

	match state:
		"chase":
			repath_t -= dt
			if repath_t <= 0.0:
				repath_t = 0.35
				_go_to(player.global_position if sees else last_seen)
			if not sees:
				lost_t += dt
				if lost_t > 3.0:
					state = "search"
					search_t = 7.0
					_go_to(last_seen)
					main.call("on_chase_end")
		"search":
			search_t -= dt
			if path.is_empty() and search_t > 0.0:
				var c := cell_of(last_seen) + Vector2i(rng.randi_range(-2, 2), rng.randi_range(-2, 2))
				if walkable(c.x, c.y):
					_go_to(center(c))
			if search_t <= 0.0:
				state = "wander"
				_pick_wander()
		_:
			if path.is_empty():
				idle_t += dt
				if idle_t > 1.2:
					idle_t = 0.0
					state = "wander"
					_pick_wander()

	var speed := chase_speed if state == "chase" else walk_speed
	var v := Vector3.ZERO
	if path.size() > 0:
		var next: Vector3 = path[0]
		var flat := Vector3(next.x - global_position.x, 0, next.z - global_position.z)
		if flat.length() < 0.25:
			path.remove_at(0)
		else:
			v = flat.normalized() * speed
	velocity = Vector3(v.x, 0, v.z)
	move_and_slide()
	if v.length_squared() > 0.01:
		var target_yaw := atan2(-v.x, -v.z)
		rotation = Vector3(0, lerp_angle(rotation.y, target_yaw, minf(1.0, dt * 8.0)), 0)
	if body != null:
		var moving := v.length_squared() > 0.01
		body.position = Vector3(0, absf(sin(Time.get_ticks_msec() * 0.006)) * (0.04 if moving else 0.0), 0)

	# The hand bell: slow, patient rings while he walks; frantic in a chase.
	bell_t -= dt
	if bell_t <= 0.0:
		bell_t = rng.randf_range(0.4, 0.6) if state == "chase" else rng.randf_range(1.4, 2.2)
		bell.pitch_scale = rng.randf_range(0.92, 1.06)
		bell.volume_db = 2.0 if state == "chase" else -2.0
		bell.play()

	var pd := global_position.distance_to(Vector3(player.global_position.x, global_position.y, player.global_position.z))
	if pd < catch_range and not player.get("hidden"):
		main.call("caught")
