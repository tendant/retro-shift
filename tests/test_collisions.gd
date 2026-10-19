extends GutTest
## Track-relative collisions (§6, §12).


func _sim(car_count: int = 2) -> RaceSimulation:
	var sim := RaceSimulation.new()
	autofree(sim)
	sim.setup(TestTracks.make(&"straight"), VehicleParams.new(), null, car_count)
	return sim


func _place(sim: RaceSimulation, car: int, s: float, x: float, speed: float) -> void:
	sim.cars[car].s_m = s
	sim.cars[car].x_m = x
	sim.cars[car].speed_mps = speed
	sim.cars[car].lateral_speed_mps = 0.0


func test_rear_impact_costs_bounded_speed_and_pushes_cars_apart() -> void:
	var sim := _sim()
	watch_signals(sim)
	_place(sim, 0, 100.0, 0.0, 60.0)
	_place(sim, 1, 102.0, 0.5, 20.0)
	sim.tick()
	assert_signal_emitted_with_parameters(sim, "collided", [0, 1])
	var rear := sim.cars[0]
	assert_lt(rear.speed_mps, 60.0)
	assert_gte(rear.speed_mps, 60.0 - RaceSimulation.COLLISION_MAX_SPEED_LOSS_MPS - 1.0)
	assert_lt(rear.lateral_speed_mps, 0.0, "rear car (left) pushed left")
	assert_gt(sim.cars[1].lateral_speed_mps, 0.0, "front car (right) pushed right")


func test_side_by_side_cars_in_different_lanes_do_not_touch() -> void:
	var sim := _sim()
	watch_signals(sim)
	_place(sim, 0, 100.0, -1.5, 40.0)
	_place(sim, 1, 101.0, 1.5, 40.0)
	sim.tick()
	assert_signal_not_emitted(sim, "collided")
	assert_eq(sim.cars[0].lateral_speed_mps, 0.0)


func test_collisions_never_reduce_s_or_corrupt_laps() -> void:
	var sim := _sim(3)
	var L := sim.track.lap_length_m
	watch_signals(sim)
	# A pile-up straddling the start line, cars on different laps.
	_place(sim, 0, L - 1.5, 0.0, 70.0)
	_place(sim, 1, L + 1.0, 0.3, 10.0)
	_place(sim, 2, L - 4.0, -0.4, 75.0)
	for car in 3:
		sim.inputs[car].throttle = 1.0
	var last_s := PackedFloat64Array([0.0, 0.0, 0.0])
	var last_laps := PackedInt32Array([0, 0, 0])
	for car in 3:
		last_s[car] = sim.cars[car].s_m
		last_laps[car] = sim.completed_laps(car)
	for i in 180:
		sim.tick()
		for car in 3:
			assert_gte(sim.cars[car].s_m, last_s[car], "s never decreases")
			var laps := sim.completed_laps(car)
			assert_true(laps == last_laps[car] or laps == last_laps[car] + 1, "laps advance by one")
			last_s[car] = sim.cars[car].s_m
			last_laps[car] = laps
	assert_signal_emitted(sim, "collided")
	assert_signal_emit_count(sim, "lap_completed", 2, "cars 0 and 2 cross once each")
	assert_eq(sim.completed_laps(1), 1)
