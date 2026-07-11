extends CanvasLayer
## Lightweight in-race HUD for 3D DeathRace.

var _player: Vehicle = null
var _elapsed: float = 0.0
var _running: bool = true

var timer_label: Label
var hp_bar: ProgressBar
var lap_label: Label
var lap_bar: ProgressBar
var alive_label: Label
var mode_label: Label
var track_label: Label
var ammo_label: Label
var hint_label: Label


func _ready() -> void:
	layer = 20
	_build()
	mode_label.text = MatchConfig.mode_display_name()
	track_label.text = MatchConfig.track_display_name()
	lap_label.visible = MatchConfig.uses_laps()
	lap_bar.visible = MatchConfig.uses_laps()


func set_player(player: Vehicle) -> void:
	_player = player
	if _player:
		if not _player.health_changed.is_connected(_on_hp):
			_player.health_changed.connect(_on_hp)
		if not _player.ammo_changed.is_connected(_on_ammo):
			_player.ammo_changed.connect(_on_ammo)
		_on_hp(_player.health, _player.max_health)
		_on_ammo(_player.missile_ammo, _player.max_missile_ammo)


func update_alive(n: int) -> void:
	if alive_label:
		alive_label.text = "ALIVE %d" % n


func stop() -> void:
	_running = false


func _build() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var panel := PanelContainer.new()
	panel.position = Vector2(16, 14)
	panel.add_theme_stylebox_override("panel", GameStyle.glass_chip())
	root.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	var margin := MarginContainer.new()
	for s in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(s, 10)
	margin.add_child(v)
	panel.add_child(margin)

	timer_label = Label.new()
	timer_label.text = "00:00.00"
	GameStyle.apply_label(timer_label, GameStyle.TEXT, 20)
	v.add_child(timer_label)

	mode_label = Label.new()
	GameStyle.apply_label(mode_label, GameStyle.ACCENT, 12)
	v.add_child(mode_label)

	track_label = Label.new()
	GameStyle.apply_label(track_label, GameStyle.TEXT_MUTED, 12)
	v.add_child(track_label)

	hp_bar = ProgressBar.new()
	hp_bar.custom_minimum_size = Vector2(180, 12)
	hp_bar.max_value = 100
	hp_bar.value = 100
	hp_bar.show_percentage = false
	hp_bar.add_theme_stylebox_override("background", GameStyle.progress_bg())
	hp_bar.add_theme_stylebox_override("fill", GameStyle.progress_fill(GameStyle.SUCCESS))
	v.add_child(hp_bar)

	ammo_label = Label.new()
	ammo_label.text = "MISSILES  0 / 3"
	GameStyle.apply_label(ammo_label, GameStyle.ACCENT, 13)
	v.add_child(ammo_label)

	lap_label = Label.new()
	lap_label.text = "LAP 0 / %d" % MatchConfig.lap_count
	GameStyle.apply_label(lap_label, GameStyle.INFO, 12)
	v.add_child(lap_label)

	lap_bar = ProgressBar.new()
	lap_bar.custom_minimum_size = Vector2(180, 8)
	lap_bar.max_value = 1.0
	lap_bar.show_percentage = false
	lap_bar.add_theme_stylebox_override("background", GameStyle.progress_bg())
	lap_bar.add_theme_stylebox_override("fill", GameStyle.progress_fill(GameStyle.INFO))
	v.add_child(lap_bar)

	var alive_panel := PanelContainer.new()
	alive_panel.anchor_left = 1.0
	alive_panel.anchor_right = 1.0
	alive_panel.offset_left = -160
	alive_panel.offset_right = -16
	alive_panel.offset_top = 14
	alive_panel.add_theme_stylebox_override("panel", GameStyle.glass_chip())
	root.add_child(alive_panel)
	var am := MarginContainer.new()
	for s in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		am.add_theme_constant_override(s, 10)
	alive_panel.add_child(am)
	alive_label = Label.new()
	alive_label.text = "ALIVE 1"
	GameStyle.apply_label(alive_label, GameStyle.WARNING, 14)
	am.add_child(alive_label)

	hint_label = Label.new()
	hint_label.text = "WASD drive  ·  Pick up gold crates for missiles  ·  Space fire  ·  Esc setup"
	hint_label.anchor_left = 0.5
	hint_label.anchor_top = 1.0
	hint_label.anchor_right = 0.5
	hint_label.anchor_bottom = 1.0
	hint_label.offset_left = -220
	hint_label.offset_right = 220
	hint_label.offset_top = -36
	hint_label.offset_bottom = -14
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	GameStyle.apply_label(hint_label, GameStyle.TEXT_DIM, 12)
	root.add_child(hint_label)
	var tw := create_tween()
	tw.tween_interval(5.0)
	tw.tween_property(hint_label, "modulate:a", 0.0, 1.0)


func _process(delta: float) -> void:
	if not _running:
		return
	_elapsed += delta
	var m := int(_elapsed) / 60
	var s := int(_elapsed) % 60
	var ms := int(fmod(_elapsed, 1.0) * 100.0)
	timer_label.text = "%02d:%02d.%02d" % [m, s, ms]
	if _player and is_instance_valid(_player) and _player.is_alive and MatchConfig.uses_laps():
		lap_label.text = "LAP %d / %d" % [_player.laps_completed, MatchConfig.lap_count]
		lap_bar.value = _player.get_lap_progress_ratio()


func _on_hp(current: float, maximum: float) -> void:
	if hp_bar == null:
		return
	hp_bar.max_value = maximum
	hp_bar.value = current
	var ratio := current / maxf(maximum, 1.0)
	hp_bar.add_theme_stylebox_override("fill", GameStyle.progress_fill(GameStyle.hp_color(ratio)))


func _on_ammo(current: int, maximum: int) -> void:
	if ammo_label:
		ammo_label.text = "MISSILES  %d / %d" % [current, maximum]
		if current <= 0:
			GameStyle.apply_label(ammo_label, GameStyle.TEXT_MUTED, 13)
		else:
			GameStyle.apply_label(ammo_label, GameStyle.ACCENT, 13)
