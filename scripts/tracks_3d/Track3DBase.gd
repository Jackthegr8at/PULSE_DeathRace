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
	## Pack player + AI on the SpawnPoint asphalt (Kenney start). Do NOT use the
	## approximate Path3D for placement — it drifts off the GridMap road.
	var base := get_spawn_transform()
	var result: Array[Transform3D] = []
	# Identity basis at Kenney start faces +Z down the road; keep that facing.
	var basis := base.basis.orthonormalized()
	var right := basis.x
	var forward := basis.z
	# Road is narrow: 2 columns, rows stacked slightly BEHIND start so all stay on tile
	for i in count:
		var col := i % 2
		var row := int(i / 2.0)
		var lateral := (float(col) - 0.5) * 1.6 # ~±0.8 m from centerline
		var along := -float(row) * 2.2 # behind spawn, still on straight
		var origin := base.origin + right * lateral + forward * along
		origin.y = base.origin.y
		result.append(Transform3D(basis, origin))
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
	# Loop around Kenney starter circuit (spawn ~ 3.5, 0, 5 — stay on the paved loop)
	var pts := [
		Vector3(3.5, 0.25, 5.0),
		Vector3(6.0, 0.25, 3.0),
		Vector3(8.5, 0.25, -1.0),
		Vector3(8.0, 0.25, -6.0),
		Vector3(4.0, 0.25, -10.0),
		Vector3(-1.0, 0.25, -11.0),
		Vector3(-6.0, 0.25, -8.0),
		Vector3(-9.0, 0.25, -3.0),
		Vector3(-8.0, 0.25, 2.0),
		Vector3(-4.0, 0.25, 6.0),
		Vector3(0.5, 0.25, 7.0),
		Vector3(3.5, 0.25, 5.0),
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
