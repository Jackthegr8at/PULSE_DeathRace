extends Node3D
## 3D race host: track, player + AI, combat win rules, HUD / end screen.

const VehicleScene: PackedScene = preload("res://scenes/vehicle.tscn")
const GAME_ICON: Texture2D = preload("res://icon.png")
const AI_MODELS: Array[String] = [
	"res://scenes/vehicles/WraithModular.tscn",
	"res://scenes/vehicles/BullDozeModular.tscn",
	"res://scenes/vehicles/VenomModular.tscn",
]

@onready var track_root: Node3D = $TrackRoot
@onready var vehicles_root: Node3D = $Vehicles
@onready var view: Node3D = $View

var track: Node3D = null
var player: Vehicle = null
var vehicles: Array[Vehicle] = []
var match_over: bool = false
var hud: CanvasLayer = null
var end_layer: CanvasLayer = null
var race_path3d: Path3D = null
var _rank_accum: float = 0.0
var _race_started: bool = false
var _countdown_running: bool = false
var _start_layer: CanvasLayer = null
var _countdown_label: Label = null
var _prompt_label: Label = null


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color(0.68, 0.76, 0.97))
	MatchConfig.ai_count = maxi(MatchConfig.ai_count, 3)
	_load_track()
	await get_tree().process_frame
	await get_tree().process_frame
	_spawn_field()
	_bind_camera()
	_spawn_hud()
	_set_race_started(false)
	_create_start_overlay()


func _load_track() -> void:
	var path := MatchConfig.track_scene_path()
	var packed := load(path) as PackedScene
	if packed == null:
		push_error("Race3D: failed to load track %s" % path)
		return
	track = packed.instantiate() as Node3D
	track_root.add_child(track)


func _spawn_field() -> void:
	var path3d: Path3D = null
	if track and track.has_method("get_race_path"):
		path3d = track.call("get_race_path") as Path3D
	race_path3d = path3d

	var count := 1 + MatchConfig.ai_count
	var spawns: Array[Transform3D] = []
	if track and track.has_method("get_spawn_transforms"):
		spawns = track.call("get_spawn_transforms", count) as Array[Transform3D]
	else:
		var base := _get_spawn_transform()
		for i in count:
			spawns.append(Transform3D(base.basis, base.origin + base.basis.z * (i * 2.5)))

	# Player
	player = _spawn_vehicle(spawns[0], true, null, "Player")
	if path3d:
		player.setup_player_laps(path3d)
	player.died.connect(_on_vehicle_died)
	player.race_finished.connect(_on_race_finished)
	vehicles.append(player)

	# AI
	for i in MatchConfig.ai_count:
		var spawn_i := mini(i + 1, spawns.size() - 1)
		var model := AI_MODELS[i % AI_MODELS.size()]
		var ai := _spawn_vehicle(spawns[spawn_i], false, model, "AI-%d" % (i + 1))
		if path3d:
			ai.setup_ai(path3d, "AI-%d" % (i + 1))
		else:
			ai.is_player = false
			ai.display_name = "AI-%d" % (i + 1)
		ai.died.connect(_on_vehicle_died)
		ai.race_finished.connect(_on_race_finished)
		# Slightly easier than the player; small variety so packs don't clone
		ai.max_health = 100.0
		ai.health = 100.0
		ai.ai_throttle = 0.72 + float(i % 3) * 0.04
		ai.ai_corner_throttle = 0.46
		ai.path_look_ahead = 5.2 + float(i % 3) * 0.4
		vehicles.append(ai)

	_update_alive_hud()


func _spawn_vehicle(spawn: Transform3D, as_player: bool, model_path: Variant, name_label: String) -> Vehicle:
	var veh := VehicleScene.instantiate() as Vehicle
	veh.is_player = as_player
	veh.display_name = name_label
	vehicles_root.add_child(veh)

	# Optional model swap for AI color variety
	if model_path != null and str(model_path) != "":
		_swap_model(veh, str(model_path))

	# Snap to ground under spawn so cars sit on GridMap asphalt, not float/clip
	var pos := _snap_spawn_to_ground(spawn.origin)
	var basis := spawn.basis.orthonormalized()
	var sphere := veh.get_node_or_null("Sphere") as RigidBody3D
	if sphere:
		sphere.global_transform = Transform3D(Basis.IDENTITY, pos)
		sphere.linear_velocity = Vector3.ZERO
		sphere.angular_velocity = Vector3.ZERO
	# Modular vehicle scenes are authored with their root on the road plane.
	# Keep that editor reference at runtime instead of applying the legacy visual drop.
	var visual_model := veh.get_node_or_null("Container/Model") as Node3D
	var is_modular_model := visual_model != null and visual_model.is_in_group("modular_vehicle_visual")
	# Modular roads now sit slightly above the old zero-height surface. Lift
	# the visual chassis/wheels without changing the physics sphere height.
	var visual_drop := 0.55 if is_modular_model else 0.65
	var model_pos := pos - Vector3(0, visual_drop, 0)
	var container := veh.get_node_or_null("Container") as Node3D
	if container:
		container.global_transform = Transform3D(basis, model_pos)
	veh.global_position = Vector3(pos.x, 0.0, pos.z)
	return veh


func _snap_spawn_to_ground(origin: Vector3) -> Vector3:
	## Raycast down onto track. If miss (off mesh), pull toward SpawnPoint and retry.
	var space := get_world_3d().direct_space_state
	var hover := 0.55
	if space == null:
		return origin + Vector3(0, hover, 0)

	var anchor := origin
	if track and track.has_method("get_spawn_transform"):
		anchor = (track.call("get_spawn_transform") as Transform3D).origin

	var candidates: Array[Vector3] = [
		origin,
		origin.lerp(anchor, 0.35),
		origin.lerp(anchor, 0.7),
		anchor,
	]
	for c in candidates:
		var from := c + Vector3(0, 10.0, 0)
		var to := c + Vector3(0, -25.0, 0)
		var q := PhysicsRayQueryParameters3D.create(from, to)
		q.collision_mask = 0xFFFFFFFF
		var hit := space.intersect_ray(q)
		if hit and hit.has("position"):
			var p: Vector3 = hit.position
			return Vector3(c.x, p.y + hover, c.z)

	return Vector3(anchor.x, anchor.y + hover, anchor.z)


func _swap_model(veh: Vehicle, glb_path: String) -> void:
	var container := veh.get_node_or_null("Container") as Node3D
	if container == null:
		return
	var old := container.get_node_or_null("Model")
	if old:
		old.free()
	var packed := load(glb_path) as PackedScene
	if packed == null:
		return
	var model := packed.instantiate()
	model.name = "Model"
	container.add_child(model)
	# Kenney trucks sit on y≈0; Ravage monomesh is centered — leave identity for kit trucks
	if str(glb_path).contains("ravage"):
		# Match Kenney truck bulk (~0.85–0.95); mesh is ~1.5×1.0×1.6 unscaled
		model.scale = Vector3(0.88, 0.88, 0.88)
		model.position = Vector3(0, 0.44, 0)
	if veh.has_method("rebind_model_parts"):
		veh.rebind_model_parts()


func _get_spawn_transform() -> Transform3D:
	if track and track.has_method("get_spawn_transform"):
		return track.call("get_spawn_transform") as Transform3D
	return Transform3D(Basis(), Vector3(3.5, 0.2, 5))


func _bind_camera() -> void:
	if view == null or player == null:
		return
	view.set("target", player)
	view.global_position = player.get_vehicle_position()


func _spawn_hud() -> void:
	hud = CanvasLayer.new()
	hud.set_script(load("res://scripts/ui/HUD3D.gd"))
	add_child(hud)
	if hud.has_method("set_player"):
		hud.call("set_player", player)
	if hud.has_method("set_race_path"):
		hud.call("set_race_path", race_path3d)
	if hud.has_method("set_running"):
		hud.call("set_running", false)
	_update_alive_hud()
	_update_position_hud()


func _set_race_started(started: bool) -> void:
	_race_started = started
	for veh in vehicles:
		if is_instance_valid(veh) and veh.has_method("set_race_started"):
			veh.set_race_started(started)
	if hud and hud.has_method("set_running"):
		hud.call("set_running", started)


func _create_start_overlay() -> void:
	_start_layer = CanvasLayer.new()
	_start_layer.name = "RaceStartOverlay"
	_start_layer.layer = 40
	add_child(_start_layer)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.03, 0.04, 0.025, 0.28)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_start_layer.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_start_layer.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(430, 430)
	panel.add_theme_stylebox_override("panel", GameStyle.comic_panel(Color(0.09, 0.12, 0.08, 0.96), 18.0))
	center.add_child(panel)

	var margin := MarginContainer.new()
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 22)
	panel.add_child(margin)

	var stack := VBoxContainer.new()
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_theme_constant_override("separation", 12)
	margin.add_child(stack)

	var logo := TextureRect.new()
	logo.texture = GAME_ICON
	logo.custom_minimum_size = Vector2(190, 190)
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(logo)

	var title := Label.new()
	title.text = "READY TO RACE?"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	GameStyle.apply_title(title, GameStyle.ACCENT, 30)
	stack.add_child(title)

	_prompt_label = Label.new()
	_prompt_label.text = "PRESS ENTER TO START"
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	GameStyle.apply_title(_prompt_label, GameStyle.TEXT, 19)
	stack.add_child(_prompt_label)

	_countdown_label = Label.new()
	_countdown_label.text = ""
	_countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_countdown_label.custom_minimum_size = Vector2(0, 110)
	_countdown_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	GameStyle.apply_title(_countdown_label, GameStyle.PINK, 92)
	stack.add_child(_countdown_label)


func _start_countdown() -> void:
	if _countdown_running or _race_started or _start_layer == null:
		return
	_countdown_running = true
	if _prompt_label:
		_prompt_label.visible = false
	var logo_node := _start_layer.get_node_or_null("CenterContainer/PanelContainer/MarginContainer/VBoxContainer/TextureRect")
	if logo_node:
		logo_node.visible = false
	var title_node := _start_layer.get_node_or_null("CenterContainer/PanelContainer/MarginContainer/VBoxContainer/Label")
	if title_node:
		title_node.visible = false

	for number in ["3", "2", "1"]:
		if _countdown_label == null:
			return
		_countdown_label.text = number
		_countdown_label.modulate = Color.WHITE
		_countdown_label.scale = Vector2(0.72, 0.72)
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(_countdown_label, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(_countdown_label, "modulate", Color(1, 0.78, 0.35, 1), 0.7)
		await get_tree().create_timer(0.8).timeout

	if _countdown_label:
		_countdown_label.text = "GO!"
		GameStyle.apply_title(_countdown_label, GameStyle.SUCCESS, 82)
	_set_race_started(true)
	await get_tree().create_timer(0.65).timeout
	if is_instance_valid(_start_layer):
		_start_layer.queue_free()
	_start_layer = null
	_countdown_running = false


func _process(delta: float) -> void:
	if match_over:
		return
	_rank_accum += delta
	if _rank_accum >= 0.25:
		_rank_accum = 0.0
		_update_position_hud()


func _race_progress(veh: Vehicle) -> float:
	return float(veh.laps_completed) + veh.get_lap_progress_ratio()


func _update_position_hud() -> void:
	if hud == null or not hud.has_method("update_position"):
		return
	if not MatchConfig.uses_laps() or player == null or not is_instance_valid(player):
		return
	var total := vehicles.size()
	var place := 1
	var mine := _race_progress(player)
	for v in vehicles:
		if v == player or not is_instance_valid(v) or not v.is_alive:
			continue
		if _race_progress(v) > mine:
			place += 1
	hud.call("update_position", place, total)


func _living() -> Array[Vehicle]:
	var out: Array[Vehicle] = []
	for v in vehicles:
		if is_instance_valid(v) and v.is_alive:
			out.append(v)
	return out


func _update_alive_hud() -> void:
	if hud and hud.has_method("update_alive"):
		hud.call("update_alive", _living().size())


func _on_vehicle_died(veh: Vehicle) -> void:
	if match_over:
		return
	vehicles.erase(veh)
	_update_alive_hud()

	if veh == player:
		_end_match(false, "You were destroyed.")
		return

	var living := _living()
	if living.size() == 1 and living[0] == player:
		if MatchConfig.mode == MatchConfig.Mode.LAST_STANDING \
				or MatchConfig.mode == MatchConfig.Mode.HYBRID:
			_end_match(true, "Last car standing!")


func _on_race_finished(veh: Vehicle) -> void:
	if match_over or not MatchConfig.uses_laps():
		return
	if veh == player:
		_end_match(true, "You finished %d laps first!" % MatchConfig.lap_count)
	else:
		_end_match(false, "%s finished the race first." % veh.display_name)


func _end_match(player_won: bool, detail: String) -> void:
	if match_over:
		return
	match_over = true
	if hud and hud.has_method("stop"):
		hud.call("stop")
	for v in vehicles:
		if is_instance_valid(v):
			v.set_match_over(true)
	_show_end(player_won, detail)


func _show_end(player_won: bool, detail: String) -> void:
	end_layer = CanvasLayer.new()
	end_layer.layer = 30
	add_child(end_layer)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.55)
	end_layer.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	end_layer.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(420, 260)
	panel.add_theme_stylebox_override("panel", GameStyle.comic_panel(Color(0.10, 0.13, 0.09, 0.97), 16.0))
	center.add_child(panel)

	var margin := MarginContainer.new()
	for s in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(s, 26)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)

	var title := Label.new()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if player_won:
		title.text = "YOU WIN!"
		GameStyle.apply_title(title, GameStyle.SUCCESS, 44)
	else:
		title.text = "WRECKED!"
		GameStyle.apply_title(title, GameStyle.DANGER, 44)
	vbox.add_child(title)

	var detail_l := Label.new()
	detail_l.text = detail
	detail_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	GameStyle.apply_label(detail_l, GameStyle.TEXT_MUTED, 14)
	vbox.add_child(detail_l)

	var stats := VBoxContainer.new()
	stats.add_theme_constant_override("separation", 4)
	vbox.add_child(stats)
	var elapsed := 0.0
	if hud and hud.has_method("get_elapsed"):
		elapsed = hud.call("get_elapsed")
	var m := int(elapsed) / 60
	var s2 := int(elapsed) % 60
	_add_stat_row(stats, "RACE TIME", "%02d:%02d" % [m, s2])
	if MatchConfig.uses_laps() and player and is_instance_valid(player):
		_add_stat_row(stats, "LAPS DONE", "%d / %d" % [player.laps_completed, MatchConfig.lap_count])
	_add_stat_row(stats, "CARS LEFT", str(_living().size()))

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	vbox.add_child(row)

	var rematch := Button.new()
	rematch.text = "REMATCH"
	rematch.custom_minimum_size = Vector2(140, 46)
	GameStyle.apply_button(rematch, GameStyle.button_primary(), GameStyle.BG_DEEP)
	rematch.pressed.connect(func() -> void:
		get_tree().change_scene_to_file("res://scenes/race/Race3D.tscn")
	)
	row.add_child(rematch)

	var setup := Button.new()
	setup.text = "SETUP"
	setup.custom_minimum_size = Vector2(140, 46)
	GameStyle.apply_button(setup, GameStyle.button_ghost())
	setup.pressed.connect(func() -> void:
		get_tree().change_scene_to_file("res://scenes/Setup.tscn")
	)
	row.add_child(setup)


func _add_stat_row(parent: Control, label_text: String, value_text: String) -> void:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var tag := Label.new()
	tag.text = label_text
	tag.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	GameStyle.apply_label(tag, GameStyle.TEXT_DIM, 13)
	row.add_child(tag)
	var val := Label.new()
	val.text = value_text
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	GameStyle.apply_label(val, GameStyle.ACCENT, 15)
	row.add_child(val)


func _unhandled_input(event: InputEvent) -> void:
	if not _race_started and not _countdown_running and event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			_start_countdown()
			get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed("ui_cancel") and not match_over:
		get_tree().change_scene_to_file("res://scenes/Setup.tscn")
