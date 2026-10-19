class_name InputBindings
extends RefCounted
## Default keyboard and gamepad bindings. Actions already defined in the
## project's input map (e.g. remapped by the player) are left untouched.


static func install_defaults() -> void:
	# Driving.
	_action(&"throttle", [_key(KEY_UP), _key(KEY_W), _button(JOY_BUTTON_A),
			_axis(JOY_AXIS_TRIGGER_RIGHT, 1.0)])
	_action(&"brake", [_key(KEY_DOWN), _key(KEY_S), _button(JOY_BUTTON_B),
			_axis(JOY_AXIS_TRIGGER_LEFT, 1.0)])
	_action(&"steer_left", [_key(KEY_LEFT), _key(KEY_A), _button(JOY_BUTTON_DPAD_LEFT),
			_axis(JOY_AXIS_LEFT_X, -1.0)])
	_action(&"steer_right", [_key(KEY_RIGHT), _key(KEY_D), _button(JOY_BUTTON_DPAD_RIGHT),
			_axis(JOY_AXIS_LEFT_X, 1.0)])
	_action(&"nitro", [_key(KEY_SPACE), _button(JOY_BUTTON_X), _button(JOY_BUTTON_RIGHT_SHOULDER)])
	# UI / game state.
	_action(&"pause", [_key(KEY_ESCAPE), _key(KEY_P), _button(JOY_BUTTON_START)])
	_action(&"restart", [_key(KEY_R), _button(JOY_BUTTON_BACK)])
	_action(&"confirm", [_key(KEY_ENTER), _key(KEY_KP_ENTER), _button(JOY_BUTTON_Y)])
	_action(&"toggle_debug", [_key(KEY_F1), _key(KEY_TAB)])
	_action(&"next_track", [_key(KEY_F2)])


static func _action(action: StringName, events: Array) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action, 0.2)
	for event: InputEvent in events:
		InputMap.action_add_event(action, event)


static func _key(code: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = code
	return event


static func _button(button: JoyButton) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	return event


static func _axis(axis: JoyAxis, value: float) -> InputEventJoypadMotion:
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = value
	return event
