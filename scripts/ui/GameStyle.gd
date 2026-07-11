class_name GameStyle
extends RefCounted
## Warm painterly UI palette (adventure-game feel, minimal neon).

const BG := Color("294b2b")
const BG_DEEP := Color("17251a")
const SURFACE := Color(0.15, 0.18, 0.13, 0.94)
const SURFACE_RAISED := Color(0.27, 0.20, 0.12, 0.96)
const SURFACE_HOVER := Color(0.38, 0.29, 0.16, 0.98)
const BORDER := Color(0.08, 0.07, 0.05, 0.96)
const BORDER_GLOW := Color(0.82, 0.58, 0.22, 0.98)
const INK := Color("17160f")
const WOOD := Color("9b552d")
const WOOD_LIGHT := Color("d17d3e")
const FIELD := Color("5b9d43")
const EARTH := Color("b9773e")
const SKY := Color("77c8be")

const ACCENT := Color("e8b84a") ## Warm gold
const ACCENT_DIM := Color("b8892e")
const SUCCESS := Color("5ecf6a")
const DANGER := Color("e04b4b")
const WARNING := Color("e8923a")
const INFO := Color("5a9e6a") ## Soft green-teal, not electric cyan
const PURPLE := Color("8b6bb0")
const PINK := Color("c45c6a")

const TEXT := Color("f4f0e4")
const TEXT_MUTED := Color("a8a090")
const TEXT_DIM := Color("6e6858")

const HP_HIGH := Color("5ecf6a")
const HP_MID := Color("e8b84a")
const HP_LOW := Color("e04b4b")


static func panel(bg: Color = SURFACE, border: Color = BORDER, radius: float = 12.0, border_w: float = 2.0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(int(radius))
	s.border_color = border
	s.set_border_width_all(int(border_w))
	s.content_margin_left = 14
	s.content_margin_right = 14
	s.content_margin_top = 10
	s.content_margin_bottom = 10
	s.shadow_color = Color(0, 0, 0, 0.35)
	s.shadow_size = 6
	s.shadow_offset = Vector2(0, 3)
	return s


static func chip(bg: Color = SURFACE_RAISED, border: Color = BORDER) -> StyleBoxFlat:
	var s := panel(bg, border, 10.0, 2.0)
	s.content_margin_left = 10
	s.content_margin_right = 10
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	return s


static func glass_chip() -> StyleBoxFlat:
	## Painted wood/metal badge: warm surface, comic ink outline, soft lift.
	return concept_panel(Color(0.12, 0.15, 0.1, 0.94), BORDER, 10.0, 3.0)


static func concept_panel(bg: Color = SURFACE, border: Color = BORDER, radius: float = 12.0, border_w: float = 3.0) -> StyleBoxFlat:
	var s := panel(bg, border, radius, border_w)
	s.shadow_color = Color(0.03, 0.04, 0.02, 0.55)
	s.shadow_size = 8
	s.shadow_offset = Vector2(0, 4)
	return s


static func button_normal(bg: Color = SURFACE_RAISED, border: Color = BORDER) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(10)
	s.border_color = border
	s.set_border_width_all(2)
	s.content_margin_left = 16
	s.content_margin_right = 16
	s.content_margin_top = 10
	s.content_margin_bottom = 10
	return s


static func button_hover(bg: Color = SURFACE_HOVER, border: Color = BORDER_GLOW) -> StyleBoxFlat:
	return button_normal(bg, border)


static func button_pressed(bg: Color = BORDER, border: Color = ACCENT) -> StyleBoxFlat:
	return button_normal(bg, border)


static func button_primary() -> Dictionary:
	return {
		"normal": button_normal(Color(0.72, 0.52, 0.15, 1), Color(0.15, 0.1, 0.05)),
		"hover": button_normal(Color(0.88, 0.65, 0.22, 1), Color(0.2, 0.14, 0.06)),
		"pressed": button_normal(Color(0.55, 0.4, 0.1, 1), Color(0.1, 0.08, 0.04)),
	}


static func button_ghost() -> Dictionary:
	return {
		"normal": button_normal(Color(0.14, 0.18, 0.13, 0.95), BORDER),
		"hover": button_normal(Color(0.2, 0.26, 0.18, 0.95), BORDER_GLOW),
		"pressed": button_normal(Color(0.1, 0.12, 0.1, 1), TEXT_MUTED),
	}


static func button_selected() -> StyleBoxFlat:
	return button_normal(Color(0.28, 0.22, 0.1, 0.95), ACCENT)


static func progress_bg() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.08, 0.1, 0.07, 0.9)
	s.set_corner_radius_all(6)
	s.border_color = Color(0.1, 0.08, 0.05, 0.8)
	s.set_border_width_all(2)
	return s


static func progress_fill(color: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(5)
	return s


static func apply_button(btn: Button, styles: Dictionary, font_color: Color = TEXT) -> void:
	btn.add_theme_stylebox_override("normal", styles["normal"])
	btn.add_theme_stylebox_override("hover", styles["hover"])
	btn.add_theme_stylebox_override("pressed", styles["pressed"])
	btn.add_theme_stylebox_override("focus", styles["hover"])
	btn.add_theme_stylebox_override("disabled", button_normal(SURFACE.darkened(0.2), BORDER.darkened(0.2)))
	btn.add_theme_color_override("font_color", font_color)
	btn.add_theme_color_override("font_hover_color", font_color.lightened(0.08))
	btn.add_theme_color_override("font_pressed_color", font_color.darkened(0.1))
	btn.add_theme_color_override("font_disabled_color", TEXT_DIM)


static func apply_label(label: Label, color: Color = TEXT, size: int = 14) -> void:
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", size)


static func hp_color(ratio: float) -> Color:
	if ratio > 0.55:
		return HP_HIGH
	if ratio > 0.28:
		return HP_MID
	return HP_LOW
