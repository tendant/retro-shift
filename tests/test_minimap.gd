extends GutTest


func test_outline_is_closed_and_normalized() -> void:
	for track_name: StringName in TestTracks.NAMES:
		var track := TestTracks.make(track_name)
		track.build()
		var minimap := Minimap.new(track)
		var pts := minimap.points
		assert_almost_eq(pts[0].distance_to(pts[pts.size() - 1]), 0.0, 1e-6, String(track_name))
		for p in pts:
			assert_true(p.x >= -1e-6 and p.x <= 1.0 + 1e-6 and p.y >= -1e-6 and p.y <= 1.0 + 1e-6)
		assert_almost_eq(minimap.point_at(0.0).distance_to(minimap.point_at(track.lap_length_m)), 0.0, 1e-6)
