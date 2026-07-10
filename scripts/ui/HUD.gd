extends CanvasLayer
## In-race overlay: timer, HP, laps, cars remaining.

@onready var timer_label: Label = %TimerLabel
@onready var hp_label: Label = %HPLabel
@onready var lap_label: Label = %LapLabel
@onready var alive_label: Label = %AliveLabel
@onready var mode_label: Label = %ModeLabel

var _elapsed: float = 0.0
var _running: bool = true
var _player: Car = null


func _ready() -> void:
	mode_label.text = MatchConfig.mode_display_name()
	lap_label.visible = MatchConfig.uses_laps()
	_refresh_laps(0)
	_refresh_alive(5)
	_refresh_hp(100.0, 100.0)


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


func _on_player_health(current: float, maximum: float) -> void:
	_refresh_hp(current, maximum)


func _on_player_lap(_car: Car, laps: int) -> void:
	_refresh_laps(laps)


func _refresh_hp(current: float, maximum: float) -> void:
	hp_label.text = "HP %d / %d" % [int(current), int(maximum)]


func _refresh_laps(current: int) -> void:
	if MatchConfig.uses_laps():
		lap_label.text = "LAP %d / %d" % [current, MatchConfig.lap_count]
	else:
		lap_label.text = "LAPS OFF"


func update_alive(count: int) -> void:
	_refresh_alive(count)


func _refresh_alive(count: int) -> void:
	alive_label.text = "ALIVE %d" % count
