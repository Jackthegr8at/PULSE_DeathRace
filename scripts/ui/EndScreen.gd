extends CanvasLayer
## Post-match overlay with Rematch and Setup actions.

signal rematch_requested
signal setup_requested

@onready var panel: PanelContainer = %Panel
@onready var title_label: Label = %TitleLabel
@onready var detail_label: Label = %DetailLabel
@onready var rematch_button: Button = %RematchButton
@onready var setup_button: Button = %SetupButton


func _ready() -> void:
	visible = false
	rematch_button.pressed.connect(func() -> void: rematch_requested.emit())
	setup_button.pressed.connect(func() -> void: setup_requested.emit())


func show_result(player_won: bool, detail: String = "") -> void:
	visible = true
	if player_won:
		title_label.text = "YOU WIN!"
		title_label.add_theme_color_override("font_color", Color(0.45, 0.95, 0.55))
	else:
		title_label.text = "GAME OVER"
		title_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
	detail_label.text = detail
