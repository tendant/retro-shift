class_name RaceMenu
extends CanvasLayer
## Pause and results buttons over the race (tap, click, keyboard or
## gamepad). Runs while the tree is paused.

signal resume_pressed
signal restart_pressed
signal garage_pressed

var _theme := Theme.new()
var _row: HBoxContainer
var _margin: MarginContainer


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = _theme
	add_child(root)
	_margin = MarginContainer.new()
	_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_margin)
	_row = HBoxContainer.new()
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_row.size_flags_vertical = Control.SIZE_SHRINK_END
	_margin.add_child(_row)
	get_window().size_changed.connect(_fit)
	_fit()
	hide_menu()


func show_pause(free_race: bool) -> void:
	_show([
		["RESUME", resume_pressed],
		["RESTART", restart_pressed],
		["NEW RACE" if free_race else "QUIT TO GARAGE", restart_pressed if free_race else garage_pressed],
	])


func show_results(free_race: bool) -> void:
	if free_race:
		_show([["RACE AGAIN", restart_pressed], ["GARAGE", garage_pressed]])
	else:
		_show([["GARAGE", garage_pressed], ["RETRY", restart_pressed]])


func hide_menu() -> void:
	visible = false
	for child in _row.get_children():
		child.queue_free()


func buttons() -> Array[Button]:
	var found: Array[Button] = []
	for child in _row.get_children():
		if child is Button and not child.is_queued_for_deletion():
			found.append(child)
	return found


func _show(entries: Array) -> void:
	hide_menu()
	for entry: Array in entries:
		var button := Button.new()
		button.text = entry[0]
		UiTheme.size_for_touch(button, get_window().size.y)
		var sig: Signal = entry[1]
		button.pressed.connect(sig.emit)
		_row.add_child(button)
	visible = true
	buttons()[0].grab_focus()


func _fit() -> void:
	var scale := UiTheme.scale_for(get_window().size.y)
	UiTheme.apply(_theme, scale)
	var inset := SafeArea.insets(get_window())
	_margin.add_theme_constant_override("margin_left", int(inset.x) + 8 * scale)
	_margin.add_theme_constant_override("margin_top", int(inset.y) + 8 * scale)
	_margin.add_theme_constant_override("margin_right", int(inset.z) + 8 * scale)
	_margin.add_theme_constant_override("margin_bottom", int(inset.w) + 10 * scale)
