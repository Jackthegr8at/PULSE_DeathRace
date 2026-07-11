class_name Minimap
extends Control
## Radar-style minimap (concept art top-right): path outline + live car dots.

@export var map_padding: float = 12.0

var track: Track = null
var player: Car = null
var _path_points: PackedVector2Array = PackedVector2Array()
var _bounds: Rect2 = Rect2()


func setup(p_track: Track, p_player: Car) -> void:
	track = p_track
	player = p_player
	_rebuild_path_cache()
	queue_redraw()


func _rebuild_path_cache() -> void:
	_path_points = PackedVector2Array()
	if track == null:
		return
	var path := track.get_race_path()
	if path == null or path.curve == null:
		return
	var baked := path.curve.get_baked_points()
	for p in baked:
		_path_points.append(path.to_global(p))
	if _path_points.is_empty():
		return
	var min_v := _path_points[0]
	var max_v := _path_points[0]
	for p in _path_points:
		min_v = min_v.min(p)
		max_v = max_v.max(p)
	_bounds = Rect2(min_v, max_v - min_v).grow(40.0)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	# Warm ink panel
	draw_rect(r, GameStyle.FIELD.darkened(0.38), true)
	draw_rect(r, GameStyle.INK, false, 3.0)
	draw_rect(r.grow(-5.0), Color(0.92, 0.76, 0.42, 0.08), false, 2.0)

	if _path_points.size() < 2 or _bounds.size.x < 1.0:
		return

	var inner := r.grow(-map_padding)
	var pts := PackedVector2Array()
	for p in _path_points:
		pts.append(_world_to_map(p, inner))

	# Dirt path on grass minimap
	if pts.size() >= 2:
		draw_polyline(pts, GameStyle.INK, 7.0, true)
		draw_polyline(pts, GameStyle.EARTH, 4.0, true)

	# Cars
	if get_tree() == null:
		return
	for node in get_tree().get_nodes_in_group("cars"):
		if not (node is Car):
			continue
		var car := node as Car
		if not car.is_alive:
			continue
		var mp := _world_to_map(car.global_position, inner)
		var col := car.body_color
		if car == player:
			col = GameStyle.SUCCESS
		draw_circle(mp, 5.0 if car == player else 3.5, GameStyle.INK)
		draw_circle(mp, 3.5 if car == player else 2.5, col)


func _world_to_map(world: Vector2, inner: Rect2) -> Vector2:
	var nx := (world.x - _bounds.position.x) / maxf(_bounds.size.x, 1.0)
	var ny := (world.y - _bounds.position.y) / maxf(_bounds.size.y, 1.0)
	return Vector2(inner.position.x + nx * inner.size.x, inner.position.y + ny * inner.size.y)
