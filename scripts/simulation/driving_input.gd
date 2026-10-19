class_name DrivingInput
extends RefCounted

var throttle: float = 0.0  # [0, 1]
var brake: float = 0.0     # [0, 1]
var steer: float = 0.0     # [-1, 1]
var nitro_pressed: bool = false  # true only on the tick the button goes down


func clear() -> void:
	throttle = 0.0
	brake = 0.0
	steer = 0.0
	nitro_pressed = false
