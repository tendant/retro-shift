class_name EngineSynth
extends AudioStreamPlayer
## Live engine sound for the player car (§2). Pitch follows speed through
## simulated gears; louder on throttle, rougher on nitro.

const MIX_RATE := 22050.0
const GEARS := 5
const IDLE_HZ := 34.0
const REDLINE_HZ := 140.0
## How fast the tone glides to a new pitch (1/s); gives audible shifts.
const PITCH_RATE := 14.0

var speed_mps: float = 0.0
var max_speed_mps: float = 75.0
var throttle: float = 0.0
var boosting: bool = false

var _playback: AudioStreamGeneratorPlayback
var _phase: float = 0.0
var _hz: float = IDLE_HZ
var _gain: float = 0.0
var _lowpass: float = 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	var generator := AudioStreamGenerator.new()
	generator.mix_rate = MIX_RATE
	generator.buffer_length = 0.1
	stream = generator
	bus = &"SFX"
	volume_db = -4.0
	play()
	_playback = get_stream_playback()


## Engine speed in [0.2, 1.15] from road speed, as if shifting through gears.
static func rpm_for(speed: float, max_speed: float) -> float:
	if speed < 1.0:
		return 0.2
	var gear_span := max_speed / GEARS
	var gear := mini(floori(speed / gear_span), GEARS - 1)
	var within := (speed - gear * gear_span) / gear_span
	return clampf(0.35 + 0.65 * within, 0.2, 1.15)


func _process(delta: float) -> void:
	if _playback == null:
		return
	var target_hz := lerpf(IDLE_HZ, REDLINE_HZ, rpm_for(speed_mps, max_speed_mps))
	var target_gain := 0.22 + 0.3 * throttle + (0.12 if boosting else 0.0)
	var frames := _playback.get_frames_available()
	if frames <= 0:
		return
	var blend := 1.0 - exp(-PITCH_RATE * delta)
	var hz_step := (lerpf(_hz, target_hz, blend) - _hz) / frames
	var gain_step := (lerpf(_gain, target_gain, blend) - _gain) / frames
	var roughness := 0.05 + 0.1 * throttle + (0.15 if boosting else 0.0)
	for i in frames:
		_hz += hz_step
		_gain += gain_step
		_phase = fmod(_phase + _hz / MIX_RATE, 1.0)
		var saw := 2.0 * _phase - 1.0
		var pulse := 1.0 if fmod(_phase * 2.0, 1.0) < 0.3 else -1.0
		var v := 0.55 * saw + 0.3 * pulse + roughness * _rng.randf_range(-1.0, 1.0)
		_lowpass += 0.3 * (v - _lowpass)
		var out := _lowpass * _gain
		_playback.push_frame(Vector2(out, out))
