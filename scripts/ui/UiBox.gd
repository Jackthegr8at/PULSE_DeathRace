class_name UiBox
extends Control
## Reusable Pulse metal frame UI panel.
## Uses painted box art (datas_box / startup_box) instead of flat StyleBox colors.

enum FrameKind {
	DATA, ## General HUD / dossier / row frames (datas_box.png)
	STARTUP, ## Large modal frames (startup_box.png)
}

const TEX_DATA: Texture2D = preload("res://assets/ui/hud/datas_box.png")
const TEX_STARTUP: Texture2D = preload("res://assets/ui/hud/startup_box.png")

## Softens only the dark interior so content reads clearly on the painted frame.
const INNER_SHADER := """
shader_type canvas_item;

void fragment() {
	vec4 pixel = texture(TEXTURE, UV);
	float inside_x = smoothstep(0.07, 0.12, UV.x) * (1.0 - smoothstep(0.88, 0.93, UV.x));
	float inside_y = smoothstep(0.10, 0.18, UV.y) * (1.0 - smoothstep(0.82, 0.90, UV.y));
	float darkness = 1.0 - smoothstep(0.04, 0.20, max(pixel.r, max(pixel.g, pixel.b)));
	pixel.a *= mix(1.0, 0.78, inside_x * inside_y * darkness);
	COLOR = pixel * COLOR;
}
"""

@export var frame_kind: FrameKind = FrameKind.DATA
## Content insets L/T/R/B inside the metal border.
@export var content_margin: Vector4 = Vector4(28, 20, 28, 20)
@export var use_inner_shader: bool = true
@export var frame_modulate: Color = Color.WHITE

var frame: NinePatchRect
var content: MarginContainer


func _ready() -> void:
	if frame == null:
		_build()


func _build() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP

	frame = NinePatchRect.new()
	frame.name = "Frame"
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.texture = TEX_STARTUP if frame_kind == FrameKind.STARTUP else TEX_DATA
	frame.modulate = frame_modulate
	# Margins tuned for the riveted corners of datas_box / startup_box art.
	if frame_kind == FrameKind.STARTUP:
		frame.patch_margin_left = 110
		frame.patch_margin_top = 90
		frame.patch_margin_right = 110
		frame.patch_margin_bottom = 90
	else:
		frame.patch_margin_left = 96
		frame.patch_margin_top = 72
		frame.patch_margin_right = 96
		frame.patch_margin_bottom = 72
	if use_inner_shader:
		var shader := Shader.new()
		shader.code = INNER_SHADER
		var mat := ShaderMaterial.new()
		mat.shader = shader
		frame.material = mat
	add_child(frame)
	move_child(frame, 0)

	content = MarginContainer.new()
	content.name = "Content"
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.add_theme_constant_override("margin_left", int(content_margin.x))
	content.add_theme_constant_override("margin_top", int(content_margin.y))
	content.add_theme_constant_override("margin_right", int(content_margin.z))
	content.add_theme_constant_override("margin_bottom", int(content_margin.w))
	add_child(content)


## Factory for code-built screens (Garage, Loading, HUD helpers).
static func create(
	kind: FrameKind = FrameKind.DATA,
	box_size: Vector2 = Vector2(200, 80),
	margins: Vector4 = Vector4(28, 20, 28, 20),
	modulate_color: Color = Color.WHITE
) -> UiBox:
	var box := UiBox.new()
	box.frame_kind = kind
	box.content_margin = margins
	box.frame_modulate = modulate_color
	box.custom_minimum_size = box_size
	box.size = box_size
	box._build()
	return box


## Compact chip / roster card margins.
static func create_chip(
	box_size: Vector2,
	modulate_color: Color = Color.WHITE
) -> UiBox:
	return create(
		FrameKind.DATA,
		box_size,
		Vector4(16, 12, 16, 12),
		modulate_color
	)


## Large modal / dossier margins.
static func create_panel(
	box_size: Vector2,
	modulate_color: Color = Color.WHITE
) -> UiBox:
	return create(
		FrameKind.DATA,
		box_size,
		Vector4(32, 24, 32, 24),
		modulate_color
	)


func set_frame_modulate(color: Color) -> void:
	frame_modulate = color
	if frame:
		frame.modulate = color


func add_content_child(node: Node) -> void:
	if content == null:
		_build()
	content.add_child(node)
