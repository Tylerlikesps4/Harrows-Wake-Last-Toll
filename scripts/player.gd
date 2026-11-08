extends CharacterBody3D
## First-person survivor: walk, run (loud), crouch-walk (quiet), flashlight.
## Keyboard + mouse, gamepad, or the touch layer (touch.gd) on phones.

var main = null
var cam: Camera3D
var flashlight: SpotLight3D
var yaw: float = 0.0
var pitch: float = 0.0
var mouse_sens: float = 0.0025
var hidden: bool = false
var light_on: bool = true
var stamina: float = 100.0
var exhausted: bool = false
var running: bool = false
var sneaking: bool = false
var step_t: float = 0.0
var bob: float = 0.0
# set by touch.gd
var touch_move := Vector2.ZERO
var touch_look := Vector2.ZERO
var touch_run: bool = false

const WALK := 1.9
const RUN := 3.9
const SNEAK := 1.0
const EYE := 1.55


func _ready() -> void:
	collision_layer = 8
	collision_mask = 1 | 2
	var cs := CollisionShape3D.new()
	var sh := CapsuleShape3D.new()
	sh.radius = 0.3
	sh.height = 1.7
	cs.shape = sh
	cs.position.y = 0.85
	add_child(cs)
	cam = Camera3D.new()
	cam.position.y = EYE
	cam.fov = 70.0
	cam.near = 0.05
	cam.far = 40.0
	add_child(cam)
	flashlight = SpotLight3D.new()
	flashlight.light_color = Color(1.0, 0.92, 0.76)
	flashlight.light_energy = 2.6
	flashlight.spot_range = 12.0
	flashlight.spot_angle = 24.0
	flashlight.spot_attenuation = 0.9
	flashlight.shadow_enabled = true
	flashlight.position = Vector3(0.12, -0.15, -0.1)
	cam.add_child(flashlight)


func set_look(y: float, p: float) -> void:
	yaw = y
	pitch = p
	rotation.y = yaw
	cam.rotation.x = pitch


func toggle_light() -> void:
	light_on = not light_on
	flashlight.visible = light_on
	main.play_sfx("flashlight", null, -6.0)


func _unhandled_input(e: InputEvent) -> void:
	if main == null or main.mode != "play":
		return
	if e is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw -= e.relative.x * mouse_sens
		pitch = clampf(pitch - e.relative.y * mouse_sens, -1.3, 1.3)


func _physics_process(delta: float) -> void:
	if main == null or main.mode != "play":
		velocity = Vector3.ZERO
		return
	# look: gamepad right stick + touch drag
	var rs := Input.get_vector("look_left", "look_right", "look_up", "look_down")
	yaw -= rs.x * 2.6 * delta + touch_look.x * 0.006
	pitch = clampf(pitch - rs.y * 1.8 * delta - touch_look.y * 0.006, -1.3, 1.3)
	touch_look = Vector2.ZERO
	rotation.y = yaw
	cam.rotation.x = pitch

	var mv := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if touch_move.length() > 0.05:
		mv = touch_move
	sneaking = Input.is_action_pressed("sneak")
	var want_run: bool = (Input.is_action_pressed("run") or touch_run) and mv.length() > 0.1 and not sneaking
	if exhausted and stamina > 35.0:
		exhausted = false
	running = want_run and not exhausted
	if running:
		stamina -= 22.0 * delta
		if stamina <= 0.0:
			stamina = 0.0
			exhausted = true
			main.play_sfx("breath", null, -4.0)
	else:
		stamina = minf(100.0, stamina + 14.0 * delta)
	var speed: float = RUN if running else (SNEAK if sneaking else WALK)
	var dir := (transform.basis * Vector3(mv.x, 0, mv.y))
	dir.y = 0
	if dir.length() > 1.0:
		dir = dir.normalized()
	var target := dir * speed
	var hv := Vector3(velocity.x, 0, velocity.z).lerp(target, minf(1.0, delta * 10.0))
	velocity = Vector3(hv.x, -2.0, hv.z)
	move_and_slide()

	var moving := hv.length() > 0.3
	if moving:
		bob += delta * hv.length() * 3.4
		step_t -= delta * hv.length()
		if step_t <= 0.0:
			step_t = 1.25
			var vol := -4.0 if running else (-22.0 if sneaking else -12.0)
			main.play_step(global_position, vol)
			# running is heard across the building; walking only nearby
			main.make_noise(global_position, 11.0 if running else (0.0 if sneaking else 3.0))
	cam.position.y = EYE + (sin(bob * 2.0) * 0.035 if moving else 0.0) - (0.35 if sneaking else 0.0)
