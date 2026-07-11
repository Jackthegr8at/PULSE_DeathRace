class_name Track3DBase
extends Node3D
## Base for Kenney GridMap tracks: spawn, race path, finish line.

@export var track_display_name: String = "Track"
@export var spawn_row_spacing: float = 1.35

var race_path: Path3D = null


const MissilePickupScene: PackedScene = preload("res://scenes/combat/MissilePickup.tscn")

@export var missile_pickup_count: int = 6
@export var first_pickup_path_fraction: float = 0.18 ## Skip start stretch so no free spam at grid

func _ready() -> void:
	_ensure_race_path()
	_ensure_finish_line()
	# Wait a frame so GridMap / path are fully ready in world space
	call_deferred("_spawn_missile_pickups")


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
	## Single-file on the start centerline. Kenney straights are narrow — a 2-wide
	## grid pushed rear cars onto grass. Keep everyone on SpawnPoint asphalt.
	var base := get_spawn_transform()
	var result: Array[Transform3D] = []
	var basis := base.basis.orthonormalized()
	var forward := basis.z.normalized()
	# One column, slight stagger behind the marker (stay on the same tile ~7–8m long)
	for i in count:
		var origin := base.origin - forward * (float(i) * spawn_row_spacing)
		origin.y = base.origin.y
		result.append(Transform3D(basis, origin))
	return result


func _ensure_race_path() -> void:
	race_path = get_node_or_null("RacePath") as Path3D
	if race_path and race_path.curve and race_path.curve.get_point_count() > 2:
		return
	if track_display_name == "Starter Circuit" and _build_path_from_grid():
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


func _build_path_from_grid() -> bool:
	var grid := get_grid_map()
	if grid == null:
		return false

	var road_cells: Array[Vector3i] = []
	var road_set: Dictionary = {}
	for cell in grid.get_used_cells():
		var item := grid.get_cell_item(cell)
		if item == 3 or item == 4 or item == 6:
			road_cells.append(cell)
			road_set[cell] = true
	if road_cells.size() < 8:
		return false

	var marker := get_node_or_null("SpawnPoint") as Marker3D
	var start_cell := road_cells[0]
	var best_distance := INF
	for cell in road_cells:
		var cell_world := grid.to_global(grid.map_to_local(cell))
		var distance := cell_world.distance_squared_to(marker.global_position if marker else global_position)
		if distance < best_distance:
			best_distance = distance
			start_cell = cell

	var points: Array[Vector3] = []
	var current := start_cell
	var previous := Vector3i(999999, 999999, 999999)
	var start_forward := marker.global_transform.basis.z.normalized() if marker else Vector3(0, 0, 1)
	var directions := [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]

	for step in road_cells.size() + 4:
		var point := grid.to_global(grid.map_to_local(current))
		point.y = marker.global_position.y if marker else point.y + 0.25
		points.append(point)

		var candidates: Array[Vector3i] = []
		for direction in directions:
			var next_cell: Vector3i = current + direction
			if road_set.has(next_cell) and next_cell != previous:
				candidates.append(next_cell)
		if candidates.is_empty():
			break

		var next := candidates[0]
		if step == 0 and candidates.size() > 1:
			var best_dot := -INF
			for candidate in candidates:
				var candidate_world := grid.to_global(grid.map_to_local(candidate))
				var candidate_dir := (candidate_world - point).normalized()
				var candidate_dot := start_forward.dot(candidate_dir)
				if candidate_dot > best_dot:
					best_dot = candidate_dot
					next = candidate

		previous = current
		current = next
		if current == start_cell and step > 4:
			break

	if points.size() < 8:
		return false

	if race_path == null:
		race_path = Path3D.new()
		race_path.name = "RacePath"
		add_child(race_path)
	var curve := Curve3D.new()
	curve.bake_interval = 0.5
	curve.closed = true
	for point in points:
		curve.add_point(point)
	race_path.curve = curve

	if marker and points.size() > 1:
		var tangent := (points[1] - points[0]).normalized()
		marker.rotation.y = atan2(tangent.x, tangent.z)
	return true


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


func _spawn_missile_pickups() -> void:
	if get_node_or_null("Pickups") != null:
		return
	var path := get_race_path()
	if path == null or path.curve == null:
		return
	var length := path.curve.get_baked_length()
	if length < 5.0:
		return

	var root := Node3D.new()
	root.name = "Pickups"
	add_child(root)

	var n := maxi(missile_pickup_count, 1)
	# Spread pickups around the lap, starting after first_pickup_path_fraction
	var usable := 1.0 - first_pickup_path_fraction
	for i in n:
		var t := first_pickup_path_fraction + usable * (float(i) + 0.5) / float(n)
		var offset := length * t
		var local_pos := path.curve.sample_baked(offset)
		var world_pos := path.to_global(local_pos)
		# Slight lateral offset alternating so crates sit on the road edge of centerline
		var ahead := path.to_global(path.curve.sample_baked(fmod(offset + 1.0, length)))
		var tangent := ahead - world_pos
		tangent.y = 0.0
		if tangent.length_squared() > 0.001:
			tangent = tangent.normalized()
		else:
			tangent = Vector3(0, 0, 1)
		var side := Vector3.UP.cross(tangent).normalized()
		var lateral := side * (0.7 if i % 2 == 0 else -0.7)

		var pickup: Area3D = MissilePickupScene.instantiate()
		root.add_child(pickup)
		pickup.global_position = world_pos + lateral + Vector3(0, 0.85, 0)
