class_name Missile3D
extends Area3D
## Straight-flying 3D missile using scenes/combat/missile.glb.
## On hit: explode (particles + flash + impact sound) then free.

@export var speed: float = 28.0
@export var damage: float = 15.0
@export var lifetime: float = 2.5
@export var model_scale: float = 0.25
@export var model_rotation_degrees: Vector3 = Vector3(0, 180, 0)
## Punchy Pulse blast (concept sheets: magenta energy + cyan spark).
@export var explosion_lifetime: float = 0.6
@export var explosion_scale: float = 1.05

const SMOKE_TEX := preload("res://sprites/smoke.png")
const IMPACT_SFX := preload("res://audio/impact.ogg")

# concept1–6 Pulse palette: hot magenta identity, cyan electric, scrap orange secondary.
const COL_PULSE := Color("ff2ec8") ## Brand pink / missile power-up
const COL_PULSE_HOT := Color("ff6ef0") ## Hot core
const COL_CYAN := Color("3de8ff") ## Electric / shield-adjacent
const COL_PURPLE := Color("a84cff") ## EMP / energy fade
const COL_SCRAP := Color("ff7a2e") ## Scrap fire secondary
const COL_WHITE := Color("fff0ff")

var owner_vehicle: Vehicle = null
var _velocity: Vector3 = Vector3.ZERO
var _age: float = 0.0
var _exploded: bool = false

@onready var model: Node3D = get_node_or_null("Model")
@onready var flight_glow: OmniLight3D = get_node_or_null("Glow")


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
	if flight_glow:
		flight_glow.visible = false
	var shape := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if shape:
		shape.set_deferred("disabled", true)

	_spawn_explosion_fx()
	_play_impact_sound()

	await get_tree().create_timer(explosion_lifetime).timeout
	if is_instance_valid(self):
		queue_free()


func _spawn_explosion_fx() -> void:
	## Pulse DeathRace (concept1–6): hot magenta energy blast + cyan electric sparks.
	## Matches missile power-up / landmine / pulse-gate language — not gold UI fire.
	var s := explosion_scale

	# Magenta core flash + brief cyan kick
	var flash := OmniLight3D.new()
	flash.light_color = COL_PULSE
	flash.light_energy = 9.0 * s
	flash.omni_range = 6.0 * s
	flash.shadow_enabled = false
	add_child(flash)
	var kick := OmniLight3D.new()
	kick.light_color = COL_CYAN
	kick.light_energy = 4.0 * s
	kick.omni_range = 4.0 * s
	kick.shadow_enabled = false
	add_child(kick)
	var light_tw := create_tween()
	light_tw.set_parallel(true)
	light_tw.tween_property(flash, "light_energy", 0.0, explosion_lifetime * 0.5)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	light_tw.tween_property(kick, "light_energy", 0.0, explosion_lifetime * 0.28)\
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)

	# Energy ring (pulse gate / brand pink)
	_spawn_pulse_ring(s)

	# White-pink core pop
	var core := _make_pulse_burst(
		Color(COL_WHITE.r, COL_WHITE.g, COL_WHITE.b, 1.0),
		Color(COL_PULSE_HOT.r, COL_PULSE_HOT.g, COL_PULSE_HOT.b, 0.0),
		14,
		explosion_lifetime * 0.35,
		4.5 * s,
		0.55 * s,
		1.0 * s,
		1.0,
		true
	)
	add_child(core)
	core.emitting = true

	# Main Pulse cloud: magenta → purple
	var pulse := _make_pulse_burst(
		Color(COL_PULSE.r, COL_PULSE.g, COL_PULSE.b, 1.0),
		Color(COL_PURPLE.r, COL_PURPLE.g, COL_PURPLE.b, 0.0),
		26,
		explosion_lifetime * 0.75,
		4.0 * s,
		0.95 * s,
		1.7 * s,
		1.35,
		true
	)
	add_child(pulse)
	pulse.emitting = true

	# Thin scrap-fire rim (combat grit without dominating the brand color)
	var scrap := _make_pulse_burst(
		Color(COL_SCRAP.r, COL_SCRAP.g, COL_SCRAP.b, 0.9),
		Color(COL_SCRAP.r, COL_SCRAP.g, COL_SCRAP.b, 0.0),
		10,
		explosion_lifetime * 0.55,
		3.2 * s,
		0.7 * s,
		1.2 * s,
		1.1,
		true
	)
	add_child(scrap)
	scrap.emitting = true

	# Cyan electric sparks (shield / EMP family)
	var sparks := _make_pulse_burst(
		Color(COL_CYAN.r, COL_CYAN.g, COL_CYAN.b, 1.0),
		Color(COL_PULSE_HOT.r, COL_PULSE_HOT.g, COL_PULSE_HOT.b, 0.0),
		20,
		explosion_lifetime * 0.48,
		7.5 * s,
		0.15 * s,
		0.35 * s,
		0.5,
		true
	)
	var spark_mat := sparks.process_material as ParticleProcessMaterial
	if spark_mat:
		spark_mat.spread = 120.0
		spark_mat.gravity = Vector3(0, -5.0, 0)
		spark_mat.damping_min = 0.3
		spark_mat.damping_max = 1.2
	add_child(sparks)
	sparks.emitting = true


func _spawn_pulse_ring(s: float) -> void:
	## Expanding energy ring — same family as concept pulse gate / landmine glow.
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.16 * s
	torus.outer_radius = 0.3 * s
	torus.rings = 10
	torus.ring_segments = 20
	ring.mesh = torus
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(COL_PULSE.r, COL_PULSE.g, COL_PULSE.b, 0.95)
	mat.emission_enabled = true
	mat.emission = COL_PULSE_HOT
	mat.emission_energy_multiplier = 2.4
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	ring.material_override = mat
	ring.rotation_degrees = Vector3(90, 0, 0)
	add_child(ring)

	# Cyan electric outer rim
	var rim := MeshInstance3D.new()
	var torus_rim := TorusMesh.new()
	torus_rim.inner_radius = 0.12 * s
	torus_rim.outer_radius = 0.36 * s
	torus_rim.rings = 10
	torus_rim.ring_segments = 20
	rim.mesh = torus_rim
	var rim_mat := StandardMaterial3D.new()
	rim_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rim_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rim_mat.albedo_color = Color(COL_CYAN.r, COL_CYAN.g, COL_CYAN.b, 0.55)
	rim_mat.emission_enabled = true
	rim_mat.emission = COL_CYAN
	rim_mat.emission_energy_multiplier = 1.4
	rim_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	rim.material_override = rim_mat
	rim.rotation_degrees = Vector3(90, 0, 0)
	rim.position = Vector3(0, -0.015, 0)
	add_child(rim)

	var end_scale := 3.4 * s
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(ring, "scale", Vector3.ONE * end_scale, explosion_lifetime * 0.48)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(rim, "scale", Vector3.ONE * (end_scale * 1.08), explosion_lifetime * 0.48)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(mat, "albedo_color:a", 0.0, explosion_lifetime * 0.48)
	tw.tween_property(rim_mat, "albedo_color:a", 0.0, explosion_lifetime * 0.48)
	tw.tween_property(mat, "emission_energy_multiplier", 0.0, explosion_lifetime * 0.4)
	tw.tween_property(rim_mat, "emission_energy_multiplier", 0.0, explosion_lifetime * 0.35)
	tw.chain().tween_callback(func() -> void:
		if is_instance_valid(ring):
			ring.queue_free()
		if is_instance_valid(rim):
			rim.queue_free()
	)


func _make_pulse_burst(
	color_start: Color,
	color_end: Color,
	amount: int,
	life: float,
	spread_speed: float,
	scale_min: float,
	scale_max: float,
	quad_size: float,
	additive: bool
) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.emitting = false
	p.one_shot = true
	p.explosiveness = 0.98
	p.randomness = 0.25
	p.amount = amount
	p.lifetime = life
	p.visibility_aabb = AABB(Vector3(-10, -10, -10), Vector3(20, 20, 20))
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 1, 0)
	mat.spread = 180.0
	mat.initial_velocity_min = spread_speed * 0.4
	mat.initial_velocity_max = spread_speed
	mat.gravity = Vector3(0, 0.6, 0)
	mat.damping_min = 1.8
	mat.damping_max = 4.0
	mat.scale_min = scale_min
	mat.scale_max = scale_max
	mat.color = color_start
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 0.1

	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.25, 0.65, 1.0])
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
	scale_curve.add_point(Vector2(0.0, 0.35))
	scale_curve.add_point(Vector2(0.15, 1.2))
	scale_curve.add_point(Vector2(0.5, 1.0))
	scale_curve.add_point(Vector2(1.0, 0.0))
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
	draw_mat.albedo_texture = SMOKE_TEX
	draw_mat.albedo_color = Color(1, 1, 1, 1)
	draw_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	draw_mat.proximity_fade_enabled = false
	p.draw_pass_1 = draw
	p.material_override = draw_mat
	return p


func _play_impact_sound() -> void:
	# Punch + higher “energy crack” pitch layer
	_spawn_impact_voice(-1.0, randf_range(0.85, 1.05))
	_spawn_impact_voice(-7.0, randf_range(1.25, 1.45))


func _spawn_impact_voice(volume_db: float, pitch: float) -> void:
	var sfx := AudioStreamPlayer3D.new()
	sfx.stream = IMPACT_SFX
	sfx.volume_db = volume_db
	sfx.pitch_scale = pitch
	sfx.max_distance = 48.0
	sfx.unit_size = 2.2
	add_child(sfx)
	sfx.play()
