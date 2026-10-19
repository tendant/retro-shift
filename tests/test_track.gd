extends GutTest


func _seg(length_m: float, curvature: float = 0.0, elevation_m: float = 0.0) -> TrackSegment:
	var seg := TrackSegment.new()
	seg.length_m = length_m
	seg.curvature_rad_per_m = curvature
	seg.elevation_delta_m = elevation_m
	return seg


func _track(segs: Array) -> Track:
	var track := Track.new()
	for seg: TrackSegment in segs:
		track.segments.append(seg)
	assert_eq(track.build().size(), 0, "track should build")
	return track


func test_validation_rejects_bad_segments() -> void:
	var cases := {
		"zero length": _seg(0.0),
		"nan curvature": _seg(10.0, NAN),
		"curvature too sharp": _seg(10.0, 0.2),
		"grade too steep": _seg(10.0, 0.0, 8.0),
	}
	var narrow := _seg(10.0)
	narrow.road_half_width_m = -1.0
	cases["negative width"] = narrow
	for label: String in cases:
		var track := Track.new()
		track.segments.append(cases[label])
		assert_gt(track.validate().size(), 0, label)


func test_validation_rejects_empty_track() -> void:
	assert_gt(Track.new().validate().size(), 0)


func test_lookup_at_boundaries() -> void:
	var track := _track([_seg(100.0), _seg(50.0, 0.01), _seg(25.0)])
	assert_almost_eq(track.lap_length_m, 175.0, 1e-9)
	assert_eq(track.segment_index_at(0.0), 0)
	assert_eq(track.segment_index_at(99.999), 0)
	assert_eq(track.segment_index_at(100.0), 1)
	assert_eq(track.segment_index_at(149.999), 1)
	assert_eq(track.segment_index_at(150.0), 2)
	assert_eq(track.segment_index_at(174.999), 2)


func test_lookup_wraps_both_directions() -> void:
	var track := _track([_seg(100.0), _seg(50.0, 0.01), _seg(25.0)])
	assert_eq(track.segment_index_at(175.0), 0)
	assert_eq(track.segment_index_at(175.0 * 3 + 120.0), 1)
	assert_eq(track.segment_index_at(-1.0), 2)
	assert_eq(track.segment_index_at(-30.0), 1)


func test_heading_and_height_continuous_across_wrap() -> void:
	# Deliberately not closed: net heading and net elevation are non-zero.
	var track := _track([_seg(200.0, 0.004, 6.0), _seg(150.0, -0.002, 3.0)])
	var L := track.lap_length_m
	for lap in [0.0, 1.0, 2.0, -1.0]:
		var s: float = (lap + 1.0) * L
		assert_almost_eq(track.heading_at(s - 1e-6), track.heading_at(s + 1e-6), 1e-5)
		assert_almost_eq(track.height_at(s - 1e-6), track.height_at(s + 1e-6), 1e-5)


func test_height_and_grade_continuous_at_segment_boundaries() -> void:
	var track := _track([_seg(100.0), _seg(80.0, 0.0, 12.0), _seg(80.0, 0.0, -12.0), _seg(100.0)])
	for boundary in [100.0, 180.0, 260.0]:
		assert_almost_eq(track.height_at(boundary - 1e-6), track.height_at(boundary + 1e-6), 1e-5)
		assert_almost_eq(track.grade_at(boundary - 1e-6), track.grade_at(boundary + 1e-6), 1e-4)
	assert_almost_eq(track.height_at(180.0), 12.0, 1e-9, "segment end heights are exact")


func test_grade_matches_height_derivative() -> void:
	var track := _track([_seg(100.0), _seg(80.0, 0.0, 12.0), _seg(80.0, 0.0, -12.0)])
	for s in [20.0, 110.0, 150.0, 200.0, 250.0]:
		var numeric := (track.height_at(s + 0.01) - track.height_at(s - 0.01)) / 0.02
		assert_almost_eq(track.grade_at(s), numeric, 1e-4)


func test_all_tracks_build() -> void:
	for track_name in TrackLibrary.names():
		var track := TrackLibrary.make(track_name)
		assert_eq(track.build(), PackedStringArray(), String(track_name))
