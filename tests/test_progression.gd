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


func _cup(events: Array) -> CupDefinition:
	var cup := CupDefinition.new()
	cup.id = &"test_cup"
	cup.unlocks = &"next_cup_1"
	for event: EventDefinition in events:
		cup.events.append(event)
	return cup


func test_trophies_need_top_three_everywhere_then_points() -> void:
	var progression := Progression.new(SaveService.new(MemorySaveStorage.new()))
	var a := _event(&"a")
	var b := _event(&"b")
	var c := _event(&"c")
	var cup := _cup([a, b, c])
	progression.award(a, 1, 100.0, cup)
	progression.award(b, 1, 100.0, cup)
	assert_eq(progression.trophy_for(cup), 0, "c not raced yet")
	var result := progression.award(c, 3, 100.0, cup)
	assert_eq(result.trophy, Progression.SILVER, "10 + 10 + 4 = 24 points")
	assert_eq(result.trophy_bonus, 300 + 500, "bronze and silver bonuses at once")
	assert_eq(result.unlocked, &"next_cup_1", "a trophy unlocks the next cup")
	assert_eq(progression.profile.credits, 400 + 400 + 150 + 800)
	result = progression.award(c, 2, 100.0, cup)
	assert_eq(progression.cup_points(cup), 26)
	assert_eq(result.trophy, Progression.GOLD)
	assert_eq(result.trophy_bonus, 800, "only the new tier is paid")
	result = progression.award(c, 1, 90.0, cup)
	assert_eq(result.trophy, 0, "already gold")
	assert_eq(result.trophy_bonus, 0)


func test_fourth_place_anywhere_blocks_the_trophy() -> void:
	var progression := Progression.new(SaveService.new(MemorySaveStorage.new()))
	var a := _event(&"a")
	var b := _event(&"b")
	var cup := _cup([a, b])
	progression.award(a, 1, 100.0, cup)
	progression.award(b, 4, 100.0, cup)
	assert_eq(progression.trophy_for(cup), 0)
	assert_eq(progression.cup_points(cup), 13, "points still count")


func test_sunrise_coast_cup_resources() -> void:
	var cup: CupDefinition = load("res://resources/cups/sunrise_coast.tres")
	assert_eq(cup.events.size(), 3)
	assert_eq(cup.events[0].id, PlayerProfile.FIRST_EVENT, "the championship starts here")
	for i in cup.events.size() - 1:
		assert_eq(cup.events[i].unlocks, cup.events[i + 1].id, "top 3 unlocks the next event")
	for i in range(1, cup.events.size()):
		assert_gte(cup.events[i].skill_max, cup.events[i - 1].skill_max, "AI gets no easier")
	for event in cup.events:
		var track: Track = event.track.duplicate()
		assert_eq(track.build(), PackedStringArray(), String(event.id))
		assert_almost_eq(track.net_heading_rad, TAU, 1e-6, "%s is a full loop" % event.id)
		assert_almost_eq(track.net_elevation_m, 0.0, 1e-6, "%s ends where it starts" % event.id)
		assert_not_null(track.palette, "%s has its own look" % event.id)
