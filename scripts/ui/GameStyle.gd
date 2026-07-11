class_name GameStyle
extends RefCounted
## Vibrant painterly toon UI (BotW-style color, Borderlands comic ink).
## Thick black outlines, saturated colors, chunky hand-painted feel.

const BG := Color("2e5a30")
const BG_DEEP := Color("1a2c1c")
const SURFACE := Color(0.13, 0.17, 0.12, 0.95)
const SURFACE_RAISED := Color(0.30, 0.22, 0.12, 0.97)
const SURFACE_HOVER := Color(0.42, 0.32, 0.17, 0.98)
const BORDER := Color(0.05, 0.045, 0.035, 1.0)
const BORDER_GLOW := Color(0.95, 0.68, 0.22, 1.0)
const INK := Color("12100a")
const WOOD := Color("a85c2e")
const WOOD_LIGHT := Color("e08a44")
const FIELD := Color("63b545")
const EARTH := Color("c68042")
const SKY := Color("6fd0c4")

const ACCENT := Color("ffc94d") ## Vivid warm gold
const ACCENT_DIM := Color("c4952f")
const SUCCESS := Color("64e070")
const DANGER := Color("f04f4f")
const WARNING := Color("ff9d3a")
const INFO := Color("5fb87a") ## Soft green-teal, not electric cyan
const PURPLE := Color("9a76c4")
const PINK := Color("d96274")

const TEXT := Color("faf5e6")
const TEXT_MUTED := Color("b5ac98")
const TEXT_DIM := Color("776f5c")

const HP_HIGH := Color("64e070")
const HP_MID := Color("ffc94d")
const HP_LOW := Color("f04f4f")


static func panel(bg: Color = SURFACE, border: Color = BORDER, radius: float = 12.0, border_w: float = 3.0) -> StyleBoxFlat:
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
	return comic_panel(Color(0.12, 0.15, 0.1, 0.95), 10.0)


static func comic_panel(bg: Color = SURFACE, radius: float = 12.0) -> StyleBoxFlat:
	## Comic-sticker panel: thick pure-ink border + hard offset shadow.
	var s := panel(bg, INK, radius, 4.0)
	s.shadow_color = Color(INK.r, INK.g, INK.b, 0.85)
	s.shadow_size = 0
	s.shadow_offset = Vector2(4, 5)
	return s


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
	s.set_border_width_all(3)
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


static func apply_title(label: Label, color: Color = ACCENT, size: int = 32) -> void:
	## Comic title: vibrant fill + thick black ink outline.
	apply_label(label, color, size)
	label.add_theme_color_override("font_outline_color", INK)
	label.add_theme_constant_override("outline_size", maxi(int(size * 0.22), 4))


static func hp_color(ratio: float) -> Color:
	if ratio > 0.55:
		return HP_HIGH
	if ratio > 0.28:
		return HP_MID
	return HP_LOW
