class_name Track3DBase
extends Node3D
## Base for Kenney GridMap tracks: spawn, race path, finish line.

@export var track_display_name: String = "Track"

var race_path: Path3D = null


func _ready() -> void:
	_ensure_race_path()
	_ensure_finish_line()


func get_spawn_transform() -> Transform3D:
	var marker := get_node_or_null("SpawnPoint") as Marker3D
	if marker:
		return marker.global_transform
	return global_transform


func get_race_path() -> Path3D:
	if race_path == null:
		race_path = get_node_or_null("RacePath") as Path3D
	return race_path


func get_grid_map() -> GridMap:
	return get_node_or_null("GridMap") as GridMap


func get_spawn_transforms(count: int) -> Array[Transform3D]:
	## Staggered spawns near SpawnPoint for player + AI.
	var base := get_spawn_transform()
	var result: Array[Transform3D] = []
	var right := base.basis.x
	var back := base.basis.z
	for i in count:
		var offset := right * ((i % 2) * 2.2 - 1.1) + back * (i * 2.4)
		var t := Transform3D(base.basis, base.origin + offset)
		result.append(t)
	return result


func _ensure_race_path() -> void:
	race_path = get_node_or_null("RacePath") as Path3D
	if race_path and race_path.curve and race_path.curve.get_point_count() > 2:
		return
	if race_path == null:
		race_path = Path3D.new()
		race_path.name = "RacePath"
		add_child(race_path)
	var curve := Curve3D.new()
	# Approximate loop around Kenney starter circuit (world units, near spawn 3.5, 0, 5)
	var pts := [
		Vector3(3.5, 0.2, 5.0),
		Vector3(8.0, 0.2, 2.0),
		Vector3(12.0, 0.2, -5.0),
		Vector3(8.0, 0.2, -12.0),
		Vector3(0.0, 0.2, -16.0),
		Vector3(-10.0, 0.2, -12.0),
		Vector3(-16.0, 0.2, -4.0),
		Vector3(-14.0, 0.2, 6.0),
		Vector3(-6.0, 0.2, 12.0),
		Vector3(2.0, 0.2, 10.0),
		Vector3(3.5, 0.2, 5.0),
	]
	for p in pts:
		curve.add_point(p)
	race_path.curve = curve


func _ensure_finish_line() -> void:
	if get_node_or_null("FinishLine") != null:
		return
	var area := Area3D.new()
	area.name = "FinishLine"
	area.collision_layer = 0
	area.collision_mask = 8 # vehicle spheres
	area.monitoring = true
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(8, 4, 3.5)
	shape.shape = box
	area.add_child(shape)
	add_child(area)
	var marker := get_node_or_null("SpawnPoint") as Marker3D
	if marker:
		area.global_position = marker.global_position + Vector3(0, 1.2, 0)
	else:
		area.position = Vector3(0, 1.2, 0)
	area.body_entered.connect(_on_finish_body_entered)


func _on_finish_body_entered(body: Node) -> void:
	var veh: Vehicle = null
	if body is RigidBody3D and body.get_parent() is Vehicle:
		veh = body.get_parent() as Vehicle
	elif body is Vehicle:
		veh = body as Vehicle
	if veh and veh.is_alive:
		veh.on_finish_line()
