class_name OpponentAI
extends RefCounted
## Opponent driver (§7). Feeds one car's DrivingInput each tick.
##
## Target speed comes from v_max(k) over a braking-distance look-ahead, so
## physics and AI agree on every curve. Lane logic: Cruise → Follow → Pass
## → Recover. Also drives the player car for `--autodrive`.

enum State { CRUISE, FOLLOW, PASS, RECOVER }

const LANES := [-3.0, 0.0, 3.0]
const SPEED_MARGIN := 0.92
const SAMPLE_STEP_M := 5.0
## Fraction of full braking assumed when planning for a curve ahead.
const PLANNED_BRAKE_FRACTION := 0.8
const FOLLOW_DISTANCE_M := 30.0
const FOLLOW_GAP_M := 12.0
## A passed car must be this far behind before returning to the home lane.
const CLEAR_BEHIND_M := 6.0
const LANE_CLEARANCE_M := 0.4
const PASS_COOLDOWN_S := 3.0
const STEER_GAIN_PER_M := 0.5
const STEER_DAMPING_S := 0.03

var sim: RaceSimulation
var car: int
var skill: float
var preferred_lane_m: float
var target_lane_m: float
var state: State = State.CRUISE
var overtake_cooldown_s: float = 0.0

var _passing: int = -1


func _init(p_sim: RaceSimulation, p_car: int, p_skill: float = 1.0,
		p_preferred_lane_m: float = 0.0) -> void:
	sim = p_sim
	car = p_car
	skill = p_skill
	preferred_lane_m = p_preferred_lane_m
	target_lane_m = p_preferred_lane_m


func read(into: DrivingInput, dt: float) -> void:
	var me := sim.cars[car]
	overtake_cooldown_s = maxf(0.0, overtake_cooldown_s - dt)
	var ahead := _nearest_ahead(target_lane_m, FOLLOW_DISTANCE_M)
	_update_state(me, ahead)

	var target_speed := _curve_target_speed(me)
	if state == State.FOLLOW and ahead >= 0:
		var gap := sim.gap_ahead(car, ahead)
		target_speed = minf(target_speed, sim.cars[ahead].speed_mps + 0.5 * (gap - FOLLOW_GAP_M))

	var diff := target_speed - me.speed_mps
	into.throttle = clampf(diff * 0.5, 0.0, 1.0)
	into.brake = clampf((-diff - 1.0) * 0.25, 0.0, 1.0)
	into.steer = _steer_toward(me, target_lane_m)
	into.nitro_pressed = _wants_nitro(me)


func _update_state(me: VehicleState, ahead: int) -> void:
	match state:
		State.CRUISE:
			if ahead >= 0 and sim.cars[ahead].speed_mps < me.speed_mps + 1.0:
				state = State.FOLLOW
		State.FOLLOW:
			if ahead < 0:
				state = State.RECOVER
			elif overtake_cooldown_s <= 0.0:
				var lane := _free_lane()
				if not is_nan(lane):
					target_lane_m = lane
					_passing = ahead
					overtake_cooldown_s = PASS_COOLDOWN_S
					state = State.PASS
		State.PASS:
			if _passing < 0 or sim.gap_ahead(car, _passing) < -CLEAR_BEHIND_M:
				_passing = -1
				overtake_cooldown_s = PASS_COOLDOWN_S
				state = State.RECOVER
			elif ahead >= 0:
				# Blocked in the new lane, possibly by the car being passed.
				state = State.FOLLOW
		State.RECOVER:
			if target_lane_m != preferred_lane_m and _lane_clear(preferred_lane_m):
				target_lane_m = preferred_lane_m
			if ahead >= 0:
				state = State.FOLLOW
			elif absf(me.x_m - target_lane_m) < 0.3:
				state = State.CRUISE


## Highest speed from which the car can still slow to every curve's safe
## speed within the braking look-ahead, capped by its own top speed.
func _curve_target_speed(me: VehicleState) -> float:
	var params := sim.car_params[car]
	return _braking_limit(me.s_m, params.max_speed_mps * sim.top_speed_mult[car] * skill)


## Highest speed at `from_s` (up to `cap`) that still allows braking to the
## safe speed of every curve within braking distance of `cap`.
func _braking_limit(from_s: float, cap: float) -> float:
	var params := sim.car_params[car]
	var track := sim.track
	var brake := params.brake_decel_mps2 * PLANNED_BRAKE_FRACTION
	var window := cap * cap / (2.0 * brake) + 20.0
	var limit := cap
	var d := 0.0
	while d <= window:
		var safe := VehiclePhysics.v_max(track.curvature_at(from_s + d), params) * skill * SPEED_MARGIN
		if safe < limit:
			limit = minf(limit, sqrt(safe * safe + 2.0 * brake * d))
		d += SAMPLE_STEP_M
	return limit


## Feed-forward against the curve push, plus PD toward the lane.
func _steer_toward(me: VehicleState, lane_m: float) -> float:
	var params := sim.car_params[car]
	var k := sim.track.curvature_at(me.s_m)
	var feed_forward := k * me.speed_mps * me.speed_mps / (params.steer_max_accel_mps2 * params.grip)
	var error := lane_m - me.x_m
	return clampf(feed_forward + STEER_GAIN_PER_M * error - STEER_DAMPING_S * me.lateral_speed_mps,
			-1.0, 1.0)


## Boost only when the car could still hold its normal top speed at the end
## of the boost, so the extra speed isn't wasted braking for a curve.
func _wants_nitro(me: VehicleState) -> bool:
	if me.nitro_remaining <= 0 or me.nitro_timer_s > 0.0 or state == State.FOLLOW:
		return false
	var params := sim.car_params[car]
	var cap := params.max_speed_mps * sim.top_speed_mult[car]
	# Boosts pay off most accelerating out of a corner, not at top speed.
	if me.speed_mps < 0.6 * cap or me.speed_mps > 0.9 * cap:
		return false
	# Not while a curve is already holding the car back...
	if _braking_limit(me.s_m, cap) < cap:
		return false
	# ...and not if it would have to brake before the boost runs out.
	var boost_distance := me.speed_mps * params.nitro_duration_s
	return _braking_limit(me.s_m + boost_distance, cap) >= cap


## Nearest car within `range_m` ahead whose body overlaps `lane_m`, or -1.
func _nearest_ahead(lane_m: float, range_m: float) -> int:
	var best := -1
	var best_gap := range_m
	for other in sim.cars.size():
		if other == car or not _overlaps_lane(other, lane_m):
			continue
		var gap := sim.gap_ahead(car, other)
		if gap > 0.0 and gap <= best_gap:
			best = other
			best_gap = gap
	return best


func _lane_clear(lane_m: float) -> bool:
	for other in sim.cars.size():
		if other == car or not _overlaps_lane(other, lane_m):
			continue
		var gap := sim.gap_ahead(car, other)
		if gap > -CLEAR_BEHIND_M and gap < FOLLOW_DISTANCE_M:
			return false
	return true


## Closest clear lane to the current one, or NAN if all are blocked.
func _free_lane() -> float:
	var best := NAN
	var half_width := sim.track.half_width_at(sim.cars[car].s_m) - sim.car_params[car].car_half_width_m
	for lane: float in LANES:
		if lane == target_lane_m or absf(lane) > half_width or not _lane_clear(lane):
			continue
		if is_nan(best) or absf(lane - target_lane_m) < absf(best - target_lane_m):
			best = lane
	return best


func _overlaps_lane(other: int, lane_m: float) -> bool:
	var reach := 2.0 * sim.car_params[car].car_half_width_m + LANE_CLEARANCE_M
	return absf(sim.cars[other].x_m - lane_m) < reach
