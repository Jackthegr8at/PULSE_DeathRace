extends SceneTree

const SOURCE_SCENE: String = "res://models/Library/mesh-library.tscn"
const OUTPUT_LIBRARY: String = "res://models/Library/mesh-library.tres"

func _init() -> void:
	var packed := load(SOURCE_SCENE) as PackedScene
	if packed == null:
		push_error("Could not load %s" % SOURCE_SCENE)
		quit(1)
		return

	var source := packed.instantiate()
	var library := MeshLibrary.new()
	library.create_from_scene(source)
	var error := ResourceSaver.save(library, OUTPUT_LIBRARY)
	if error != OK:
		push_error("Could not save %s: %s" % [OUTPUT_LIBRARY, error_string(error)])
		quit(1)
		return

	print("Rebuilt %s with %d items" % [OUTPUT_LIBRARY, library.get_item_list().size()])
	quit()
