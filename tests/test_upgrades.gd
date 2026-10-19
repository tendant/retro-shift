extends GutTest


func _progression(credits: int = 0) -> Progression:
	var progression := Progression.new(SaveService.new(MemorySaveStorage.new()))
	progression.profile.credits = credits
	return progression


func test_apply_scales_the_right_stats() -> void:
	var base := VehicleParams.new()
	var params := Upgrades.apply(base, {&"engine": 3, &"gearbox": 2, &"tires": 1, &"nitro": 3})
	assert_almost_eq(params.engine_accel_mps2, base.engine_accel_mps2 * 1.35, 1e-9)
	assert_almost_eq(params.max_speed_mps, base.max_speed_mps * 1.12, 1e-9)
	assert_almost_eq(params.grip, base.grip * 1.08, 1e-9)
	assert_eq(params.nitro_count, 6)
	assert_gt(params.nitro_accel_mult, base.nitro_accel_mult, "nitro L3 boosts are stronger")


func test_apply_never_mutates_the_base() -> void:
	var base := VehicleParams.new()
	var before := base.engine_accel_mps2
	Upgrades.apply(base, {&"engine": 3})
	assert_eq(base.engine_accel_mps2, before)


func test_tires_raise_v_max() -> void:
	var base := VehicleParams.new()
	var tuned := Upgrades.apply(base, {&"tires": 1})
	assert_gt(VehiclePhysics.v_max(0.01, tuned), VehiclePhysics.v_max(0.01, base))


func test_purchase_needs_enough_credits_and_changes_nothing_otherwise() -> void:
	var progression := _progression(199)
	assert_false(progression.buy(&"engine"))
	assert_eq(progression.profile.credits, 199)
	assert_eq(progression.profile.level(&"engine"), 0)
	progression.profile.credits = 200
	assert_true(progression.buy(&"engine"))
	assert_eq(progression.profile.credits, 0)
	assert_eq(progression.profile.level(&"engine"), 1)


func test_levels_cap_at_three() -> void:
	var progression := _progression(100000)
	for i in 3:
		assert_true(progression.buy(&"tires"))
	assert_false(progression.buy(&"tires"))
	assert_eq(progression.profile.level(&"tires"), 3)
	assert_eq(progression.profile.credits, 100000 - 150 - 350 - 650)
	assert_eq(Upgrades.next_price(&"tires", 3), -1)


func test_player_params_follow_profile() -> void:
	var progression := _progression(1000)
	var before := progression.player_params().max_speed_mps
	progression.buy(&"gearbox")
	assert_gt(progression.player_params().max_speed_mps, before)
