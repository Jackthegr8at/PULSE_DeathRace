extends Control
## Responsive pre-race command screen built on a fixed 1536x1024 art canvas.

const DESIGN_SIZE := Vector2(1536.0, 1024.0)
const SETUP_BACKGROUND: Texture2D = preload("res://assets/ui/setup/setup-background.png")
const SETUP_REFERENCE: Texture2D = preload("res://assets/ui/setup/setup-reference.png")
const STARTER_PREVIEW: Texture2D = preload("res://assets/concept/starter-circuit-preview.png")
const FIGURE8_PREVIEW: Texture2D = preload("res://assets/concept/figure8-preview.png")

var _selected_mode: MatchConfig.Mode = MatchConfig.Mode.HYBRID
var _selected_track: MatchConfig.TrackId = MatchConfig.TrackId.KENNEY_DEFAULT
var _lap_count: int = 5
var _crate_count: int = 5
var _missiles_per_crate: int = 2

var _canvas: Control
var _display_font: SystemFont
var _body_font: SystemFont
var _mode_buttons: Dictionary = {}
var _track_buttons: Dictionary = {}
var _focus_buttons: Array[Button] = []
var _lap_value: Label
var _lap_minus: Button
var _lap_plus: Button
var _crate_value: Label
var _ammo_value: Label
var _mode_detail: Label
var _preview_title: Label
var _preview_image: TextureRect
var _preview_note: Label
var _race_type_value: Label


func _ready() -> void:
	_selected_mode = MatchConfig.mode
	_selected_track = MatchConfig.track_id
	_lap_count = MatchConfig.lap_count
	_crate_count = MatchConfig.crate_count
	_missiles_per_crate = MatchConfig.missiles_per_crate
	_create_fonts()
	_build_screen()
	resized.connect(_fit_canvas)
	call_deferred("_fit_canvas")
	call_deferred("_focus_initial_control")
	_refresh_all()


func _create_fonts() -> void:
	_display_font = SystemFont.new()
	_display_font.font_names = PackedStringArray(["Impact", "Bahnschrift Condensed", "Arial Narrow", "Arial"])
	_display_font.font_weight = 700
	_body_font = SystemFont.new()
	_body_font.font_names = PackedStringArray(["Bahnschrift", "Arial", "Noto Sans"])
	_body_font.font_weight = 600


func _build_screen() -> void:
	for child in get_children():
		child.free()

	var backdrop := TextureRect.new()
	backdrop.name = "Backdrop"
	backdrop.texture = SETUP_BACKGROUND
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)

	var backdrop_tint := ColorRect.new()
	backdrop_tint.name = "BackdropTint"
	backdrop_tint.color = Color(0.01, 0.018, 0.022, 0.30)
	backdrop_tint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop_tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop_tint)

	_canvas = Control.new()
	_canvas.name = "SetupCanvas1536x1024"
	_canvas.size = DESIGN_SIZE
	_canvas.custom_minimum_size = DESIGN_SIZE
	_canvas.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_canvas)

	var reference_art := TextureRect.new()
	reference_art.name = "ReferenceArt"
	reference_art.texture = SETUP_REFERENCE
	reference_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	reference_art.stretch_mode = TextureRect.STRETCH_SCALE
	reference_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(reference_art, Vector2.ZERO, DESIGN_SIZE)
	_canvas.add_child(reference_art)

	_build_live_control_panel()
	_build_live_briefing_panel()
	_build_start_hit_target()
	_wire_focus_order()


func _build_live_control_panel() -> void:
	var panel := PanelContainer.new()
	panel.name = "LiveSetupControls"
	panel.add_theme_stylebox_override("panel", GameStyle.setup_panel(Color("071117"), Color("513a25"), 3))
	_place(panel, Vector2(41, 275), Vector2(466, 578))
	_canvas.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 7)
	margin.add_child(stack)

	stack.add_child(_section_title("⚔  MATCH MODE", GameStyle.SETUP_CYAN))
	var mode_row := HBoxContainer.new()
	mode_row.custom_minimum_size = Vector2(0, 64)
	mode_row.add_theme_constant_override("separation", 8)
	stack.add_child(mode_row)
	_add_mode_button(mode_row, MatchConfig.Mode.HYBRID, "HYBRID")
	_add_mode_button(mode_row, MatchConfig.Mode.RACE, "RACE")
	_add_mode_button(mode_row, MatchConfig.Mode.LAST_STANDING, "LAST\nSTANDING")

	_mode_detail = _make_label("", 14, Color("d5d7d5"))
	_mode_detail.custom_minimum_size = Vector2(0, 42)
	_mode_detail.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_mode_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(_mode_detail)
	stack.add_child(_divider(GameStyle.SETUP_EDGE))

	stack.add_child(_section_title("⚑  TRACK", GameStyle.SETUP_PURPLE))
	var track_row := HBoxContainer.new()
	track_row.custom_minimum_size = Vector2(0, 64)
	track_row.add_theme_constant_override("separation", 8)
	stack.add_child(track_row)
	_add_track_button(track_row, MatchConfig.TrackId.KENNEY_DEFAULT, "STARTER CIRCUIT")
	_add_track_button(track_row, MatchConfig.TrackId.FIGURE_8, "FIGURE-8\nCHAOS")

	stack.add_child(_divider(GameStyle.SETUP_EDGE))
	stack.add_child(_section_title("⚠  RACE RULES", GameStyle.SETUP_YELLOW))
	stack.add_child(_build_stepper("⚑", "LAPS", "laps", _change_laps))
	stack.add_child(_build_stepper("▣", "MISSILE CRATES", "crates", _change_crate_count))
	stack.add_child(_build_stepper("➤", "MISSILES / CRATE", "ammo", _change_missiles_per_crate))


func _build_live_briefing_panel() -> void:
	var title_panel := PanelContainer.new()
	title_panel.name = "LiveTrackTitle"
	title_panel.add_theme_stylebox_override("panel", GameStyle.setup_panel(Color("081218"), Color("443326"), 3))
	_place(title_panel, Vector2(554, 229), Vector2(934, 63))
	_canvas.add_child(title_panel)

	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 18)
	title_panel.add_child(title_row)
	_preview_title = _make_label("", 38, Color("f1f0e8"), true)
	_preview_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_preview_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_row.add_child(_preview_title)
	var slashes := _make_label("///", 42, GameStyle.SETUP_CYAN, true)
	slashes.custom_minimum_size = Vector2(140, 0)
	slashes.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	slashes.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_row.add_child(slashes)

	var preview_frame := PanelContainer.new()
	preview_frame.name = "LiveTrackPreview"
	var preview_style := GameStyle.setup_panel(Color("050b0e"), GameStyle.SETUP_YELLOW, 3)
	preview_style.content_margin_left = 5
	preview_style.content_margin_right = 5
	preview_style.content_margin_top = 5
	preview_style.content_margin_bottom = 5
	preview_frame.add_theme_stylebox_override("panel", preview_style)
	_place(preview_frame, Vector2(568, 297), Vector2(906, 417))
	_canvas.add_child(preview_frame)

	_preview_image = TextureRect.new()
	_preview_image.name = "TrackPreviewImage"
	_preview_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_preview_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_preview_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_frame.add_child(_preview_image)

	var metrics := HBoxContainer.new()
	metrics.name = "LiveMetrics"
	metrics.add_theme_constant_override("separation", 10)
	_place(metrics, Vector2(568, 704), Vector2(838, 92))
	_canvas.add_child(metrics)
	var race_metric := _metric_card("☠", "RACE TYPE", "COMBAT", GameStyle.SETUP_CYAN)
	metrics.add_child(race_metric)
	_race_type_value = race_metric.get_node("MetricRow/MetricStack/Value") as Label
	metrics.add_child(_metric_card("☠", "OPPONENTS", "%d AI" % MatchConfig.ai_count, GameStyle.SETUP_PURPLE))
	metrics.add_child(_metric_card("▣", "CRATES", "LIVE", GameStyle.SETUP_YELLOW))

	var note_panel := PanelContainer.new()
	note_panel.name = "LiveTrackDescription"
	note_panel.add_theme_stylebox_override("panel", GameStyle.setup_panel(Color("071117"), Color("263038"), 2))
	_place(note_panel, Vector2(580, 805), Vector2(472, 60))
	_canvas.add_child(note_panel)
	_preview_note = _make_label("", 14, Color("e3e2dc"))
	_preview_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_preview_note.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	note_panel.add_child(_preview_note)


func _build_start_hit_target() -> void:
	var start := Button.new()
	start.name = "StartRace"
	start.text = ""
	start.tooltip_text = "Start Race"
	start.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var empty := StyleBoxEmpty.new()
	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(1.0, 0.84, 0.18, 0.14)
	hover.border_color = Color(1.0, 0.88, 0.34, 0.85)
	hover.set_border_width_all(4)
	hover.set_corner_radius_all(8)
	var pressed := StyleBoxFlat.new()
	pressed.bg_color = Color(0.08, 0.04, 0.01, 0.22)
	pressed.border_color = Color("ffbf00")
	pressed.set_border_width_all(4)
	pressed.set_corner_radius_all(8)
	start.add_theme_stylebox_override("normal", empty)
	start.add_theme_stylebox_override("hover", hover)
	start.add_theme_stylebox_override("focus", hover)
	start.add_theme_stylebox_override("pressed", pressed)
	start.pressed.connect(_on_start_pressed)
	_place(start, Vector2(972, 895), Vector2(534, 105))
	_canvas.add_child(start)
	_focus_buttons.append(start)


func _add_mode_button(parent: Control, mode: MatchConfig.Mode, text: String) -> void:
	var button := _choice_button(text)
	button.name = "Mode%d" % int(mode)
	button.pressed.connect(_select_mode.bind(mode))
	_mode_buttons[mode] = button
	parent.add_child(button)
	_focus_buttons.append(button)


func _add_track_button(parent: Control, track: MatchConfig.TrackId, text: String) -> void:
	var button := _choice_button(text)
	button.name = "Track%d" % int(track)
	button.pressed.connect(_select_track.bind(track))
	_track_buttons[track] = button
	parent.add_child(button)
	_focus_buttons.append(button)


func _choice_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 62)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_override("font", _display_font)
	button.add_theme_font_size_override("font_size", 17)
	button.add_theme_color_override("font_outline_color", Color("020405"))
	button.add_theme_constant_override("outline_size", 3)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return button


func _build_stepper(icon: String, caption: String, target: String, action: Callable) -> Control:
	var row := PanelContainer.new()
	row.custom_minimum_size = Vector2(0, 57)
	row.add_theme_stylebox_override("panel", GameStyle.setup_rule_row())
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 7)
	row.add_child(box)

	var icon_label := _make_label(icon, 24, GameStyle.SETUP_YELLOW, true)
	icon_label.custom_minimum_size = Vector2(38, 0)
	icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	box.add_child(icon_label)
	var label := _make_label(caption, 16, Color("f2f0e9"), true)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	box.add_child(label)

	var minus := _stepper_button("−")
	minus.name = target.capitalize() + "Minus"
	minus.pressed.connect(func() -> void: action.call(-1))
	box.add_child(minus)
	_focus_buttons.append(minus)
	var value := _make_label("", 27, GameStyle.SETUP_YELLOW, true)
	value.custom_minimum_size = Vector2(48, 0)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	box.add_child(value)
	var plus := _stepper_button("+")
	plus.name = target.capitalize() + "Plus"
	plus.pressed.connect(func() -> void: action.call(1))
	box.add_child(plus)
	_focus_buttons.append(plus)

	match target:
		"laps":
			_lap_value = value
			_lap_minus = minus
			_lap_plus = plus
		"crates":
			_crate_value = value
		"ammo":
			_ammo_value = value
	return row


func _stepper_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(44, 42)
	button.add_theme_font_override("font", _display_font)
	button.add_theme_font_size_override("font_size", 25)
	GameStyle.apply_button(button, GameStyle.setup_stepper_button_styles(), Color("f4f1e8"))
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return button


func _metric_card(icon: String, caption: String, value: String, accent: Color) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", GameStyle.setup_panel(Color("0a141a"), Color("443428"), 2))
	var row := HBoxContainer.new()
	row.name = "MetricRow"
	row.add_theme_constant_override("separation", 12)
	panel.add_child(row)
	var icon_label := _make_label(icon, 34, accent, true)
	icon_label.custom_minimum_size = Vector2(58, 0)
	icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(icon_label)
	var stack := VBoxContainer.new()
	stack.name = "MetricStack"
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(stack)
	var cap := _make_label(caption, 13, Color("9b9995"), true)
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	stack.add_child(cap)
	var val := _make_label(value, 25, accent, true)
	val.name = "Value"
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	stack.add_child(val)
	return panel


func _section_title(text: String, color: Color) -> Label:
	var label := _make_label(text, 18, color, true)
	label.custom_minimum_size = Vector2(0, 25)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label


func _divider(color: Color) -> ColorRect:
	var divider := ColorRect.new()
	divider.custom_minimum_size = Vector2(0, 2)
	divider.color = color
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return divider


func _make_label(text: String, font_size: int, color: Color, display: bool = false) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", _display_font if display else _body_font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	if display:
		label.add_theme_color_override("font_outline_color", Color("020405"))
		label.add_theme_constant_override("outline_size", maxi(2, int(font_size * 0.10)))
	return label


func _place(control: Control, at: Vector2, dimensions: Vector2) -> void:
	control.position = at
	control.size = dimensions
	control.custom_minimum_size = dimensions


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


func _refresh_all() -> void:
	_refresh_choices()
	if is_instance_valid(_lap_value):
		var laps_enabled := _selected_mode != MatchConfig.Mode.LAST_STANDING
		_lap_value.text = str(_lap_count) if laps_enabled else "—"
		_lap_value.modulate = Color.WHITE if laps_enabled else Color(1, 1, 1, 0.34)
		if is_instance_valid(_lap_minus):
			_lap_minus.disabled = not laps_enabled
		if is_instance_valid(_lap_plus):
			_lap_plus.disabled = not laps_enabled
	if is_instance_valid(_crate_value):
		_crate_value.text = str(_crate_count)
	if is_instance_valid(_ammo_value):
		_ammo_value.text = str(_missiles_per_crate)
	if is_instance_valid(_mode_detail):
		match _selected_mode:
			MatchConfig.Mode.HYBRID:
				_mode_detail.text = "Win by finishing first or being the last car standing."
			MatchConfig.Mode.RACE:
				_mode_detail.text = "Finish first. Combat remains active throughout the race."
			MatchConfig.Mode.LAST_STANDING:
				_mode_detail.text = "No lap target. Destroy every rival to win."
	if is_instance_valid(_race_type_value):
		match _selected_mode:
			MatchConfig.Mode.HYBRID:
				_race_type_value.text = "COMBAT"
			MatchConfig.Mode.RACE:
				_race_type_value.text = "RACE"
			MatchConfig.Mode.LAST_STANDING:
				_race_type_value.text = "SURVIVE"
	_refresh_preview()


func _refresh_choices() -> void:
	for mode in _mode_buttons:
		_paint_choice(_mode_buttons[mode] as Button, mode == _selected_mode, GameStyle.SETUP_CYAN)
	for track in _track_buttons:
		_paint_choice(_track_buttons[track] as Button, track == _selected_track, GameStyle.SETUP_PURPLE)


func _paint_choice(button: Button, selected: bool, accent: Color) -> void:
	GameStyle.apply_button(button, GameStyle.setup_choice_styles(accent, selected), Color("f4f1e8"))
	button.add_theme_color_override("font_color", accent if selected else Color("f4f1e8"))
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_focus_color", Color.WHITE)


func _refresh_preview() -> void:
	if not is_instance_valid(_preview_title) or not is_instance_valid(_preview_image) or not is_instance_valid(_preview_note):
		return
	if _selected_track == MatchConfig.TrackId.KENNEY_DEFAULT:
		_preview_title.text = "STARTER CIRCUIT"
		_preview_image.texture = STARTER_PREVIEW
		_preview_note.text = "A flowing forest circuit with long straights, broad corners, and room to line up your shot."
	else:
		_preview_title.text = "FIGURE-8 CHAOS"
		_preview_image.texture = FIGURE8_PREVIEW
		_preview_note.text = "Twin loops and crossover lanes create constant close-range combat opportunities."
	if _preview_image.texture == null:
		_preview_image.modulate = Color("11181d")
	else:
		_preview_image.modulate = Color.WHITE


func _on_start_pressed() -> void:
	MatchConfig.mode = _selected_mode
	MatchConfig.track_id = _selected_track
	if _selected_mode != MatchConfig.Mode.LAST_STANDING:
		MatchConfig.lap_count = _lap_count
	MatchConfig.crate_count = _crate_count
	MatchConfig.missiles_per_crate = _missiles_per_crate
	get_tree().change_scene_to_file("res://scenes/race/Race3D.tscn")
