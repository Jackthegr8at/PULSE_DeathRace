class_name Vehicle
extends Node3D
## Kenney arcade vehicle + DeathRace combat (HP, fire, death, optional AI input).

signal health_changed(current: float, maximum: float)
signal ammo_changed(current: int, maximum: int)
signal died(vehicle: Vehicle)
signal lap_completed(vehicle: Vehicle, laps: int)
signal race_finished(vehicle: Vehicle)
signal missile_direct_hit(target: Vehicle)

enum VehicleType {
	RAVAGE,
	BULLDOZE,
	VENOM,
	WRAITH,
	SPECTER,
	MOLTEN,
	THUNDERCLAW,
	TORRENT,
	WRECKMONGER,
}

const MissileScene: PackedScene = preload("res://scenes/combat/Missile3D.tscn")
const HomingMissileScene: PackedScene = preload("res://scenes/combat/HomingMissile3D.tscn")
const CustomWheelScene: PackedScene = preload("res://models/wheel.glb")
const RAVAGE_HEALTH_MULTIPLIER := 1.15
const BULLDOZE_RAM_DAMAGE := 7.5
const BULLDOZE_MIN_IMPACT_SPEED := 1.5
const BULLDOZE_RAM_COOLDOWN_SECONDS := 1.0
const VENOM_FORWARD_SPEED_MULTIPLIER := 1.12
const WRAITH_MISSILE_DAMAGE_MULTIPLIER := 1.5
const SPECTER_HEALTH_MULTIPLIER := 0.90
const SPECTER_FORWARD_SPEED_MULTIPLIER := 1.06
const SPECTER_STEER_MULTIPLIER := 1.10
const SPECTER_STEER_RESPONSE_MULTIPLIER := 1.12
const SPECTER_CLOAK_DURATION := 2.5
const SPECTER_CLOAK_COOLDOWN := 8.0
const SPECTER_CLOAK_TRANSPARENCY := 0.70
const MOLTEN_HEALTH_MULTIPLIER := 1.05
const MOLTEN_STEER_RESPONSE_MULTIPLIER := 0.95
const THUNDERCLAW_SURGE_DURATION := 2.5
const THUNDERCLAW_SURGE_SPEED_MULTIPLIER := 1.25
const THUNDERCLAW_SURGE_ACCELERATION_MULTIPLIER := 1.5
const THUNDERCLAW_CHAIN_RANGE := 6.0
const THUNDERCLAW_CHAIN_DAMAGE_MULTIPLIER := 0.5
const THUNDERCLAW_ARC_DURATION := 0.18
const THUNDERCLAW_ARC_COLOR := Color("28bfff")
const HOMING_LOCK_RANGE := 14.0
const HOMING_LOCK_HALF_ANGLE_DEGREES := 22.5
const WRECKMONGER_HEALTH_MULTIPLIER := 1.20
const WRECKMONGER_STEER_MULTIPLIER := 0.92
const WRECKMONGER_STEER_RESPONSE_MULTIPLIER := 0.90
const WRECKMONGER_HARVEST_RADIUS := 20.0
const WRECKMONGER_HARVEST_HEALTH_RATIO := 0.25
const WRECKMONGER_HARVEST_MISSILES := 2
const FIRESTORM_DURATION := 4.0
const FIRESTORM_RANGE := 8.0
const FIRESTORM_HALF_ANGLE_DEGREES := 17.5
const FIRESTORM_TICK_INTERVAL := 0.25
const FIRESTORM_DAMAGE_PER_TICK := 0.75
const FIRESTORM_TOTAL_TICKS := 16

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

const THRUSTER_SMOKE_TEX := preload("res://sprites/smoke.png")

var _exhaust_anchor: Node3D = null
var _weapon_anchor: Node3D = null
var _electrode_anchor: Node3D = null
var _thruster_core: GPUParticles3D = null
var _thruster_spark: GPUParticles3D = null
var _thruster_light: OmniLight3D = null
var _thruster_power: float = 0.0
var _thruster_color: Color = Color("3de8ff")
var _thruster_color_hot: Color = Color("a8f7ff")

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

@export_group("Thruster Exhaust")
@export var thruster_enabled: bool = true
## Used when the model has no ExhaustAnchor (local space on Container).
@export var thruster_default_offset: Vector3 = Vector3(0.0, 0.32, -0.72)
@export var thruster_idle_power: float = 0.12
@export var thruster_max_power: float = 1.0
## Multiplier for jet length / particle speed (lower = shorter plume).
@export var thruster_length_scale: float = 0.55

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

@export_group("Handling")
## Peak yaw rate multiplier (original was 4 — too snappy; 1.85 felt too slow).
@export var steer_sensitivity: float = 2.65
## How fast keyboard/gamepad steer eases in toward full lock.
@export var steer_input_rise: float = 5.5
## How fast steer returns to center when released.
@export var steer_input_fall: float = 7.0
## How quickly angular_speed tracks the desired rate.
@export var steer_response: float = 3.6
## At full speed, turn power is scaled by this (still less than low speed to limit zig-zag).
@export var high_speed_steer_factor: float = 0.62
## At crawl, turn power scale.
@export var low_speed_steer_factor: float = 1.05

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
@export var ai_steer_gain: float = 1.85
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
var is_cloaked: bool = false
var _cloak_remaining: float = 0.0
var _cloak_cooldown_remaining: float = 0.0
var is_firestorm_active: bool = false
var _firestorm_elapsed: float = 0.0
var _firestorm_ticks_done: int = 0
## Firestorm layered stream (core / outer / embers / smoke).
var _firestorm_particles: GPUParticles3D = null
var _firestorm_outer: GPUParticles3D = null
var _firestorm_embers: GPUParticles3D = null
var _firestorm_smoke: GPUParticles3D = null
var _firestorm_light: OmniLight3D = null
## Always-on pilot flame at the Molten turret tip.
var _flame_tip_core: GPUParticles3D = null
var _flame_tip_glow: GPUParticles3D = null
var _flame_tip_light: OmniLight3D = null
var _thunderclaw_surge_remaining: float = 0.0
## Idle + surge electric corona on the Thunderclaw roof electrode.
var _electrode_sparks: GPUParticles3D = null
var _electrode_corona: GPUParticles3D = null
var _electrode_light: OmniLight3D = null
var _electrode_arc_timer: float = 0.0
var _cooldown: float = 0.0
var _ai_aim_target: Vehicle = null
var _ai_aim_timer: float = 0.0
var _traits_applied: bool = false
var _ram_cooldowns: Dictionary = {}
var _last_damage_source: WeakRef = null
var _last_damage_source_msec: int = 0
var _last_damage_kind: StringName = &"vehicle"
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
## Smoothed steer (-1..1); raw input.x is filtered to kill keyboard snap oversteer.
var _steer_smoothed: float = 0.0
## Cycles modular suspension raycasts (4 wheels → 2 rays/frame for cheaper physics).
var _suspension_phase: int = 0
var _wheel_suspension_delta: Dictionary = {}


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
	_ensure_thruster_fx()
	_ensure_molten_tip_fx()
	_ensure_thunderclaw_electrode_fx()
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
		VehicleType.SPECTER:
			max_health *= SPECTER_HEALTH_MULTIPLIER
			forward_speed_multiplier = SPECTER_FORWARD_SPEED_MULTIPLIER
			steer_sensitivity *= SPECTER_STEER_MULTIPLIER
			steer_response *= SPECTER_STEER_RESPONSE_MULTIPLIER
		VehicleType.MOLTEN:
			max_health *= MOLTEN_HEALTH_MULTIPLIER
			steer_response *= MOLTEN_STEER_RESPONSE_MULTIPLIER
		VehicleType.THUNDERCLAW:
			pass
		VehicleType.TORRENT:
			pass
		VehicleType.WRECKMONGER:
			max_health *= WRECKMONGER_HEALTH_MULTIPLIER
			steer_sensitivity *= WRECKMONGER_STEER_MULTIPLIER
			steer_response *= WRECKMONGER_STEER_RESPONSE_MULTIPLIER


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
	_resolve_exhaust_anchor(model)
	_resolve_weapon_anchor(model)
	_resolve_electrode_anchor(model)
	# Rebuild thruster / special weapon FX under the (possibly new) model / anchor
	if is_inside_tree() and thruster_enabled:
		_ensure_thruster_fx()
	if is_inside_tree():
		_free_molten_tip_fx()
		_free_firestorm_fx_nodes()
		_free_thunderclaw_electrode_fx()
		_ensure_molten_tip_fx()
		_ensure_thunderclaw_electrode_fx()
	if is_cloaked:
		_set_vehicle_transparency(SPECTER_CLOAK_TRANSPARENCY)


func _resolve_exhaust_anchor(model: Node3D) -> void:
	_exhaust_anchor = null
	if model != null:
		_exhaust_anchor = model.get_node_or_null("ExhaustAnchor") as Node3D
		if _exhaust_anchor == null:
			_exhaust_anchor = model.find_child("ExhaustAnchor", true, false) as Node3D
	if _exhaust_anchor == null and vehicle_model != null:
		_exhaust_anchor = vehicle_model.get_node_or_null("ExhaustAnchor") as Node3D


func _resolve_weapon_anchor(model: Node3D) -> void:
	_weapon_anchor = null
	if model != null:
		_weapon_anchor = model.get_node_or_null("WeaponAnchor") as Node3D
		if _weapon_anchor == null:
			_weapon_anchor = model.find_child("WeaponAnchor", true, false) as Node3D
	if _weapon_anchor == null and vehicle_model != null:
		_weapon_anchor = vehicle_model.get_node_or_null("WeaponAnchor") as Node3D


func _resolve_electrode_anchor(model: Node3D) -> void:
	## Thunderclaw roof electrode is separate from the front WeaponAnchor muzzle.
	_electrode_anchor = null
	if model != null:
		_electrode_anchor = model.get_node_or_null("ElectrodeAnchor") as Node3D
		if _electrode_anchor == null:
			_electrode_anchor = model.find_child("ElectrodeAnchor", true, false) as Node3D
	if _electrode_anchor == null and vehicle_model != null:
		_electrode_anchor = vehicle_model.get_node_or_null("ElectrodeAnchor") as Node3D
		if _electrode_anchor == null:
			_electrode_anchor = vehicle_model.find_child("ElectrodeAnchor", true, false) as Node3D


func _electrode_fx_parent() -> Node3D:
	if _electrode_anchor != null and is_instance_valid(_electrode_anchor):
		return _electrode_anchor
	# Fallback only if an older scene lacks ElectrodeAnchor.
	if vehicle_model != null:
		return vehicle_model
	return null


func _electrode_fx_local_origin() -> Vector3:
	if _electrode_anchor != null and is_instance_valid(_electrode_anchor):
		return Vector3.ZERO
	# Roof peak estimate when no dedicated anchor is authored.
	return Vector3(0.0, 0.76, -0.445)


func _get_weapon_origin() -> Vector3:
	if _weapon_anchor != null and is_instance_valid(_weapon_anchor):
		return _weapon_anchor.global_position
	var forward := get_forward()
	return get_vehicle_position() + Vector3(0, 0.75, 0) + forward * 2.2


func _get_weapon_forward() -> Vector3:
	if _weapon_anchor != null and is_instance_valid(_weapon_anchor):
		var anchor_forward := _weapon_anchor.global_transform.basis.z.normalized()
		if anchor_forward.length_squared() > 0.0001:
			return anchor_forward
	return get_forward()


func _thruster_colors_for_type() -> void:
	## Per-car propulsor identity (keeps missile magenta unique).
	match vehicle_type:
		VehicleType.RAVAGE:
			_thruster_color = Color("3de8ff") # cyan
			_thruster_color_hot = Color("b8fbff")
		VehicleType.BULLDOZE:
			_thruster_color = Color("f6b600") # yellow
			_thruster_color_hot = Color("ffe566")
		VehicleType.WRAITH:
			_thruster_color = Color("e23b3b") # red
			_thruster_color_hot = Color("ff7a6e")
		VehicleType.VENOM:
			_thruster_color = Color("a84cff") # purple
			_thruster_color_hot = Color("d4a0ff")
		VehicleType.SPECTER:
			_thruster_color = Color("7547ff") # spectral violet
			_thruster_color_hot = Color("d9c7ff")
		VehicleType.MOLTEN:
			_thruster_color = Color("ff650d") # furnace orange
			_thruster_color_hot = Color("fff08a")
		VehicleType.THUNDERCLAW:
			_thruster_color = THUNDERCLAW_ARC_COLOR
			_thruster_color_hot = Color("d8f6ff")
		VehicleType.TORRENT:
			_thruster_color = Color("15d5d1")
			_thruster_color_hot = Color("c8fffd")
		_:
			_thruster_color = Color("3de8ff")
			_thruster_color_hot = Color("b8fbff")


func _ensure_thruster_fx() -> void:
	if not thruster_enabled:
		return
	# Parent: preferred ExhaustAnchor on modular model, else Container
	var parent: Node3D = _exhaust_anchor
	if parent == null and vehicle_model != null:
		parent = vehicle_model
	if parent == null:
		return

	# Tear down old FX if rebinding
	if _thruster_core != null and is_instance_valid(_thruster_core):
		_thruster_core.queue_free()
	if _thruster_spark != null and is_instance_valid(_thruster_spark):
		_thruster_spark.queue_free()
	if _thruster_light != null and is_instance_valid(_thruster_light):
		_thruster_light.queue_free()
	_thruster_core = null
	_thruster_spark = null
	_thruster_light = null

	_thruster_colors_for_type()
	var c := _thruster_color
	var h := _thruster_color_hot
	var fade := Color(c.r, c.g, c.b, 0.0)
	var fade_hot := Color(h.r, h.g, h.b, 0.0)

	var local_pos := Vector3.ZERO
	if _exhaust_anchor == null:
		local_pos = thruster_default_offset

	var len_s := thruster_length_scale
	# AI: one cheap core jet only (no spark stream / light) — big multiplayer FPS win.
	var core_amount := 22 if is_player else 10
	_thruster_core = _make_thruster_particles(
		Color(c.r, c.g, c.b, 0.95),
		fade_hot,
		core_amount,
		0.12 * len_s + 0.06,
		3.2 * len_s,
		0.22,
		0.5,
		0.38,
		true
	)
	_thruster_core.name = "ThrusterCore"
	_thruster_core.position = local_pos
	_thruster_core.fixed_fps = 30
	_thruster_core.interpolate = true
	parent.add_child(_thruster_core)

	if is_player:
		_thruster_spark = _make_thruster_particles(
			Color(h.r, h.g, h.b, 1.0),
			fade,
			10,
			0.08 * len_s + 0.04,
			4.5 * len_s,
			0.08,
			0.18,
			0.24,
			true
		)
		_thruster_spark.name = "ThrusterSpark"
		_thruster_spark.position = local_pos
		_thruster_spark.fixed_fps = 30
		_thruster_spark.interpolate = true
		parent.add_child(_thruster_spark)

		_thruster_light = OmniLight3D.new()
		_thruster_light.name = "ThrusterLight"
		_thruster_light.light_color = c
		_thruster_light.light_energy = 0.0
		_thruster_light.omni_range = 2.0
		_thruster_light.shadow_enabled = false
		_thruster_light.position = local_pos
		parent.add_child(_thruster_light)

	_thruster_core.emitting = true
	if _thruster_spark:
		_thruster_spark.emitting = true


func _make_thruster_particles(
	color_start: Color,
	color_end: Color,
	amount: int,
	life: float,
	speed: float,
	scale_min: float,
	scale_max: float,
	quad_size: float,
	additive: bool
) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.emitting = false
	p.amount = amount
	p.lifetime = life
	p.explosiveness = 0.05
	p.randomness = 0.35
	p.visibility_aabb = AABB(Vector3(-4, -4, -8), Vector3(8, 8, 12))
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Car forward is +Z; exhaust shoots out the back (−Z).
	p.rotation_degrees = Vector3(0, 180, 0)

	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 0, 1) # local +Z after 180° yaw = world rear of car
	mat.spread = 10.0
	mat.initial_velocity_min = speed * 0.5
	mat.initial_velocity_max = speed
	mat.gravity = Vector3(0, 0.25, 0)
	mat.damping_min = 2.2
	mat.damping_max = 4.0
	mat.scale_min = scale_min
	mat.scale_max = scale_max
	mat.color = color_start
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 0.04

	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.25, 0.7, 1.0])
	grad.colors = PackedColorArray([
		color_start,
		color_start,
		color_start.lerp(color_end, 0.55),
		color_end,
	])
	var grad_tex := GradientTexture1D.new()
	grad_tex.gradient = grad
	mat.color_ramp = grad_tex

	var scale_curve := Curve.new()
	scale_curve.add_point(Vector2(0.0, 0.7))
	scale_curve.add_point(Vector2(0.2, 1.0))
	scale_curve.add_point(Vector2(1.0, 0.05))
	var scale_tex := CurveTexture.new()
	scale_tex.curve = scale_curve
	mat.scale_curve = scale_tex

	p.process_material = mat

	var draw := QuadMesh.new()
	draw.size = Vector2(quad_size, quad_size)
	var draw_mat := StandardMaterial3D.new()
	draw_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	draw_mat.blend_mode = (
		BaseMaterial3D.BLEND_MODE_ADD if additive else BaseMaterial3D.BLEND_MODE_MIX
	)
	draw_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	draw_mat.vertex_color_use_as_albedo = true
	draw_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	draw_mat.billboard_keep_scale = true
	draw_mat.albedo_texture = THRUSTER_SMOKE_TEX
	draw_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	draw_mat.proximity_fade_enabled = false
	p.draw_pass_1 = draw
	p.material_override = draw_mat
	return p


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
		_end_specter_cloak()
		_end_firestorm()
		_thunderclaw_surge_remaining = 0.0
		input = Vector3.ZERO
		linear_speed = 0.0


func mark_race_finished() -> void:
	## Finished cars keep driving, but can no longer affect the remaining race
	## with weapons or missile pickups.
	has_finished_race = true
	_end_specter_cloak()
	_end_firestorm()
	_thunderclaw_surge_remaining = 0.0
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
	_update_specter_cloak(delta)
	_update_firestorm(delta)
	if _thunderclaw_surge_remaining > 0.0:
		_thunderclaw_surge_remaining = maxf(0.0, _thunderclaw_surge_remaining - delta)
	_update_molten_tip_fx(delta)
	_update_thunderclaw_electrode_fx(delta)

	if match_over:
		input = Vector3.ZERO
	elif is_player:
		handle_input(delta)
		if Input.is_action_just_pressed("bounce"):
			try_fire()
	else:
		_ai_combat(delta)
		_ai_drive(delta)

	_update_steering(delta)

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
		if _thunderclaw_surge_remaining > 0.0:
			target_speed *= THUNDERCLAW_SURGE_SPEED_MULTIPLIER
	if target_speed < 0 and linear_speed > 0.01:
		linear_speed = lerpf(linear_speed, 0.0, clampf(delta * 8.0, 0.0, 1.0))
	else:
		if target_speed < 0:
			linear_speed = lerpf(linear_speed, target_speed / 2.0, clampf(delta * 2.0, 0.0, 1.0))
		else:
			# Original throttle ramp (speed unchanged by handling retune)
			var acceleration_rate := 6.0
			if _thunderclaw_surge_remaining > 0.0:
				acceleration_rate *= THUNDERCLAW_SURGE_ACCELERATION_MULTIPLIER
			linear_speed = lerpf(
				linear_speed,
				target_speed,
				clampf(delta * acceleration_rate, 0.0, 1.0),
			)

	if sphere and vehicle_model:
		acceleration = lerpf(acceleration, linear_speed + (abs(sphere.angular_velocity.length() * linear_speed) / 100), delta * 1)
		# Modular chassis/wheels are authored higher than the legacy vehicle
		# visual. Keep their lift every physics frame instead of overwriting it.
		var visual_drop: float = 0.55 if _is_modular_model else 0.65
		vehicle_model.position = sphere.position - Vector3(0, visual_drop, 0)
		raycast.position = sphere.position
		linear_velocity = (vehicle_model.position - prev_position) / maxf(delta, 0.0001)
		prev_position = vehicle_model.position
		# Original drive coupling (speed / top-end feel)
		sphere.angular_velocity += vehicle_model.get_global_transform().basis.x * (linear_speed * 100.0) * delta

	effect_engine(delta)
	effect_body(delta)
	effect_wheels(delta)
	effect_suspension(delta)
	effect_trails()
	effect_thruster(delta)
	_update_lap_progress()
	_billboard_hp_bar()


func _update_steering(delta: float) -> void:
	## Smooth steer: quick into the turn, still filtered enough to avoid wall-to-wall zig-zag.
	var raw_steer := clampf(input.x, -1.0, 1.0)
	var rate := steer_input_rise
	if absf(raw_steer) < absf(_steer_smoothed) or (
		signf(raw_steer) != signf(_steer_smoothed) and absf(raw_steer) < 0.01
	):
		rate = steer_input_fall
	elif signf(raw_steer) != signf(_steer_smoothed) and absf(_steer_smoothed) > 0.05:
		# Flip direction quickly but not instantly
		rate = steer_input_rise * 0.9
	_steer_smoothed = move_toward(_steer_smoothed, raw_steer, rate * delta)

	var direction := signf(linear_speed)
	if direction == 0.0:
		direction = signf(input.z) if absf(input.z) > 0.1 else 1.0

	var speed_n := clampf(absf(linear_speed), 0.0, 1.0)
	# Mild high-speed falloff (linear, not squared — squared felt too soft mid-turn)
	var speed_steer := lerpf(low_speed_steer_factor, high_speed_steer_factor, speed_n)
	if speed_n < 0.05 and absf(input.z) < 0.12:
		speed_steer *= 0.55

	var target_angular := -_steer_smoothed * speed_steer * steer_sensitivity * direction
	angular_speed = lerpf(angular_speed, target_angular, clampf(delta * steer_response, 0.0, 1.0))
	if vehicle_model:
		vehicle_model.rotate_y(angular_speed * delta)


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
	if not _ai_aim_target.is_targetable_by_ai():
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
		if not other.is_targetable_by_ai():
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
	if vehicle_type == VehicleType.MOLTEN:
		_ai_firestorm_combat(delta)
		return

	# Keep or acquire a target in a wide forward cone, then steer (in _ai_drive) before firing
	if (
		_ai_aim_target != null
		and is_instance_valid(_ai_aim_target)
		and _ai_aim_target.is_targetable_by_ai()
	):
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


func _ai_firestorm_combat(delta: float) -> void:
	if is_firestorm_active:
		_ai_clear_aim()
		return

	if (
		_ai_aim_target != null
		and is_instance_valid(_ai_aim_target)
		and _ai_aim_target.is_targetable_by_ai()
	):
		var offset := _ai_aim_target.get_vehicle_position() - get_vehicle_position()
		offset.y = 0.0
		var distance := offset.length()
		if distance > FIRESTORM_RANGE or distance < 1.0:
			_ai_clear_aim()
			return
		_ai_aim_timer += delta
		var alignment := _get_weapon_forward().dot(offset.normalized())
		if alignment >= cos(deg_to_rad(FIRESTORM_HALF_ANGLE_DEGREES)):
			try_fire()
			_ai_clear_aim()
			return
		if _ai_aim_timer >= ai_aim_time_max:
			_ai_clear_aim()
		return

	_ai_clear_aim()
	var candidate := _ai_pick_firestorm_target(0.65)
	if candidate:
		_ai_aim_target = candidate
		_ai_aim_timer = 0.0


func _ai_pick_firestorm_target(acquire_dot: float) -> Vehicle:
	var best: Vehicle = null
	var best_distance := FIRESTORM_RANGE
	var forward := _get_weapon_forward()
	var origin := _get_weapon_origin()
	for node in get_tree().get_nodes_in_group("vehicles"):
		if node == self or not (node is Vehicle):
			continue
		var other := node as Vehicle
		if not other.is_targetable_by_ai():
			continue
		var offset := other.get_vehicle_position() - origin
		offset.y = 0.0
		var distance := offset.length()
		if distance < 1.0 or distance > best_distance:
			continue
		if forward.dot(offset.normalized()) < acquire_dot:
			continue
		best = other
		best_distance = distance
	return best


func add_missiles(amount: int) -> bool:
	## Returns true if any ammo was actually added (pickup may respawn).
	if amount <= 0 or not is_alive or match_over or has_finished_race:
		return false
	if missile_ammo >= max_missile_ammo:
		return false
	missile_ammo = mini(max_missile_ammo, missile_ammo + amount)
	ammo_changed.emit(missile_ammo, max_missile_ammo)
	return true


func restore_health(amount: float) -> bool:
	## Restores health without reviving destroyed cars or exceeding maximum health.
	if amount <= 0.0 or not is_alive or match_over or has_finished_race:
		return false
	if health >= max_health:
		return false
	health = minf(max_health, health + amount)
	health_changed.emit(health, max_health)
	return true


func can_scrap_harvest(wreck_position: Vector3) -> bool:
	return (
		vehicle_type == VehicleType.WRECKMONGER
		and is_alive
		and not match_over
		and not has_finished_race
		and get_vehicle_position().distance_to(wreck_position) <= WRECKMONGER_HARVEST_RADIUS
	)


func apply_scrap_harvest() -> bool:
	if vehicle_type != VehicleType.WRECKMONGER or not is_alive:
		return false
	var restored := restore_health(max_health * WRECKMONGER_HARVEST_HEALTH_RATIO)
	var rearmed := add_missiles(WRECKMONGER_HARVEST_MISSILES)
	return restored or rearmed


func try_fire() -> bool:
	if not is_alive or match_over or has_finished_race or _cooldown > 0.0:
		return false
	if missile_ammo <= 0:
		return false
	if vehicle_type == VehicleType.MOLTEN:
		return _start_firestorm()
	var was_cloaked := is_cloaked
	if was_cloaked:
		_end_specter_cloak()
	missile_ammo -= 1
	ammo_changed.emit(missile_ammo, max_missile_ammo)
	_cooldown = fire_cooldown
	var forward := _get_weapon_forward()
	var origin := _get_weapon_origin()
	var projectile_scene := (
		HomingMissileScene if vehicle_type == VehicleType.TORRENT else MissileScene
	)
	var missile: Area3D = projectile_scene.instantiate()
	var host := get_tree().current_scene
	if host:
		host.add_child(missile)
	else:
		get_parent().add_child(missile)
	missile.global_position = origin
	if missile.has_method("setup"):
		missile.setup(self, missile_damage, missile_speed, forward)
	if vehicle_type == VehicleType.TORRENT and missile.has_method("setup_homing"):
		missile.setup_homing(_find_homing_missile_target(origin, forward))
	if vehicle_type == VehicleType.SPECTER and not was_cloaked:
		_start_specter_cloak()
	if vehicle_type == VehicleType.THUNDERCLAW:
		_thunderclaw_surge_remaining = THUNDERCLAW_SURGE_DURATION
	return true


func on_missile_direct_hit(direct_target: Vehicle, direct_damage: float) -> void:
	if direct_target != null and is_instance_valid(direct_target):
		missile_direct_hit.emit(direct_target)
	## Thunderclaw chains exactly once from a successful direct missile hit.
	if (
		vehicle_type != VehicleType.THUNDERCLAW
		or not is_alive
		or match_over
		or direct_target == null
		or not is_instance_valid(direct_target)
	):
		return
	var chain_target := _find_thunderclaw_chain_target(direct_target)
	if chain_target == null:
		return
	var arc_start := direct_target.get_vehicle_position() + Vector3(0, 0.55, 0)
	var arc_end := chain_target.get_vehicle_position() + Vector3(0, 0.55, 0)
	chain_target.take_damage(
		direct_damage * THUNDERCLAW_CHAIN_DAMAGE_MULTIPLIER,
		self,
	)
	_spawn_thunderclaw_arc(arc_start, arc_end)


func _find_homing_missile_target(origin: Vector3, forward: Vector3) -> Vehicle:
	var best: Vehicle = null
	var best_distance := HOMING_LOCK_RANGE
	var minimum_dot := cos(deg_to_rad(HOMING_LOCK_HALF_ANGLE_DEGREES))
	for node in get_tree().get_nodes_in_group("vehicles"):
		if node == self or not (node is Vehicle):
			continue
		var candidate := node as Vehicle
		if (
			not candidate.is_alive
			or candidate.has_finished_race
			or candidate.is_cloaked
		):
			continue
		var target_position := candidate.get_vehicle_position() + Vector3(0, 0.45, 0)
		var offset := target_position - origin
		var distance := offset.length()
		if distance <= 0.01 or distance > best_distance:
			continue
		if forward.dot(offset.normalized()) < minimum_dot:
			continue
		if not _has_weapon_line_of_sight(origin, target_position, candidate):
			continue
		best = candidate
		best_distance = distance
	return best


func _has_weapon_line_of_sight(
	origin: Vector3,
	target_position: Vector3,
	target: Vehicle
) -> bool:
	if get_world_3d() == null:
		return true
	var query := PhysicsRayQueryParameters3D.create(origin, target_position)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	if sphere:
		query.exclude = [sphere.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return true
	var collider := hit.get("collider") as Node
	return collider == target.sphere or (collider != null and collider.get_parent() == target)


func _find_thunderclaw_chain_target(direct_target: Vehicle) -> Vehicle:
	var best: Vehicle = null
	var best_distance := THUNDERCLAW_CHAIN_RANGE
	var origin := direct_target.get_vehicle_position()
	for node in get_tree().get_nodes_in_group("vehicles"):
		if node == self or node == direct_target or not (node is Vehicle):
			continue
		var candidate := node as Vehicle
		if not candidate.is_alive or candidate.has_finished_race:
			continue
		var distance := origin.distance_to(candidate.get_vehicle_position())
		if distance > best_distance:
			continue
		best = candidate
		best_distance = distance
	return best


func _spawn_thunderclaw_arc(start: Vector3, finish: Vector3) -> void:
	var host := get_tree().current_scene
	if host == null:
		return
	var arc_root := Node3D.new()
	arc_root.name = "ThunderclawArc"
	host.add_child(arc_root)

	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = THUNDERCLAW_ARC_COLOR
	material.emission_enabled = true
	material.emission = Color("9be9ff")
	material.emission_energy_multiplier = 4.0

	var direction := finish - start
	var perpendicular := direction.cross(Vector3.UP).normalized()
	if perpendicular.length_squared() < 0.001:
		perpendicular = Vector3.RIGHT
	var points: Array[Vector3] = [start]
	for index in range(1, 5):
		var fraction := float(index) / 5.0
		var offset := perpendicular * sin(float(index) * 4.7) * 0.16
		offset.y += sin(float(index) * 7.1) * 0.09
		points.append(start.lerp(finish, fraction) + offset)
	points.append(finish)

	for index in range(points.size() - 1):
		_add_thunderclaw_arc_segment(
			arc_root,
			points[index],
			points[index + 1],
			material,
		)

	var light := OmniLight3D.new()
	light.light_color = THUNDERCLAW_ARC_COLOR
	light.light_energy = 3.0
	light.omni_range = 4.0
	light.shadow_enabled = false
	light.global_position = start.lerp(finish, 0.5)
	arc_root.add_child(light)

	var tween := arc_root.create_tween()
	tween.set_parallel(true)
	tween.tween_property(material, "albedo_color:a", 0.0, THUNDERCLAW_ARC_DURATION)
	tween.tween_property(material, "emission_energy_multiplier", 0.0, THUNDERCLAW_ARC_DURATION)
	tween.tween_property(light, "light_energy", 0.0, THUNDERCLAW_ARC_DURATION)
	tween.chain().tween_callback(arc_root.queue_free)


func _add_thunderclaw_arc_segment(
	parent: Node3D,
	start: Vector3,
	finish: Vector3,
	material: StandardMaterial3D
) -> void:
	var segment_direction := finish - start
	var segment_length := segment_direction.length()
	if segment_length <= 0.001:
		return
	var segment := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.025
	cylinder.bottom_radius = 0.025
	cylinder.height = segment_length
	cylinder.radial_segments = 5
	cylinder.rings = 1
	segment.mesh = cylinder
	segment.material_override = material
	segment.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(segment)
	segment.global_position = start.lerp(finish, 0.5)
	segment.quaternion = Quaternion(Vector3.UP, segment_direction.normalized())


func _start_firestorm() -> bool:
	if vehicle_type != VehicleType.MOLTEN or is_firestorm_active or missile_ammo <= 0:
		return false
	missile_ammo -= 1
	ammo_changed.emit(missile_ammo, max_missile_ammo)
	_cooldown = maxf(fire_cooldown, FIRESTORM_DURATION)
	is_firestorm_active = true
	_firestorm_elapsed = 0.0
	_firestorm_ticks_done = 0
	_ensure_firestorm_fx()
	_set_firestorm_emitting(true)
	return true


func _update_firestorm(delta: float) -> void:
	if not is_firestorm_active:
		return
	_firestorm_elapsed = minf(_firestorm_elapsed + delta, FIRESTORM_DURATION)
	while (
		_firestorm_ticks_done < FIRESTORM_TOTAL_TICKS
		and _firestorm_elapsed + 0.0001
			>= float(_firestorm_ticks_done + 1) * FIRESTORM_TICK_INTERVAL
	):
		_apply_firestorm_tick()
		_firestorm_ticks_done += 1
	if _firestorm_elapsed >= FIRESTORM_DURATION:
		_end_firestorm()


func _apply_firestorm_tick() -> void:
	var origin := _get_weapon_origin()
	var forward := _get_weapon_forward()
	var minimum_dot := cos(deg_to_rad(FIRESTORM_HALF_ANGLE_DEGREES))
	for node in get_tree().get_nodes_in_group("vehicles"):
		if node == self or not (node is Vehicle):
			continue
		var target := node as Vehicle
		if not target.is_alive or target.has_finished_race:
			continue
		var target_position := target.get_vehicle_position() + Vector3(0, 0.35, 0)
		var offset := target_position - origin
		var distance := offset.length()
		if distance <= 0.01 or distance > FIRESTORM_RANGE:
			continue
		if forward.dot(offset.normalized()) < minimum_dot:
			continue
		if not _firestorm_has_line_of_sight(origin, target_position, target):
			continue
		target.take_damage(FIRESTORM_DAMAGE_PER_TICK, self)


func _firestorm_has_line_of_sight(
	origin: Vector3,
	target_position: Vector3,
	target: Vehicle
) -> bool:
	if get_world_3d() == null:
		return true
	var query := PhysicsRayQueryParameters3D.create(origin, target_position)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	if sphere:
		query.exclude = [sphere.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return true
	var collider := hit.get("collider") as Node
	return collider == target.sphere or (collider != null and collider.get_parent() == target)


func _weapon_fx_parent() -> Node3D:
	if _weapon_anchor != null and is_instance_valid(_weapon_anchor):
		return _weapon_anchor
	return vehicle_model


func _weapon_fx_local_origin() -> Vector3:
	return Vector3.ZERO if _weapon_fx_parent() == _weapon_anchor else Vector3(0, 0.28, 1.1)


func _make_weapon_stream_particles(
	color_start: Color,
	color_end: Color,
	amount: int,
	life: float,
	speed: float,
	scale_min: float,
	scale_max: float,
	quad_size: float,
	additive: bool,
	spread_deg: float,
	emit_radius: float = 0.03
) -> GPUParticles3D:
	## Particles that stream along weapon local +Z (no thruster 180° flip).
	var p := _make_thruster_particles(
		color_start,
		color_end,
		amount,
		life,
		speed,
		scale_min,
		scale_max,
		quad_size,
		additive
	)
	p.rotation_degrees = Vector3.ZERO
	p.fixed_fps = 30
	p.interpolate = true
	p.visibility_aabb = AABB(Vector3(-6, -4, -2), Vector3(12, 10, 16))
	var mat := p.process_material as ParticleProcessMaterial
	if mat:
		mat.direction = Vector3(0, 0, 1)
		mat.spread = spread_deg
		mat.gravity = Vector3(0, 0.45, 0)
		mat.damping_min = 0.4
		mat.damping_max = 1.6
		mat.emission_sphere_radius = emit_radius
	return p


func _free_firestorm_fx_nodes() -> void:
	for node in [
		_firestorm_particles,
		_firestorm_outer,
		_firestorm_embers,
		_firestorm_smoke,
		_firestorm_light,
	]:
		if node != null and is_instance_valid(node):
			node.queue_free()
	_firestorm_particles = null
	_firestorm_outer = null
	_firestorm_embers = null
	_firestorm_smoke = null
	_firestorm_light = null


func _ensure_firestorm_fx() -> void:
	if _firestorm_particles != null and is_instance_valid(_firestorm_particles):
		return
	if vehicle_model == null:
		return
	var fx_parent := _weapon_fx_parent()
	if fx_parent == null:
		return
	var origin := _weapon_fx_local_origin()
	var full_fx := is_player
	var half_angle := FIRESTORM_HALF_ANGLE_DEGREES

	# Hot white-yellow core jet
	_firestorm_particles = _make_weapon_stream_particles(
		Color(1.0, 0.98, 0.75, 1.0),
		Color(1.0, 0.35, 0.02, 0.0),
		72 if full_fx else 36,
		0.38,
		18.0,
		0.22,
		0.55,
		0.48,
		true,
		half_angle * 0.55,
		0.02
	)
	_firestorm_particles.name = "FirestormCore"
	_firestorm_particles.position = origin
	_firestorm_particles.explosiveness = 0.0
	_firestorm_particles.randomness = 0.25
	fx_parent.add_child(_firestorm_particles)

	# Broader orange-red flame body
	_firestorm_outer = _make_weapon_stream_particles(
		Color(1.0, 0.55, 0.08, 0.95),
		Color(0.55, 0.04, 0.0, 0.0),
		90 if full_fx else 40,
		0.55,
		14.5,
		0.4,
		1.05,
		0.85,
		true,
		half_angle * 1.15,
		0.05
	)
	_firestorm_outer.name = "FirestormOuter"
	_firestorm_outer.position = origin
	_firestorm_outer.explosiveness = 0.0
	var outer_mat := _firestorm_outer.process_material as ParticleProcessMaterial
	if outer_mat:
		outer_mat.gravity = Vector3(0, 0.85, 0)
		outer_mat.damping_min = 0.8
		outer_mat.damping_max = 2.2
	fx_parent.add_child(_firestorm_outer)

	if full_fx:
		# Bright embers / sparks in the stream
		_firestorm_embers = _make_weapon_stream_particles(
			Color(1.0, 0.9, 0.4, 1.0),
			Color(1.0, 0.2, 0.0, 0.0),
			48,
			0.45,
			20.0,
			0.06,
			0.18,
			0.22,
			true,
			half_angle * 1.35,
			0.04
		)
		_firestorm_embers.name = "FirestormEmbers"
		_firestorm_embers.position = origin
		_firestorm_embers.randomness = 0.55
		var ember_mat := _firestorm_embers.process_material as ParticleProcessMaterial
		if ember_mat:
			ember_mat.gravity = Vector3(0, 1.4, 0)
			ember_mat.damping_min = 0.2
			ember_mat.damping_max = 1.0
		fx_parent.add_child(_firestorm_embers)

		# Soft dark smoke billow mixed in (reads as real fire)
		_firestorm_smoke = _make_weapon_stream_particles(
			Color(0.35, 0.18, 0.08, 0.55),
			Color(0.12, 0.08, 0.06, 0.0),
			36,
			0.85,
			8.5,
			0.55,
			1.4,
			1.15,
			false,
			half_angle * 1.5,
			0.06
		)
		_firestorm_smoke.name = "FirestormSmoke"
		_firestorm_smoke.position = origin + Vector3(0, 0.02, 0.05)
		var smoke_mat := _firestorm_smoke.process_material as ParticleProcessMaterial
		if smoke_mat:
			smoke_mat.gravity = Vector3(0, 1.6, 0)
			smoke_mat.damping_min = 1.5
			smoke_mat.damping_max = 3.0
		fx_parent.add_child(_firestorm_smoke)

	_firestorm_light = OmniLight3D.new()
	_firestorm_light.name = "FirestormLight"
	_firestorm_light.light_color = Color("ff6a18")
	_firestorm_light.light_energy = 3.4
	_firestorm_light.omni_range = 6.5
	_firestorm_light.shadow_enabled = false
	_firestorm_light.position = (
		origin + Vector3(0, 0.05, 1.1) if fx_parent == _weapon_anchor else Vector3(0, 0.55, 2.2)
	)
	fx_parent.add_child(_firestorm_light)


func _set_firestorm_emitting(on: bool) -> void:
	for p in [_firestorm_particles, _firestorm_outer, _firestorm_embers, _firestorm_smoke]:
		if p != null and is_instance_valid(p):
			if on:
				p.restart()
			p.emitting = on
	if _firestorm_light and is_instance_valid(_firestorm_light):
		_firestorm_light.visible = on


func _end_firestorm() -> void:
	if not is_firestorm_active and _firestorm_particles == null:
		return
	is_firestorm_active = false
	_firestorm_elapsed = 0.0
	_firestorm_ticks_done = 0
	_set_firestorm_emitting(false)


func _free_molten_tip_fx() -> void:
	for node in [_flame_tip_core, _flame_tip_glow, _flame_tip_light]:
		if node != null and is_instance_valid(node):
			node.queue_free()
	_flame_tip_core = null
	_flame_tip_glow = null
	_flame_tip_light = null


func _ensure_molten_tip_fx() -> void:
	if vehicle_type != VehicleType.MOLTEN:
		return
	if _flame_tip_core != null and is_instance_valid(_flame_tip_core):
		return
	if vehicle_model == null:
		return
	var fx_parent := _weapon_fx_parent()
	if fx_parent == null:
		return
	var origin := _weapon_fx_local_origin()
	var full_fx := is_player

	# Pilot flame: small continuous jet at the nozzle tip
	_flame_tip_core = _make_weapon_stream_particles(
		Color(1.0, 0.92, 0.45, 1.0),
		Color(1.0, 0.25, 0.0, 0.0),
		28 if full_fx else 14,
		0.16,
		3.2,
		0.1,
		0.28,
		0.28,
		true,
		12.0,
		0.012
	)
	_flame_tip_core.name = "FlameTipCore"
	_flame_tip_core.position = origin
	_flame_tip_core.emitting = true
	_flame_tip_core.explosiveness = 0.0
	var tip_mat := _flame_tip_core.process_material as ParticleProcessMaterial
	if tip_mat:
		tip_mat.gravity = Vector3(0, 0.9, 0)
		tip_mat.damping_min = 1.0
		tip_mat.damping_max = 2.5
	fx_parent.add_child(_flame_tip_core)

	if full_fx:
		_flame_tip_glow = _make_weapon_stream_particles(
			Color(1.0, 0.55, 0.12, 0.9),
			Color(0.8, 0.1, 0.0, 0.0),
			18,
			0.22,
			2.0,
			0.18,
			0.42,
			0.4,
			true,
			22.0,
			0.02
		)
		_flame_tip_glow.name = "FlameTipGlow"
		_flame_tip_glow.position = origin
		_flame_tip_glow.emitting = true
		_flame_tip_glow.explosiveness = 0.0
		fx_parent.add_child(_flame_tip_glow)

	_flame_tip_light = OmniLight3D.new()
	_flame_tip_light.name = "FlameTipLight"
	_flame_tip_light.light_color = Color("ff7a22")
	_flame_tip_light.light_energy = 1.1
	_flame_tip_light.omni_range = 2.4
	_flame_tip_light.shadow_enabled = false
	_flame_tip_light.position = origin + Vector3(0, 0.02, 0.12)
	fx_parent.add_child(_flame_tip_light)


func _update_molten_tip_fx(_delta: float) -> void:
	if vehicle_type != VehicleType.MOLTEN:
		return
	if _flame_tip_core == null or not is_instance_valid(_flame_tip_core):
		return
	var alive := is_alive and not match_over
	_flame_tip_core.emitting = alive
	if _flame_tip_glow and is_instance_valid(_flame_tip_glow):
		_flame_tip_glow.emitting = alive
	if not alive:
		if _flame_tip_light and is_instance_valid(_flame_tip_light):
			_flame_tip_light.light_energy = 0.0
		return

	# Idle pilot is small; while firestorm is active the tip roars.
	var power := 1.0
	if is_firestorm_active:
		power = 2.4
	var core_mat := _flame_tip_core.process_material as ParticleProcessMaterial
	if core_mat:
		var base_spd := 2.6 + power * 2.8
		core_mat.initial_velocity_min = base_spd * 0.55
		core_mat.initial_velocity_max = base_spd
		core_mat.scale_min = 0.08 + power * 0.06
		core_mat.scale_max = 0.2 + power * 0.14
	if _flame_tip_glow and is_instance_valid(_flame_tip_glow):
		var glow_mat := _flame_tip_glow.process_material as ParticleProcessMaterial
		if glow_mat:
			var gspd := 1.6 + power * 1.8
			glow_mat.initial_velocity_min = gspd * 0.5
			glow_mat.initial_velocity_max = gspd
	if _flame_tip_light and is_instance_valid(_flame_tip_light):
		var flicker := 0.85 + 0.15 * sin(Time.get_ticks_msec() * 0.028)
		_flame_tip_light.light_energy = (0.85 + power * 0.55) * flicker
		_flame_tip_light.omni_range = 1.8 + power * 0.9
		_flame_tip_light.light_color = Color("ff7a22").lerp(
			Color("ffee88"),
			clampf(power - 1.0, 0.0, 1.0) * 0.35
		)

	# Firestorm light flicker while active
	if is_firestorm_active and _firestorm_light and is_instance_valid(_firestorm_light):
		var fl := 0.75 + 0.25 * sin(Time.get_ticks_msec() * 0.041)
		fl *= 0.9 + 0.1 * sin(Time.get_ticks_msec() * 0.097)
		_firestorm_light.light_energy = 3.2 * fl
		_firestorm_light.light_color = Color("ff6a18").lerp(
			Color("ffcc44"),
			0.15 + 0.2 * sin(Time.get_ticks_msec() * 0.02)
		)


func _free_thunderclaw_electrode_fx() -> void:
	for node in [_electrode_sparks, _electrode_corona, _electrode_light]:
		if node != null and is_instance_valid(node):
			node.queue_free()
	_electrode_sparks = null
	_electrode_corona = null
	_electrode_light = null
	_electrode_arc_timer = 0.0


func _ensure_thunderclaw_electrode_fx() -> void:
	if vehicle_type != VehicleType.THUNDERCLAW:
		return
	if _electrode_sparks != null and is_instance_valid(_electrode_sparks):
		return
	if vehicle_model == null:
		return
	var fx_parent := _electrode_fx_parent()
	if fx_parent == null:
		return
	# Local origin of ElectrodeAnchor (roof spike), not the front WeaponAnchor.
	var origin := _electrode_fx_local_origin()
	var full_fx := is_player
	var arc_col := THUNDERCLAW_ARC_COLOR
	var arc_hot := Color("d8f6ff")

	_electrode_corona = _make_thruster_particles(
		Color(arc_col.r, arc_col.g, arc_col.b, 0.85),
		Color(arc_hot.r, arc_hot.g, arc_hot.b, 0.0),
		22 if full_fx else 10,
		0.22,
		1.1,
		0.12,
		0.32,
		0.34,
		true
	)
	_electrode_corona.name = "ElectrodeCorona"
	_electrode_corona.position = origin
	_electrode_corona.rotation_degrees = Vector3.ZERO
	_electrode_corona.fixed_fps = 30
	_electrode_corona.interpolate = true
	_electrode_corona.emitting = true
	_electrode_corona.explosiveness = 0.0
	_electrode_corona.randomness = 0.5
	var corona_mat := _electrode_corona.process_material as ParticleProcessMaterial
	if corona_mat:
		# Soft radial bloom around the electrode (not a rear thruster jet).
		corona_mat.direction = Vector3(0, 1, 0)
		corona_mat.spread = 180.0
		corona_mat.gravity = Vector3(0, 0.15, 0)
		corona_mat.damping_min = 2.5
		corona_mat.damping_max = 4.5
		corona_mat.emission_sphere_radius = 0.05
		corona_mat.initial_velocity_min = 0.35
		corona_mat.initial_velocity_max = 1.1
	fx_parent.add_child(_electrode_corona)

	_electrode_sparks = _make_thruster_particles(
		Color(arc_hot.r, arc_hot.g, arc_hot.b, 1.0),
		Color(arc_col.r, arc_col.g, arc_col.b, 0.0),
		30 if full_fx else 12,
		0.12,
		3.5,
		0.04,
		0.12,
		0.16,
		true
	)
	_electrode_sparks.name = "ElectrodeSparks"
	_electrode_sparks.position = origin
	_electrode_sparks.rotation_degrees = Vector3.ZERO
	_electrode_sparks.fixed_fps = 30
	_electrode_sparks.interpolate = true
	_electrode_sparks.emitting = true
	_electrode_sparks.explosiveness = 0.15
	_electrode_sparks.randomness = 0.7
	var spark_mat := _electrode_sparks.process_material as ParticleProcessMaterial
	if spark_mat:
		spark_mat.direction = Vector3(0, 1, 0)
		spark_mat.spread = 160.0
		spark_mat.gravity = Vector3(0, -0.4, 0)
		spark_mat.damping_min = 1.0
		spark_mat.damping_max = 3.0
		spark_mat.emission_sphere_radius = 0.03
		spark_mat.initial_velocity_min = 1.2
		spark_mat.initial_velocity_max = 3.8
	fx_parent.add_child(_electrode_sparks)

	_electrode_light = OmniLight3D.new()
	_electrode_light.name = "ElectrodeLight"
	_electrode_light.light_color = arc_col
	_electrode_light.light_energy = 1.2
	_electrode_light.omni_range = 2.8
	_electrode_light.shadow_enabled = false
	_electrode_light.position = origin
	fx_parent.add_child(_electrode_light)


func _update_thunderclaw_electrode_fx(delta: float) -> void:
	if vehicle_type != VehicleType.THUNDERCLAW:
		return
	if _electrode_sparks == null or not is_instance_valid(_electrode_sparks):
		return
	var alive := is_alive and not match_over
	_electrode_sparks.emitting = alive
	if _electrode_corona and is_instance_valid(_electrode_corona):
		_electrode_corona.emitting = alive
	if not alive:
		if _electrode_light and is_instance_valid(_electrode_light):
			_electrode_light.light_energy = 0.0
		return

	var surging := _thunderclaw_surge_remaining > 0.0
	var power := 2.8 if surging else 1.0
	var t := Time.get_ticks_msec() * 0.001
	var crackle := 0.7 + 0.3 * sin(t * 28.0) * sin(t * 11.3)

	var spark_mat := _electrode_sparks.process_material as ParticleProcessMaterial
	if spark_mat:
		var spd := (2.2 + power * 3.5) * crackle
		spark_mat.initial_velocity_min = spd * 0.45
		spark_mat.initial_velocity_max = spd
		spark_mat.scale_min = 0.03 + power * 0.02
		spark_mat.scale_max = 0.1 + power * 0.06
	if _electrode_corona and is_instance_valid(_electrode_corona):
		var corona_mat := _electrode_corona.process_material as ParticleProcessMaterial
		if corona_mat:
			var cspd := 0.5 + power * 1.1
			corona_mat.initial_velocity_min = cspd * 0.4
			corona_mat.initial_velocity_max = cspd
			corona_mat.scale_min = 0.1 + power * 0.08
			corona_mat.scale_max = 0.25 + power * 0.18
	if _electrode_light and is_instance_valid(_electrode_light):
		_electrode_light.light_energy = (0.9 + power * 1.6) * crackle
		_electrode_light.omni_range = 2.2 + power * 1.8
		_electrode_light.light_color = THUNDERCLAW_ARC_COLOR.lerp(Color("e8fbff"), 0.25 if surging else 0.0)

	# Occasional micro-arcs snapping off the electrode while surging (player only).
	if surging and is_player and is_inside_tree():
		_electrode_arc_timer -= delta
		if _electrode_arc_timer <= 0.0:
			_electrode_arc_timer = randf_range(0.22, 0.42)
			_spawn_electrode_micro_arc()


func _spawn_electrode_micro_arc() -> void:
	if vehicle_model == null:
		return
	var origin := Vector3.ZERO
	if _electrode_anchor != null and is_instance_valid(_electrode_anchor):
		origin = _electrode_anchor.global_position
	elif _electrode_sparks != null and is_instance_valid(_electrode_sparks):
		origin = _electrode_sparks.global_position
	else:
		origin = vehicle_model.global_position + Vector3(0, 1.1, -0.6)
	var yaw := randf() * TAU
	var pitch := randf_range(0.35, 1.15)
	var reach := randf_range(0.35, 0.85)
	var tip := origin + Vector3(cos(yaw) * reach * 0.55, pitch * reach * 0.65, sin(yaw) * reach * 0.55)
	_spawn_thunderclaw_arc(origin, tip)


func is_targetable_by_ai() -> bool:
	return is_alive and not has_finished_race and not is_cloaked


func _update_specter_cloak(delta: float) -> void:
	if vehicle_type != VehicleType.SPECTER:
		return
	if _cloak_cooldown_remaining > 0.0:
		_cloak_cooldown_remaining = maxf(0.0, _cloak_cooldown_remaining - delta)
	if not is_cloaked:
		return
	_cloak_remaining = maxf(0.0, _cloak_remaining - delta)
	if _cloak_remaining <= 0.0:
		_end_specter_cloak()


func _start_specter_cloak() -> void:
	if (
		vehicle_type != VehicleType.SPECTER
		or not is_alive
		or is_cloaked
		or _cloak_cooldown_remaining > 0.0
	):
		return
	is_cloaked = true
	_cloak_remaining = SPECTER_CLOAK_DURATION
	_cloak_cooldown_remaining = SPECTER_CLOAK_COOLDOWN
	_set_vehicle_transparency(SPECTER_CLOAK_TRANSPARENCY)
	if _hp_root:
		_hp_root.visible = false


func _end_specter_cloak() -> void:
	if not is_cloaked:
		return
	is_cloaked = false
	_cloak_remaining = 0.0
	_set_vehicle_transparency(0.0)
	if _hp_root and is_alive:
		_hp_root.visible = true


func _set_vehicle_transparency(amount: float) -> void:
	if vehicle_model == null:
		return
	for descendant in vehicle_model.find_children("*", "GeometryInstance3D", true, false):
		var geometry := descendant as GeometryInstance3D
		if geometry:
			geometry.transparency = amount


func take_damage(amount: float, source: Node = null, damage_kind: StringName = &"vehicle") -> void:
	if not is_alive or match_over:
		return
	if source is Vehicle and source != self and (source as Vehicle).is_alive:
		_last_damage_source = weakref(source)
		_last_damage_source_msec = Time.get_ticks_msec()
		_last_damage_kind = damage_kind
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


func get_last_damage_kind() -> StringName:
	if get_last_damage_source() == null:
		return &""
	return _last_damage_kind


func _die() -> void:
	if not is_alive:
		return
	_end_specter_cloak()
	_end_firestorm()
	_thunderclaw_surge_remaining = 0.0
	if _flame_tip_core and is_instance_valid(_flame_tip_core):
		_flame_tip_core.emitting = false
	if _flame_tip_glow and is_instance_valid(_flame_tip_glow):
		_flame_tip_glow.emitting = false
	if _flame_tip_light and is_instance_valid(_flame_tip_light):
		_flame_tip_light.light_energy = 0.0
	if _electrode_sparks and is_instance_valid(_electrode_sparks):
		_electrode_sparks.emitting = false
	if _electrode_corona and is_instance_valid(_electrode_corona):
		_electrode_corona.emitting = false
	if _electrode_light and is_instance_valid(_electrode_light):
		_electrode_light.light_energy = 0.0
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
	# Use smoothed steer so visual lean matches actual turn, not keyboard snaps
	calculated_lean = lerp_angle(
		calculated_lean,
		-_steer_smoothed / 5.5 * linear_speed * body_lean_strength,
		delta * 4.0
	)
	if vehicle_body == null:
		return
	# Pitch under accel/brake + roll in turns (chassis or monomesh)
	var pitch := clampf(-(linear_speed - acceleration) / 6.0, -0.28, 0.28) * body_lean_strength
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
	## Only 2 of 4 wheels raycast each frame (staggered) to cut physics queries ~50%.
	if _wheel_rest_positions.is_empty():
		return
	var wheels: Array[Node3D] = [wheel_fl, wheel_fr, wheel_bl, wheel_br]
	_suspension_phase = (_suspension_phase + 1) % 2
	# Phase 0: front pair, phase 1: rear pair (or whatever two indices).
	var start_i := _suspension_phase * 2
	for offset in 2:
		var i := start_i + offset
		if i >= wheels.size():
			continue
		var wheel := wheels[i]
		if wheel == null or not _wheel_rest_positions.has(wheel):
			continue
		var parent := wheel.get_parent() as Node3D
		if parent == null:
			continue
		var rest: Vector3 = _wheel_rest_positions[wheel]
		var authored_world := parent.to_global(Vector3(rest.x, 0.0, rest.z))
		var hit := _get_road_hit(authored_world)
		var target_y := rest.y
		if not hit.is_empty():
			var wheel_visual := wheel.get_node_or_null("Wheel") as Node3D
			var wheel_scale: float = (
				wheel_visual.global_transform.basis.get_scale().y
				if wheel_visual
				else wheel.global_transform.basis.get_scale().y
			)
			var radius := modular_wheel_radius * wheel_scale
			var hit_position: Vector3 = hit["position"]
			var hub_world := Vector3(authored_world.x, hit_position.y + radius, authored_world.z)
			target_y = parent.to_local(hub_world).y
		target_y = clampf(target_y, rest.y - modular_wheel_travel_down, rest.y + modular_wheel_travel_up)
		_wheel_suspension_delta[wheel] = target_y - rest.y
		wheel.position.y = lerpf(
			wheel.position.y,
			target_y,
			clampf(delta * modular_suspension_smoothing, 0.0, 1.0)
		)

	# Smooth all wheels toward last known targets (non-raycasted wheels keep previous delta).
	var total_delta := 0.0
	var contact_count := 0
	for wheel in wheels:
		if wheel == null or not _wheel_rest_positions.has(wheel):
			continue
		var rest2: Vector3 = _wheel_rest_positions[wheel]
		if not _wheel_suspension_delta.has(wheel):
			_wheel_suspension_delta[wheel] = 0.0
		var d: float = _wheel_suspension_delta[wheel]
		# Non-updated wheels still ease toward cached target height.
		if wheel != wheels[start_i] and wheel != wheels[mini(start_i + 1, wheels.size() - 1)]:
			var cached_y := rest2.y + d
			wheel.position.y = lerpf(
				wheel.position.y,
				cached_y,
				clampf(delta * modular_suspension_smoothing * 0.75, 0.0, 1.0)
			)
		total_delta += d
		contact_count += 1

	var body_target_y := _body_rest.y
	if contact_count > 0:
		body_target_y += total_delta / float(contact_count)
	body_target_y = maxf(body_target_y, _body_rest.y - modular_chassis_max_drop)
	vehicle_body.position.y = lerpf(
		vehicle_body.position.y,
		body_target_y,
		clampf(delta * modular_suspension_smoothing, 0.0, 1.0)
	)


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
	var wheel_yaw := -_steer_smoothed / 2.2
	if wheel_fl != null:
		wheel_fl.rotation.y = lerp_angle(wheel_fl.rotation.y, wheel_yaw, delta * 8.0)
	if wheel_fr != null:
		wheel_fr.rotation.y = lerp_angle(wheel_fr.rotation.y, wheel_yaw, delta * 8.0)


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


func effect_thruster(delta: float) -> void:
	if not thruster_enabled:
		return
	if _thruster_core == null or not is_instance_valid(_thruster_core):
		return
	# Forward throttle + speed feed the rear propulsor; idle glow when nearly stopped.
	var throttle_fwd := clampf(input.z, 0.0, 1.0)
	var speed_n := clampf(absf(linear_speed), 0.0, 1.0)
	var target_power := thruster_idle_power
	if is_alive and not match_over:
		target_power = thruster_idle_power + (1.0 - thruster_idle_power) * clampf(
			throttle_fwd * 0.75 + speed_n * 0.45,
			0.0,
			thruster_max_power
		)
		if throttle_fwd < 0.05 and speed_n < 0.08:
			target_power = thruster_idle_power * 0.65
		if _thunderclaw_surge_remaining > 0.0:
			target_power = thruster_max_power
	else:
		target_power = 0.0
	_thruster_power = lerpf(_thruster_power, target_power, clampf(delta * 8.0, 0.0, 1.0))

	var on := _thruster_power > 0.02
	_thruster_core.emitting = on
	if _thruster_spark:
		_thruster_spark.emitting = on and _thruster_power > 0.15

	var len_s := thruster_length_scale
	var core_mat := _thruster_core.process_material as ParticleProcessMaterial
	if core_mat:
		var base_spd := (1.8 + _thruster_power * 3.8) * len_s
		core_mat.initial_velocity_min = base_spd * 0.5
		core_mat.initial_velocity_max = base_spd
		core_mat.scale_min = 0.18 + _thruster_power * 0.22
		core_mat.scale_max = 0.38 + _thruster_power * 0.4
	if _thruster_spark:
		var spark_mat := _thruster_spark.process_material as ParticleProcessMaterial
		if spark_mat:
			var spark_spd := (2.6 + _thruster_power * 5.0) * len_s
			spark_mat.initial_velocity_min = spark_spd * 0.55
			spark_mat.initial_velocity_max = spark_spd
	if _thruster_light:
		_thruster_light.light_color = _thruster_color
		_thruster_light.light_energy = _thruster_power * 2.2
		_thruster_light.omni_range = 1.2 + _thruster_power * 1.6
		if _thruster_power > 0.2:
			_thruster_light.light_energy *= 0.9 + 0.1 * sin(Time.get_ticks_msec() * 0.045)


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
