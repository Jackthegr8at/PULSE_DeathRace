extends Track3DBase
## Playable figure-8 from Kenney road tiles only (like Starter Circuit).
## No full-map empty fill (that caused void / fall-through). Spawn on finish.

const ITEM_FOREST := 1
const ITEM_TENTS := 2
const ITEM_CORNER := 3
const ITEM_FINISH := 4
const ITEM_STRAIGHT := 6

const O_0 := 0
const O_90 := 10
const O_180 := 16
const O_270 := 22

@onready var grid: GridMap = $GridMap

## Finish + spawn on left loop top edge
const SPAWN_CELL := Vector3i(-4, 0, -4)


func _ready() -> void:
	track_display_name = "Figure-8 Chaos"
	if grid == null:
		push_error("TrackFigure8: GridMap missing")
		return
	grid.clear()
	_build_figure8_roads()
	_place_sparse_forest()
	# Defer: GridMap collision + transforms must settle (fixes void spawn)
	call_deferred("_finalize_track")


func _finalize_track() -> void:
	_place_spawn_on_finish()
	if not _build_path_from_grid():
		_build_fallback_path()
	_ensure_finish_line()
	_spawn_missile_pickups()


func _build_figure8_roads() -> void:
	## Twin loops + center cross. Only road tiles (no empty ground carpet).
	##
	## Left:  x=-7..-1  z=-4..1
	## Right: x=1..7    z=-4..1
	## Cross: x=-1..1   z=-2..-1

	# ---- Left loop ----
	_corner(-7, -4, O_180)
	_corner(-1, -4, O_270)
	_corner(-1, 1, O_0)
	_corner(-7, 1, O_90)
	for x in range(-6, 0):
		_straight(x, -4, O_0)
		_straight(x, 1, O_0)
	for z in range(-3, 1):
		_straight(-7, z, O_90)
	# left-loop east edge (except cross rows -2,-1)
	_straight(-1, -3, O_90)
	_straight(-1, 0, O_90)

	# ---- Right loop ----
	_corner(1, -4, O_180)
	_corner(7, -4, O_270)
	_corner(7, 1, O_0)
	_corner(1, 1, O_90)
	for x in range(2, 7):
		_straight(x, -4, O_0)
		_straight(x, 1, O_0)
	for z in range(-3, 1):
		_straight(7, z, O_90)
	_straight(1, -3, O_90)
	_straight(1, 0, O_90)

	# ---- Center cross (links the loops) ----
	for x in range(-1, 2):
		_straight(x, -2, O_0)
		_straight(x, -1, O_0)

	# Finish / spawn (overwrites left-top straight at -4,-4)
	grid.set_cell_item(SPAWN_CELL, ITEM_FINISH, O_0)


func _place_sparse_forest() -> void:
	## Decorate around the track only — never fill the map with empty tiles.
	var forest_spots: Array[Vector3i] = [
		Vector3i(-9, 0, -6), Vector3i(-9, 0, -2), Vector3i(-9, 0, 2),
		Vector3i(9, 0, -6), Vector3i(9, 0, -2), Vector3i(9, 0, 2),
		Vector3i(-5, 0, -7), Vector3i(0, 0, -7), Vector3i(5, 0, -7),
		Vector3i(-5, 0, 3), Vector3i(0, 0, 3), Vector3i(5, 0, 3),
		Vector3i(-10, 0, -4), Vector3i(10, 0, -4),
		Vector3i(-8, 0, 0), Vector3i(8, 0, 0),
		Vector3i(-3, 0, -6), Vector3i(3, 0, -6),
		Vector3i(-3, 0, 2), Vector3i(3, 0, 2),
	]
	for cell in forest_spots:
		if grid.get_cell_item(cell) == GridMap.INVALID_CELL_ITEM:
			grid.set_cell_item(cell, ITEM_FOREST, O_0)
	if grid.get_cell_item(Vector3i(0, 0, 4)) == GridMap.INVALID_CELL_ITEM:
		grid.set_cell_item(Vector3i(0, 0, 4), ITEM_TENTS, O_0)
	if grid.get_cell_item(Vector3i(0, 0, -8)) == GridMap.INVALID_CELL_ITEM:
		grid.set_cell_item(Vector3i(0, 0, -8), ITEM_TENTS, O_180)


func _place_spawn_on_finish() -> void:
	var marker := get_node_or_null("SpawnPoint") as Marker3D
	if marker == null:
		marker = Marker3D.new()
		marker.name = "SpawnPoint"
		add_child(marker)
	# Sibling of GridMap: convert cell center into track-local space
	var cell_local: Vector3 = grid.map_to_local(SPAWN_CELL)
	marker.position = grid.transform * cell_local + Vector3(0, 0.55, 0)
	# Face along +X (into left-top straight toward the cross)
	marker.rotation = Vector3(0, PI * 0.5, 0)


func _build_fallback_path() -> void:
	if race_path == null:
		race_path = Path3D.new()
		race_path.name = "RacePath"
		add_child(race_path)
	# Walk all used road cells into a rough loop order via grid neighbor walk
	# (same algorithm as base, but force re-run after tiles exist)
	if _build_path_from_grid():
		return
	# Last resort: sample cell centers we know exist
	var cells: Array[Vector3i] = []
	for x in range(-7, 0):
		cells.append(Vector3i(x, 0, -4))
	for z in range(-3, 2):
		cells.append(Vector3i(-1, 0, z))
	for x in range(-1, -8, -1):
		cells.append(Vector3i(x, 0, 1))
	for z in range(0, -5, -1):
		cells.append(Vector3i(-7, 0, z))
	for x in range(-1, 2):
		cells.append(Vector3i(x, 0, -2))
	for x in range(1, 8):
		cells.append(Vector3i(x, 0, -4))
	for z in range(-3, 2):
		cells.append(Vector3i(7, 0, z))
	for x in range(6, 0, -1):
		cells.append(Vector3i(x, 0, 1))
	for x in range(1, -2, -1):
		cells.append(Vector3i(x, 0, -1))
	var curve := Curve3D.new()
	curve.bake_interval = 0.4
	for c in cells:
		if grid.get_cell_item(c) == GridMap.INVALID_CELL_ITEM:
			continue
		var p: Vector3 = grid.to_global(grid.map_to_local(c))
		p.y = 0.3
		curve.add_point(p)
	if curve.get_point_count() > 2:
		race_path.curve = curve


func _straight(x: int, z: int, orientation: int) -> void:
	grid.set_cell_item(Vector3i(x, 0, z), ITEM_STRAIGHT, orientation)


func _corner(x: int, z: int, orientation: int) -> void:
	grid.set_cell_item(Vector3i(x, 0, z), ITEM_CORNER, orientation)
