extends Control
## Pre-match: mode, laps, track (Kenney default or Figure-8) → Race3D.

@onready var title_label: Label = %Title
@onready var subtitle: Label = %Subtitle
@onready var mode_hybrid: Button = %ModeHybrid
@onready var mode_race: Button = %ModeRace
@onready var mode_last: Button = %ModeLast
@onready var track_default: Button = %TrackDefault
@onready var track_figure8: Button = %TrackFigure8
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
var _selected_track: MatchConfig.TrackId = MatchConfig.TrackId.KENNEY_DEFAULT
var _lap_count: int = 5
var _mode_buttons: Array[Button] = []
var _track_buttons: Array[Button] = []


func _ready() -> void:
	_selected_mode = MatchConfig.mode
	_selected_track = MatchConfig.track_id
	_lap_count = MatchConfig.lap_count

	_mode_buttons = [mode_hybrid, mode_race, mode_last]
	_track_buttons = [track_default, track_figure8]

	mode_hybrid.pressed.connect(func() -> void: _select_mode(MatchConfig.Mode.HYBRID))
	mode_race.pressed.connect(func() -> void: _select_mode(MatchConfig.Mode.RACE))
	mode_last.pressed.connect(func() -> void: _select_mode(MatchConfig.Mode.LAST_STANDING))
	track_default.pressed.connect(func() -> void: _select_track(MatchConfig.TrackId.KENNEY_DEFAULT))
	track_figure8.pressed.connect(func() -> void: _select_track(MatchConfig.TrackId.FIGURE_8))
	lap_minus.pressed.connect(func() -> void: _change_laps(-1))
	lap_plus.pressed.connect(func() -> void: _change_laps(1))
	start_button.pressed.connect(_on_start_pressed)

	_apply_styles()
	_refresh_mode_ui()
	_refresh_track_ui()
	_refresh_laps_ui()


func _apply_styles() -> void:
	if panel:
		panel.add_theme_stylebox_override(
			"panel",
			GameStyle.panel(Color(0.1, 0.14, 0.1, 0.94), GameStyle.BORDER, 14.0, 2.0)
		)
	if title_label:
		GameStyle.apply_label(title_label, GameStyle.ACCENT, 36)
	if subtitle:
		GameStyle.apply_label(subtitle, GameStyle.TEXT_MUTED, 14)
		subtitle.text = "3D combat racing · Kenney base · pick a track"
	if controls_label:
		GameStyle.apply_label(controls_label, GameStyle.TEXT_DIM, 12)
		controls_label.text = "WASD drive  ·  Esc back to setup  ·  Combat AI next"
	if lap_hint:
		GameStyle.apply_label(lap_hint, GameStyle.TEXT_MUTED, 12)
	if lap_value:
		GameStyle.apply_label(lap_value, GameStyle.TEXT, 28)
	if accent_bar:
		accent_bar.color = GameStyle.ACCENT

	for b in _mode_buttons + _track_buttons:
		if b:
			b.custom_minimum_size = Vector2(0, 44)
			b.add_theme_font_size_override("font_size", 14)
			GameStyle.apply_button(b, GameStyle.button_ghost())

	if lap_minus and lap_plus:
		GameStyle.apply_button(lap_minus, GameStyle.button_ghost())
		GameStyle.apply_button(lap_plus, GameStyle.button_ghost())
		lap_minus.custom_minimum_size = Vector2(48, 48)
		lap_plus.custom_minimum_size = Vector2(48, 48)

	if start_button:
		var primary := GameStyle.button_primary()
		GameStyle.apply_button(start_button, primary, GameStyle.BG_DEEP)
		start_button.add_theme_font_size_override("font_size", 20)
		start_button.custom_minimum_size = Vector2(0, 52)
		start_button.text = "START RACE"

	var bg := get_node_or_null("Background") as ColorRect
	if bg:
		bg.color = Color(0.28, 0.42, 0.26)


func _select_mode(mode: MatchConfig.Mode) -> void:
	_selected_mode = mode
	_refresh_mode_ui()
	_refresh_laps_ui()


func _select_track(track: MatchConfig.TrackId) -> void:
	_selected_track = track
	_refresh_track_ui()


func _change_laps(delta: int) -> void:
	if not _uses_laps():
		return
	_lap_count = clampi(_lap_count + delta, 1, 99)
	_refresh_laps_ui()


func _uses_laps() -> bool:
	return _selected_mode != MatchConfig.Mode.LAST_STANDING


func _paint_selected(btn: Button, on: bool) -> void:
	if on:
		btn.add_theme_stylebox_override("normal", GameStyle.button_selected())
		btn.add_theme_stylebox_override("hover", GameStyle.button_selected())
		btn.add_theme_stylebox_override("pressed", GameStyle.button_selected())
		btn.add_theme_color_override("font_color", GameStyle.ACCENT)
	else:
		GameStyle.apply_button(btn, GameStyle.button_ghost())


func _refresh_mode_ui() -> void:
	_paint_selected(mode_hybrid, _selected_mode == MatchConfig.Mode.HYBRID)
	_paint_selected(mode_race, _selected_mode == MatchConfig.Mode.RACE)
	_paint_selected(mode_last, _selected_mode == MatchConfig.Mode.LAST_STANDING)
	if lap_hint == null:
		return
	match _selected_mode:
		MatchConfig.Mode.HYBRID:
			lap_hint.text = "Win by race finish or last car standing (combat coming soon)."
		MatchConfig.Mode.RACE:
			lap_hint.text = "First to finish the set laps wins."
		MatchConfig.Mode.LAST_STANDING:
			lap_hint.text = "No laps — survival mode (combat coming soon)."


func _refresh_track_ui() -> void:
	_paint_selected(track_default, _selected_track == MatchConfig.TrackId.KENNEY_DEFAULT)
	_paint_selected(track_figure8, _selected_track == MatchConfig.TrackId.FIGURE_8)


func _refresh_laps_ui() -> void:
	var use := _uses_laps()
	if lap_row:
		lap_row.modulate = Color(1, 1, 1, 1) if use else Color(1, 1, 1, 0.4)
	if lap_minus:
		lap_minus.disabled = not use
	if lap_plus:
		lap_plus.disabled = not use
	if lap_value:
		lap_value.text = str(_lap_count) if use else "—"


func _on_start_pressed() -> void:
	MatchConfig.mode = _selected_mode
	MatchConfig.track_id = _selected_track
	MatchConfig.lap_count = _lap_count if _uses_laps() else MatchConfig.lap_count
	get_tree().change_scene_to_file("res://scenes/race/Race3D.tscn")
