class_name DroneController
extends Node3D
## Autonomous world-space drone that follows an owning vehicle and attacks rivals.

enum State {
	FOLLOW,
	LUNGE,
	RETURN,
}

const TARGET_RANGE := 12.0
const HOVER_HEIGHT := 2.15
const HOVER_REAR_OFFSET := 0.65
const FOLLOW_SMOOTHNESS := 8.0
const LUNGE_SPEED := 15.0
const RETURN_SPEED := 10.0
const HIT_DISTANCE := 1.15
const TARGET_HEIGHT := 0.65
const MODEL_TARGET_SIZE := 1.35

var owner_vehicle: Vehicle = null
var drone_id: String = DroneCatalog.SCRAPJAW_ID
var tier: int = 1
var cooldown_duration: float = 12.0
var damage_ratio: float = 0.60

var _state: State = State.FOLLOW
var _cooldown_remaining: float = 0.8
var _target: Vehicle = null
var _visual: Node3D = null
var _model: Node3D = null
var _bob_time: float = 0.0
var _last_owner_position := Vector3.ZERO


func configure(vehicle: Vehicle, configured_drone_id: String, configured_tier: int) -> bool:
	owner_vehicle = vehicle
	drone_id = configured_drone_id
	tier = clampi(configured_tier, DroneCatalog.MIN_TIER, DroneCatalog.MAX_TIER)
	var tier_data := DroneCatalog.get_tier(drone_id, tier)
	if owner_vehicle == null or tier_data.is_empty():
		return false
	cooldown_duration = float(tier_data.get("cooldown", 12.0))
	damage_ratio = float(tier_data.get("damage_ratio", 0.60))
	_build_visual(str(tier_data.get("scene_path", "")))
	_last_owner_position = owner_vehicle.get_vehicle_position()
	global_position = _hover_target_position()
	add_to_group("combat_drones")
	return _model != null


func _process(delta: float) -> void:
	if not is_instance_valid(owner_vehicle) or not owner_vehicle.is_alive:
		queue_free()
		return
	_bob_time += delta
	match _state:
		State.FOLLOW:
			_update_follow(delta)
		State.LUNGE:
			_update_lunge(delta)
		State.RETURN:
			_update_return(delta)
	_update_visual_attitude(delta)
	_last_owner_position = owner_vehicle.get_vehicle_position()


func _update_follow(delta: float) -> void:
	var destination := _hover_target_position()
	global_position = global_position.lerp(
		destination,
		1.0 - exp(-FOLLOW_SMOOTHNESS * delta)
	)
	_face_direction(owner_vehicle.get_forward(), delta)
	if not _combat_is_active():
		return
	_cooldown_remaining = maxf(_cooldown_remaining - delta, 0.0)
	if _cooldown_remaining > 0.0:
		return
	_target = _find_target()
	if is_instance_valid(_target):
		_state = State.LUNGE


func _update_lunge(delta: float) -> void:
	if not _target_is_valid(_target) or not _combat_is_active():
		_cancel_attack()
		return
	var target_position := _target.get_vehicle_position() + Vector3.UP * TARGET_HEIGHT
	var to_target := target_position - global_position
	if to_target.length() <= HIT_DISTANCE:
		var damage := maxf(owner_vehicle.missile_damage * damage_ratio, 1.0)
		_target.take_damage(damage, owner_vehicle, &"drone")
		_cooldown_remaining = cooldown_duration
		_target = null
		_state = State.RETURN
		return
	var direction := to_target.normalized()
	global_position += direction * minf(LUNGE_SPEED * delta, to_target.length())
	_face_direction(direction, delta)


func _update_return(delta: float) -> void:
	var destination := _hover_target_position()
	var to_home := destination - global_position
	if to_home.length() <= 0.18:
		global_position = destination
		_state = State.FOLLOW
		return
	var direction := to_home.normalized()
	global_position += direction * minf(RETURN_SPEED * delta, to_home.length())
	_face_direction(direction, delta)


func _cancel_attack() -> void:
	_target = null
	# A cancelled approach did not hit, so it does not consume the full cooldown.
	_cooldown_remaining = 0.0
	_state = State.RETURN


func _combat_is_active() -> bool:
	return (
		owner_vehicle.race_started
		and not owner_vehicle.match_over
		and not owner_vehicle.has_finished_race
		and owner_vehicle.is_alive
	)


func _find_target() -> Vehicle:
	var nearest: Vehicle = null
	var nearest_distance := TARGET_RANGE
	for candidate_node in get_tree().get_nodes_in_group("vehicles"):
		var candidate := candidate_node as Vehicle
		if not _target_is_valid(candidate):
			continue
		var distance := global_position.distance_to(candidate.get_vehicle_position())
		if distance >= nearest_distance or not _has_visibility(candidate):
			continue
		nearest = candidate
		nearest_distance = distance
	return nearest


func _target_is_valid(candidate: Vehicle) -> bool:
	return (
		is_instance_valid(candidate)
		and candidate != owner_vehicle
		and candidate.is_alive
		and not candidate.match_over
		and not candidate.has_finished_race
		and not candidate.is_cloaked
		and owner_vehicle.get_vehicle_position().distance_to(candidate.get_vehicle_position()) <= TARGET_RANGE
	)


func _has_visibility(candidate: Vehicle) -> bool:
	var from := global_position
	var to := candidate.get_vehicle_position() + Vector3.UP * TARGET_HEIGHT
	var query := PhysicsRayQueryParameters3D.create(from, to, 1 | 8)
	var owner_body := owner_vehicle.get_node_or_null("Sphere") as CollisionObject3D
	if owner_body:
		query.exclude = [owner_body.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return true
	var collider := hit.get("collider") as Node
	if collider == candidate:
		return true
	return collider != null and candidate.is_ancestor_of(collider)


func _hover_target_position() -> Vector3:
	var bob := sin(_bob_time * 2.25 + float(tier) * 0.4) * 0.09
	return (
		owner_vehicle.get_vehicle_position()
		+ Vector3.UP * (HOVER_HEIGHT + bob)
		- owner_vehicle.get_forward() * HOVER_REAR_OFFSET
	)


func _face_direction(direction: Vector3, delta: float) -> void:
	var flat := Vector3(direction.x, 0.0, direction.z)
	if flat.length_squared() < 0.0001:
		return
	var desired := Basis.looking_at(flat.normalized(), Vector3.UP)
	global_basis = global_basis.slerp(desired, 1.0 - exp(-10.0 * delta)).orthonormalized()


func _update_visual_attitude(delta: float) -> void:
	if _visual == null:
		return
	var owner_delta := owner_vehicle.get_vehicle_position() - _last_owner_position
	var lateral := owner_delta.dot(owner_vehicle.global_basis.x)
	var target_roll := clampf(-lateral * 0.12, -0.16, 0.16)
	_visual.rotation.z = lerpf(_visual.rotation.z, target_roll, 1.0 - exp(-6.0 * delta))


func _build_visual(scene_path: String) -> void:
	if scene_path.is_empty():
		return
	var packed := load(scene_path) as PackedScene
	if packed == null:
		push_error("DroneController: failed to load %s" % scene_path)
		return
	_visual = Node3D.new()
	_visual.name = "Visual"
	add_child(_visual)
	_model = packed.instantiate() as Node3D
	if _model == null:
		return
	_model.name = "Model"
	_visual.add_child(_model)
	_model.rotation.y = deg_to_rad(DroneCatalog.get_model_yaw_degrees(drone_id))
	_normalize_model()


func _normalize_model() -> void:
	if _model == null:
		return
	var bounds := AABB()
	var has_bounds := false
	for descendant in _model.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := descendant as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null:
			continue
		var relative := _model.global_transform.affine_inverse() * mesh_instance.global_transform
		var transformed := relative * mesh_instance.get_aabb()
		bounds = transformed if not has_bounds else bounds.merge(transformed)
		has_bounds = true
	if not has_bounds:
		return
	var largest := maxf(bounds.size.x, maxf(bounds.size.y, bounds.size.z))
	if largest <= 0.001:
		return
	var uniform_scale := MODEL_TARGET_SIZE / largest
	_model.scale = Vector3.ONE * uniform_scale
	var center := bounds.get_center() * uniform_scale
	_model.position = -center
