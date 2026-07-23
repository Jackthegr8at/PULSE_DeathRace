extends Node3D
## 3D race host: track, player + AI, combat win rules, HUD / end screen.

const VehicleScene: PackedScene = preload("res://scenes/vehicle.tscn")
const EndScreenScene: PackedScene = preload("res://scenes/ui/EndScreen.tscn")
const STARTUP_PANEL_TEXTURE: Texture2D = preload("res://assets/ui/hud/startup_box.png")
const COUNTDOWN_TEXTURES: Dictionary = {
	"3": preload("res://assets/ui/hud/countdown/3.png"),
	"2": preload("res://assets/ui/hud/countdown/2.png"),
	"1": preload("res://assets/ui/hud/countdown/1.png"),
	"GO": preload("res://assets/ui/hud/countdown/go.png"),
}
const FINISH_WINDOW_SECONDS := 30.0

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
var _countdown_art: TextureRect = null
var _startup_panel: TextureRect = null
var finish_order: Array[Dictionary] = []
var dnf_order: Array[Dictionary] = []
var _resolved_vehicle_ids: Dictionary = {}
var _entrant_count: int = 0
var _finish_window_started: bool = false
var _finish_timer: Timer = null
var _player_kills_by_vehicle_id: Dictionary = {}
var _race_summary_committed: bool = false
var _newly_unlocked_vehicle_ids: Array[String] = []
var _race_session_id: String = ""


func _ready() -> void:
	var ready_started_msec := Time.get_ticks_msec()
	_race_session_id = "%d-%d" % [Time.get_unix_time_from_system(), Time.get_ticks_usec()]
	RenderingServer.set_default_clear_color(Color(0.68, 0.76, 0.97))
	MatchConfig.ai_count = maxi(MatchConfig.ai_count, 3)
	var phase_started_msec := Time.get_ticks_msec()
	_load_track()
	_print_load_phase("track load and instantiation", phase_started_msec)
	await get_tree().process_frame
	await get_tree().process_frame
	phase_started_msec = Time.get_ticks_msec()
	_spawn_field()
	_print_load_phase("vehicle field creation", phase_started_msec)
	_bind_camera()
	phase_started_msec = Time.get_ticks_msec()
	_spawn_hud()
	_set_race_started(false)
	_create_start_overlay()
	_print_load_phase("HUD and start overlay", phase_started_msec)
	_print_load_phase("Race3D ready total", ready_started_msec)
	if MatchConfig.loading_started_msec > 0:
		_print_load_phase("setup-to-race total", MatchConfig.loading_started_msec)
	MatchConfig.clear_loading_resources()


func _print_load_phase(label: String, started_msec: int) -> void:
	var elapsed_seconds := float(Time.get_ticks_msec() - started_msec) / 1000.0
	print("[RaceLoad] %s: %.2f s" % [label, elapsed_seconds])


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
	_entrant_count = count
	var spawns: Array[Transform3D] = []
	if track and track.has_method("get_spawn_transforms"):
		spawns = track.call("get_spawn_transforms", count) as Array[Transform3D]
	else:
		var base := _get_spawn_transform()
		for i in count:
			spawns.append(Transform3D(base.basis, base.origin + base.basis.z * (i * 2.5)))

	var player_id := MatchConfig.selected_vehicle_id()
	var player_entry := VehicleCatalog.get_vehicle(player_id)
	var ai_ids := MatchConfig.ai_vehicle_ids()

	# Player
	player = _spawn_vehicle(spawns[0], true, player_entry, "Player")
	if path3d:
		player.setup_player_laps(path3d)
	player.died.connect(_on_vehicle_died)
	player.race_finished.connect(_on_race_finished)
	vehicles.append(player)

	# AI
	for i in MatchConfig.ai_count:
		var spawn_i := mini(i + 1, spawns.size() - 1)
		var ai_id := ai_ids[i % ai_ids.size()]
		var ai_entry := VehicleCatalog.get_vehicle(ai_id)
		var ai := _spawn_vehicle(spawns[spawn_i], false, ai_entry, "AI-%d" % (i + 1))
		if path3d:
			ai.setup_ai(path3d, "AI-%d" % (i + 1))
		else:
			ai.is_player = false
			ai.display_name = "AI-%d" % (i + 1)
		ai.died.connect(_on_vehicle_died)
		ai.race_finished.connect(_on_race_finished)
		_apply_ai_difficulty(ai, i)
		ai.path_look_ahead = 5.2 + float(i % 3) * 0.4
		vehicles.append(ai)

	_update_alive_hud()


func _apply_ai_difficulty(ai: Vehicle, ai_index: int) -> void:
	var profile := MatchConfig.ai_profile()
	ai.ai_throttle = (
		float(profile.get("throttle_base", 0.72))
		+ float(ai_index % 3) * float(profile.get("throttle_step", 0.04))
	)
	ai.ai_corner_throttle = float(profile.get("corner_throttle", 0.46))
	ai.ai_steer_gain = float(profile.get("steer_gain", 2.10))
	ai.detect_range = float(profile.get("detect_range", 22.0))
	ai.ai_aim_steer_weight = float(profile.get("aim_steer_weight", 0.72))
	ai.ai_aim_time_max = float(profile.get("aim_time_max", 0.40))
	ai.fire_dot_min = float(profile.get("fire_dot_min", 0.93))


func _spawn_vehicle(spawn: Transform3D, as_player: bool, vehicle_entry: Dictionary, name_label: String) -> Vehicle:
	var veh := VehicleScene.instantiate() as Vehicle
	veh.is_player = as_player
	veh.display_name = name_label
	veh.minimap_color = vehicle_entry.get("minimap_color", GameStyle.DANGER) as Color
	veh.vehicle_type = int(vehicle_entry.get("vehicle_type", Vehicle.VehicleType.RAVAGE))
	veh.set_meta("vehicle_id", str(vehicle_entry.get("id", VehicleCatalog.DEFAULT_VEHICLE_ID)))
	vehicles_root.add_child(veh)

	var model_path := str(vehicle_entry.get("scene_path", ""))
	if not model_path.is_empty():
		_swap_model(veh, model_path)

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

	_startup_panel = TextureRect.new()
	_startup_panel.name = "StartupPanel"
	_startup_panel.anchor_left = 0.25
	_startup_panel.anchor_top = 0.25
	_startup_panel.anchor_right = 0.75
	_startup_panel.anchor_bottom = 0.75
	_startup_panel.texture = STARTUP_PANEL_TEXTURE
	_startup_panel.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_startup_panel.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_startup_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_start_layer.add_child(_startup_panel)

	_countdown_art = TextureRect.new()
	_countdown_art.name = "CountdownArt"
	_countdown_art.anchor_left = 0.30
	_countdown_art.anchor_top = 0.24
	_countdown_art.anchor_right = 0.70
	_countdown_art.anchor_bottom = 0.76
	_countdown_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_countdown_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_countdown_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_countdown_art.visible = false
	_start_layer.add_child(_countdown_art)
	_countdown_art.resized.connect(_center_countdown_pivot)
	_center_countdown_pivot()


func _center_countdown_pivot() -> void:
	if _countdown_art:
		_countdown_art.pivot_offset = _countdown_art.size * 0.5


func _start_countdown() -> void:
	if _countdown_running or _race_started or _start_layer == null:
		return
	_countdown_running = true
	if _startup_panel:
		_startup_panel.visible = false

	for number in ["3", "2", "1"]:
		if _countdown_art == null:
			return
		_countdown_art.texture = COUNTDOWN_TEXTURES[number]
		_countdown_art.visible = true
		_countdown_art.modulate = Color.WHITE
		_countdown_art.scale = Vector2(0.72, 0.72)
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(_countdown_art, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(_countdown_art, "modulate", Color(1, 1, 1, 0.82), 0.7)
		await get_tree().create_timer(0.8).timeout

	if _countdown_art:
		_countdown_art.texture = COUNTDOWN_TEXTURES["GO"]
		_countdown_art.modulate = Color.WHITE
		_countdown_art.scale = Vector2(0.72, 0.72)
		var go_tween := create_tween()
		go_tween.set_parallel(true)
		go_tween.tween_property(_countdown_art, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		go_tween.tween_property(_countdown_art, "modulate", Color(1, 1, 1, 0.82), 0.55)
	_set_race_started(true)
	await get_tree().create_timer(0.65).timeout
	if is_instance_valid(_start_layer):
		_start_layer.queue_free()
	_start_layer = null
	_startup_panel = null
	_countdown_art = null
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
	var player_finish_place := _get_player_finish_place()
	if player_finish_place > 0:
		hud.call("update_position", player_finish_place, _entrant_count)
		return
	var place := finish_order.size() + 1
	var mine := _race_progress(player)
	for v in vehicles:
		if v == player or not is_instance_valid(v) or not v.is_alive or _is_vehicle_resolved(v):
			continue
		if _race_progress(v) > mine:
			place += 1
	hud.call("update_position", place, _entrant_count)


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
	var attacker := veh.get_last_damage_source()
	if is_instance_valid(attacker) and attacker == player and veh != player:
		var victim_id := str(veh.get_meta("vehicle_id", VehicleCatalog.DEFAULT_VEHICLE_ID))
		_player_kills_by_vehicle_id[victim_id] = int(_player_kills_by_vehicle_id.get(victim_id, 0)) + 1
	var had_finished := _is_vehicle_resolved(veh) and veh.has_finished_race
	if not _is_vehicle_resolved(veh):
		_record_dnf(veh)
	vehicles.erase(veh)
	_update_alive_hud()

	if veh == player and not had_finished:
		_end_match(false, "You were destroyed.")
		return
	if _finish_window_started and _all_entrants_resolved():
		_finish_race_from_order()
		return

	var living := _living()
	if living.size() == 1 and living[0] == player:
		if not _finish_window_started and (
			MatchConfig.mode == MatchConfig.Mode.LAST_STANDING
			or MatchConfig.mode == MatchConfig.Mode.HYBRID
		):
			_end_match(true, "Last car standing!")


func _on_race_finished(veh: Vehicle) -> void:
	if match_over or not MatchConfig.uses_laps():
		return
	if _is_vehicle_resolved(veh):
		return
	_record_finished(veh)
	veh.mark_race_finished()
	if veh == player:
		_record_remaining_estimates()
		_finish_race_from_order()
		return
	if not _finish_window_started:
		_start_finish_window()
	if _all_entrants_resolved():
		_finish_race_from_order()


func _record_finished(veh: Vehicle) -> void:
	var vehicle_id := veh.get_instance_id()
	_resolved_vehicle_ids[vehicle_id] = true
	finish_order.append({
		"id": vehicle_id,
		"name": veh.display_name,
		"is_player": veh == player,
		"status": "FINISHED",
		"place": finish_order.size() + 1,
		"progress": _race_progress(veh),
		"finish_time": _race_elapsed(),
	})


func _record_dnf(veh: Vehicle) -> void:
	var vehicle_id := veh.get_instance_id()
	if _resolved_vehicle_ids.has(vehicle_id):
		return
	_resolved_vehicle_ids[vehicle_id] = true
	dnf_order.append({
		"id": vehicle_id,
		"name": veh.display_name,
		"is_player": veh == player,
		"status": "DNF",
		"place": 0,
		"progress": _race_progress(veh),
	})


func _is_vehicle_resolved(veh: Vehicle) -> bool:
	return _resolved_vehicle_ids.has(veh.get_instance_id())


func _all_entrants_resolved() -> bool:
	return _entrant_count > 0 and _resolved_vehicle_ids.size() >= _entrant_count


func _start_finish_window() -> void:
	_finish_window_started = true
	_finish_timer = Timer.new()
	_finish_timer.name = "FinishWindowTimer"
	_finish_timer.one_shot = true
	_finish_timer.wait_time = FINISH_WINDOW_SECONDS
	_finish_timer.timeout.connect(_on_finish_timeout)
	add_child(_finish_timer)
	_finish_timer.start()


func _on_finish_timeout() -> void:
	if match_over:
		return
	_record_remaining_dnfs()
	_finish_race_from_order()


func _record_remaining_dnfs() -> void:
	for veh in vehicles:
		if is_instance_valid(veh) and not _is_vehicle_resolved(veh):
			_record_dnf(veh)
	_sort_dnf_order()


func _record_remaining_estimates() -> void:
	var estimated: Array[Dictionary] = []
	for veh in vehicles:
		if not is_instance_valid(veh) or _is_vehicle_resolved(veh):
			continue
		estimated.append({
			"vehicle": veh,
			"progress": _race_progress(veh),
		})
	estimated.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("progress", 0.0)) > float(b.get("progress", 0.0))
	)
	for entry in estimated:
		var estimated_vehicle: Vehicle = entry.get("vehicle") as Vehicle
		if estimated_vehicle == null:
			continue
		var vehicle_id := estimated_vehicle.get_instance_id()
		_resolved_vehicle_ids[vehicle_id] = true
		finish_order.append({
			"id": vehicle_id,
			"name": estimated_vehicle.display_name,
			"is_player": false,
			"status": "ESTIMATED",
			"place": finish_order.size() + 1,
			"progress": float(entry.get("progress", 0.0)),
		})


func _sort_dnf_order() -> void:
	dnf_order.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("progress", 0.0)) > float(b.get("progress", 0.0))
	)


func _finish_race_from_order() -> void:
	if match_over:
		return
	if _finish_timer != null:
		_finish_timer.stop()
	_sort_dnf_order()
	var player_place := _get_player_finish_place()
	var player_won := player_place == 1
	var detail := "You were marked DNF."
	if player_place > 0:
		detail = "You finished %s." % _ordinal(player_place).to_lower()
	_end_match(player_won, detail)


func _get_player_finish_place() -> int:
	for result in finish_order:
		if bool(result.get("is_player", false)):
			return int(result.get("place", 0))
	return 0


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


func _end_match(player_won: bool, detail: String) -> void:
	if match_over:
		return
	if _finish_window_started:
		_record_remaining_dnfs()
	match_over = true
	if _finish_timer != null:
		_finish_timer.stop()
	if hud and hud.has_method("stop"):
		hud.call("stop")
	for v in vehicles:
		if is_instance_valid(v):
			v.set_match_over(true)
	_commit_race_progress(player_won)
	_show_end(player_won, detail)


func _commit_race_progress(player_won: bool) -> void:
	if _race_summary_committed:
		return
	_race_summary_committed = true
	_newly_unlocked_vehicle_ids = GarageProfile.commit_completed_race({
		"race_id": _race_session_id,
		"completed": true,
		"player_first": player_won and _get_player_finish_place() == 1,
		"player_kills_by_vehicle_id": _player_kills_by_vehicle_id.duplicate(true),
	})


func _show_end(player_won: bool, detail: String) -> void:
	var player_place := _get_player_finish_place()
	var result_title := "WRECKED"
	if player_place > 0:
		result_title = "%s PLACE" % _ordinal(player_place)
	elif player_won:
		result_title = "YOU WIN"

	var display_results: Array[Dictionary] = []
	for result in finish_order:
		display_results.append(result.duplicate(true))
	for result in dnf_order:
		display_results.append(result.duplicate(true))

	var laps_done := 0
	if player and is_instance_valid(player):
		laps_done = player.laps_completed
	var race_time := _race_elapsed()
	for result in finish_order:
		if bool(result.get("is_player", false)) and result.has("finish_time"):
			race_time = float(result.get("finish_time", race_time))
			break

	end_layer = EndScreenScene.instantiate() as CanvasLayer
	if end_layer == null:
		push_error("Race3D: failed to instantiate EndScreen")
		return
	add_child(end_layer)
	end_layer.connect("rematch_requested", _on_end_rematch_requested)
	end_layer.connect("setup_requested", _on_end_setup_requested)
	end_layer.call("show_results", {
		"title": result_title,
		"player_won": player_won,
		"player_place": player_place,
		"detail": detail,
		"race_time": race_time,
		"uses_laps": MatchConfig.uses_laps(),
		"laps_done": laps_done,
		"lap_total": MatchConfig.lap_count,
		"difficulty": MatchConfig.ai_difficulty_display_name().to_upper(),
		"survivors": _living().size(),
		"results": display_results,
		"newly_unlocked_vehicle_ids": _newly_unlocked_vehicle_ids,
	})


func _race_elapsed() -> float:
	if hud and hud.has_method("get_elapsed"):
		return float(hud.call("get_elapsed"))
	return 0.0


func _on_end_rematch_requested() -> void:
	get_tree().change_scene_to_file("res://scenes/race/Race3D.tscn")


func _on_end_setup_requested() -> void:
	get_tree().change_scene_to_file("res://scenes/Setup.tscn")


func _unhandled_input(event: InputEvent) -> void:
	if not _race_started and not _countdown_running and event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			_start_countdown()
			get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed("ui_cancel") and not match_over:
		get_tree().change_scene_to_file("res://scenes/Setup.tscn")
