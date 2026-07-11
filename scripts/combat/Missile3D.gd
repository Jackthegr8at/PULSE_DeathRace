class_name Missile3D
extends Area3D
## Straight-flying 3D missile using scenes/combat/missile.glb.
## On hit: explode (particles + flash + impact sound) then free.

@export var speed: float = 28.0
@export var damage: float = 15.0
@export var lifetime: float = 2.5
@export var model_scale: float = 0.25
@export var model_rotation_degrees: Vector3 = Vector3(0, 180, 0)
@export var explosion_lifetime: float = 0.55

const SMOKE_TEX := preload("res://sprites/smoke.png")
const IMPACT_SFX := preload("res://audio/impact.ogg")

var owner_vehicle: Vehicle = null
var _velocity: Vector3 = Vector3.ZERO
var _age: float = 0.0
var _exploded: bool = false

@onready var model: Node3D = get_node_or_null("Model")


func setup(shooter: Vehicle, dmg: float, spd: float, dir: Vector3) -> void:
	owner_vehicle = shooter
	damage = dmg
	speed = spd
	var d := dir
	d.y = 0.0
	if d.length_squared() < 0.0001:
		d = Vector3(0, 0, 1)
	_velocity = d.normalized() * speed
	if _velocity.length_squared() > 0.001:
		look_at(global_position + _velocity, Vector3.UP)
	_apply_model_transform()


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	monitoring = true
	collision_layer = 16
	collision_mask = 1 | 8
	_apply_model_transform()


func _apply_model_transform() -> void:
	if model == null:
		model = get_node_or_null("Model")
	if model == null:
		return
	model.scale = Vector3.ONE * model_scale
	model.rotation_degrees = model_rotation_degrees


func _physics_process(delta: float) -> void:
	if _exploded:
		return
	global_position += _velocity * delta
	_age += delta
	if _age >= lifetime:
		_explode()


func _on_body_entered(body: Node) -> void:
	if _exploded:
		return
	if owner_vehicle and (body == owner_vehicle.sphere or body.get_parent() == owner_vehicle):
		return
	var veh: Vehicle = null
	if body is RigidBody3D and body.get_parent() is Vehicle:
		veh = body.get_parent() as Vehicle
	elif body is Vehicle:
		veh = body as Vehicle
	if veh and veh != owner_vehicle and veh.is_alive:
		veh.take_damage(damage, owner_vehicle)
		_explode()
		return
	if body is StaticBody3D or body is GridMap:
		_explode()


func _explode() -> void:
	if _exploded:
		return
	_exploded = true
	_velocity = Vector3.ZERO
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	collision_layer = 0
	collision_mask = 0

	if model:
		model.visible = false
	var shape := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if shape:
		shape.set_deferred("disabled", true)

	_spawn_explosion_fx()
	_play_impact_sound()

	await get_tree().create_timer(explosion_lifetime).timeout
	if is_instance_valid(self):
		queue_free()


func _spawn_explosion_fx() -> void:
	# Bright flash
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.55, 0.15)
	light.light_energy = 6.0
	light.omni_range = 6.0
	light.position = Vector3.ZERO
	add_child(light)
	var light_tw := create_tween()
	light_tw.tween_property(light, "light_energy", 0.0, explosion_lifetime * 0.85)

	# Core burst (orange/yellow fire)
	var fire := _make_particles(
		Color(1.0, 0.45, 0.08, 1.0),
		Color(1.0, 0.85, 0.2, 0.0),
		28,
		explosion_lifetime * 0.9,
		4.5,
		1.2
	)
	add_child(fire)
	fire.emitting = true

	# Smoke puff
	var smoke := _make_particles(
		Color(0.35, 0.32, 0.3, 0.9),
		Color(0.2, 0.2, 0.2, 0.0),
		20,
		explosion_lifetime,
		2.8,
		2.0
	)
	add_child(smoke)
	smoke.emitting = true


func _make_particles(
	color_start: Color,
	color_end: Color,
	amount: int,
	life: float,
	spread_speed: float,
	scale_max: float
) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.emitting = false
	p.one_shot = true
	p.explosiveness = 0.95
	p.amount = amount
	p.lifetime = life
	p.visibility_aabb = AABB(Vector3(-8, -8, -8), Vector3(16, 16, 16))

	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 1, 0)
	mat.spread = 180.0
	mat.initial_velocity_min = spread_speed * 0.4
	mat.initial_velocity_max = spread_speed
	mat.gravity = Vector3(0, 1.5, 0)
	mat.damping_min = 1.0
	mat.damping_max = 3.0
	mat.scale_min = scale_max * 0.35
	mat.scale_max = scale_max
	mat.color = color_start

	# Fade via gradient
	var grad := Gradient.new()
	grad.colors = PackedColorArray([color_start, color_end])
	var grad_tex := GradientTexture1D.new()
	grad_tex.gradient = grad
	mat.color_ramp = grad_tex

	p.process_material = mat

	var draw := QuadMesh.new()
	draw.size = Vector2(0.35, 0.35)
	var draw_mat := StandardMaterial3D.new()
	draw_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	draw_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	draw_mat.vertex_color_use_as_albedo = true
	draw_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	draw_mat.albedo_texture = SMOKE_TEX
	draw_mat.albedo_color = Color(1, 1, 1, 1)
	p.draw_pass_1 = draw
	p.material_override = draw_mat
	return p


func _play_impact_sound() -> void:
	var sfx := AudioStreamPlayer3D.new()
	sfx.stream = IMPACT_SFX
	sfx.volume_db = -2.0
	sfx.pitch_scale = randf_range(0.85, 1.15)
	sfx.max_distance = 40.0
	add_child(sfx)
	sfx.play()
