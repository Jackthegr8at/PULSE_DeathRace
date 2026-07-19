extends Control
## Lightweight threaded loader shown between Setup and Race3D.
## This scene intentionally references no track or vehicle resources itself.

const RACE_SCENE_PATH := "res://scenes/race/Race3D.tscn"
const SETUP_BACKGROUND: Texture2D = preload("res://assets/ui/setup/setup-background.png")
const OFFICIAL_LOGO: Texture2D = preload("res://assets/ui/setup/logo_officiel.png")
const CYAN := Color("00dbe8")
const MAGENTA := Color("ef1459")
const YELLOW := Color("ffc20b")

var _requests: Array[Dictionary] = []
var _request_index: int = 0
var _request_started_msec: int = 0
var _display_font: SystemFont
var _progress_bar: ProgressBar
var _percent_label: Label
var _stage_label: Label
var _detail_label: Label
var _error_label: Label
var _pulse_time: float = 0.0
var _loading_finished: bool = false


func _ready() -> void:
	_build_screen()
	_build_request_list()
	if MatchConfig.loading_started_msec <= 0:
		MatchConfig.begin_race_loading()
	_start_current_request()


func _process(delta: float) -> void:
	_pulse_time += delta
	if _loading_finished:
		return

	var request: Dictionary = _requests[_request_index]
	var path: String = request["path"]
	var progress: Array = []
	var status: ResourceLoader.ThreadLoadStatus = ResourceLoader.load_threaded_get_status(path, progress)
	var item_progress: float = 0.0
	if not progress.is_empty():
		item_progress = clampf(float(progress[0]), 0.0, 1.0)
	_set_total_progress((float(_request_index) + item_progress) / float(_requests.size()))
	_stage_label.modulate.a = 0.84 + sin(_pulse_time * 4.0) * 0.16

	match status:
		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			return
		ResourceLoader.THREAD_LOAD_LOADED:
			var resource: Resource = ResourceLoader.load_threaded_get(path)
			if resource == null:
				_fail_loading("Loaded resource was empty: %s" % path)
				return
			MatchConfig.retain_loading_resource(path, resource)
			_print_request_time(String(request["label"]))
			_request_index += 1
			if _request_index >= _requests.size():
				_finish_loading()
			else:
				_start_current_request()
		ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			_fail_loading("Could not load %s" % String(request["label"]))


func _build_request_list() -> void:
	_requests = [
		{"path": MatchConfig.track_scene_path(), "label": "TRACK AND ENVIRONMENT"},
		{"path": RACE_SCENE_PATH, "label": "PLAYER VEHICLE"},
		{"path": "res://scenes/vehicles/WraithModular.tscn", "label": "WRAITH"},
		{"path": "res://scenes/vehicles/BullDozeModular.tscn", "label": "BULLDOZE"},
		{"path": "res://scenes/vehicles/VenomModular.tscn", "label": "VENOM"},
	]


func _start_current_request() -> void:
	var request: Dictionary = _requests[_request_index]
	var path: String = request["path"]
	var label_text: String = request["label"]
	_stage_label.text = "LOADING %s" % label_text
	_detail_label.text = "STAGE %d / %d  •  %s" % [_request_index + 1, _requests.size(), MatchConfig.track_display_name().to_upper()]
	_request_started_msec = Time.get_ticks_msec()

	if ResourceLoader.has_cached(path):
		var cached: Resource = ResourceLoader.get_cached_ref(path)
		if cached != null:
			MatchConfig.retain_loading_resource(path, cached)
			_print_request_time(label_text)
			_request_index += 1
			if _request_index >= _requests.size():
				call_deferred("_finish_loading")
			else:
				call_deferred("_start_current_request")
			return

	var error := ResourceLoader.load_threaded_request(path, "PackedScene", true)
	if error != OK:
		_fail_loading("Could not queue %s (error %d)" % [label_text, error])


func _finish_loading() -> void:
	if _loading_finished:
		return
	_loading_finished = true
	set_process(false)
	_set_total_progress(1.0)
	_stage_label.modulate = Color.WHITE
	_stage_label.text = "BUILDING THE STARTING GRID"
	_detail_label.text = "PREPARING TRACK COLLISIONS AND VEHICLES"
	print("[RaceLoad] threaded resources: %.2f s" % [float(Time.get_ticks_msec() - MatchConfig.loading_started_msec) / 1000.0])

	# Draw the final loading state before PackedScene instantiation performs its
	# unavoidable main-thread work. The loading artwork remains on screen during
	# that final hitch instead of leaving the setup page apparently frozen.
	await get_tree().process_frame
	await get_tree().process_frame
	var race_scene := MatchConfig.get_loading_resource(RACE_SCENE_PATH) as PackedScene
	if race_scene == null:
		_fail_loading("The race scene was not available after loading.")
		return
	var error := get_tree().change_scene_to_packed(race_scene)
	if error != OK:
		_fail_loading("Could not open the race (error %d)." % error)


func _fail_loading(message: String) -> void:
	_loading_finished = true
	set_process(false)
	_stage_label.modulate = Color.WHITE
	_stage_label.text = "LOAD FAILED"
	_stage_label.add_theme_color_override("font_color", MAGENTA)
	_detail_label.text = "PRESS ESCAPE TO RETURN TO SETUP"
	_error_label.text = message
	_error_label.visible = true
	push_error("LoadingScreen: %s" % message)


func _unhandled_key_input(event: InputEvent) -> void:
	if _loading_finished and event.is_action_pressed("ui_cancel"):
		MatchConfig.clear_loading_resources()
		get_tree().change_scene_to_file("res://scenes/Setup.tscn")


func _set_total_progress(ratio: float) -> void:
	var percent := clampf(ratio, 0.0, 1.0) * 100.0
	_progress_bar.value = percent
	_percent_label.text = "%d%%" % roundi(percent)


func _print_request_time(label_text: String) -> void:
	var elapsed := float(Time.get_ticks_msec() - _request_started_msec) / 1000.0
	print("[RaceLoad] threaded %s: %.2f s" % [label_text.to_lower(), elapsed])


func _build_screen() -> void:
	_display_font = SystemFont.new()
	_display_font.font_names = PackedStringArray(["Impact", "Bahnschrift Condensed", "Arial Narrow", "Arial"])
	_display_font.font_weight = 700

	var background := TextureRect.new()
	background.texture = SETUP_BACKGROUND
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	var shade := ColorRect.new()
	shade.color = Color(0.004, 0.009, 0.013, 0.76)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)

	var logo := TextureRect.new()
	logo.texture = OFFICIAL_LOGO
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.set_anchors_preset(Control.PRESET_CENTER_TOP)
	logo.position = Vector2(-260, 28)
	logo.size = Vector2(520, 150)
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(logo)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-355, -92)
	panel.size = Vector2(710, 245)
	panel.add_theme_stylebox_override("panel", _panel_style())
	add_child(panel)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 11)
	panel.add_child(content)

	var title := _label("ASSEMBLING DEATHRACE", 38, Color.WHITE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(title)

	_stage_label = _label("LOADING", 25, CYAN)
	_stage_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(_stage_label)

	var progress_row := HBoxContainer.new()
	progress_row.add_theme_constant_override("separation", 14)
	content.add_child(progress_row)

	_progress_bar = ProgressBar.new()
	_progress_bar.custom_minimum_size = Vector2(580, 28)
	_progress_bar.show_percentage = false
	_progress_bar.add_theme_stylebox_override("background", _bar_style(Color("11191c"), Color("3c4d50")))
	_progress_bar.add_theme_stylebox_override("fill", _bar_style(MAGENTA, YELLOW))
	progress_row.add_child(_progress_bar)

	_percent_label = _label("0%", 23, YELLOW)
	_percent_label.custom_minimum_size = Vector2(65, 30)
	_percent_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	progress_row.add_child(_percent_label)

	_detail_label = _label("PREPARING", 16, Color("a8b7b9"))
	_detail_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(_detail_label)

	_error_label = _label("", 15, MAGENTA)
	_error_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_error_label.visible = false
	content.add_child(_error_label)


func _label(text_value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_override("font", _display_font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color("020405"))
	label.add_theme_constant_override("outline_size", 5)
	return label


func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.01, 0.025, 0.032, 0.94)
	style.border_color = Color(0.18, 0.78, 0.83, 0.8)
	style.set_border_width_all(3)
	style.set_corner_radius_all(9)
	style.content_margin_left = 26
	style.content_margin_right = 26
	style.content_margin_top = 20
	style.content_margin_bottom = 18
	return style


func _bar_style(background_color: Color, border_color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background_color
	style.border_color = border_color
	style.set_border_width_all(2)
	style.set_corner_radius_all(5)
	return style
