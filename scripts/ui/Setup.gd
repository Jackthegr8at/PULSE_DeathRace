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
var _lap_count: int = 5
var _crate_count: int = 5
var _missiles_per_crate: int = 2

var _canvas: Control
var _display_font: SystemFont
var _mode_buttons: Dictionary = {}
var _track_buttons: Dictionary = {}
var _focus_buttons: Array[Button] = []
var _lap_value: Label
var _crate_value: Label
var _ammo_value: Label
var _ai_badge_value: Label
var _opponents_value: Label
var _race_type_value: Label
var _crates_state_value: Label
var _preview_image: TextureRect


func _ready() -> void:
	_selected_mode = MatchConfig.mode
	_selected_track = MatchConfig.track_id
	_lap_count = MatchConfig.lap_count
	_crate_count = MatchConfig.crate_count
	_missiles_per_crate = MatchConfig.missiles_per_crate
	_create_font()
	_build_screen()
	resized.connect(_fit_canvas)
	call_deferred("_fit_canvas")
	call_deferred("_focus_initial_control")
	_refresh_all()


func _create_font() -> void:
	_display_font = SystemFont.new()
	_display_font.font_names = PackedStringArray(["Impact", "Bahnschrift Condensed", "Arial Narrow", "Arial"])
	_display_font.font_weight = 700


func _build_screen() -> void:
	for child in get_children():
		child.free()
	_mode_buttons.clear()
	_track_buttons.clear()
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
	_crate_value = _value_label("CrateValue", Vector2(372, 703), Vector2(49, 48), 29, YELLOW)
	_crate_value.pivot_offset = _crate_value.size * 0.5
	_crate_value.rotation_degrees = 1
	_ammo_value = _value_label("AmmoValue", Vector2(372, 784), Vector2(49, 48), 29, YELLOW)
	_ai_badge_value = _value_label("AiBadgeValue", Vector2(1379, 45), Vector2(34, 36), 27, Color.WHITE)
	_opponents_value = _value_label("OpponentsValue", Vector2(990, 726), Vector2(36, 42), 32, PURPLE)
	_opponents_value.pivot_offset = _opponents_value.size * 0.5
	_opponents_value.rotation_degrees = 1
	_race_type_value = _value_label("RaceTypeValue", Vector2(684, 716), Vector2(124, 38), 27, CYAN, HORIZONTAL_ALIGNMENT_LEFT)
	_race_type_value.pivot_offset = _race_type_value.size * 0.5
	_race_type_value.rotation_degrees = 1
	_crates_state_value = _value_label("CratesStateValue", Vector2(1260, 732), Vector2(94, 38), 27, YELLOW, HORIZONTAL_ALIGNMENT_LEFT)


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

	var laps_enabled := _selected_mode != MatchConfig.Mode.LAST_STANDING
	_lap_value.text = str(_lap_count) if laps_enabled else "—"
	_lap_value.modulate = Color.WHITE if laps_enabled else Color(1, 1, 1, 0.4)
	(_canvas.get_node("LapsMinus") as Button).disabled = not laps_enabled
	(_canvas.get_node("LapsPlus") as Button).disabled = not laps_enabled
	_crate_value.text = str(_crate_count)
	_ammo_value.text = str(_missiles_per_crate)
	_ai_badge_value.text = str(MatchConfig.ai_count)
	_opponents_value.text = str(MatchConfig.ai_count)
	_crates_state_value.text = "LIVE" if _crate_count > 0 else "OFF"

	match _selected_mode:
		MatchConfig.Mode.HYBRID:
			_race_type_value.text = "COMBAT"
		MatchConfig.Mode.RACE:
			_race_type_value.text = "RACE"
		MatchConfig.Mode.LAST_STANDING:
			_race_type_value.text = "SURVIVE"

	_preview_image.texture = STARTER_PREVIEW if _selected_track == MatchConfig.TrackId.KENNEY_DEFAULT else FIGURE8_PREVIEW


func _paint_choice(button: Button, selected: bool) -> void:
	var accent: Color = button.get_meta("accent") as Color
	button.add_theme_stylebox_override("normal", _highlight_style(accent, 0.20, 3) if selected else StyleBoxEmpty.new())
	button.add_theme_stylebox_override("hover", _highlight_style(accent, 0.14, 2))
	button.add_theme_stylebox_override("focus", _highlight_style(accent, 0.14, 2))
	button.add_theme_stylebox_override("pressed", _highlight_style(accent, 0.28, 3))


func _select_mode(mode: MatchConfig.Mode) -> void:
	_selected_mode = mode
	_refresh_all()


func _select_track(track: MatchConfig.TrackId) -> void:
	_selected_track = track
	_refresh_all()


func _change_laps(delta: int) -> void:
	if _selected_mode == MatchConfig.Mode.LAST_STANDING:
		return
	_lap_count = clampi(_lap_count + delta, 1, 99)
	_refresh_all()


func _change_crate_count(delta: int) -> void:
	_crate_count = clampi(_crate_count + delta, 0, 24)
	_refresh_all()


func _change_missiles_per_crate(delta: int) -> void:
	_missiles_per_crate = clampi(_missiles_per_crate + delta, 1, 5)
	_refresh_all()


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
	MatchConfig.mode = _selected_mode
	MatchConfig.track_id = _selected_track
	if _selected_mode != MatchConfig.Mode.LAST_STANDING:
		MatchConfig.lap_count = _lap_count
	MatchConfig.crate_count = _crate_count
	MatchConfig.missiles_per_crate = _missiles_per_crate
	get_tree().change_scene_to_file("res://scenes/race/Race3D.tscn")
