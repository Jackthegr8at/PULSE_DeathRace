extends Control
## Pre-match menu — arcade card layout with mode pills and lap control.

@onready var title_label: Label = %Title
@onready var subtitle: Label = %Subtitle
@onready var mode_hybrid: Button = %ModeHybrid
@onready var mode_race: Button = %ModeRace
@onready var mode_last: Button = %ModeLast
@onready var lap_row: Control = %LapRow
@onready var lap_value: Label = %LapValue
@onready var lap_minus: Button = %LapMinus
@onready var lap_plus: Button = %LapPlus
@onready var lap_hint: Label = %LapHint
@onready var start_button: Button = %StartButton
@onready var controls_label: Label = %ControlsLabel
@onready var panel: PanelContainer = %Panel
@onready var accent_bar: ColorRect = %AccentBar

var _selected_mode: MatchConfig.Mode = MatchConfig.Mode.HYBRID
var _lap_count: int = 5
var _mode_buttons: Array[Button] = []


func _ready() -> void:
	_selected_mode = MatchConfig.mode
	_lap_count = MatchConfig.lap_count

	_mode_buttons = [mode_hybrid, mode_race, mode_last]
	mode_hybrid.pressed.connect(func() -> void: _select_mode(MatchConfig.Mode.HYBRID))
	mode_race.pressed.connect(func() -> void: _select_mode(MatchConfig.Mode.RACE))
	mode_last.pressed.connect(func() -> void: _select_mode(MatchConfig.Mode.LAST_STANDING))
	lap_minus.pressed.connect(func() -> void: _change_laps(-1))
	lap_plus.pressed.connect(func() -> void: _change_laps(1))
	start_button.pressed.connect(_on_start_pressed)

	_apply_styles()
	_refresh_mode_ui()
	_refresh_laps_ui()


func _apply_styles() -> void:
	panel.add_theme_stylebox_override(
		"panel",
		GameStyle.panel(Color(0.06, 0.08, 0.12, 0.92), GameStyle.BORDER_GLOW, 14.0, 1.0)
	)
	GameStyle.apply_label(title_label, GameStyle.ACCENT, 40)
	# Darker full-screen backdrop if present
	var bg := get_node_or_null("Background") as ColorRect
	if bg:
		bg.color = Color(0.28, 0.42, 0.26)
	GameStyle.apply_label(subtitle, GameStyle.TEXT_MUTED, 14)
	GameStyle.apply_label(controls_label, GameStyle.TEXT_DIM, 12)
	GameStyle.apply_label(lap_hint, GameStyle.TEXT_MUTED, 12)
	GameStyle.apply_label(lap_value, GameStyle.TEXT, 28)

	for b in _mode_buttons:
		b.custom_minimum_size = Vector2(0, 44)
		b.add_theme_font_size_override("font_size", 14)
		GameStyle.apply_button(b, GameStyle.button_ghost())

	GameStyle.apply_button(lap_minus, GameStyle.button_ghost())
	GameStyle.apply_button(lap_plus, GameStyle.button_ghost())
	lap_minus.custom_minimum_size = Vector2(48, 48)
	lap_plus.custom_minimum_size = Vector2(48, 48)

	var primary := GameStyle.button_primary()
	GameStyle.apply_button(start_button, primary, GameStyle.BG_DEEP)
	start_button.add_theme_font_size_override("font_size", 20)
	start_button.custom_minimum_size = Vector2(0, 52)

	if accent_bar:
		accent_bar.color = GameStyle.ACCENT


func _select_mode(mode: MatchConfig.Mode) -> void:
	_selected_mode = mode
	_refresh_mode_ui()
	_refresh_laps_ui()


func _change_laps(delta: int) -> void:
	if not _uses_laps():
		return
	_lap_count = clampi(_lap_count + delta, 1, 99)
	_refresh_laps_ui()


func _uses_laps() -> bool:
	return _selected_mode != MatchConfig.Mode.LAST_STANDING


func _refresh_mode_ui() -> void:
	var map := {
		MatchConfig.Mode.HYBRID: mode_hybrid,
		MatchConfig.Mode.RACE: mode_race,
		MatchConfig.Mode.LAST_STANDING: mode_last,
	}
	for mode in map:
		var btn: Button = map[mode]
		var selected: bool = mode == _selected_mode
		if selected:
			btn.add_theme_stylebox_override("normal", GameStyle.button_selected())
			btn.add_theme_stylebox_override("hover", GameStyle.button_selected())
			btn.add_theme_stylebox_override("pressed", GameStyle.button_selected())
			btn.add_theme_color_override("font_color", GameStyle.ACCENT)
		else:
			GameStyle.apply_button(btn, GameStyle.button_ghost())

	match _selected_mode:
		MatchConfig.Mode.HYBRID:
			lap_hint.text = "Win by finishing the race or eliminating everyone."
		MatchConfig.Mode.RACE:
			lap_hint.text = "First to finish the set laps wins. Combat is optional."
		MatchConfig.Mode.LAST_STANDING:
			lap_hint.text = "No laps. Last car alive wins."


func _refresh_laps_ui() -> void:
	var use := _uses_laps()
	lap_row.modulate = Color(1, 1, 1, 1) if use else Color(1, 1, 1, 0.4)
	lap_minus.disabled = not use
	lap_plus.disabled = not use
	if use:
		lap_value.text = str(_lap_count)
	else:
		lap_value.text = "—"


func _on_start_pressed() -> void:
	MatchConfig.mode = _selected_mode
	MatchConfig.lap_count = _lap_count if _uses_laps() else MatchConfig.lap_count
	MatchConfig.ai_count = 4
	MatchConfig.track_scene_path = "res://scenes/tracks/Figure8.tscn"
	get_tree().change_scene_to_file("res://scenes/Main.tscn")
