extends CanvasLayer
## Comic-style in-race HUD for 3D DeathRace.
## Top-left stat card (timer, chips, HP, missile pips, lap), top-right position
## + alive, bottom-right minimap, bottom-center fading hint.

var _player: Vehicle = null
var _elapsed: float = 0.0
var _running: bool = true
var _last_hp: float = -1.0

var timer_label: Label
var hp_bar: ProgressBar
var lap_label: Label
var lap_bar: ProgressBar
var alive_label: Label
var mode_label: Label
var track_label: Label
var hint_label: Label
var place_label: Label
var place_total_label: Label
var place_panel: PanelContainer
var missile_pips: MissilePips
var minimap: Minimap3D


func _ready() -> void:
	layer = 20
	_build()
	mode_label.text = MatchConfig.mode_display_name().to_upper()
	track_label.text = MatchConfig.track_display_name()
	var laps := MatchConfig.uses_laps()
	lap_label.visible = laps
	lap_bar.visible = laps
	if place_panel:
		place_panel.visible = laps


func set_player(player: Vehicle) -> void:
	_player = player
	if _player:
		if not _player.health_changed.is_connected(_on_hp):
			_player.health_changed.connect(_on_hp)
		if not _player.ammo_changed.is_connected(_on_ammo):
			_player.ammo_changed.connect(_on_ammo)
		_last_hp = _player.health
		_on_hp(_player.health, _player.max_health)
		_on_ammo(_player.missile_ammo, _player.max_missile_ammo)


func set_race_path(path: Path3D) -> void:
	if minimap:
		minimap.setup(path, _player)


func update_alive(n: int) -> void:
	if alive_label:
		alive_label.text = "ALIVE  %d" % n


func update_position(place: int, total: int) -> void:
	if place_label == null:
		return
	place_label.text = _ordinal(place)
	place_total_label.text = "of %d" % total


func stop() -> void:
	_running = false


func get_elapsed() -> float:
	return _elapsed


func _ordinal(n: int) -> String:
	match n:
		1: return "1ST"
		2: return "2ND"
		3: return "3RD"
		_: return "%dTH" % n


func _build() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# ---- Top-left stat card ----
	var panel := PanelContainer.new()
	panel.position = Vector2(16, 14)
	panel.add_theme_stylebox_override("panel", GameStyle.comic_panel(Color(0.10, 0.13, 0.09, 0.95), 14.0))
	root.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	var margin := MarginContainer.new()
	for s in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(s, 12)
	margin.add_child(v)
	panel.add_child(margin)

	timer_label = Label.new()
	timer_label.text = "00:00.00"
	GameStyle.apply_title(timer_label, GameStyle.TEXT, 26)
	v.add_child(timer_label)

	var chips := HBoxContainer.new()
	chips.add_theme_constant_override("separation", 6)
	v.add_child(chips)

	var mode_chip := PanelContainer.new()
	mode_chip.add_theme_stylebox_override("panel", GameStyle.comic_panel(GameStyle.ACCENT_DIM.darkened(0.25), 8.0))
	chips.add_child(mode_chip)
	mode_label = Label.new()
	GameStyle.apply_label(mode_label, GameStyle.ACCENT, 12)
	mode_chip.add_child(mode_label)

	var track_chip := PanelContainer.new()
	track_chip.add_theme_stylebox_override("panel", GameStyle.comic_panel(Color(0.14, 0.18, 0.13, 0.95), 8.0))
	chips.add_child(track_chip)
	track_label = Label.new()
	GameStyle.apply_label(track_label, GameStyle.TEXT_MUTED, 12)
	track_chip.add_child(track_label)

	var hp_row := HBoxContainer.new()
	hp_row.add_theme_constant_override("separation", 8)
	v.add_child(hp_row)
	var hp_tag := Label.new()
	hp_tag.text = "HP"
	GameStyle.apply_title(hp_tag, GameStyle.SUCCESS, 15)
	hp_row.add_child(hp_tag)
	hp_bar = ProgressBar.new()
	hp_bar.custom_minimum_size = Vector2(190, 20)
	hp_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hp_bar.max_value = 100
	hp_bar.value = 100
	hp_bar.show_percentage = false
	var hp_bg := GameStyle.progress_bg()
	hp_bg.border_color = GameStyle.INK
	hp_bg.set_border_width_all(3)
	hp_bar.add_theme_stylebox_override("background", hp_bg)
	hp_bar.add_theme_stylebox_override("fill", GameStyle.progress_fill(GameStyle.SUCCESS))
	hp_row.add_child(hp_bar)

	missile_pips = MissilePips.new()
	missile_pips.custom_minimum_size = Vector2(190, 26)
	v.add_child(missile_pips)

	lap_label = Label.new()
	lap_label.text = "LAP 0 / %d" % MatchConfig.lap_count
	GameStyle.apply_title(lap_label, GameStyle.SKY, 14)
	v.add_child(lap_label)

	lap_bar = ProgressBar.new()
	lap_bar.custom_minimum_size = Vector2(190, 10)
	lap_bar.max_value = 1.0
	lap_bar.show_percentage = false
	var lap_bg := GameStyle.progress_bg()
	lap_bg.border_color = GameStyle.INK
	lap_bg.set_border_width_all(2)
	lap_bar.add_theme_stylebox_override("background", lap_bg)
	lap_bar.add_theme_stylebox_override("fill", GameStyle.progress_fill(GameStyle.SKY))
	v.add_child(lap_bar)

	# ---- Top-right: position + alive ----
	var right := VBoxContainer.new()
	right.anchor_left = 1.0
	right.anchor_right = 1.0
	right.offset_left = -190
	right.offset_right = -16
	right.offset_top = 14
	right.add_theme_constant_override("separation", 8)
	root.add_child(right)

	place_panel = PanelContainer.new()
	place_panel.add_theme_stylebox_override("panel", GameStyle.comic_panel(Color(0.10, 0.13, 0.09, 0.95), 14.0))
	right.add_child(place_panel)
	var place_row := HBoxContainer.new()
	place_row.alignment = BoxContainer.ALIGNMENT_CENTER
	place_row.add_theme_constant_override("separation", 8)
	place_panel.add_child(place_row)
	place_label = Label.new()
	place_label.text = "--"
	GameStyle.apply_title(place_label, GameStyle.ACCENT, 38)
	place_row.add_child(place_label)
	place_total_label = Label.new()
	place_total_label.text = ""
	place_total_label.size_flags_vertical = Control.SIZE_SHRINK_END
	GameStyle.apply_label(place_total_label, GameStyle.TEXT_MUTED, 15)
	place_row.add_child(place_total_label)

	var alive_panel := PanelContainer.new()
	alive_panel.add_theme_stylebox_override("panel", GameStyle.comic_panel(Color(0.16, 0.10, 0.07, 0.95), 10.0))
	right.add_child(alive_panel)
	alive_label = Label.new()
	alive_label.text = "ALIVE  1"
	alive_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	GameStyle.apply_title(alive_label, GameStyle.WARNING, 16)
	alive_panel.add_child(alive_label)

	# ---- Bottom-right minimap ----
	var map_panel := PanelContainer.new()
	map_panel.anchor_left = 1.0
	map_panel.anchor_right = 1.0
	map_panel.anchor_top = 1.0
	map_panel.anchor_bottom = 1.0
	map_panel.offset_left = -196
	map_panel.offset_right = -16
	map_panel.offset_top = -196
	map_panel.offset_bottom = -16
	map_panel.add_theme_stylebox_override("panel", GameStyle.comic_panel(Color(0.10, 0.13, 0.09, 0.95), 14.0))
	root.add_child(map_panel)
	minimap = Minimap3D.new()
	minimap.custom_minimum_size = Vector2(160, 160)
	map_panel.add_child(minimap)

	# ---- Bottom-center hint ----
	hint_label = Label.new()
	hint_label.text = "WASD drive  ·  Pick up crates for missiles  ·  Space fire  ·  Esc setup"
	hint_label.anchor_left = 0.5
	hint_label.anchor_top = 1.0
	hint_label.anchor_right = 0.5
	hint_label.anchor_bottom = 1.0
	hint_label.offset_left = -240
	hint_label.offset_right = 240
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
	# Damage flash
	if _last_hp >= 0.0 and current < _last_hp:
		hp_bar.modulate = Color(1.6, 0.7, 0.7)
		var tw := create_tween()
		tw.tween_property(hp_bar, "modulate", Color.WHITE, 0.3)
	_last_hp = current


func _on_ammo(current: int, maximum: int) -> void:
	if missile_pips == null:
		return
	var gained := current > missile_pips.filled
	missile_pips.set_ammo(current, maximum)
	if gained:
		missile_pips.pivot_offset = missile_pips.size * 0.5
		missile_pips.scale = Vector2(1.18, 1.18)
		var tw := create_tween()
		tw.tween_property(missile_pips, "scale", Vector2.ONE, 0.25) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)


class MissilePips extends Control:
	## Icon-based ammo: filled/empty missile silhouettes with ink outlines.
	var filled: int = 0
	var total: int = 3

	func set_ammo(current: int, maximum: int) -> void:
		filled = current
		total = maxi(maximum, 1)
		queue_redraw()

	func _draw() -> void:
		var pip_w := 26.0
		var pip_h := minf(size.y, 24.0)
		var gap := 8.0
		var y := (size.y - pip_h) * 0.5
		for i in total:
			var x := float(i) * (pip_w + gap)
			var is_full := i < filled
			_draw_missile(Rect2(x, y, pip_w, pip_h), is_full)

	func _draw_missile(r: Rect2, full: bool) -> void:
		var body_color := GameStyle.ACCENT if full else Color(0.25, 0.24, 0.20, 0.9)
		var cy := r.position.y + r.size.y * 0.5
		var body_h := r.size.y * 0.46
		var nose_w := r.size.x * 0.3
		var body := Rect2(r.position.x + r.size.x * 0.12, cy - body_h * 0.5, r.size.x * 0.55, body_h)
		var nose := PackedVector2Array([
			Vector2(body.end.x, cy - body_h * 0.5),
			Vector2(body.end.x + nose_w, cy),
			Vector2(body.end.x, cy + body_h * 0.5),
		])
		var fin_top := PackedVector2Array([
			Vector2(body.position.x, cy - body_h * 0.5),
			Vector2(body.position.x - r.size.x * 0.1, cy - body_h * 1.0),
			Vector2(body.position.x + r.size.x * 0.14, cy - body_h * 0.5),
		])
		var fin_bot := PackedVector2Array([
			Vector2(body.position.x, cy + body_h * 0.5),
			Vector2(body.position.x - r.size.x * 0.1, cy + body_h * 1.0),
			Vector2(body.position.x + r.size.x * 0.14, cy + body_h * 0.5),
		])
		# Ink outline pass (slightly inflated)
		var ink := GameStyle.INK
		draw_rect(body.grow(2.0), ink, true)
		draw_colored_polygon(_inflate(nose, Vector2(body.end.x + nose_w * 0.5, cy)), ink)
		draw_colored_polygon(_inflate(fin_top, Vector2(body.position.x, cy - body_h * 0.75)), ink)
		draw_colored_polygon(_inflate(fin_bot, Vector2(body.position.x, cy + body_h * 0.75)), ink)
		# Color fill
		draw_rect(body, body_color, true)
		draw_colored_polygon(nose, body_color)
		draw_colored_polygon(fin_top, body_color)
		draw_colored_polygon(fin_bot, body_color)

	func _inflate(points: PackedVector2Array, center: Vector2) -> PackedVector2Array:
		var out := PackedVector2Array()
		for p in points:
			out.append(center + (p - center) * 1.25 + (p - center).normalized() * 1.2)
		return out
