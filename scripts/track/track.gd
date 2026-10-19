class_name Track
extends Resource
## A race loop built from TrackSegments (§4).
##
## Every query takes an unwrapped distance `s_m`. Heading and height are
## continuous across lap boundaries even when the loop does not close
## geometrically: each lap adds the net heading/elevation of one lap.

const MAX_ABS_CURVATURE := 0.05  # radius >= 20 m
const MAX_ABS_GRADE := 0.4

@export var display_name: String = ""
@export var laps: int = 3
@export var segments: Array[TrackSegment] = []

var lap_length_m: float = 0.0
var net_heading_rad: float = 0.0
var net_elevation_m: float = 0.0

var _starts := PackedFloat64Array()
var _heading_starts := PackedFloat64Array()
var _height_starts := PackedFloat64Array()
# Height slope (dh/ds) at each segment start; shared with the previous
# segment's end so grade changes ease in and out instead of kinking.
var _grade_tangents := PackedFloat64Array()


## Validates the segments and precomputes lookup tables. Returns the
## validation errors; the track is usable only when the list is empty.
func build() -> PackedStringArray:
	var errors := validate()
	if not errors.is_empty():
		return errors

	var n := segments.size()
	_starts.resize(n)
	_heading_starts.resize(n)
	_height_starts.resize(n)
	_grade_tangents.resize(n)
	var s := 0.0
	var heading := 0.0
	var height := 0.0
	for i in n:
		var seg := segments[i]
		_starts[i] = s
		_heading_starts[i] = heading
		_height_starts[i] = height
		s += seg.length_m
		heading += seg.curvature_rad_per_m * seg.length_m
		height += seg.elevation_delta_m
	lap_length_m = s
	net_heading_rad = heading
	net_elevation_m = height

	for i in n:
		var prev := segments[posmod(i - 1, n)]
		_grade_tangents[i] = 0.5 * (_grade(prev) + _grade(segments[i]))
	return errors


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if segments.is_empty():
		errors.append("track has no segments")
	if laps < 1:
		errors.append("laps must be >= 1 (got %d)" % laps)
	for i in segments.size():
		var seg := segments[i]
		if seg == null:
			errors.append("segment %d is null" % i)
			continue
		if not is_finite(seg.length_m) or seg.length_m <= 0.0:
			errors.append("segment %d: length must be positive and finite" % i)
			continue
		if not is_finite(seg.road_half_width_m) or seg.road_half_width_m <= 0.0:
			errors.append("segment %d: road half-width must be positive and finite" % i)
		if not is_finite(seg.curvature_rad_per_m) or absf(seg.curvature_rad_per_m) > MAX_ABS_CURVATURE:
			errors.append("segment %d: curvature must be finite and within ±%s" % [i, MAX_ABS_CURVATURE])
		if not is_finite(seg.elevation_delta_m) or absf(_grade(seg)) > MAX_ABS_GRADE:
			errors.append("segment %d: elevation must be finite with grade within ±%s" % [i, MAX_ABS_GRADE])
	return errors


func wrap_s(s_m: float) -> float:
	return fposmod(s_m, lap_length_m)


func segment_index_at(s_m: float) -> int:
	var i := _starts.bsearch(wrap_s(s_m), false) - 1
	return clampi(i, 0, segments.size() - 1)


func segment_at(s_m: float) -> TrackSegment:
	return segments[segment_index_at(s_m)]


func curvature_at(s_m: float) -> float:
	return segment_at(s_m).curvature_rad_per_m


func half_width_at(s_m: float) -> float:
	return segment_at(s_m).road_half_width_m


func heading_at(s_m: float) -> float:
	var lap := floorf(s_m / lap_length_m)
	var sw := s_m - lap * lap_length_m
	var i := segment_index_at(sw)
	var local := sw - _starts[i]
	return lap * net_heading_rad + _heading_starts[i] + segments[i].curvature_rad_per_m * local


func height_at(s_m: float) -> float:
	var lap := floorf(s_m / lap_length_m)
	var sw := s_m - lap * lap_length_m
	var i := segment_index_at(sw)
	var seg := segments[i]
	var t := (sw - _starts[i]) / seg.length_m
	var m0 := _grade_tangents[i] * seg.length_m
	var m1 := _grade_tangents[(i + 1) % segments.size()] * seg.length_m
	var t2 := t * t
	var t3 := t2 * t
	# Cubic Hermite between the segment's end heights.
	var h := (
		(3.0 * t2 - 2.0 * t3) * seg.elevation_delta_m
		+ (t3 - 2.0 * t2 + t) * m0
		+ (t3 - t2) * m1
	)
	return lap * net_elevation_m + _height_starts[i] + h


func grade_at(s_m: float) -> float:
	var sw := wrap_s(s_m)
	var i := segment_index_at(sw)
	var seg := segments[i]
	var t := (sw - _starts[i]) / seg.length_m
	var m0 := _grade_tangents[i] * seg.length_m
	var m1 := _grade_tangents[(i + 1) % segments.size()] * seg.length_m
	var t2 := t * t
	var dh_dt := (
		(6.0 * t - 6.0 * t2) * seg.elevation_delta_m
		+ (3.0 * t2 - 4.0 * t + 1.0) * m0
		+ (3.0 * t2 - 2.0 * t) * m1
	)
	return dh_dt / seg.length_m


func segment_start_s(index: int) -> float:
	return _starts[index]


static func _grade(seg: TrackSegment) -> float:
	return seg.elevation_delta_m / seg.length_m
