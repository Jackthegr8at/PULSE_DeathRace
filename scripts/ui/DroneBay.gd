extends Control
## Persistent drone shop/equipment screen with an isolated presentation viewport.

const SETUP_SCENE := "res://scenes/Setup.tscn"
const PREVIEW_SIZE := Vector2i(760, 520)

var _selected_drone_id: String = DroneCatalog.SCRAPJAW_ID
var _selected_tier: int = 1
var _wallet_label: Label
var _name_label: Label
var _rarity_label: Label
var _description_label: Label
var _stats_label: Label
var _status_label: Label
var _action_button: Button
var _unequip_button: Button
var _tier_buttons: Dictionary = {}
var _preview_root: Node3D
var _preview_model: Node3D
var _dragging := false
var _last_mouse_x := 0.0


func _ready() -> void:
	_build_ui()
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().change_scene_to_file(SETUP_SCENE)
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging = event.pressed
		_last_mouse_x = event.position.x
	elif event is InputEventMouseMotion and _dragging and is_instance_valid(_preview_root):
		var mouse_motion := event as InputEventMouseMotion
		var delta_x: float = mouse_motion.position.x - _last_mouse_x
		_last_mouse_x = mouse_motion.position.x
		_preview_root.rotate_y(-delta_x * 0.008)


func _process(delta: float) -> void:
	if is_instance_valid(_preview_root) and not _dragging:
		_preview_root.rotate_y(delta * 0.22)


func _build_ui() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = Color("05090c")
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)

	var vignette := ColorRect.new()
	vignette.color = Color(0.03, 0.0, 0.04, 0.34)
	vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vignette)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_bottom", 22)
	add_child(margin)

	var main := VBoxContainer.new()
	main.add_theme_constant_override("separation", 14)
	margin.add_child(main)

	var header := HBoxContainer.new()
	header.custom_minimum_size.y = 72
	main.add_child(header)
	var title := Label.new()
	title.text = "PULSE DRONE BAY"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	GameStyle.apply_title(title, GameStyle.SETUP_CYAN, 42)
	header.add_child(title)
	_wallet_label = Label.new()
	_wallet_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_wallet_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_wallet_label.custom_minimum_size.x = 230
	GameStyle.apply_display_label(_wallet_label, GameStyle.SETUP_YELLOW, 29)
	header.add_child(_wallet_label)

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 14)
	main.add_child(body)

	body.add_child(_build_drone_list())
	body.add_child(_build_preview())
	body.add_child(_build_details())

	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_END
	main.add_child(footer)
	var back := Button.new()
	back.text = "BACK TO SETUP"
	back.custom_minimum_size = Vector2(230, 54)
	GameStyle.apply_button(back, GameStyle.button_ghost())
	back.add_theme_font_size_override("font_size", 23)
	back.pressed.connect(func() -> void: get_tree().change_scene_to_file(SETUP_SCENE))
	footer.add_child(back)


func _build_drone_list() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 250
	panel.add_theme_stylebox_override(
		"panel",
		GameStyle.setup_panel(Color("081218"), GameStyle.SETUP_PURPLE, 2)
	)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	var heading := Label.new()
	heading.text = "DRONES"
	GameStyle.apply_display_label(heading, GameStyle.SETUP_PURPLE, 25)
	box.add_child(heading)
	for drone_id in DroneCatalog.get_all_ids():
		var entry := DroneCatalog.get_drone(drone_id)
		var button := Button.new()
		button.text = str(entry.get("display_name", drone_id)).to_upper()
		button.custom_minimum_size.y = 62
		GameStyle.apply_button(button, GameStyle.setup_choice_styles(GameStyle.SETUP_PURPLE, true))
		button.add_theme_font_size_override("font_size", 22)
		button.pressed.connect(_select_drone.bind(drone_id))
		box.add_child(button)
	var note := Label.new()
	note.text = "Autonomous combat companions.\nOne drone may be equipped."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.size_flags_vertical = Control.SIZE_EXPAND_FILL
	GameStyle.apply_label(note, GameStyle.TEXT_MUTED, 14)
	box.add_child(note)
	return panel


func _build_preview() -> Control:
	var frame := PanelContainer.new()
	frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	frame.add_theme_stylebox_override(
		"panel",
		GameStyle.setup_panel(Color("050a0e"), GameStyle.SETUP_CYAN.darkened(0.45), 2)
	)
	var viewport_container := SubViewportContainer.new()
	viewport_container.stretch = true
	viewport_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	viewport_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	viewport_container.custom_minimum_size = Vector2(430, 350)
	frame.add_child(viewport_container)

	var viewport := SubViewport.new()
	viewport.size = PREVIEW_SIZE
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	viewport_container.add_child(viewport)

	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("071014")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("ead9ed")
	env.ambient_light_energy = 0.82
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.environment = env
	viewport.add_child(environment)

	var camera := Camera3D.new()
	camera.position = Vector3(0, 1.4, 5.8)
	camera.fov = 42
	camera.look_at_from_position(camera.position, Vector3(0, 0.25, 0), Vector3.UP)
	viewport.add_child(camera)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-48, -32, 0)
	key.light_color = Color("ffe7d7")
	key.light_energy = 1.35
	viewport.add_child(key)
	var rim := OmniLight3D.new()
	rim.position = Vector3(-2.8, 2.2, -1.5)
	rim.light_color = GameStyle.SETUP_PURPLE
	rim.light_energy = 5.0
	rim.omni_range = 8.0
	viewport.add_child(rim)

	_preview_root = Node3D.new()
	viewport.add_child(_preview_root)
	return frame


func _build_details() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 330
	panel.add_theme_stylebox_override(
		"panel",
		GameStyle.setup_panel(Color("081218"), GameStyle.SETUP_EDGE, 2)
	)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	_name_label = Label.new()
	GameStyle.apply_title(_name_label, GameStyle.SETUP_PURPLE, 34)
	box.add_child(_name_label)
	_rarity_label = Label.new()
	GameStyle.apply_display_label(_rarity_label, GameStyle.SETUP_CYAN, 21)
	box.add_child(_rarity_label)
	_description_label = Label.new()
	_description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_description_label.custom_minimum_size.y = 80
	GameStyle.apply_label(_description_label, GameStyle.TEXT_MUTED, 15)
	box.add_child(_description_label)
	_stats_label = Label.new()
	_stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	GameStyle.apply_bold_label(_stats_label, GameStyle.TEXT, 15)
	box.add_child(_stats_label)

	var tier_title := Label.new()
	tier_title.text = "SELECT TIER"
	GameStyle.apply_display_label(tier_title, GameStyle.TEXT, 20)
	box.add_child(tier_title)
	var tier_row := HBoxContainer.new()
	tier_row.add_theme_constant_override("separation", 6)
	box.add_child(tier_row)
	for tier in range(DroneCatalog.MIN_TIER, DroneCatalog.MAX_TIER + 1):
		var tier_button := Button.new()
		tier_button.text = str(tier)
		tier_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tier_button.custom_minimum_size.y = 48
		GameStyle.apply_button(tier_button, GameStyle.setup_choice_styles(GameStyle.SETUP_PURPLE))
		tier_button.pressed.connect(_select_tier.bind(tier))
		tier_row.add_child(tier_button)
		_tier_buttons[tier] = tier_button

	_status_label = Label.new()
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	GameStyle.apply_bold_label(_status_label, GameStyle.TEXT_MUTED, 15)
	box.add_child(_status_label)
	_action_button = Button.new()
	_action_button.custom_minimum_size.y = 56
	_action_button.pressed.connect(_on_action_pressed)
	box.add_child(_action_button)
	_unequip_button = Button.new()
	_unequip_button.text = "UNEQUIP DRONE"
	_unequip_button.custom_minimum_size.y = 48
	GameStyle.apply_button(_unequip_button, GameStyle.button_ghost())
	_unequip_button.pressed.connect(_on_unequip_pressed)
	box.add_child(_unequip_button)
	return panel


func _select_drone(drone_id: String) -> void:
	_selected_drone_id = drone_id
	_selected_tier = clampi(maxi(GarageProfile.owned_drone_tier(drone_id), 1), 1, 4)
	_refresh()


func _select_tier(tier: int) -> void:
	_selected_tier = clampi(tier, DroneCatalog.MIN_TIER, DroneCatalog.MAX_TIER)
	_refresh()


func _refresh() -> void:
	var drone := DroneCatalog.get_drone(_selected_drone_id)
	var tier_data := DroneCatalog.get_tier(_selected_drone_id, _selected_tier)
	var tier_available := DroneCatalog.is_tier_available(_selected_drone_id, _selected_tier)
	var equipped := GarageProfile.equipped_drone()
	var owned_tier := GarageProfile.owned_drone_tier(_selected_drone_id)
	var owned := GarageProfile.owns_drone_tier(_selected_drone_id, _selected_tier)
	var price := DroneCatalog.get_price(_selected_drone_id, _selected_tier)
	_wallet_label.text = "CREDITS  %d" % GarageProfile.credit_balance()
	_name_label.text = str(drone.get("display_name", "DRONE")).to_upper()
	_rarity_label.text = "TIER %d  •  %s  •  %s" % [
		_selected_tier,
		str(tier_data.get("label", "")),
		str(drone.get("ability", "")),
	]
	_description_label.text = str(drone.get("description", ""))
	if not tier_available:
		_stats_label.text = "COMING SOON\nMODEL IN DEVELOPMENT"
	elif DroneCatalog.get_attack_type(_selected_drone_id) == "bombdrop":
		_stats_label.text = (
			"BOMBDROP: %d MINES\nDAMAGE: %d%% MISSILE DAMAGE\n"
			+ "COOLDOWN: %.0f SECONDS\nMINE LIFE: %.1f SECONDS"
		) % [
			int(tier_data.get("bomb_count", 0)),
			int(round(float(tier_data.get("damage_ratio", 0.0)) * 100.0)),
			float(tier_data.get("cooldown", 0.0)),
			float(tier_data.get("mine_lifetime", 0.0)),
		]
	else:
		_stats_label.text = "ATTACK: %d%% MISSILE DAMAGE\nCOOLDOWN: %.0f SECONDS\nTARGET RANGE: 12 METERS" % [
			int(round(float(tier_data.get("damage_ratio", 0.0)) * 100.0)),
			float(tier_data.get("cooldown", 0.0)),
		]
	for tier in _tier_buttons:
		var tier_button := _tier_buttons[tier] as Button
		GameStyle.apply_button(
			tier_button,
			GameStyle.setup_choice_styles(GameStyle.SETUP_PURPLE, int(tier) == _selected_tier)
		)
		tier_button.text = "%d%s" % [int(tier), " ✓" if int(tier) <= owned_tier else ""]
		if not DroneCatalog.is_tier_available(_selected_drone_id, int(tier)):
			tier_button.text = "%d —" % int(tier)

	var is_equipped := (
		str(equipped.get("id", "")) == _selected_drone_id
		and int(equipped.get("tier", 0)) == _selected_tier
	)
	if not tier_available:
		_status_label.text = "THIS TIER IS COMING SOON"
		_action_button.text = "MODEL IN DEVELOPMENT"
		_action_button.disabled = true
	elif is_equipped:
		_status_label.text = "THIS DRONE IS EQUIPPED"
		_action_button.text = "EQUIPPED"
		_action_button.disabled = true
	elif owned:
		_status_label.text = "OWNED — READY TO EQUIP"
		_action_button.text = "EQUIP TIER %d" % _selected_tier
		_action_button.disabled = false
	elif _selected_tier > 1 and owned_tier < _selected_tier - 1:
		_status_label.text = "PURCHASE TIER %d FIRST" % (_selected_tier - 1)
		_action_button.text = "LOCKED"
		_action_button.disabled = true
	else:
		_status_label.text = "PRICE: %d CREDITS" % price
		_action_button.text = "PURCHASE  %d" % price
		_action_button.disabled = GarageProfile.credit_balance() < price
	GameStyle.apply_button(_action_button, GameStyle.setup_start_styles(), GameStyle.INK)
	_action_button.add_theme_font_size_override("font_size", 23)
	_unequip_button.visible = str(equipped.get("id", "")).is_empty() == false
	_reload_preview()


func _reload_preview() -> void:
	if is_instance_valid(_preview_model):
		_preview_model.queue_free()
		_preview_model = null
	if not DroneCatalog.is_tier_available(_selected_drone_id, _selected_tier):
		return
	var packed := load(DroneCatalog.get_scene_path(_selected_drone_id, _selected_tier)) as PackedScene
	if packed == null:
		_status_label.text = "PREVIEW MODEL COULD NOT BE LOADED"
		return
	_preview_model = packed.instantiate() as Node3D
	if _preview_model == null:
		return
	_preview_root.add_child(_preview_model)
	_preview_model.rotation.y = deg_to_rad(
		DroneCatalog.get_model_yaw_degrees(_selected_drone_id)
	)
	_prepare_preview_node(_preview_model)
	await get_tree().process_frame
	if not is_instance_valid(_preview_model):
		return
	var bounds := _visual_bounds(_preview_model)
	var largest := maxf(bounds.size.x, maxf(bounds.size.y, bounds.size.z))
	if largest > 0.001:
		_preview_model.scale = Vector3.ONE * (3.2 / largest)
		await get_tree().process_frame
		bounds = _visual_bounds(_preview_model)
	_preview_model.position -= bounds.get_center()


func _visual_bounds(root: Node3D) -> AABB:
	var merged := AABB()
	var has_bounds := false
	var inverse := root.global_transform.affine_inverse()
	for descendant in root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := descendant as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null:
			continue
		var transformed := (inverse * mesh_instance.global_transform) * mesh_instance.get_aabb()
		merged = transformed if not has_bounds else merged.merge(transformed)
		has_bounds = true
	return merged


func _prepare_preview_node(node: Node) -> void:
	node.process_mode = Node.PROCESS_MODE_DISABLED
	if node is CollisionObject3D:
		(node as CollisionObject3D).collision_layer = 0
		(node as CollisionObject3D).collision_mask = 0
	if node is GeometryInstance3D:
		(node as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for child in node.get_children():
		_prepare_preview_node(child)


func _on_action_pressed() -> void:
	if GarageProfile.owns_drone_tier(_selected_drone_id, _selected_tier):
		GarageProfile.equip_drone(_selected_drone_id, _selected_tier)
	else:
		GarageProfile.purchase_drone_tier(_selected_drone_id, _selected_tier)
	_refresh()


func _on_unequip_pressed() -> void:
	GarageProfile.unequip_drone()
	_refresh()
