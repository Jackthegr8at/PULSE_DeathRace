extends Car
## Basic AI: follow track Path2D with look-ahead and shoot cars in a forward cone.

@export_group("AI Pathing")
@export var path_look_ahead: float = 110.0 ## Pixels ahead along the path
@export var path_repath_rate: float = 0.05
@export var arrive_throttle: float = 0.72 ## Not full send — easier for player to read
@export var corner_speed_factor: float = 0.4

@export_group("AI Combat")
@export var detect_range: float = 380.0
@export var fire_cone_degrees: float = 28.0
@export var aim_dot_min: float = 0.88 ## Cosine threshold for "facing" target

var race_path: Path2D = null
var _path_length: float = 0.0
var _progress: float = 0.0
var _think_timer: float = 0.0


func _ready() -> void:
	super._ready()
	if display_name == "Car":
		display_name = "AI"


func setup_ai(path: Path2D, color: Color, name_label: String) -> void:
	race_path = path
	body_color = color
	display_name = name_label
	_apply_visuals()
	if race_path and race_path.curve:
		_path_length = race_path.curve.get_baked_length()
		# Snap progress to nearest path point so AI doesn't cut across first
		_progress = _nearest_offset(global_position)


func _physics_process(delta: float) -> void:
	if not is_alive or _match_over:
		return

	_think_timer -= delta
	if _think_timer <= 0.0:
		_think_timer = path_repath_rate
		_update_driving()
		_update_combat()

	super._physics_process(delta)


func _update_driving() -> void:
	if race_path == null or race_path.curve == null or _path_length <= 0.0:
		set_throttle(0.3)
		set_steer(0.0)
		return

	# Advance progress roughly with current speed for smoother chase
	_progress = fmod(_progress + maxf(velocity.length(), 80.0) * path_repath_rate * 0.35, _path_length)
	# Prefer tracking near car projection
	var near := _nearest_offset(global_position)
	# Blend so we don't snap violently
	if absf(near - _progress) < _path_length * 0.5:
		_progress = lerpf(_progress, near, 0.35)
	else:
		_progress = near

	var target_offset := fmod(_progress + path_look_ahead, _path_length)
	var target_point := race_path.curve.sample_baked(target_offset)
	# Path points are local to Path2D
	var world_target := race_path.to_global(target_point)

	var to_target := world_target - global_position
	var desired_angle := to_target.angle()
	var angle_diff := wrapf(desired_angle - rotation, -PI, PI)

	set_steer(clampf(angle_diff * 2.2, -1.0, 1.0))

	# Ease throttle hard on corners so AI (and pack) stay on the ribbon
	var turn_severity := clampf(absf(angle_diff) / (PI * 0.4), 0.0, 1.0)
	var thr := lerpf(arrive_throttle, corner_speed_factor, turn_severity)
	set_throttle(thr)


func _update_combat() -> void:
	var target := _find_target()
	if target == null:
		return
	var to_target := target.global_position - global_position
	if to_target.length() > detect_range:
		return
	var forward := get_forward_vector()
	var dir := to_target.normalized()
	if forward.dot(dir) >= aim_dot_min:
		try_fire()


func _find_target() -> Car:
	var best: Car = null
	var best_dist := detect_range
	var forward := get_forward_vector()
	var cone := deg_to_rad(fire_cone_degrees)

	for node in get_tree().get_nodes_in_group("cars"):
		if node == self or not (node is Car):
			continue
		var other := node as Car
		if not other.is_alive:
			continue
		var offset: Vector2 = other.global_position - global_position
		var dist := offset.length()
		if dist > best_dist or dist < 1.0:
			continue
		var ang := absf(forward.angle_to(offset))
		if ang > cone:
			continue
		best_dist = dist
		best = other
	return best


func _nearest_offset(world_pos: Vector2) -> float:
	if race_path == null or race_path.curve == null:
		return 0.0
	var local := race_path.to_local(world_pos)
	return race_path.curve.get_closest_offset(local)
