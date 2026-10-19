extends GutTest
## Garage and race scenes wired through the Game autoload.

var _saved_progression: Progression
var _saved_event: EventDefinition


func before_each() -> void:
	# Never touch the real user:// save from tests.
	_saved_progression = Game.progression
	_saved_event = Game.current_event
	Game.progression = Progression.new(SaveService.new(MemorySaveStorage.new()))


func after_each() -> void:
	Game.stop_music()
	Game.progression = _saved_progression
	Game.current_event = _saved_event
	get_tree().paused = false


func _buttons(node: Node) -> Array[Button]:
	var found: Array[Button] = []
	for child in node.find_children("*", "Button", true, false):
		found.append(child)
	return found


func test_garage_shows_locks_and_affordability() -> void:
	var garage: Control = add_child_autofree(load("res://scenes/garage.tscn").instantiate())
	var buttons := _buttons(garage)
	var start := Game.events.size()
	var first_upgrade := start + 1
	var settings := first_upgrade + Upgrades.LINES.size()
	assert_eq(buttons.size(), settings + 2, "events, start, upgrades, music + sound toggles")
	assert_false(buttons[0].disabled, "event 1 open")
	assert_true(buttons[1].disabled, "event 2 locked")
	for i in range(first_upgrade, settings):
		assert_true(buttons[i].disabled, "can't afford anything with 0 credits")

	Game.progression.award(Game.events[0], 1, 100.0)  # emits changed → refresh
	assert_false(buttons[1].disabled, "event 2 unlocked by a win")
	assert_string_contains(buttons[0].text, "BEST 1st")

	# Choosing an event selects it; only START races.
	Game.current_event = null
	buttons[1].pressed.emit()
	assert_null(Game.current_event, "choosing doesn't start a race")
	assert_string_contains(buttons[1].text, "> ")
	assert_false(buttons[0].text.begins_with("> "), "only one event selected")
	assert_eq(buttons[start].text, "START  %s" % Game.events[1].display_name.to_upper())
	assert_true(buttons[start].has_focus(), "focus moves to START")
	var tires_button := buttons[first_upgrade + Upgrades.LINES.find(&"tires")]
	assert_false(tires_button.disabled)
	tires_button.pressed.emit()
	assert_eq(Game.progression.profile.level(&"tires"), 1)
	assert_eq(Game.progression.profile.credits, 400 - 150)


func test_event_race_awards_credits_on_finish() -> void:
	Game.current_event = Game.events[0]
	Game.progression.buy(&"engine")  # no credits: no-op, keeps stock params
	var race: Node = add_child_autofree(load("res://scenes/race.tscn").instantiate())
	var sim: RaceSimulation = race.get_node("RaceSimulation")
	assert_eq(sim.cars.size(), Game.events[0].opponents + 1)
	assert_eq(sim.track.laps, Game.events[0].laps)
	assert_eq(sim.car_params[0].nitro_count, 3)

	assert_gt(sim.countdown_s, 0.0, "race opens with a countdown")
	while sim.countdown_s > 0.0:
		sim.tick()
	var race_end := sim.track.laps * sim.track.lap_length_m
	sim.cars[0].s_m = race_end - 0.5
	sim.cars[0].speed_mps = 60.0
	sim.tick()
	assert_true(sim.has_results())
	var place := sim.result_order.find(0) + 1
	assert_eq(place, 1)
	assert_eq(Game.progression.profile.credits, 400)
	assert_true(Game.progression.profile.is_unlocked(&"lighthouse_loop"))
	var hud: Hud = race.get_node("GameView/Hud")
	assert_eq(hud.result_notes[0], "+400 credits")
	assert_true(Array(hud.result_notes).has("Unlocked: Lighthouse Loop"))


func test_race_uses_upgraded_player_car() -> void:
	Game.progression.profile.credits = 10000
	Game.progression.buy(&"nitro")
	Game.current_event = Game.events[0]
	var race: Node = add_child_autofree(load("res://scenes/race.tscn").instantiate())
	var sim: RaceSimulation = race.get_node("RaceSimulation")
	assert_eq(sim.car_params[0].nitro_count, 4)
	assert_eq(sim.cars[0].nitro_remaining, 4)
	assert_eq(sim.car_params[1].nitro_count, 3, "opponents stay stock")
