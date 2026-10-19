class_name Minimap
extends RefCounted
## Cosmetic track outline (§4). Segments are integrated once into world
## space and any closure error is spread linearly along the loop so the
## outline closes. Never used by physics or AI.

const SAMPLE_M := 5.0
## Outlines narrower than this fraction of the lap fall back to a circle.
const MIN_EXTENT_FRAC := 0.05

## Outline in [0, 1]², aspect preserved and centered; first == last point.
var points := PackedVector2Array()

var _lap_length_m: float


func _init(track: Track) -> void:
	_lap_length_m = track.lap_length_m
	var n := maxi(8, ceili(_lap_length_m / SAMPLE_M))
	points.resize(n + 1)
	var pos := Vector2.ZERO
	points[0] = pos
	for i in n:
		var s0 := _lap_length_m * i / n
		var s1 := _lap_length_m * (i + 1) / n
		var heading := track.heading_at(0.5 * (s0 + s1))
		# Forward is up on screen; positive heading turns right.
		pos += Vector2(sin(heading), -cos(heading)) * (s1 - s0)
		points[i + 1] = pos
	var closure := points[n] - points[0]
	var bounds := Rect2(points[0], Vector2.ZERO)
	for i in n + 1:
		points[i] -= closure * (float(i) / n)
		bounds = bounds.expand(points[i])
	# A loop with no net turning (e.g. a straight test track) collapses to
	# a sliver once closed; draw it as a circle instead.
	if maxf(bounds.size.x, bounds.size.y) < MIN_EXTENT_FRAC * _lap_length_m:
		for i in n + 1:
			var angle := TAU * i / n
			points[i] = Vector2(sin(angle), -cos(angle))
		bounds = Rect2(-Vector2.ONE, Vector2(2.0, 2.0))
	var scale := 1.0 / maxf(bounds.size.x, bounds.size.y)
	var offset := (Vector2.ONE - bounds.size * scale) * 0.5
	for i in n + 1:
		points[i] = (points[i] - bounds.position) * scale + offset


## Outline position of track distance `s_m`, in [0, 1]².
func point_at(s_m: float) -> Vector2:
	var t := fposmod(s_m, _lap_length_m) / _lap_length_m * (points.size() - 1)
	var i := mini(floori(t), points.size() - 2)
	return points[i].lerp(points[i + 1], t - i)
