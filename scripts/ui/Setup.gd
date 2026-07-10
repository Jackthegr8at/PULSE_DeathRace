extends Control
## Pre-match menu: choose mode + laps, then start the race.

@onready var mode_option: OptionButton = %ModeOption
@onready var lap_spin: SpinBox = %LapSpin
@onready var lap_row: HBoxContainer = %LapRow
@onready var start_button: Button = %StartButton
@onready var subtitle: Label = %Subtitle


func _ready() -> void:
	mode_option.clear()
	mode_option.add_item("Hybrid (race or wipeout)", MatchConfig.Mode.HYBRID)
	mode_option.add_item("Race only", MatchConfig.Mode.RACE)
	mode_option.add_item("Last Standing (no laps)", MatchConfig.Mode.LAST_STANDING)
	mode_option.select(int(MatchConfig.mode))

	lap_spin.min_value = 1
	lap_spin.max_value = 99
	lap_spin.value = MatchConfig.lap_count
	lap_spin.rounded = true

	mode_option.item_selected.connect(_on_mode_selected)
	start_button.pressed.connect(_on_start_pressed)
	_refresh_lap_enabled()
	subtitle.text = "Figure-8 chaos · 1 player + 4 AI · prototype"


func _on_mode_selected(index: int) -> void:
	MatchConfig.mode = mode_option.get_item_id(index) as MatchConfig.Mode
	_refresh_lap_enabled()


func _refresh_lap_enabled() -> void:
	var use_laps := MatchConfig.uses_laps()
	lap_spin.editable = use_laps
	lap_row.modulate = Color(1, 1, 1, 1) if use_laps else Color(1, 1, 1, 0.4)


func _on_start_pressed() -> void:
	MatchConfig.mode = mode_option.get_item_id(mode_option.selected) as MatchConfig.Mode
	MatchConfig.lap_count = int(lap_spin.value)
	MatchConfig.ai_count = 4
	MatchConfig.track_scene_path = "res://scenes/tracks/Figure8.tscn"
	get_tree().change_scene_to_file("res://scenes/Main.tscn")
