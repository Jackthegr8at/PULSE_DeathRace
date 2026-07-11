class_name Track3DBase
extends Node3D
## Shared logic for EVERY hand-painted GridMap track.
## No per-map car/crate files — path, crates, and finish come from this GridMap.

@export var track_display_name: String = "Track"
@export var spawn_row_spacing: float = 1.35
@export var first_pickup_path_fraction: float = 0.12

## Mesh library road items (models/Library/mesh-library.tres)
const ROAD_ITEMS := [3, 4, 5, 6] # corner, finish, ramp, straight

const MissilePickupScene: PackedScene = preload("res://scenes/combat/MissilePickup.tscn")

var race_path: Path3D = null


func _ready() -> void:
	call_deferred("_setup_track_runtime")


func _setup_track_runtime() -> void:
	_ensure_race_path()
	_ensure_finish_line()
	_spawn_missile_pickups()


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
	var base := get_spawn_transform()
	var result: Array[Transform3D] = []
	var basis := base.basis.orthonormalized()
	var forward := basis.z.normalized()
	for i in count:
		var origin := base.origin - forward * (float(i) * spawn_row_spacing)
		origin.y = base.origin.y
		result.append(Transform3D(basis, origin))
	return result


func _is_road_item(item: int) -> bool:
	return item in ROAD_ITEMS


func _ensure_race_path() -> void:
	race_path = get_node_or_null("RacePath") as Path3D
	if race_path and race_path.curve and race_path.curve.get_baked_length() > 5.0:
		return
	if _build_path_from_grid():
		return
	push_warning("%s: could not build race path from GridMap — AI/crates may be wrong. Put SpawnPoint on a road tile and use connected track pieces." % track_display_name)
	_build_path_around_spawn_fallback()


func _build_path_from_grid() -> bool:
	var grid := get_grid_map()
	if grid == null:
		return false

	var road_cells: Array[Vector3i] = []
	var road_set: Dictionary = {}
	for cell in grid.get_used_cells():
		var item := grid.get_cell_item(cell)
		if _is_road_item(item):
			road_cells.append(cell)
			road_set[cell] = true

	if road_cells.size() < 4:
		push_warning("%s: only %d road tiles found (need straights/corners/finish)." % [track_display_name, road_cells.size()])
		return false

	var marker := get_node_or_null("SpawnPoint") as Marker3D
	var start_cell := _pick_start_cell(grid, road_cells, marker)

	# Walk the road graph preferring unvisited neighbors (works for loops & long tracks)
	var points: Array[Vector3] = []
	var visited: Dictionary = {}
	var current := start_cell
	var previous := Vector3i(999999, 0, 999999)
	var directions := [
		Vector3i(1, 0, 0), Vector3i(-1, 0, 0),
		Vector3i(0, 0, 1), Vector3i(0, 0, -1),
	]
	var start_forward := Vector3(0, 0, 1)
	if marker:
		start_forward = marker.global_transform.basis.z
		start_forward.y = 0.0
		if start_forward.length_squared() > 0.001:
			start_forward = start_forward.normalized()

	for step in road_cells.size() + 8:
		visited[current] = true
		var point := grid.to_global(grid.map_to_local(current))
		point.y = marker.global_position.y if marker else 0.3
		points.append(point)

		var candidates: Array[Vector3i] = []
		var unvisited: Array[Vector3i] = []
		for direction in directions:
			var next_cell: Vector3i = current + direction
			if not road_set.has(next_cell):
				continue
			if next_cell == previous:
				continue
			candidates.append(next_cell)
			if not visited.has(next_cell):
				unvisited.append(next_cell)

		var pool: Array[Vector3i] = unvisited if unvisited.size() > 0 else candidates
		if pool.is_empty():
			break

		var next := pool[0]
		if step == 0 and pool.size() > 1:
			# Leave spawn facing the player's forward direction
			var best_dot := -INF
			for candidate in pool:
				var cw := grid.to_global(grid.map_to_local(candidate))
				var cd := (cw - point)
				cd.y = 0.0
				if cd.length_squared() < 0.001:
					continue
				var d := start_forward.dot(cd.normalized())
				if d > best_dot:
					best_dot = d
					next = candidate
		elif pool.size() > 1:
			# Prefer continuing straight-ish
			var travel := point - (points[points.size() - 2] if points.size() > 1 else point)
			travel.y = 0.0
			if travel.length_squared() > 0.001:
				travel = travel.normalized()
				var best_dot := -INF
				for candidate in pool:
					var cw := grid.to_global(grid.map_to_local(candidate))
					var cd := (cw - point)
					cd.y = 0.0
					if cd.length_squared() < 0.001:
						continue
					var d := travel.dot(cd.normalized())
					if d > best_dot:
						best_dot = d
						next = candidate

		previous = current
		current = next
		if current == start_cell and step > 3:
			break

	# If we didn't close the loop, try to append remaining road cells (loose order)
	if points.size() < road_cells.size() * 0.5:
		# incomplete walk — still usable if we got a decent chain
		pass

	if points.size() < 4:
		return false

	if race_path == null:
		race_path = Path3D.new()
		race_path.name = "RacePath"
		add_child(race_path)
	var curve := Curve3D.new()
	curve.bake_interval = 0.4
	for point in points:
		curve.add_point(point)
	# Close path back to start for laps
	if points.size() > 2:
		curve.add_point(points[0])
	race_path.curve = curve
	return true


func _pick_start_cell(grid: GridMap, road_cells: Array[Vector3i], marker: Marker3D) -> Vector3i:
	# Prefer finish tile (item 4)
	for cell in road_cells:
		if grid.get_cell_item(cell) == 4:
			return cell
	# Else nearest road cell to SpawnPoint
	var start_cell := road_cells[0]
	var best_distance := INF
	var anchor := marker.global_position if marker else global_position
	for cell in road_cells:
		var cell_world := grid.to_global(grid.map_to_local(cell))
		var distance := cell_world.distance_squared_to(anchor)
		if distance < best_distance:
			best_distance = distance
			start_cell = cell
	return start_cell


func _build_path_around_spawn_fallback() -> void:
	## Last resort: small oval around SpawnPoint so crates aren't at world origin.
	if race_path == null:
		race_path = Path3D.new()
		race_path.name = "RacePath"
		add_child(race_path)
	var o := get_spawn_transform().origin
	var curve := Curve3D.new()
	var r := 12.0
	for i in 12:
		var a := TAU * float(i) / 12.0
		curve.add_point(o + Vector3(cos(a) * r, 0.25, sin(a) * r))
	curve.add_point(o + Vector3(r, 0.25, 0))
	race_path.curve = curve


func _ensure_finish_line() -> void:
	if get_node_or_null("FinishLine") != null:
		return
	var area := Area3D.new()
	area.name = "FinishLine"
	area.collision_layer = 0
	area.collision_mask = 8
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

	var n := maxi(MatchConfig.crate_count, 0)
	if n == 0:
		return

	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var min_frac := first_pickup_path_fraction
	var min_spacing := maxf(length * 0.05, 3.5)
	var chosen_offsets: Array[float] = []
	var attempts := 0
	while chosen_offsets.size() < n and attempts < n * 50:
		attempts += 1
		var off := rng.randf_range(length * min_frac, length * 0.97)
		var ok := true
		for existing in chosen_offsets:
			var dist := absf(off - existing)
			dist = mini(dist, length - dist)
			if dist < min_spacing:
				ok = false
				break
		if ok:
			chosen_offsets.append(off)

	while chosen_offsets.size() < n:
		var t := min_frac + (1.0 - min_frac) * (float(chosen_offsets.size()) + 0.5) / float(n)
		chosen_offsets.append(length * t)

	for i in chosen_offsets.size():
		var offset: float = chosen_offsets[i]
		var local_pos := path.curve.sample_baked(offset)
		var world_pos := path.to_global(local_pos)
		var ahead := path.to_global(path.curve.sample_baked(fmod(offset + 1.0, length)))
		var tangent := ahead - world_pos
		tangent.y = 0.0
		if tangent.length_squared() > 0.001:
			tangent = tangent.normalized()
		else:
			tangent = Vector3(0, 0, 1)
		var side := Vector3.UP.cross(tangent).normalized()
		# Keep crates near centerline (on asphalt) — small lateral only
		var lateral := side * rng.randf_range(-0.45, 0.45)

		var pickup: Area3D = MissilePickupScene.instantiate()
		root.add_child(pickup)
		pickup.global_position = world_pos + lateral + Vector3(0, 0.85, 0)
		if pickup is MissilePickup:
			(pickup as MissilePickup).ammo_amount = MatchConfig.missiles_per_crate
