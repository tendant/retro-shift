extends Node
## Race scene: wires the simulation to the low-res game view and handles
## UI/game-state input (pause, restart, debug, track switching).

const VIEW_HEIGHT := 240
## Opponent skill spread (§7); the first opponent is the weakest.
const SKILL_MIN := 0.86
const SKILL_MAX := 1.0

@export var track_name: StringName = &"basic"
@export_range(0, 5) var opponents: int = 5

var _track_index: int = 0
var _autodrive: bool = false

@onready var _sim: RaceSimulation = $RaceSimulation
@onready var _view: SubViewport = $GameView
@onready var _renderer: RoadRenderer = $GameView/RoadRenderer
@onready var _hud: Hud = $GameView/Hud
@onready var _screen: TextureRect = $Screen


func _ready() -> void:
	InputBindings.install_defaults()
	process_mode = Node.PROCESS_MODE_ALWAYS
	_sim.process_mode = Node.PROCESS_MODE_PAUSABLE
	_screen.texture = _view.get_texture()
	get_window().size_changed.connect(_fit_view)
	_fit_view()

	var requested := _cmdline_value("--track=")
	if requested != "":
		track_name = StringName(requested)
	_autodrive = OS.get_cmdline_user_args().has("--autodrive")
	var opponents_arg := _cmdline_value("--opponents=")
	if opponents_arg.is_valid_int():
		opponents = clampi(opponents_arg.to_int(), 0, 5)
	_renderer.debug_enabled = OS.get_cmdline_user_args().has("--debug")
	_track_index = maxi(0, TestTracks.NAMES.find(track_name))
	_start_race()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause"):
		get_tree().paused = not get_tree().paused
		_hud.paused = get_tree().paused
	elif event.is_action_pressed(&"restart"):
		_start_race()
	elif event.is_action_pressed(&"toggle_debug"):
		_renderer.debug_enabled = not _renderer.debug_enabled
	elif event.is_action_pressed(&"next_track"):
		_track_index = (_track_index + 1) % TestTracks.NAMES.size()
		_start_race()


func _start_race() -> void:
	get_tree().paused = false
	_hud.paused = false
	var track := TestTracks.make(TestTracks.NAMES[_track_index])
	_sim.setup(track, VehicleParams.new(), PlayerInputAdapter.new(), opponents + 1)
	for car in range(1, opponents + 1):
		var t := float(car - 1) / maxf(1.0, opponents - 1)
		var lane: float = OpponentAI.LANES[car % OpponentAI.LANES.size()]
		_sim.set_input_source(car, OpponentAI.new(_sim, car, lerpf(SKILL_MIN, SKILL_MAX, t), lane))
	if _autodrive:
		_sim.set_input_source(RaceSimulation.PLAYER, OpponentAI.new(_sim, RaceSimulation.PLAYER))
	_renderer.sim = _sim
	_renderer.reset_camera()
	_hud.sim = _sim


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
