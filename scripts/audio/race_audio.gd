class_name RaceAudio
extends Node
## Race sound (§2): engine, tire squeal, nitro, impacts, countdown and lap
## jingles. Reacts to simulation signals and snapshots; never mutates them.

const SOUNDS := {
	&"beep_low": preload("res://assets/audio/beep_low.wav"),
	&"beep_high": preload("res://assets/audio/beep_high.wav"),
	&"nitro": preload("res://assets/audio/nitro.wav"),
	&"thud": preload("res://assets/audio/thud.wav"),
	&"lap": preload("res://assets/audio/lap.wav"),
	&"finish": preload("res://assets/audio/finish.wav"),
}
const SQUEAL: AudioStreamWAV = preload("res://assets/audio/squeal.wav")
## Squeal starts at this fraction of the curve's v_max...
const SQUEAL_FROM := 0.85
## ...and is at full volume this much above it.
const SQUEAL_RANGE := 0.3
const SQUEAL_MIN_SPEED_MPS := 15.0

var sim: RaceSimulation:
	set(value):
		_disconnect()
		sim = value
		_connect()

var _engine: EngineSynth
var _squeal: AudioStreamPlayer
var _players := {}


func _ready() -> void:
	_engine = EngineSynth.new()
	add_child(_engine)
	var squeal: AudioStreamWAV = SQUEAL
	squeal.loop_mode = AudioStreamWAV.LOOP_FORWARD
	squeal.loop_end = roundi(squeal.get_length() * squeal.mix_rate)
	_squeal = _player(squeal)
	_squeal.volume_db = -80.0
	_squeal.play()
	for sound: StringName in SOUNDS:
		_players[sound] = _player(SOUNDS[sound])


func _process(_delta: float) -> void:
	if sim == null or sim.track == null:
		return
	var car := RaceSimulation.PLAYER
	var state := sim.cars[car]
	var params := sim.car_params[car]
	_engine.speed_mps = state.speed_mps
	_engine.max_speed_mps = params.max_speed_mps
	_engine.throttle = sim.inputs[car].throttle if sim.countdown_s <= 0.0 else sim.inputs[car].throttle * 0.5
	_engine.boosting = state.nitro_timer_s > 0.0

	var slip := 0.0
	if state.speed_mps > SQUEAL_MIN_SPEED_MPS and not VehiclePhysics.is_off_road(state, sim.track):
		var v_max := VehiclePhysics.v_max(sim.track.curvature_at(state.s_m), params)
		slip = clampf((state.speed_mps / v_max - SQUEAL_FROM) / SQUEAL_RANGE, 0.0, 1.0)
	_squeal.volume_db = lerpf(-40.0, -6.0, slip) if slip > 0.0 else -80.0


func play(sound: StringName) -> void:
	_players[sound].play()


func _player(stream: AudioStream) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.bus = &"SFX"
	add_child(player)
	return player


func _connect() -> void:
	if sim == null:
		return
	sim.countdown_beat.connect(_on_countdown_beat)
	sim.nitro_fired.connect(_on_nitro_fired)
	sim.collided.connect(_on_collided)
	sim.lap_completed.connect(_on_lap_completed)
	sim.car_finished.connect(_on_car_finished)


func _disconnect() -> void:
	if sim == null:
		return
	sim.countdown_beat.disconnect(_on_countdown_beat)
	sim.nitro_fired.disconnect(_on_nitro_fired)
	sim.collided.disconnect(_on_collided)
	sim.lap_completed.disconnect(_on_lap_completed)
	sim.car_finished.disconnect(_on_car_finished)


func _on_countdown_beat(count: int) -> void:
	play(&"beep_low" if count > 0 else &"beep_high")


func _on_nitro_fired(car: int) -> void:
	if car == RaceSimulation.PLAYER:
		play(&"nitro")


func _on_collided(rear_car: int, front_car: int) -> void:
	if RaceSimulation.PLAYER in [rear_car, front_car]:
		play(&"thud")


func _on_lap_completed(car: int, lap: int) -> void:
	if car == RaceSimulation.PLAYER and lap < sim.track.laps:
		play(&"lap")


func _on_car_finished(car: int, _time_s: float) -> void:
	if car == RaceSimulation.PLAYER:
		play(&"finish")
