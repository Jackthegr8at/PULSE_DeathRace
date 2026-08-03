class_name BombletMine
extends Area3D
## Short-lived Bomblet proximity mine with a compact orange area blast.

const ARM_DELAY := 0.4
const TRIGGER_RADIUS := 2.2
const EXPLOSION_RADIUS := 2.4
const EXPLOSION_DURATION := 0.55
const SMOKE_TEX := preload("res://sprites/smoke.png")
const PRIMARY := Color("ff7315")
const HOT := Color("ffd56a")
const CORE := Color("fff4d0")
const FADE := Color("7a2605")
const ACCENT := Color("ff3b0a")

var _owner: Vehicle = null
var _damage: float = 1.0
var _active_lifetime: float = 3.0
var _elapsed: float = 0.0
var _armed: bool = false
var _detonated: bool = false
var _hit_registry: Dictionary = {}
var _body_mesh: MeshInstance3D = null
var _ring_mesh: MeshInstance3D = null
var _outer_ring: MeshInstance3D = null
var _light: OmniLight3D = null
var _arm_sparks: GPUParticles3D = null
var _body_material: StandardMaterial3D = null
var _ring_material: StandardMaterial3D = null


func configure(
	owner: Vehicle,
	damage: float,
	active_lifetime: float,
	hit_registry: Dictionary,
) -> void:
	_owner = owner
	_damage = maxf(damage, 1.0)
	_active_lifetime = maxf(active_lifetime, 0.5)
	_hit_registry = hit_registry


func _ready() -> void:
	collision_layer = 0
	collision_mask = 8
	monitoring = true
	monitorable = false
	body_entered.connect(_on_body_entered)
	_build_collision()
	_build_visual()
	_spawn_drop_puff()


func _physics_process(delta: float) -> void:
	if _detonated:
		return
	if not is_instance_valid(_owner) or _owner.match_over:
		queue_free()
		return
	_elapsed += delta
	if not _armed and _elapsed >= ARM_DELAY:
		_armed = true
		_set_armed_visual()
		for body in get_overlapping_bodies():
			if _is_enemy_body(body):
				_detonate()
				return
	if _elapsed >= ARM_DELAY + _active_lifetime:
		_expire()
		return
	if _armed:
		var pulse := 1.0 + sin(_elapsed * 9.0) * 0.1
		if is_instance_valid(_ring_mesh):
			_ring_mesh.scale = Vector3.ONE * pulse
		if is_instance_valid(_outer_ring):
			_outer_ring.scale = Vector3.ONE * (1.05 + sin(_elapsed * 6.5) * 0.08)
		if is_instance_valid(_light):
			_light.light_energy = 1.5 + 0.55 * sin(_elapsed * 12.0)
		if is_instance_valid(_body_material):
			_body_material.emission_energy_multiplier = 1.1 + 0.6 * sin(_elapsed * 10.0)


func _build_collision() -> void:
	var shape_node := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = TRIGGER_RADIUS
	shape_node.shape = shape
	add_child(shape_node)


func _build_visual() -> void:
	_body_mesh = MeshInstance3D.new()
	var body := SphereMesh.new()
	body.radius = 0.22
	body.height = 0.38
	_body_mesh.mesh = body
	_body_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_body_material = StandardMaterial3D.new()
	_body_material.albedo_color = Color("21170f")
	_body_material.metallic = 0.75
	_body_material.roughness = 0.28
	_body_material.emission_enabled = true
	_body_material.emission = Color("7a2605")
	_body_material.emission_energy_multiplier = 0.8
	_body_mesh.material_override = _body_material
	add_child(_body_mesh)

	_ring_mesh = MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = 0.23
	ring.outer_radius = 0.31
	ring.rings = 10
	ring.ring_segments = 20
	_ring_mesh.mesh = ring
	_ring_mesh.rotation_degrees.x = 90.0
	_ring_mesh.position.y = -0.12
	_ring_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ring_material = StandardMaterial3D.new()
	_ring_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ring_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ring_material.albedo_color = Color(PRIMARY.r, PRIMARY.g, PRIMARY.b, 0.95)
	_ring_material.emission_enabled = true
	_ring_material.emission = ACCENT
	_ring_material.emission_energy_multiplier = 2.2
	_ring_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_ring_mesh.material_override = _ring_material
	add_child(_ring_mesh)

	_outer_ring = MeshInstance3D.new()
	var outer := TorusMesh.new()
	outer.inner_radius = 0.42
	outer.outer_radius = 0.52
	outer.rings = 8
	outer.ring_segments = 22
	_outer_ring.mesh = outer
	_outer_ring.rotation_degrees.x = 90.0
	_outer_ring.position.y = -0.14
	_outer_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var outer_mat := StandardMaterial3D.new()
	outer_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	outer_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	outer_mat.albedo_color = Color(HOT.r, HOT.g, HOT.b, 0.35)
	outer_mat.emission_enabled = true
	outer_mat.emission = HOT
	outer_mat.emission_energy_multiplier = 1.2
	outer_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_outer_ring.material_override = outer_mat
	_outer_ring.visible = false
	add_child(_outer_ring)

	_arm_sparks = _make_burst(
		Color(HOT.r, HOT.g, HOT.b, 0.9),
		Color(PRIMARY.r, PRIMARY.g, PRIMARY.b, 0.0),
		8,
		0.35,
		1.4,
		0.06,
		0.14,
		0.18,
		true
	)
	_arm_sparks.name = "ArmSparks"
	_arm_sparks.one_shot = false
	_arm_sparks.explosiveness = 0.1
	_arm_sparks.emitting = false
	var arm_mat := _arm_sparks.process_material as ParticleProcessMaterial
	if arm_mat:
		arm_mat.direction = Vector3(0, 1, 0)
		arm_mat.spread = 180.0
		arm_mat.gravity = Vector3(0, 0.8, 0)
		arm_mat.emission_sphere_radius = 0.18
		arm_mat.initial_velocity_min = 0.3
		arm_mat.initial_velocity_max = 1.2
	add_child(_arm_sparks)

	_light = OmniLight3D.new()
	_light.light_color = PRIMARY
	_light.light_energy = 0.7
	_light.omni_range = 1.8
	_light.shadow_enabled = false
	add_child(_light)


func _spawn_drop_puff() -> void:
	var puff := _make_burst(
		Color(PRIMARY.r, PRIMARY.g, PRIMARY.b, 0.85),
		Color(FADE.r, FADE.g, FADE.b, 0.0),
		10,
		0.28,
		2.2,
		0.2,
		0.5,
		0.45,
		true
	)
	puff.one_shot = true
	puff.explosiveness = 0.9
	puff.emitting = true
	var mat := puff.process_material as ParticleProcessMaterial
	if mat:
		mat.direction = Vector3(0, 1, 0)
		mat.spread = 90.0
		mat.gravity = Vector3(0, 1.0, 0)
	add_child(puff)


func _set_armed_visual() -> void:
	if is_instance_valid(_light):
		_light.light_energy = 1.8
		_light.omni_range = 2.6
	if is_instance_valid(_outer_ring):
		_outer_ring.visible = true
	if is_instance_valid(_arm_sparks):
		_arm_sparks.emitting = true
	if is_instance_valid(_body_material):
		_body_material.emission = ACCENT
		_body_material.emission_energy_multiplier = 1.6
	if is_instance_valid(_ring_mesh):
		var tween := create_tween()
		tween.tween_property(_ring_mesh, "scale", Vector3.ONE * 1.28, 0.1)
		tween.tween_property(_ring_mesh, "scale", Vector3.ONE, 0.12)


func _on_body_entered(body: Node3D) -> void:
	if _armed and not _detonated and _is_enemy_body(body):
		call_deferred("_detonate")


func _is_enemy_body(body: Node) -> bool:
	var vehicle := _vehicle_from_node(body)
	return (
		is_instance_valid(vehicle)
		and vehicle != _owner
		and vehicle.is_alive
		and not vehicle.match_over
		and not vehicle.has_finished_race
	)


func _vehicle_from_node(node: Node) -> Vehicle:
	var current := node
	while current != null:
		if current is Vehicle:
			return current as Vehicle
		current = current.get_parent()
	return null


func _detonate() -> void:
	if _detonated:
		return
	_detonated = true
	monitoring = false
	collision_mask = 0
	_apply_area_damage()
	_play_explosion()
	await get_tree().create_timer(EXPLOSION_DURATION).timeout
	queue_free()


func _apply_area_damage() -> void:
	var sphere := SphereShape3D.new()
	sphere.radius = EXPLOSION_RADIUS
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = sphere
	query.transform = Transform3D(Basis.IDENTITY, global_position)
	query.collision_mask = 8
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var seen: Dictionary = {}
	for result in get_world_3d().direct_space_state.intersect_shape(query, 16):
		var vehicle := _vehicle_from_node(result.get("collider") as Node)
		if not is_instance_valid(vehicle) or vehicle == _owner or not vehicle.is_alive:
			continue
		var vehicle_key := vehicle.get_instance_id()
		if seen.has(vehicle_key) or _hit_registry.has(vehicle_key):
			continue
		seen[vehicle_key] = true
		_hit_registry[vehicle_key] = true
		vehicle.take_damage(_damage, _owner, &"drone")


func _play_explosion() -> void:
	if is_instance_valid(_body_mesh):
		_body_mesh.visible = false
	if is_instance_valid(_arm_sparks):
		_arm_sparks.emitting = false

	# Expanding rings
	if is_instance_valid(_ring_mesh):
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(_ring_mesh, "scale", Vector3.ONE * 8.0, EXPLOSION_DURATION * 0.55)\
			.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		if _ring_material:
			tween.tween_property(_ring_material, "albedo_color:a", 0.0, EXPLOSION_DURATION * 0.55)
			tween.tween_property(_ring_material, "emission_energy_multiplier", 0.0, EXPLOSION_DURATION * 0.5)
	if is_instance_valid(_outer_ring):
		_outer_ring.visible = true
		var outer_mat := _outer_ring.material_override as StandardMaterial3D
		var ot := create_tween()
		ot.set_parallel(true)
		ot.tween_property(_outer_ring, "scale", Vector3.ONE * 9.5, EXPLOSION_DURATION * 0.6)\
			.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		if outer_mat:
			ot.tween_property(outer_mat, "albedo_color:a", 0.0, EXPLOSION_DURATION * 0.6)

	# Particle layers
	var core := _make_burst(
		Color(CORE.r, CORE.g, CORE.b, 1.0),
		Color(HOT.r, HOT.g, HOT.b, 0.0),
		14,
		EXPLOSION_DURATION * 0.4,
		5.0,
		0.45,
		0.95,
		0.9,
		true
	)
	core.one_shot = true
	core.explosiveness = 0.98
	core.emitting = true
	add_child(core)

	var fire := _make_burst(
		Color(PRIMARY.r, PRIMARY.g, PRIMARY.b, 1.0),
		Color(FADE.r, FADE.g, FADE.b, 0.0),
		20,
		EXPLOSION_DURATION * 0.75,
		4.2,
		0.7,
		1.5,
		1.2,
		true
	)
	fire.one_shot = true
	fire.explosiveness = 0.95
	fire.emitting = true
	add_child(fire)

	var embers := _make_burst(
		Color(HOT.r, HOT.g, HOT.b, 1.0),
		Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.0),
		16,
		EXPLOSION_DURATION * 0.55,
		7.5,
		0.1,
		0.28,
		0.35,
		true
	)
	embers.one_shot = true
	embers.explosiveness = 0.98
	embers.emitting = true
	var ember_mat := embers.process_material as ParticleProcessMaterial
	if ember_mat:
		ember_mat.spread = 140.0
		ember_mat.gravity = Vector3(0, -5.0, 0)
		ember_mat.damping_min = 0.4
		ember_mat.damping_max = 1.5
	add_child(embers)

	var smoke := _make_burst(
		Color(0.35, 0.18, 0.08, 0.55),
		Color(0.12, 0.08, 0.06, 0.0),
		12,
		EXPLOSION_DURATION * 0.95,
		2.4,
		0.8,
		1.6,
		1.4,
		false
	)
	smoke.one_shot = true
	smoke.explosiveness = 0.85
	smoke.emitting = true
	var smoke_mat := smoke.process_material as ParticleProcessMaterial
	if smoke_mat:
		smoke_mat.gravity = Vector3(0, 2.2, 0)
		smoke_mat.damping_min = 1.5
		smoke_mat.damping_max = 3.0
	add_child(smoke)

	if is_instance_valid(_light):
		_light.light_energy = 7.5
		_light.omni_range = 5.5
		_light.light_color = HOT
		var light_tween := create_tween()
		light_tween.tween_property(_light, "light_energy", 0.0, EXPLOSION_DURATION)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _expire() -> void:
	if _detonated:
		return
	_detonated = true
	monitoring = false
	if is_instance_valid(_arm_sparks):
		_arm_sparks.emitting = false
	var tween := create_tween()
	tween.set_parallel(true)
	if is_instance_valid(_body_mesh):
		tween.tween_property(_body_mesh, "scale", Vector3.ZERO, 0.18)
	if is_instance_valid(_ring_mesh):
		tween.tween_property(_ring_mesh, "scale", Vector3.ZERO, 0.18)
	if is_instance_valid(_outer_ring):
		tween.tween_property(_outer_ring, "scale", Vector3.ZERO, 0.18)
	if is_instance_valid(_light):
		tween.tween_property(_light, "light_energy", 0.0, 0.18)
	tween.chain().tween_callback(queue_free)


func _make_burst(
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
	p.amount = amount
	p.lifetime = life
	p.randomness = 0.3
	p.fixed_fps = 30
	p.interpolate = true
	p.visibility_aabb = AABB(Vector3(-8, -4, -8), Vector3(16, 12, 16))
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 1, 0)
	mat.spread = 180.0
	mat.initial_velocity_min = spread_speed * 0.4
	mat.initial_velocity_max = spread_speed
	mat.gravity = Vector3(0, 0.8, 0)
	mat.damping_min = 1.5
	mat.damping_max = 3.5
	mat.scale_min = scale_min
	mat.scale_max = scale_max
	mat.color = color_start
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 0.08

	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.2, 0.65, 1.0])
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
	scale_curve.add_point(Vector2(0.0, 0.4))
	scale_curve.add_point(Vector2(0.15, 1.15))
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
	draw_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	p.draw_pass_1 = draw
	p.material_override = draw_mat
	return p
