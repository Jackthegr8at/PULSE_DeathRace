class_name GameStyle
extends RefCounted
## Neon arena palette from concept art (docs/mockups/2.jpg).

const BG := Color("0a0c12")
const BG_DEEP := Color("05060c")
const SURFACE := Color(0.06, 0.08, 0.12, 0.82)
const SURFACE_RAISED := Color(0.08, 0.1, 0.16, 0.88)
const SURFACE_HOVER := Color(0.12, 0.16, 0.24, 0.95)
const BORDER := Color(0.25, 0.45, 0.65, 0.55)
const BORDER_GLOW := Color(0.3, 0.85, 1.0, 0.65)

const ACCENT := Color("ffd54a")
const ACCENT_DIM := Color("c49a28")
const SUCCESS := Color("3dff9a")
const DANGER := Color("ff3b4a")
const WARNING := Color("ff8a3d")
const INFO := Color("2ef0ff")
const PURPLE := Color("b14dff")
const PINK := Color("ff3d9a")

const TEXT := Color("f2f6ff")
const TEXT_MUTED := Color("8b9bb8")
const TEXT_DIM := Color("5c667a")

const HP_HIGH := Color("3dff9a")
const HP_MID := Color("ffd54a")
const HP_LOW := Color("ff3b4a")

const NEON_CYAN := Color("2ef0ff")
const NEON_PURPLE := Color("b14dff")
const NEON_PINK := Color("ff3d9a")


static func panel(bg: Color = SURFACE, border: Color = BORDER, radius: float = 12.0, border_w: float = 1.0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(int(radius))
	s.border_color = border
	s.set_border_width_all(int(border_w))
	s.content_margin_left = 14
	s.content_margin_right = 14
	s.content_margin_top = 10
	s.content_margin_bottom = 10
	s.shadow_color = Color(0, 0, 0, 0.45)
	s.shadow_size = 8
	s.shadow_offset = Vector2(0, 4)
	return s


static func chip(bg: Color = SURFACE_RAISED, border: Color = BORDER) -> StyleBoxFlat:
	var s := panel(bg, border, 10.0, 1.0)
	s.content_margin_left = 10
	s.content_margin_right = 10
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	return s


static func glass_chip() -> StyleBoxFlat:
	## Translucent dark panel with cyan edge (concept HUD).
	return chip(Color(0.05, 0.07, 0.12, 0.78), Color(0.18, 0.55, 0.75, 0.45))


static func button_normal(bg: Color = SURFACE_RAISED, border: Color = BORDER) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(10)
	s.border_color = border
	s.set_border_width_all(1)
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
		"normal": button_normal(Color(0.75, 0.55, 0.1, 1), ACCENT),
		"hover": button_normal(Color(0.95, 0.75, 0.2, 1), ACCENT.lightened(0.15)),
		"pressed": button_normal(Color(0.55, 0.4, 0.08, 1), ACCENT_DIM),
	}


static func button_ghost() -> Dictionary:
	return {
		"normal": button_normal(Color(0.06, 0.08, 0.12, 0.9), BORDER),
		"hover": button_normal(Color(0.1, 0.14, 0.2, 0.95), BORDER_GLOW),
		"pressed": button_normal(Color(0.15, 0.18, 0.25, 1), TEXT_MUTED),
	}


static func button_selected() -> StyleBoxFlat:
	return button_normal(Color(0.2, 0.16, 0.05, 0.95), ACCENT)


static func progress_bg() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.02, 0.03, 0.05, 0.9)
	s.set_corner_radius_all(6)
	s.border_color = Color(1, 1, 1, 0.06)
	s.set_border_width_all(1)
	return s


static func progress_fill(color: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(6)
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
