class_name RoadRenderer
extends Node2D
## Pseudo-3D road renderer (§5).
##
## One far-to-near pass: for each strip, a full-width terrain band, then
## rumble/road/lane, then the sprites standing on that strip. Nearer strips
## paint over whatever lies beyond a crest, so no clipping buffer is needed.
## Reads only the interpolated snapshot; never advances the simulation.

const SKY_TOP := Color8(48, 88, 192)
const SKY_HORIZON := Color8(168, 204, 244)
const SKY_BANDS := 8
const GRASS := [Color8(64, 156, 64), Color8(54, 140, 56)]
const RUMBLE := [Color8(236, 236, 236), Color8(206, 44, 44)]
const ROAD := [Color8(108, 108, 118), Color8(100, 100, 110)]
const LANE := Color8(240, 240, 240)
const FLAME := [Color8(255, 236, 140), Color8(255, 150, 40), Color8(120, 200, 255)]
const DEBUG := Color8(255, 240, 0)
const DEBUG_EDGE := Color8(0, 255, 255)

## World width of the car sprite (48 px, including shadow).
const CAR_WIDTH_M := 2.0
## Scenery texel density: 8 px per meter (a 32 px pine is 4 m wide).
const SCENERY_PX_PER_M := 8.0
const RUMBLE_WIDTH_FRAC := 0.12
const TREE_KINDS := [&"pine_a", &"pine_a", &"pine_b", &"pine_b", &"pine_a", &"bush", &"bush", &"rock"]
const BILLBOARDS := [&"billboard_retroshift", &"billboard_nitro", &"billboard_upgrade"]
## Chevron signs mark curves at least this tight.
const CHEVRON_MIN_CURVATURE := 1.0 / 130.0
const CHEVRON_SPACING_M := 15.0
const GANTRY_HEIGHT_M := 7.0
## Sprites wider than this many view widths are skipped. Huge draw rects
## from items brushing past the camera distort the whole frame.
const MAX_SPRITE_VIEW_WIDTHS := 4.0
const LANE_HALF_WIDTH_M := 0.12

@export var steps: int = 240
@export var step_len_m: float = 3.0
@export var cam_height_m: float = 2.2
@export var cam_back_offset_m: float = 6.0
@export var vertical_fov_deg: float = 50.0
## Exponential follow rate (1/s) of the camera's lateral position.
@export var cam_lateral_follow_rate: float = 10.0
@export var stripe_len_m: float = 6.0
@export var scenery_spacing_m: float = 12.0
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
var _car_boost := PackedByteArray()
var _car_strip := PackedInt32Array()
# Scratch buffers reused for every primitive to avoid per-frame allocation.
var _quad := PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO])
var _color := PackedColorArray([Color.WHITE])
var _no_uvs := PackedVector2Array()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_projector = RoadProjector.new(steps, step_len_m)
	_font = Game.FONT


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
	var lap_length := sim.track.lap_length_m
	for i in _car_s.size():
		# Opponents a lap ahead/behind are still physically right here.
		if i != RaceSimulation.PLAYER:
			_car_s[i] = s_cam + fposmod(_car_s[i] - s_cam, lap_length)
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
		_car_boost.resize(n)
		_car_strip.resize(n)
	for i in n:
		_car_s[i] = lerpf(prev.s_m[i], curr.s_m[i], alpha)
		_car_x[i] = lerpf(prev.x_m[i], curr.x_m[i], alpha)
		_car_steer[i] = curr.steer[i]
		_car_boost[i] = curr.nitro_active[i]


func _draw() -> void:
	if sim == null or sim.track == null or _car_s.is_empty():
		return
	var view := get_viewport_rect().size
	_draw_background(view)
	for i in range(_projector.count - 2, -1, -1):
		if _draw_strip(i, view):
			_draw_scenery_on_strip(i)
		# Cars are drawn even on hidden strips; nearer strips paint over them.
		_draw_cars_on_strip(i)
	if debug_enabled:
		_draw_debug()


func _draw_background(view: Vector2) -> void:
	var horizon := _projector.center.y
	var band_h := ceilf(horizon / SKY_BANDS)
	for b in SKY_BANDS:
		var color := SKY_TOP.lerp(SKY_HORIZON, float(b) / (SKY_BANDS - 1))
		draw_rect(Rect2(0, b * band_h, view.x, band_h), color)
	_draw_layer(SpriteAtlas.BG_CLOUDS, view, horizon - 70.0, 0.3)
	_draw_layer(SpriteAtlas.BG_MOUNTAINS, view, horizon + 1.0, 0.5)
	_draw_layer(SpriteAtlas.BG_HILLS, view, horizon + 1.0, 1.0)
	draw_rect(Rect2(0, horizon, view.x, view.y - horizon), GRASS[1])


## Tiles a parallax strip whose bottom sits at `bottom_y`; `depth` < 1
## scrolls slower with the camera heading.
func _draw_layer(texture: Texture2D, view: Vector2, bottom_y: float, depth: float) -> void:
	var w := float(texture.get_width())
	var x := fposmod(-_projector.cam_heading * parallax_px_per_rad * depth, w) - w
	var y := roundf(bottom_y - texture.get_height())
	while x < view.x:
		draw_texture(texture, Vector2(roundf(x), y))
		x += w


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
	var s0 := p.s_m[i]
	var s1 := p.s_m[i + 1]
	var track := sim.track
	var lap := track.lap_length_m

	# Start/finish gantry spanning the road.
	var line_s := ceilf(s0 / lap) * lap
	if line_s < s1:
		_draw_gantry(line_s, track.half_width_at(line_s))

	# Chevrons on the outside of tight curves, pointing where the road goes.
	var n := ceili(s0 / CHEVRON_SPACING_M)
	while n * CHEVRON_SPACING_M < s1:
		var s := n * CHEVRON_SPACING_M
		var k := track.curvature_at(s)
		if absf(k) >= CHEVRON_MIN_CURVATURE:
			var outside := -signf(k)
			var rumble := track.half_width_at(s) * (1.0 + RUMBLE_WIDTH_FRAC)
			var sign_name: StringName = &"chevron_right" if k > 0.0 else &"chevron_left"
			_draw_scenery(sign_name, p.project_on_road(s, outside * (rumble + 1.2)))
		n += 1

	# Roadside dressing by segment theme.
	n = ceili(s0 / scenery_spacing_m)
	while n * scenery_spacing_m < s1:
		var s := n * scenery_spacing_m
		var seg := track.segment_at(s)
		var rumble := seg.road_half_width_m * (1.0 + RUMBLE_WIDTH_FRAC)
		var h := _hash(n)
		var side := 1.0 if posmod(n, 2) == 0 else -1.0
		match seg.scenery_id:
			&"trees":
				var kind: StringName = TREE_KINDS[h % TREE_KINDS.size()]
				var lateral := side * (rumble + 3.0 + float(h % 7))
				_draw_scenery(kind, p.project_on_road(s, lateral))
			&"posts":
				if posmod(n, 2) == 0:
					_draw_scenery(&"post", p.project_on_road(s, rumble + 0.8))
					_draw_scenery(&"post", p.project_on_road(s, -rumble - 0.8))
				if posmod(n, 9) == 3:
					var board: StringName = BILLBOARDS[h % BILLBOARDS.size()]
					_draw_scenery(board, p.project_on_road(s, side * (rumble + 7.0)))
		n += 1


func _draw_gantry(s: float, half_width: float) -> void:
	var p := _projector
	var reach := half_width * (1.0 + RUMBLE_WIDTH_FRAC) + 0.6
	var left := p.project_on_road(s, -reach)
	var right := p.project_on_road(s, reach)
	if left.z <= 0.0 or right.z <= 0.0:
		return
	_draw_scenery(&"gantry_pillar", left)
	_draw_scenery(&"gantry_pillar", right)
	var banner: Rect2 = SpriteAtlas.SCENERY_RECTS[&"gantry_banner"]
	var top := left.y - GANTRY_HEIGHT_M * left.z
	var height := banner.size.y / SCENERY_PX_PER_M * left.z
	var x0 := roundf(left.x)
	var y0 := roundf(top)
	draw_texture_rect_region(SpriteAtlas.SCENERY, Rect2(x0, y0, roundf(right.x) - x0,
			maxf(1.0, roundf(top + height) - y0)), banner)


func _draw_scenery(sprite: StringName, base: Vector3) -> void:
	if base.z <= 0.0:
		return
	var region: Rect2 = SpriteAtlas.SCENERY_RECTS[sprite]
	_sprite(SpriteAtlas.SCENERY, region, base, region.size.x / SCENERY_PX_PER_M)


## Draws cars standing on strip `i`, farthest first.
func _draw_cars_on_strip(i: int) -> void:
	var drawn_s := INF
	while true:
		var next := -1
		for car in _car_strip.size():
			if _car_strip[car] == i and _car_s[car] < drawn_s and (next < 0 or _car_s[car] > _car_s[next]):
				next = car
		if next < 0:
			return
		drawn_s = _car_s[next]
		var base := _projector.project_on_road(_car_s[next], _car_x[next])
		if base.z > 0.0:
			var color_row := 0 if next == RaceSimulation.PLAYER else 1 + (next - 1) % (SpriteAtlas.CAR_COLORS - 1)
			_draw_car(base, _car_steer[next], color_row, _car_boost[next] != 0)


## Rear view with hard-left/left/center/right/hard-right frames (§5).
func _draw_car(base: Vector3, steer: float, color_row: int, boosting: bool) -> void:
	var frame := 2
	if absf(steer) > 0.7:
		frame = 2 + 2 * int(signf(steer))
	elif absf(steer) > 0.25:
		frame = 2 + int(signf(steer))
	var rect := _sprite(SpriteAtlas.CARS, SpriteAtlas.car_rect(color_row, frame), base, CAR_WIDTH_M)
	if boosting and rect.size.x >= 8.0:
		_draw_flames(rect)


## Flickering exhaust flames under the bumper while a nitro boost runs.
func _draw_flames(car_rect: Rect2) -> void:
	var px := car_rect.size.x / SpriteAtlas.CAR_SIZE.x
	var flicker := (sim.tick_count / 3) % 2
	for exhaust_x: float in [15.5, 32.5]:
		var cx := car_rect.position.x + exhaust_x * px
		var cy := car_rect.position.y + 22.0 * px
		var r := (2.0 + flicker) * px
		draw_rect(Rect2(roundf(cx - r), roundf(cy - r * 0.6), roundf(2 * r), roundf(r * 1.4)), FLAME[2])
		draw_rect(Rect2(roundf(cx - r * 0.6), roundf(cy - r * 0.4), roundf(1.2 * r), roundf(r)), FLAME[1])
		draw_rect(Rect2(roundf(cx - r * 0.3), roundf(cy - r * 0.2), maxf(1.0, roundf(0.6 * r)),
				maxf(1.0, roundf(r * 0.5))), FLAME[0])


## Draws `region` of `texture` standing on `base` (bottom-center), `width_m`
## wide in the world, with integer-snapped edges. Returns the screen rect.
func _sprite(texture: Texture2D, region: Rect2, base: Vector3, width_m: float) -> Rect2:
	var w := width_m * base.z
	# Too small to see, or so close it's effectively at the camera.
	if w < 1.0 or w > MAX_SPRITE_VIEW_WIDTHS * get_viewport_rect().size.x:
		return Rect2()
	var h := w * region.size.y / region.size.x
	var x0 := roundf(base.x - w * 0.5)
	var y0 := roundf(base.y - h)
	var rect := Rect2(x0, y0, maxf(1.0, roundf(base.x + w * 0.5) - x0), maxf(1.0, roundf(base.y) - y0))
	draw_texture_rect_region(texture, rect, region)
	return rect


## Cheap deterministic hash so scenery choices are stable per position.
static func _hash(n: int) -> int:
	return absi((n * 73856093) ^ ((n * 19349663) >> 3)) % 1000003


# --- Debug overlay ---------------------------------------------------------

func _draw_debug() -> void:
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
		"seg %d  k %.4f  vmax %s" % [track.segment_index_at(car.s_m), k, _kmh(VehiclePhysics.v_max(k, sim.car_params[RaceSimulation.PLAYER]))],
		"vmax ahead %s" % _kmh(_v_max_ahead(car.s_m, 200.0)),
		"track %s  L %.0f m" % [track.display_name, track.lap_length_m],
	])
	for li in lines.size():
		_text(Vector2(6, 64 + li * 9), lines[li], DEBUG)


func _v_max_ahead(s: float, window_m: float) -> float:
	var best := INF
	var d := 0.0
	while d <= window_m:
		best = minf(best, VehiclePhysics.v_max(sim.track.curvature_at(s + d), sim.car_params[RaceSimulation.PLAYER]))
		d += 10.0
	return best


func _kmh(mps: float) -> String:
	return "inf" if is_inf(mps) else "%d km/h" % roundi(mps * 3.6)


func _text(pos: Vector2, text: String, color: Color) -> void:
	draw_string(_font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, color)
