extends CanvasLayer
## In-race HUD — chip panels, HP bar, lap progress, timer.

@onready var timer_label: Label = %TimerLabel
@onready var mode_label: Label = %ModeLabel
@onready var lap_label: Label = %LapLabel
@onready var lap_bar: ProgressBar = %LapBar
@onready var lap_block: Control = %LapBlock
@onready var hp_label: Label = %HPLabel
@onready var hp_bar: ProgressBar = %HPBar
@onready var alive_label: Label = %AliveLabel
@onready var top_panel: PanelContainer = %TopPanel
@onready var hp_panel: PanelContainer = %HPPanel
@onready var alive_panel: PanelContainer = %AlivePanel
@onready var controls_hint: Label = %ControlsHint

var _elapsed: float = 0.0
var _running: bool = true
var _player: Car = null


func _ready() -> void:
	_apply_styles()
	mode_label.text = MatchConfig.mode_display_name().to_upper()
	lap_block.visible = MatchConfig.uses_laps()
	_refresh_laps(0)
	_refresh_alive(5)
	_refresh_hp(100.0, 100.0)
	if controls_hint:
		controls_hint.modulate.a = 1.0
		# Fade controls hint after a few seconds
		var tw := create_tween()
		tw.tween_interval(4.0)
		tw.tween_property(controls_hint, "modulate:a", 0.0, 1.2)


func _apply_styles() -> void:
	var chip := GameStyle.chip(GameStyle.SURFACE, GameStyle.BORDER)
	top_panel.add_theme_stylebox_override("panel", chip)
	hp_panel.add_theme_stylebox_override("panel", chip)
	alive_panel.add_theme_stylebox_override("panel", chip)

	GameStyle.apply_label(timer_label, GameStyle.TEXT, 22)
	GameStyle.apply_label(mode_label, GameStyle.PURPLE, 12)
	GameStyle.apply_label(lap_label, GameStyle.INFO, 13)
	GameStyle.apply_label(hp_label, GameStyle.SUCCESS, 13)
	GameStyle.apply_label(alive_label, GameStyle.WARNING, 14)
	if controls_hint:
		GameStyle.apply_label(controls_hint, GameStyle.TEXT_DIM, 12)

	_style_bar(lap_bar, GameStyle.INFO)
	_style_bar(hp_bar, GameStyle.SUCCESS)


func _style_bar(bar: ProgressBar, fill: Color) -> void:
	bar.show_percentage = false
	bar.add_theme_stylebox_override("background", GameStyle.progress_bg())
	bar.add_theme_stylebox_override("fill", GameStyle.progress_fill(fill))
	bar.custom_minimum_size = Vector2(120, 10)


func set_player(player: Car) -> void:
	_player = player
	if _player:
		if not _player.health_changed.is_connected(_on_player_health):
			_player.health_changed.connect(_on_player_health)
		if not _player.lap_completed.is_connected(_on_player_lap):
			_player.lap_completed.connect(_on_player_lap)
		_refresh_hp(_player.health, _player.max_health)
		_refresh_laps(_player.laps_completed)


func stop() -> void:
	_running = false


func _process(delta: float) -> void:
	if not _running:
		return
	_elapsed += delta
	var minutes := int(_elapsed) / 60
	var seconds := int(_elapsed) % 60
	var ms := int(fmod(_elapsed, 1.0) * 100.0)
	timer_label.text = "%02d:%02d.%02d" % [minutes, seconds, ms]

	if MatchConfig.uses_laps() and _player and is_instance_valid(_player) and _player.is_alive:
		var ratio := _player.get_lap_progress_ratio()
		var pct := int(ratio * 100.0)
		lap_label.text = "LAP %d / %d" % [_player.laps_completed, MatchConfig.lap_count]
		if lap_bar:
			lap_bar.max_value = 1.0
			lap_bar.value = ratio
		# Tiny caption via tooltip-style second line is the bar itself
		lap_bar.tooltip_text = "%d%% of current lap" % pct


func _on_player_health(current: float, maximum: float) -> void:
	_refresh_hp(current, maximum)


func _on_player_lap(_car: Car, laps: int) -> void:
	_refresh_laps(laps)


func _refresh_hp(current: float, maximum: float) -> void:
	hp_label.text = "HP  %d" % int(current)
	if hp_bar:
		hp_bar.max_value = maximum
		hp_bar.value = current
		var ratio := current / maxf(maximum, 1.0)
		var col := GameStyle.hp_color(ratio)
		hp_bar.add_theme_stylebox_override("fill", GameStyle.progress_fill(col))
		GameStyle.apply_label(hp_label, col, 13)


func _refresh_laps(current: int) -> void:
	if MatchConfig.uses_laps():
		lap_label.text = "LAP %d / %d" % [current, MatchConfig.lap_count]
	else:
		lap_label.text = "LAPS OFF"


func update_alive(count: int) -> void:
	_refresh_alive(count)


func _refresh_alive(count: int) -> void:
	alive_label.text = "ALIVE  %d" % count
	if count <= 1:
		GameStyle.apply_label(alive_label, GameStyle.SUCCESS, 14)
	elif count <= 2:
		GameStyle.apply_label(alive_label, GameStyle.WARNING, 14)
	else:
		GameStyle.apply_label(alive_label, GameStyle.WARNING, 14)
