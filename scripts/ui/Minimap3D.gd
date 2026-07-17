class_name Minimap3D
extends Control
## Top-down comic minimap for 3D races: RacePath outline + live vehicle dots.
## World (x, z) is mapped into this control's rect. Player dot is highlighted.

const ROAD_SHADOW := Color("25170f")
const ROAD_EDGE := Color("6f4528")
const ROAD_DIRT := Color("bd8249")
const ROAD_DUST := Color("d5a366")

@export var map_region: Rect2 = Rect2(0.115, 0.235, 0.77, 0.625)

var player: Vehicle = null

var _path_points: PackedVector2Array = PackedVector2Array()
var _display_points: PackedVector2Array = PackedVector2Array()
var _bounds: Rect2 = Rect2()
var _display_cache_size: Vector2 = Vector2.ZERO


func setup(path: Path3D, p_player: Vehicle) -> void:
	player = p_player
	_rebuild_path_cache(path)
	_display_points = PackedVector2Array()
	_display_cache_size = Vector2.ZERO
	queue_redraw()


func _rebuild_path_cache(path: Path3D) -> void:
	_path_points = PackedVector2Array()
	if path == null or path.curve == null:
		return
	for p in path.curve.get_baked_points():
		var world := path.to_global(p)
		_path_points.append(Vector2(world.x, world.z))
	if _path_points.is_empty():
		return
	var min_v := _path_points[0]
	var max_v := _path_points[0]
	for p in _path_points:
		min_v = min_v.min(p)
		max_v = max_v.max(p)
	_bounds = Rect2(min_v, max_v - min_v).grow(6.0)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	if _path_points.size() < 2 or _bounds.size.x < 1.0:
		return

	var inner := Rect2(
		Vector2(r.size.x * map_region.position.x, r.size.y * map_region.position.y),
		Vector2(r.size.x * map_region.size.x, r.size.y * map_region.size.y)
	)
	if _display_points.is_empty() or not _display_cache_size.is_equal_approx(size):
		_rebuild_display_path(inner)
	var pts := _display_points

	# Painterly dirt road: soft soil edge, packed dirt and an irregular dusty face.
	if pts.size() >= 2:
		draw_polyline(pts, ROAD_SHADOW, 12.5, true)
		draw_polyline(pts, ROAD_EDGE, 10.0, true)
		draw_polyline(pts, ROAD_DIRT, 8.0, true)
		draw_polyline(pts, ROAD_DUST, 5.5, true)
		_draw_road_wear(pts)

	if get_tree() == null:
		return
	for node in get_tree().get_nodes_in_group("vehicles"):
		if not (node is Vehicle):
			continue
		var veh := node as Vehicle
		if not veh.is_alive:
			continue
		var world := veh.get_vehicle_position()
		var mp := _world_to_map(Vector2(world.x, world.z), inner)
		mp = _closest_point_on_path(mp, pts)
		var dot_color := veh.minimap_color
		if veh == player:
			draw_circle(mp, 8.0, GameStyle.INK)
			draw_circle(mp, 6.0, Color.WHITE)
			draw_circle(mp, 4.7, dot_color)
		else:
			draw_circle(mp, 6.0, GameStyle.INK)
			draw_circle(mp, 4.2, dot_color)


func _draw_road_wear(points: PackedVector2Array) -> void:
	## Small deterministic marks break up the clean vector stroke without
	## flickering or introducing a runtime texture.
	if points.size() < 6:
		return
	var stride := maxi(int(points.size() / 48), 3)
	var mark_index := 0
	for index in range(2, points.size() - 2, stride):
		var tangent := (points[index + 1] - points[index - 1]).normalized()
		if tangent.length_squared() < 0.001:
			continue
		var normal := Vector2(-tangent.y, tangent.x)
		var wave := sin(float(index) * 1.73)
		var center := points[index] + normal * wave * 2.0
		var half_length := 1.1 + absf(cos(float(index) * 0.91)) * 1.5
		var mark_color := Color("704327") if mark_index % 3 != 0 else Color("efd093")
		mark_color.a = 0.56 if mark_index % 3 != 0 else 0.42
		draw_line(center - tangent * half_length, center + tangent * half_length, mark_color, 1.1, true)
		if mark_index % 5 == 0:
			draw_circle(center + normal * 1.2, 0.75, mark_color)
		mark_index += 1


func _rebuild_display_path(inner: Rect2) -> void:
	var mapped := PackedVector2Array()
	for point in _path_points:
		mapped.append(_world_to_map(point, inner))
	_display_points = _smooth_closed_path(mapped, 4)
	_display_cache_size = size


func _smooth_closed_path(points: PackedVector2Array, iterations: int) -> PackedVector2Array:
	## Chaikin corner cutting gives the HUD road broad, rounded bends while
	## leaving the gameplay Path3D untouched.
	if points.size() < 3:
		return points
	var working: Array[Vector2] = []
	var count := points.size()
	if points[0].distance_to(points[count - 1]) < 1.0:
		count -= 1
	for index in count:
		working.append(points[index])
	for _pass in iterations:
		var rounded: Array[Vector2] = []
		for index in working.size():
			var current := working[index]
			var following := working[(index + 1) % working.size()]
			rounded.append(current.lerp(following, 0.25))
			rounded.append(current.lerp(following, 0.75))
		working = rounded
	var result := PackedVector2Array()
	for point in working:
		result.append(point)
	if not working.is_empty():
		result.append(working[0])
	return result


func _closest_point_on_path(point: Vector2, points: PackedVector2Array) -> Vector2:
	if points.size() < 2:
		return point
	var closest := points[0]
	var closest_distance := INF
	for index in points.size() - 1:
		var start := points[index]
		var finish := points[index + 1]
		var segment := finish - start
		var segment_length_squared := segment.length_squared()
		var amount := 0.0
		if segment_length_squared > 0.0001:
			amount = clampf((point - start).dot(segment) / segment_length_squared, 0.0, 1.0)
		var candidate := start + segment * amount
		var distance := point.distance_squared_to(candidate)
		if distance < closest_distance:
			closest_distance = distance
			closest = candidate
	return closest


func _world_to_map(world: Vector2, inner: Rect2) -> Vector2:
	var scale_factor := minf(
		inner.size.x / maxf(_bounds.size.x, 1.0),
		inner.size.y / maxf(_bounds.size.y, 1.0)
	)
	var fitted_size := _bounds.size * scale_factor
	var fitted_origin := inner.position + (inner.size - fitted_size) * 0.5
	return fitted_origin + (world - _bounds.position) * scale_factor
