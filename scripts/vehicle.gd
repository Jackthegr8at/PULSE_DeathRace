class_name Vehicle
extends Node3D
## Kenney arcade vehicle + DeathRace combat (HP, fire, death, optional AI input).

signal health_changed(current: float, maximum: float)
signal ammo_changed(current: int, maximum: int)
signal died(vehicle: Vehicle)
signal lap_completed(vehicle: Vehicle, laps: int)
signal race_finished(vehicle: Vehicle)

enum VehicleType {
	RAVAGE,
	BULLDOZE,
	VENOM,
	WRAITH,
}

const MissileScene: PackedScene = preload("res://scenes/combat/Missile3D.tscn")
const CustomWheelScene: PackedScene = preload("res://models/wheel.glb")
const RAVAGE_HEALTH_MULTIPLIER := 1.15
const BULLDOZE_RAM_DAMAGE := 7.5
const BULLDOZE_MIN_IMPACT_SPEED := 1.5
const BULLDOZE_RAM_COOLDOWN_SECONDS := 1.0
const VENOM_FORWARD_SPEED_MULTIPLIER := 1.12
const WRAITH_MISSILE_DAMAGE_MULTIPLIER := 1.5

# Nodes
@onready var sphere: RigidBody3D = $Sphere
@onready var raycast: RayCast3D = $Ground
@onready var vehicle_model = $Container
var vehicle_body: Node3D = null

var wheel_fl: Node3D = null
var wheel_fr: Node3D = null
var wheel_bl: Node3D = null
var wheel_br: Node3D = null
## True when mesh has separate wheel nodes (Kenney-style). False for monomesh (Ravage).
var _has_separate_wheels: bool = false
var _is_modular_model: bool = false
var _body_rest: Vector3 = Vector3.ZERO
var _suspension_y: float = 0.0
var _wheel_spin: float = 0.0
var _wheel_rest_positions: Dictionary = {}

@onready var trail_left = get_node_or_null("Container/TrailLeft")
@onready var trail_right = get_node_or_null("Container/TrailRight")

@onready var screech_sound: AudioStreamPlayer3D = $Container/ScreechSound
@onready var engine_sound: AudioStreamPlayer3D = $Container/EngineSound
@onready var impact_sound: AudioStreamPlayer3D = $Container/ImpactSound

@export_group("Identity")
@export var is_player: bool = true
@export var display_name: String = "Vehicle"
@export var minimap_color: Color = Color("21e6e6")
@export var vehicle_type: VehicleType = VehicleType.RAVAGE

@export_group("Model")
## Extra pitch/lean strength for body (works on monomesh or chassis node).
@export var body_lean_strength: float = 1.0
@export var suspension_strength: float = 0.045
@export var suspension_max: float = 0.1
## Monomesh only: light road bob (set 0 to disable). Full wheel spin needs separate wheel nodes.
@export var monomesh_motion: float = 0.35
@export var use_custom_wheels: bool = true
@export var custom_wheel_scale: float = 0.25
@export var custom_wheel_track: float = 0.53
@export var custom_wheel_base: float = 0.55
@export var custom_wheel_height: float = 0.34

@export_group("Modular Visual Suspension")
## Radius of the source wheel mesh before its scene scale is applied.
@export var modular_wheel_radius: float = 0.95
@export var modular_wheel_travel_down: float = 0.08
@export var modular_wheel_travel_up: float = 0.025
@export var modular_wheel_ray_height: float = 2.5
@export var modular_wheel_ray_length: float = 5.0
## The chassis cannot visually compress farther than this below its authored height.
@export var modular_chassis_max_drop: float = 0.12
@export var modular_suspension_smoothing: float = 16.0

@export_group("Combat")
@export var max_health: float = 100.0
@export var fire_cooldown: float = 0.85
@export var missile_damage: float = 15.0
@export var missile_speed: float = 32.0
## Missiles only from road pickups (start empty).
@export var starting_missile_ammo: int = 0
@export var max_missile_ammo: int = 3

@export_group("AI")
@export var path_look_ahead: float = 5.5
@export var ai_throttle: float = 0.78
@export var ai_corner_throttle: float = 0.48
@export var ai_steer_gain: float = 2.1
@export var detect_range: float = 22.0
## Must be this aligned with target to actually fire (missile still goes straight forward).
@export var fire_dot_min: float = 0.93
## Looser cone to *start* a short aim steer toward the target.
@export var fire_acquire_dot_min: float = 0.55
## Max seconds spent pointing at a target before giving up.
@export var ai_aim_time_max: float = 0.4
## How hard to turn toward the target while aiming (0–1 blend over path steer).
@export var ai_aim_steer_weight: float = 0.72

var health: float = 100.0
var missile_ammo: int = 0
var is_alive: bool = true
var match_over: bool = false
var race_started: bool = true
var has_finished_race: bool = false
var forward_speed_multiplier: float = 1.0
var _cooldown: float = 0.0
var _ai_aim_target: Vehicle = null
var _ai_aim_timer: float = 0.0
var _traits_applied: bool = false
var _ram_cooldowns: Dictionary = {}
var _last_damage_source: WeakRef = null
var _last_damage_source_msec: int = 0
const DAMAGE_ATTRIBUTION_WINDOW_MSEC := 10000

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
		return Vector3(0, 0, 1)
	# Kenney kit rolls the sphere on basis.x so travel is along +Z of the model.
	var f: Vector3 = vehicle_model.global_transform.basis.z
	f.y = 0.0
	if f.length_squared() < 0.0001:
		return Vector3(0, 0, 1)
	return f.normalized()


func _ready() -> void:
	_apply_vehicle_traits()
	health = max_health
	missile_ammo = starting_missile_ammo
	add_to_group("vehicles")
	rebind_model_parts()
	_ensure_hp_bar()
	health_changed.emit(health, max_health)
	ammo_changed.emit(missile_ammo, max_missile_ammo)
	if sphere:
		# Vehicle spheres on layer 8 (matches kit)
		sphere.collision_layer = 8
		sphere.collision_mask = 1 | 8


func _apply_vehicle_traits() -> void:
	if _traits_applied:
		return
	_traits_applied = true
	forward_speed_multiplier = 1.0
	match vehicle_type:
		VehicleType.RAVAGE:
			max_health *= RAVAGE_HEALTH_MULTIPLIER
		VehicleType.VENOM:
			forward_speed_multiplier = VENOM_FORWARD_SPEED_MULTIPLIER
		VehicleType.WRAITH:
			missile_damage *= WRAITH_MISSILE_DAMAGE_MULTIPLIER
		VehicleType.BULLDOZE:
			pass


## Call after swapping Container/Model (e.g. AI color trucks or custom GLB).
func rebind_model_parts() -> void:
	var model := get_node_or_null("Container/Model") as Node3D
	var is_modular_model := model != null and model.is_in_group("modular_vehicle_visual")
	_is_modular_model = is_modular_model
	if is_modular_model:
		# Editable modular scenes own these animation pivots directly.
		wheel_fl = model.get_node_or_null("WheelFrontLeft") as Node3D
		wheel_fr = model.get_node_or_null("WheelFrontRight") as Node3D
		wheel_bl = model.get_node_or_null("WheelBackLeft") as Node3D
		wheel_br = model.get_node_or_null("WheelBackRight") as Node3D
		vehicle_body = model.get_node_or_null("Chassis") as Node3D
	else:
		wheel_fl = _find_model_node(model, [
			"wheel-front-left", "WheelFrontLeft", "wheel_front_left", "FL", "Wheel.FL"
		])
		wheel_fr = _find_model_node(model, [
			"wheel-front-right", "WheelFrontRight", "wheel_front_right", "FR", "Wheel.FR"
		])
		wheel_bl = _find_model_node(model, [
			"wheel-back-left", "WheelBackLeft", "wheel_back_left", "BL", "Wheel.BL", "wheel-rear-left"
		])
		wheel_br = _find_model_node(model, [
			"wheel-back-right", "WheelBackRight", "wheel_back_right", "BR", "Wheel.BR", "wheel-rear-right"
		])
		vehicle_body = _find_model_node(model, ["body", "Body", "chassis", "Chassis", "Hull", "hull"])
	_has_separate_wheels = wheel_fl != null or wheel_fr != null or wheel_bl != null or wheel_br != null
	if use_custom_wheels and model != null and not is_modular_model:
		_install_custom_wheels(model)

	# Monomesh (Ravage): no body/wheel nodes — lean/bounce the whole Model root.
	if vehicle_body == null and model != null:
		vehicle_body = model
	if vehicle_body:
		_body_rest = vehicle_body.position
	_suspension_y = 0.0
	_wheel_rest_positions.clear()
	for wheel in [wheel_fl, wheel_fr, wheel_bl, wheel_br]:
		if wheel != null:
			_wheel_rest_positions[wheel] = wheel.position


func _install_custom_wheels(model: Node3D) -> void:
	## The authored wheel is visual-only: existing sphere physics stays unchanged.
	## Each wrapper is the animation pivot used by effect_wheels().
	var existing := model.get_node_or_null("CustomWheels")
	if existing:
		existing.free()
	for old_wheel in [wheel_fl, wheel_fr, wheel_bl, wheel_br]:
		if old_wheel != null:
			_set_visual_visibility(old_wheel, false)

	var root := Node3D.new()
	root.name = "CustomWheels"
	model.add_child(root)
	wheel_fl = _create_custom_wheel(root, "WheelFrontLeft", Vector3(-custom_wheel_track, custom_wheel_height, custom_wheel_base))
	wheel_fr = _create_custom_wheel(root, "WheelFrontRight", Vector3(custom_wheel_track, custom_wheel_height, custom_wheel_base))
	wheel_bl = _create_custom_wheel(root, "WheelBackLeft", Vector3(-custom_wheel_track, custom_wheel_height, -custom_wheel_base))
	wheel_br = _create_custom_wheel(root, "WheelBackRight", Vector3(custom_wheel_track, custom_wheel_height, -custom_wheel_base))
	_has_separate_wheels = true


func _create_custom_wheel(parent: Node3D, wheel_name: String, wheel_position: Vector3) -> Node3D:
	var pivot := Node3D.new()
	pivot.name = wheel_name
	pivot.position = wheel_position
	parent.add_child(pivot)
	var wheel := CustomWheelScene.instantiate() as Node3D
	if wheel == null:
		return pivot
	# Blender wheel is wide along local Z; rotate it so the axle runs across the car.
	wheel.rotation.y = PI * 0.5
	wheel.scale = Vector3.ONE * custom_wheel_scale
	pivot.add_child(wheel)
	return pivot


func _set_visual_visibility(node: Node, is_visible: bool) -> void:
	if node is VisualInstance3D:
		(node as VisualInstance3D).visible = is_visible
	for child in node.get_children():
		_set_visual_visibility(child, is_visible)


func _find_model_node(root: Node, names: Array) -> Node3D:
	if root == null:
		return null
	for n in names:
		var exact := root.find_child(str(n), true, false)
		if exact is Node3D:
			return exact as Node3D
	# Case-insensitive contains match (Blender often uses mixed names)
	var want: Array[String] = []
	for n in names:
		want.append(str(n).to_lower().replace("_", "-").replace(" ", ""))
	return _find_model_node_fuzzy(root, want)


func _find_model_node_fuzzy(node: Node, want: Array[String]) -> Node3D:
	var key := node.name.to_lower().replace("_", "-").replace(" ", "")
	for w in want:
		if key == w or key.ends_with(w) or key.contains(w):
			if node is Node3D:
				return node as Node3D
	for child in node.get_children():
		var found := _find_model_node_fuzzy(child, want)
		if found:
			return found
	return null


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


func mark_race_finished() -> void:
	## Finished cars keep driving, but can no longer affect the remaining race
	## with weapons or missile pickups.
	has_finished_race = true
	_ai_clear_aim()


func set_race_started(started: bool) -> void:
	## Holds both player and AI in place until the race countdown completes.
	race_started = started
	input = Vector3.ZERO
	linear_speed = 0.0
	if sphere:
		sphere.freeze = not started
		sphere.linear_velocity = Vector3.ZERO
		sphere.angular_velocity = Vector3.ZERO


func _physics_process(delta: float) -> void:
	_update_ram_cooldowns(delta)
	if not is_alive:
		return
	if not race_started:
		input = Vector3.ZERO
		linear_speed = 0.0
		if sphere:
			sphere.freeze = true
			sphere.linear_velocity = Vector3.ZERO
			sphere.angular_velocity = Vector3.ZERO
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
		_ai_combat(delta)
		_ai_drive(delta)

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
			# Landing bump — visual suspension only
			_suspension_y = -minf(suspension_max, 0.08)
			input.z = 0
		normal = raycast.get_collision_normal()
		if vehicle_model and normal.dot(vehicle_model.global_basis.y) > 0.5:
			var xform = align_with_y(vehicle_model.global_transform, normal)
			vehicle_model.global_transform = vehicle_model.global_transform.interpolate_with(xform, 0.2).orthonormalized()

	colliding = raycast.is_colliding() if raycast else false

	var target_speed := input.z
	if target_speed > 0.0:
		target_speed *= forward_speed_multiplier
	if target_speed < 0 and linear_speed > 0.01:
		linear_speed = lerp(linear_speed, 0.0, delta * 8)
	else:
		if target_speed < 0:
			linear_speed = lerp(linear_speed, target_speed / 2, delta * 2)
		else:
			linear_speed = lerp(linear_speed, target_speed, delta * 6)

	if sphere and vehicle_model:
		acceleration = lerpf(acceleration, linear_speed + (abs(sphere.angular_velocity.length() * linear_speed) / 100), delta * 1)
		# Modular chassis/wheels are authored higher than the legacy vehicle
		# visual. Keep their lift every physics frame instead of overwriting it.
		var visual_drop: float = 0.55 if _is_modular_model else 0.65
		vehicle_model.position = sphere.position - Vector3(0, visual_drop, 0)
		raycast.position = sphere.position
		linear_velocity = (vehicle_model.position - prev_position) / maxf(delta, 0.0001)
		prev_position = vehicle_model.position
		sphere.angular_velocity += vehicle_model.get_global_transform().basis.x * (linear_speed * 100) * delta

	effect_engine(delta)
	effect_body(delta)
	effect_wheels(delta)
	effect_suspension(delta)
	effect_trails()
	_update_lap_progress()
	_billboard_hp_bar()


func handle_input(_delta: float) -> void:
	input.x = Input.get_axis("left", "right")
	input.z = Input.get_axis("back", "forward")


func _ai_drive(_delta: float) -> void:
	if race_path == null or race_path.curve == null or _path_length <= 1.0:
		input.z = 0.4
		input.x = 0.0
		_ai_apply_aim_steer()
		return

	var pos := get_vehicle_position()
	var curve := race_path.curve
	var near := curve.get_closest_offset(race_path.to_local(pos))
	_ai_progress = near

	var path_point := race_path.to_global(curve.sample_baked(near))
	var path_error := pos - path_point
	path_error.y = 0.0

	# Slightly shorter look-ahead than the original 7 when off-line / turning hard
	var look_ahead := path_look_ahead
	if path_error.length() > 2.5:
		look_ahead = path_look_ahead * 0.75

	var target_off := fmod(near + look_ahead + _path_length, _path_length)
	var target := race_path.to_global(curve.sample_baked(target_off))
	# If drifting off centerline, bias aim slightly back toward the path
	if path_error.length() > 1.5:
		target = target.lerp(path_point, clampf((path_error.length() - 1.5) / 5.0, 0.0, 0.3))

	var to_target := target - pos
	to_target.y = 0.0
	if to_target.length_squared() < 0.01:
		input.z = ai_throttle
		input.x = 0.0
		_ai_apply_aim_steer()
		return

	var forward := get_forward()
	forward.y = 0.0
	if forward.length_squared() < 0.0001:
		forward = Vector3(0, 0, 1)
	else:
		forward = forward.normalized()

	var tangent_off := fmod(target_off + 3.0 + _path_length, _path_length)
	var path_tangent := race_path.to_global(curve.sample_baked(tangent_off)) - target
	path_tangent.y = 0.0
	if path_tangent.length_squared() < 0.0001:
		path_tangent = to_target
	path_tangent = path_tangent.normalized()

	# Mostly chase the look-ahead point; a little path heading (original 70/30 was too wall-cutty)
	var desired := (to_target.normalized() * 0.65 + path_tangent * 0.35).normalized()
	var cross_y := forward.cross(desired).y
	var dot := clampf(forward.dot(desired), -1.0, 1.0)
	input.x = clampf(-cross_y * ai_steer_gain, -1.0, 1.0)

	# Light corner ease only — stay fast on straights
	var turn_pen := clampf((1.0 - dot) * 1.1 + absf(cross_y) * 0.45, 0.0, 1.0)
	input.z = lerpf(ai_throttle, ai_corner_throttle, turn_pen * 0.85)

	# Only slow down if badly off the road
	if path_error.length() > 5.0:
		input.x = clampf(-forward.cross(to_target.normalized()).y * (ai_steer_gain + 0.6), -1.0, 1.0)
		input.z = minf(input.z, 0.55)

	# After path steer: briefly point the nose at a combat target (fair aim)
	_ai_apply_aim_steer()


func _ai_apply_aim_steer() -> void:
	if _ai_aim_target == null or not is_instance_valid(_ai_aim_target):
		return
	if not _ai_aim_target.is_alive:
		_ai_clear_aim()
		return
	var to_enemy := _ai_aim_target.get_vehicle_position() - get_vehicle_position()
	to_enemy.y = 0.0
	if to_enemy.length_squared() < 0.01:
		return
	var forward := get_forward()
	var dir := to_enemy.normalized()
	var cross_y := forward.cross(dir).y
	var aim_steer := clampf(-cross_y * (ai_steer_gain + 0.8), -1.0, 1.0)
	input.x = lerpf(input.x, aim_steer, clampf(ai_aim_steer_weight, 0.0, 1.0))
	# Ease throttle a bit so the turn can actually land before the shot
	input.z = minf(input.z, lerpf(ai_throttle, ai_corner_throttle, 0.55))


func _ai_clear_aim() -> void:
	_ai_aim_target = null
	_ai_aim_timer = 0.0


func _ai_pick_fire_target(acquire_dot: float) -> Vehicle:
	var best: Vehicle = null
	var best_dist := detect_range
	var forward := get_forward()
	var origin := get_vehicle_position()
	for node in get_tree().get_nodes_in_group("vehicles"):
		if node == self or not (node is Vehicle):
			continue
		var other := node as Vehicle
		if not other.is_alive or other.has_finished_race:
			continue
		var offset: Vector3 = other.get_vehicle_position() - origin
		var dist := offset.length()
		if dist > best_dist or dist < 1.0:
			continue
		var dir := offset.normalized()
		if forward.dot(dir) < acquire_dot:
			continue
		best_dist = dist
		best = other
	return best


func _ai_combat(delta: float) -> void:
	if has_finished_race or match_over or not is_alive or missile_ammo <= 0 or _cooldown > 0.0:
		_ai_clear_aim()
		return

	# Keep or acquire a target in a wide forward cone, then steer (in _ai_drive) before firing
	if _ai_aim_target != null and is_instance_valid(_ai_aim_target) and _ai_aim_target.is_alive:
		var offset := _ai_aim_target.get_vehicle_position() - get_vehicle_position()
		var dist := offset.length()
		offset.y = 0.0
		if dist > detect_range * 1.15 or dist < 1.0 or offset.length_squared() < 0.01:
			_ai_clear_aim()
		else:
			_ai_aim_timer += delta
			var dir := offset.normalized()
			var align := get_forward().dot(dir)
			# Lined up enough → fire straight (same as player)
			if align >= fire_dot_min:
				try_fire()
				_ai_clear_aim()
				return
			# Timed out without a clean line → drop the attempt (don't waste ammo)
			if _ai_aim_timer >= ai_aim_time_max:
				_ai_clear_aim()
			return

	_ai_clear_aim()
	var candidate := _ai_pick_fire_target(fire_acquire_dot_min)
	if candidate:
		_ai_aim_target = candidate
		_ai_aim_timer = 0.0
		# Already perfectly lined up this frame — shoot immediately
		var to_c := candidate.get_vehicle_position() - get_vehicle_position()
		to_c.y = 0.0
		if to_c.length_squared() > 0.01 and get_forward().dot(to_c.normalized()) >= fire_dot_min:
			try_fire()
			_ai_clear_aim()


func add_missiles(amount: int) -> bool:
	## Returns true if any ammo was actually added (pickup may respawn).
	if amount <= 0 or not is_alive or match_over or has_finished_race:
		return false
	if missile_ammo >= max_missile_ammo:
		return false
	missile_ammo = mini(max_missile_ammo, missile_ammo + amount)
	ammo_changed.emit(missile_ammo, max_missile_ammo)
	return true


func try_fire() -> bool:
	if not is_alive or match_over or has_finished_race or _cooldown > 0.0:
		return false
	if missile_ammo <= 0:
		return false
	missile_ammo -= 1
	ammo_changed.emit(missile_ammo, max_missile_ammo)
	_cooldown = fire_cooldown
	var forward := get_forward()
	var missile: Area3D = MissileScene.instantiate()
	# Spawn well ahead of the nose so it never pops out the rear
	var origin := get_vehicle_position() + Vector3(0, 0.75, 0) + forward * 2.2
	var host := get_tree().current_scene
	if host:
		host.add_child(missile)
	else:
		get_parent().add_child(missile)
	missile.global_position = origin
	if missile.has_method("setup"):
		missile.setup(self, missile_damage, missile_speed, forward)
	return true


func take_damage(amount: float, source: Node = null) -> void:
	if not is_alive or match_over:
		return
	if source is Vehicle and source != self and (source as Vehicle).is_alive:
		_last_damage_source = weakref(source)
		_last_damage_source_msec = Time.get_ticks_msec()
	health = maxf(0.0, health - amount)
	health_changed.emit(health, max_health)
	_update_hp_bar_visual()
	if health <= 0.0:
		_die()


func get_last_damage_source() -> Vehicle:
	if _last_damage_source == null:
		return null
	if Time.get_ticks_msec() - _last_damage_source_msec > DAMAGE_ATTRIBUTION_WINDOW_MSEC:
		return null
	var source := _last_damage_source.get_ref() as Vehicle
	if not is_instance_valid(source) or source == self:
		return null
	return source


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
	if _hp_root:
		_hp_root.visible = false
	died.emit(self)
	await get_tree().create_timer(0.4).timeout
	if is_instance_valid(self):
		queue_free()


# --- World-space HP bar (billboard) ---
var _hp_root: Node3D = null
var _hp_fill: MeshInstance3D = null
const HP_BAR_WIDTH := 1.4


func _ensure_hp_bar() -> void:
	if _hp_root != null:
		return
	_hp_root = Node3D.new()
	_hp_root.name = "HealthBar3D"
	add_child(_hp_root)
	_hp_root.position = Vector3(0, 2.1, 0)

	var bg := MeshInstance3D.new()
	bg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var bg_mesh := BoxMesh.new()
	bg_mesh.size = Vector3(HP_BAR_WIDTH, 0.12, 0.04)
	bg.mesh = bg_mesh
	var bg_mat := StandardMaterial3D.new()
	bg_mat.albedo_color = Color(0.1, 0.1, 0.1, 0.85)
	bg_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bg_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bg.material_override = bg_mat
	_hp_root.add_child(bg)

	_hp_fill = MeshInstance3D.new()
	_hp_fill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var fill_mesh := BoxMesh.new()
	fill_mesh.size = Vector3(HP_BAR_WIDTH, 0.1, 0.05)
	_hp_fill.mesh = fill_mesh
	var fill_mat := StandardMaterial3D.new()
	fill_mat.albedo_color = Color(0.35, 0.85, 0.4, 1.0)
	fill_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_hp_fill.material_override = fill_mat
	_hp_root.add_child(_hp_fill)
	_update_hp_bar_visual()


func _update_hp_bar_visual() -> void:
	if _hp_fill == null:
		return
	var ratio := clampf(health / maxf(max_health, 1.0), 0.0, 1.0)
	_hp_fill.scale = Vector3(maxf(ratio, 0.02), 1.0, 1.0)
	# Keep fill left-aligned on the bar
	_hp_fill.position.x = -HP_BAR_WIDTH * 0.5 * (1.0 - ratio)
	var mat := _hp_fill.material_override as StandardMaterial3D
	if mat:
		if ratio > 0.55:
			mat.albedo_color = Color(0.35, 0.85, 0.4)
		elif ratio > 0.28:
			mat.albedo_color = Color(0.95, 0.75, 0.25)
		else:
			mat.albedo_color = Color(0.9, 0.25, 0.25)


func _billboard_hp_bar() -> void:
	if _hp_root == null or not is_alive:
		return
	# Follow vehicle position (sphere drives model)
	_hp_root.global_position = get_vehicle_position() + Vector3(0, 2.1, 0)
	var cam := get_viewport().get_camera_3d()
	if cam:
		_hp_root.look_at(cam.global_position, Vector3.UP)
		# look_at points -Z at target; flip so bar faces camera
		_hp_root.rotate_object_local(Vector3.UP, PI)


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
	if not is_alive or not MatchConfig.uses_laps() or match_over or has_finished_race:
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
	calculated_lean = lerp_angle(calculated_lean, -input.x / 5.0 * linear_speed * body_lean_strength, delta * 5)
	if vehicle_body == null:
		return
	# Pitch under accel/brake + roll in turns (chassis or monomesh)
	var pitch := clampf(-(linear_speed - acceleration) / 6.0, -0.35, 0.35) * body_lean_strength
	# Optional light monomesh road noise (keep low until wheels are separate)
	if not _has_separate_wheels and monomesh_motion > 0.0:
		var t := Time.get_ticks_msec() * 0.001
		var speed_n := clampf(absf(linear_speed), 0.0, 1.0)
		pitch += sin(t * (10.0 + speed_n * 18.0)) * speed_n * 0.012 * monomesh_motion
	vehicle_body.rotation.x = lerp_angle(vehicle_body.rotation.x, pitch, delta * 10)
	vehicle_body.rotation.z = calculated_lean


func effect_suspension(delta: float) -> void:
	if vehicle_body == null:
		return
	if _is_modular_model:
		_effect_modular_suspension(delta)
		return
	# Visual-only spring: compress on landing / hard hits, settle back to rest height
	var vert_v := 0.0
	if sphere:
		vert_v = sphere.linear_velocity.y
	var target_compress := clampf(-vert_v * suspension_strength, -suspension_max, suspension_max)
	# Slight squat when accelerating hard
	target_compress -= clampf(acceleration * 0.02, 0.0, suspension_max * 0.4)
	_suspension_y = lerpf(_suspension_y, target_compress, clampf(delta * 8.0, 0.0, 1.0))
	var rest := _body_rest
	# Kenney truck bodies bounced around y=0.2. Modular scenes keep their
	# authored chassis position so editor and runtime wheel alignment match.
	if _has_separate_wheels and not _is_modular_model:
		rest = Vector3(_body_rest.x, 0.2, _body_rest.z)
	var target_pos := rest + Vector3(0.0, _suspension_y, 0.0)
	vehicle_body.position = vehicle_body.position.lerp(target_pos, clampf(delta * 12.0, 0.0, 1.0))


func _effect_modular_suspension(delta: float) -> void:
	## Visual-only wheel contact. Physics remains on Sphere; these pivots keep
	## the rendered tyres on the road and prevent them from entering the chassis.
	if _wheel_rest_positions.is_empty():
		return
	var total_delta := 0.0
	var contact_count := 0
	for wheel in [wheel_fl, wheel_fr, wheel_bl, wheel_br]:
		if wheel == null or not _wheel_rest_positions.has(wheel):
			continue
		var parent := wheel.get_parent() as Node3D
		if parent == null:
			continue
		var rest: Vector3 = _wheel_rest_positions[wheel]
		# Ray from the wheel's authored X/Z location, not its current suspended height.
		var authored_world := parent.to_global(Vector3(rest.x, 0.0, rest.z))
		var hit := _get_road_hit(authored_world)
		var target_y := rest.y
		if not hit.is_empty():
			var wheel_visual := wheel.get_node_or_null("Wheel") as Node3D
			var wheel_scale: float = wheel_visual.global_transform.basis.get_scale().y if wheel_visual else wheel.global_transform.basis.get_scale().y
			var radius := modular_wheel_radius * wheel_scale
			var hit_position: Vector3 = hit["position"]
			var hub_world := Vector3(authored_world.x, hit_position.y + radius, authored_world.z)
			target_y = parent.to_local(hub_world).y
		# The upper limit keeps tyres out of fenders; the lower limit prevents
		# a missed/low contact from visually dropping through the road.
		target_y = clampf(target_y, rest.y - modular_wheel_travel_down, rest.y + modular_wheel_travel_up)
		wheel.position.y = lerpf(wheel.position.y, target_y, clampf(delta * modular_suspension_smoothing, 0.0, 1.0))
		total_delta += target_y - rest.y
		contact_count += 1

	var body_target_y := _body_rest.y
	if contact_count > 0:
		body_target_y += total_delta / float(contact_count)
	# Authored body height is the clearance reference. This makes every modular
	# car keep its own silhouette clearance instead of applying a truck-specific
	# absolute height to every chassis.
	body_target_y = maxf(body_target_y, _body_rest.y - modular_chassis_max_drop)
	vehicle_body.position.y = lerpf(vehicle_body.position.y, body_target_y, clampf(delta * modular_suspension_smoothing, 0.0, 1.0))


func _get_road_hit(world_position: Vector3) -> Dictionary:
	var space := get_world_3d().direct_space_state
	if space == null:
		return {}
	var from := world_position + Vector3.UP * modular_wheel_ray_height
	var to := world_position - Vector3.UP * modular_wheel_ray_length
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 1
	if sphere:
		query.exclude = [sphere.get_rid()]
	return space.intersect_ray(query)


func effect_wheels(delta: float) -> void:
	_wheel_spin += acceleration * 1.15
	if not _has_separate_wheels:
		# Separate wheel nodes in the GLB (e.g. wheel-front-left) enable spin/steer.
		return
	for wheel in [wheel_fl, wheel_fr, wheel_bl, wheel_br]:
		if wheel != null:
			wheel.rotation.x = _wheel_spin
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


func _update_ram_cooldowns(delta: float) -> void:
	if _ram_cooldowns.is_empty():
		return
	for target_id in _ram_cooldowns.keys():
		var remaining := float(_ram_cooldowns.get(target_id, 0.0)) - delta
		if remaining <= 0.0:
			_ram_cooldowns.erase(target_id)
		else:
			_ram_cooldowns[target_id] = remaining


func _vehicle_from_collision_body(body: Node) -> Vehicle:
	var current := body
	while current != null:
		if current is Vehicle:
			return current as Vehicle
		current = current.get_parent()
	return null


func _try_apply_ram_damage(body: Node) -> void:
	if vehicle_type != VehicleType.BULLDOZE:
		return
	if not is_alive or not race_started or has_finished_race or match_over:
		return
	var other := _vehicle_from_collision_body(body)
	if other == null or other == self:
		return
	if not other.is_alive or not other.race_started or other.has_finished_race or other.match_over:
		return
	var relative_velocity := linear_velocity - other.linear_velocity
	relative_velocity.y = 0.0
	if relative_velocity.length() < BULLDOZE_MIN_IMPACT_SPEED:
		return
	var target_id := other.get_instance_id()
	if float(_ram_cooldowns.get(target_id, 0.0)) > 0.0:
		return
	_ram_cooldowns[target_id] = BULLDOZE_RAM_COOLDOWN_SECONDS
	other.take_damage(BULLDOZE_RAM_DAMAGE, self)


func _on_sphere_body_entered(body: Node) -> void:
	_try_apply_ram_damage(body)
	if impact_sound == null:
		return
	_suspension_y = -suspension_max
	if not impact_sound.playing:
		var basis_z: Vector3 = Vector3(0, 0, 1)
		if vehicle_body != null:
			basis_z = vehicle_body.global_basis.z
		elif vehicle_model != null:
			basis_z = vehicle_model.global_basis.z
		var impact_velocity := absf(linear_velocity.dot(basis_z))
		impact_sound.volume_db = clampf(remap(impact_velocity, 0.0, 6.0, -20.0, 0.0), -20.0, 0.0)
		impact_sound.play()
