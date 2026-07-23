extends CanvasLayer
## Responsive comic-metal post-race results presentation.

signal rematch_requested
signal setup_requested

const DESIGN_SIZE := Vector2(820.0, 650.0)
const VIEWPORT_MARGIN := Vector2(28.0, 22.0)
const DATA_BOX_SHADER := """
shader_type canvas_item;

void fragment() {
	vec4 pixel = texture(TEXTURE, UV);
	float inside_x = smoothstep(0.07, 0.12, UV.x) * (1.0 - smoothstep(0.88, 0.93, UV.x));
	float inside_y = smoothstep(0.10, 0.18, UV.y) * (1.0 - smoothstep(0.82, 0.90, UV.y));
	float darkness = 1.0 - smoothstep(0.04, 0.20, max(pixel.r, max(pixel.g, pixel.b)));
	pixel.a *= mix(1.0, 0.82, inside_x * inside_y * darkness);
	COLOR = pixel * COLOR;
}
"""

@onready var dim: ColorRect = %Dim
@onready var design_root: Control = %DesignRoot
@onready var card: Control = %Card
@onready var frame: NinePatchRect = %Frame
@onready var kicker_label: Label = %KickerLabel
@onready var title_label: Label = %TitleLabel
@onready var detail_label: Label = %DetailLabel
@onready var results_list: VBoxContainer = %ResultsList
@onready var rematch_button: Button = %RematchButton
@onready var setup_button: Button = %SetupButton

@onready var time_value: Label = $DesignRoot/Card/Content/VBox/Summary/TimeStat/TimeValue
@onready var laps_value: Label = $DesignRoot/Card/Content/VBox/Summary/LapsStat/LapsValue
@onready var difficulty_value: Label = $DesignRoot/Card/Content/VBox/Summary/DifficultyStat/DifficultyValue
@onready var survivors_value: Label = $DesignRoot/Card/Content/VBox/Summary/SurvivorsStat/SurvivorsValue


func _ready() -> void:
	_apply_styles()
	rematch_button.pressed.connect(func() -> void: rematch_requested.emit())
	setup_button.pressed.connect(func() -> void: setup_requested.emit())
	get_viewport().size_changed.connect(_fit_to_viewport)
	_fit_to_viewport()


func show_results(data: Dictionary) -> void:
	visible = true
	var player_won := bool(data.get("player_won", false))
	var player_place := int(data.get("player_place", 0))
	title_label.text = str(data.get("title", "RACE COMPLETE"))
	detail_label.text = str(data.get("detail", ""))

	var title_color := GameStyle.ACCENT
	if player_place <= 0 and not player_won:
		title_color = GameStyle.DANGER
	elif player_place <= 0 and player_won:
		title_color = GameStyle.SUCCESS
	GameStyle.apply_title(title_label, title_color, 50)

	time_value.text = _format_time(float(data.get("race_time", 0.0)))
	if bool(data.get("uses_laps", false)):
		laps_value.text = "%d / %d" % [
			int(data.get("laps_done", 0)),
			int(data.get("lap_total", 0)),
		]
	else:
		laps_value.text = "--"
	difficulty_value.text = str(data.get("difficulty", "NOVICE"))
	survivors_value.text = str(data.get("survivors", 0))

	_populate_results(data.get("results", []) as Array)
	_show_unlocks(data.get("newly_unlocked_vehicle_ids", []) as Array)
	_fit_to_viewport()
	_play_entrance()


func _show_unlocks(unlocked_ids: Array) -> void:
	if unlocked_ids.is_empty():
		return
	var names: Array[String] = []
	for vehicle_id in unlocked_ids:
		var entry := VehicleCatalog.get_vehicle(str(vehicle_id))
		names.append(str(entry.get("display_name", vehicle_id)).to_upper())
	var unlock_label := Label.new()
	unlock_label.text = "VEHICLE UNLOCKED: %s" % ", ".join(names)
	unlock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	unlock_label.custom_minimum_size = Vector2(0.0, 30.0)
	GameStyle.apply_display_label(unlock_label, GameStyle.SUCCESS, 17)
	unlock_label.add_theme_constant_override("outline_size", 4)
	unlock_label.add_theme_color_override("font_outline_color", GameStyle.INK)
	var vbox := $DesignRoot/Card/Content/VBox as VBoxContainer
	vbox.add_child(unlock_label)
	vbox.move_child(unlock_label, 4)


func _apply_styles() -> void:
	dim.color = Color(0.0, 0.0, 0.0, 0.68)
	var shader := Shader.new()
	shader.code = DATA_BOX_SHADER
	var material := ShaderMaterial.new()
	material.shader = shader
	frame.material = material

	GameStyle.apply_display_label(kicker_label, GameStyle.SETUP_CYAN, 19)
	kicker_label.add_theme_constant_override("outline_size", 4)
	kicker_label.add_theme_color_override("font_outline_color", GameStyle.INK)
	GameStyle.apply_title(title_label, GameStyle.ACCENT, 50)
	GameStyle.apply_label(detail_label, GameStyle.TEXT_MUTED, 15)

	var summary: HBoxContainer = $DesignRoot/Card/Content/VBox/Summary
	for stat_node in summary.get_children():
		var stat := stat_node as VBoxContainer
		if stat == null or stat.get_child_count() < 2:
			continue
		var tag := stat.get_child(0) as Label
		var value := stat.get_child(1) as Label
		GameStyle.apply_label(tag, GameStyle.TEXT_DIM, 11)
		GameStyle.apply_display_label(value, GameStyle.ACCENT, 20)

	var order_title: Label = $DesignRoot/Card/Content/VBox/OrderTitle
	GameStyle.apply_display_label(order_title, GameStyle.TEXT, 18)
	order_title.add_theme_constant_override("outline_size", 3)
	order_title.add_theme_color_override("font_outline_color", GameStyle.INK)
	var column_header: HBoxContainer = $DesignRoot/Card/Content/VBox/ColumnHeader
	for header_node in column_header.get_children():
		var header := header_node as Label
		if header:
			GameStyle.apply_label(header, GameStyle.TEXT_DIM, 11)

	GameStyle.apply_button(rematch_button, GameStyle.setup_start_styles(), GameStyle.INK)
	GameStyle.apply_button(setup_button, GameStyle.button_ghost())
	rematch_button.add_theme_font_size_override("font_size", 18)
	setup_button.add_theme_font_size_override("font_size", 18)


func _populate_results(raw_results: Array) -> void:
	for child in results_list.get_children():
		child.queue_free()

	if raw_results.is_empty():
		var empty := Label.new()
		empty.text = "NO CLASSIFIED FINISHERS"
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.custom_minimum_size = Vector2(0.0, 48.0)
		GameStyle.apply_display_label(empty, GameStyle.TEXT_DIM, 14)
		results_list.add_child(empty)
		return

	for raw_result in raw_results:
		var result := raw_result as Dictionary
		_add_result_row(result)


func _add_result_row(result: Dictionary) -> void:
	var status := str(result.get("status", "FINISHED"))
	var is_player := bool(result.get("is_player", false))
	var accent := GameStyle.ACCENT
	if is_player:
		accent = GameStyle.SETUP_CYAN
	elif status == "ESTIMATED":
		accent = GameStyle.TEXT_MUTED
	elif status == "DNF":
		accent = GameStyle.DANGER

	var row_panel := PanelContainer.new()
	row_panel.custom_minimum_size = Vector2(0.0, 43.0)
	var row_style := StyleBoxFlat.new()
	row_style.bg_color = Color(accent.r, accent.g, accent.b, 0.14 if is_player else 0.06)
	row_style.border_color = accent
	row_style.border_width_left = 4
	row_style.set_corner_radius_all(4)
	row_style.content_margin_left = 13
	row_style.content_margin_right = 13
	row_style.content_margin_top = 7
	row_style.content_margin_bottom = 7
	row_panel.add_theme_stylebox_override("panel", row_style)
	results_list.add_child(row_panel)

	var row := HBoxContainer.new()
	row_panel.add_child(row)

	var place := Label.new()
	place.custom_minimum_size = Vector2(86.0, 0.0)
	place.text = "DNF" if status == "DNF" else _ordinal(int(result.get("place", 0)))
	GameStyle.apply_display_label(place, accent, 15)
	row.add_child(place)

	var racer := Label.new()
	racer.text = str(result.get("name", "CAR")).to_upper()
	racer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	GameStyle.apply_label(racer, GameStyle.TEXT, 15)
	row.add_child(racer)

	var result_value := Label.new()
	result_value.custom_minimum_size = Vector2(124.0, 0.0)
	result_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	match status:
		"FINISHED":
			result_value.text = _format_time(float(result.get("finish_time", 0.0)))
		"ESTIMATED":
			result_value.text = "EST."
		_:
			result_value.text = "DNF"
	GameStyle.apply_display_label(result_value, accent, 15)
	row.add_child(result_value)


func _format_time(elapsed: float) -> String:
	var total_centiseconds := maxi(int(round(maxf(elapsed, 0.0) * 100.0)), 0)
	var minutes := int(float(total_centiseconds) / 6000.0)
	var seconds := float(total_centiseconds % 6000) / 100.0
	return "%02d:%05.2f" % [minutes, seconds]


func _ordinal(value: int) -> String:
	var remainder_100 := value % 100
	if remainder_100 >= 11 and remainder_100 <= 13:
		return "%dTH" % value
	match value % 10:
		1:
			return "%dST" % value
		2:
			return "%dND" % value
		3:
			return "%dRD" % value
		_:
			return "%dTH" % value


func _fit_to_viewport() -> void:
	if not is_instance_valid(design_root):
		return
	var viewport_size := Vector2(get_viewport().get_visible_rect().size)
	var available := viewport_size - VIEWPORT_MARGIN * 2.0
	var fit_scale := minf(available.x / DESIGN_SIZE.x, available.y / DESIGN_SIZE.y)
	fit_scale = clampf(fit_scale, 0.45, 1.15)
	design_root.scale = Vector2.ONE * fit_scale
	design_root.position = (viewport_size - DESIGN_SIZE * fit_scale) * 0.5


func _play_entrance() -> void:
	card.scale = Vector2(0.94, 0.94)
	card.modulate.a = 0.0
	dim.modulate.a = 0.0
	var tween := create_tween().set_parallel(true)
	tween.tween_property(dim, "modulate:a", 1.0, 0.18)
	tween.tween_property(card, "modulate:a", 1.0, 0.22)
	tween.tween_property(card, "scale", Vector2.ONE, 0.28).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
