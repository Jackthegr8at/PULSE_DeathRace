class_name BombletBombdrop
extends Node
## Bomblet attack strategy: dash ahead, deploy a line of mines, and return.

enum State {
	IDLE,
	OUTBOUND,
	RETURN,
}

const MineScene: PackedScene = preload("res://scenes/drones/BombletMine.tscn")
const OUTBOUND_SPEED := 12.0
const RETURN_SPEED := 11.0
const FIRST_DROP_FRACTION := 0.28

var _controller: DroneController = null
var _owner: Vehicle = null
var _state: State = State.IDLE
var _cooldown_duration: float = 12.0
var _cooldown_remaining: float = 1.0
var _damage_ratio: float = 0.30
var _bomb_count: int = 3
var _mine_lifetime: float = 3.0
var _drop_distance: float = 8.0
var _attack_start := Vector3.ZERO
var _attack_end := Vector3.ZERO
var _attack_direction := Vector3.FORWARD
var _next_drop: int = 0
var _hit_registry: Dictionary = {}


func configure(controller: DroneController, owner: Vehicle, tier_data: Dictionary) -> void:
	_controller = controller
	_owner = owner
	_cooldown_duration = float(tier_data.get("cooldown", 12.0))
	_damage_ratio = float(tier_data.get("damage_ratio", 0.30))
	_bomb_count = maxi(int(tier_data.get("bomb_count", 3)), 1)
	_mine_lifetime = maxf(float(tier_data.get("mine_lifetime", 3.0)), 0.5)
	_drop_distance = maxf(float(tier_data.get("bombdrop_distance", 8.0)), 2.0)


func tick(delta: float) -> void:
	if not is_instance_valid(_controller) or not is_instance_valid(_owner):
		return
	match _state:
		State.IDLE:
			_update_idle(delta)
		State.OUTBOUND:
			_update_outbound(delta)
		State.RETURN:
			_update_return(delta)


func _update_idle(delta: float) -> void:
	_controller.ability_follow_owner(delta)
	if not _controller.ability_combat_is_active():
		return
	_cooldown_remaining = maxf(_cooldown_remaining - delta, 0.0)
	if _cooldown_remaining > 0.0:
		return
	var target := _controller.ability_find_target()
	if not is_instance_valid(target):
		return
	_begin_bombdrop(target)


func _begin_bombdrop(target: Vehicle) -> void:
	var owner_position := _owner.get_vehicle_position()
	var toward_target := target.get_vehicle_position() - owner_position
	toward_target.y = 0.0
	_attack_direction = (
		toward_target.normalized()
		if toward_target.length_squared() > 0.001
		else _owner.get_forward()
	)
	_attack_start = _controller.global_position
	_attack_end = (
		owner_position
		+ _attack_direction * _drop_distance
		+ Vector3.UP * 2.15
	)
	_next_drop = 0
	_hit_registry = {}
	_state = State.OUTBOUND


func _update_outbound(delta: float) -> void:
	if not _controller.ability_combat_is_active():
		_state = State.RETURN
		return
	var to_end := _attack_end - _controller.global_position
	var total_distance := maxf(_attack_start.distance_to(_attack_end), 0.001)
	var travelled := _attack_start.distance_to(_controller.global_position)
	var progress := clampf(travelled / total_distance, 0.0, 1.0)
	while _next_drop < _bomb_count and progress >= _drop_fraction(_next_drop):
		_drop_mine()
		_next_drop += 1
	if to_end.length() <= 0.16:
		while _next_drop < _bomb_count:
			_drop_mine()
			_next_drop += 1
		_cooldown_remaining = _cooldown_duration
		_state = State.RETURN
		return
	var direction := to_end.normalized()
	_controller.global_position += direction * minf(OUTBOUND_SPEED * delta, to_end.length())
	_controller.ability_face_direction(_attack_direction, delta)


func _drop_fraction(index: int) -> float:
	if _bomb_count <= 1:
		return 0.55
	return lerpf(FIRST_DROP_FRACTION, 0.90, float(index) / float(_bomb_count - 1))


func _drop_mine() -> void:
	var mine := MineScene.instantiate() as BombletMine
	if mine == null:
		return
	var race_root := _controller.get_parent()
	mine.configure(
		_owner,
		maxf(_owner.missile_damage * _damage_ratio, 1.0),
		_mine_lifetime,
		_hit_registry,
	)
	race_root.add_child(mine)
	mine.global_position = _road_position_below(_controller.global_position)


func _road_position_below(from: Vector3) -> Vector3:
	var query := PhysicsRayQueryParameters3D.create(
		from + Vector3.UP * 1.0,
		from + Vector3.DOWN * 8.0,
		1,
	)
	var owner_body := _owner.get_node_or_null("Sphere") as CollisionObject3D
	if owner_body:
		query.exclude = [owner_body.get_rid()]
	var hit := _controller.get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		var hit_position: Vector3 = hit.get("position", from)
		return hit_position + Vector3.UP * 0.18
	return Vector3(from.x, _owner.get_vehicle_position().y + 0.05, from.z)


func _update_return(delta: float) -> void:
	var destination := _controller.ability_hover_target_position()
	var to_home := destination - _controller.global_position
	if to_home.length() <= 0.18:
		_controller.global_position = destination
		_state = State.IDLE
		return
	var direction := to_home.normalized()
	_controller.global_position += direction * minf(RETURN_SPEED * delta, to_home.length())
	_controller.ability_face_direction(direction, delta)
