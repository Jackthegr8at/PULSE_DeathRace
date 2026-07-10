extends Car
## Player-controlled car. Maps input actions to the shared Car API.

@export var camera_enabled: bool = true

@onready var camera: Camera2D = get_node_or_null("Camera2D")


func _ready() -> void:
	super._ready()
	display_name = "Player"
	if body_color == Color(0.3, 0.8, 0.45):
		body_color = Color(0.29, 0.87, 0.5)
		_apply_visuals()
	if camera and camera_enabled:
		camera.enabled = true
		camera.make_current()


func _physics_process(delta: float) -> void:
	if not is_alive or _match_over:
		return

	var throttle := 0.0
	if Input.is_action_pressed("accelerate"):
		throttle += 1.0
	if Input.is_action_pressed("brake"):
		throttle -= 1.0
	set_throttle(throttle)

	var steer := 0.0
	if Input.is_action_pressed("steer_left"):
		steer -= 1.0
	if Input.is_action_pressed("steer_right"):
		steer += 1.0
	set_steer(steer)

	if Input.is_action_just_pressed("fire"):
		try_fire()

	super._physics_process(delta)
