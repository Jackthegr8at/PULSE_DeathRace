extends Node3D

@export_group("Properties")
@export var target: Vehicle

@onready var camera = $Camera

var _shake_remaining: float = 0.0
var _shake_strength: float = 0.0
var _shake_offset := Vector3.ZERO


func _ready() -> void:
	# Player vehicles can request a short camera punch on hard hits.
	if not is_in_group("race_camera"):
		add_to_group("race_camera")


func _physics_process(delta: float) -> void:
	if target == null or camera == null:
		return

	# Ease position towards target vehicle position
	var follow := target.get_vehicle_position()
	self.position = self.position.lerp(follow + _shake_offset, delta * 4)

	# Zoom camera based on the speed of the vehicle
	var speed_factor = clamp(abs(target.linear_speed), 0.0, 1.0)
	var target_z = remap(speed_factor, 0.0, 1.0, 10, 20)
	camera.position.z = lerp(camera.position.z, target_z, delta * 0.5)

	if _shake_remaining > 0.0:
		_shake_remaining = maxf(0.0, _shake_remaining - delta)
		var falloff := clampf(_shake_remaining / 0.25, 0.0, 1.0)
		_shake_offset = Vector3(
			randf_range(-1.0, 1.0),
			randf_range(-0.5, 0.5),
			randf_range(-0.4, 0.4)
		) * (_shake_strength * falloff)
		if _shake_remaining <= 0.0:
			_shake_offset = Vector3.ZERO
	else:
		_shake_offset = _shake_offset.lerp(Vector3.ZERO, delta * 12.0)


func punch(strength: float = 0.22, duration: float = 0.18) -> void:
	_shake_strength = maxf(_shake_strength * 0.35, strength)
	_shake_remaining = maxf(_shake_remaining, duration)
