class_name TouchControls
extends CanvasLayer
## On-screen driving buttons (§10). Each presses the same input action as
## the keyboard, so PlayerInputAdapter and the simulation are unchanged.
## Steering and pedals use passby press: slide a thumb between them.

## Button height as a fraction of the window height (before integer snap).
const BUTTON_FRAC := 0.17
const BUTTONS := {
	&"left": &"steer_left",
	&"right": &"steer_right",
	&"brake": &"brake",
	&"gas": &"throttle",
	&"nitro": &"nitro",
	&"pause": &"pause",
}

var _buttons := {}


func _ready() -> void:
	layer = 5
	for name: StringName in BUTTONS:
		var button := TouchScreenButton.new()
		button.texture_normal = _icon("touch_%s" % name)
		button.texture_pressed = _icon("touch_%s_pressed" % name)
		var shape := RectangleShape2D.new()
		shape.size = button.texture_normal.get_size()
		button.shape = shape
		button.shape_centered = true
		button.action = BUTTONS[name]
		button.passby_press = name != &"pause" and name != &"nitro"
		add_child(button)
		_buttons[name] = button
	get_window().size_changed.connect(layout)
	layout()


func layout() -> void:
	layout_for(Vector2(get_window().size), SafeArea.insets(get_window()))


## Positions buttons for a screen `size` (px) inside the safe area `inset`
## (left, top, right, bottom).
func layout_for(size: Vector2, inset: Vector4) -> void:
	var k := maxi(2, floori(size.y * BUTTON_FRAC / 32.0))
	var px := 32.0 * k
	var gap := 4.0 * k
	var margin := 6.0 * k
	var bottom := size.y - inset.w - margin - px
	_place(&"left", Vector2(inset.x + margin, bottom), k)
	_place(&"right", Vector2(inset.x + margin + px + gap, bottom), k)
	var gas_x := size.x - inset.z - margin - px
	_place(&"gas", Vector2(gas_x, bottom), k)
	_place(&"brake", Vector2(gas_x - px - gap, bottom), k)
	_place(&"nitro", Vector2(gas_x, bottom - px - gap), k)
	var pause_k := maxi(1, k - 1)
	_place(&"pause", Vector2(roundf((size.x - 32.0 * pause_k) * 0.5), inset.y + margin), pause_k)


func button_rect(name: StringName) -> Rect2:
	var button: TouchScreenButton = _buttons[name]
	return Rect2(button.position, button.texture_normal.get_size() * button.scale)


func _place(name: StringName, pos: Vector2, k: int) -> void:
	var button: TouchScreenButton = _buttons[name]
	button.position = pos.round()
	button.scale = Vector2(k, k)


static func _icon(sprite: String) -> AtlasTexture:
	var texture := AtlasTexture.new()
	texture.atlas = SpriteAtlas.HUD
	texture.region = SpriteAtlas.HUD_RECTS[StringName(sprite)]
	return texture
