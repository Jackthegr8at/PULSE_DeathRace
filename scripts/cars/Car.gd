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
@export var turn_speed: float = 1.55 ## Radians/sec while accelerating — deliberate at speed
@export var turn_speed_coast: float = 3.4 ## Radians/sec with gas off — quick recovery / re-aim after a wall
@export var turn_speed_stopped_bonus: float = 1.25 ## Extra multiplier when nearly stopped + gas off
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
var laps_completed: int = 0
var race_path: Path2D = null
## How much of the race line we've covered this lap (world units along path).
var _lap_distance: float = 0.0
var _last_path_offset: float = 0.0
var _path_length: float = 0.0
## Fraction of full path required before S/F / wrap can count a lap.
@export var lap_min_path_fraction: float = 0.45
var _lap_cooldown: float = 0.0


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
		# Slightly longer hot-wheels silhouette
		body_rect.offset_left = -20
		body_rect.offset_top = -11
		body_rect.offset_right = 20
		body_rect.offset_bottom = 11
	var nose := get_node_or_null("Nose") as ColorRect
	if nose:
		nose.color = body_color.darkened(0.25)
		nose.offset_left = 12
		nose.offset_top = -6
		nose.offset_right = 24
		nose.offset_bottom = 6
	# Neon underglow
	var glow := get_node_or_null("Glow") as ColorRect
	if glow == null and body_rect:
		glow = ColorRect.new()
		glow.name = "Glow"
		glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		glow.offset_left = -22
		glow.offset_top = -13
		glow.offset_right = 22
		glow.offset_bottom = 13
		glow.z_index = -1
		add_child(glow)
		move_child(glow, 0)
	if glow:
		glow.color = Color(body_color.r, body_color.g, body_color.b, 0.35)
	if hp_bar:
		hp_bar.max_value = max_health
		hp_bar.value = health
		hp_bar.offset_left = -22
		hp_bar.offset_top = -30
		hp_bar.offset_right = 22
		hp_bar.offset_bottom = -22


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


func setup_lap_tracking(path: Path2D, _checkpoint_count: int = 0) -> void:
	## Path-progress lap counting (reliable). Checkpoints are visual only.
	race_path = path
	laps_completed = 0
	_lap_distance = 0.0
	_lap_cooldown = 0.0
	_path_length = 0.0
	if race_path and race_path.curve:
		_path_length = race_path.curve.get_baked_length()
		_last_path_offset = race_path.curve.get_closest_offset(
			race_path.to_local(global_position)
		)


func _physics_process(delta: float) -> void:
	if not is_alive or _match_over:
		return

	if _cooldown_left > 0.0:
		_cooldown_left = maxf(0.0, _cooldown_left - delta)
	if _lap_cooldown > 0.0:
		_lap_cooldown = maxf(0.0, _lap_cooldown - delta)

	_apply_vehicle_physics(delta)
	_update_lap_progress()
	# Keep HP bar upright in world space
	if hp_bar:
		hp_bar.rotation = -rotation


func _apply_vehicle_physics(delta: float) -> void:
	# --- Arcade top-down: you always drive where the nose points ---
	# (Old model accumulated sideways momentum and felt like ice into walls.)

	# Turn: slower with gas on (stable driving); faster with gas off (wall recovery)
	var gas_on := throttle_input > 0.05
	var base_turn := turn_speed if gas_on else turn_speed_coast
	if not gas_on and absf(_speed) < 40.0:
		base_turn *= turn_speed_stopped_bonus
	rotation += steer_input * base_turn * delta

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


func on_checkpoint(_index: int) -> void:
	## Kept for Track Area2D hooks / future UI. Laps use path progress.
	pass


func on_start_finish() -> void:
	## Crossing the painted S/F line can complete a lap if we've driven enough track.
	_try_complete_lap("start_finish_gate")


func _update_lap_progress() -> void:
	if not MatchConfig.uses_laps():
		return
	if race_path == null or race_path.curve == null or _path_length <= 1.0:
		return

	var curve := race_path.curve
	var local_pos := race_path.to_local(global_position)
	var offset := curve.get_closest_offset(local_pos)
	# Ignore updates when far off the ribbon (avoids figure-8 cross confusion a bit)
	var on_path_point := curve.sample_baked(offset)
	if local_pos.distance_to(on_path_point) > 140.0:
		_last_path_offset = offset
		return

	var delta_off := offset - _last_path_offset
	var half := _path_length * 0.5

	# Forward along path
	if delta_off > 0.0 and delta_off < half:
		_lap_distance += delta_off
	# Wrapped past the end of the curve (crossed start region along the race line)
	elif _last_path_offset > _path_length * 0.72 and offset < _path_length * 0.28:
		var wrap_forward := (_path_length - _last_path_offset) + offset
		if wrap_forward < half:
			_lap_distance += wrap_forward
		_try_complete_lap("path_wrap")
	# Large jump (figure-8 closest-point flip) — ignore, don't corrupt distance
	elif absf(delta_off) >= half:
		pass

	_last_path_offset = offset


func _try_complete_lap(_reason: String = "") -> void:
	if not is_alive or not MatchConfig.uses_laps() or _match_over:
		return
	if _lap_cooldown > 0.0:
		return
	if _path_length <= 1.0:
		return
	# Must have driven a real portion of the figure-8 (not just sitting on S/F)
	if _lap_distance < _path_length * lap_min_path_fraction:
		return

	laps_completed += 1
	_lap_distance = 0.0
	_lap_cooldown = 2.0 ## Prevent double-count while lingering on the line
	lap_completed.emit(self, laps_completed)
	if laps_completed >= MatchConfig.lap_count:
		race_finished.emit(self)


func get_forward_vector() -> Vector2:
	return Vector2.RIGHT.rotated(rotation)


func get_lap_progress_ratio() -> float:
	## 0..1 progress toward the next lap (for HUD).
	if _path_length <= 1.0:
		return 0.0
	return clampf(_lap_distance / _path_length, 0.0, 1.0)
