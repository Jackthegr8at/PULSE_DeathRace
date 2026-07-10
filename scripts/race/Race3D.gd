extends Node3D
## 3D race host: track, player + AI, combat win rules, HUD / end screen.

const VehicleScene: PackedScene = preload("res://scenes/vehicle.tscn")
const AI_MODELS: Array[String] = [
	"res://models/vehicle-truck-red.glb",
	"res://models/vehicle-truck-green.glb",
	"res://models/vehicle-truck-purple.glb",
	"res://models/vehicle-truck-yellow.glb",
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


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color(0.68, 0.76, 0.97))
	MatchConfig.ai_count = maxi(MatchConfig.ai_count, 3)
	_load_track()
	await get_tree().process_frame
	await get_tree().process_frame
	_spawn_field()
	_bind_camera()
	_spawn_hud()


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
		# Slightly easier targets
		ai.max_health = 100.0
		ai.health = 100.0
		ai.ai_throttle = 0.65
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
	var model_pos := pos - Vector3(0, 0.65, 0)
	var container := veh.get_node_or_null("Container") as Node3D
	if container:
		container.global_transform = Transform3D(basis, model_pos)
	if veh.vehicle_model:
		veh.vehicle_model.global_transform = Transform3D(basis, model_pos)
	veh.global_position = Vector3(pos.x, 0.0, pos.z)
	return veh


func _snap_spawn_to_ground(origin: Vector3) -> Vector3:
	## Raycast down onto track/ground; fall back to spawn height + hover.
	var space := get_world_3d().direct_space_state
	if space == null:
		return origin + Vector3(0, 0.55, 0)
	var from := origin + Vector3(0, 8.0, 0)
	var to := origin + Vector3(0, -20.0, 0)
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.collision_mask = 1 # world / grid
	var hit := space.intersect_ray(q)
	if hit and hit.has("position"):
		return hit.position + Vector3(0, 0.55, 0)
	return origin + Vector3(0, 0.55, 0)


func _swap_model(veh: Vehicle, glb_path: String) -> void:
	var container := veh.get_node_or_null("Container") as Node3D
	if container == null:
		return
	var old := container.get_node_or_null("Model")
	if old:
		old.queue_free()
	var packed := load(glb_path) as PackedScene
	if packed == null:
		return
	var model := packed.instantiate()
	model.name = "Model"
	container.add_child(model)
	# Re-bind body reference after model swap
	veh.vehicle_body = model.get_node_or_null("body")
	veh.wheel_fl = model.get_node_or_null("wheel-front-left")
	veh.wheel_fr = model.get_node_or_null("wheel-front-right")
	veh.wheel_bl = model.get_node_or_null("wheel-back-left")
	veh.wheel_br = model.get_node_or_null("wheel-back-right")


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
	_update_alive_hud()


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
	panel.custom_minimum_size = Vector2(400, 220)
	panel.add_theme_stylebox_override("panel", GameStyle.panel())
	center.add_child(panel)

	var margin := MarginContainer.new()
	for s in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(s, 24)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	margin.add_child(vbox)

	var title := Label.new()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if player_won:
		title.text = "YOU WIN!"
		GameStyle.apply_label(title, GameStyle.SUCCESS, 36)
	else:
		title.text = "GAME OVER"
		GameStyle.apply_label(title, GameStyle.DANGER, 36)
	vbox.add_child(title)

	var detail_l := Label.new()
	detail_l.text = detail
	detail_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	GameStyle.apply_label(detail_l, GameStyle.TEXT_MUTED, 14)
	vbox.add_child(detail_l)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	vbox.add_child(row)

	var rematch := Button.new()
	rematch.text = "Rematch"
	rematch.custom_minimum_size = Vector2(140, 44)
	GameStyle.apply_button(rematch, GameStyle.button_primary(), GameStyle.BG_DEEP)
	rematch.pressed.connect(func() -> void:
		get_tree().change_scene_to_file("res://scenes/race/Race3D.tscn")
	)
	row.add_child(rematch)

	var setup := Button.new()
	setup.text = "Setup"
	setup.custom_minimum_size = Vector2(140, 44)
	GameStyle.apply_button(setup, GameStyle.button_ghost())
	setup.pressed.connect(func() -> void:
		get_tree().change_scene_to_file("res://scenes/Setup.tscn")
	)
	row.add_child(setup)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not match_over:
		get_tree().change_scene_to_file("res://scenes/Setup.tscn")
