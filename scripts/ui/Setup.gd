extends Control
## Responsive pre-race setup screen. The supplied artwork is the frame; Godot
## only provides the live preview, values, selection states, and hit targets.

const DESIGN_SIZE := Vector2(1536.0, 1024.0)
const SETUP_BACKGROUND: Texture2D = preload("res://assets/ui/setup/setup-background.png")
const SETUP_OVERLAY: Texture2D = preload("res://assets/ui/setup/setup-overlay.png")
const OFFICIAL_LOGO: Texture2D = preload("res://assets/ui/setup/logo_officiel.png")
const STARTER_PREVIEW: Texture2D = preload("res://assets/concept/starter-circuit-preview.png")
const FIGURE8_PREVIEW: Texture2D = preload("res://assets/concept/figure8-preview.png")

const CYAN := Color("00dbe8")
const PURPLE := Color("a62cff")
const YELLOW := Color("ffc20b")

var _selected_mode: MatchConfig.Mode = MatchConfig.Mode.HYBRID
var _selected_track: MatchConfig.TrackId = MatchConfig.TrackId.KENNEY_DEFAULT
var _selected_ai_difficulty: MatchConfig.AIDifficulty = MatchConfig.AIDifficulty.NOVICE
var _lap_count: int = 5
var _ai_count: int = 3
var _crate_count: int = 5
var _last_live_crate_count: int = 5
var _missiles_per_crate: int = 2

var _canvas: Control
var _display_font: Font
var _mode_buttons: Dictionary = {}
var _track_buttons: Dictionary = {}
var _difficulty_buttons: Dictionary = {}
var _difficulty_highlights: Dictionary = {}
var _focus_buttons: Array[Button] = []
var _lap_value: Label
var _practice_warning: Label
var _crate_value: Label
var _ammo_value: Label
var _ai_badge_value: Label
var _ai_count_value: Label
var _crates_state_value: Label
var _preview_image: TextureRect
var _selected_vehicle_value: Label
var _selected_drone_value: Label
var _drone_panel_highlight: CanvasItem
var _garage_panel_highlight: CanvasItem
var _crates_panel_highlight: CanvasItem


func _ready() -> void:
	_selected_mode = MatchConfig.mode
	_selected_track = MatchConfig.track_id
	_selected_ai_difficulty = MatchConfig.ai_difficulty
	_lap_count = MatchConfig.lap_count
	_ai_count = clampi(MatchConfig.ai_count, 1, 7)
	_crate_count = MatchConfig.crate_count
	_last_live_crate_count = maxi(MatchConfig.last_live_crate_count, 1)
	if _crate_count > 0:
		_last_live_crate_count = _crate_count
	_missiles_per_crate = MatchConfig.missiles_per_crate
	_create_font()
	_build_screen()
	resized.connect(_fit_canvas)
	call_deferred("_fit_canvas")
	call_deferred("_focus_initial_control")
	_refresh_all()


func _create_font() -> void:
	_display_font = GameStyle.DISPLAY_FONT


func _build_screen() -> void:
	for child in get_children():
		child.free()
	_mode_buttons.clear()
	_track_buttons.clear()
	_difficulty_buttons.clear()
	_difficulty_highlights.clear()
	_focus_buttons.clear()

	var backdrop := TextureRect.new()
	backdrop.name = "Backdrop"
	backdrop.texture = SETUP_BACKGROUND
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)

	var tint := ColorRect.new()
	tint.name = "BackdropTint"
	tint.color = Color(0.005, 0.012, 0.016, 0.23)
	tint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tint)

	_canvas = Control.new()
	_canvas.name = "SetupCanvas1536x1024"
	_canvas.size = DESIGN_SIZE
	_canvas.custom_minimum_size = DESIGN_SIZE
	add_child(_canvas)

	# This image sits below the transparent preview aperture in the overlay.
	_preview_image = TextureRect.new()
	_preview_image.name = "TrackPreviewImage"
	_preview_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_preview_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_preview_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Overscan beneath the artwork so rounding at non-native resolutions can
	# never expose the background around the transparent preview aperture.
	_place(_preview_image, Vector2(560, 235), Vector2(935, 450))
	_canvas.add_child(_preview_image)

	var overlay := TextureRect.new()
	overlay.name = "SetupArtwork"
	overlay.texture = SETUP_OVERLAY
	overlay.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	overlay.stretch_mode = TextureRect.STRETCH_SCALE
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(overlay, Vector2.ZERO, DESIGN_SIZE)
	_canvas.add_child(overlay)

	_build_logo()
	_build_choice_targets()
	_build_stepper_targets()
	_build_dynamic_values()
	_build_top_match_controls()
	_build_ai_difficulty_selector()
	_build_drone_bay_target()
	_build_garage_target()
	_build_start_target()
	_wire_focus_order()


func _build_logo() -> void:
	var logo := TextureRect.new()
	logo.name = "OfficialLogo"
	logo.texture = OFFICIAL_LOGO
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# The logo belongs to the scaled canvas, so it follows the available upper-left
	# corner at every aspect ratio instead of being pinned to viewport pixels.
	_place(logo, Vector2(24, 14), Vector2(500, 132))
	_canvas.add_child(logo)


func _build_choice_targets() -> void:
	_add_choice_target("ModeHybrid", Vector2(139, 257), Vector2(116, 69), CYAN, _select_mode.bind(MatchConfig.Mode.HYBRID), _mode_buttons, MatchConfig.Mode.HYBRID)
	_add_choice_target("ModeRace", Vector2(263, 257), Vector2(108, 69), CYAN, _select_mode.bind(MatchConfig.Mode.RACE), _mode_buttons, MatchConfig.Mode.RACE)
	_add_choice_target("ModeLastStanding", Vector2(381, 257), Vector2(108, 69), CYAN, _select_mode.bind(MatchConfig.Mode.LAST_STANDING), _mode_buttons, MatchConfig.Mode.LAST_STANDING)
	_add_choice_target("TrackStarter", Vector2(139, 440), Vector2(191, 79), PURPLE, _select_track.bind(MatchConfig.TrackId.KENNEY_DEFAULT), _track_buttons, MatchConfig.TrackId.KENNEY_DEFAULT)
	_add_choice_target("TrackFigure8", Vector2(340, 440), Vector2(151, 79), PURPLE, _select_track.bind(MatchConfig.TrackId.FIGURE_8), _track_buttons, MatchConfig.TrackId.FIGURE_8)


func _add_choice_target(name_text: String, at: Vector2, dimensions: Vector2, accent: Color, action: Callable, registry: Dictionary, key: Variant) -> void:
	var button := _transparent_button(name_text, at, dimensions)
	button.set_meta("accent", accent)
	button.pressed.connect(action)
	_canvas.add_child(button)
	registry[key] = button
	_focus_buttons.append(button)


func _build_stepper_targets() -> void:
	_add_stepper_target("LapsMinus", Vector2(313, 627), _change_laps.bind(-1))
	_add_stepper_target("LapsPlus", Vector2(433, 627), _change_laps.bind(1))
	_add_stepper_target("CratesMinus", Vector2(313, 702), _change_crate_count.bind(-1))
	_add_stepper_target("CratesPlus", Vector2(433, 702), _change_crate_count.bind(1))
	_add_stepper_target("AmmoMinus", Vector2(313, 777), _change_missiles_per_crate.bind(-1))
	_add_stepper_target("AmmoPlus", Vector2(433, 777), _change_missiles_per_crate.bind(1))


func _add_stepper_target(name_text: String, at: Vector2, action: Callable) -> void:
	var button := _transparent_button(name_text, at, Vector2(45, 48))
	button.pressed.connect(action)
	button.add_theme_stylebox_override("hover", _highlight_style(YELLOW, 0.16, 2))
	button.add_theme_stylebox_override("focus", _highlight_style(YELLOW, 0.16, 2))
	button.add_theme_stylebox_override("pressed", _highlight_style(YELLOW, 0.28, 3))
	_canvas.add_child(button)
	_focus_buttons.append(button)


func _build_dynamic_values() -> void:
	_lap_value = _value_label("LapValue", Vector2(372, 621), Vector2(49, 48), 29, YELLOW)
	_practice_warning = _value_label(
		"PracticeWarning",
		Vector2(126, 532),
		Vector2(370, 30),
		18,
		YELLOW
	)
	_practice_warning.text = "PRACTICE RACE - REWARDS DISABLED"
	_crate_value = _value_label("CrateValue", Vector2(372, 703), Vector2(49, 48), 29, YELLOW)
	_crate_value.pivot_offset = _crate_value.size * 0.5
	_crate_value.rotation_degrees = 1
	_ammo_value = _value_label("AmmoValue", Vector2(372, 784), Vector2(49, 48), 29, YELLOW)
	# The badge artwork already contains "AI". Keep the dynamic count in the
	# open area to its right instead of letting the glyphs overlap.
	_ai_badge_value = _value_label("AiBadgeValue", Vector2(1411, 52), Vector2(30, 36), 27, Color.WHITE)


func _build_top_match_controls() -> void:
	var ai_heading := _value_label("AiCountHeading", Vector2(870, 35), Vector2(92, 29), 19, Color.WHITE)
	ai_heading.text = "AI"
	_ai_count_value = _value_label("AiCountValue", Vector2(891, 61), Vector2(52, 38), 30, CYAN)
	_add_top_stepper_target("AiCountMinus", "−", Vector2(830, 62), _change_ai_count.bind(-1))
	_add_top_stepper_target("AiCountPlus", "+", Vector2(958, 62), _change_ai_count.bind(1))

	var crates_toggle := _transparent_button("CratesToggle", Vector2(1027, 28), Vector2(247, 87))
	_crates_panel_highlight = _create_polygon_highlight(
		_canvas,
		"CratesPanelHighlight",
		Vector2(1028, 29),
		YELLOW,
		PackedVector2Array([
			Vector2(18, 8), Vector2(224, 9), Vector2(234, 18),
			Vector2(230, 67), Vector2(220, 75), Vector2(18, 74), Vector2(9, 64), Vector2(11, 20),
		])
	)
	_bind_fitted_highlight(crates_toggle, _crates_panel_highlight)
	crates_toggle.pressed.connect(_toggle_crates)
	_canvas.add_child(crates_toggle)
	_focus_buttons.append(crates_toggle)
	var crates_heading := _value_label("CratesToggleHeading", Vector2(1094, 36), Vector2(154, 27), 18, Color.WHITE)
	crates_heading.text = "CRATES"
	_crates_state_value = _value_label("CratesStateValue", Vector2(1094, 62), Vector2(154, 38), 28, YELLOW)


func _build_ai_difficulty_selector() -> void:
	var panel := _angled_panel_root("AiDifficultyPanel", Vector2(554, 684), Vector2(286, 102), 1.0)
	var heading := _panel_label(panel, "AiDifficultyHeading", Vector2(12, 7), Vector2(260, 29), 21, CYAN)
	heading.text = "AI DIFFICULTY"
	_add_difficulty_target(panel, "DifficultyNovice", "NOVICE", Vector2(14, 43), MatchConfig.AIDifficulty.NOVICE)
	_add_difficulty_target(panel, "DifficultyMedium", "MEDIUM", Vector2(98, 43), MatchConfig.AIDifficulty.MEDIUM)
	_add_difficulty_target(panel, "DifficultyHard", "HARD", Vector2(182, 43), MatchConfig.AIDifficulty.HARD)


func _build_garage_target() -> void:
	var panel := _angled_panel_root("GaragePanel", Vector2(1126, 684), Vector2(280, 104), 1.0)
	_garage_panel_highlight = _create_polygon_highlight(panel, "GaragePanelHighlight", Vector2.ZERO, CYAN, _panel_polygon(panel.size))
	var garage := _transparent_button("Garage", Vector2.ZERO, panel.size)
	_bind_fitted_highlight(garage, _garage_panel_highlight)
	garage.pressed.connect(_on_garage_pressed)
	panel.add_child(garage)
	_focus_buttons.append(garage)
	var heading := _panel_label(panel, "GarageHeading", Vector2(14, 12), Vector2(252, 32), 27, Color.WHITE)
	heading.text = "GARAGE"
	_selected_vehicle_value = _panel_label(
		panel,
		"SelectedVehicle",
		Vector2(14, 51),
		Vector2(252, 32),
		20,
		CYAN
	)


func _build_drone_bay_target() -> void:
	var panel := _angled_panel_root("DronePanel", Vector2(844, 683), Vector2(276, 104), 1.0)
	_drone_panel_highlight = _create_polygon_highlight(panel, "DronePanelHighlight", Vector2.ZERO, PURPLE, _panel_polygon(panel.size))
	var drone_bay := _transparent_button("DroneBay", Vector2.ZERO, panel.size)
	_bind_fitted_highlight(drone_bay, _drone_panel_highlight)
	drone_bay.pressed.connect(_on_drone_bay_pressed)
	panel.add_child(drone_bay)
	_focus_buttons.append(drone_bay)
	var heading := _panel_label(panel, "DroneBayHeading", Vector2(13, 12), Vector2(250, 32), 27, Color.WHITE)
	heading.text = "DRONE"
	_selected_drone_value = _panel_label(
		panel,
		"SelectedDrone",
		Vector2(13, 51),
		Vector2(250, 32),
		20,
		PURPLE
	)


func _add_difficulty_target(panel: Control, name_text: String, label_text: String, at: Vector2, difficulty: MatchConfig.AIDifficulty) -> void:
	var highlight := _create_polygon_highlight(
		panel,
		"%sHighlight" % name_text,
		at,
		CYAN,
		PackedVector2Array([Vector2(7, 5), Vector2(70, 6), Vector2(74, 11), Vector2(70, 41), Vector2(8, 40), Vector2(4, 35), Vector2(5, 11)])
	)
	var button := _transparent_button(name_text, at, Vector2(78, 48))
	button.text = label_text
	button.add_theme_font_override("font", _display_font)
	button.add_theme_font_size_override("font_size", 20)
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_color_override("font_hover_color", CYAN)
	button.add_theme_color_override("font_focus_color", CYAN)
	button.add_theme_color_override("font_pressed_color", CYAN)
	button.add_theme_color_override("font_outline_color", Color("020405"))
	button.add_theme_constant_override("outline_size", 4)
	button.set_meta("accent", CYAN)
	button.pressed.connect(_select_ai_difficulty.bind(difficulty))
	button.mouse_entered.connect(_show_difficulty_highlight.bind(difficulty))
	button.mouse_exited.connect(_refresh_difficulty_highlights)
	button.focus_entered.connect(_show_difficulty_highlight.bind(difficulty))
	button.focus_exited.connect(_refresh_difficulty_highlights)
	panel.add_child(button)
	_difficulty_buttons[difficulty] = button
	_difficulty_highlights[difficulty] = highlight
	_focus_buttons.append(button)


func _add_top_stepper_target(name_text: String, label_text: String, at: Vector2, action: Callable) -> void:
	var button := _transparent_button(name_text, at, Vector2(52, 38))
	button.text = label_text
	button.add_theme_font_override("font", _display_font)
	button.add_theme_font_size_override("font_size", 27)
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_color_override("font_hover_color", CYAN)
	button.add_theme_color_override("font_focus_color", CYAN)
	button.add_theme_color_override("font_pressed_color", CYAN)
	button.add_theme_color_override("font_outline_color", Color("020405"))
	button.add_theme_constant_override("outline_size", 4)
	button.pressed.connect(action)
	_canvas.add_child(button)
	_focus_buttons.append(button)


func _angled_panel_root(name_text: String, at: Vector2, dimensions: Vector2, angle_degrees: float) -> Control:
	var panel := Control.new()
	panel.name = name_text
	_place(panel, at, dimensions)
	panel.pivot_offset = dimensions * 0.5
	panel.rotation_degrees = angle_degrees
	_canvas.add_child(panel)
	return panel


func _panel_label(
	panel: Control,
	name_text: String,
	at: Vector2,
	dimensions: Vector2,
	font_size: int,
	color: Color
) -> Label:
	var label := Label.new()
	label.name = name_text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", _display_font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color("020405"))
	label.add_theme_constant_override("outline_size", 4)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(label, at, dimensions)
	panel.add_child(label)
	return label


func _panel_polygon(dimensions: Vector2) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(17, 8),
		Vector2(dimensions.x - 17, 9),
		Vector2(dimensions.x - 9, 17),
		Vector2(dimensions.x - 12, dimensions.y - 18),
		Vector2(dimensions.x - 20, dimensions.y - 10),
		Vector2(18, dimensions.y - 11),
		Vector2(10, dimensions.y - 19),
		Vector2(11, 17),
	])


func _create_polygon_highlight(
	parent: Node,
	name_text: String,
	at: Vector2,
	accent: Color,
	points: PackedVector2Array
) -> CanvasItem:
	var group := Node2D.new()
	group.name = name_text
	group.position = at
	group.visible = false

	var fill := Polygon2D.new()
	fill.polygon = points
	fill.color = Color(accent.r, accent.g, accent.b, 0.075)
	group.add_child(fill)

	var border := Line2D.new()
	border.points = points
	border.closed = true
	border.width = 1.5
	border.default_color = Color(accent.r, accent.g, accent.b, 0.72)
	border.antialiased = true
	group.add_child(border)

	parent.add_child(group)
	return group


func _bind_fitted_highlight(button: Button, highlight: CanvasItem) -> void:
	button.mouse_entered.connect(func() -> void: highlight.visible = true)
	button.mouse_exited.connect(func() -> void: highlight.visible = button.has_focus())
	button.focus_entered.connect(func() -> void: highlight.visible = true)
	button.focus_exited.connect(func() -> void: highlight.visible = button.is_hovered())


func _show_difficulty_highlight(difficulty: MatchConfig.AIDifficulty) -> void:
	for key in _difficulty_highlights:
		(_difficulty_highlights[key] as CanvasItem).visible = int(key) == int(difficulty)


func _refresh_difficulty_highlights() -> void:
	for key in _difficulty_highlights:
		var button := _difficulty_buttons[key] as Button
		var selected := int(key) == int(_selected_ai_difficulty)
		(_difficulty_highlights[key] as CanvasItem).visible = selected or button.is_hovered() or button.has_focus()


func _value_label(name_text: String, at: Vector2, dimensions: Vector2, font_size: int, color: Color, alignment: HorizontalAlignment = HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var label := Label.new()
	label.name = name_text
	label.horizontal_alignment = alignment
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", _display_font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color("020405"))
	label.add_theme_constant_override("outline_size", 4)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(label, at, dimensions)
	_canvas.add_child(label)
	return label


func _build_start_target() -> void:
	var start := _transparent_button("StartRace", Vector2(953, 876), Vector2(555, 119))
	start.pressed.connect(_on_start_pressed)
	_canvas.add_child(start)
	_focus_buttons.append(start)


func _transparent_button(name_text: String, at: Vector2, dimensions: Vector2) -> Button:
	var button := Button.new()
	button.name = name_text
	button.text = ""
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var empty := StyleBoxEmpty.new()
	button.add_theme_stylebox_override("normal", empty)
	button.add_theme_stylebox_override("hover", empty)
	button.add_theme_stylebox_override("focus", empty)
	button.add_theme_stylebox_override("pressed", empty)
	_place(button, at, dimensions)
	return button


func _highlight_style(accent: Color, alpha: float, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(accent.r, accent.g, accent.b, alpha)
	style.border_color = Color(accent.r, accent.g, accent.b, minf(alpha * 3.5, 1.0))
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(5)
	return style


func _refresh_all() -> void:
	for mode in _mode_buttons:
		_paint_choice(_mode_buttons[mode] as Button, mode == _selected_mode)
	for track in _track_buttons:
		_paint_choice(_track_buttons[track] as Button, track == _selected_track)
	for difficulty in _difficulty_buttons:
		var difficulty_button := _difficulty_buttons[difficulty] as Button
		var selected: bool = int(difficulty) == int(_selected_ai_difficulty)
		var empty := StyleBoxEmpty.new()
		difficulty_button.add_theme_stylebox_override("normal", empty)
		difficulty_button.add_theme_stylebox_override("hover", empty)
		difficulty_button.add_theme_stylebox_override("focus", empty)
		difficulty_button.add_theme_stylebox_override("pressed", empty)
		difficulty_button.add_theme_color_override("font_color", CYAN if selected else Color.WHITE)
	_refresh_difficulty_highlights()

	var laps_enabled := _selected_mode != MatchConfig.Mode.LAST_STANDING
	_lap_value.text = str(_lap_count) if laps_enabled else "—"
	_lap_value.modulate = Color.WHITE if laps_enabled else Color(1, 1, 1, 0.4)
	_practice_warning.visible = laps_enabled and _lap_count == 1
	(_canvas.get_node("LapsMinus") as Button).disabled = not laps_enabled
	(_canvas.get_node("LapsPlus") as Button).disabled = not laps_enabled
	_crate_value.text = str(_crate_count)
	_ammo_value.text = str(_missiles_per_crate)
	_ai_badge_value.text = str(_ai_count)
	_ai_count_value.text = str(_ai_count)
	_crates_state_value.text = "LIVE" if _crate_count > 0 else "OFF"
	_crates_state_value.add_theme_color_override("font_color", YELLOW if _crate_count > 0 else Color("849095"))

	_preview_image.texture = STARTER_PREVIEW if _selected_track == MatchConfig.TrackId.KENNEY_DEFAULT else FIGURE8_PREVIEW
	if is_instance_valid(_selected_vehicle_value):
		var selected_entry := VehicleCatalog.get_vehicle(GarageProfile.selected_vehicle_id())
		_selected_vehicle_value.text = str(selected_entry.get("display_name", "RAVAGE")).to_upper()
	if is_instance_valid(_selected_drone_value):
		var equipped := GarageProfile.equipped_drone()
		if str(equipped.get("id", "")).is_empty():
			_selected_drone_value.text = "NO DRONE EQUIPPED"
		else:
			var drone := DroneCatalog.get_drone(str(equipped.get("id", "")))
			_selected_drone_value.text = "%s  T%d" % [
				str(drone.get("display_name", "DRONE")).to_upper(),
				int(equipped.get("tier", 0)),
			]


func _paint_choice(button: Button, selected: bool) -> void:
	var accent: Color = button.get_meta("accent") as Color
	var normal_style: StyleBox
	if selected:
		normal_style = _highlight_style(accent, 0.20, 3)
	else:
		normal_style = StyleBoxEmpty.new()
	button.add_theme_stylebox_override("normal", normal_style)
	button.add_theme_stylebox_override("hover", _highlight_style(accent, 0.14, 2))
	button.add_theme_stylebox_override("focus", _highlight_style(accent, 0.14, 2))
	button.add_theme_stylebox_override("pressed", _highlight_style(accent, 0.28, 3))


func _select_mode(mode: MatchConfig.Mode) -> void:
	_selected_mode = mode
	_refresh_all()
	_store_match_settings()


func _select_track(track: MatchConfig.TrackId) -> void:
	_selected_track = track
	_refresh_all()
	_store_match_settings()


func _select_ai_difficulty(difficulty: MatchConfig.AIDifficulty) -> void:
	_selected_ai_difficulty = difficulty
	_refresh_all()
	_store_match_settings()


func _change_laps(delta: int) -> void:
	if _selected_mode == MatchConfig.Mode.LAST_STANDING:
		return
	_lap_count = clampi(_lap_count + delta, 1, 99)
	_refresh_all()
	_store_match_settings()


func _change_crate_count(delta: int) -> void:
	_crate_count = clampi(_crate_count + delta, 0, 24)
	if _crate_count > 0:
		_last_live_crate_count = _crate_count
	_refresh_all()
	_store_match_settings()


func _change_ai_count(delta: int) -> void:
	_ai_count = clampi(_ai_count + delta, 1, 7)
	_refresh_all()
	_store_match_settings()


func _toggle_crates() -> void:
	if _crate_count > 0:
		_last_live_crate_count = _crate_count
		_crate_count = 0
	else:
		_crate_count = clampi(_last_live_crate_count, 1, 24)
	_refresh_all()
	_store_match_settings()


func _change_missiles_per_crate(delta: int) -> void:
	_missiles_per_crate = clampi(_missiles_per_crate + delta, 1, 5)
	_refresh_all()
	_store_match_settings()


func _fit_canvas() -> void:
	if not is_instance_valid(_canvas):
		return
	var available := size
	if available.x <= 0.0 or available.y <= 0.0:
		available = Vector2(get_viewport_rect().size)
	var fit_scale: float = minf(available.x / DESIGN_SIZE.x, available.y / DESIGN_SIZE.y)
	fit_scale = maxf(fit_scale, 0.01)
	_canvas.scale = Vector2.ONE * fit_scale
	_canvas.position = (available - DESIGN_SIZE * fit_scale) * 0.5


func _wire_focus_order() -> void:
	if _focus_buttons.is_empty():
		return
	for index in _focus_buttons.size():
		var current := _focus_buttons[index]
		var previous := _focus_buttons[(index - 1 + _focus_buttons.size()) % _focus_buttons.size()]
		var next := _focus_buttons[(index + 1) % _focus_buttons.size()]
		current.focus_neighbor_top = current.get_path_to(previous)
		current.focus_neighbor_left = current.get_path_to(previous)
		current.focus_previous = current.get_path_to(previous)
		current.focus_neighbor_bottom = current.get_path_to(next)
		current.focus_neighbor_right = current.get_path_to(next)
		current.focus_next = current.get_path_to(next)


func _focus_initial_control() -> void:
	var initial := _mode_buttons.get(_selected_mode) as Button
	if is_instance_valid(initial):
		initial.grab_focus()


func _place(control: Control, at: Vector2, dimensions: Vector2) -> void:
	control.position = at
	control.size = dimensions
	control.custom_minimum_size = dimensions


func _on_start_pressed() -> void:
	_store_match_settings()
	MatchConfig.begin_race_loading()
	get_tree().change_scene_to_file("res://scenes/LoadingScreen.tscn")


func _on_garage_pressed() -> void:
	_store_match_settings()
	get_tree().change_scene_to_file("res://scenes/Garage.tscn")


func _on_drone_bay_pressed() -> void:
	_store_match_settings()
	get_tree().change_scene_to_file("res://scenes/DroneBay.tscn")


func _store_match_settings() -> void:
	MatchConfig.mode = _selected_mode
	MatchConfig.track_id = _selected_track
	MatchConfig.ai_difficulty = _selected_ai_difficulty
	MatchConfig.ai_count = _ai_count
	if _selected_mode != MatchConfig.Mode.LAST_STANDING:
		MatchConfig.lap_count = _lap_count
	MatchConfig.crate_count = _crate_count
	MatchConfig.last_live_crate_count = _last_live_crate_count
	MatchConfig.missiles_per_crate = _missiles_per_crate
	MatchConfig.save_match_settings()
