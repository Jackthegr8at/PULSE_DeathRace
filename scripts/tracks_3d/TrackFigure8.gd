extends Track3DBase
## Builds a figure-8 course from Kenney track tiles at runtime.

## MeshLibrary item ids (models/Library/mesh-library.tres)
const ITEM_FOREST := 1
const ITEM_CORNER := 3
const ITEM_FINISH := 4
const ITEM_STRAIGHT := 6

## Orthogonal orientations used by the Kenney sample track
const O_0 := 0
const O_90 := 10
const O_180 := 16
const O_270 := 22

@onready var grid: GridMap = $GridMap


func _ready() -> void:
	track_display_name = "Figure-8 Chaos"
	_build_figure8()
	_place_spawn()
	# Use base path/finish helpers (approximate path until figure-8 is retuned)
	_ensure_race_path()
	_ensure_finish_line()


func _build_figure8() -> void:
	if grid == null:
		return
	grid.clear()

	# --- Left loop (center ~ -3, 0) : square-ish ring ---
	# Top edge (along +X), z = -4
	_corner(-6, -4, O_180)
	_straight(-5, -4, O_0)
	_straight(-4, -4, O_0)
	_straight(-3, -4, O_0)
	_corner(-2, -4, O_270)

	# Right edge of left loop (along +Z), x = -2
	_straight(-2, -3, O_90)
	_straight(-2, -2, O_90)

	# Bottom edge, z = -1
	_corner(-2, -1, O_0)
	_straight(-3, -1, O_0)
	_straight(-4, -1, O_0)
	_straight(-5, -1, O_0)
	_corner(-6, -1, O_90)

	# Left edge, x = -6
	_straight(-6, -2, O_90)
	_straight(-6, -3, O_90)

	# --- Right loop (center ~ 3, 0) ---
	# Top edge z = -4
	_corner(1, -4, O_180)
	_straight(2, -4, O_0)
	_straight(3, -4, O_0)
	_straight(4, -4, O_0)
	_corner(5, -4, O_270)

	# Right edge x = 5
	_straight(5, -3, O_90)
	_straight(5, -2, O_90)

	# Bottom edge z = -1
	_corner(5, -1, O_0)
	_straight(4, -1, O_0)
	_straight(3, -1, O_0)
	_straight(2, -1, O_0)
	_corner(1, -1, O_90)

	# Left edge of right loop x = 1
	_straight(1, -2, O_90)
	_straight(1, -3, O_90)

	# --- Cross connector (figure-8 bridge feel) through center ---
	# Horizontal connector between loops at z = -2.5 approx using z=-2 and -3 already
	# Diagonal-ish link using straights at center
	_straight(-1, -3, O_0)
	_straight(0, -3, O_0)
	_straight(-1, -2, O_0)
	_straight(0, -2, O_0)

	# Finish line on left loop top-center
	grid.set_cell_item(Vector3i(-4, 0, -4), ITEM_FINISH, O_0)

	# Forest decorations around perimeter
	for x in range(-9, 9):
		for z in range(-7, 4):
			if grid.get_cell_item(Vector3i(x, 0, z)) == GridMap.INVALID_CELL_ITEM:
				# Sparse forest
				if (x * 13 + z * 7) % 5 == 0:
					grid.set_cell_item(Vector3i(x, 0, z), ITEM_FOREST, O_0)
				elif (x + z) % 11 == 0:
					grid.set_cell_item(Vector3i(x, 0, z), ITEM_FOREST, O_90)


func _straight(x: int, z: int, ori: int) -> void:
	grid.set_cell_item(Vector3i(x, 0, z), ITEM_STRAIGHT, ori)


func _corner(x: int, z: int, ori: int) -> void:
	grid.set_cell_item(Vector3i(x, 0, z), ITEM_CORNER, ori)


func _place_spawn() -> void:
	var marker := get_node_or_null("SpawnPoint") as Marker3D
	if marker == null:
		marker = Marker3D.new()
		marker.name = "SpawnPoint"
		add_child(marker)
	# Spawn on finish cell (-4, -4); GridMap cell_size 9.99, scale 0.75
	if grid:
		var cell_center := Vector3((-4.0 + 0.5) * 9.99, 0.5, (-4.0 + 0.5) * 9.99)
		marker.global_position = grid.to_global(cell_center)
		marker.rotation = Vector3.ZERO
	else:
		marker.position = Vector3(-20, 0.3, -20)
