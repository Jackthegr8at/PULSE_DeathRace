class_name Track
extends Node2D
## Base track API. Figure-8 builds geometry in code for a consistent playable layout.

signal car_checkpoint(car: Car, index: int)
signal car_lap_line(car: Car)

@export var build_figure8_on_ready: bool = true
@export var track_scale: float = 1.0

## Centers and radii for the two loops (world units).
@export var left_center: Vector2 = Vector2(700, 520)
@export var right_center: Vector2 = Vector2(1300, 520)
@export var loop_radius: float = 280.0
@export var track_half_width: float = 100.0 ## Wider lane = fewer accidental wall rides

var race_path: Path2D
var spawn_markers: Array[Marker2D] = []
var checkpoint_count: int = 0

var _walls_root: Node2D
var _visuals_root: Node2D
var _areas_root: Node2D


func _ready() -> void:
	if build_figure8_on_ready:
		_build_figure8()
	else:
		_cache_existing()


func get_race_path() -> Path2D:
	return race_path


func get_spawn_transforms() -> Array[Transform2D]:
	var result: Array[Transform2D] = []
	for m in spawn_markers:
		result.append(m.global_transform)
	return result


func get_checkpoint_count() -> int:
	return checkpoint_count


func _cache_existing() -> void:
	race_path = get_node_or_null("RacePath") as Path2D
	spawn_markers.clear()
	for child in get_children():
		if child is Marker2D and child.name.begins_with("Spawn"):
			spawn_markers.append(child)


func _build_figure8() -> void:
	_visuals_root = Node2D.new()
	_visuals_root.name = "Visuals"
	add_child(_visuals_root)

	_walls_root = Node2D.new()
	_walls_root.name = "Walls"
	add_child(_walls_root)

	_areas_root = Node2D.new()
	_areas_root.name = "Areas"
	add_child(_areas_root)

	_draw_background()
	_build_path()
	_build_walls()
	_build_checkpoints_and_finish()
	_build_spawns()


func _draw_background() -> void:
	var bg := ColorRect.new()
	bg.name = "Asphalt"
	bg.color = Color(0.14, 0.16, 0.2)
	bg.position = Vector2(200, 80)
	bg.size = Vector2(1600, 880)
	_visuals_root.add_child(bg)

	# Soft infield tint under loops
	_add_circle_poly(left_center, loop_radius - track_half_width - 10.0, Color(0.1, 0.22, 0.14, 0.9), _visuals_root)
	_add_circle_poly(right_center, loop_radius - track_half_width - 10.0, Color(0.1, 0.22, 0.14, 0.9), _visuals_root)

	# Track ribbons (visual only)
	_add_ring_poly(left_center, loop_radius, track_half_width, Color(0.22, 0.25, 0.3), _visuals_root)
	_add_ring_poly(right_center, loop_radius, track_half_width, Color(0.22, 0.25, 0.3), _visuals_root)

	# Cross paint
	var cross := ColorRect.new()
	cross.color = Color(0.95, 0.7, 0.25, 0.35)
	cross.size = Vector2(90, 90)
	cross.position = (left_center + right_center) * 0.5 - cross.size * 0.5
	_visuals_root.add_child(cross)


func _build_path() -> void:
	race_path = Path2D.new()
	race_path.name = "RacePath"
	var curve := Curve2D.new()

	# Continuous figure-8: left loop then right loop (lemniscate-ish via two circles)
	# Direction: start at top of left loop, go clockwise around left, through center,
	# counterclockwise around right, back through center.
	var segments := 48
	# Left loop clockwise starting from top (angle -PI/2)
	for i in segments:
		var t := float(i) / float(segments)
		var ang := -PI / 2.0 + t * TAU
		var p := left_center + Vector2(cos(ang), sin(ang)) * loop_radius
		curve.add_point(p)

	# Right loop: enter from center-ish going up-right, counterclockwise from PI
	for i in segments:
		var t := float(i) / float(segments)
		# Start at left side of right loop (ang = PI) going toward top then right...
		var ang := PI - t * TAU
		var p := right_center + Vector2(cos(ang), sin(ang)) * loop_radius
		curve.add_point(p)

	# Close toward start
	curve.add_point(left_center + Vector2(0, -loop_radius))
	race_path.curve = curve
	add_child(race_path)

	# Debug draw of path (subtle)
	var line := Line2D.new()
	line.name = "PathGuide"
	line.width = 2.0
	line.default_color = Color(1, 0.9, 0.3, 0.25)
	for i in curve.get_baked_points().size():
		line.add_point(curve.get_baked_points()[i])
	_visuals_root.add_child(line)


func _build_walls() -> void:
	# Outer bounding walls (keep cars in the arena)
	var margin := 40.0
	var min_x: float = minf(left_center.x, right_center.x) - loop_radius - track_half_width - 60.0
	var max_x: float = maxf(left_center.x, right_center.x) + loop_radius + track_half_width + 60.0
	var min_y: float = minf(left_center.y, right_center.y) - loop_radius - track_half_width - 60.0
	var max_y: float = maxf(left_center.y, right_center.y) + loop_radius + track_half_width + 60.0
	var thickness := 40.0

	_add_wall_rect(Rect2(min_x - thickness, min_y - thickness, (max_x - min_x) + thickness * 2, thickness), "WallTop")
	_add_wall_rect(Rect2(min_x - thickness, max_y, (max_x - min_x) + thickness * 2, thickness), "WallBottom")
	_add_wall_rect(Rect2(min_x - thickness, min_y, thickness, max_y - min_y), "WallLeft")
	_add_wall_rect(Rect2(max_x, min_y, thickness, max_y - min_y), "WallRight")

	# Infield islands (cars drive around these)
	_add_wall_circle(left_center, loop_radius - track_half_width - 8.0, "IslandLeft")
	_add_wall_circle(right_center, loop_radius - track_half_width - 8.0, "IslandRight")

	# Outer ring walls as segmented arcs approximate (optional extra channel)
	_add_outer_ring_walls(left_center, loop_radius + track_half_width + 8.0, true)
	_add_outer_ring_walls(right_center, loop_radius + track_half_width + 8.0, false)


func _add_outer_ring_walls(center: Vector2, radius: float, is_left: bool) -> void:
	# Segmented thick wall around most of each loop, leaving center gap open for the X
	var segs := 20
	for i in segs:
		var t0 := float(i) / float(segs) * TAU
		var t1 := float(i + 1) / float(segs) * TAU
		var mid := (t0 + t1) * 0.5
		# Skip segments near the inner cross (facing the other loop)
		if is_left and absf(wrapf(mid, -PI, PI)) < 0.55:
			continue
		if not is_left and absf(wrapf(mid - PI, -PI, PI)) < 0.55:
			continue
		var p := center + Vector2(cos(mid), sin(mid)) * radius
		var wall := StaticBody2D.new()
		wall.name = "RingSeg_%s_%d" % ["L" if is_left else "R", i]
		wall.position = p
		wall.rotation = mid
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(28, radius * (t1 - t0) * 1.15)
		shape.shape = rect
		wall.add_child(shape)
		var vis := ColorRect.new()
		vis.size = rect.size
		vis.position = -rect.size * 0.5
		vis.color = Color(0.45, 0.5, 0.58)
		wall.add_child(vis)
		wall.collision_layer = 1
		wall.collision_mask = 0
		_walls_root.add_child(wall)


func _add_wall_rect(rect: Rect2, wall_name: String) -> void:
	var wall := StaticBody2D.new()
	wall.name = wall_name
	wall.position = rect.position + rect.size * 0.5
	var shape := CollisionShape2D.new()
	var rect_shape := RectangleShape2D.new()
	rect_shape.size = rect.size
	shape.shape = rect_shape
	wall.add_child(shape)
	var vis := ColorRect.new()
	vis.size = rect.size
	vis.position = -rect.size * 0.5
	vis.color = Color(0.4, 0.45, 0.52)
	wall.add_child(vis)
	wall.collision_layer = 1
	_walls_root.add_child(wall)


func _add_wall_circle(center: Vector2, radius: float, wall_name: String) -> void:
	var wall := StaticBody2D.new()
	wall.name = wall_name
	wall.position = center
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius
	shape.shape = circle
	wall.add_child(shape)
	_add_circle_poly(Vector2.ZERO, radius, Color(0.12, 0.28, 0.16), wall)
	wall.collision_layer = 1
	_walls_root.add_child(wall)


func _build_checkpoints_and_finish() -> void:
	if race_path == null or race_path.curve == null:
		return
	var length := race_path.curve.get_baked_length()
	# Visual sector markers only — lap counting is path-progress based on cars.
	var count := 4
	checkpoint_count = count
	for i in count:
		var offset := length * (float(i) + 0.5) / float(count)
		var pos := race_path.curve.sample_baked(offset)
		var next_pos := race_path.curve.sample_baked(fmod(offset + 20.0, length))
		var ang := (next_pos - pos).angle()
		_add_checkpoint_marker(i, pos, ang)

	# Wide start/finish gate (backup lap complete when enough path distance)
	var sf_pos := race_path.curve.sample_baked(0.0)
	var sf_next := race_path.curve.sample_baked(25.0)
	_add_start_finish(sf_pos, (sf_next - sf_pos).angle())


func _add_checkpoint_marker(index: int, pos: Vector2, ang: float) -> void:
	var vis_root := Node2D.new()
	vis_root.name = "CheckpointMark_%d" % index
	vis_root.position = pos
	vis_root.rotation = ang
	var vis := ColorRect.new()
	vis.size = Vector2(6, track_half_width * 1.6)
	vis.position = Vector2(-3, -track_half_width * 0.8)
	vis.color = Color(0.4, 0.7, 1.0, 0.3)
	vis_root.add_child(vis)
	_areas_root.add_child(vis_root)


func _add_start_finish(pos: Vector2, ang: float) -> void:
	var area := Area2D.new()
	area.name = "StartFinish"
	area.position = pos
	area.rotation = ang
	area.collision_layer = 0
	area.collision_mask = 2
	area.monitoring = true
	area.monitorable = false
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	# Thick gate across the full lane so it's hard to miss
	rect.size = Vector2(70, track_half_width * 2.6)
	shape.shape = rect
	area.add_child(shape)
	var vis := ColorRect.new()
	vis.size = Vector2(14, track_half_width * 2.0)
	vis.position = Vector2(-7, -track_half_width)
	vis.color = Color(0.4, 0.95, 0.5, 0.55)
	area.add_child(vis)
	var label := Label.new()
	label.text = "S/F"
	label.position = Vector2(-14, -track_half_width - 20)
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(0.6, 1.0, 0.7))
	area.add_child(label)
	area.body_entered.connect(func(body: Node) -> void:
		if body is Car:
			(body as Car).on_start_finish()
			car_lap_line.emit(body as Car)
	)
	_areas_root.add_child(area)


func _build_spawns() -> void:
	spawn_markers.clear()
	# Grid near start/finish along the path
	if race_path == null or race_path.curve == null:
		return
	var base := 40.0
	for i in 5:
		var offset := base + float(i) * 38.0
		var pos := race_path.curve.sample_baked(offset)
		var ahead := race_path.curve.sample_baked(offset + 30.0)
		var ang := (ahead - pos).angle()
		# Stagger left/right of path
		var side := -1.0 if i % 2 == 0 else 1.0
		var lateral := Vector2.UP.rotated(ang) * side * 22.0
		var marker := Marker2D.new()
		marker.name = "Spawn_%d" % i
		marker.position = pos + lateral
		marker.rotation = ang
		add_child(marker)
		spawn_markers.append(marker)


func _add_circle_poly(center: Vector2, radius: float, color: Color, parent: Node) -> void:
	var poly := Polygon2D.new()
	var pts := PackedVector2Array()
	var n := 28
	for i in n:
		var a := TAU * float(i) / float(n)
		pts.append(center + Vector2(cos(a), sin(a)) * radius)
	poly.polygon = pts
	poly.color = color
	parent.add_child(poly)


func _add_ring_poly(center: Vector2, radius: float, half_width: float, color: Color, parent: Node) -> void:
	# Approximate ring as many quads via Polygon2D strips
	var n := 40
	for i in n:
		var a0 := TAU * float(i) / float(n)
		var a1 := TAU * float(i + 1) / float(n)
		var poly := Polygon2D.new()
		var outer0 := center + Vector2(cos(a0), sin(a0)) * (radius + half_width)
		var outer1 := center + Vector2(cos(a1), sin(a1)) * (radius + half_width)
		var inner1 := center + Vector2(cos(a1), sin(a1)) * (radius - half_width)
		var inner0 := center + Vector2(cos(a0), sin(a0)) * (radius - half_width)
		poly.polygon = PackedVector2Array([outer0, outer1, inner1, inner0])
		poly.color = color
		parent.add_child(poly)
