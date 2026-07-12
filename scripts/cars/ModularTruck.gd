@tool
extends Node3D
## Editor-visible truck assembly. The imported source keeps its stock wheels,
## but they are hidden so the editable Wheel* pivots are the only visible set.


func _ready() -> void:
	call_deferred("_hide_stock_wheels")


func _hide_stock_wheels() -> void:
	var chassis := get_node_or_null("Chassis")
	if chassis == null:
		return
	for child in chassis.get_children():
		if str(child.name).to_lower().begins_with("wheel-"):
			_set_visual_visibility(child, false)


func _set_visual_visibility(node: Node, is_visible: bool) -> void:
	if node is VisualInstance3D:
		(node as VisualInstance3D).visible = is_visible
	for child in node.get_children():
		_set_visual_visibility(child, is_visible)
