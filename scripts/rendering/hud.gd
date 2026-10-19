class_name Hud
extends Node2D
## Race HUD (§2): position, lap, timer, speed, nitro, minimap, and the
## results panel once the player finishes. Read-only.

const TEXT := Color8(255, 255, 255)
const TEXT_DIM := Color8(176, 184, 200)
const TEXT_SHADOW := Color8(0, 0, 0)
const NITRO_ON := Color8(64, 200, 255)
const NITRO_OFF := Color8(40, 56, 72)
const MAP_LINE := Color8(255, 255, 255, 200)
const MAP_PLAYER := Color8(255, 64, 64)
const MAP_OPPONENT := Color8(255, 220, 64)
const PANEL := Color8(0, 0, 0, 170)
const NOTE := Color8(255, 210, 80)
const FONT_SIZE := 10
const MAP_SIZE := 52.0
const MAP_MARGIN := 6.0

var sim: RaceSimulation
var paused: bool = false
## Extra lines under the results (credits earned, unlocks).
var result_notes := PackedStringArray()
var result_hint: String = "R: race again"
var pause_hint: String = ""

var _font: Font
var _minimap: Minimap
var _minimap_track: Track
var _map_line := PackedVector2Array()
var _map_origin := Vector2.INF


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

	var line := 14.0
	if snap.car_count > 1:
		_text(Vector2(6, line), "POS %d/%d" % [snap.position[car], snap.car_count])
		line += 12.0
	_text(Vector2(6, line), "LAP %d/%d" % [sim.current_lap(car), sim.track.laps])
	var time_s := sim.finish_time_s[car] if snap.finished[car] else snap.race_time_s
	_text(Vector2(6, line + 12.0), format_time(time_s))
	_text(Vector2(view.x - 70, view.y - 8), "%3d km/h" % roundi(snap.speed_mps[car] * 3.6))

	var boosting := snap.nitro_active[car] != 0
	for i in sim.car_params[car].nitro_count:
		var lit := i < snap.nitro_remaining[car] or (boosting and i == snap.nitro_remaining[car])
		draw_rect(Rect2(6 + i * 9, view.y - 14, 7, 7), NITRO_ON if lit else NITRO_OFF)

	_draw_minimap(view, snap)

	if sim.has_results():
		_draw_results(view)
	elif paused:
		_text_centered(view, view.y * 0.35, "PAUSED")
		_text_centered(view, view.y * 0.35 + 14.0, pause_hint)
	elif snap.s_m[car] < 0.0:
		_text_centered(view, view.y * 0.35, "GO!")


func _draw_minimap(view: Vector2, snap: RaceSnapshot) -> void:
	if _minimap_track != sim.track:
		_minimap_track = sim.track
		_minimap = Minimap.new(sim.track)
		_map_origin = Vector2.INF
	var origin := Vector2(view.x - MAP_SIZE - MAP_MARGIN, MAP_MARGIN)
	if origin != _map_origin:
		_map_origin = origin
		_map_line.resize(_minimap.points.size())
		for i in _map_line.size():
			_map_line[i] = origin + _minimap.points[i] * MAP_SIZE
	draw_polyline(_map_line, MAP_LINE, 1.0)
	# Opponents first so the player dot stays on top.
	for i in range(snap.car_count - 1, -1, -1):
		var p := origin + _minimap.point_at(snap.s_m[i]) * MAP_SIZE
		if i == RaceSimulation.PLAYER:
			draw_rect(Rect2(roundf(p.x) - 1, roundf(p.y) - 1, 3, 3), MAP_PLAYER)
		else:
			draw_rect(Rect2(roundf(p.x) - 1, roundf(p.y) - 1, 2, 2), MAP_OPPONENT)


func _draw_results(view: Vector2) -> void:
	var rows := sim.result_order.size()
	var height := 38.0 + (rows + result_notes.size()) * 11.0
	var top := roundf((view.y - height) * 0.5)
	var width := 170.0
	var left := roundf((view.x - width) * 0.5)
	draw_rect(Rect2(left, top, width, height), PANEL)
	var place := sim.result_order.find(RaceSimulation.PLAYER) + 1
	_text_centered(view, top + 12.0, "FINISHED %s" % ordinal(place))
	for row in rows:
		var car := sim.result_order[row]
		var who := "YOU" if car == RaceSimulation.PLAYER else "CPU %d" % car
		var time := format_time(sim.result_time_s[car])
		if sim.result_projected[car]:
			time += "*"
		var y := top + 25.0 + row * 11.0
		var color := TEXT if car == RaceSimulation.PLAYER else TEXT_DIM
		_text(Vector2(left + 8, y), "%d. %s" % [row + 1, who], color)
		_text(Vector2(left + 80, y), time, color)
	for i in result_notes.size():
		_text(Vector2(left + 8, top + 27.0 + (rows + i) * 11.0), result_notes[i], NOTE)
	_text(Vector2(left + 8, top + height - 4.0), result_hint, TEXT_DIM)


func _text(pos: Vector2, text: String, color: Color = TEXT) -> void:
	draw_string(_font, pos + Vector2.ONE, text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, TEXT_SHADOW)
	draw_string(_font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, color)


func _text_centered(view: Vector2, y: float, text: String) -> void:
	var width := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
	_text(Vector2(roundf((view.x - width) * 0.5), y), text)


static func format_time(seconds: float) -> String:
	var minutes := floori(seconds / 60.0)
	return "%d:%05.2f" % [minutes, seconds - minutes * 60.0]


static func ordinal(n: int) -> String:
	var suffix := "th"
	if n % 100 < 11 or n % 100 > 13:
		match n % 10:
			1: suffix = "st"
			2: suffix = "nd"
			3: suffix = "rd"
	return "%d%s" % [n, suffix]
