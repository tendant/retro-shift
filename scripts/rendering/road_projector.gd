class_name RoadProjector
extends RefCounted
## Camera-relative road integration and projection (§5).
##
## Each frame the road is rebuilt forward from the camera: point 0 sits just
## ahead of the camera and the rest land on a fixed world grid of `step_len_m`
## so stripes don't swim. Positions are in camera space (x right, y up,
## z forward) before the camera's lateral offset is applied.

## Point 0 starts this far ahead of the camera, past the near clip.
const NEAR_START_M := 1.0

var step_len_m: float
var near_clip_m: float = 0.3
var count: int = 0

var s_m := PackedFloat64Array()
var pos_x := PackedFloat64Array()
var pos_y := PackedFloat64Array()
var pos_z := PackedFloat64Array()
var heading := PackedFloat64Array()
var half_width := PackedFloat64Array()
var segment := PackedInt32Array()

var focal: float = 1.0
var center := Vector2.ZERO
var cam_x: float = 0.0
## Absolute (unwrapped) track heading at the camera; drives sky parallax.
var cam_heading: float = 0.0


func _init(max_points: int = 240, p_step_len_m: float = 3.0) -> void:
	step_len_m = p_step_len_m
	count = max_points
	s_m.resize(max_points)
	pos_x.resize(max_points)
	pos_y.resize(max_points)
	pos_z.resize(max_points)
	heading.resize(max_points)
	half_width.resize(max_points)
	segment.resize(max_points)


func build(track: Track, s_cam: float, p_cam_x: float, cam_height_m: float,
		view_size: Vector2, vertical_fov_rad: float) -> void:
	focal = (view_size.y * 0.5) / tan(vertical_fov_rad * 0.5)
	center = view_size * 0.5
	cam_x = p_cam_x
	cam_heading = track.heading_at(s_cam)
	var cam_road_height := track.height_at(s_cam)

	var first := s_cam + NEAR_START_M
	var first_grid := (floorf(first / step_len_m) + 1.0) * step_len_m
	var x := 0.0
	var z := 0.0
	var prev_s := s_cam
	for i in count:
		var s := first if i == 0 else first_grid + (i - 1) * step_len_m
		# Midpoint heading integrates each step's arc exactly enough.
		var mid_heading := track.heading_at(0.5 * (prev_s + s)) - cam_heading
		var ds := s - prev_s
		x += sin(mid_heading) * ds
		z += cos(mid_heading) * ds
		s_m[i] = s
		pos_x[i] = x
		pos_z[i] = z
		pos_y[i] = track.height_at(s) - cam_road_height - cam_height_m
		heading[i] = track.heading_at(s) - cam_heading
		half_width[i] = track.half_width_at(s)
		segment[i] = track.segment_index_at(s)
		prev_s = s


## Projects camera-space (x, y, z). Returns (screen_x, screen_y, px_per_m);
## px_per_m <= 0 means the point is behind the near clip.
func project(x: float, y: float, z: float) -> Vector3:
	if z < near_clip_m:
		return Vector3(0.0, 0.0, -1.0)
	var scale := focal / z
	return Vector3(center.x + x * scale, center.y - y * scale, scale)


## Projects the road point `i` offset by `lateral` meters (positive = right)
## and raised by `height` meters.
##
## Lateral offsets stay at the centerline's depth, so every strip is
## horizontal on screen. Rotating edges by heading tilts strips on curves and
## lets a nearer strip's full-width terrain band cut into farther road.
func project_point(i: int, lateral: float, height: float = 0.0) -> Vector3:
	return project(pos_x[i] + lateral - cam_x, pos_y[i] + height, pos_z[i])


## Index of the strip [i, i + 1] containing `s`, or -1 if `s` isn't visible.
func strip_at(s: float) -> int:
	if count < 2 or s < s_m[0] or s >= s_m[count - 1]:
		return -1
	if s < s_m[1]:
		return 0
	return mini(floori((s - s_m[1]) / step_len_m) + 1, count - 2)


## Projects an arbitrary track position (s, lateral) inside the visible range.
func project_on_road(s: float, lateral: float, height: float = 0.0) -> Vector3:
	var i := strip_at(s)
	if i < 0:
		return Vector3(0.0, 0.0, -1.0)
	var t := (s - s_m[i]) / (s_m[i + 1] - s_m[i])
	return project(
		lerpf(pos_x[i], pos_x[i + 1], t) + lateral - cam_x,
		lerpf(pos_y[i], pos_y[i + 1], t) + height,
		lerpf(pos_z[i], pos_z[i + 1], t))
