extends GutTest

const FILE := SaveService.PROFILE_FILE


func _profile() -> PlayerProfile:
	var profile := PlayerProfile.new()
	profile.credits = 321
	profile.upgrades[&"engine"] = 2
	profile.unlocked_events.append(&"event_2")
	profile.best_results[&"event_1"] = {"place": 2, "time_s": 101.5}
	profile.settings = {"volume": 0.5}
	return profile


func test_round_trip() -> void:
	var storage := MemorySaveStorage.new()
	var service := SaveService.new(storage)
	assert_true(service.save_profile(_profile()))
	var loaded := service.load_profile()
	assert_eq(loaded.credits, 321)
	assert_eq(loaded.level(&"engine"), 2)
	assert_true(loaded.is_unlocked(&"event_2"))
	assert_eq(loaded.best_results[&"event_1"], {"place": 2, "time_s": 101.5})
	assert_eq(loaded.settings, {"volume": 0.5})


func test_missing_save_gives_defaults() -> void:
	var loaded := SaveService.new(MemorySaveStorage.new()).load_profile()
	assert_eq(loaded.credits, 0)
	assert_true(loaded.is_unlocked(PlayerProfile.FIRST_EVENT))
	assert_false(loaded.is_unlocked(&"event_2"))


func test_corrupt_save_is_backed_up_and_reset() -> void:
	var storage := MemorySaveStorage.new()
	storage.files[FILE] = "{not json"
	var loaded := SaveService.new(storage).load_profile()
	assert_eq(loaded.credits, 0)
	assert_eq(storage.files["profile.corrupt.bak"], "{not json")


func test_bad_values_are_sanitized() -> void:
	var storage := MemorySaveStorage.new()
	storage.files[FILE] = JSON.stringify({
		"schema_version": SaveService.SCHEMA_VERSION,
		"credits": -50,
		"upgrades": {"engine": 9, "gearbox": "lots", "tires": 1.5, "nitro": 2},
		"unlocked_events": ["event_2", 7],
		"best_results": {"event_1": {"place": 0, "time_s": 10.0}, "event_2": "fast"},
	})
	var loaded := SaveService.new(storage).load_profile()
	assert_eq(loaded.credits, 0)
	assert_eq(loaded.level(&"engine"), Upgrades.MAX_LEVEL)
	assert_eq(loaded.level(&"gearbox"), 0)
	assert_eq(loaded.level(&"tires"), 0)
	assert_eq(loaded.level(&"nitro"), 2)
	assert_true(loaded.is_unlocked(PlayerProfile.FIRST_EVENT), "first event always unlocked")
	assert_true(loaded.is_unlocked(&"event_2"))
	assert_true(loaded.best_results.is_empty())


func test_newer_schema_is_backed_up_not_trusted() -> void:
	var storage := MemorySaveStorage.new()
	storage.files[FILE] = JSON.stringify({"schema_version": 99, "credits": 5000})
	var loaded := SaveService.new(storage).load_profile()
	assert_eq(loaded.credits, 0)
	assert_true(storage.exists("profile.corrupt.bak"))


func test_migration_backs_up_first_then_upgrades() -> void:
	var storage := MemorySaveStorage.new()
	SaveService.new(storage).save_profile(_profile())
	var v1_text := storage.read_text(FILE)

	# Pretend a future schema compensated every player with 100 credits.
	var from := SaveService.SCHEMA_VERSION
	var service := SaveService.new(storage)
	service.schema_version = from + 1
	service.migrations[from] = func(data: Dictionary) -> Dictionary:
		data["credits"] += 100
		return data
	var loaded := service.load_profile()
	assert_eq(storage.files["profile.v%d.bak" % from], v1_text, "original kept before migrating")
	assert_eq(loaded.credits, 421)
	assert_eq(loaded.level(&"engine"), 2, "everything else carried over")


func test_missing_migration_falls_back_to_defaults() -> void:
	var storage := MemorySaveStorage.new()
	SaveService.new(storage).save_profile(_profile())
	var service := SaveService.new(storage)
	service.schema_version = SaveService.SCHEMA_VERSION + 2
	service.migrations[SaveService.SCHEMA_VERSION] = func(data: Dictionary) -> Dictionary: return data
	var loaded := service.load_profile()
	assert_eq(loaded.credits, 0)
	assert_push_warning("no migration from schema %d" % (SaveService.SCHEMA_VERSION + 1))


func test_v1_save_moves_to_sunrise_coast_keeping_credits_and_upgrades() -> void:
	var storage := MemorySaveStorage.new()
	var v1 := JSON.stringify({
		"schema_version": 1,
		"credits": 1250,
		"upgrades": {"engine": 1, "gearbox": 0, "tires": 1, "nitro": 0},
		"unlocked_events": ["event_1", "event_2"],
		"best_results": {"event_1": {"place": 1, "time_s": 110.27}},
		"settings": {"music_on": false},
	})
	storage.files[FILE] = v1
	var loaded := SaveService.new(storage).load_profile()
	assert_eq(storage.files["profile.v1.bak"], v1, "backed up before migrating")
	assert_eq(loaded.credits, 1250)
	assert_eq(loaded.level(&"engine"), 1)
	assert_eq(loaded.level(&"tires"), 1)
	assert_eq(loaded.settings, {"music_on": false})
	assert_eq(loaded.unlocked_events, [PlayerProfile.FIRST_EVENT] as Array[StringName])
	assert_true(loaded.best_results.is_empty(), "old events are gone")
