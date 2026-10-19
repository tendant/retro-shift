class_name Hud
extends Node2D
## Minimal race HUD (§2): speed, lap, timer, nitro. Read-only.

const TEXT := Color8(255, 255, 255)
const TEXT_SHADOW := Color8(0, 0, 0)
const NITRO_ON := Color8(64, 200, 255)
const NITRO_OFF := Color8(40, 56, 72)
const FONT_SIZE := 10

var sim: RaceSimulation
var paused: bool = false

var _font: Font


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_font = ThemeDB.fallback_font


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if sim == null or sim.track == null:
		return
	var view := get_viewport_rect().size
	var snap := sim.current_snapshot()
	var car := RaceSimulation.PLAYER

	_text(Vector2(6, 14), "LAP %d/%d" % [sim.current_lap(car), sim.track.laps])
	var time_s := sim.finish_time_s[car] if snap.finished[car] else snap.race_time_s
	_text(Vector2(6, 26), _format_time(time_s))
	_text(Vector2(view.x - 70, view.y - 8), "%3d km/h" % roundi(snap.speed_mps[car] * 3.6))

	var boosting := snap.nitro_active[car] != 0
	for i in sim.params.nitro_count:
		var lit := i < snap.nitro_remaining[car] or (boosting and i == snap.nitro_remaining[car])
		draw_rect(Rect2(6 + i * 9, view.y - 14, 7, 7), NITRO_ON if lit else NITRO_OFF)

	if snap.finished[car]:
		_text_centered(view, "FINISH  " + _format_time(sim.finish_time_s[car]))
	elif paused:
		_text_centered(view, "PAUSED")
	elif snap.s_m[car] < 0.0:
		_text_centered(view, "GO!")


func _text(pos: Vector2, text: String) -> void:
	draw_string(_font, pos + Vector2.ONE, text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, TEXT_SHADOW)
	draw_string(_font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, TEXT)


func _text_centered(view: Vector2, text: String) -> void:
	var width := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
	_text(Vector2((view.x - width) * 0.5, view.y * 0.35), text)


static func _format_time(seconds: float) -> String:
	var minutes := floori(seconds / 60.0)
	return "%d:%05.2f" % [minutes, seconds - minutes * 60.0]
