extends GutTest
## Laps and ranking edge cases (§7, §12).


func _sim(car_count: int) -> RaceSimulation:
	var sim := RaceSimulation.new()
	autofree(sim)
	sim.setup(TestTracks.make(&"straight"), VehicleParams.new(), null, car_count)
	return sim


func _place(sim: RaceSimulation, car: int, s: float, speed: float = 0.0, x: float = NAN) -> void:
	sim.cars[car].s_m = s
	sim.cars[car].speed_mps = speed
	if not is_nan(x):
		sim.cars[car].x_m = x


func test_player_starts_last_on_the_grid() -> void:
	var sim := _sim(6)
	assert_eq(sim.position_of(RaceSimulation.PLAYER), 6)
	for car in range(1, 6):
		assert_lt(sim.cars[car].s_m, 0.0)
		assert_gt(sim.cars[car].s_m, sim.cars[RaceSimulation.PLAYER].s_m)


func test_lapped_car_ranks_behind_despite_being_ahead_on_track() -> void:
	var sim := _sim(2)
	var L := sim.track.lap_length_m
	_place(sim, 0, L + 500.0, 0.0, -3.0)  # just behind car 1 on the road...
	_place(sim, 1, 2.0 * L + 10.0, 0.0, 3.0)  # ...but car 1 is a lap up
	sim.tick()
	assert_eq(sim.position_of(1), 1)
	assert_eq(sim.position_of(0), 2)


func test_overtake_just_before_and_after_the_line() -> void:
	var sim := _sim(2)
	var L := sim.track.lap_length_m
	watch_signals(sim)
	_place(sim, 0, L - 0.5, 60.0, -3.0)
	_place(sim, 1, L + 0.2, 10.0, 3.0)
	sim.tick()  # car 0 crosses the line and passes car 1 in the same tick
	assert_signal_emitted_with_parameters(sim, "lap_completed", [0, 1])
	assert_eq(sim.completed_laps(0), 1)
	assert_eq(sim.completed_laps(1), 1)
	assert_eq(sim.position_of(0), 1)


func test_finished_cars_keep_finishing_order() -> void:
	var sim := _sim(3)
	var L := sim.track.lap_length_m
	var race_end := sim.track.laps * L
	_place(sim, 1, race_end - 0.1, 30.0, -3.0)
	_place(sim, 2, race_end - 50.0, 0.0, 3.0)
	sim.tick()
	assert_true(sim.is_finished(1))
	# Car 2 finishes later but blows past the coasting car 1.
	_place(sim, 2, race_end + 100.0, 0.0)
	sim.tick()
	assert_true(sim.is_finished(2))
	assert_eq(sim.position_of(1), 1)
	assert_eq(sim.position_of(2), 2)


func test_results_freeze_and_project_unfinished_cars() -> void:
	var sim := _sim(3)
	var race_end := sim.track.laps * sim.track.lap_length_m
	watch_signals(sim)
	_place(sim, 0, race_end - 0.5, 60.0, 0.0)
	_place(sim, 1, race_end - 100.0, 50.0, -3.0)
	_place(sim, 2, race_end - 300.0, 50.0, 3.0)
	sim.tick()
	assert_signal_emit_count(sim, "results_ready", 1)
	assert_true(sim.has_results())
	assert_eq(sim.result_order, PackedInt32Array([0, 1, 2]))
	assert_eq(sim.result_projected[0], 0)
	assert_eq(sim.result_projected[1], 1)
	assert_almost_eq(sim.result_time_s[1], sim.race_time_s + 99.17 / 49.4, 0.1)
	var frozen := sim.result_time_s.duplicate()
	for i in 120:
		sim.tick()
	assert_eq(sim.result_time_s, frozen, "results stay frozen")
	assert_signal_emit_count(sim, "results_ready", 1)


func test_snapshot_carries_positions() -> void:
	var sim := _sim(3)
	sim.tick()
	var snap := sim.current_snapshot()
	for car in 3:
		assert_eq(snap.position[car], sim.position_of(car))
