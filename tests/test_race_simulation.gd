extends GutTest


class FullThrottle:
	extends RefCounted

	func read(into: DrivingInput, _dt: float) -> void:
		into.throttle = 1.0


func _sim(track_name: StringName, input_source: Object = null, car_count: int = 1) -> RaceSimulation:
	var sim := RaceSimulation.new()
	autofree(sim)
	var errors := sim.setup(TestTracks.make(track_name), VehicleParams.new(), input_source, car_count)
	assert_eq(errors, PackedStringArray())
	return sim


func test_grid_starts_behind_the_line() -> void:
	var sim := _sim(&"straight", null, 3)
	for i in 3:
		assert_lt(sim.cars[i].s_m, 0.0)
		assert_eq(sim.completed_laps(i), 0)
		assert_eq(sim.current_lap(i), 1)


func test_three_laps_then_finish() -> void:
	var sim := _sim(&"straight", FullThrottle.new())
	watch_signals(sim)
	var limit := 60 * 120
	while not sim.is_finished(RaceSimulation.PLAYER) and sim.tick_count < limit:
		sim.tick()
	assert_true(sim.is_finished(RaceSimulation.PLAYER))
	assert_signal_emit_count(sim, "lap_completed", 3)
	assert_signal_emitted_with_parameters(sim, "lap_completed", [RaceSimulation.PLAYER, 3])
	assert_signal_emit_count(sim, "car_finished", 1)
	assert_eq(sim.current_lap(RaceSimulation.PLAYER), 3, "HUD lap is capped")
	var finish := sim.finish_time_s[RaceSimulation.PLAYER]
	for i in 600:
		sim.tick()
	assert_eq(sim.finish_time_s[RaceSimulation.PLAYER], finish, "finish time frozen")
	assert_signal_emit_count(sim, "car_finished", 1)
	assert_almost_eq(sim.cars[RaceSimulation.PLAYER].speed_mps, 0.0, 1e-6, "coasts to a stop")


func test_snapshots_hold_previous_and_current_tick() -> void:
	var sim := _sim(&"basic", FullThrottle.new())
	for i in 30:
		sim.tick()
	var prev := sim.previous_snapshot()
	var curr := sim.current_snapshot()
	assert_ne(prev, curr)
	assert_eq(curr.tick, 30)
	assert_eq(prev.tick, 29)
	assert_lt(prev.s_m[0], curr.s_m[0])
	assert_eq(curr.s_m[0], sim.cars[0].s_m)


func test_simulation_is_repeatable() -> void:
	var a := _sim(&"basic", FullThrottle.new())
	var b := _sim(&"basic", FullThrottle.new())
	for i in 1200:
		a.tick()
		b.tick()
	assert_eq(a.cars[0].s_m, b.cars[0].s_m)
	assert_eq(a.cars[0].x_m, b.cars[0].x_m)


func test_invalid_track_is_rejected() -> void:
	var sim := RaceSimulation.new()
	autofree(sim)
	var errors := sim.setup(Track.new(), VehicleParams.new())
	assert_gt(errors.size(), 0)
	assert_null(sim.track)
	assert_push_error("track has no segments")


func test_countdown_holds_the_field_then_beats_to_go() -> void:
	var sim := _sim(&"straight", FullThrottle.new(), 3)
	watch_signals(sim)
	var grid := sim.cars[0].s_m
	sim.start_countdown(3)
	for i in 3 * 60 - 1:
		sim.tick()
	assert_eq(sim.cars[0].s_m, grid, "held during countdown")
	assert_eq(sim.race_time_s, 0.0, "clock stopped")
	sim.tick()
	assert_eq(sim.countdown_s, 0.0)
	assert_signal_emit_count(sim, "countdown_beat", 4)
	assert_signal_emitted_with_parameters(sim, "countdown_beat", [0])
	sim.tick()
	assert_gt(sim.cars[0].s_m, grid, "racing after GO")
