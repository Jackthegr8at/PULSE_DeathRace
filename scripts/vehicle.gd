class_name Vehicle
extends Node3D
## Kenney arcade vehicle + DeathRace combat (HP, fire, death, optional AI input).

signal health_changed(current: float, maximum: float)
signal died(vehicle: Vehicle)
signal lap_completed(vehicle: Vehicle, laps: int)
signal race_finished(vehicle: Vehicle)

const MissileScene: PackedScene = preload("res://scenes/combat/Missile3D.tscn")

# Nodes
@onready var sphere: RigidBody3D = $Sphere
@onready var raycast: RayCast3D = $Ground
@onready var vehicle_model = $Container
@onready var vehicle_body = get_node_or_null("Container/Model/body")

@onready var wheel_fl = get_node_or_null("Container/Model/wheel-front-left")
@onready var wheel_fr = get_node_or_null("Container/Model/wheel-front-right")
@onready var wheel_bl = get_node_or_null("Container/Model/wheel-back-left")
@onready var wheel_br = get_node_or_null("Container/Model/wheel-back-right")

@onready var trail_left = get_node_or_null("Container/TrailLeft")
@onready var trail_right = get_node_or_null("Container/TrailRight")

@onready var screech_sound: AudioStreamPlayer3D = $Container/ScreechSound
@onready var engine_sound: AudioStreamPlayer3D = $Container/EngineSound
@onready var impact_sound: AudioStreamPlayer3D = $Container/ImpactSound

@export_group("Identity")
@export var is_player: bool = true
@export var display_name: String = "Vehicle"

@export_group("Combat")
@export var max_health: float = 100.0
@export var fire_cooldown: float = 0.6
@export var missile_damage: float = 15.0
@export var missile_speed: float = 32.0

@export_group("AI")
@export var path_look_ahead: float = 12.0
@export var ai_throttle: float = 0.75
@export var ai_steer_gain: float = 2.2
@export var detect_range: float = 22.0
@export var fire_dot_min: float = 0.82

var health: float = 100.0
var is_alive: bool = true
var match_over: bool = false
var _cooldown: float = 0.0

var race_path: Path3D = null
var _path_length: float = 0.0
var _ai_progress: float = 0.0
var _lap_distance: float = 0.0
var _last_path_offset: float = 0.0
var laps_completed: int = 0
var _lap_cooldown: float = 0.0
@export var lap_min_fraction: float = 0.45

var input: Vector3
var normal: Vector3
var acceleration: float
var angular_speed: float
var linear_speed: float
var colliding: bool
var linear_velocity: Vector3
var prev_position: Vector3
var calculated_lean: float


func get_vehicle_position() -> Vector3:
	return vehicle_model.global_position if vehicle_model else global_position


func get_forward() -> Vector3:
	if vehicle_model == null:
		return Vector3.FORWARD
	# Kenney models: drive along local -Z (Godot convention)
	return -vehicle_model.global_transform.basis.z


func _ready() -> void:
	health = max_health
	add_to_group("vehicles")
	health_changed.emit(health, max_health)
	if sphere:
		# Vehicle spheres on layer 8 (matches kit)
		sphere.collision_layer = 8
		sphere.collision_mask = 1 | 8


func setup_ai(path: Path3D, name_label: String) -> void:
	is_player = false
	display_name = name_label
	race_path = path
	if race_path and race_path.curve:
		_path_length = race_path.curve.get_baked_length()
		_ai_progress = race_path.curve.get_closest_offset(race_path.to_local(get_vehicle_position()))
		_last_path_offset = _ai_progress


func setup_player_laps(path: Path3D) -> void:
	is_player = true
	race_path = path
	if race_path and race_path.curve:
		_path_length = race_path.curve.get_baked_length()
		_last_path_offset = race_path.curve.get_closest_offset(race_path.to_local(get_vehicle_position()))


func set_match_over(over: bool) -> void:
	match_over = over
	if over:
		input = Vector3.ZERO
		linear_speed = 0.0


func _physics_process(delta: float) -> void:
	if not is_alive:
		return
	if _cooldown > 0.0:
		_cooldown = maxf(0.0, _cooldown - delta)
	if _lap_cooldown > 0.0:
		_lap_cooldown = maxf(0.0, _lap_cooldown - delta)

	if match_over:
		input = Vector3.ZERO
	elif is_player:
		handle_input(delta)
		if Input.is_action_just_pressed("bounce"):
			try_fire()
	else:
		_ai_drive(delta)
		_ai_combat()

	var direction = sign(linear_speed)
	if direction == 0:
		direction = sign(input.z) if abs(input.z) > 0.1 else 1

	var steering_grip = clamp(abs(linear_speed), 0.2, 1.0)
	var target_angular = -input.x * steering_grip * 4 * direction
	angular_speed = lerp(angular_speed, target_angular, delta * 4)
	if vehicle_model:
		vehicle_model.rotate_y(angular_speed * delta)

	if raycast and raycast.is_colliding():
		if not colliding:
			if vehicle_body != null:
				vehicle_body.position = Vector3(0, 0.1, 0)
			input.z = 0
		normal = raycast.get_collision_normal()
		if vehicle_model and normal.dot(vehicle_model.global_basis.y) > 0.5:
			var xform = align_with_y(vehicle_model.global_transform, normal)
			vehicle_model.global_transform = vehicle_model.global_transform.interpolate_with(xform, 0.2).orthonormalized()

	colliding = raycast.is_colliding() if raycast else false

	var target_speed = input.z
	if target_speed < 0 and linear_speed > 0.01:
		linear_speed = lerp(linear_speed, 0.0, delta * 8)
	else:
		if target_speed < 0:
			linear_speed = lerp(linear_speed, target_speed / 2, delta * 2)
		else:
			linear_speed = lerp(linear_speed, target_speed, delta * 6)

	if sphere and vehicle_model:
		acceleration = lerpf(acceleration, linear_speed + (abs(sphere.angular_velocity.length() * linear_speed) / 100), delta * 1)
		vehicle_model.position = sphere.position - Vector3(0, 0.65, 0)
		raycast.position = sphere.position
		linear_velocity = (vehicle_model.position - prev_position) / maxf(delta, 0.0001)
		prev_position = vehicle_model.position
		sphere.angular_velocity += vehicle_model.get_global_transform().basis.x * (linear_speed * 100) * delta

	effect_engine(delta)
	effect_body(delta)
	effect_wheels(delta)
	effect_trails()
	_update_lap_progress()


func handle_input(_delta: float) -> void:
	if raycast and raycast.is_colliding():
		input.x = Input.get_axis("left", "right")
		input.z = Input.get_axis("back", "forward")


func _ai_drive(_delta: float) -> void:
	if race_path == null or race_path.curve == null or _path_length <= 1.0:
		input.z = 0.4
		input.x = 0.0
		return
	if not (raycast and raycast.is_colliding()):
		return

	var pos := get_vehicle_position()
	var near := race_path.curve.get_closest_offset(race_path.to_local(pos))
	_ai_progress = lerpf(_ai_progress, near, 0.25)
	_ai_progress = fmod(_ai_progress + absf(linear_speed) * 2.0 + 0.5, _path_length)

	var target_off := fmod(_ai_progress + path_look_ahead, _path_length)
	var target := race_path.to_global(race_path.curve.sample_baked(target_off))
	var to_target := target - pos
	to_target.y = 0.0
	if to_target.length_squared() < 0.01:
		input.z = ai_throttle
		input.x = 0.0
		return

	var forward := get_forward()
	forward.y = 0.0
	forward = forward.normalized()
	var desired := to_target.normalized()
	var cross_y := forward.cross(desired).y
	var dot := forward.dot(desired)
	input.x = clampf(cross_y * ai_steer_gain, -1.0, 1.0)
	var turn_pen := clampf(1.0 - dot, 0.0, 1.0)
	input.z = lerpf(ai_throttle, 0.35, turn_pen)


func _ai_combat() -> void:
	if _cooldown > 0.0 or match_over:
		return
	var best: Vehicle = null
	var best_dist := detect_range
	var forward := get_forward()
	var origin := get_vehicle_position()
	for node in get_tree().get_nodes_in_group("vehicles"):
		if node == self or not (node is Vehicle):
			continue
		var other := node as Vehicle
		if not other.is_alive:
			continue
		var offset: Vector3 = other.get_vehicle_position() - origin
		var dist := offset.length()
		if dist > best_dist or dist < 1.0:
			continue
		var dir := offset.normalized()
		if forward.dot(dir) < fire_dot_min:
			continue
		best_dist = dist
		best = other
	if best:
		try_fire()


func try_fire() -> bool:
	if not is_alive or match_over or _cooldown > 0.0:
		return false
	_cooldown = fire_cooldown
	var missile: Area3D = MissileScene.instantiate()
	var origin := get_vehicle_position() + Vector3(0, 0.6, 0) + get_forward() * 1.4
	var host := get_tree().current_scene
	if host:
		host.add_child(missile)
	else:
		get_parent().add_child(missile)
	missile.global_position = origin
	if missile.has_method("setup"):
		missile.setup(self, missile_damage, missile_speed, get_forward())
	return true


func take_damage(amount: float, _source: Node = null) -> void:
	if not is_alive or match_over:
		return
	health = maxf(0.0, health - amount)
	health_changed.emit(health, max_health)
	if health <= 0.0:
		_die()


func _die() -> void:
	if not is_alive:
		return
	is_alive = false
	input = Vector3.ZERO
	linear_speed = 0.0
	if sphere:
		sphere.freeze = true
	if vehicle_model:
		vehicle_model.visible = false
	died.emit(self)
	await get_tree().create_timer(0.4).timeout
	if is_instance_valid(self):
		queue_free()


func on_finish_line() -> void:
	_try_complete_lap()


func _update_lap_progress() -> void:
	if not MatchConfig.uses_laps():
		return
	if race_path == null or race_path.curve == null or _path_length <= 1.0:
		return
	var pos := get_vehicle_position()
	var offset := race_path.curve.get_closest_offset(race_path.to_local(pos))
	var delta_off := offset - _last_path_offset
	var half := _path_length * 0.5
	if delta_off > 0.0 and delta_off < half:
		_lap_distance += delta_off
	elif _last_path_offset > _path_length * 0.72 and offset < _path_length * 0.28:
		var wrap := (_path_length - _last_path_offset) + offset
		if wrap < half:
			_lap_distance += wrap
		_try_complete_lap()
	_last_path_offset = offset


func _try_complete_lap() -> void:
	if not is_alive or not MatchConfig.uses_laps() or match_over:
		return
	if _lap_cooldown > 0.0 or _path_length <= 1.0:
		return
	if _lap_distance < _path_length * lap_min_fraction:
		return
	laps_completed += 1
	_lap_distance = 0.0
	_lap_cooldown = 2.5
	lap_completed.emit(self, laps_completed)
	if laps_completed >= MatchConfig.lap_count:
		race_finished.emit(self)


func get_lap_progress_ratio() -> float:
	if _path_length <= 1.0:
		return 0.0
	return clampf(_lap_distance / _path_length, 0.0, 1.0)


func effect_body(delta: float) -> void:
	calculated_lean = lerp_angle(calculated_lean, -input.x / 5 * linear_speed, delta * 5)
	if vehicle_body != null:
		vehicle_body.rotation.x = lerp_angle(vehicle_body.rotation.x, -(linear_speed - acceleration) / 6, delta * 10)
		vehicle_body.rotation.z = calculated_lean
		vehicle_body.position = vehicle_body.position.lerp(Vector3(0, 0.2, 0), delta * 5)


func effect_wheels(delta: float) -> void:
	for wheel in [wheel_fl, wheel_fr, wheel_bl, wheel_br]:
		if wheel != null:
			wheel.rotation.x += acceleration
	if wheel_fl != null:
		wheel_fl.rotation.y = lerp_angle(wheel_fl.rotation.y, -input.x / 1.5, delta * 10)
	if wheel_fr != null:
		wheel_fr.rotation.y = lerp_angle(wheel_fr.rotation.y, -input.x / 1.5, delta * 10)


func effect_engine(delta: float) -> void:
	if engine_sound == null:
		return
	var speed_factor = clamp(abs(linear_speed), 0.0, 1.0)
	var throttle_factor = clamp(abs(input.z), 0.0, 1.0)
	var target_volume = remap(speed_factor + (throttle_factor * 0.5), 0.0, 1.5, -15.0, -5.0)
	engine_sound.volume_db = lerp(engine_sound.volume_db, target_volume, delta * 5.0)
	var target_pitch = remap(speed_factor, 0.0, 1.0, 0.5, 3)
	if throttle_factor > 0.1:
		target_pitch += 0.2
	engine_sound.pitch_scale = lerp(engine_sound.pitch_scale, target_pitch, delta * 2.0)


func effect_trails() -> void:
	var drift_intensity = abs(linear_speed - acceleration) + (abs(calculated_lean) * 2.0)
	var should_emit = drift_intensity > 0.25
	if trail_left != null:
		trail_left.emitting = should_emit
	if trail_right != null:
		trail_right.emitting = should_emit
	if screech_sound == null:
		return
	var target_volume = -80.0
	if should_emit:
		target_volume = remap(clamp(drift_intensity, 0.25, 2.0), 0.25, 2.0, -10.0, 0.0)
	screech_sound.pitch_scale = lerp(screech_sound.pitch_scale, clamp(abs(linear_speed), 1.0, 3.0), 0.1)
	screech_sound.volume_db = lerp(screech_sound.volume_db, target_volume, 10.0 * get_physics_process_delta_time())


func align_with_y(xform, new_y):
	xform.basis.y = new_y
	xform.basis.x = -xform.basis.z.cross(new_y)
	xform.basis = xform.basis.orthonormalized()
	return xform


func _on_sphere_body_entered(_body: Node) -> void:
	if vehicle_body == null or impact_sound == null:
		return
	if not impact_sound.playing:
		var impact_velocity := absf(linear_velocity.dot(vehicle_body.global_basis.z))
		impact_sound.volume_db = clampf(remap(impact_velocity, 0.0, 6.0, -20.0, 0.0), -20.0, 0.0)
		impact_sound.play()
