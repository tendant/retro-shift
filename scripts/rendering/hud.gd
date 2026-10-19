class_name Hud
extends Node2D
## Race HUD (§2): position, lap, timer, speed, nitro, minimap, countdown,
## lap banners, first-race control hints, and the results panel. Read-only.

const TEXT := Color8(255, 255, 255)
const TEXT_DIM := Color8(176, 184, 200)
const TEXT_SHADOW := Color8(16, 16, 28)
const ACCENT := Color8(255, 208, 64)
const MAP_LINE := Color8(255, 255, 255, 220)
const MAP_PLAYER := Color8(255, 64, 64)
const MAP_OPPONENT := Color8(255, 220, 64)
const PANEL := Color8(10, 12, 28, 170)
const PANEL_EDGE := Color8(255, 255, 255, 60)
const NOTE := Color8(255, 210, 80)
## The bitmap font's native size; draw at whole multiples only.
const FONT_PX := 8
const MAP_SIZE := 52.0
const MARGIN := 6.0
const BANNER_S := 1.5
const HINTS := "↑ GAS   ↓ BRAKE   ← → STEER   SPACE NITRO"

## Setting a new simulation resets per-race HUD state (banners, lap).
var sim: RaceSimulation:
	set(value):
		sim = value
		_shown_lap = 0
		_banner_text = ""
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
var _shown_lap: int = 0
var _banner_text: String = ""
var _banner_until_s: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_font = Game.FONT


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if sim == null or sim.track == null:
		return
	var view := get_viewport_rect().size
	var snap := sim.current_snapshot()
	var car := RaceSimulation.PLAYER
	_update_lap_banner(snap)

	# Top left: position, lap, time.
	_panel(Rect2(MARGIN - 3, MARGIN - 3, 74, 44))
	if snap.car_count > 1:
		_text(Vector2(MARGIN, MARGIN), "POS", TEXT_DIM)
		_text(Vector2(MARGIN + 22, MARGIN - 1), "%d/%d" % [snap.position[car], snap.car_count], TEXT, 2)
	_text(Vector2(MARGIN, MARGIN + 18), "LAP %d/%d" % [sim.current_lap(car), sim.track.laps])
	var time_s := sim.finish_time_s[car] if snap.finished[car] else snap.race_time_s
	_text(Vector2(MARGIN, MARGIN + 29), format_time(time_s), ACCENT)

	# Bottom right: speed. Bottom left: nitro.
	var kmh := "%d" % roundi(snap.speed_mps[car] * 3.6)
	var speed_w := _width(kmh, 3)
	_text(Vector2(view.x - MARGIN - 30 - speed_w, view.y - MARGIN - 21), kmh, TEXT, 3)
	_text(Vector2(view.x - MARGIN - 24, view.y - MARGIN - 8), "KM/H", TEXT_DIM)
	_draw_nitro(view, snap, car)

	_draw_minimap(view, snap)

	if snap.countdown_s > 0.0 or (snap.race_time_s < 1.0 and sim.tick_count > 0 and snap.countdown_s == 0.0):
		_draw_countdown(view, snap)
	if snap.countdown_s > 0.0 or snap.race_time_s < 3.0:
		_text_centered(view, view.y - MARGIN - 34, HINTS, TEXT)
	if _banner_text != "" and snap.race_time_s < _banner_until_s:
		_text_centered(view, 64.0, _banner_text, ACCENT, 2)

	if sim.has_results():
		_draw_results(view)
	elif paused:
		_panel(Rect2(view.x * 0.5 - 70, view.y * 0.35 - 8, 140, 36))
		_text_centered(view, view.y * 0.35 - 2, "PAUSED", TEXT, 2)
		_text_centered(view, view.y * 0.35 + 16, pause_hint, TEXT_DIM)


func _update_lap_banner(snap: RaceSnapshot) -> void:
	var lap := sim.current_lap(RaceSimulation.PLAYER)
	if lap == _shown_lap:
		return
	if _shown_lap > 0 and not snap.finished[RaceSimulation.PLAYER]:
		_banner_text = "FINAL LAP" if lap == sim.track.laps else "LAP %d" % lap
		_banner_until_s = snap.race_time_s + BANNER_S
	_shown_lap = lap


func _draw_countdown(view: Vector2, snap: RaceSnapshot) -> void:
	var lit := 3 - ceili(snap.countdown_s)  # red lights on: 0..2, then all green
	var go := snap.countdown_s <= 0.0
	var size: Vector2 = SpriteAtlas.HUD_RECTS[&"light_off"].size
	var left := roundf(view.x * 0.5 - (size.x * 3 + 8) * 0.5)
	_panel(Rect2(left - 4, 40, size.x * 3 + 16, size.y + 8))
	for i in 3:
		var light: StringName = &"light_green" if go else (&"light_red" if i <= lit else &"light_off")
		draw_texture_rect_region(SpriteAtlas.HUD, Rect2(Vector2(left + i * (size.x + 4), 44), size),
				SpriteAtlas.HUD_RECTS[light])
	if go:
		_text_centered(view, 64.0, "GO!", ACCENT, 3)


func _draw_nitro(view: Vector2, snap: RaceSnapshot, car: int) -> void:
	var boosting := snap.nitro_active[car] != 0
	var size: Vector2 = SpriteAtlas.HUD_RECTS[&"nitro_on"].size
	var y := view.y - MARGIN - size.y
	_text(Vector2(MARGIN, y - 10), "NITRO", TEXT_DIM)
	for i in sim.car_params[car].nitro_count:
		var lit := i < snap.nitro_remaining[car]
		# The canister in use blinks.
		if boosting and i == snap.nitro_remaining[car]:
			lit = (sim.tick_count / 6) % 2 == 0
		var icon: StringName = &"nitro_on" if lit else &"nitro_off"
		draw_texture_rect_region(SpriteAtlas.HUD, Rect2(Vector2(MARGIN + i * (size.x + 2), y), size),
				SpriteAtlas.HUD_RECTS[icon])


func _draw_minimap(view: Vector2, snap: RaceSnapshot) -> void:
	if _minimap_track != sim.track:
		_minimap_track = sim.track
		_minimap = Minimap.new(sim.track)
		_map_origin = Vector2.INF
	var origin := Vector2(view.x - MAP_SIZE - MARGIN - 2, MARGIN + 2)
	if origin != _map_origin:
		_map_origin = origin
		_map_line.resize(_minimap.points.size())
		for i in _map_line.size():
			_map_line[i] = origin + _minimap.points[i] * MAP_SIZE
	_panel(Rect2(origin - Vector2(4, 4), Vector2(MAP_SIZE + 8, MAP_SIZE + 8)))
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
	var row_h := 10.0
	var height := 40.0 + (rows + result_notes.size()) * row_h
	var width := 176.0
	var top := roundf((view.y - height) * 0.5)
	var left := roundf((view.x - width) * 0.5)
	_panel(Rect2(left, top, width, height))
	var place := sim.result_order.find(RaceSimulation.PLAYER) + 1
	_text_centered(view, top + 6.0, "FINISHED %s" % ordinal(place), ACCENT, 2)
	for row in rows:
		var car := sim.result_order[row]
		var who := "YOU" if car == RaceSimulation.PLAYER else "CPU %d" % car
		var time := format_time(sim.result_time_s[car])
		if sim.result_projected[car]:
			time += "*"
		var y := top + 26.0 + row * row_h
		var color := ACCENT if car == RaceSimulation.PLAYER else TEXT_DIM
		_text(Vector2(left + 10, y), "%d. %s" % [row + 1, who], color)
		_text(Vector2(left + 96, y), time, color)
	for i in result_notes.size():
		_text(Vector2(left + 10, top + 28.0 + (rows + i) * row_h), result_notes[i], NOTE)
	_text(Vector2(left + 10, top + height - 11.0), result_hint, TEXT)


## Dark translucent box with a thin light edge.
func _panel(rect: Rect2) -> void:
	draw_rect(rect, PANEL)
	draw_rect(rect, PANEL_EDGE, false, 1.0)


## Draws `text` with its top-left at `pos`, at a whole-number `scale`.
func _text(pos: Vector2, text: String, color: Color = TEXT, scale: int = 1) -> void:
	var size := FONT_PX * scale
	var baseline := Vector2(roundf(pos.x), roundf(pos.y) + 7 * scale)
	draw_string(_font, baseline + Vector2(scale, scale), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, TEXT_SHADOW)
	draw_string(_font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


func _text_centered(view: Vector2, y: float, text: String, color: Color = TEXT, scale: int = 1) -> void:
	_text(Vector2(roundf((view.x - _width(text, scale)) * 0.5), y), text, color, scale)


func _width(text: String, scale: int) -> float:
	return _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_PX * scale).x


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
