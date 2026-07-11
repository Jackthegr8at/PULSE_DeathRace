extends CanvasLayer
## In-race HUD matching concept art layout (assets/concept/2.jpg).

var _elapsed: float = 0.0
var _running: bool = true
var _player: Car = null
var _track: Track = null

var hp_bar: ProgressBar
var speed_pips: Array[ColorRect] = []
var missile_icons: Array[ColorRect] = []
var timer_label: Label
var mode_label: Label
var lap_label: Label
var lap_bar: ProgressBar
var alive_label: Label
var place_label: Label
var lead_label: Label
var nitro_segments: Array[ColorRect] = []
var minimap: Minimap
var controls_hint: Label
var lap_block: Control


func _ready() -> void:
	layer = 10
	_build_ui()
	mode_label.text = MatchConfig.mode_display_name().to_upper()
	lap_block.visible = MatchConfig.uses_laps()
	_refresh_hp(100.0, 100.0)
	_refresh_alive(5)
	_refresh_missiles(3, 4)
	_set_speed_pips(2)
	_set_nitro(3, 5)


func setup(track: Track, player: Car) -> void:
	_track = track
	set_player(player)
	if minimap:
		minimap.setup(track, player)


func set_player(player: Car) -> void:
	_player = player
	if _player == null:
		return
	if not _player.health_changed.is_connected(_on_player_health):
		_player.health_changed.connect(_on_player_health)
	if not _player.lap_completed.is_connected(_on_player_lap):
		_player.lap_completed.connect(_on_player_lap)
	_refresh_hp(_player.health, _player.max_health)
	_refresh_laps(_player.laps_completed)


func stop() -> void:
	_running = false


func update_alive(count: int) -> void:
	_refresh_alive(count)


func _build_ui() -> void:
	var root := Control.new()
	root.name = "Root"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# --- Top left stack ---
	var tl := VBoxContainer.new()
	tl.position = Vector2(16, 14)
	tl.add_theme_constant_override("separation", 8)
	tl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(tl)

	# HP row: car pip + bar
	var hp_row := _glass_panel()
	var hp_h := HBoxContainer.new()
	hp_h.add_theme_constant_override("separation", 10)
	var car_pip := ColorRect.new()
	car_pip.custom_minimum_size = Vector2(28, 14)
	car_pip.color = GameStyle.SUCCESS
	hp_h.add_child(car_pip)
	hp_bar = ProgressBar.new()
	hp_bar.custom_minimum_size = Vector2(160, 14)
	hp_bar.show_percentage = false
	hp_bar.max_value = 100
	hp_bar.value = 100
	_style_bar(hp_bar, GameStyle.SUCCESS)
	hp_h.add_child(hp_bar)
	_panel_margin(hp_row, hp_h)
	tl.add_child(hp_row)

	# Speed pips (concept art left)
	var speed_panel := _glass_panel()
	var speed_h := HBoxContainer.new()
	speed_h.add_theme_constant_override("separation", 4)
	speed_pips.clear()
	for i in 4:
		var pip := ColorRect.new()
		pip.custom_minimum_size = Vector2(18, 10)
		pip.color = GameStyle.INFO if i < 2 else Color(0.15, 0.2, 0.28)
		speed_pips.append(pip)
		speed_h.add_child(pip)
	_panel_margin(speed_panel, speed_h)
	tl.add_child(speed_panel)

	# Missile ammo
	var msl_panel := _glass_panel()
	var msl_h := HBoxContainer.new()
	msl_h.add_theme_constant_override("separation", 6)
	missile_icons.clear()
	for i in 4:
		var m := ColorRect.new()
		m.custom_minimum_size = Vector2(22, 9)
		m.color = GameStyle.ACCENT
		missile_icons.append(m)
		msl_h.add_child(m)
	_panel_margin(msl_panel, msl_h)
	tl.add_child(msl_panel)

	# Timer + mode
	var info_row := HBoxContainer.new()
	info_row.add_theme_constant_override("separation", 8)
	var t_panel := _glass_panel()
	timer_label = Label.new()
	timer_label.text = "00:00.00"
	GameStyle.apply_label(timer_label, GameStyle.TEXT, 16)
	_panel_margin(t_panel, timer_label)
	info_row.add_child(t_panel)
	var mode_panel := _glass_panel()
	mode_label = Label.new()
	mode_label.text = "HYBRID"
	GameStyle.apply_label(mode_label, GameStyle.PURPLE, 12)
	_panel_margin(mode_panel, mode_label)
	info_row.add_child(mode_panel)
	tl.add_child(info_row)

	# Lap block
	lap_block = _glass_panel()
	var lap_v := VBoxContainer.new()
	lap_v.add_theme_constant_override("separation", 4)
	lap_label = Label.new()
	lap_label.text = "LAP 0 / 5"
	GameStyle.apply_label(lap_label, GameStyle.INFO, 12)
	lap_v.add_child(lap_label)
	lap_bar = ProgressBar.new()
	lap_bar.custom_minimum_size = Vector2(180, 10)
	lap_bar.max_value = 1.0
	lap_bar.show_percentage = false
	_style_bar(lap_bar, GameStyle.INFO)
	lap_v.add_child(lap_bar)
	_panel_margin(lap_block, lap_v)
	tl.add_child(lap_block)

	# --- Top right: minimap + LEAD ---
	var tr := VBoxContainer.new()
	tr.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	tr.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	tr.position = Vector2(-16, 14)
	tr.offset_left = -160
	tr.offset_right = -16
	tr.offset_top = 14
	tr.offset_bottom = 200
	# Anchor properly
	tr.anchor_left = 1.0
	tr.anchor_right = 1.0
	tr.anchor_top = 0.0
	tr.anchor_bottom = 0.0
	tr.offset_left = -156
	tr.offset_right = -16
	tr.offset_top = 14
	tr.offset_bottom = 220
	tr.add_theme_constant_override("separation", 8)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(tr)

	var mm_panel := _glass_panel()
	minimap = Minimap.new()
	minimap.custom_minimum_size = Vector2(128, 128)
	_panel_margin(mm_panel, minimap)
	tr.add_child(mm_panel)

	var lead_panel := _glass_panel()
	lead_label = Label.new()
	lead_label.text = "LEAD  >"
	lead_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	GameStyle.apply_label(lead_label, GameStyle.ACCENT, 14)
	_panel_margin(lead_panel, lead_label)
	tr.add_child(lead_panel)

	# --- Bottom left: alive + place ---
	var bl := VBoxContainer.new()
	bl.anchor_left = 0.0
	bl.anchor_top = 1.0
	bl.anchor_right = 0.0
	bl.anchor_bottom = 1.0
	bl.offset_left = 16
	bl.offset_top = -100
	bl.offset_right = 180
	bl.offset_bottom = -16
	bl.add_theme_constant_override("separation", 8)
	bl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bl)

	var alive_panel := _glass_panel()
	alive_label = Label.new()
	alive_label.text = "3 / 5  ALIVE"
	GameStyle.apply_label(alive_label, GameStyle.PINK, 13)
	_panel_margin(alive_panel, alive_label)
	bl.add_child(alive_panel)

	var place_panel := _glass_panel()
	place_label = Label.new()
	place_label.text = "1st  PLACE"
	GameStyle.apply_label(place_label, GameStyle.ACCENT, 13)
	_panel_margin(place_panel, place_label)
	bl.add_child(place_panel)

	# --- Bottom right: vertical NITRO ---
	var br := VBoxContainer.new()
	br.anchor_left = 1.0
	br.anchor_top = 1.0
	br.anchor_right = 1.0
	br.anchor_bottom = 1.0
	br.offset_left = -70
	br.offset_top = -200
	br.offset_right = -16
	br.offset_bottom = -16
	br.add_theme_constant_override("separation", 6)
	br.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(br)

	var nitro_panel := _glass_panel()
	var nitro_box := VBoxContainer.new()
	nitro_box.add_theme_constant_override("separation", 3)
	nitro_box.alignment = BoxContainer.ALIGNMENT_END
	var nitro_title := Label.new()
	nitro_title.text = "NITRO"
	nitro_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	GameStyle.apply_label(nitro_title, GameStyle.INFO, 10)
	nitro_box.add_child(nitro_title)
	nitro_segments.clear()
	# Vertical stack top = full
	for i in 5:
		var seg := ColorRect.new()
		seg.custom_minimum_size = Vector2(18, 18)
		seg.color = GameStyle.INFO
		nitro_segments.append(seg)
		nitro_box.add_child(seg)
	# reverse visual order: first child is top = full end of stack
	_panel_margin(nitro_panel, nitro_box)
	br.add_child(nitro_panel)

	# Center painted title banner
	var title_panel := PanelContainer.new()
	title_panel.anchor_left = 0.5
	title_panel.anchor_right = 0.5
	title_panel.offset_left = -170
	title_panel.offset_right = 170
	title_panel.offset_top = 14
	title_panel.offset_bottom = 58
	title_panel.add_theme_stylebox_override(
		"panel", GameStyle.concept_panel(GameStyle.WOOD, GameStyle.INK, 12.0, 3.0)
	)
	title_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var title := Label.new()
	title.text = "PULSE DEATHRACE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	GameStyle.apply_label(title, GameStyle.TEXT, 20)
	title.add_theme_color_override("font_outline_color", GameStyle.INK)
	title.add_theme_constant_override("outline_size", 4)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_panel.add_child(title)
	root.add_child(title_panel)

	# Controls hint bottom center
	controls_hint = Label.new()
	controls_hint.text = "WASD drive  ·  Space fire  ·  Coast to turn sharper"
	controls_hint.anchor_left = 0.5
	controls_hint.anchor_top = 1.0
	controls_hint.anchor_right = 0.5
	controls_hint.anchor_bottom = 1.0
	controls_hint.offset_left = -260
	controls_hint.offset_right = 260
	controls_hint.offset_top = -36
	controls_hint.offset_bottom = -14
	controls_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	GameStyle.apply_label(controls_hint, GameStyle.TEXT_DIM, 12)
	controls_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(controls_hint)

	var tw := create_tween()
	tw.tween_interval(4.0)
	tw.tween_property(controls_hint, "modulate:a", 0.0, 1.2)


func _glass_panel() -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", GameStyle.glass_chip())
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


func _panel_margin(panel: PanelContainer, child: Control) -> void:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 10)
	m.add_theme_constant_override("margin_right", 10)
	m.add_theme_constant_override("margin_top", 8)
	m.add_theme_constant_override("margin_bottom", 8)
	m.add_child(child)
	panel.add_child(m)


func _style_bar(bar: ProgressBar, fill: Color) -> void:
	bar.show_percentage = false
	bar.add_theme_stylebox_override("background", GameStyle.progress_bg())
	bar.add_theme_stylebox_override("fill", GameStyle.progress_fill(fill))


func _process(delta: float) -> void:
	if not _running:
		return
	_elapsed += delta
	var minutes := int(_elapsed) / 60
	var seconds := int(_elapsed) % 60
	var ms := int(fmod(_elapsed, 1.0) * 100.0)
	timer_label.text = "%02d:%02d.%02d" % [minutes, seconds, ms]

	if _player and is_instance_valid(_player) and _player.is_alive:
		var spd_ratio := absf(_player._speed) / maxf(_player.max_speed, 1.0)
		_set_speed_pips(int(round(spd_ratio * 4.0)))
		if MatchConfig.uses_laps():
			var ratio := _player.get_lap_progress_ratio()
			lap_label.text = "LAP %d / %d" % [_player.laps_completed, MatchConfig.lap_count]
			lap_bar.value = ratio


func _on_player_health(current: float, maximum: float) -> void:
	_refresh_hp(current, maximum)


func _on_player_lap(_car: Car, laps: int) -> void:
	_refresh_laps(laps)


func _refresh_hp(current: float, maximum: float) -> void:
	if hp_bar == null:
		return
	hp_bar.max_value = maximum
	hp_bar.value = current
	var ratio := current / maxf(maximum, 1.0)
	hp_bar.add_theme_stylebox_override("fill", GameStyle.progress_fill(GameStyle.hp_color(ratio)))


func _refresh_laps(current: int) -> void:
	if MatchConfig.uses_laps():
		lap_label.text = "LAP %d / %d" % [current, MatchConfig.lap_count]
	else:
		lap_label.text = "LAPS OFF"


func _refresh_alive(count: int) -> void:
	if alive_label:
		alive_label.text = "%d / 5  ALIVE" % count
	if place_label:
		# Rough place: by alive order (player wins place when fewer alive)
		if _player and is_instance_valid(_player) and _player.is_alive:
			place_label.text = "RACING"
			if count <= 1:
				place_label.text = "1st  PLACE"
				lead_label.text = "LEAD  >"
			elif count == 2:
				place_label.text = "TOP 2"
			else:
				place_label.text = "FIELD"


func _refresh_missiles(ready: int, total: int) -> void:
	for i in missile_icons.size():
		if i < ready:
			missile_icons[i].color = GameStyle.ACCENT
			missile_icons[i].modulate.a = 1.0
		elif i < total:
			missile_icons[i].color = GameStyle.ACCENT
			missile_icons[i].modulate.a = 0.25
		else:
			missile_icons[i].modulate.a = 0.15


func _set_speed_pips(n: int) -> void:
	for i in speed_pips.size():
		speed_pips[i].color = GameStyle.INFO if i < n else Color(0.12, 0.16, 0.22)


func _set_nitro(filled: int, total: int) -> void:
	# segments[0] is top of VBox = "full" end visually last filled from bottom
	for i in nitro_segments.size():
		# bottom segment = last child = index total-1 should light first
		var from_bottom := total - 1 - i
		nitro_segments[i].color = GameStyle.INFO if from_bottom < filled else Color(0.1, 0.14, 0.18)
