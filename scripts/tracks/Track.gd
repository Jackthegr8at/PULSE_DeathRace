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
	# Industrial night arena floor (concept art mood)
	var floor_rect := ColorRect.new()
	floor_rect.name = "ArenaFloor"
	floor_rect.color = Color(0.07, 0.08, 0.11)
	floor_rect.position = Vector2(80, 20)
	floor_rect.size = Vector2(1840, 1000)
	_visuals_root.add_child(floor_rect)

	# Subtle grid
	var grid := Node2D.new()
	grid.name = "Grid"
	_visuals_root.add_child(grid)
	for x in range(0, 20):
		var v := Line2D.new()
		v.width = 1.0
		v.default_color = Color(1, 1, 1, 0.03)
		v.add_point(Vector2(100 + x * 90, 40))
		v.add_point(Vector2(100 + x * 90, 1000))
		grid.add_child(v)
	for y in range(0, 12):
		var h := Line2D.new()
		h.width = 1.0
		h.default_color = Color(1, 1, 1, 0.03)
		h.add_point(Vector2(100, 40 + y * 80))
		h.add_point(Vector2(1900, 40 + y * 80))
		grid.add_child(h)

	# Dark infields (inside loops)
	_add_circle_poly(left_center, loop_radius - track_half_width - 6.0, Color(0.05, 0.06, 0.08), _visuals_root)
	_add_circle_poly(right_center, loop_radius - track_half_width - 6.0, Color(0.05, 0.06, 0.08), _visuals_root)


func _build_path() -> void:
	race_path = Path2D.new()
	race_path.name = "RacePath"
	var curve := Curve2D.new()

	# Continuous figure-8: left loop then right loop
	var segments := 48
	for i in segments:
		var t := float(i) / float(segments)
		var ang := -PI / 2.0 + t * TAU
		var p := left_center + Vector2(cos(ang), sin(ang)) * loop_radius
		curve.add_point(p)

	for i in segments:
		var t := float(i) / float(segments)
		var ang := PI - t * TAU
		var p := right_center + Vector2(cos(ang), sin(ang)) * loop_radius
		curve.add_point(p)

	curve.add_point(left_center + Vector2(0, -loop_radius))
	race_path.curve = curve
	add_child(race_path)

	_draw_neon_track_ribbon(curve)


func _draw_neon_track_ribbon(curve: Curve2D) -> void:
	## Concept-style asphalt + cyan/purple neon edges + yellow dashes.
	var baked := curve.get_baked_points()
	if baked.is_empty():
		return

	# Outer neon glow (wide, soft)
	var glow := Line2D.new()
	glow.name = "NeonGlow"
	glow.width = track_half_width * 2.0 + 28.0
	glow.default_color = Color(0.18, 0.75, 1.0, 0.12)
	glow.begin_cap_mode = Line2D.LINE_CAP_ROUND
	glow.end_cap_mode = Line2D.LINE_CAP_ROUND
	glow.joint_mode = Line2D.LINE_JOINT_ROUND
	for p in baked:
		glow.add_point(p)
	_visuals_root.add_child(glow)

	# Asphalt body
	var asphalt := Line2D.new()
	asphalt.name = "AsphaltRibbon"
	asphalt.width = track_half_width * 2.0
	asphalt.default_color = Color(0.16, 0.18, 0.22, 1.0)
	asphalt.begin_cap_mode = Line2D.LINE_CAP_ROUND
	asphalt.end_cap_mode = Line2D.LINE_CAP_ROUND
	asphalt.joint_mode = Line2D.LINE_JOINT_ROUND
	for p in baked:
		asphalt.add_point(p)
	_visuals_root.add_child(asphalt)

	# Inner asphalt shade
	var asphalt_inner := Line2D.new()
	asphalt_inner.name = "AsphaltInner"
	asphalt_inner.width = track_half_width * 1.55
	asphalt_inner.default_color = Color(0.12, 0.13, 0.16, 1.0)
	asphalt_inner.begin_cap_mode = Line2D.LINE_CAP_ROUND
	asphalt_inner.end_cap_mode = Line2D.LINE_CAP_ROUND
	asphalt_inner.joint_mode = Line2D.LINE_JOINT_ROUND
	for p in baked:
		asphalt_inner.add_point(p)
	_visuals_root.add_child(asphalt_inner)

	# Neon rails (cyan outer / purple inner) — concept art figure-8 edge lights
	_add_neon_rail(baked, track_half_width + 2.0, Color(0.18, 0.94, 1.0, 0.9), "NeonOuter")
	_add_neon_rail(baked, -(track_half_width + 2.0), Color(0.7, 0.3, 1.0, 0.85), "NeonInner")

	# Yellow center dashes
	var step := 18
	var i := 0
	while i + 8 < baked.size():
		var seg := Line2D.new()
		seg.width = 3.0
		seg.default_color = Color(1.0, 0.84, 0.3, 0.7)
		seg.add_point(baked[i])
		seg.add_point(baked[mini(i + 6, baked.size() - 1)])
		_visuals_root.add_child(seg)
		i += step


func _add_neon_rail(baked: PackedVector2Array, lateral: float, color: Color, rail_name: String) -> void:
	var rail := Line2D.new()
	rail.name = rail_name
	rail.width = 6.0
	rail.default_color = color
	rail.begin_cap_mode = Line2D.LINE_CAP_ROUND
	rail.end_cap_mode = Line2D.LINE_CAP_ROUND
	rail.joint_mode = Line2D.LINE_JOINT_ROUND
	for i in baked.size():
		var p: Vector2 = baked[i]
		var prev: Vector2 = baked[maxi(i - 1, 0)]
		var next: Vector2 = baked[mini(i + 1, baked.size() - 1)]
		var tangent := (next - prev).normalized()
		if tangent.length_squared() < 0.0001:
			tangent = Vector2.RIGHT
		var normal := Vector2(-tangent.y, tangent.x) * lateral
		rail.add_point(p + normal)
	_visuals_root.add_child(rail)
	# Soft glow twin
	var glow := Line2D.new()
	glow.name = rail_name + "Glow"
	glow.width = 14.0
	glow.default_color = Color(color.r, color.g, color.b, 0.2)
	glow.begin_cap_mode = Line2D.LINE_CAP_ROUND
	glow.end_cap_mode = Line2D.LINE_CAP_ROUND
	glow.joint_mode = Line2D.LINE_JOINT_ROUND
	for i in rail.get_point_count():
		glow.add_point(rail.get_point_position(i))
	_visuals_root.add_child(glow)


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
		vis.color = Color(0.2, 0.22, 0.26)
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
	vis.color = Color(0.18, 0.2, 0.24)
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
	_add_circle_poly(Vector2.ZERO, radius, Color(0.06, 0.07, 0.09), wall)
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
