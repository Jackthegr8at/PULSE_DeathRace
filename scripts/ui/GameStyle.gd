class_name GameStyle
extends RefCounted
## Shared DeathRace UI palette and StyleBox helpers (arcade / neon dark).

const BG := Color("0b0d14")
const BG_DEEP := Color("07080e")
const SURFACE := Color("141a24")
const SURFACE_RAISED := Color("1c2433")
const SURFACE_HOVER := Color("253044")
const BORDER := Color("2e3a4f")
const BORDER_GLOW := Color("3d4f6f")

const ACCENT := Color("f5c842") ## Gold / pulse
const ACCENT_DIM := Color("c49a28")
const SUCCESS := Color("3dd68c")
const DANGER := Color("ff4d5a")
const WARNING := Color("ff9f43")
const INFO := Color("4db8ff")
const PURPLE := Color("a78bfa")

const TEXT := Color("eef2f8")
const TEXT_MUTED := Color("8b95a8")
const TEXT_DIM := Color("5c667a")

const HP_HIGH := Color("3dd68c")
const HP_MID := Color("f5c842")
const HP_LOW := Color("ff4d5a")


static func panel(bg: Color = SURFACE, border: Color = BORDER, radius: float = 10.0, border_w: float = 2.0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(int(radius))
	s.border_color = border
	s.set_border_width_all(int(border_w))
	s.content_margin_left = 16
	s.content_margin_right = 16
	s.content_margin_top = 14
	s.content_margin_bottom = 14
	return s


static func chip(bg: Color = SURFACE_RAISED, border: Color = BORDER) -> StyleBoxFlat:
	var s := panel(bg, border, 8.0, 1.0)
	s.content_margin_left = 12
	s.content_margin_right = 12
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	return s


static func button_normal(bg: Color = SURFACE_RAISED, border: Color = BORDER) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(8)
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
	## Returns normal/hover/pressed StyleBoxFlat for the main CTA.
	return {
		"normal": button_normal(ACCENT_DIM.darkened(0.15), ACCENT),
		"hover": button_normal(ACCENT.darkened(0.05), ACCENT.lightened(0.15)),
		"pressed": button_normal(ACCENT.darkened(0.25), ACCENT_DIM),
	}


static func button_ghost() -> Dictionary:
	return {
		"normal": button_normal(SURFACE, BORDER),
		"hover": button_normal(SURFACE_HOVER, BORDER_GLOW),
		"pressed": button_normal(BORDER, TEXT_MUTED),
	}


static func button_selected() -> StyleBoxFlat:
	return button_normal(Color(0.25, 0.2, 0.08), ACCENT)


static func progress_bg() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.08, 0.1, 0.14, 0.95)
	s.set_corner_radius_all(4)
	s.content_margin_left = 0
	s.content_margin_right = 0
	s.content_margin_top = 0
	s.content_margin_bottom = 0
	return s


static func progress_fill(color: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(4)
	return s


static func apply_button(btn: Button, styles: Dictionary, font_color: Color = TEXT) -> void:
	btn.add_theme_stylebox_override("normal", styles["normal"])
	btn.add_theme_stylebox_override("hover", styles["hover"])
	btn.add_theme_stylebox_override("pressed", styles["pressed"])
	btn.add_theme_stylebox_override("focus", styles["hover"])
	btn.add_theme_stylebox_override("disabled", button_normal(SURFACE.darkened(0.2), BORDER.darkened(0.2)))
	btn.add_theme_color_override("font_color", font_color)
	btn.add_theme_color_override("font_hover_color", font_color.lightened(0.1))
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
