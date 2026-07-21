extends SceneTree

const LIBRARY_PATH := "res://models/Library/mesh-library-runtime.res"


func _initialize() -> void:
	var library := load(LIBRARY_PATH) as MeshLibrary
	if library == null:
		push_error("Could not load %s" % LIBRARY_PATH)
		quit(1)
		return
	var triangle_counts: Dictionary = {}
	for item_id in library.get_item_list():
		var mesh := library.get_item_mesh(item_id)
		var vertices := 0
		var triangles := 0
		var surfaces := 0
		if mesh != null:
			surfaces = mesh.get_surface_count()
			for surface_id in surfaces:
				var arrays := mesh.surface_get_arrays(surface_id)
				var vertex_array = arrays[Mesh.ARRAY_VERTEX]
				var index_array = arrays[Mesh.ARRAY_INDEX]
				vertices += vertex_array.size()
				triangles += (index_array.size() / 3) if index_array.size() > 0 else (vertex_array.size() / 3)
		triangle_counts[item_id] = triangles
		print("%d | %s | surfaces=%d vertices=%d triangles=%d shadow=%d" % [
			item_id,
			library.get_item_name(item_id),
			surfaces,
			vertices,
			triangles,
			library.get_item_mesh_cast_shadow(item_id),
		])
	quit(0)
