extends CanvasLayer
## Comic-style in-race HUD for 3D DeathRace.
## Top-left health/timer/lap, top-right position/alive, bottom-left missiles,
## bottom-right minimap and track progress.

const DATA_BOX_TEXTURE: Texture2D = preload("res://assets/ui/hud/datas_box.png")
const SURVIVOR_SKULL_TEXTURE: Texture2D = preload("res://assets/ui/hud/skull-yellow.png")
const MISSILE_BOX_TEXTURE: Texture2D = preload("res://assets/ui/hud/missiles-box.png")
const HP_BAR_TEXTURE: Texture2D = preload("res://assets/ui/hud/hp-bar.png")
const MINIMAP_TEXTURE: Texture2D = preload("res://assets/ui/hud/minimap.png")
const AMMO_EMPTY_COLOR := Color("8f8a80")
const AMMO_READY_COLOR := Color("ff2b9d")
const AMMO_FULL_COLOR := Color("76f04b")
const DATA_BOX_SHADER := """
shader_type canvas_item;

void fragment() {
	vec4 pixel = texture(TEXTURE, UV);
	float inside_x = smoothstep(0.07, 0.12, UV.x) * (1.0 - smoothstep(0.88, 0.93, UV.x));
	float inside_y = smoothstep(0.10, 0.18, UV.y) * (1.0 - smoothstep(0.82, 0.90, UV.y));
	float darkness = 1.0 - smoothstep(0.04, 0.20, max(pixel.r, max(pixel.g, pixel.b)));
	pixel.a *= mix(1.0, 0.70, inside_x * inside_y * darkness);
	COLOR = pixel * COLOR;
}
"""

var _player: Vehicle = null
var _elapsed: float = 0.0
var _running: bool = true
var _last_hp: float = -1.0
var _last_ammo: int = 0

var timer_label: Label
var hp_bar: TextureRect
var hp_display: Control
var hp_segments: HPFillSegments
var lap_label: Label
var lap_panel: Control
var lap_bar: ProgressBar
var alive_label: Label
var alive_count_label: Label
var hint_label: Label
var place_label: Label
var place_total_label: Label
var place_panel: Control
var missile_display: Control
var missile_count_label: Label
var minimap: Minimap3D


func _ready() -> void:
	layer = 20
	_build()
	var laps := MatchConfig.uses_laps()
	lap_panel.visible = laps
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
	if alive_count_label:
		alive_count_label.text = str(n)


func update_position(place: int, total: int) -> void:
	if place_label == null:
		return
	place_label.text = _ordinal(place)
	place_total_label.text = "OF %d" % total


func stop() -> void:
	_running = false


func set_running(running: bool) -> void:
	_running = running


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

	# ---- Top-left: health, timer, lap ----
	hp_display = Control.new()
	hp_display.position = Vector2(16, 14)
	hp_display.size = Vector2(350, 53)
	hp_display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hp_display)

	hp_segments = HPFillSegments.new()
	hp_segments.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hp_segments.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hp_display.add_child(hp_segments)

	hp_bar = TextureRect.new()
	hp_bar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hp_bar.texture = HP_BAR_TEXTURE
	hp_bar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	hp_bar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hp_display.add_child(hp_bar)

	var timer_panel := _make_data_panel(Vector2(205, 56))
	timer_panel.position = Vector2(16, 72)
	root.add_child(timer_panel)
	var timer_row := HBoxContainer.new()
	timer_row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	timer_row.offset_left = 18
	timer_row.offset_top = 4
	timer_row.offset_right = -18
	timer_row.offset_bottom = -4
	timer_row.alignment = BoxContainer.ALIGNMENT_CENTER
	timer_row.add_theme_constant_override("separation", 10)
	timer_panel.add_child(timer_row)
	var stopwatch := StopwatchIcon.new()
	stopwatch.custom_minimum_size = Vector2(27, 31)
	stopwatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	timer_row.add_child(stopwatch)
	timer_label = Label.new()
	timer_label.text = "00:00.00"
	GameStyle.apply_title(timer_label, GameStyle.TEXT, 24)
	timer_row.add_child(timer_label)

	lap_panel = _make_data_panel(Vector2(150, 46))
	lap_panel.position = Vector2(16, 132)
	root.add_child(lap_panel)
	var lap_row := HBoxContainer.new()
	lap_row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lap_row.offset_left = 18
	lap_row.offset_top = 4
	lap_row.offset_right = -18
	lap_row.offset_bottom = -4
	lap_row.alignment = BoxContainer.ALIGNMENT_CENTER
	lap_row.add_theme_constant_override("separation", 5)
	lap_panel.add_child(lap_row)
	var lap_title := Label.new()
	lap_title.text = "LAP"
	GameStyle.apply_title(lap_title, GameStyle.TEXT, 16)
	lap_row.add_child(lap_title)
	lap_label = Label.new()
	lap_label.text = "0"
	GameStyle.apply_title(lap_label, GameStyle.SKY, 24)
	lap_row.add_child(lap_label)
	var lap_total := Label.new()
	lap_total.text = "/%d" % MatchConfig.lap_count
	GameStyle.apply_title(lap_total, GameStyle.TEXT, 17)
	lap_row.add_child(lap_total)

	# ---- Top-right: position + alive ----
	var right := Control.new()
	right.anchor_left = 1.0
	right.anchor_right = 1.0
	right.offset_left = -221
	right.offset_right = -16
	right.offset_top = 14
	right.offset_bottom = 120
	root.add_child(right)

	place_panel = _make_data_panel(Vector2(205, 56))
	place_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	place_panel.position = Vector2.ZERO
	place_panel.size = Vector2(205, 56)
	right.add_child(place_panel)

	var place_row := HBoxContainer.new()
	place_row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	place_row.offset_left = 22
	place_row.offset_top = 4
	place_row.offset_right = -22
	place_row.offset_bottom = -4
	place_row.alignment = BoxContainer.ALIGNMENT_CENTER
	place_row.add_theme_constant_override("separation", 14)
	place_panel.add_child(place_row)

	place_label = Label.new()
	place_label.text = "--"
	place_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	GameStyle.apply_title(place_label, GameStyle.ACCENT, 30)
	place_row.add_child(place_label)

	place_total_label = Label.new()
	place_total_label.text = "OF 4"
	place_total_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	GameStyle.apply_title(place_total_label, GameStyle.TEXT_MUTED, 14)
	place_row.add_child(place_total_label)

	var alive_panel := _make_data_panel(Vector2(175, 46))
	alive_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	alive_panel.position = Vector2(30, 60)
	alive_panel.size = Vector2(175, 46)
	right.add_child(alive_panel)

	var skull := TextureRect.new()
	skull.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	skull.offset_left = 138
	skull.offset_top = 9
	skull.offset_right = -12
	skull.offset_bottom = -9
	skull.texture = SURVIVOR_SKULL_TEXTURE
	skull.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	skull.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	skull.mouse_filter = Control.MOUSE_FILTER_IGNORE
	alive_panel.add_child(skull)

	var alive_row := HBoxContainer.new()
	alive_row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	alive_row.offset_left = 18
	alive_row.offset_top = 4
	alive_row.offset_right = -42
	alive_row.offset_bottom = -4
	alive_row.alignment = BoxContainer.ALIGNMENT_CENTER
	alive_row.add_theme_constant_override("separation", 8)
	alive_panel.add_child(alive_row)

	alive_label = Label.new()
	alive_label.text = "ALIVE"
	alive_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	GameStyle.apply_title(alive_label, GameStyle.TEXT, 16)
	alive_row.add_child(alive_label)

	alive_count_label = Label.new()
	alive_count_label.text = "1"
	alive_count_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	GameStyle.apply_title(alive_count_label, GameStyle.WARNING, 18)
	alive_row.add_child(alive_count_label)

	# ---- Bottom-left: missile ammo ----
	missile_display = Control.new()
	missile_display.anchor_top = 1.0
	missile_display.anchor_bottom = 1.0
	missile_display.offset_left = 16
	missile_display.offset_top = -222
	missile_display.offset_right = 196
	missile_display.offset_bottom = -16
	missile_display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(missile_display)

	var missile_art := TextureRect.new()
	missile_art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	missile_art.texture = MISSILE_BOX_TEXTURE
	missile_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	missile_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	missile_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	missile_display.add_child(missile_art)

	missile_count_label = Label.new()
	missile_count_label.position = Vector2(119, 109)
	missile_count_label.size = Vector2(50, 50)
	missile_count_label.text = "0"
	missile_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	missile_count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	missile_count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	GameStyle.apply_title(missile_count_label, AMMO_EMPTY_COLOR, 29)
	missile_count_label.add_theme_constant_override("outline_size", 7)
	missile_display.add_child(missile_count_label)

	# Keep track progress directly above the minimap until its final visual pass.
	lap_bar = ProgressBar.new()
	lap_bar.anchor_left = 1.0
	lap_bar.anchor_right = 1.0
	lap_bar.anchor_top = 1.0
	lap_bar.anchor_bottom = 1.0
	lap_bar.offset_left = -232
	lap_bar.offset_right = -16
	lap_bar.offset_top = -266
	lap_bar.offset_bottom = -256
	lap_bar.max_value = 1.0
	lap_bar.show_percentage = false
	var lap_bg := GameStyle.progress_bg()
	lap_bg.border_color = GameStyle.INK
	lap_bg.set_border_width_all(2)
	lap_bar.add_theme_stylebox_override("background", lap_bg)
	lap_bar.add_theme_stylebox_override("fill", GameStyle.progress_fill(GameStyle.SKY))
	root.add_child(lap_bar)

	# ---- Bottom-right minimap ----
	var map_panel := Control.new()
	map_panel.anchor_left = 1.0
	map_panel.anchor_right = 1.0
	map_panel.anchor_top = 1.0
	map_panel.anchor_bottom = 1.0
	map_panel.offset_left = -232
	map_panel.offset_right = -16
	map_panel.offset_top = -254
	map_panel.offset_bottom = -16
	map_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(map_panel)
	var map_art := TextureRect.new()
	map_art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	map_art.texture = MINIMAP_TEXTURE
	map_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	map_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	map_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_panel.add_child(map_art)
	minimap = Minimap3D.new()
	minimap.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	minimap.mouse_filter = Control.MOUSE_FILTER_IGNORE
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


func _make_data_panel(panel_size: Vector2) -> TextureRect:
	var panel := TextureRect.new()
	panel.texture = DATA_BOX_TEXTURE
	panel.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	panel.stretch_mode = TextureRect.STRETCH_SCALE
	panel.custom_minimum_size = Vector2.ZERO
	panel.size = panel_size
	var shader := Shader.new()
	shader.code = DATA_BOX_SHADER
	var shader_material := ShaderMaterial.new()
	shader_material.shader = shader
	panel.material = shader_material
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return panel
func _process(delta: float) -> void:
	if not _running:
		return
	_elapsed += delta
	var m := int(_elapsed) / 60
	var s := int(_elapsed) % 60
	var ms := int(fmod(_elapsed, 1.0) * 100.0)
	timer_label.text = "%02d:%02d.%02d" % [m, s, ms]
	if _player and is_instance_valid(_player) and _player.is_alive and MatchConfig.uses_laps():
		lap_label.text = str(mini(_player.laps_completed + 1, MatchConfig.lap_count))
		lap_bar.value = _player.get_lap_progress_ratio()


func _on_hp(current: float, maximum: float) -> void:
	if hp_display == null or hp_segments == null:
		return
	var ratio := current / maxf(maximum, 1.0)
	hp_segments.set_ratio(ratio)
	# Damage flash
	if _last_hp >= 0.0 and current < _last_hp:
		hp_display.modulate = Color(1.6, 0.7, 0.7)
		var tw := create_tween()
		tw.tween_property(hp_display, "modulate", Color.WHITE, 0.3)
	_last_hp = current


func _on_ammo(current: int, maximum: int) -> void:
	if missile_display == null or missile_count_label == null:
		return
	var gained := current > _last_ammo
	_last_ammo = current
	missile_count_label.text = str(current)
	var counter_color := AMMO_EMPTY_COLOR
	if current > 0:
		counter_color = AMMO_FULL_COLOR if maximum > 0 and current >= maximum else AMMO_READY_COLOR
	missile_count_label.add_theme_color_override("font_color", counter_color)
	if gained:
		missile_display.pivot_offset = missile_display.size * 0.5
		missile_display.scale = Vector2(1.12, 1.12)
		var tw := create_tween()
		tw.tween_property(missile_display, "scale", Vector2.ONE, 0.25) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)


class StopwatchIcon extends Control:
	func _draw() -> void:
		var ink := GameStyle.INK
		var face := GameStyle.TEXT
		var center := Vector2(13.5, 17.0)
		draw_arc(center, 10.0, 0.0, TAU, 28, ink, 5.0, true)
		draw_arc(center, 10.0, 0.0, TAU, 28, face, 2.2, true)
		draw_line(Vector2(10.0, 4.0), Vector2(17.0, 4.0), ink, 5.0, true)
		draw_line(Vector2(10.0, 4.0), Vector2(17.0, 4.0), face, 2.2, true)
		draw_line(Vector2(13.5, 4.0), Vector2(13.5, 7.0), face, 2.2, true)
		draw_line(center, Vector2(13.5, 10.0), face, 2.0, true)
		draw_line(center, Vector2(18.5, 17.0), face, 2.0, true)


class HPFillSegments extends Control:
	const SEGMENT_COUNT := 14
	var ratio: float = 1.0

	func set_ratio(value: float) -> void:
		ratio = clampf(value, 0.0, 1.0)
		queue_redraw()

	func _draw() -> void:
		var filled_count := ceili(ratio * float(SEGMENT_COUNT))
		var start_x := size.x * 0.145
		var end_x := size.x * 0.955
		var segment_width := (end_x - start_x) / float(SEGMENT_COUNT)
		var top := size.y * 0.27
		var bottom := size.y * 0.80
		for index in SEGMENT_COUNT:
			var x := start_x + float(index) * segment_width
			var color := Color("#d9251d") if index < filled_count else Color("#252326")
			# The source frame contains the exact angled transparent openings and
			# opaque separators. Rectangles behind it are clipped into those shapes.
			draw_rect(Rect2(x - 1.0, top, segment_width + 2.0, bottom - top), color, true)
