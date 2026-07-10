class_name Track3DBase
extends Node3D
## Base for Kenney GridMap tracks. Exposes spawn for Race3D.

@export var track_display_name: String = "Track"


func get_spawn_transform() -> Transform3D:
	var marker := get_node_or_null("SpawnPoint") as Marker3D
	if marker:
		return marker.global_transform
	return global_transform


func get_grid_map() -> GridMap:
	return get_node_or_null("GridMap") as GridMap
