class_name PlayerInputAdapter
extends RefCounted
## Maps keyboard/gamepad actions into DrivingInput. Read once per physics tick.

## Steering slews toward the target so digital keys don't snap to full lock.
const STEER_RATE_PER_S := 12.0

var _steer: float = 0.0


func read(into: DrivingInput, dt: float) -> void:
	into.throttle = Input.get_action_strength(&"throttle")
	into.brake = Input.get_action_strength(&"brake")
	var target := Input.get_axis(&"steer_left", &"steer_right")
	_steer = move_toward(_steer, target, STEER_RATE_PER_S * dt)
	into.steer = _steer
	into.nitro_pressed = Input.is_action_just_pressed(&"nitro")
