class_name Car
extends CharacterBody2D
## Shared top-down arcade vehicle: drive, shoot, take damage, explode.
## Controllers (Player / AI) only call set_throttle, set_steer, try_fire.

signal health_changed(current: float, maximum: float)
signal died(car: Car)
signal fired(car: Car)
signal lap_completed(car: Car, laps: int)
signal race_finished(car: Car)

const MissileScene: PackedScene = preload("res://scenes/cars/Missile.tscn")

@export_group("Movement")
## Tuned for readable figure-8 control (arcade: speed follows facing).
@export var max_speed: float = 230.0
@export var acceleration: float = 380.0
@export var brake_force: float = 520.0 ## How fast you scrub speed when holding reverse while moving forward
@export var reverse_speed: float = 110.0
@export var reverse_acceleration: float = 280.0
@export var turn_speed: float = 4.6 ## Radians/sec at full steer (higher = tighter turns)
@export var turn_speed_min_factor: float = 0.55 ## Turn authority at standstill / crawl (easier recovery)
@export var friction: float = 280.0 ## Coast slowdown when no throttle
@export var wall_slowdown_factor: float = 0.4 ## Velocity kept after wall scrape
@export var wall_bounce: float = 0.15 ## Small push-off along wall normal so you don't glue to walls

@export_group("Combat")
@export var max_health: float = 100.0
@export var fire_cooldown: float = 0.55
@export var missile_damage: float = 15.0
@export var missile_speed: float = 520.0
@export var muzzle_offset: float = 28.0

@export_group("Identity")
@export var display_name: String = "Car"
@export var body_color: Color = Color(0.3, 0.8, 0.45)

@onready var body_rect: ColorRect = $BodyVisual
@onready var hp_bar: ProgressBar = $HealthBar
@onready var muzzle: Marker2D = $Muzzle
@onready var death_particles: CPUParticles2D = $DeathParticles
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var health: float = 100.0
var is_alive: bool = true
var throttle_input: float = 0.0 ## -1..1
var steer_input: float = 0.0 ## -1..1
var _cooldown_left: float = 0.0
var _match_over: bool = false
## Signed speed along facing (+ forward, - reverse). Arcade model = easy aiming.
var _speed: float = 0.0

## Lap / race state (used when MatchConfig.uses_laps())
var next_checkpoint: int = 0
var laps_completed: int = 0
var total_checkpoints: int = 0


func _ready() -> void:
	health = max_health
	add_to_group("cars")
	_apply_visuals()
	_update_hp_bar()
	health_changed.emit(health, max_health)
	# Cars on layer 2, collide with world (1) and cars (2)
	collision_layer = 2
	collision_mask = 1 | 2


func _apply_visuals() -> void:
	if body_rect:
		body_rect.color = body_color
	if hp_bar:
		hp_bar.max_value = max_health
		hp_bar.value = health


func set_throttle(value: float) -> void:
	throttle_input = clampf(value, -1.0, 1.0)


func set_steer(value: float) -> void:
	steer_input = clampf(value, -1.0, 1.0)


func set_match_over(over: bool) -> void:
	_match_over = over
	if over:
		throttle_input = 0.0
		steer_input = 0.0
		_speed = 0.0
		velocity = Vector2.ZERO


func setup_lap_tracking(checkpoint_count: int) -> void:
	total_checkpoints = checkpoint_count
	next_checkpoint = 0
	laps_completed = 0


func _physics_process(delta: float) -> void:
	if not is_alive or _match_over:
		return

	if _cooldown_left > 0.0:
		_cooldown_left = maxf(0.0, _cooldown_left - delta)

	_apply_vehicle_physics(delta)
	# Keep HP bar upright in world space
	if hp_bar:
		hp_bar.rotation = -rotation


func _apply_vehicle_physics(delta: float) -> void:
	# --- Arcade top-down: you always drive where the nose points ---
	# (Old model accumulated sideways momentum and felt like ice into walls.)

	# Turn: still effective at low speed so you can unstick from walls
	var speed_ratio := clampf(absf(_speed) / maxf(max_speed, 1.0), 0.0, 1.0)
	var turn_factor := lerpf(turn_speed_min_factor, 1.0, speed_ratio)
	rotation += steer_input * turn_speed * turn_factor * delta

	if throttle_input > 0.05:
		_speed += acceleration * throttle_input * delta
	elif throttle_input < -0.05:
		if _speed > 5.0:
			# Holding "back" while going forward = brake (not reverse yet)
			_speed -= brake_force * absf(throttle_input) * delta
		else:
			_speed -= reverse_acceleration * absf(throttle_input) * delta
	else:
		_speed = move_toward(_speed, 0.0, friction * delta)

	_speed = clampf(_speed, -reverse_speed, max_speed)

	var forward := Vector2.RIGHT.rotated(rotation)
	velocity = forward * _speed

	move_and_slide()

	if get_slide_collision_count() > 0:
		for i in get_slide_collision_count():
			var col := get_slide_collision(i)
			if col == null:
				continue
			var collider := col.get_collider()
			if collider is StaticBody2D:
				# Kill speed and nudge off the wall so recovery is easy
				_speed *= wall_slowdown_factor
				velocity = forward * _speed
				velocity += col.get_normal() * maxf(absf(_speed), 40.0) * wall_bounce
				_speed = velocity.dot(forward)
				break


func try_fire() -> bool:
	if not is_alive or _match_over:
		return false
	if _cooldown_left > 0.0:
		return false

	_cooldown_left = fire_cooldown
	var missile: Area2D = MissileScene.instantiate()
	missile.global_position = muzzle.global_position if muzzle else global_position + Vector2.RIGHT.rotated(rotation) * muzzle_offset
	missile.rotation = rotation
	if missile.has_method("setup"):
		missile.setup(self, missile_damage, missile_speed)
	# Parent to current scene so missiles outlive brief car freezes
	var host := get_tree().current_scene
	if host:
		host.add_child(missile)
	else:
		get_parent().add_child(missile)
	fired.emit(self)
	return true


func take_damage(amount: float, _source: Node = null) -> void:
	if not is_alive or _match_over:
		return
	health = maxf(0.0, health - amount)
	_update_hp_bar()
	health_changed.emit(health, max_health)
	if health <= 0.0:
		_die()


func _update_hp_bar() -> void:
	if hp_bar == null:
		return
	hp_bar.value = health
	# Color shift as HP drops
	var pct := health / maxf(max_health, 1.0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.9, 0.2, 0.2).lerp(Color(0.2, 0.85, 0.35), pct)
	style.corner_radius_top_left = 2
	style.corner_radius_top_right = 2
	style.corner_radius_bottom_left = 2
	style.corner_radius_bottom_right = 2
	hp_bar.add_theme_stylebox_override("fill", style)


func _die() -> void:
	if not is_alive:
		return
	is_alive = false
	_speed = 0.0
	velocity = Vector2.ZERO
	if death_particles:
		death_particles.emitting = true
	if body_rect:
		body_rect.visible = false
	if hp_bar:
		hp_bar.visible = false
	if collision_shape:
		collision_shape.set_deferred("disabled", true)
	died.emit(self)
	# Brief delay so particles show, then remove
	await get_tree().create_timer(0.45).timeout
	if is_instance_valid(self):
		queue_free()


func on_checkpoint(index: int) -> void:
	if not is_alive or not MatchConfig.uses_laps():
		return
	if index == next_checkpoint:
		next_checkpoint += 1


func on_start_finish() -> void:
	if not is_alive or not MatchConfig.uses_laps():
		return
	# Require all checkpoints before counting a lap (blocks reverse cheese)
	if total_checkpoints > 0 and next_checkpoint < total_checkpoints:
		return
	laps_completed += 1
	next_checkpoint = 0
	lap_completed.emit(self, laps_completed)
	if laps_completed >= MatchConfig.lap_count:
		race_finished.emit(self)


func get_forward_vector() -> Vector2:
	return Vector2.RIGHT.rotated(rotation)
