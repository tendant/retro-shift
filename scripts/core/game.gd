extends Node
## Game state and scene flow (§9): garage → race → results → garage.
## Autoloaded as `Game`.

const GARAGE_SCENE := "res://scenes/garage.tscn"
const RACE_SCENE := "res://scenes/race.tscn"
const EVENT_PATHS := ["res://resources/events/event_1.tres", "res://resources/events/event_2.tres"]
## Flags that skip the garage and drop straight into a free race.
const DEV_RACE_FLAGS := ["--track=", "--opponents=", "--autodrive"]

var events: Array[EventDefinition] = []
var progression: Progression
## Event being raced, or null for a free race (no rewards).
var current_event: EventDefinition

var _dev_race_pending: bool = false


func _ready() -> void:
	InputBindings.install_defaults()
	for path: String in EVENT_PATHS:
		events.append(load(path))
	progression = Progression.new(SaveService.new(FileSaveStorage.new()))
	for arg in OS.get_cmdline_user_args():
		for flag: String in DEV_RACE_FLAGS:
			if arg.begins_with(flag):
				_dev_race_pending = true


## True once if the command line asked for a free race.
func take_dev_race_request() -> bool:
	var pending := _dev_race_pending
	_dev_race_pending = false
	return pending


func event_by_id(id: StringName) -> EventDefinition:
	for event in events:
		if event.id == id:
			return event
	return null


func start_event(event: EventDefinition) -> void:
	if not progression.profile.is_unlocked(event.id):
		return
	current_event = event
	_change_scene(RACE_SCENE)


func start_free_race() -> void:
	current_event = null
	_change_scene(RACE_SCENE)


## Awards the current event's finish. Returns Progression.award()'s result,
## or {} for a free race.
func record_finish(place: int, time_s: float) -> Dictionary:
	if current_event == null:
		return {}
	return progression.award(current_event, place, time_s)


func go_to_garage() -> void:
	_change_scene(GARAGE_SCENE)


func _change_scene(path: String) -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(path)
