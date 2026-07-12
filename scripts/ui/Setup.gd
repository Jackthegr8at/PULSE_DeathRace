extends Control
## Pre-race command screen: compact controls, track briefing, decisive launch CTA.

const BACKDROP: Texture2D = preload("res://assets/concept/figure8_playfield_painted.png")
const STARTER_PREVIEW: Texture2D = preload("res://assets/concept/starter-circuit-preview.png")
const FIGURE8_PREVIEW: Texture2D = preload("res://assets/concept/figure8-preview.png")

var _selected_mode: MatchConfig.Mode = MatchConfig.Mode.HYBRID
var _selected_track: MatchConfig.TrackId = MatchConfig.TrackId.KENNEY_DEFAULT
var _lap_count: int = 5
var _crate_count: int = 5
var _missiles_per_crate: int = 2

var _mode_buttons: Dictionary = {}
var _track_buttons: Dictionary = {}
var _lap_value: Label
var _crate_value: Label
var _ammo_value: Label
var _mode_detail: Label
var _preview_title: Label
var _preview_image: TextureRect
var _preview_note: Label


func _ready() -> void:
	_selected_mode = MatchConfig.mode
	_selected_track = MatchConfig.track_id
	_lap_count = MatchConfig.lap_count
	_crate_count = MatchConfig.crate_count
	_missiles_per_crate = MatchConfig.missiles_per_crate
	_build_screen()
	_refresh_all()


func _build_screen() -> void:
	for child in get_children():
		child.queue_free()

	var backdrop := TextureRect.new()
	backdrop.texture = BACKDROP
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.modulate = Color(0.62, 0.72, 0.62, 0.7)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)

	var scrim := ColorRect.new()
	scrim.color = Color(0.025, 0.045, 0.03, 0.76)
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(scrim)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_bottom", 22)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 14)
	margin.add_child(root)
	root.add_child(_build_header())

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 18)
	root.add_child(body)
	body.add_child(_build_controls())
	body.add_child(_build_briefing())

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 14)
	root.add_child(footer)
	var help := Label.new()
	help.text = "WASD / Arrows drive   ·   Space fire   ·   Grab missile crates"
	help.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	help.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	GameStyle.apply_label(help, GameStyle.TEXT_MUTED, 13)
	footer.add_child(help)
	var start := Button.new()
	start.text = "START RACE"
	start.custom_minimum_size = Vector2(360, 62)
	start.add_theme_font_size_override("font_size", 24)
	GameStyle.apply_button(start, GameStyle.button_primary(), GameStyle.BG_DEEP)
	start.pressed.connect(_on_start_pressed)
	footer.add_child(start)


func _build_header() -> Control:
	var header := HBoxContainer.new()
	header.custom_minimum_size = Vector2(0, 76)
	header.add_theme_constant_override("separation", 18)

	var brand := VBoxContainer.new()
	brand.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	brand.alignment = BoxContainer.ALIGNMENT_CENTER
	header.add_child(brand)
	var title := Label.new()
	title.text = "PULSE DEATHRACE"
	GameStyle.apply_title(title, GameStyle.ACCENT, 38)
	brand.add_child(title)
	var sub := Label.new()
	sub.text = "RACE BRIEF  ·  ARCADE COMBAT LEAGUE"
	GameStyle.apply_label(sub, GameStyle.TEXT, 13)
	sub.modulate = Color(1, 1, 1, 0.85)
	brand.add_child(sub)

	var badge := PanelContainer.new()
	badge.custom_minimum_size = Vector2(210, 56)
	badge.add_theme_stylebox_override("panel", GameStyle.comic_panel(Color(0.10, 0.18, 0.12, 0.96), 12.0))
	header.add_child(badge)
	var badge_label := Label.new()
	badge_label.text = "3 AI  ·  COMBAT ON"
	badge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	GameStyle.apply_label(badge_label, GameStyle.SUCCESS, 13)
	badge.add_child(badge_label)
	return header


func _build_controls() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(430, 0)
	panel.add_theme_stylebox_override("panel", GameStyle.comic_panel(Color(0.055, 0.075, 0.055, 0.97), 16.0))
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(margin)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 12)
	margin.add_child(stack)

	stack.add_child(_caption("MATCH MODE"))
	var mode_row := HBoxContainer.new()
	mode_row.add_theme_constant_override("separation", 8)
	stack.add_child(mode_row)
	for entry in [[MatchConfig.Mode.HYBRID, "HYBRID"], [MatchConfig.Mode.RACE, "RACE"], [MatchConfig.Mode.LAST_STANDING, "LAST STANDING"]]:
		var mode: MatchConfig.Mode = entry[0]
		var button := _choice_button(str(entry[1]))
		button.pressed.connect(func() -> void: _select_mode(mode))
		_mode_buttons[mode] = button
		mode_row.add_child(button)

	_mode_detail = Label.new()
	_mode_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	GameStyle.apply_label(_mode_detail, GameStyle.TEXT_MUTED, 12)
	stack.add_child(_mode_detail)

	stack.add_child(_caption("TRACK"))
	var track_row := HBoxContainer.new()
	track_row.add_theme_constant_override("separation", 8)
	stack.add_child(track_row)
	for entry in [[MatchConfig.TrackId.KENNEY_DEFAULT, "STARTER\nCIRCUIT"], [MatchConfig.TrackId.FIGURE_8, "FIGURE-8\nCHAOS"]]:
		var track: MatchConfig.TrackId = entry[0]
		var button := _choice_button(str(entry[1]))
		button.pressed.connect(func() -> void: _select_track(track))
		_track_buttons[track] = button
		track_row.add_child(button)

	stack.add_child(_caption("RACE RULES"))
	stack.add_child(_build_stepper("LAPS", func(delta: int) -> void: _change_laps(delta), "laps"))
	stack.add_child(_build_stepper("MISSILE CRATES", func(delta: int) -> void: _change_crate_count(delta), "crates"))
	stack.add_child(_build_stepper("MISSILES / CRATE", func(delta: int) -> void: _change_missiles_per_crate(delta), "ammo"))
	return panel


func _build_briefing() -> Control:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", GameStyle.comic_panel(Color(0.055, 0.075, 0.055, 0.97), 16.0))
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(margin)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 12)
	margin.add_child(stack)

	_preview_title = Label.new()
	_preview_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	GameStyle.apply_title(_preview_title, GameStyle.TEXT, 28)
	stack.add_child(_preview_title)

	var preview_frame := PanelContainer.new()
	preview_frame.custom_minimum_size = Vector2(0, 315)
	preview_frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview_frame.add_theme_stylebox_override("panel", GameStyle.panel(Color(0.03, 0.05, 0.03, 1), GameStyle.ACCENT, 4.0, 3.0))
	stack.add_child(preview_frame)
	_preview_image = TextureRect.new()
	_preview_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_preview_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_preview_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_frame.add_child(_preview_image)

	var info := HBoxContainer.new()
	info.add_theme_constant_override("separation", 8)
	stack.add_child(info)
	info.add_child(_metric("RACE TYPE", "COMBAT"))
	info.add_child(_metric("OPPONENTS", "3 AI"))
	info.add_child(_metric("CRATES", "LIVE"))

	_preview_note = Label.new()
	_preview_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	GameStyle.apply_label(_preview_note, GameStyle.TEXT_MUTED, 13)
	stack.add_child(_preview_note)
	return panel


func _caption(text: String) -> Label:
	var label := Label.new()
	label.text = text
	GameStyle.apply_label(label, GameStyle.ACCENT, 12)
	label.add_theme_color_override("font_outline_color", GameStyle.INK)
	label.add_theme_constant_override("outline_size", 2)
	return label


func _choice_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 72)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 14)
	GameStyle.apply_button(button, GameStyle.button_ghost())
	return button


func _build_stepper(caption: String, action: Callable, target: String) -> Control:
	var row := PanelContainer.new()
	row.add_theme_stylebox_override("panel", GameStyle.panel(Color(0.08, 0.11, 0.08, 0.92), GameStyle.BORDER, 8.0, 2.0))
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	row.add_child(box)
	var label := Label.new()
	label.text = caption
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	GameStyle.apply_label(label, GameStyle.TEXT, 12)
	box.add_child(label)
	var minus := Button.new()
	minus.text = "−"
	minus.custom_minimum_size = Vector2(38, 38)
	GameStyle.apply_button(minus, GameStyle.button_ghost())
	minus.pressed.connect(func() -> void: action.call(-1))
	box.add_child(minus)
	var value := Label.new()
	value.custom_minimum_size = Vector2(42, 0)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	GameStyle.apply_title(value, GameStyle.ACCENT, 20)
	box.add_child(value)
	var plus := Button.new()
	plus.text = "+"
	plus.custom_minimum_size = Vector2(38, 38)
	GameStyle.apply_button(plus, GameStyle.button_ghost())
	plus.pressed.connect(func() -> void: action.call(1))
	box.add_child(plus)
	match target:
		"laps":
			_lap_value = value
		"crates":
			_crate_value = value
		"ammo":
			_ammo_value = value
	return row


func _metric(caption: String, value: String) -> Control:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", GameStyle.panel(Color(0.10, 0.13, 0.10, 0.94), GameStyle.BORDER, 8.0, 2.0))
	var stack := VBoxContainer.new()
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(stack)
	var cap := Label.new()
	cap.text = caption
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	GameStyle.apply_label(cap, GameStyle.TEXT_MUTED, 10)
	stack.add_child(cap)
	var val := Label.new()
	val.text = value
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	GameStyle.apply_title(val, GameStyle.INFO, 16)
	stack.add_child(val)
	return panel


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
	if _lap_value:
		_lap_value.text = "—" if _selected_mode == MatchConfig.Mode.LAST_STANDING else str(_lap_count)
		_lap_value.modulate = Color(1, 1, 1, 0.38) if _selected_mode == MatchConfig.Mode.LAST_STANDING else Color.WHITE
	if _crate_value:
		_crate_value.text = str(_crate_count)
	if _ammo_value:
		_ammo_value.text = str(_missiles_per_crate)
	if _mode_detail:
		match _selected_mode:
			MatchConfig.Mode.HYBRID:
				_mode_detail.text = "Win by finishing first or being the last car standing."
			MatchConfig.Mode.RACE:
				_mode_detail.text = "Finish first. Combat remains active throughout the race."
			MatchConfig.Mode.LAST_STANDING:
				_mode_detail.text = "No lap target. Destroy every rival to win."
	if _preview_title and _preview_image and _preview_note:
		if _selected_track == MatchConfig.TrackId.KENNEY_DEFAULT:
			_preview_title.text = "STARTER CIRCUIT"
			_preview_image.texture = STARTER_PREVIEW
			_preview_note.text = "A flowing forest circuit with long straights, broad corners, and room to line up your shot."
		else:
			_preview_title.text = "FIGURE-8 CHAOS"
			_preview_image.texture = FIGURE8_PREVIEW
			_preview_note.text = "Twin loops and crossover lanes create constant close-range combat opportunities."


func _refresh_choices() -> void:
	for mode in _mode_buttons:
		_paint_choice(_mode_buttons[mode] as Button, mode == _selected_mode)
	for track in _track_buttons:
		_paint_choice(_track_buttons[track] as Button, track == _selected_track)


func _paint_choice(button: Button, selected: bool) -> void:
	if selected:
		var style := GameStyle.button_normal(Color(0.28, 0.36, 0.13, 0.98), GameStyle.ACCENT)
		style.set_border_width_all(4)
		button.add_theme_stylebox_override("normal", style)
		button.add_theme_stylebox_override("hover", style)
		button.add_theme_stylebox_override("pressed", style)
		button.add_theme_color_override("font_color", GameStyle.ACCENT)
	else:
		GameStyle.apply_button(button, GameStyle.button_ghost())


func _on_start_pressed() -> void:
	MatchConfig.mode = _selected_mode
	MatchConfig.track_id = _selected_track
	MatchConfig.lap_count = _lap_count if _selected_mode != MatchConfig.Mode.LAST_STANDING else MatchConfig.lap_count
	MatchConfig.crate_count = _crate_count
	MatchConfig.missiles_per_crate = _missiles_per_crate
	get_tree().change_scene_to_file("res://scenes/race/Race3D.tscn")
