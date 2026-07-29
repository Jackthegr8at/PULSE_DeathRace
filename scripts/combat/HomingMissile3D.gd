class_name HomingMissile3D
extends Missile3D
## Reusable limited-distance homing missile. It never changes its launch lock.

@export var homing_distance: float = 18.0
@export var turn_rate_degrees: float = 105.0
@export var target_height_offset: float = 0.45

var _target: Vehicle = null
var _homing_travelled: float = 0.0
var _previous_position: Vector3 = Vector3.ZERO
var _has_previous_position: bool = false
var _homing_active: bool = false


func setup_homing(target: Vehicle) -> void:
	_target = target
	_homing_active = (
		target != null
		and is_instance_valid(target)
		and target.is_alive
		and not target.has_finished_race
	)
	_homing_travelled = 0.0
	_previous_position = global_position
	_has_previous_position = true


func _update_guidance(delta: float) -> void:
	if _has_previous_position:
		_homing_travelled += global_position.distance_to(_previous_position)
	_previous_position = global_position
	_has_previous_position = true

	if not _homing_active:
		return
	if _homing_travelled >= homing_distance:
		_homing_active = false
		return
	if (
		_target == null
		or not is_instance_valid(_target)
		or not _target.is_alive
		or _target.has_finished_race
	):
		_homing_active = false
		return

	var desired := (
		_target.get_vehicle_position()
		+ Vector3(0.0, target_height_offset, 0.0)
		- global_position
	)
	if desired.length_squared() < 0.0001:
		return
	desired = desired.normalized()
	var current := _velocity.normalized()
	if current.length_squared() < 0.0001:
		current = desired
	var angle := current.angle_to(desired)
	var max_step := deg_to_rad(turn_rate_degrees) * delta
	var weight := 1.0 if angle <= max_step else max_step / maxf(angle, 0.0001)
	var direction := current.slerp(desired, clampf(weight, 0.0, 1.0)).normalized()
	_velocity = direction * speed
	look_at(global_position + direction, Vector3.UP)

