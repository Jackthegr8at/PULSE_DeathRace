extends SceneTree
## Reports base-mesh triangles for imported 3D scenes passed after `--`.


func _initialize() -> void:
	var paths := OS.get_cmdline_user_args()
	if paths.is_empty():
		push_error("Pass one or more res:// scene paths after --")
		quit(1)
		return
	for path in paths:
		_report_scene(path)
	quit(0)


func _report_scene(path: String) -> void:
	var packed := load(path) as PackedScene
	if packed == null:
		push_error("Could not load %s" % path)
		return
	var root := packed.instantiate()
	var instance_triangles := 0
	var unique_triangles := 0
	var mesh_instances := 0
	var unique_meshes: Dictionary = {}
	var pending: Array[Node] = [root]
	while not pending.is_empty():
		var node: Node = pending.pop_back() as Node
		for child in node.get_children():
			pending.append(child)
		if node is not MeshInstance3D:
			continue
		var mesh := (node as MeshInstance3D).mesh
		if mesh == null:
			continue
		mesh_instances += 1
		var triangles := _mesh_triangles(mesh)
		instance_triangles += triangles
		var mesh_id := mesh.get_instance_id()
		if not unique_meshes.has(mesh_id):
			unique_meshes[mesh_id] = true
			unique_triangles += triangles
	print("%s | instances=%d unique_meshes=%d instance_triangles=%d unique_triangles=%d" % [
		path,
		mesh_instances,
		unique_meshes.size(),
		instance_triangles,
		unique_triangles,
	])
	root.free()


func _mesh_triangles(mesh: Mesh) -> int:
	var total := 0
	for surface_id in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(surface_id)
		var vertices = arrays[Mesh.ARRAY_VERTEX]
		var indices = arrays[Mesh.ARRAY_INDEX]
		total += (indices.size() / 3) if indices.size() > 0 else (vertices.size() / 3)
	return total
