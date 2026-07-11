class_name Track
extends Node2D
## Base track API. Figure-8 builds geometry in code for a consistent playable layout.

signal car_checkpoint(car: Car, index: int)
signal car_lap_line(car: Car)

@export var build_figure8_on_ready: bool = true
@export var track_scale: float = 1.0

## Centers and radii for the two loops (world units).
@export var left_center: Vector2 = Vector2(635, 550)
@export var right_center: Vector2 = Vector2(1410, 550)
@export var loop_radius: float = 280.0
@export var track_half_width: float = 110.0 ## Matches the painted road width

var race_path: Path2D
var spawn_markers: Array[Marker2D] = []
var checkpoint_count: int = 0

var _walls_root: Node2D
var _visuals_root: Node2D
var _areas_root: Node2D
var _using_concept_backdrop: bool = false


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
	## Use the finished painted playfield as the visual foundation; gameplay remains procedural.
	var concept_texture := load("res://assets/concept/figure8_playfield_painted.png") as Texture2D
	if concept_texture:
		_using_concept_backdrop = true
		var backdrop := Sprite2D.new()
		backdrop.name = "PaintedPlayfield"
		backdrop.texture = concept_texture
		backdrop.position = Vector2(1023, 520)
		backdrop.scale = Vector2(1.15, 1.106)
		backdrop.z_index = -10
		_visuals_root.add_child(backdrop)
		return

	## Fallback procedural countryside if the painted playfield is unavailable.
	var floor_rect := ColorRect.new()
	floor_rect.name = "GrassField"
	floor_rect.color = Color(0.34, 0.62, 0.26)
	floor_rect.position = Vector2(40, 0)
	floor_rect.size = Vector2(1920, 1040)
	_visuals_root.add_child(floor_rect)

	# Soft grass patches (painterly blobs)
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for i in 28:
		var c := Color(
				rng.randf_range(0.28, 0.48),
				rng.randf_range(0.50, 0.75),
				rng.randf_range(0.18, 0.34),
			0.55
		)
		var pos := Vector2(rng.randf_range(120, 1880), rng.randf_range(60, 980))
		_add_circle_poly(pos, rng.randf_range(40, 110), c, _visuals_root)

	# Infield meadow (inside loops)
	_add_circle_poly(left_center, loop_radius - track_half_width - 4.0, Color(0.38, 0.58, 0.3), _visuals_root)
	_add_circle_poly(right_center, loop_radius - track_half_width - 4.0, Color(0.4, 0.6, 0.32), _visuals_root)

	_scatter_props()
	_scatter_grass_and_flowers()


func _scatter_props() -> void:
	var tree_tex := load("res://assets/sprites/prop_tree.png") as Texture2D
	var rock_tex := load("res://assets/sprites/prop_rock.png") as Texture2D
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var props := Node2D.new()
	props.name = "Props"
	_visuals_root.add_child(props)

	# Trees around the outer edge of the arena
	for i in 14:
		var ang := rng.randf() * TAU
		var dist := loop_radius + track_half_width + rng.randf_range(90, 220)
		var center := left_center if i % 2 == 0 else right_center
		# Mix of both loops and outer ring
		if i > 8:
			center = (left_center + right_center) * 0.5
			dist = rng.randf_range(420, 560)
			ang = rng.randf() * TAU
		var pos: Vector2 = center + Vector2(cos(ang), sin(ang)) * dist
		# Keep off the racing line roughly
		if pos.distance_to(left_center) < loop_radius + track_half_width + 30:
			continue
		if pos.distance_to(right_center) < loop_radius + track_half_width + 30:
			continue
		if tree_tex:
			var spr := Sprite2D.new()
			spr.texture = tree_tex
			spr.position = pos
			spr.scale = Vector2.ONE * rng.randf_range(0.7, 1.15)
			spr.z_index = 2
			props.add_child(spr)

	for i in 10:
		var ang := rng.randf() * TAU
		var center := left_center if i % 2 == 0 else right_center
		var dist := loop_radius + track_half_width + rng.randf_range(50, 140)
		var pos: Vector2 = center + Vector2(cos(ang), sin(ang)) * dist
		if rock_tex:
			var spr := Sprite2D.new()
			spr.texture = rock_tex
			spr.position = pos
			spr.scale = Vector2.ONE * rng.randf_range(0.45, 0.85)
			spr.rotation = rng.randf() * TAU
			spr.z_index = 1
			props.add_child(spr)

	_add_arena_fences()


func _scatter_grass_and_flowers() -> void:
	## Small painted blades and flowers break up the procedural field into a hand-placed look.
	var details := Node2D.new()
	details.name = "GrassAndFlowers"
	details.z_index = 1
	_visuals_root.add_child(details)
	var rng := RandomNumberGenerator.new()
	rng.seed = 91
	for i in 110:
		var pos := Vector2(rng.randf_range(90, 1870), rng.randf_range(55, 985))
		if _near_racing_surface(pos, 46.0):
			continue
		var blade_color := Color("2c6d31").lightened(rng.randf_range(0.0, 0.35))
		for j in 3:
			var blade := Polygon2D.new()
			var x := float(j - 1) * 4.0
			blade.polygon = PackedVector2Array([
				pos + Vector2(x - 2.0, 4.0),
				pos + Vector2(x + 1.0, -rng.randf_range(7.0, 14.0)),
				pos + Vector2(x + 4.0, 4.0),
			])
			blade.color = blade_color
			details.add_child(blade)
		if i % 4 == 0:
			var flower := Polygon2D.new()
			flower.polygon = _circle_points(pos + Vector2(5, -5), 3.0, 8)
			flower.color = Color("f5c85b") if i % 8 == 0 else Color("d46c76")
			details.add_child(flower)


func _near_racing_surface(pos: Vector2, padding: float) -> bool:
	for center in [left_center, right_center]:
		var radial := absf(pos.distance_to(center) - loop_radius)
		if radial < track_half_width + padding:
			return true
	return false


func _circle_points(center: Vector2, radius: float, count: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in count:
		var angle := TAU * float(i) / float(count)
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	return points


func _add_arena_fences() -> void:
	## Decorative fence rails and pennants keep the empty field lively without collision.
	var fence := Node2D.new()
	fence.name = "PaintedFences"
	fence.z_index = 3
	_visuals_root.add_child(fence)
	var points := [Vector2(120, 140), Vector2(560, 86), Vector2(1420, 86), Vector2(1830, 150), Vector2(1840, 900), Vector2(1450, 980), Vector2(470, 980), Vector2(100, 880)]
	for i in points.size():
		var a: Vector2 = points[i]
		var b: Vector2 = points[(i + 1) % points.size()]
		var rail := Line2D.new()
		rail.width = 6.0
		rail.default_color = Color("5b3824")
		rail.add_point(a)
		rail.add_point(b)
		fence.add_child(rail)
		for j in 2:
			var post := ColorRect.new()
			post.color = Color("3b291c")
			post.size = Vector2(10, 30)
			post.position = a.lerp(b, (float(j) + 0.35) / 2.0) - post.size * 0.5
			post.rotation = (b - a).angle()
			fence.add_child(post)


func _build_path() -> void:
	race_path = Path2D.new()
	race_path.name = "RacePath"
	var curve := Curve2D.new()

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

	if not _using_concept_backdrop:
		_draw_dirt_track_ribbon(curve)


func _draw_dirt_track_ribbon(curve: Curve2D) -> void:
	## Warm dirt / packed earth road with bold dark outlines (toon, not neon).
	var baked := curve.get_baked_points()
	if baked.is_empty():
		return

	# Bold outer outline (comic ink)
	var outline := Line2D.new()
	outline.name = "TrackOutline"
	outline.width = track_half_width * 2.0 + 14.0
	outline.default_color = Color(0.12, 0.08, 0.05, 1.0)
	outline.begin_cap_mode = Line2D.LINE_CAP_ROUND
	outline.end_cap_mode = Line2D.LINE_CAP_ROUND
	outline.joint_mode = Line2D.LINE_JOINT_ROUND
	for p in baked:
		outline.add_point(p)
	_visuals_root.add_child(outline)

	# Dirt body
	var dirt := Line2D.new()
	dirt.name = "DirtRibbon"
	dirt.width = track_half_width * 2.0
	dirt.default_color = Color(0.62, 0.36, 0.18, 1.0)
	dirt.begin_cap_mode = Line2D.LINE_CAP_ROUND
	dirt.end_cap_mode = Line2D.LINE_CAP_ROUND
	dirt.joint_mode = Line2D.LINE_JOINT_ROUND
	for p in baked:
		dirt.add_point(p)
	_visuals_root.add_child(dirt)

	# Lighter packed center
	var packed := Line2D.new()
	packed.name = "DirtPacked"
	packed.width = track_half_width * 1.35
	packed.default_color = Color(0.74, 0.47, 0.25, 1.0)
	packed.begin_cap_mode = Line2D.LINE_CAP_ROUND
	packed.end_cap_mode = Line2D.LINE_CAP_ROUND
	packed.joint_mode = Line2D.LINE_JOINT_ROUND
	for p in baked:
		packed.add_point(p)
	_visuals_root.add_child(packed)

	# Soft cream dashed center line
	var step := 16
	var i := 0
	while i + 7 < baked.size():
		var seg := Line2D.new()
		seg.width = 3.0
		seg.default_color = Color(1.0, 0.86, 0.50, 0.92)
		seg.add_point(baked[i])
		seg.add_point(baked[mini(i + 5, baked.size() - 1)])
		_visuals_root.add_child(seg)
		i += step

	# Painted tire scuffs and dust flecks along the racing line.
	var rng := RandomNumberGenerator.new()
	rng.seed = 101
	for k in range(0, baked.size(), 4):
		var p: Vector2 = baked[k]
		var next_p: Vector2 = baked[(k + 1) % baked.size()]
		var tangent := (next_p - p).normalized()
		var normal := Vector2(-tangent.y, tangent.x)
		var center := p + normal * rng.randf_range(-track_half_width * 0.62, track_half_width * 0.62)
		var length := rng.randf_range(8.0, 22.0)
		var width := rng.randf_range(2.0, 5.0)
		var fleck := Polygon2D.new()
		fleck.polygon = PackedVector2Array([
			center - tangent * length * 0.5 - normal * width,
			center + tangent * length * 0.5 - normal * width,
			center + tangent * length * 0.5 + normal * width,
			center - tangent * length * 0.5 + normal * width,
		])
		fleck.color = Color(0.36, 0.18, 0.08, rng.randf_range(0.10, 0.24))
		fleck.z_index = 1
		_visuals_root.add_child(fleck)


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
		# Invisible collision only — visuals come from dirt outline / props
		vis.color = Color(0.35, 0.45, 0.28, 0.0)
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
	vis.color = Color(0.45, 0.35, 0.22, 0.0 if _using_concept_backdrop else 1.0) # collision wall; art is in the backdrop
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
	if not _using_concept_backdrop:
		_add_circle_poly(Vector2.ZERO, radius, Color(0.36, 0.55, 0.28), wall)
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
	if _using_concept_backdrop:
		return
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
	if not _using_concept_backdrop:
		var vis := ColorRect.new()
		vis.size = Vector2(14, track_half_width * 2.0)
		vis.position = Vector2(-7, -track_half_width)
		vis.color = Color(0.95, 0.88, 0.55, 0.75)
		area.add_child(vis)
		var label := Label.new()
		label.text = "S/F"
		label.position = Vector2(-14, -track_half_width - 20)
		label.add_theme_font_size_override("font_size", 14)
		label.add_theme_color_override("font_color", Color(0.25, 0.2, 0.12))
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
