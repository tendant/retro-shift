class_name RaceSimulation
extends Node
## Authoritative race state, advanced at a fixed 60 Hz (§3, §9).
##
## Rendering, HUD and audio read the previous/current snapshot buffers and
## never mutate this node. Car 0 is the player.

signal lap_completed(car: int, lap: int)
signal car_finished(car: int, time_s: float)
signal nitro_fired(car: int)

const TICK_DT := 1.0 / 60.0
const PLAYER := 0
## Grid slots sit behind the line, so lap 1 begins as each car crosses s = 0.
const GRID_FIRST_S := -6.0
const GRID_SPACING_S := 8.0

var track: Track
var params: VehicleParams
## Anything with `read(into: DrivingInput, dt: float)`; feeds the player car.
var input_source: Object
var cars: Array[VehicleState] = []
var inputs: Array[DrivingInput] = []
var finish_time_s := PackedFloat64Array()
var tick_count: int = 0
var race_time_s: float = 0.0

var _finished := PackedByteArray()
var _prev := RaceSnapshot.new()
var _curr := RaceSnapshot.new()


## Starts a new race. Returns the track's validation errors (empty on success).
func setup(p_track: Track, p_params: VehicleParams, p_input_source: Object = null,
		car_count: int = 1) -> PackedStringArray:
	var errors := p_track.build()
	if not errors.is_empty():
		for e in errors:
			push_error("Track '%s': %s" % [p_track.display_name, e])
		track = null
		return errors

	track = p_track
	params = p_params
	input_source = p_input_source
	tick_count = 0
	race_time_s = 0.0
	cars.clear()
	inputs.clear()
	for i in car_count:
		var state := VehicleState.new()
		state.s_m = GRID_FIRST_S - i * GRID_SPACING_S
		state.nitro_remaining = params.nitro_count
		cars.append(state)
		inputs.append(DrivingInput.new())
	_finished.resize(car_count)
	_finished.fill(0)
	finish_time_s.resize(car_count)
	finish_time_s.fill(0.0)
	_prev.resize(car_count)
	_curr.resize(car_count)
	_write_snapshot(_curr)
	_write_snapshot(_prev)
	return errors


func _physics_process(_delta: float) -> void:
	if track != null:
		tick()


func tick() -> void:
	if input_source != null:
		input_source.read(inputs[PLAYER], TICK_DT)
	race_time_s += TICK_DT
	for i in cars.size():
		var state := cars[i]
		var input := inputs[i]
		if _finished[i]:
			# Coast to a stop after the flag.
			input.clear()
			input.brake = 0.25
		var laps_before := completed_laps(i)
		if VehiclePhysics.step(state, input, params, track, TICK_DT):
			nitro_fired.emit(i)
		var laps_after := completed_laps(i)
		if laps_after > laps_before:
			lap_completed.emit(i, laps_after)
		if not _finished[i] and laps_after >= track.laps:
			_finished[i] = 1
			finish_time_s[i] = race_time_s
			car_finished.emit(i, race_time_s)
	tick_count += 1

	var older := _prev
	_prev = _curr
	_curr = older
	_write_snapshot(_curr)


## Laps fully completed. `s` only increases, so this is just floor(s / L).
func completed_laps(car: int) -> int:
	return maxi(0, floori(cars[car].s_m / track.lap_length_m))


## Lap shown on the HUD, 1-based and capped at the race length.
func current_lap(car: int) -> int:
	return mini(completed_laps(car) + 1, track.laps)


func is_finished(car: int) -> bool:
	return _finished[car] != 0


func previous_snapshot() -> RaceSnapshot:
	return _prev


func current_snapshot() -> RaceSnapshot:
	return _curr


func _write_snapshot(snap: RaceSnapshot) -> void:
	snap.tick = tick_count
	snap.race_time_s = race_time_s
	for i in cars.size():
		var state := cars[i]
		snap.s_m[i] = state.s_m
		snap.x_m[i] = state.x_m
		snap.speed_mps[i] = state.speed_mps
		snap.lateral_speed_mps[i] = state.lateral_speed_mps
		snap.steer[i] = inputs[i].steer
		snap.nitro_remaining[i] = state.nitro_remaining
		snap.nitro_active[i] = 1 if state.nitro_timer_s > 0.0 else 0
		snap.finished[i] = _finished[i]
