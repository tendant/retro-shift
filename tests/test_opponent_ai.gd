extends GutTest
## Opponent AI (§7, §12).


## Holds a car near a fixed speed in a fixed lane.
class SlowCar:
	extends RefCounted
	var sim: RaceSimulation
	var car: int
	var speed: float

	func _init(p_sim: RaceSimulation, p_car: int, p_speed: float) -> void:
		sim = p_sim
		car = p_car
		speed = p_speed

	func read(into: DrivingInput, _dt: float) -> void:
		into.throttle = 1.0 if sim.cars[car].speed_mps < speed else 0.0
		into.steer = clampf(-0.3 * sim.cars[car].x_m, -1.0, 1.0)


func _ai_race(track_name: StringName, car_count: int) -> RaceSimulation:
	var sim := RaceSimulation.new()
	autofree(sim)
	sim.setup(TrackLibrary.make(track_name), VehicleParams.new(), null, car_count)
	for car in car_count:
		var lane: float = OpponentAI.LANES[car % OpponentAI.LANES.size()]
		sim.set_input_source(car, OpponentAI.new(sim, car, lerpf(0.86, 1.0, car / 5.0), lane))
	return sim


func test_ai_stays_on_road_on_all_test_tracks() -> void:
	for track_name in TrackLibrary.names():
		var sim := _ai_race(track_name, 6)
		var worst := -INF
		for i in 60 * 60:
			sim.tick()
			for car in sim.cars.size():
				var state := sim.cars[car]
				worst = maxf(worst, absf(state.x_m) - sim.track.half_width_at(state.s_m))
		assert_lt(worst, 0.0, "%s: worst excursion past the road edge %.2f m" % [track_name, worst])


func test_ai_respects_curve_speed() -> void:
	var sim := _ai_race(&"s_curve", 1)
	var worst := -INF
	for i in 60 * 60:
		sim.tick()
		var state := sim.cars[0]
		var k := sim.track.curvature_at(state.s_m)
		if k != 0.0:
			worst = maxf(worst, state.speed_mps - VehiclePhysics.v_max(k, sim.params))
	assert_lt(worst, 0.0, "AI exceeded v_max by %.2f m/s" % worst)


func test_ai_passes_slower_car_without_oscillating() -> void:
	var sim := RaceSimulation.new()
	autofree(sim)
	sim.setup(TestTracks.make(&"straight"), VehicleParams.new(), null, 2)
	var ai := OpponentAI.new(sim, 0, 1.0, 0.0)
	sim.set_input_source(0, ai)
	sim.set_input_source(1, SlowCar.new(sim, 1, 25.0))
	sim.cars[0].s_m = 0.0
	sim.cars[0].x_m = 0.0
	sim.cars[1].s_m = 60.0
	sim.cars[1].x_m = 0.0
	sim.cars[1].speed_mps = 25.0
	var lane_changes := 0
	var last_lane := ai.target_lane_m
	# 12 s: long enough to pass and settle, short enough not to lap it.
	for i in 60 * 12:
		sim.tick()
		if ai.target_lane_m != last_lane:
			lane_changes += 1
			last_lane = ai.target_lane_m
	assert_gt(sim.cars[0].s_m, sim.cars[1].s_m + 50.0, "passed the slow car")
	assert_lte(lane_changes, 2, "out and back, no weaving")
	assert_eq(ai.target_lane_m, 0.0, "returned to its lane")


func test_rubber_band_is_capped_and_one_sided() -> void:
	var sim := RaceSimulation.new()
	autofree(sim)
	sim.setup(TestTracks.make(&"straight"), VehicleParams.new(), null, 3)
	sim.cars[0].s_m = 1000.0
	sim.cars[1].s_m = 0.0  # far behind
	sim.cars[2].s_m = 1500.0  # ahead
	sim.tick()
	assert_almost_eq(sim.top_speed_mult[1], 1.0 + RaceSimulation.RUBBER_BAND_MAX_BONUS, 1e-9)
	assert_eq(sim.top_speed_mult[2], 1.0, "never slows cars ahead")
	sim.rubber_band_strength = 0.0
	sim.tick()
	assert_eq(sim.top_speed_mult[1], 1.0, "can be switched off")


func test_full_field_race_finishes() -> void:
	var sim := _ai_race(&"basic", 6)
	var limit := 60 * 60 * 5
	var all_done := false
	while sim.tick_count < limit and not all_done:
		sim.tick()
		all_done = true
		for car in sim.cars.size():
			all_done = all_done and sim.is_finished(car)
	assert_true(all_done, "all six cars finish three laps")
	assert_true(sim.has_results())
	var sorted := sim.result_order.duplicate()
	sorted.sort()
	assert_eq(sorted, PackedInt32Array([0, 1, 2, 3, 4, 5]))
