class_name BombletMine
extends Area3D
## Short-lived Bomblet proximity mine with a compact orange area blast.

const ARM_DELAY := 0.4
const TRIGGER_RADIUS := 2.2
const EXPLOSION_RADIUS := 2.4
const EXPLOSION_DURATION := 0.42

var _owner: Vehicle = null
var _damage: float = 1.0
var _active_lifetime: float = 3.0
var _elapsed: float = 0.0
var _armed: bool = false
var _detonated: bool = false
var _hit_registry: Dictionary = {}
var _body_mesh: MeshInstance3D = null
var _ring_mesh: MeshInstance3D = null
var _light: OmniLight3D = null


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
	if _armed and is_instance_valid(_ring_mesh):
		var pulse := 1.0 + sin(_elapsed * 8.0) * 0.09
		_ring_mesh.scale = Vector3.ONE * pulse


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
	var body_material := StandardMaterial3D.new()
	body_material.albedo_color = Color("21170f")
	body_material.metallic = 0.75
	body_material.roughness = 0.28
	body_material.emission_enabled = true
	body_material.emission = Color("7a2605")
	body_material.emission_energy_multiplier = 0.8
	_body_mesh.material_override = body_material
	add_child(_body_mesh)

	_ring_mesh = MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = 0.23
	ring.outer_radius = 0.31
	ring.rings = 8
	ring.ring_segments = 18
	_ring_mesh.mesh = ring
	_ring_mesh.rotation_degrees.x = 90.0
	_ring_mesh.position.y = -0.12
	_ring_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var ring_material := StandardMaterial3D.new()
	ring_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_material.albedo_color = Color("ff7315")
	ring_material.emission_enabled = true
	ring_material.emission = Color("ff5a0a")
	ring_material.emission_energy_multiplier = 2.2
	_ring_mesh.material_override = ring_material
	add_child(_ring_mesh)

	_light = OmniLight3D.new()
	_light.light_color = Color("ff6b16")
	_light.light_energy = 0.7
	_light.omni_range = 1.8
	_light.shadow_enabled = false
	add_child(_light)


func _set_armed_visual() -> void:
	if is_instance_valid(_light):
		_light.light_energy = 1.8
	if is_instance_valid(_ring_mesh):
		var tween := create_tween()
		tween.tween_property(_ring_mesh, "scale", Vector3.ONE * 1.22, 0.12)
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
	if is_instance_valid(_ring_mesh):
		var material := _ring_mesh.material_override as StandardMaterial3D
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(_ring_mesh, "scale", Vector3.ONE * 7.0, EXPLOSION_DURATION)\
			.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		if material:
			tween.tween_property(material, "albedo_color:a", 0.0, EXPLOSION_DURATION)
	if is_instance_valid(_light):
		_light.light_energy = 5.0
		var light_tween := create_tween()
		light_tween.tween_property(_light, "light_energy", 0.0, EXPLOSION_DURATION)


func _expire() -> void:
	if _detonated:
		return
	_detonated = true
	monitoring = false
	var tween := create_tween()
	tween.set_parallel(true)
	if is_instance_valid(_body_mesh):
		tween.tween_property(_body_mesh, "scale", Vector3.ZERO, 0.18)
	if is_instance_valid(_ring_mesh):
		tween.tween_property(_ring_mesh, "scale", Vector3.ZERO, 0.18)
	tween.chain().tween_callback(queue_free)
