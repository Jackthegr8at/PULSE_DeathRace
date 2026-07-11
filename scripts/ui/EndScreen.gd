extends CanvasLayer
## Post-match overlay — styled result card with Rematch / Setup.

signal rematch_requested
signal setup_requested

@onready var dim: ColorRect = %Dim
@onready var panel: PanelContainer = %Panel
@onready var title_label: Label = %TitleLabel
@onready var detail_label: Label = %DetailLabel
@onready var rematch_button: Button = %RematchButton
@onready var setup_button: Button = %SetupButton
@onready var accent: ColorRect = %Accent


func _ready() -> void:
	visible = false
	_apply_styles()
	rematch_button.pressed.connect(func() -> void: rematch_requested.emit())
	setup_button.pressed.connect(func() -> void: setup_requested.emit())


func _apply_styles() -> void:
	panel.add_theme_stylebox_override(
		"panel",
		GameStyle.comic_panel(GameStyle.SURFACE, 16.0)
	)
	GameStyle.apply_label(detail_label, GameStyle.TEXT_MUTED, 15)
	var primary := GameStyle.button_primary()
	GameStyle.apply_button(rematch_button, primary, GameStyle.BG_DEEP)
	rematch_button.add_theme_font_size_override("font_size", 16)
	rematch_button.custom_minimum_size = Vector2(150, 46)
	GameStyle.apply_button(setup_button, GameStyle.button_ghost())
	setup_button.add_theme_font_size_override("font_size", 16)
	setup_button.custom_minimum_size = Vector2(150, 46)
	if dim:
		dim.color = Color(0, 0, 0, 0.62)


func show_result(player_won: bool, detail: String = "") -> void:
	visible = true
	detail_label.text = detail
	if player_won:
		title_label.text = "YOU WIN!"
		GameStyle.apply_title(title_label, GameStyle.SUCCESS, 42)
		if accent:
			accent.color = GameStyle.SUCCESS
	else:
		title_label.text = "WRECKED!"
		GameStyle.apply_title(title_label, GameStyle.DANGER, 42)
		if accent:
			accent.color = GameStyle.DANGER

	# Ensure layout so pivot is centered for scale pop
	await get_tree().process_frame
	if is_instance_valid(panel):
		panel.pivot_offset = panel.size * 0.5

	# Pop-in animation
	panel.scale = Vector2(0.92, 0.92)
	panel.modulate.a = 0.0
	dim.modulate.a = 0.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(dim, "modulate:a", 1.0, 0.2)
	tw.tween_property(panel, "modulate:a", 1.0, 0.22)
	tw.tween_property(panel, "scale", Vector2.ONE, 0.28).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
