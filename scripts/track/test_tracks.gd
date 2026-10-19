class_name TestTracks
extends RefCounted
## Code-built tracks for development and the visual test scenes (§5, §12).
## These move to `resources/` as `.tres` once the format settles.

const NAMES := [&"basic", &"gentle", &"hills", &"straight", &"s_curve", &"hillcrest", &"valley",
		&"crest_into_curve"]


static func make(track_name: StringName) -> Track:
	match track_name:
		&"straight":
			return _track("Straight", [_seg(600.0, 0.0, 0.0, &"posts")])
		&"s_curve":
			return _track("S-Curve", [
				_seg(150.0, 0.0, 0.0, &"posts"),
				_seg(160.0, 1.0 / 80.0),
				_seg(160.0, -1.0 / 80.0),
				_seg(150.0, 0.0, 0.0, &"posts"),
			])
		&"hillcrest":
			return _track("Hillcrest", [
				_seg(200.0, 0.0, 0.0, &"posts"),
				_seg(120.0, 0.0, 18.0),
				_seg(120.0, 0.0, -18.0),
				_seg(200.0, 0.0, 0.0, &"posts"),
			])
		&"valley":
			return _track("Valley", [
				_seg(200.0, 0.0, 0.0, &"posts"),
				_seg(110.0, 0.0, -14.0),
				_seg(110.0, 0.0, 14.0),
				_seg(200.0, 0.0, 0.0, &"posts"),
			])
		&"crest_into_curve":
			return _track("Crest into curve", [
				_seg(200.0, 0.0, 0.0, &"posts"),
				_seg(90.0, 0.0, 12.0),
				_seg(110.0, 1.0 / 70.0, -12.0),
				_seg(200.0, 0.0, 0.0, &"posts"),
			])
		&"gentle":
			return _gentle()
		&"hills":
			return _hills()
		_:
			return _basic()


## One straight, one S-curve and one hill, plus a sweeper, a valley and a
## crest into a curve: the first checkpoint track (§14).
static func _basic() -> Track:
	return _track("Test Loop", [
		_seg(200.0, 0.0, 0.0, &"posts"),
		_seg(150.0, 1.0 / 90.0),
		_seg(150.0, -1.0 / 90.0),
		_seg(120.0),
		_seg(100.0, 0.0, 14.0),
		_seg(100.0, 0.0, -14.0),
		_seg(250.0, 1.0 / 160.0),
		_seg(80.0, 0.0, -8.0),
		_seg(80.0, 0.0, 8.0),
		_seg(70.0, 0.0, 9.0),
		_seg(70.0, -1.0 / 70.0, -9.0),
		_seg(200.0, 0.0, 0.0, &"posts"),
	])


## Event 1: wide sweepers and one mild hill. Turns a full 360° (right-hand
## loop) so the minimap closes cleanly.
static func _gentle() -> Track:
	return _track("Green Valley", [
		_seg(450.0, 0.0, 0.0, &"posts"),
		_seg(300.0, 1.0 / 150.0),
		_seg(300.0),
		_seg(250.0, 1.0 / 200.0),
		_seg(120.0, 0.0, 10.0),
		_seg(120.0, 0.0, -10.0),
		_seg(200.0, 1.0 / 120.0),
		_seg(100.0),
		_seg(_closing_length(1.0 / 130.0, [2.0, 1.25, 200.0 / 120.0]), 1.0 / 130.0),
		_seg(80.0, 0.0, 0.0, &"posts"),
	])


## Event 2: hills, S-curves and a crest into a curve; also a full 360°.
static func _hills() -> Track:
	return _track("Ridge Line", [
		_seg(400.0, 0.0, 0.0, &"posts"),
		_seg(100.0, 0.0, 14.0),
		_seg(100.0, 0.0, -14.0),
		_seg(160.0, 1.0 / 80.0),
		_seg(120.0, -1.0 / 80.0),
		_seg(250.0),
		_seg(80.0, 0.0, 10.0),
		_seg(140.0, 1.0 / 70.0, -10.0),
		_seg(80.0, 0.0, -8.0),
		_seg(80.0, 0.0, 8.0),
		_seg(150.0, 1.0 / 100.0),
		_seg(90.0, -1.0 / 90.0),
		_seg(_closing_length(1.0 / 90.0, [2.0, -1.5, 2.0, 1.5, -1.0]), 1.0 / 90.0),
		_seg(100.0, 0.0, 0.0, &"posts"),
	])


## Length of a final curve of `curvature` that brings the heading turned by
## `turns` (radians) up to a full right-hand loop.
static func _closing_length(curvature: float, turns: Array) -> float:
	var turned := 0.0
	for t: float in turns:
		turned += t
	return (TAU - turned) / curvature


static func _track(display_name: String, segs: Array) -> Track:
	var track := Track.new()
	track.display_name = display_name
	for seg: TrackSegment in segs:
		track.segments.append(seg)
	return track


static func _seg(length_m: float, curvature: float = 0.0, elevation_m: float = 0.0,
		scenery: StringName = &"trees") -> TrackSegment:
	var seg := TrackSegment.new()
	seg.length_m = length_m
	seg.curvature_rad_per_m = curvature
	seg.elevation_delta_m = elevation_m
	seg.scenery_id = scenery
	return seg
