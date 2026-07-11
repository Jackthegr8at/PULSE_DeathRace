class_name Minimap3D
extends Control
## Top-down comic minimap for 3D races: RacePath outline + live vehicle dots.
## World (x, z) is mapped into this control's rect. Player dot is highlighted.

@export var map_padding: float = 14.0

var player: Vehicle = null

var _path_points: PackedVector2Array = PackedVector2Array()
var _bounds: Rect2 = Rect2()


func setup(path: Path3D, p_player: Vehicle) -> void:
	player = p_player
	_rebuild_path_cache(path)
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
	# Painted grass panel with comic ink frame
	draw_rect(r, GameStyle.FIELD.darkened(0.45), true)
	draw_rect(r, GameStyle.INK, false, 4.0)
	draw_rect(r.grow(-6.0), Color(1.0, 0.9, 0.6, 0.10), false, 2.0)

	if _path_points.size() < 2 or _bounds.size.x < 1.0:
		return

	var inner := r.grow(-map_padding)
	var pts := PackedVector2Array()
	for p in _path_points:
		pts.append(_world_to_map(p, inner))

	# Dirt road: thick ink underlay + earth stroke
	if pts.size() >= 2:
		draw_polyline(pts, GameStyle.INK, 8.0, true)
		draw_polyline(pts, GameStyle.EARTH, 4.5, true)

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
		if veh == player:
			draw_circle(mp, 7.0, GameStyle.INK)
			draw_circle(mp, 5.0, GameStyle.ACCENT)
			draw_circle(mp, 2.4, GameStyle.INK)
		else:
			draw_circle(mp, 5.0, GameStyle.INK)
			draw_circle(mp, 3.4, GameStyle.DANGER)


func _world_to_map(world: Vector2, inner: Rect2) -> Vector2:
	var nx := (world.x - _bounds.position.x) / maxf(_bounds.size.x, 1.0)
	var ny := (world.y - _bounds.position.y) / maxf(_bounds.size.y, 1.0)
	return Vector2(inner.position.x + nx * inner.size.x, inner.position.y + ny * inner.size.y)
