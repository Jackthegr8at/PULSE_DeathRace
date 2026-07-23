extends Node3D
## Lightweight live-3D garage. It loads vehicle visuals only: no track,
## Vehicle physics, AI, missiles, or race HUD.

const SETUP_SCENE := "res://scenes/Setup.tscn"
const CYAN := Color("00dbe8")
const MAGENTA := Color("ef1459")
const PURPLE := Color("a62cff")
const YELLOW := Color("ffc20b")
const DESIGN_SIZE := Vector2(1280.0, 720.0)
const DISPLAY_FLOOR_Y := -0.055

var _browsed_id: String = VehicleCatalog.DEFAULT_VEHICLE_ID
var _models: Dictionary = {}
var _display_pivots: Dictionary = {}
var _canvas: Control
var _title: Label
var _role: Label
var _ability_title: Label
var _ability_description: Label
var _status: Label
var _progress: ProgressBar
var _select_button: Button
var _vehicle_buttons: Dictionary = {}
var _dragging: bool = false
var _last_mouse_x: float = 0.0


func _ready() -> void:
	_browsed_id = GarageProfile.selected_vehicle_id()
	_build_world()
	_build_ui()
	_load_vehicle_displays()
	_refresh_selection()
	get_viewport().size_changed.connect(_fit_canvas)
	call_deferred("_fit_canvas")


func _input(event: InputEvent) -> void:
	# Left/right is reserved for inspecting the central car. Consume these
	# events before Control nodes can also use them for focus navigation.
	if (
		event.is_action_pressed("ui_left")
		or event.is_action_released("ui_left")
		or event.is_action_pressed("ui_right")
		or event.is_action_released("ui_right")
	):
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	var rotate_input := Input.get_axis("ui_left", "ui_right")
	if absf(rotate_input) > 0.05:
		_rotate_central(-rotate_input * delta * 1.8)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().change_scene_to_file(SETUP_SCENE)
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging = event.pressed
		_last_mouse_x = event.position.x
	elif event is InputEventMouseMotion and _dragging:
		var delta_x: float = event.position.x - _last_mouse_x
		_last_mouse_x = event.position.x
		_rotate_central(-delta_x * 0.008)


func _build_world() -> void:
	RenderingServer.set_default_clear_color(Color("080c10"))
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("0b1116")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("92b3c1")
	env.ambient_light_energy = 0.72
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.environment = env
	add_child(environment)

	var floor := MeshInstance3D.new()
	var floor_mesh := BoxMesh.new()
	floor_mesh.size = Vector3(20.0, 0.22, 12.0)
	floor.mesh = floor_mesh
	floor.position.y = -0.18
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color("111820")
	floor_material.metallic = 0.72
	floor_material.roughness = 0.38
	floor.material_override = floor_material
	add_child(floor)

	for x in [-6.0, -2.0, 2.0, 6.0]:
		var stripe := MeshInstance3D.new()
		var stripe_mesh := BoxMesh.new()
		stripe_mesh.size = Vector3(0.04, 0.018, 10.5)
		stripe.mesh = stripe_mesh
		stripe.position = Vector3(x, -0.055, 0.0)
		var stripe_material := StandardMaterial3D.new()
		stripe_material.albedo_color = Color(0.0, 0.86, 0.91, 0.18)
		stripe_material.emission_enabled = true
		stripe_material.emission = Color(0.0, 0.86, 0.91, 0.28)
		stripe.material_override = stripe_material
		add_child(stripe)

	var camera := Camera3D.new()
	camera.position = Vector3(0.0, 5.9, 10.8)
	camera.fov = 48.0
	camera.look_at_from_position(camera.position, Vector3(0.0, 0.65, -0.8), Vector3.UP)
	add_child(camera)

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-52.0, -34.0, 0.0)
	key.light_energy = 1.35
	key.light_color = Color("dbefff")
	key.shadow_enabled = true
	add_child(key)

	var rim := OmniLight3D.new()
	rim.position = Vector3(-4.5, 3.5, -1.5)
	rim.light_color = CYAN
	rim.light_energy = 8.0
	rim.omni_range = 10.0
	add_child(rim)

	var warm := OmniLight3D.new()
	warm.position = Vector3(4.5, 2.7, 0.5)
	warm.light_color = MAGENTA
	warm.light_energy = 6.0
	warm.omni_range = 9.0
	add_child(warm)


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_canvas = Control.new()
	_canvas.size = DESIGN_SIZE
	_canvas.custom_minimum_size = DESIGN_SIZE
	layer.add_child(_canvas)

	var top := PanelContainer.new()
	top.position = Vector2(28, 24)
	top.size = Vector2(1224, 82)
	top.add_theme_stylebox_override("panel", GameStyle.panel(Color(0.01, 0.025, 0.032, 0.92), CYAN, 8, 2))
	_canvas.add_child(top)
	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 18)
	top.add_child(top_row)
	var heading := _label("PULSE GARAGE", 38, Color.WHITE)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(heading)
	var hint := _label("DRAG OR USE LEFT / RIGHT TO INSPECT", 16, CYAN)
	hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	top_row.add_child(hint)

	var roster := HBoxContainer.new()
	roster.position = Vector2(28, 120)
	roster.size = Vector2(1224, 58)
	roster.add_theme_constant_override("separation", 10)
	_canvas.add_child(roster)
	for vehicle_id in VehicleCatalog.get_all_ids():
		var entry := VehicleCatalog.get_vehicle(vehicle_id)
		var button := Button.new()
		button.text = str(entry.get("display_name", vehicle_id))
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.focus_mode = Control.FOCUS_NONE
		button.add_theme_font_override("font", GameStyle.DISPLAY_FONT)
		button.add_theme_font_size_override("font_size", 20)
		GameStyle.apply_button(button, GameStyle.button_ghost())
		button.pressed.connect(_browse_vehicle.bind(vehicle_id))
		roster.add_child(button)
		_vehicle_buttons[vehicle_id] = button

	var info := PanelContainer.new()
	info.position = Vector2(28, 488)
	info.size = Vector2(1224, 202)
	info.add_theme_stylebox_override("panel", GameStyle.panel(Color(0.006, 0.018, 0.024, 0.94), Color("414e55"), 8, 2))
	_canvas.add_child(info)
	var info_row := HBoxContainer.new()
	info_row.add_theme_constant_override("separation", 24)
	info.add_child(info_row)

	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.add_theme_constant_override("separation", 4)
	info_row.add_child(copy)
	_title = _label("RAVAGE", 36, YELLOW)
	copy.add_child(_title)
	_role = _label("ARMORED SURVIVOR", 17, CYAN)
	copy.add_child(_role)
	_ability_title = _label("REINFORCED HULL", 20, Color.WHITE)
	copy.add_child(_ability_title)
	_ability_description = _body_label("", 16, Color("bdc8cb"))
	_ability_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	copy.add_child(_ability_description)

	var action_column := VBoxContainer.new()
	action_column.custom_minimum_size.x = 390
	action_column.add_theme_constant_override("separation", 8)
	info_row.add_child(action_column)
	_status = _label("", 17, PURPLE)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	action_column.add_child(_status)
	_progress = ProgressBar.new()
	_progress.custom_minimum_size = Vector2(390, 18)
	_progress.show_percentage = false
	_progress.add_theme_stylebox_override("background", GameStyle.panel(Color("11191c"), Color("39454a"), 4, 1))
	_progress.add_theme_stylebox_override("fill", GameStyle.panel(PURPLE, PURPLE, 4, 0))
	action_column.add_child(_progress)
	_select_button = Button.new()
	_select_button.text = "SELECT VEHICLE"
	_select_button.custom_minimum_size = Vector2(390, 48)
	GameStyle.apply_button(_select_button, GameStyle.button_primary())
	_select_button.pressed.connect(_confirm_selection)
	action_column.add_child(_select_button)
	var back := Button.new()
	back.text = "BACK TO SETUP"
	back.custom_minimum_size = Vector2(390, 40)
	GameStyle.apply_button(back, GameStyle.button_ghost())
	back.pressed.connect(func() -> void: get_tree().change_scene_to_file(SETUP_SCENE))
	action_column.add_child(back)

	if OS.is_debug_build():
		var unlock_all := Button.new()
		unlock_all.text = "DEBUG: UNLOCK ALL"
		unlock_all.position = Vector2(1030, 188)
		unlock_all.size = Vector2(222, 34)
		GameStyle.apply_button(unlock_all, GameStyle.button_ghost())
		unlock_all.pressed.connect(_debug_unlock_all)
		_canvas.add_child(unlock_all)


func _load_vehicle_displays() -> void:
	var positions := [
		Vector3(0.0, 0.0, -1.0),
		Vector3(-5.0, 0.0, -2.2),
		Vector3(5.0, 0.0, -2.2),
		Vector3(0.0, 0.0, -5.0),
	]
	for index in VehicleCatalog.get_all_ids().size():
		var vehicle_id := VehicleCatalog.get_all_ids()[index]
		var entry := VehicleCatalog.get_vehicle(vehicle_id)
		var packed := load(str(entry.get("scene_path", ""))) as PackedScene
		if packed == null:
			push_error("Garage: could not load %s" % vehicle_id)
			continue
		var pivot := Node3D.new()
		pivot.name = "%sDisplay" % vehicle_id.capitalize()
		pivot.position = positions[index]
		add_child(pivot)
		var model := packed.instantiate() as Node3D
		if model == null:
			continue
		pivot.add_child(model)
		_prepare_presentation(model, index != 0)
		_models[vehicle_id] = model
		_display_pivots[vehicle_id] = pivot
	await get_tree().process_frame
	_normalize_vehicle_displays()
	_refresh_display_positions()


func _normalize_vehicle_displays() -> void:
	var reference_pivot := _display_pivots.get(VehicleCatalog.DEFAULT_VEHICLE_ID) as Node3D
	if reference_pivot == null:
		return
	var reference_bounds := _visual_bounds_in_pivot(reference_pivot)
	var target_footprint := maxf(reference_bounds.size.x, reference_bounds.size.z)
	if target_footprint <= 0.001:
		return

	for vehicle_id in VehicleCatalog.get_all_ids():
		var pivot := _display_pivots.get(vehicle_id) as Node3D
		var model := _models.get(vehicle_id) as Node3D
		if pivot == null or model == null:
			continue
		var bounds := _visual_bounds_in_pivot(pivot)
		var footprint := maxf(bounds.size.x, bounds.size.z)
		if footprint <= 0.001:
			continue

		model.scale *= target_footprint / footprint
		var normalized_bounds := _visual_bounds_in_pivot(pivot)
		var center := normalized_bounds.get_center()
		var entry := VehicleCatalog.get_vehicle(vehicle_id)
		model.position += Vector3(
			-center.x,
			DISPLAY_FLOOR_Y
			- normalized_bounds.position.y
			+ float(entry.get("garage_y_offset", 0.0)),
			-center.z
		)


func _visual_bounds_in_pivot(pivot: Node3D) -> AABB:
	var merged := AABB()
	var has_bounds := false
	var pivot_inverse := pivot.global_transform.affine_inverse()
	for descendant in pivot.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := descendant as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null:
			continue
		var relative_transform := pivot_inverse * mesh_instance.global_transform
		var transformed_bounds := relative_transform * mesh_instance.get_aabb()
		if not has_bounds:
			merged = transformed_bounds
			has_bounds = true
		else:
			merged = merged.merge(transformed_bounds)
	return merged


func _prepare_presentation(node: Node, disable_shadows: bool) -> void:
	node.process_mode = Node.PROCESS_MODE_DISABLED
	if node is CollisionObject3D:
		(node as CollisionObject3D).collision_layer = 0
		(node as CollisionObject3D).collision_mask = 0
	if node is AudioStreamPlayer3D:
		(node as AudioStreamPlayer3D).stream = null
	if node is GeometryInstance3D and disable_shadows:
		(node as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for child in node.get_children():
		_prepare_presentation(child, disable_shadows)


func _browse_vehicle(vehicle_id: String) -> void:
	if not VehicleCatalog.has_vehicle(vehicle_id):
		return
	_browsed_id = vehicle_id
	_refresh_selection()


func _refresh_selection() -> void:
	var entry := VehicleCatalog.get_vehicle(_browsed_id)
	_title.text = str(entry.get("display_name", _browsed_id)).to_upper()
	_role.text = str(entry.get("role", "")).to_upper()
	_ability_title.text = str(entry.get("ability_title", "")).to_upper()
	_ability_description.text = str(entry.get("ability_description", ""))
	var unlocked := GarageProfile.is_vehicle_unlocked(_browsed_id)
	var selected := GarageProfile.selected_vehicle_id() == _browsed_id
	var current := GarageProfile.unlock_progress(_browsed_id)
	var target := GarageProfile.unlock_target(_browsed_id)
	_progress.max_value = maxf(float(target), 1.0)
	_progress.value = float(target if unlocked else mini(current, target))
	_progress.visible = not unlocked
	if unlocked:
		_status.text = "SELECTED" if selected else "READY"
	else:
		_status.text = "%s  •  %d / %d" % [
			VehicleCatalog.unlock_requirement_text(_browsed_id),
			current,
			target,
		]
	_select_button.disabled = not unlocked or selected
	_select_button.text = "SELECTED" if selected else ("LOCKED" if not unlocked else "SELECT VEHICLE")
	for vehicle_id in _vehicle_buttons:
		var button := _vehicle_buttons[vehicle_id] as Button
		var is_browsed: bool = vehicle_id == _browsed_id
		button.add_theme_color_override("font_color", CYAN if is_browsed else Color.WHITE)
		button.add_theme_stylebox_override(
			"normal",
			GameStyle.button_selected() if is_browsed else GameStyle.button_normal()
		)
	_refresh_display_positions()


func _refresh_display_positions() -> void:
	var ordered := VehicleCatalog.get_all_ids()
	var stall_positions := [
		Vector3(-5.0, 0.0, -2.6),
		Vector3(5.0, 0.0, -2.6),
		Vector3(0.0, 0.0, -5.5),
	]
	var stall_index := 0
	for vehicle_id in ordered:
		var pivot := _display_pivots.get(vehicle_id) as Node3D
		if pivot == null:
			continue
		if vehicle_id == _browsed_id:
			pivot.position = Vector3(0.0, 0.0, -0.55)
			pivot.scale = Vector3.ONE * 1.48
			pivot.rotation = Vector3.ZERO
			_set_shadow_recursive(pivot, true)
		else:
			pivot.position = stall_positions[stall_index]
			pivot.scale = Vector3.ONE * 0.82
			pivot.rotation = Vector3(0.0, 0.0, 0.0)
			_set_shadow_recursive(pivot, false)
			stall_index += 1


func _set_shadow_recursive(node: Node, enabled: bool) -> void:
	if node is GeometryInstance3D:
		(node as GeometryInstance3D).cast_shadow = (
			GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			if enabled
			else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		)
	for child in node.get_children():
		_set_shadow_recursive(child, enabled)


func _rotate_central(amount: float) -> void:
	var pivot := _display_pivots.get(_browsed_id) as Node3D
	if pivot:
		pivot.rotate_y(amount)


func _confirm_selection() -> void:
	if GarageProfile.select_vehicle(_browsed_id):
		_refresh_selection()


func _debug_unlock_all() -> void:
	GarageProfile.set_debug_unlock_all(true)
	_refresh_selection()


func _fit_canvas() -> void:
	if not is_instance_valid(_canvas):
		return
	var viewport_size := Vector2(get_viewport().get_visible_rect().size)
	var fit := minf(viewport_size.x / DESIGN_SIZE.x, viewport_size.y / DESIGN_SIZE.y)
	_canvas.scale = Vector2.ONE * maxf(fit, 0.01)
	_canvas.position = (viewport_size - DESIGN_SIZE * _canvas.scale) * 0.5


func _label(text_value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text_value
	GameStyle.apply_display_label(label, color, font_size)
	label.add_theme_color_override("font_outline_color", Color("020405"))
	label.add_theme_constant_override("outline_size", 4)
	return label


func _body_label(text_value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text_value
	GameStyle.apply_label(label, color, font_size)
	return label
