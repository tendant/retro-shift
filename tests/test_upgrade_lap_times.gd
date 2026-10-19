extends GutTest
## Each upgrade level must produce a measurable lap-time change (§12),
## measured with the AI driving the player car alone on the first event track.

const MIN_GAIN_S := 0.1


func _race_time(levels: Dictionary) -> float:
	var sim := RaceSimulation.new()
	autofree(sim)
	var base := VehicleParams.new()
	sim.setup(TrackLibrary.make(&"harbor_mile"), base, null, 1, Upgrades.apply(base, levels))
	sim.set_input_source(0, OpponentAI.new(sim, 0, 1.0))
	while not sim.is_finished(0) and sim.tick_count < 60 * 600:
		sim.tick()
	assert_true(sim.is_finished(0))
	return sim.finish_time_s[0]


func test_every_level_of_every_line_is_faster() -> void:
	var stock := _race_time({})
	for line in Upgrades.LINES:
		var previous := stock
		for level in range(1, Upgrades.MAX_LEVEL + 1):
			var time := _race_time({line: level})
			gut.p("%s L%d: %.2f s (%.1f%% vs stock)" % [line, level, time, 100.0 * (stock - time) / stock])
			assert_lt(time, previous - MIN_GAIN_S, "%s L%d beats L%d by %.1f s" % [line, level, level - 1, MIN_GAIN_S])
			previous = time
