class_name RoadRenderer
extends Node2D
## Pseudo-3D road renderer (§5).
##
## One far-to-near pass: for each strip, a full-width terrain band, then
## rumble/road/lane, then the sprites standing on that strip. Nearer strips
## paint over whatever lies beyond a crest, so no clipping buffer is needed.
## Reads only the interpolated snapshot; never advances the simulation.

const SKY_TOP := Color8(56, 104, 200)
const SKY_HORIZON := Color8(150, 196, 240)
const HILLS_FAR := Color8(92, 120, 168)
const HILLS_NEAR := Color8(64, 128, 88)
const GRASS := [Color8(56, 152, 56), Color8(48, 136, 48)]
const RUMBLE := [Color8(232, 232, 232), Color8(200, 40, 40)]
const ROAD := [Color8(104, 104, 112), Color8(96, 96, 104)]
const LANE := Color8(236, 236, 236)
const TREE_TRUNK := Color8(96, 64, 32)
const TREE_LEAVES := Color8(24, 104, 40)
const POST := Color8(240, 240, 240)
const POST_BAND := Color8(32, 32, 32)
const PLAYER_BODY := Color8(220, 40, 40)
const AI_BODY := Color8(40, 96, 220)
const CAR_GLASS := Color8(40, 48, 72)
const CAR_TYRE := Color8(24, 24, 24)
const CAR_LIGHT := Color8(255, 200, 64)
const SHADOW := Color(0, 0, 0, 0.35)
const DEBUG := Color8(255, 240, 0)
const DEBUG_EDGE := Color8(0, 255, 255)

const CAR_WIDTH_M := 1.8
const CAR_HEIGHT_M := 1.1
const RUMBLE_WIDTH_FRAC := 0.12
const LANE_HALF_WIDTH_M := 0.12

@export var steps: int = 240
@export var step_len_m: float = 3.0
@export var cam_height_m: float = 2.2
@export var cam_back_offset_m: float = 6.0
@export var vertical_fov_deg: float = 50.0
## Exponential follow rate (1/s) of the camera's lateral position.
@export var cam_lateral_follow_rate: float = 10.0
@export var stripe_len_m: float = 6.0
@export var scenery_spacing_m: float = 24.0
@export var parallax_px_per_rad: float = 160.0

var sim: RaceSimulation
var debug_enabled: bool = false

var _projector: RoadProjector
var _cam_x: float = 0.0
var _font: Font
# Interpolated car state for this frame, plus the strip each car stands on.
var _car_s := PackedFloat64Array()
var _car_x := PackedFloat64Array()
var _car_steer := PackedFloat64Array()
var _car_strip := PackedInt32Array()
# Scratch buffers reused for every primitive to avoid per-frame allocation.
var _quad := PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO])
var _tri := PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO])
var _color := PackedColorArray([Color.WHITE])
var _no_uvs := PackedVector2Array()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_projector = RoadProjector.new(steps, step_len_m)
	_font = ThemeDB.fallback_font


func reset_camera() -> void:
	_cam_x = 0.0


func _process(delta: float) -> void:
	if sim == null or sim.track == null:
		return
	var alpha := 1.0 if get_tree().paused else Engine.get_physics_interpolation_fraction()
	_interpolate(alpha)
	_cam_x = lerpf(_cam_x, _car_x[RaceSimulation.PLAYER], 1.0 - exp(-cam_lateral_follow_rate * delta))
	var s_cam := _car_s[RaceSimulation.PLAYER] - cam_back_offset_m
	_projector.build(sim.track, s_cam, _cam_x, cam_height_m, get_viewport_rect().size,
			deg_to_rad(vertical_fov_deg))
	for i in _car_s.size():
		_car_strip[i] = _projector.strip_at(_car_s[i])
	queue_redraw()


func _interpolate(alpha: float) -> void:
	var prev := sim.previous_snapshot()
	var curr := sim.current_snapshot()
	var n := curr.car_count
	if _car_s.size() != n:
		_car_s.resize(n)
		_car_x.resize(n)
		_car_steer.resize(n)
		_car_strip.resize(n)
	for i in n:
		_car_s[i] = lerpf(prev.s_m[i], curr.s_m[i], alpha)
		_car_x[i] = lerpf(prev.x_m[i], curr.x_m[i], alpha)
		_car_steer[i] = curr.steer[i]


func _draw() -> void:
	if sim == null or sim.track == null or _car_s.is_empty():
		return
	var view := get_viewport_rect().size
	_draw_background(view)
	for i in range(_projector.count - 2, -1, -1):
		if _draw_strip(i, view):
			_draw_scenery_on_strip(i)
			_draw_cars_on_strip(i)
	_draw_player()
	if debug_enabled:
		_draw_debug(view)


func _draw_background(view: Vector2) -> void:
	var horizon := _projector.center.y
	draw_rect(Rect2(0, 0, view.x, horizon * 0.5), SKY_TOP)
	draw_rect(Rect2(0, horizon * 0.5, view.x, horizon * 0.5), SKY_TOP.lerp(SKY_HORIZON, 0.5))
	draw_rect(Rect2(0, horizon * 0.8, view.x, horizon * 0.2), SKY_HORIZON)
	_draw_hills(view, horizon, 0.5, 96.0, 22.0, HILLS_FAR)
	_draw_hills(view, horizon, 1.0, 64.0, 12.0, HILLS_NEAR)
	draw_rect(Rect2(0, horizon, view.x, view.y - horizon), GRASS[1])


## Repeating mounds scrolled by camera heading; `depth` < 1 scrolls slower.
func _draw_hills(view: Vector2, horizon: float, depth: float, period: float, height: float,
		color: Color) -> void:
	var offset := fposmod(-_projector.cam_heading * parallax_px_per_rad * depth, period)
	var x := offset - period
	var k := 0
	while x < view.x + period:
		var h := height * (0.6 + 0.4 * absf(sin(float(k) * 1.7 + depth)))
		_tri[0] = Vector2(x - period * 0.6, horizon)
		_tri[1] = Vector2(x, horizon - h)
		_tri[2] = Vector2(x + period * 0.6, horizon)
		_color[0] = color
		draw_primitive(_tri, _color, _no_uvs)
		x += period
		k += 1


## Draws terrain band and road for strip [i, i + 1]. Returns false if the
## strip is behind the camera or faces away (beyond a crest).
func _draw_strip(i: int, view: Vector2) -> bool:
	var p := _projector
	var near_c := p.project_point(i, 0.0)
	var far_c := p.project_point(i + 1, 0.0)
	if near_c.z <= 0.0 or far_c.z <= 0.0 or near_c.y <= far_c.y:
		return false
	var stripe := posmod(floori(p.s_m[i] / stripe_len_m), 2)
	draw_rect(Rect2(0.0, far_c.y, view.x, near_c.y - far_c.y), GRASS[stripe])
	var hw := p.half_width[i]
	var rumble := hw * (1.0 + RUMBLE_WIDTH_FRAC)
	_draw_road_quad(i, -rumble, rumble, RUMBLE[stripe])
	_draw_road_quad(i, -hw, hw, ROAD[stripe])
	if stripe == 0:
		_draw_road_quad(i, -LANE_HALF_WIDTH_M, LANE_HALF_WIDTH_M, LANE)
	return true


func _draw_road_quad(i: int, lat_a: float, lat_b: float, color: Color) -> void:
	var p := _projector
	var a := p.project_point(i, lat_a)
	var b := p.project_point(i, lat_b)
	var c := p.project_point(i + 1, lat_b)
	var d := p.project_point(i + 1, lat_a)
	if a.z <= 0.0 or b.z <= 0.0 or c.z <= 0.0 or d.z <= 0.0:
		return
	_quad[0] = Vector2(a.x, a.y)
	_quad[1] = Vector2(b.x, b.y)
	_quad[2] = Vector2(c.x, c.y)
	_quad[3] = Vector2(d.x, d.y)
	_color[0] = color
	draw_primitive(_quad, _color, _no_uvs)


func _draw_scenery_on_strip(i: int) -> void:
	var p := _projector
	var n := ceili(p.s_m[i] / scenery_spacing_m)
	var s := n * scenery_spacing_m
	if s >= p.s_m[i + 1]:
		return
	var seg := sim.track.segment_at(s)
	if seg.scenery_id == &"" or seg.scenery_id == &"none":
		return
	var side := 1.0 if posmod(n, 2) == 0 else -1.0
	var lateral := side * (seg.road_half_width_m * (1.0 + RUMBLE_WIDTH_FRAC) + 2.0 + posmod(n, 3))
	var base := p.project_on_road(s, lateral)
	if base.z < 0.1:
		return
	match seg.scenery_id:
		&"trees":
			_draw_tree(base)
		&"posts":
			_draw_post(base)


func _draw_cars_on_strip(i: int) -> void:
	for car in range(1, _car_strip.size()):
		if _car_strip[car] == i:
			var base := _projector.project_on_road(_car_s[car], _car_x[car])
			if base.z > 0.0:
				_draw_car(base, _car_steer[car], AI_BODY)


func _draw_player() -> void:
	var car := RaceSimulation.PLAYER
	var base := _projector.project_on_road(_car_s[car], _car_x[car])
	if base.z > 0.0:
		_draw_car(base, _car_steer[car], PLAYER_BODY)


# --- Placeholder sprites (procedural until Milestone 5 art) ---------------

func _draw_tree(base: Vector3) -> void:
	var m := base.z
	_rect(base.x - 0.3 * m, base.y - 2.0 * m, 0.6 * m, 2.0 * m, TREE_TRUNK)
	_tri[0] = Vector2(roundf(base.x - 2.0 * m), roundf(base.y - 1.5 * m))
	_tri[1] = Vector2(roundf(base.x), roundf(base.y - 7.0 * m))
	_tri[2] = Vector2(roundf(base.x + 2.0 * m), roundf(base.y - 1.5 * m))
	_color[0] = TREE_LEAVES
	draw_primitive(_tri, _color, _no_uvs)


func _draw_post(base: Vector3) -> void:
	var m := base.z
	_rect(base.x - 0.15 * m, base.y - 2.5 * m, 0.3 * m, 2.5 * m, POST)
	_rect(base.x - 0.15 * m, base.y - 2.5 * m, 0.3 * m, 0.4 * m, POST_BAND)


## Rear view of a car with left/center/right turning frames (§5).
func _draw_car(base: Vector3, steer: float, body: Color) -> void:
	var m := base.z
	var w := CAR_WIDTH_M * m
	var h := CAR_HEIGHT_M * m
	var frame := 0.0 if absf(steer) < 0.3 else signf(steer)
	var left := base.x - w * 0.5
	var top := base.y - h
	_rect(left - 0.05 * w, base.y - 0.1 * h, w * 1.1, 0.16 * h, SHADOW)
	_rect(left, base.y - 0.3 * h, 0.2 * w, 0.3 * h, CAR_TYRE)
	_rect(left + 0.8 * w, base.y - 0.3 * h, 0.2 * w, 0.3 * h, CAR_TYRE)
	_rect(left, top + 0.4 * h, w, 0.45 * h, body)
	var cabin_shift := frame * 0.1 * w
	_rect(left + 0.15 * w + cabin_shift, top, 0.7 * w, 0.42 * h, body.darkened(0.2))
	_rect(left + 0.22 * w + cabin_shift, top + 0.08 * h, 0.56 * w, 0.26 * h, CAR_GLASS)
	_rect(left + 0.06 * w, top + 0.5 * h, 0.16 * w, 0.12 * h, CAR_LIGHT)
	_rect(left + 0.78 * w, top + 0.5 * h, 0.16 * w, 0.12 * h, CAR_LIGHT)


## Integer-snapped rect so scaled sprites stay crisp.
func _rect(x: float, y: float, w: float, h: float, color: Color) -> void:
	var x0 := roundf(x)
	var y0 := roundf(y)
	var rw := maxf(1.0, roundf(x + w) - x0)
	var rh := maxf(1.0, roundf(y + h) - y0)
	draw_rect(Rect2(x0, y0, rw, rh), color)


# --- Debug overlay ---------------------------------------------------------

func _draw_debug(view: Vector2) -> void:
	var p := _projector
	var last_segment := -1
	for i in p.count:
		var c := p.project_point(i, 0.0)
		if c.z <= 0.0:
			continue
		if i % 4 == 0:
			draw_rect(Rect2(c.x - 0.5, c.y - 0.5, 1, 1), DEBUG)
			var l := p.project_point(i, -p.half_width[i])
			var r := p.project_point(i, p.half_width[i])
			draw_rect(Rect2(l.x - 0.5, l.y - 0.5, 1, 1), DEBUG_EDGE)
			draw_rect(Rect2(r.x - 0.5, r.y - 0.5, 1, 1), DEBUG_EDGE)
		if p.segment[i] != last_segment:
			last_segment = p.segment[i]
			draw_line(Vector2(c.x - 6, c.y), Vector2(c.x + 6, c.y), DEBUG)
			_text(Vector2(c.x + 8, c.y), "seg %d z%.0f" % [p.segment[i], p.pos_z[i]], DEBUG)
	# Camera axes at the projection center.
	draw_line(p.center - Vector2(4, 0), p.center + Vector2(4, 0), Color.RED)
	draw_line(p.center - Vector2(0, 4), p.center + Vector2(0, 4), Color.GREEN)

	var track := sim.track
	var car := sim.cars[RaceSimulation.PLAYER]
	var k := track.curvature_at(car.s_m)
	var lines := PackedStringArray([
		"fps %d  tick %d" % [Engine.get_frames_per_second(), sim.tick_count],
		"s %.1f  x %.2f  v %.1f m/s" % [car.s_m, car.x_m, car.speed_mps],
		"seg %d  k %.4f  vmax %s" % [track.segment_index_at(car.s_m), k, _kmh(VehiclePhysics.v_max(k, sim.params))],
		"vmax ahead %s" % _kmh(_v_max_ahead(car.s_m, 200.0)),
		"track %s  L %.0f m" % [track.display_name, track.lap_length_m],
	])
	for li in lines.size():
		_text(Vector2(view.x - 150, 24 + li * 9), lines[li], DEBUG)


func _v_max_ahead(s: float, window_m: float) -> float:
	var best := INF
	var d := 0.0
	while d <= window_m:
		best = minf(best, VehiclePhysics.v_max(sim.track.curvature_at(s + d), sim.params))
		d += 10.0
	return best


func _kmh(mps: float) -> String:
	return "inf" if is_inf(mps) else "%d km/h" % roundi(mps * 3.6)


func _text(pos: Vector2, text: String, color: Color) -> void:
	draw_string(_font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, color)
