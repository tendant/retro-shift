extends Control
## Garage hub (§2 core loop): pick an unlocked event, buy upgrades.
## Keyboard/gamepad navigation uses Godot's built-in ui_* actions.

const BACKGROUND := Color8(20, 24, 44)
const ACCENT := Color8(255, 200, 64)
const DIM := Color8(150, 160, 190)
const GOOD := Color8(120, 220, 120)

var _ui_theme := Theme.new()
var _credits: Label
var _event_buttons: Array[Button] = []
## {line: {"level": Label, "effect": Label, "buy": Button}}
var _rows: Dictionary = {}


func _ready() -> void:
	if Game.take_dev_race_request():
		Game.start_free_race.call_deferred()
		return
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = _ui_theme
	_build()
	Game.progression.changed.connect(_refresh)
	get_window().size_changed.connect(_fit_font)
	_fit_font()
	_refresh()
	_focus_default()


func _build() -> void:
	var background := ColorRect.new()
	background.color = BACKGROUND
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 40)
	add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	margin.add_child(box)

	box.add_child(_label("RETROSHIFT  ·  GARAGE", ACCENT))
	_credits = _label("", Color.WHITE)
	box.add_child(_credits)

	box.add_child(_label("EVENTS", DIM))
	for event in Game.events:
		var button := Button.new()
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.pressed.connect(Game.start_event.bind(event))
		box.add_child(button)
		_event_buttons.append(button)

	box.add_child(_label("UPGRADES", DIM))
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 24)
	box.add_child(grid)
	for line in Upgrades.LINES:
		var row := {
			"level": _label("", ACCENT),
			"effect": _label("", Color.WHITE),
			"buy": Button.new(),
		}
		grid.add_child(_label(Upgrades.DISPLAY_NAMES[line], Color.WHITE))
		grid.add_child(row.level)
		grid.add_child(row.effect)
		row.buy.pressed.connect(_buy.bind(line))
		grid.add_child(row.buy)
		_rows[line] = row

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(spacer)
	box.add_child(_label("Arrows/D-pad: select    Enter/A: confirm    Top 3 unlocks the next event", DIM))


func _refresh() -> void:
	var profile := Game.progression.profile
	_credits.text = "CREDITS  %d" % profile.credits
	for i in Game.events.size():
		var event := Game.events[i]
		var button := _event_buttons[i]
		if profile.is_unlocked(event.id):
			button.disabled = false
			var best: Dictionary = profile.best_results.get(event.id, {})
			var best_text := "" if best.is_empty() else "   best: %s, %s" % [
				Hud.ordinal(best["place"]), Hud.format_time(best["time_s"])]
			button.text = "%s  (%d laps)%s" % [event.display_name, event.laps, best_text]
		else:
			button.disabled = true
			button.text = "%s  — locked" % event.display_name
	for line: StringName in _rows:
		var row: Dictionary = _rows[line]
		var level := profile.level(line)
		row.level.text = "■".repeat(level) + "□".repeat(Upgrades.MAX_LEVEL - level)
		row.effect.text = Upgrades.describe(line, level) if level > 0 else "stock"
		var price := Upgrades.next_price(line, level)
		if price < 0:
			row.buy.text = "MAX"
		else:
			row.buy.text = "BUY %d  →  %s" % [price, Upgrades.describe(line, level + 1)]
		row.buy.disabled = not Game.progression.can_buy(line)


func _buy(line: StringName) -> void:
	Game.progression.buy(line)


func _focus_default() -> void:
	for i in range(_event_buttons.size() - 1, -1, -1):
		if not _event_buttons[i].disabled:
			_event_buttons[i].grab_focus()
			return


## UI scales with window height, independent of the 240 px game view (§10).
func _fit_font() -> void:
	_ui_theme.default_font_size = clampi(get_window().size.y / 32, 14, 48)


func _label(text: String, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", color)
	return label
