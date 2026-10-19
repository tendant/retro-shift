class_name RaceSimulation
extends Node
## Authoritative race state, advanced at a fixed 60 Hz (§3, §9).
##
## Rendering, HUD and audio read the previous/current snapshot buffers and
## never mutate this node. Car 0 is the player; the rest are opponents.

signal lap_completed(car: int, lap: int)
signal car_finished(car: int, time_s: float)
signal nitro_fired(car: int)
signal collided(rear_car: int, front_car: int)
## The player finished; `result_order` and `result_time_s` are now frozen.
signal results_ready

const TICK_DT := 1.0 / 60.0
const PLAYER := 0
## Grid slots sit behind the line, so lap 1 begins as each car crosses s = 0.
## Opponents fill the front slots; the player starts last.
const GRID_FIRST_S := -6.0
const GRID_SPACING_S := 7.0
const GRID_LANE_OFFSET_M := 2.0

const CAR_LENGTH_M := 4.0
## Rear car drops toward this fraction of the front car's speed on impact...
const COLLISION_SPEED_RATIO := 0.92
## ...but never loses more than this per impact (§6: bounded).
const COLLISION_MAX_SPEED_LOSS_MPS := 20.0
const COLLISION_LATERAL_IMPULSE_MPS := 3.0

## Opponents this far behind the player start gaining top speed (§2)...
const RUBBER_BAND_START_M := 150.0
## ...reaching the full bonus here.
const RUBBER_BAND_FULL_M := 300.0
const RUBBER_BAND_MAX_BONUS := 0.05

var track: Track
## Opponents' tuning; the player's (upgraded) car may differ, see car_params.
var params: VehicleParams
## Per-car tuning used by physics and AI.
var car_params: Array[VehicleParams] = []
## Per car, anything with `read(into: DrivingInput, dt: float)`, or null.
var input_sources: Array[Object] = []
var cars: Array[VehicleState] = []
var inputs: Array[DrivingInput] = []
## 0 disables rubber-banding; difficulty settings scale it.
var rubber_band_strength: float = 1.0
## Per-car top-speed multiplier from rubber-banding (1.0 = none).
var top_speed_mult := PackedFloat64Array()
var finish_time_s := PackedFloat64Array()
## Cars in current race order (index 0 = leader).
var order := PackedInt32Array()
## Frozen when the player finishes: final order, and each car's finish time
## (projected from distance and speed for cars still racing).
var result_order := PackedInt32Array()
var result_time_s := PackedFloat64Array()
var result_projected := PackedByteArray()
var tick_count: int = 0
var race_time_s: float = 0.0

var _finished := PackedByteArray()
var _finish_rank := PackedInt32Array()
var _finished_count: int = 0
var _results_frozen: bool = false
var _prev := RaceSnapshot.new()
var _curr := RaceSnapshot.new()


## Starts a new race. `player_params` (upgrades) defaults to `p_params`.
## Returns the track's validation errors (empty on success).
func setup(p_track: Track, p_params: VehicleParams, player_input: Object = null,
		car_count: int = 1, player_params: VehicleParams = null) -> PackedStringArray:
	var errors := p_track.build()
	if not errors.is_empty():
		for e in errors:
			push_error("Track '%s': %s" % [p_track.display_name, e])
		track = null
		return errors

	track = p_track
	params = p_params
	tick_count = 0
	race_time_s = 0.0
	_finished_count = 0
	_results_frozen = false
	cars.clear()
	inputs.clear()
	input_sources.clear()
	car_params.clear()
	for i in car_count:
		var slot := car_count - 1 if i == PLAYER else i - 1
		var tuning := player_params if i == PLAYER and player_params != null else params
		var state := VehicleState.new()
		state.s_m = GRID_FIRST_S - slot * GRID_SPACING_S
		state.x_m = GRID_LANE_OFFSET_M * (1.0 if slot % 2 == 0 else -1.0)
		state.nitro_remaining = tuning.nitro_count
		cars.append(state)
		car_params.append(tuning)
		inputs.append(DrivingInput.new())
		input_sources.append(null)
	input_sources[PLAYER] = player_input
	_finished.resize(car_count)
	_finished.fill(0)
	result_projected.resize(car_count)
	result_projected.fill(0)
	_finish_rank.resize(car_count)
	_finish_rank.fill(-1)
	finish_time_s.resize(car_count)
	finish_time_s.fill(0.0)
	result_time_s.resize(car_count)
	result_time_s.fill(0.0)
	top_speed_mult.resize(car_count)
	top_speed_mult.fill(1.0)
	order.resize(car_count)
	result_order.resize(0)
	_update_order()
	_prev.resize(car_count)
	_curr.resize(car_count)
	_write_snapshot(_curr)
	_write_snapshot(_prev)
	return errors


func set_input_source(car: int, source: Object) -> void:
	input_sources[car] = source


func _physics_process(_delta: float) -> void:
	if track != null:
		tick()


func tick() -> void:
	race_time_s += TICK_DT
	for i in cars.size():
		if input_sources[i] != null:
			input_sources[i].read(inputs[i], TICK_DT)
		if _finished[i]:
			# Coast to a stop after the flag, still steering.
			inputs[i].throttle = 0.0
			inputs[i].brake = 0.25
			inputs[i].nitro_pressed = false
	_update_rubber_band()

	for i in cars.size():
		var laps_before := completed_laps(i)
		if VehiclePhysics.step(cars[i], inputs[i], car_params[i], track, TICK_DT, top_speed_mult[i]):
			nitro_fired.emit(i)
		var laps_after := completed_laps(i)
		if laps_after > laps_before:
			lap_completed.emit(i, laps_after)
		if not _finished[i] and laps_after >= track.laps:
			_finished[i] = 1
			_finish_rank[i] = _finished_count
			_finished_count += 1
			finish_time_s[i] = race_time_s
			car_finished.emit(i, race_time_s)
	_resolve_collisions()
	_update_order()
	if _finished[PLAYER] and not _results_frozen:
		_freeze_results()
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


func has_results() -> bool:
	return _results_frozen


## 1-based race position.
func position_of(car: int) -> int:
	return order.find(car) + 1


## Shortest signed distance from car `from` forward to car `to` along the
## loop, in [-L/2, L/2). Use for proximity, not for ranking.
func gap_ahead(from: int, to: int) -> float:
	var half := 0.5 * track.lap_length_m
	return fposmod(cars[to].s_m - cars[from].s_m + half, track.lap_length_m) - half


func previous_snapshot() -> RaceSnapshot:
	return _prev


func current_snapshot() -> RaceSnapshot:
	return _curr


## Opponents far behind the player gain up to +5% top speed; cars ahead are
## never slowed (§2).
func _update_rubber_band() -> void:
	for i in cars.size():
		if i == PLAYER:
			continue
		var behind := cars[PLAYER].s_m - cars[i].s_m
		var t := clampf((behind - RUBBER_BAND_START_M) / (RUBBER_BAND_FULL_M - RUBBER_BAND_START_M), 0.0, 1.0)
		top_speed_mult[i] = 1.0 + RUBBER_BAND_MAX_BONUS * rubber_band_strength * t


## Track-relative collisions (§6). Only speeds change, so `s` never moves
## backward and lap counts can't be corrupted.
func _resolve_collisions() -> void:
	var reach := 2.0 * params.car_half_width_m
	for a in cars.size():
		for b in range(a + 1, cars.size()):
			var ds := gap_ahead(a, b)
			if absf(ds) >= CAR_LENGTH_M:
				continue
			var car_a := cars[a]
			var car_b := cars[b]
			var dx := car_b.x_m - car_a.x_m
			if absf(dx) >= reach:
				continue
			var rear := b if ds < 0.0 else a
			var front := a if rear == b else b
			var rear_car := cars[rear]
			var front_speed := cars[front].speed_mps
			if rear_car.speed_mps > front_speed:
				rear_car.speed_mps = clampf(front_speed * COLLISION_SPEED_RATIO,
						rear_car.speed_mps - COLLISION_MAX_SPEED_LOSS_MPS, rear_car.speed_mps)
				collided.emit(rear, front)
			# Push apart unless already separating fast enough.
			var dir := signf(dx) if dx != 0.0 else 1.0
			var separating := (car_b.lateral_speed_mps - car_a.lateral_speed_mps) * dir
			if separating < COLLISION_LATERAL_IMPULSE_MPS:
				var kick := 0.5 * (COLLISION_LATERAL_IMPULSE_MPS - separating) * dir
				var cap_a := car_params[a].lateral_speed_cap_mps
				var cap_b := car_params[b].lateral_speed_cap_mps
				car_a.lateral_speed_mps = clampf(car_a.lateral_speed_mps - kick, -cap_a, cap_a)
				car_b.lateral_speed_mps = clampf(car_b.lateral_speed_mps + kick, -cap_b, cap_b)


## Finished cars first in finishing order, then the rest by distance (§7).
func _update_order() -> void:
	for i in cars.size():
		order[i] = i
	# Insertion sort: tiny, stable, allocation-free.
	for i in range(1, order.size()):
		var car := order[i]
		var j := i - 1
		while j >= 0 and _is_ahead(car, order[j]):
			order[j + 1] = order[j]
			j -= 1
		order[j + 1] = car


func _is_ahead(a: int, b: int) -> bool:
	var fa := _finished[a] != 0
	var fb := _finished[b] != 0
	if fa and fb:
		return _finish_rank[a] < _finish_rank[b]
	if fa != fb:
		return fa
	return cars[a].s_m > cars[b].s_m


## Projects finish times for cars still racing so results show immediately.
## Real finish times are all <= now <= projected ones, so sorting by time
## keeps finished cars in their finishing order.
func _freeze_results() -> void:
	var race_length := track.laps * track.lap_length_m
	for i in cars.size():
		if _finished[i]:
			result_time_s[i] = finish_time_s[i]
			result_projected[i] = 0
		else:
			var remaining := maxf(0.0, race_length - cars[i].s_m)
			result_time_s[i] = race_time_s + remaining / maxf(cars[i].speed_mps, 1.0)
			result_projected[i] = 1
	result_order = order.duplicate()
	for i in range(1, result_order.size()):
		var car := result_order[i]
		var j := i - 1
		while j >= 0 and result_time_s[car] < result_time_s[result_order[j]]:
			result_order[j + 1] = result_order[j]
			j -= 1
		result_order[j + 1] = car
	_results_frozen = true
	results_ready.emit()


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
	for rank in order.size():
		snap.position[order[rank]] = rank + 1
