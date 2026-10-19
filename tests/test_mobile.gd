extends GutTest
## Touch layout, safe areas and app-lifecycle pause (§10).

## Landscape resolutions with typical safe-area insets (left, top, right, bottom).
const SCREENS := {
	"iphone_pro_max": [Vector2(2868, 1320), Vector4(177, 0, 177, 63)],
	"iphone_se": [Vector2(1334, 750), Vector4(0, 0, 0, 0)],
	"android_20x9": [Vector2(2400, 1080), Vector4(96, 0, 0, 0)],
	"ipad": [Vector2(2732, 2048), Vector4(0, 0, 0, 40)],
	"desktop": [Vector2(1280, 960), Vector4(0, 0, 0, 0)],
}
## Apple's minimum touch target is 44 pt; assume up to 3 px per pt.
const MIN_TARGET_PX := 44.0 * 3.0

var _saved_progression: Progression
var _saved_event: EventDefinition


func before_each() -> void:
	_saved_progression = Game.progression
	_saved_event = Game.current_event
	Game.progression = Progression.new(SaveService.new(MemorySaveStorage.new()))
	Game.current_event = Game.events[0]


func after_each() -> void:
	get_tree().paused = false
	Game.stop_music()
	Game.progression = _saved_progression
	Game.current_event = _saved_event


func test_touch_buttons_fit_safe_area_without_overlap() -> void:
	var controls: TouchControls = add_child_autofree(TouchControls.new())
	for screen: String in SCREENS:
		var size: Vector2 = SCREENS[screen][0]
		var inset: Vector4 = SCREENS[screen][1]
		controls.layout_for(size, inset)
		var safe := Rect2(inset.x, inset.y, size.x - inset.x - inset.z, size.y - inset.y - inset.w)
		var rects: Array[Rect2] = []
		for name: StringName in TouchControls.BUTTONS:
			var rect := controls.button_rect(name)
			assert_true(safe.encloses(rect), "%s: %s inside safe area" % [screen, name])
			if name != &"pause" and size.y >= 1000.0:
				assert_gte(rect.size.y, MIN_TARGET_PX, "%s: %s big enough to hit" % [screen, name])
			for other in rects:
				assert_false(rect.intersects(other), "%s: %s overlaps another button" % [screen, name])
			rects.append(rect)


func test_losing_focus_pauses_and_resume_continues() -> void:
	var race: Node = add_child_autofree(load("res://scenes/race.tscn").instantiate())
	race.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	assert_true(get_tree().paused, "backgrounding pauses the race")
	var menu: RaceMenu = race.find_children("*", "RaceMenu", false, false)[0]
	assert_true(menu.visible)
	var labels := menu.buttons().map(func(b: Button) -> String: return b.text)
	assert_eq(labels, ["RESUME", "RESTART", "QUIT TO GARAGE"])
	menu.buttons()[0].pressed.emit()
	assert_false(get_tree().paused, "resume unpauses")
	assert_false(menu.visible)


func test_results_offer_garage_and_retry() -> void:
	var race: Node = add_child_autofree(load("res://scenes/race.tscn").instantiate())
	var sim: RaceSimulation = race.get_node("RaceSimulation")
	while sim.countdown_s > 0.0:
		sim.tick()
	sim.cars[0].s_m = sim.track.laps * sim.track.lap_length_m - 0.5
	sim.cars[0].speed_mps = 60.0
	sim.tick()
	var menu: RaceMenu = race.find_children("*", "RaceMenu", false, false)[0]
	var labels := menu.buttons().map(func(b: Button) -> String: return b.text)
	assert_eq(labels, ["GARAGE", "RETRY"])
	race.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	assert_false(get_tree().paused, "no auto-pause once the race is over")
