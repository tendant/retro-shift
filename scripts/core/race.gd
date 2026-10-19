extends Node
## Race scene: wires the simulation to the low-res game view, reports the
## finish to Game, and handles UI/game-state input (pause, restart, debug,
## track switching, back to garage).

const VIEW_HEIGHT := 240

var _event: EventDefinition
## Free race (no event): dev flags and F2 track cycling.
var _free_race: bool = false
var _track_index: int = 0
var _autodrive: bool = false

@onready var _sim: RaceSimulation = $RaceSimulation
@onready var _view: SubViewport = $GameView
@onready var _renderer: RoadRenderer = $GameView/RoadRenderer
@onready var _hud: Hud = $GameView/Hud
@onready var _screen: TextureRect = $Screen


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_sim.process_mode = Node.PROCESS_MODE_PAUSABLE
	_screen.texture = _view.get_texture()
	get_window().size_changed.connect(_fit_view)
	_fit_view()
	_sim.results_ready.connect(_on_results_ready)
	_autodrive = OS.get_cmdline_user_args().has("--autodrive")
	_renderer.debug_enabled = OS.get_cmdline_user_args().has("--debug")

	_event = Game.current_event
	_free_race = _event == null
	if _free_race:
		_track_index = maxi(0, TestTracks.NAMES.find(StringName(_cmdline_value("--track="))))
		_event = _free_race_event()
	_start_race()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"confirm") and (_sim.has_results() or get_tree().paused):
		if _free_race:
			_start_race()
		else:
			Game.go_to_garage()
	elif event.is_action_pressed(&"pause") and not _sim.has_results():
		get_tree().paused = not get_tree().paused
		_hud.paused = get_tree().paused
	elif event.is_action_pressed(&"restart"):
		_start_race()
	elif event.is_action_pressed(&"toggle_debug"):
		_renderer.debug_enabled = not _renderer.debug_enabled
	elif event.is_action_pressed(&"next_track") and _free_race:
		_track_index = (_track_index + 1) % TestTracks.NAMES.size()
		_event = _free_race_event()
		_start_race()


func _start_race() -> void:
	get_tree().paused = false
	_hud.paused = false
	_hud.result_notes = PackedStringArray()
	_hud.result_hint = "Enter: race again" if _free_race else "Enter: garage    R: retry"
	_hud.pause_hint = "Enter: restart" if _free_race else "Enter: quit to garage"

	var track := TestTracks.make(_event.track_name)
	track.laps = _event.laps
	var opponents := _event.opponents
	_sim.setup(track, Game.progression.base_params, PlayerInputAdapter.new(), opponents + 1,
			Game.progression.player_params())
	_sim.rubber_band_strength = _event.rubber_band_strength
	for car in range(1, opponents + 1):
		var t := float(car - 1) / maxf(1.0, opponents - 1)
		var lane: float = OpponentAI.LANES[car % OpponentAI.LANES.size()]
		var skill := lerpf(_event.skill_min, _event.skill_max, t)
		_sim.set_input_source(car, OpponentAI.new(_sim, car, skill, lane))
	if _autodrive:
		_sim.set_input_source(RaceSimulation.PLAYER, OpponentAI.new(_sim, RaceSimulation.PLAYER))
	_renderer.sim = _sim
	_renderer.reset_camera()
	_hud.sim = _sim


func _on_results_ready() -> void:
	var car := RaceSimulation.PLAYER
	var place := _sim.result_order.find(car) + 1
	var award := Game.record_finish(place, _sim.result_time_s[car])
	if award.is_empty():
		return
	var notes := PackedStringArray(["+%d credits" % award.credits])
	if award.new_best:
		notes.append("New best!")
	if award.unlocked != &"":
		var unlocked := Game.event_by_id(award.unlocked)
		notes.append("Unlocked: %s" % (unlocked.display_name if unlocked else String(award.unlocked)))
	_hud.result_notes = notes


## Free races use dev flags: --track=NAME, --opponents=N.
func _free_race_event() -> EventDefinition:
	var event := EventDefinition.new()
	event.display_name = "Free race"
	event.track_name = TestTracks.NAMES[_track_index]
	var opponents_arg := _cmdline_value("--opponents=")
	if opponents_arg.is_valid_int():
		event.opponents = clampi(opponents_arg.to_int(), 0, 5)
	return event


## Fixed 240 px logical height; width follows the window's aspect ratio so
## widescreen shows more roadside instead of stretching (§10).
func _fit_view() -> void:
	var window_size := get_window().size
	if window_size.y <= 0:
		return
	var width := roundi(VIEW_HEIGHT * float(window_size.x) / float(window_size.y))
	_view.size = Vector2i(maxi(width, VIEW_HEIGHT), VIEW_HEIGHT)


static func _cmdline_value(prefix: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with(prefix):
			return arg.trim_prefix(prefix)
	return ""
