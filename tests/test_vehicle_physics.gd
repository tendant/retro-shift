extends GutTest

const DT := 1.0 / 60.0


func _curve_track(curvature: float) -> Track:
	var seg := TrackSegment.new()
	seg.length_m = 2000.0
	seg.curvature_rad_per_m = curvature
	var track := Track.new()
	track.segments.append(seg)
	track.build()
	return track


## Holds speed constant, steers fully into the curve, returns lateral drift
## toward the inside (positive) after `seconds`.
func _drift_into_curve(speed_fraction_of_vmax: float, seconds: float) -> float:
	var k := 1.0 / 80.0
	var track := _curve_track(k)
	var params := VehicleParams.new()
	var state := VehicleState.new()
	var input := DrivingInput.new()
	input.steer = signf(k)
	var speed := VehiclePhysics.v_max(k, params) * speed_fraction_of_vmax
	for i in roundi(seconds / DT):
		state.speed_mps = speed
		VehiclePhysics.step(state, input, params, track, DT)
	# Positive curvature bends right; the inside of the curve is +x.
	return state.x_m * signf(k)


func test_v_max_formula() -> void:
	var params := VehicleParams.new()
	assert_almost_eq(VehiclePhysics.v_max(1.0 / 80.0, params),
			sqrt(params.steer_max_accel_mps2 * params.grip * 80.0), 1e-9)
	assert_eq(VehiclePhysics.v_max(0.0, params), INF)
	assert_eq(VehiclePhysics.v_max(-0.01, params), VehiclePhysics.v_max(0.01, params))


func test_below_v_max_holds_curve() -> void:
	assert_gte(_drift_into_curve(0.95, 3.0), 0.0)


func test_above_v_max_drifts_outward() -> void:
	assert_lt(_drift_into_curve(1.2, 3.0), -2.0)


func test_better_grip_raises_v_max() -> void:
	var params := VehicleParams.new()
	var base := VehiclePhysics.v_max(0.01, params)
	params.grip = 1.25
	assert_gt(VehiclePhysics.v_max(0.01, params), base)


func test_random_inputs_stay_finite_and_bounded() -> void:
	var track := TestTracks.make(&"basic")
	track.build()
	var params := VehicleParams.new()
	var state := VehicleState.new()
	var input := DrivingInput.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234
	var max_cap := params.max_speed_mps * params.nitro_speed_mult
	for i in 20000:
		if i % 30 == 0:
			input.throttle = rng.randf()
			input.brake = rng.randf() if rng.randf() < 0.3 else 0.0
			input.steer = rng.randf_range(-1.0, 1.0)
		input.nitro_pressed = rng.randf() < 0.002
		var s_before := state.s_m
		VehiclePhysics.step(state, input, params, track, DT)
		assert_true(is_finite(state.s_m) and is_finite(state.x_m) and is_finite(state.speed_mps)
				and is_finite(state.lateral_speed_mps), "finite at tick %d" % i)
		if not (state.speed_mps >= 0.0 and state.speed_mps <= max_cap + 1e-6
				and absf(state.lateral_speed_mps) <= params.lateral_speed_cap_mps + 1e-6
				and state.s_m >= s_before):
			fail_test("out of bounds at tick %d: v=%f lat=%f" % [i, state.speed_mps, state.lateral_speed_mps])
			return
	pass_test("bounded for 20000 ticks")


func test_off_road_slows_and_is_recoverable() -> void:
	var track := _curve_track(0.0)
	var params := VehicleParams.new()
	var state := VehicleState.new()
	state.x_m = track.half_width_at(0.0) + 4.0
	state.speed_mps = 60.0
	var input := DrivingInput.new()
	input.throttle = 1.0
	input.steer = -1.0
	VehiclePhysics.step(state, input, params, track, DT)
	assert_lt(state.speed_mps, 60.0, "off-road drag beats full throttle")
	for i in 600:
		if not VehiclePhysics.is_off_road(state, track):
			break
		VehiclePhysics.step(state, input, params, track, DT)
	assert_false(VehiclePhysics.is_off_road(state, track), "back on the road within 10 s")


func test_nitro_is_limited_and_raises_speed_cap() -> void:
	var track := _curve_track(0.0)
	var params := VehicleParams.new()
	var state := VehicleState.new()
	state.nitro_remaining = 1
	state.speed_mps = params.max_speed_mps
	var input := DrivingInput.new()
	input.throttle = 1.0
	input.nitro_pressed = true
	assert_true(VehiclePhysics.step(state, input, params, track, DT), "first press fires")
	assert_eq(state.nitro_remaining, 0)
	input.nitro_pressed = false
	for i in 60:
		VehiclePhysics.step(state, input, params, track, DT)
	assert_gt(state.speed_mps, params.max_speed_mps, "boost exceeds the normal cap")
	input.nitro_pressed = true
	for i in 300:
		assert_false(VehiclePhysics.step(state, input, params, track, DT), "no boosts left")
	assert_almost_eq(state.speed_mps, params.max_speed_mps, 1e-6, "decays back to the cap")


func test_steering_is_responsive() -> void:
	# Arcade feel: a 3 m lane change at 40 m/s well under half a second of
	# full steer, and the car stops drifting right fast once steered left.
	var track := _curve_track(0.0)
	var params := VehicleParams.new()
	var state := VehicleState.new()
	var input := DrivingInput.new()
	input.steer = 1.0
	var t := 0.0
	while state.x_m < 3.0 and t < 2.0:
		state.speed_mps = 40.0
		VehiclePhysics.step(state, input, params, track, DT)
		t += DT
	assert_lt(t, 0.5, "3 m lane change took %.2f s" % t)
	input.steer = -1.0
	var reverse := 0.0
	while state.lateral_speed_mps > 0.0 and reverse < 1.0:
		state.speed_mps = 40.0
		VehiclePhysics.step(state, input, params, track, DT)
		reverse += DT
	assert_lt(reverse, 0.15, "reversing took %.2f s" % reverse)
