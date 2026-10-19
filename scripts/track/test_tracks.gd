class_name TestTracks
extends RefCounted
## Code-built tracks for development and the visual test scenes (§5, §12).
## Championship tracks live in resources/tracks/ (see TrackLibrary).

const NAMES := [&"basic", &"straight", &"s_curve", &"hillcrest", &"valley", &"crest_into_curve"]


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
