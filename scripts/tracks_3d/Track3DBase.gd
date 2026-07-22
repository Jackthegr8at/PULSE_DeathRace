class_name Track3DBase
extends Node3D
## Shared logic for EVERY hand-painted GridMap track.
## No per-map car/crate files — path, crates, and finish come from this GridMap.

@export var track_display_name: String = "Track"
@export var spawn_row_spacing: float = 2.2
@export var spawn_column_spacing: float = 1.1
@export var first_pickup_path_fraction: float = 0.12
@export var build_runtime_wall_colliders: bool = true

const MissilePickupScene: PackedScene = preload("res://scenes/combat/MissilePickup.tscn")
const MESH_LIBRARY_SOURCE_SCENE_PATH := "res://models/Library/mesh-library.tscn"

static var _wall_collision_sources: Dictionary = {}

var race_path: Path3D = null


func _ready() -> void:
	call_deferred("_setup_track_runtime")


func _setup_track_runtime() -> void:
	_ensure_runtime_wall_colliders()
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
	var result: Array[Transform3D] = []
	if count <= 0:
		return result
	var base := get_spawn_transform()
	var basis := base.basis.orthonormalized()
	var forward := basis.z.normalized()
	var lateral := basis.x.normalized()
	var half_column := spawn_column_spacing * 0.5
	var front_left := base.origin - lateral * half_column
	var front_right := base.origin + lateral * half_column
	var rear_left := front_left - forward * spawn_row_spacing
	var rear_right := front_right - forward * spawn_row_spacing
	var first_origins: Array[Vector3] = [
		rear_left,
		front_left,
		front_right,
		rear_right,
	]
	for i in mini(count, first_origins.size()):
		var origin := first_origins[i]
		origin.y = base.origin.y
		result.append(Transform3D(basis, origin))
	var row_index := 2
	var column_signs: Array[float] = [-1.0, 1.0]
	while result.size() < count:
		for column_sign in column_signs:
			if result.size() >= count:
				break
			var origin := (
				base.origin
				+ lateral * half_column * column_sign
				- forward * (float(row_index) * spawn_row_spacing)
			)
			origin.y = base.origin.y
			result.append(Transform3D(basis, origin))
		row_index += 1
	return result


func _is_road_item(item: int) -> bool:
	# Do not rely on numeric MeshLibrary IDs: adding/reordering decoration
	# entries changes those IDs. Road pieces are identified by their item name.
	var grid := get_grid_map()
	if grid == null or grid.mesh_library == null or item < 0:
		return false
	var item_name := grid.mesh_library.get_item_name(item).to_lower()
	return item_name.begins_with("track-") or item_name.begins_with("road-")


func _ensure_runtime_wall_colliders() -> void:
	## MeshLibrary exports can lose item shapes while the visual meshes remain
	## valid. Reuse the authored collision shapes from the source MeshLibrary
	## scene and place them with the same cell transform as the GridMap.
	if not build_runtime_wall_colliders:
		return
	if get_node_or_null("RuntimeTrackWalls") != null:
		return

	var grid: GridMap = get_grid_map()
	if grid == null or grid.mesh_library == null:
		return

	var road_cells: Array[Vector3i] = []
	for raw_cell in grid.get_used_cells():
		var cell: Vector3i = raw_cell
		var item: int = grid.get_cell_item(cell)
		if _is_road_item(item):
			road_cells.append(cell)

	if road_cells.is_empty():
		return
	var needs_runtime_shapes := false
	for cell in road_cells:
		var item := grid.get_cell_item(cell)
		if grid.mesh_library.get_item_shapes(item).is_empty():
			needs_runtime_shapes = true
			break
	if not needs_runtime_shapes:
		# The generated binary MeshLibrary embeds these collisions directly,
		# allowing GridMap to create its optimized physics bodies itself.
		return

	var wall_root := StaticBody3D.new()
	wall_root.name = "RuntimeTrackWalls"
	wall_root.collision_layer = 1
	wall_root.collision_mask = 0
	add_child(wall_root)

	var collision_sources := _get_wall_collision_sources()
	if collision_sources.is_empty():
		wall_root.queue_free()
		return

	for cell in road_cells:
		var item: int = grid.get_cell_item(cell)
		var item_name: String = grid.mesh_library.get_item_name(item).to_lower()
		var source_name: String = _collision_source_item_name(item_name)
		if source_name.is_empty():
			continue

		var source: Array = collision_sources.get(source_name, [])
		if source.size() != 2:
			continue
		var collision_shape: Shape3D = source[0] as Shape3D
		var local_shape_transform: Transform3D = source[1]
		if collision_shape == null:
			continue

		var orientation: int = grid.get_cell_item_orientation(cell)
		var item_basis: Basis = grid.get_basis_with_orthogonal_index(orientation)
		var cell_transform: Transform3D = grid.global_transform * Transform3D(item_basis, grid.map_to_local(cell))

		var target_shape := CollisionShape3D.new()
		target_shape.shape = collision_shape
		wall_root.add_child(target_shape)
		target_shape.global_transform = cell_transform * local_shape_transform

	if wall_root.get_child_count() == 0:
		wall_root.queue_free()


func _collision_source_item_name(item_name: String) -> String:
	match item_name:
		"road-corner":
			return "track-corner"
		"track-finish":
			# The finish tile shares the straight segment's side barriers.
			# Its own special collision is reserved for the lap trigger.
			return "track-straight"
		"track-straight":
			return "track-straight"
		_:
			return ""


func _get_wall_collision_sources() -> Dictionary:
	if not _wall_collision_sources.is_empty():
		return _wall_collision_sources
	var started_msec := Time.get_ticks_msec()
	var source_text := FileAccess.get_file_as_string(MESH_LIBRARY_SOURCE_SCENE_PATH)
	if source_text.is_empty():
		push_warning("Could not read wall collision source: %s" % MESH_LIBRARY_SOURCE_SCENE_PATH)
		return {}
	var corner_shape := _read_node_concave_shape(
		source_text,
		"[node name=\"collision-shape\" type=\"CollisionShape3D\" parent=\"track-corner/collision\""
	)
	var straight_shape := _read_node_concave_shape(
		source_text,
		"[node name=\"collision-shape\" type=\"CollisionShape3D\" parent=\"track-straight/collision\""
	)
	if corner_shape == null or straight_shape == null:
		push_warning("Could not extract track wall collision shapes")
		return {}
	_wall_collision_sources = {
		"track-corner": [
			corner_shape,
			_read_node_transform(source_text, "[node name=\"track-corner\"")
			* _read_node_transform(source_text, "[node name=\"collision\" type=\"StaticBody3D\" parent=\"track-corner\"")
			* _read_node_transform(source_text, "[node name=\"collision-shape\" type=\"CollisionShape3D\" parent=\"track-corner/collision\"")
		],
		"track-straight": [
			straight_shape,
			_read_node_transform(source_text, "[node name=\"track-straight\"")
			* _read_node_transform(source_text, "[node name=\"collision\" type=\"StaticBody3D\" parent=\"track-straight\"")
			* _read_node_transform(source_text, "[node name=\"collision-shape\" type=\"CollisionShape3D\" parent=\"track-straight/collision\"")
		],
	}
	print("[RaceLoad] wall collision source parse: %.3f s" % [float(Time.get_ticks_msec() - started_msec) / 1000.0])
	return _wall_collision_sources


func _read_node_concave_shape(source_text: String, node_prefix: String) -> ConcavePolygonShape3D:
	var node_block := _read_node_block(source_text, node_prefix)
	var reference_start := node_block.find("shape = SubResource(\"")
	if reference_start < 0:
		return null
	reference_start += "shape = SubResource(\"".length()
	var reference_end := node_block.find("\"", reference_start)
	if reference_end < 0:
		return null
	var resource_id := node_block.substr(reference_start, reference_end - reference_start)
	var block_start := source_text.find("[sub_resource type=\"ConcavePolygonShape3D\" id=\"%s\"]" % resource_id)
	if block_start < 0:
		return null
	var values_start := source_text.find("data = PackedVector3Array(", block_start)
	if values_start < 0:
		return null
	values_start += "data = PackedVector3Array(".length()
	var values_end := source_text.find(")", values_start)
	if values_end < 0:
		return null
	var numbers := source_text.substr(values_start, values_end - values_start).split(",", false)
	if numbers.size() < 3 or numbers.size() % 3 != 0:
		return null
	var faces := PackedVector3Array()
	for index in range(0, numbers.size(), 3):
		faces.append(Vector3(float(numbers[index]), float(numbers[index + 1]), float(numbers[index + 2])))
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	return shape


func _read_node_transform(source_text: String, node_prefix: String) -> Transform3D:
	var block := _read_node_block(source_text, node_prefix)
	var values_start := block.find("transform = Transform3D(")
	if values_start < 0:
		return Transform3D.IDENTITY
	values_start += "transform = Transform3D(".length()
	var values_end := block.find(")", values_start)
	if values_end < 0:
		return Transform3D.IDENTITY
	var numbers := block.substr(values_start, values_end - values_start).split(",", false)
	if numbers.size() != 12:
		return Transform3D.IDENTITY
	var values: Array[float] = []
	for number in numbers:
		values.append(float(number))
	var parsed_basis := Basis(
		Vector3(values[0], values[1], values[2]),
		Vector3(values[3], values[4], values[5]),
		Vector3(values[6], values[7], values[8])
	)
	return Transform3D(parsed_basis, Vector3(values[9], values[10], values[11]))


func _read_node_block(source_text: String, node_prefix: String) -> String:
	var node_start := source_text.find(node_prefix)
	if node_start < 0:
		return ""
	var node_end := source_text.find("\n[node ", node_start + node_prefix.length())
	if node_end < 0:
		node_end = source_text.length()
	return source_text.substr(node_start, node_end - node_start)


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
	curve.bake_interval = 0.25
	# Densify + soft-round corners so AI centerline doesn't chord into walls
	var dense := _densify_centerline(points)
	for point in dense:
		curve.add_point(race_path.to_local(point) if race_path.is_inside_tree() else point)
	# Close path back to start for laps
	if dense.size() > 2:
		var first: Vector3 = dense[0]
		curve.add_point(race_path.to_local(first) if race_path.is_inside_tree() else first)
	race_path.curve = curve
	return true


func _densify_centerline(world_points: Array[Vector3]) -> Array[Vector3]:
	## Insert midpoints between cell centers so corners are gradual, not one sharp knee.
	if world_points.size() < 2:
		return world_points
	var out: Array[Vector3] = []
	for i in world_points.size():
		var a: Vector3 = world_points[i]
		out.append(a)
		var b: Vector3 = world_points[(i + 1) % world_points.size()]
		# Skip wrap midpoint until we close the loop in the caller if open chain
		if i == world_points.size() - 1:
			break
		var mid := a.lerp(b, 0.5)
		# On sharp turns, pull midpoint slightly toward the outside of the bend
		# so the racing line is less "cut the apex into the wall".
		if i > 0:
			var prev: Vector3 = world_points[i - 1]
			var d0 := (a - prev)
			var d1 := (b - a)
			d0.y = 0.0
			d1.y = 0.0
			if d0.length_squared() > 0.001 and d1.length_squared() > 0.001:
				d0 = d0.normalized()
				d1 = d1.normalized()
				var turn := d0.cross(d1).y
				if absf(turn) > 0.35:
					# turn > 0 = left turn; outside of corner is to the right of travel
					var left := Vector3(-d0.z, 0.0, d0.x).normalized()
					var outside: Vector3 = -left if turn > 0.0 else left
					# Nudge midpoint slightly outward so AI doesn't hug the inside wall
					mid += outside * 0.55
		mid.y = a.y
		out.append(mid)
	return out


func _pick_start_cell(grid: GridMap, road_cells: Array[Vector3i], marker: Marker3D) -> Vector3i:
	# Prefer the finish tile by name; its numeric MeshLibrary ID can change.
	for cell in road_cells:
		var item_name := grid.mesh_library.get_item_name(grid.get_cell_item(cell)).to_lower()
		if item_name == "track-finish" or item_name == "finish":
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
