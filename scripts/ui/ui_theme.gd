class_name UiTheme
extends RefCounted
## Shared look for menus: pixel font at a whole-number scale, framed buttons
## with a yellow focus border.

const ACCENT := Color8(255, 208, 64)
const DIM := Color8(150, 160, 190)
const TEXT := Color8(240, 240, 248)
const PANEL := Color8(10, 12, 28, 200)
const PANEL_EDGE := Color8(255, 255, 255, 70)


## Minimum button height for fingers, as a fraction of the window height
## (about Apple's 44 pt on a landscape phone).
const TOUCH_BUTTON_FRAC := 0.11


## Pixel scale for a window height: whole multiples of the 8 px font.
static func scale_for(window_height: int) -> int:
	return maxi(1, window_height / 320)


## Gives `button` a finger-sized minimum height in touch mode.
static func size_for_touch(button: Button, window_height: int, frac: float = TOUCH_BUTTON_FRAC) -> void:
	if Game.touch_mode():
		button.custom_minimum_size.y = roundf(window_height * frac)


static func apply(theme: Theme, scale: int) -> void:
	theme.default_font_size = Hud.FONT_PX * scale
	theme.set_stylebox("normal", "Button", _box(PANEL, PANEL_EDGE, scale))
	theme.set_stylebox("hover", "Button", _box(PANEL, PANEL_EDGE, scale))
	theme.set_stylebox("pressed", "Button", _box(PANEL, ACCENT, scale))
	theme.set_stylebox("focus", "Button", _box(Color.TRANSPARENT, ACCENT, scale))
	theme.set_stylebox("disabled", "Button", _box(Color8(10, 12, 28, 120), Color8(255, 255, 255, 25), scale))
	theme.set_color("font_color", "Button", TEXT)
	theme.set_color("font_hover_color", "Button", TEXT)
	theme.set_color("font_focus_color", "Button", ACCENT)
	theme.set_color("font_pressed_color", "Button", ACCENT)
	theme.set_color("font_disabled_color", "Button", Color8(110, 116, 140))
	theme.set_constant("h_separation", "GridContainer", 6 * scale)
	theme.set_constant("v_separation", "GridContainer", 2 * scale)
	theme.set_constant("separation", "HBoxContainer", 6 * scale)
	theme.set_constant("separation", "VBoxContainer", 3 * scale)


static func _box(fill: Color, edge: Color, scale: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = edge
	box.set_border_width_all(scale)
	box.content_margin_left = 4 * scale
	box.content_margin_right = 4 * scale
	box.content_margin_top = 2 * scale
	box.content_margin_bottom = 2 * scale
	return box
