extends Node
## Game state and scene flow (§9): garage → race → results → garage.
## Autoloaded as `Game`.

const GARAGE_SCENE := "res://scenes/garage.tscn"
const RACE_SCENE := "res://scenes/race.tscn"
const CUP_PATHS := ["res://resources/cups/sunrise_coast.tres", "res://resources/cups/red_mesa.tres"]
## Flags that skip the garage and drop straight into a free race.
const DEV_RACE_FLAGS := ["--track=", "--opponents=", "--autodrive"]
## Imported with integer-only scaling so pixels stay square.
const FONT: FontFile = preload("res://assets/fonts/retroshift_5x7.fnt")
const MUSIC := {
	&"race": preload("res://assets/audio/music_race.wav"),
	&"garage": preload("res://assets/audio/music_garage.wav"),
}
const MUSIC_VOLUME_DB := -8.0
## Saved in the profile's settings.
const SETTING_MUSIC := "music_on"
const SETTING_SFX := "sfx_on"

var cups: Array[CupDefinition] = []
## Every event in championship order.
var events: Array[EventDefinition] = []
var progression: Progression
## Event being raced, or null for a free race (no rewards).
var current_event: EventDefinition

var _dev_race_pending: bool = false
var _music_player: AudioStreamPlayer
var _music_name: StringName


func _ready() -> void:
	InputBindings.install_defaults()
	for path: String in CUP_PATHS:
		var cup: CupDefinition = load(path)
		cups.append(cup)
		events.append_array(cup.events)
	progression = Progression.new(SaveService.new(FileSaveStorage.new()))
	progression.sync_unlocks(cups)
	_setup_audio()
	get_tree().auto_accept_quit = false
	for arg in OS.get_cmdline_user_args():
		for flag: String in DEV_RACE_FLAGS:
			if arg.begins_with(flag):
				_dev_race_pending = true


## True once if the command line asked for a free race.
func take_dev_race_request() -> bool:
	var pending := _dev_race_pending
	_dev_race_pending = false
	return pending


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		quit()


## Quits after stopping all audio. Streams still playing at exit leak their
## playback objects, which the audio server only releases on a later mix.
func quit() -> void:
	stop_music()
	var scene := get_tree().current_scene
	if scene != null:
		scene.queue_free()
	for i in 3:
		await get_tree().process_frame
	get_tree().quit()


func event_by_id(id: StringName) -> EventDefinition:
	for event in events:
		if event.id == id:
			return event
	return null


func cup_of(event: EventDefinition) -> CupDefinition:
	for cup in cups:
		if cup.events.has(event):
			return cup
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
	return progression.award(current_event, place, time_s, cup_of(current_event))


func go_to_garage() -> void:
	_change_scene(GARAGE_SCENE)


## Touch UI: real touchscreen, or --touch to try it on desktop with a mouse.
func touch_mode() -> bool:
	return DisplayServer.is_touchscreen_available() or OS.get_cmdline_user_args().has("--touch")


func play_music(music_name: StringName) -> void:
	if music_name == _music_name and _music_player.playing:
		return
	_music_name = music_name
	_music_player.stream = MUSIC[music_name]
	_music_player.play()


func stop_music() -> void:
	_music_player.stop()
	_music_player.stream = null
	_music_name = &""


func is_enabled(setting: String) -> bool:
	return progression.profile.settings.get(setting, true)


func toggle(setting: String) -> void:
	progression.profile.settings[setting] = not is_enabled(setting)
	progression.save()
	_apply_audio_settings()


func _setup_audio() -> void:
	for bus_name in [&"Music", &"SFX"]:
		if AudioServer.get_bus_index(bus_name) < 0:
			AudioServer.add_bus()
			var index := AudioServer.bus_count - 1
			AudioServer.set_bus_name(index, bus_name)
			AudioServer.set_bus_send(index, &"Master")
	for stream: AudioStreamWAV in MUSIC.values():
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = roundi(stream.get_length() * stream.mix_rate)
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = &"Music"
	_music_player.volume_db = MUSIC_VOLUME_DB
	add_child(_music_player)
	_apply_audio_settings()


func _apply_audio_settings() -> void:
	AudioServer.set_bus_mute(AudioServer.get_bus_index(&"Music"), not is_enabled(SETTING_MUSIC))
	AudioServer.set_bus_mute(AudioServer.get_bus_index(&"SFX"), not is_enabled(SETTING_SFX))


func _change_scene(path: String) -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(path)
