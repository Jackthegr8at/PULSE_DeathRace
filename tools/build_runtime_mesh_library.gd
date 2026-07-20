extends SceneTree
## Generates the binary MeshLibrary used by race scenes.
## The editable source remains models/Library/mesh-library.tres.
## Regenerate after MeshLibrary edits with:
## Godot --headless --path . --script res://tools/build_runtime_mesh_library.gd

const SOURCE_PATH := "res://models/Library/mesh-library.tres"
const SOURCE_SCENE_PATH := "res://models/Library/mesh-library.tscn"
const OUTPUT_PATH := "res://models/Library/mesh-library-runtime.res"
const NO_SHADOW_ITEMS: Array[String] = [
	"decoration-empty",
	"decoration-forest",
	"decoration-tents",
	"decoration-watchtower",
	"road-corner",
	"track-finish",
	"decoration-pitstop",
	"track-straight",
]


func _initialize() -> void:
	call_deferred("_build")


func _build() -> void:
	var started_msec := Time.get_ticks_msec()
	print("[MeshLibraryBuild] Loading editable source...")
	var library := ResourceLoader.load(SOURCE_PATH, "MeshLibrary", ResourceLoader.CACHE_MODE_IGNORE) as MeshLibrary
	if library == null:
		_fail("Could not load %s" % SOURCE_PATH)
		return

	var collision_source_text := FileAccess.get_file_as_string(SOURCE_SCENE_PATH)
	var collision_sources := _read_collision_sources(collision_source_text)
	if collision_sources.is_empty():
		_fail("Could not read road wall collision shapes")
		return

	var road_items := 0
	var shape_count := 0
	var shadow_disabled_items := 0
	for item_id in library.get_item_list():
		var item_name := library.get_item_name(item_id).to_lower()
		if item_name in NO_SHADOW_ITEMS:
			library.set_item_mesh_cast_shadow(item_id, RenderingServer.SHADOW_CASTING_SETTING_OFF)
			shadow_disabled_items += 1
		var source_name := _collision_source_name(item_name)
		if source_name.is_empty():
			continue
		var source: Array = collision_sources.get(source_name, [])
		if source.size() != 2:
			_fail("Missing collision source %s" % source_name)
			return
		var source_shape := source[0] as Shape3D
		var shape_transform: Transform3D = source[1]
		if source_shape == null:
			_fail("Invalid collision source %s" % source_name)
			return
		var embedded_shape := source_shape.duplicate(true) as Shape3D
		library.set_item_shapes(item_id, [embedded_shape, shape_transform])
		road_items += 1
		shape_count += 1

	print("[MeshLibraryBuild] Saving compressed binary runtime library...")
	var flags := ResourceSaver.FLAG_COMPRESS | ResourceSaver.FLAG_OMIT_EDITOR_PROPERTIES
	var error := ResourceSaver.save(library, OUTPUT_PATH, flags)
	if error != OK:
		_fail("Could not save %s (error %d)" % [OUTPUT_PATH, error])
		return

	var elapsed := float(Time.get_ticks_msec() - started_msec) / 1000.0
	print("[MeshLibraryBuild] Embedded %d wall shapes across %d road items" % [shape_count, road_items])
	print("[MeshLibraryBuild] Disabled shadows on %d dense decoration items" % shadow_disabled_items)
	print("[MeshLibraryBuild] Saved %s in %.2f s" % [OUTPUT_PATH, elapsed])
	quit(0)


func _collision_source_name(item_name: String) -> String:
	match item_name:
		"road-corner":
			return "track-corner"
		"track-finish", "track-straight":
			return "track-straight"
		_:
			return ""


func _read_collision_sources(source_text: String) -> Dictionary:
	if source_text.is_empty():
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
		return {}
	return {
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


func _fail(message: String) -> void:
	push_error("[MeshLibraryBuild] %s" % message)
	quit(1)
