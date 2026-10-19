extends GutTest


func _event(id: StringName, unlocks: StringName = &"", mult: float = 1.0) -> EventDefinition:
	var event := EventDefinition.new()
	event.id = id
	event.unlocks = unlocks
	event.reward_mult = mult
	return event


func test_rewards_by_place_and_tier() -> void:
	var tier1 := _event(&"a")
	assert_eq(Progression.reward_for(tier1, 1), 400)
	assert_eq(Progression.reward_for(tier1, 2), 250)
	assert_eq(Progression.reward_for(tier1, 3), 150)
	assert_eq(Progression.reward_for(tier1, 6), 75)
	assert_eq(Progression.reward_for(_event(&"b", &"", 1.5), 1), 600)


func test_top_three_unlocks_next_event() -> void:
	var progression := Progression.new(SaveService.new(MemorySaveStorage.new()))
	var first := _event(&"event_1", &"event_2")
	var result := progression.award(first, 4, 100.0)
	assert_eq(result.unlocked, &"")
	assert_false(progression.profile.is_unlocked(&"event_2"))
	result = progression.award(first, 3, 100.0)
	assert_eq(result.unlocked, &"event_2")
	assert_true(progression.profile.is_unlocked(&"event_2"))
	assert_eq(progression.profile.credits, 75 + 150)
	result = progression.award(first, 1, 90.0)
	assert_eq(result.unlocked, &"", "only reported the first time")


func test_best_result_keeps_the_best() -> void:
	var progression := Progression.new(SaveService.new(MemorySaveStorage.new()))
	var event := _event(&"event_1")
	assert_true(progression.award(event, 3, 100.0).new_best)
	assert_false(progression.award(event, 4, 90.0).new_best)
	assert_true(progression.award(event, 3, 95.0).new_best)
	assert_eq(progression.profile.best_results[&"event_1"], {"place": 3, "time_s": 95.0})


func test_changes_persist_across_sessions() -> void:
	var storage := MemorySaveStorage.new()
	var progression := Progression.new(SaveService.new(storage))
	progression.award(_event(&"event_1", &"event_2"), 1, 80.0)
	progression.buy(&"tires")
	var reloaded := Progression.new(SaveService.new(storage))
	assert_eq(reloaded.profile.credits, 400 - 150)
	assert_eq(reloaded.profile.level(&"tires"), 1)
	assert_true(reloaded.profile.is_unlocked(&"event_2"))
	assert_eq(reloaded.profile.best_results[&"event_1"].place, 1)


func test_event_resources_load_and_chain() -> void:
	var first: EventDefinition = load("res://resources/events/event_1.tres")
	var second: EventDefinition = load("res://resources/events/event_2.tres")
	assert_eq(first.id, &"event_1")
	assert_eq(first.unlocks, second.id)
	assert_gt(second.reward_mult, first.reward_mult)
	assert_lt(first.skill_max, second.skill_max, "event 2 has harder AI")
	for event in [first, second]:
		var track := TestTracks.make(event.track_name)
		assert_eq(track.build(), PackedStringArray())
		assert_almost_eq(track.net_heading_rad, TAU, 1e-6, "event tracks are full loops")
