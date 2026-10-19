class_name RaceSnapshot
extends RefCounted
## Read-only view of race state for rendering, HUD and audio (§9).
## Preallocated once per race; written in place every tick.

var tick: int = 0
var race_time_s: float = 0.0
var countdown_s: float = 0.0
var car_count: int = 0
var s_m := PackedFloat64Array()
var x_m := PackedFloat64Array()
var speed_mps := PackedFloat64Array()
var lateral_speed_mps := PackedFloat64Array()
var steer := PackedFloat64Array()
var nitro_remaining := PackedInt32Array()
var nitro_active := PackedByteArray()
var finished := PackedByteArray()
var position := PackedInt32Array()  # 1-based race position


func resize(count: int) -> void:
	car_count = count
	s_m.resize(count)
	x_m.resize(count)
	speed_mps.resize(count)
	lateral_speed_mps.resize(count)
	steer.resize(count)
	nitro_remaining.resize(count)
	nitro_active.resize(count)
	finished.resize(count)
	position.resize(count)
