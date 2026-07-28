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
const GARAGE_BACKGROUND := preload("res://assets/ui/garage/garage-background.jpg")

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
var _display_font: Font


func _ready() -> void:
	_display_font = GameStyle.DISPLAY_FONT
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
	RenderingServer.set_default_clear_color(Color.TRANSPARENT)
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_CANVAS
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("f0c8b8")
	env.ambient_light_energy = 0.86
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.environment = env
	add_child(environment)

	var camera := Camera3D.new()
	camera.position = Vector3(0.0, 5.25, 12.4)
	camera.fov = 44.0
	camera.look_at_from_position(camera.position, Vector3(0.0, 0.62, -1.55), Vector3.UP)
	add_child(camera)

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-52.0, -34.0, 0.0)
	key.light_energy = 1.15
	key.light_color = Color("ffe6d1")
	key.shadow_enabled = false
	add_child(key)

	var rim := OmniLight3D.new()
	rim.position = Vector3(-4.8, 3.2, -2.2)
	rim.light_color = MAGENTA
	rim.light_energy = 4.2
	rim.omni_range = 9.0
	add_child(rim)

	var warm := OmniLight3D.new()
	warm.position = Vector3(4.7, 3.0, -1.0)
	warm.light_color = Color("ff9a57")
	warm.light_energy = 4.8
	warm.omni_range = 10.0
	add_child(warm)


func _build_ui() -> void:
	var background_layer := CanvasLayer.new()
	background_layer.layer = -10
	add_child(background_layer)
	var background := TextureRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.texture = GARAGE_BACKGROUND
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background_layer.add_child(background)

	var vignette := ColorRect.new()
	vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vignette.color = Color(0.02, 0.01, 0.03, 0.1)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background_layer.add_child(vignette)

	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	_canvas = Control.new()
	_canvas.size = DESIGN_SIZE
	_canvas.custom_minimum_size = DESIGN_SIZE
	layer.add_child(_canvas)

	# --- Top banner: thin glass bar, doesn't fight the hangar photo ---
	var top := PanelContainer.new()
	top.position = Vector2(28, 18)
	top.size = Vector2(1224, 56)
	top.add_theme_stylebox_override("panel", _glass_panel(Color(0.04, 0.045, 0.06, 0.72), MAGENTA, 2))
	_canvas.add_child(top)
	var top_margin := MarginContainer.new()
	top_margin.add_theme_constant_override("margin_left", 18)
	top_margin.add_theme_constant_override("margin_right", 16)
	top_margin.add_theme_constant_override("margin_top", 8)
	top_margin.add_theme_constant_override("margin_bottom", 8)
	top.add_child(top_margin)
	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 18)
	top_margin.add_child(top_row)

	var brand_col := VBoxContainer.new()
	brand_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	brand_col.add_theme_constant_override("separation", -4)
	top_row.add_child(brand_col)
	brand_col.add_child(_label("PULSE  ·  VEHICLE BAY", 11, CYAN))
	brand_col.add_child(_label("GARAGE", 28, Color("faf5e6")))

	var hint := _label("DRAG  ·  ← →  INSPECT", 12, Color("9fdfe6"))
	hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	top_row.add_child(hint)

	# --- Roster: compact glass cards with car accent bar ---
	var roster := HBoxContainer.new()
	roster.position = Vector2(28, 86)
	roster.size = Vector2(1224, 64)
	roster.add_theme_constant_override("separation", 12)
	_canvas.add_child(roster)
	for vehicle_id in VehicleCatalog.get_all_ids():
		var entry := VehicleCatalog.get_vehicle(vehicle_id)
		var accent: Color = entry.get("minimap_color", MAGENTA) as Color
		var button := Button.new()
		button.focus_mode = Control.FOCUS_NONE
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size = Vector2(0, 64)
		button.text = ""
		button.pressed.connect(_browse_vehicle.bind(vehicle_id))
		roster.add_child(button)

		var margin := MarginContainer.new()
		margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		margin.add_theme_constant_override("margin_left", 12)
		margin.add_theme_constant_override("margin_right", 12)
		margin.add_theme_constant_override("margin_top", 10)
		margin.add_theme_constant_override("margin_bottom", 10)
		button.add_child(margin)
		var card_row := HBoxContainer.new()
		card_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card_row.add_theme_constant_override("separation", 10)
		margin.add_child(card_row)
		var accent_bar := ColorRect.new()
		accent_bar.custom_minimum_size = Vector2(4, 0)
		accent_bar.color = accent
		accent_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card_row.add_child(accent_bar)
		var card_copy := VBoxContainer.new()
		card_copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card_copy.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card_copy.add_theme_constant_override("separation", 0)
		card_row.add_child(card_copy)
		var name_l := _label(str(entry.get("display_name", vehicle_id)).to_upper(), 18, Color("faf5e6"))
		name_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card_copy.add_child(name_l)
		var role_l := _label(str(entry.get("role", "")).to_upper(), 11, accent.lightened(0.2))
		role_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card_copy.add_child(role_l)

		_vehicle_buttons[vehicle_id] = {
			"button": button,
			"accent": accent,
			"name_label": name_l,
			"role_label": role_l,
		}
		_apply_roster_card(button, accent, false)

	# --- Bottom dossier ---
	var info := PanelContainer.new()
	info.position = Vector2(28, 556)
	info.size = Vector2(1224, 144)
	info.add_theme_stylebox_override("panel", _glass_panel(Color(0.03, 0.035, 0.045, 0.82), Color("3a444c"), 2))
	_canvas.add_child(info)
	var info_margin := MarginContainer.new()
	info_margin.add_theme_constant_override("margin_left", 22)
	info_margin.add_theme_constant_override("margin_right", 18)
	info_margin.add_theme_constant_override("margin_top", 14)
	info_margin.add_theme_constant_override("margin_bottom", 14)
	info.add_child(info_margin)
	var info_row := HBoxContainer.new()
	info_row.add_theme_constant_override("separation", 28)
	info_margin.add_child(info_row)

	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.add_theme_constant_override("separation", 3)
	info_row.add_child(copy)

	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 12)
	copy.add_child(title_row)
	_title = _label("RAVAGE", 28, MAGENTA)
	title_row.add_child(_title)
	_role = _label("ARMORED SURVIVOR", 13, CYAN)
	_role.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_row.add_child(_role)

	copy.add_child(_label("SPECIAL ABILITY", 10, Color("8a949c")))
	_ability_title = _label("REINFORCED HULL", 15, Color("f5eee3"))
	copy.add_child(_ability_title)
	_ability_description = _body_label("", 14, Color("c2c8cc"))
	_ability_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	copy.add_child(_ability_description)

	var action_column := VBoxContainer.new()
	action_column.custom_minimum_size.x = 320
	action_column.add_theme_constant_override("separation", 8)
	info_row.add_child(action_column)

	_status = _label("", 13, Color("d0d6da"))
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	action_column.add_child(_status)

	_progress = ProgressBar.new()
	_progress.custom_minimum_size = Vector2(320, 10)
	_progress.show_percentage = false
	_progress.add_theme_stylebox_override("background", _progress_track())
	_progress.add_theme_stylebox_override("fill", _progress_fill(PURPLE))
	action_column.add_child(_progress)

	_select_button = Button.new()
	_select_button.text = "SELECT VEHICLE"
	_select_button.custom_minimum_size = Vector2(320, 42)
	_select_button.focus_mode = Control.FOCUS_NONE
	_apply_primary_button(_select_button, MAGENTA, true)
	_select_button.pressed.connect(_confirm_selection)
	action_column.add_child(_select_button)

	var back := Button.new()
	back.text = "BACK TO SETUP"
	back.custom_minimum_size = Vector2(320, 34)
	back.focus_mode = Control.FOCUS_NONE
	_apply_secondary_button(back)
	back.pressed.connect(func() -> void: get_tree().change_scene_to_file(SETUP_SCENE))
	action_column.add_child(back)

	if OS.is_debug_build():
		var unlock_all := Button.new()
		unlock_all.text = "DEBUG: UNLOCK ALL"
		unlock_all.position = Vector2(1020, 164)
		unlock_all.size = Vector2(232, 34)
		unlock_all.focus_mode = Control.FOCUS_NONE
		_apply_secondary_button(unlock_all)
		unlock_all.add_theme_color_override("font_color", CYAN)
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
	var accent: Color = entry.get("minimap_color", MAGENTA) as Color
	_title.text = str(entry.get("display_name", _browsed_id)).to_upper()
	_title.add_theme_color_override("font_color", accent)
	_role.text = str(entry.get("role", "")).to_upper()
	_role.add_theme_color_override("font_color", accent.lightened(0.2))
	_ability_title.text = str(entry.get("ability_title", "")).to_upper()
	_ability_description.text = str(entry.get("ability_description", ""))
	var unlocked := GarageProfile.is_vehicle_unlocked(_browsed_id)
	var selected := GarageProfile.selected_vehicle_id() == _browsed_id
	var current := GarageProfile.unlock_progress(_browsed_id)
	var target := GarageProfile.unlock_target(_browsed_id)
	_progress.max_value = maxf(float(target), 1.0)
	_progress.value = float(target if unlocked else mini(current, target))
	_progress.visible = not unlocked
	_progress.add_theme_stylebox_override("fill", _progress_fill(accent))
	if unlocked:
		_status.text = "●  EQUIPPED" if selected else "●  READY TO RACE"
		_status.add_theme_color_override("font_color", accent if selected else Color("9dffb0"))
	else:
		_status.text = "LOCKED  ·  %s  ·  %d / %d" % [
			VehicleCatalog.unlock_requirement_text(_browsed_id),
			current,
			target,
		]
		_status.add_theme_color_override("font_color", Color("c4a070"))
	_select_button.disabled = not unlocked or selected
	_select_button.text = (
		"EQUIPPED"
		if selected
		else ("LOCKED" if not unlocked else "SELECT VEHICLE")
	)
	_apply_primary_button(_select_button, accent, unlocked and not selected)
	for vehicle_id in _vehicle_buttons:
		var data: Dictionary = _vehicle_buttons[vehicle_id]
		var button := data.get("button") as Button
		var card_accent: Color = data.get("accent", MAGENTA) as Color
		var is_browsed: bool = vehicle_id == _browsed_id
		_apply_roster_card(button, card_accent, is_browsed)
		var name_l := data.get("name_label") as Label
		if name_l:
			name_l.add_theme_color_override(
				"font_color",
				Color("ffffff") if is_browsed else Color("ece8e0")
			)
	_refresh_display_positions()


func _refresh_display_positions() -> void:
	var ordered := VehicleCatalog.get_all_ids()
	for vehicle_id in ordered:
		var pivot := _display_pivots.get(vehicle_id) as Node3D
		if pivot == null:
			continue
		var is_browsed: bool = vehicle_id == _browsed_id
		pivot.visible = is_browsed
		if is_browsed:
			pivot.position = Vector3(0.0, 0.0, -0.35)
			pivot.scale = Vector3.ONE * 2.35
			pivot.rotation = Vector3.ZERO
			_set_shadow_recursive(pivot, true)
			_set_transparency_recursive(pivot, 0.0)


func _set_shadow_recursive(node: Node, enabled: bool) -> void:
	if node is GeometryInstance3D:
		(node as GeometryInstance3D).cast_shadow = (
			GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			if enabled
			else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		)
	for child in node.get_children():
		_set_shadow_recursive(child, enabled)


func _set_transparency_recursive(node: Node, amount: float) -> void:
	if node is GeometryInstance3D:
		(node as GeometryInstance3D).transparency = amount
	for child in node.get_children():
		_set_transparency_recursive(child, amount)


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
	GameStyle.apply_label(label, color, font_size)
	label.add_theme_font_override("font", _display_font)
	label.add_theme_color_override("font_outline_color", Color("020405"))
	label.add_theme_constant_override("outline_size", maxi(int(font_size * 0.18), 3))
	return label


func _body_label(text_value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text_value
	GameStyle.apply_label(label, color, font_size)
	return label


func _glass_panel(bg: Color, border: Color, border_w: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(border_w)
	style.set_corner_radius_all(6)
	style.content_margin_left = 4
	style.content_margin_right = 4
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	style.shadow_color = Color(0, 0, 0, 0.45)
	style.shadow_size = 8
	style.shadow_offset = Vector2(0, 3)
	return style


func _progress_track() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.09, 0.1, 0.9)
	style.border_color = Color("2a3238")
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	return style


func _progress_fill(accent: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = accent
	style.set_corner_radius_all(2)
	return style


func _apply_roster_card(button: Button, accent: Color, selected: bool) -> void:
	var border := accent if selected else Color(0.35, 0.38, 0.42, 0.85)
	var bg := (
		Color(accent.r * 0.18, accent.g * 0.14, accent.b * 0.16, 0.78)
		if selected
		else Color(0.05, 0.055, 0.07, 0.68)
	)
	var style_n := _glass_panel(bg, border, 2 if selected else 1)
	style_n.content_margin_left = 0
	style_n.content_margin_right = 0
	style_n.content_margin_top = 0
	style_n.content_margin_bottom = 0
	var style_h := style_n.duplicate() as StyleBoxFlat
	style_h.bg_color = Color(accent.r * 0.24, accent.g * 0.18, accent.b * 0.2, 0.85)
	style_h.border_color = accent.lightened(0.1)
	style_h.set_border_width_all(2)
	var style_p := style_n.duplicate() as StyleBoxFlat
	style_p.bg_color = bg.darkened(0.12)
	button.add_theme_stylebox_override("normal", style_n)
	button.add_theme_stylebox_override("hover", style_h)
	button.add_theme_stylebox_override("pressed", style_p)
	button.add_theme_stylebox_override("focus", style_h)
	button.add_theme_color_override("font_color", Color.TRANSPARENT)
	button.add_theme_color_override("font_hover_color", Color.TRANSPARENT)
	button.add_theme_color_override("font_pressed_color", Color.TRANSPARENT)


func _apply_primary_button(button: Button, accent: Color, enabled_look: bool) -> void:
	var normal_bg := accent.darkened(0.06) if enabled_look else Color(0.16, 0.17, 0.19, 0.9)
	var style_n := StyleBoxFlat.new()
	style_n.bg_color = normal_bg
	style_n.border_color = Color(0.1, 0.09, 0.08) if enabled_look else Color("34383a")
	style_n.set_border_width_all(2)
	style_n.set_corner_radius_all(5)
	style_n.content_margin_left = 16
	style_n.content_margin_right = 16
	style_n.content_margin_top = 10
	style_n.content_margin_bottom = 10
	style_n.shadow_color = Color(0, 0, 0, 0.5)
	style_n.shadow_size = 5
	style_n.shadow_offset = Vector2(2, 3)
	var style_h := style_n.duplicate() as StyleBoxFlat
	style_h.bg_color = accent.lightened(0.12) if enabled_look else normal_bg.lightened(0.08)
	var style_p := style_n.duplicate() as StyleBoxFlat
	style_p.bg_color = accent.darkened(0.2) if enabled_look else normal_bg.darkened(0.1)
	var style_d := style_n.duplicate() as StyleBoxFlat
	style_d.bg_color = Color(0.14, 0.15, 0.16, 0.85)
	style_d.border_color = Color("2e3336")
	button.add_theme_stylebox_override("normal", style_n)
	button.add_theme_stylebox_override("hover", style_h)
	button.add_theme_stylebox_override("pressed", style_p)
	button.add_theme_stylebox_override("disabled", style_d)
	button.add_theme_stylebox_override("focus", style_h)
	button.add_theme_font_override("font", _display_font)
	button.add_theme_font_size_override("font_size", 18)
	button.add_theme_color_override("font_color", Color("12141a") if enabled_look else Color("8a8e92"))
	button.add_theme_color_override("font_hover_color", Color("0a0c10"))
	button.add_theme_color_override("font_pressed_color", Color("050608"))
	button.add_theme_color_override("font_disabled_color", Color("6a6e72"))


func _apply_secondary_button(button: Button) -> void:
	var style_n := _glass_panel(Color(0.08, 0.09, 0.11, 0.78), Color("4a545c"), 1)
	style_n.content_margin_left = 14
	style_n.content_margin_right = 14
	style_n.content_margin_top = 8
	style_n.content_margin_bottom = 8
	var style_h := style_n.duplicate() as StyleBoxFlat
	style_h.border_color = CYAN
	style_h.bg_color = Color(0.08, 0.12, 0.14, 0.88)
	var style_p := style_n.duplicate() as StyleBoxFlat
	style_p.bg_color = Color(0.05, 0.06, 0.07, 0.9)
	button.add_theme_stylebox_override("normal", style_n)
	button.add_theme_stylebox_override("hover", style_h)
	button.add_theme_stylebox_override("pressed", style_p)
	button.add_theme_stylebox_override("focus", style_h)
	button.add_theme_font_override("font", _display_font)
	button.add_theme_font_size_override("font_size", 15)
	button.add_theme_color_override("font_color", Color("d8dde0"))
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color("b8c0c4"))
