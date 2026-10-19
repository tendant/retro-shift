extends Control
## Garage hub (§2 core loop): pick an unlocked event, buy upgrades, toggle
## sound. Keyboard/gamepad navigation uses Godot's built-in ui_* actions.

const ACCENT := Color8(255, 208, 64)
const DIM := Color8(150, 160, 190)
const TEXT := Color8(240, 240, 248)
const PANEL := Color8(10, 12, 28, 200)
const PANEL_EDGE := Color8(255, 255, 255, 70)
const SOUNDS := {
	&"move": preload("res://assets/audio/ui_move.wav"),
	&"buy": preload("res://assets/audio/ui_buy.wav"),
	&"denied": preload("res://assets/audio/ui_denied.wav"),
	&"go": preload("res://assets/audio/beep_high.wav"),
}

var _ui_theme := Theme.new()
## Pixel scale for the bitmap font and art (whole multiples only).
var _scale: int = 1
var _credits: Label
var _event_buttons: Array[Button] = []
## {line: {"level": Label, "effect": Label, "buy": Button}}
var _rows: Dictionary = {}
var _music_button: Button
var _sfx_button: Button
var _sfx: AudioStreamPlayer
var _backdrop: Backdrop
var _margin: MarginContainer
var _content: VBoxContainer


func _ready() -> void:
	if Game.take_dev_race_request():
		Game.start_free_race.call_deferred()
		return
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = _ui_theme
	_sfx = AudioStreamPlayer.new()
	_sfx.bus = &"SFX"
	add_child(_sfx)
	_build()
	Game.progression.changed.connect(_refresh)
	get_window().size_changed.connect(_fit_scale)
	_fit_scale()
	_refresh()
	_focus_default()
	Game.play_music(&"garage")


func _unhandled_input(event: InputEvent) -> void:
	# Feedback when confirming something unavailable (locked, unaffordable).
	if event.is_action_pressed(&"ui_accept"):
		var focused := get_viewport().gui_get_focus_owner() as Button
		if focused != null and focused.disabled:
			_play(&"denied")


func _build() -> void:
	_backdrop = Backdrop.new()
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_backdrop)

	_margin = MarginContainer.new()
	_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_margin)
	var box := VBoxContainer.new()
	_margin.add_child(box)
	_content = box

	box.add_child(_label("RETROSHIFT", ACCENT, 2))
	box.add_child(_label("RACE. EARN. UPGRADE. REPEAT.", DIM))
	_credits = _label("", TEXT)
	box.add_child(_credits)

	box.add_child(_label("EVENTS", DIM))
	for event in Game.events:
		var button := _button()
		button.pressed.connect(_start_event.bind(event))
		box.add_child(button)
		_event_buttons.append(button)

	box.add_child(_label("UPGRADES", DIM))
	var grid := GridContainer.new()
	grid.columns = 4
	box.add_child(grid)
	for line in Upgrades.LINES:
		var row := {
			"level": _label("", ACCENT),
			"effect": _label("", TEXT),
			"buy": _button(),
		}
		grid.add_child(_label(Upgrades.DISPLAY_NAMES[line], TEXT))
		grid.add_child(row.level)
		grid.add_child(row.effect)
		row.buy.pressed.connect(_buy.bind(line))
		grid.add_child(row.buy)
		_rows[line] = row

	var settings := HBoxContainer.new()
	box.add_child(settings)
	_music_button = _button()
	_music_button.pressed.connect(_toggle.bind(Game.SETTING_MUSIC))
	settings.add_child(_music_button)
	_sfx_button = _button()
	_sfx_button.pressed.connect(_toggle.bind(Game.SETTING_SFX))
	settings.add_child(_sfx_button)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(spacer)
	box.add_child(_label("↑↓ SELECT   ENTER CONFIRM   TOP 3 UNLOCKS THE NEXT EVENT", DIM))


func _refresh() -> void:
	var profile := Game.progression.profile
	_credits.text = "CREDITS  %d" % profile.credits
	for i in Game.events.size():
		var event := Game.events[i]
		var button := _event_buttons[i]
		if profile.is_unlocked(event.id):
			button.disabled = false
			var best: Dictionary = profile.best_results.get(event.id, {})
			var best_text := "" if best.is_empty() else "   BEST %s %s" % [
				Hud.ordinal(best["place"]), Hud.format_time(best["time_s"])]
			button.text = "%s%s" % [event.display_name, best_text]
		else:
			button.disabled = true
			button.text = "%s  LOCKED" % event.display_name
	for line: StringName in _rows:
		var row: Dictionary = _rows[line]
		var level := profile.level(line)
		row.level.text = "■".repeat(level) + "□".repeat(Upgrades.MAX_LEVEL - level)
		row.effect.text = Upgrades.describe(line, level) if level > 0 else "STOCK"
		var price := Upgrades.next_price(line, level)
		if price < 0:
			row.buy.text = "MAX"
		else:
			row.buy.text = "BUY %d → %s" % [price, Upgrades.describe(line, level + 1)]
		row.buy.disabled = not Game.progression.can_buy(line)
	_music_button.text = "MUSIC %s" % ("ON" if Game.is_enabled(Game.SETTING_MUSIC) else "OFF")
	_sfx_button.text = "SOUND %s" % ("ON" if Game.is_enabled(Game.SETTING_SFX) else "OFF")
	_backdrop.queue_redraw()


func _start_event(event: EventDefinition) -> void:
	_play(&"go")
	Game.start_event(event)


func _buy(line: StringName) -> void:
	_play(&"buy" if Game.progression.buy(line) else &"denied")


func _toggle(setting: String) -> void:
	Game.toggle(setting)
	_refresh()
	_play(&"move")


func _play(sound: StringName) -> void:
	_sfx.stream = SOUNDS[sound]
	_sfx.play()


func _focus_default() -> void:
	for i in range(_event_buttons.size() - 1, -1, -1):
		if not _event_buttons[i].disabled:
			_event_buttons[i].grab_focus()
			return


## The UI scales in whole steps with window height, independent of the
## 240 px game view (§10).
func _fit_scale() -> void:
	_scale = maxi(1, get_window().size.y / 320)
	var font_size := Hud.FONT_PX * _scale
	_ui_theme.default_font_size = font_size
	for side in ["left", "right", "top", "bottom"]:
		_margin.add_theme_constant_override("margin_" + side, 12 * _scale)
	_content.add_theme_constant_override("separation", 3 * _scale)
	for label: Label in find_children("*", "Label", true, false):
		label.add_theme_font_size_override("font_size", font_size * label.get_meta("size", 1))
	_ui_theme.set_stylebox("normal", "Button", _box(PANEL, PANEL_EDGE))
	_ui_theme.set_stylebox("hover", "Button", _box(PANEL, PANEL_EDGE))
	_ui_theme.set_stylebox("pressed", "Button", _box(PANEL, ACCENT))
	_ui_theme.set_stylebox("focus", "Button", _box(Color.TRANSPARENT, ACCENT))
	_ui_theme.set_stylebox("disabled", "Button", _box(Color8(10, 12, 28, 120), Color8(255, 255, 255, 25)))
	_ui_theme.set_color("font_color", "Button", TEXT)
	_ui_theme.set_color("font_hover_color", "Button", TEXT)
	_ui_theme.set_color("font_focus_color", "Button", ACCENT)
	_ui_theme.set_color("font_pressed_color", "Button", ACCENT)
	_ui_theme.set_color("font_disabled_color", "Button", Color8(110, 116, 140))
	_ui_theme.set_constant("h_separation", "GridContainer", 6 * _scale)
	_ui_theme.set_constant("v_separation", "GridContainer", 2 * _scale)
	_ui_theme.set_constant("separation", "HBoxContainer", 6 * _scale)
	_backdrop.pixel_scale = _scale


func _box(fill: Color, edge: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = edge
	box.set_border_width_all(_scale)
	box.content_margin_left = 4 * _scale
	box.content_margin_right = 4 * _scale
	box.content_margin_top = 2 * _scale
	box.content_margin_bottom = 2 * _scale
	return box


func _button() -> Button:
	var button := Button.new()
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.focus_entered.connect(_play.bind(&"move"))
	return button


## `size` is a multiple of the base font scale (2 = title).
func _label(text: String, color: Color, size: int = 1) -> Label:
	var label := Label.new()
	label.text = text
	label.set_meta("size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color8(10, 12, 28))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	return label


## Sky, parallax landscape and a big view of the player's car.
class Backdrop:
	extends Control

	const SKY_TOP := Color8(32, 52, 128)
	const SKY_BOTTOM := Color8(240, 150, 110)
	const GROUND := Color8(40, 108, 52)

	var pixel_scale: int = 1:
		set(value):
			pixel_scale = value
			queue_redraw()

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var k := float(pixel_scale)
		var horizon := roundf(size.y * 0.72)
		var bands := 12
		for b in bands:
			var y0 := roundf(horizon * b / bands)
			var y1 := roundf(horizon * (b + 1) / bands)
			draw_rect(Rect2(0, y0, size.x, y1 - y0), SKY_TOP.lerp(SKY_BOTTOM, float(b) / (bands - 1)))
		draw_rect(Rect2(0, horizon, size.x, size.y - horizon), GROUND)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(k, k))
		var h := horizon / k
		for layer: Texture2D in [SpriteAtlas.BG_MOUNTAINS, SpriteAtlas.BG_HILLS]:
			var x := 0.0
			while x < size.x / k:
				draw_texture(layer, Vector2(x, h - layer.get_height() + 1))
				x += layer.get_width()
		# Player's car, big, bottom right.
		var car_scale := 3.0
		var car_size := SpriteAtlas.CAR_SIZE * car_scale
		var car_pos := Vector2(size.x / k - car_size.x - 24, size.y / k - car_size.y - 30)
		draw_texture_rect_region(SpriteAtlas.CARS, Rect2(car_pos.round(), car_size),
				SpriteAtlas.car_rect(0, 2))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
