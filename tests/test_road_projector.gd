extends GutTest

const VIEW := Vector2(320, 240)
const FOV := deg_to_rad(50.0)


func _projector(track_name: StringName, s_cam: float, cam_x: float = 0.0) -> Array:
	var track := TestTracks.make(track_name)
	track.build()
	var p := RoadProjector.new(240, 3.0)
	p.build(track, s_cam, cam_x, 2.2, VIEW, FOV)
	return [p, track]


func test_straight_road_stays_centered() -> void:
	var p: RoadProjector = _projector(&"straight", 10.0)[0]
	for i in p.count:
		assert_almost_eq(p.pos_x[i], 0.0, 1e-9)
		assert_almost_eq(p.pos_y[i], -2.2, 1e-9)
		var c := p.project_point(i, 0.0)
		assert_almost_eq(c.x, VIEW.x * 0.5, 1e-6)
	for i in range(1, p.count):
		assert_gt(p.pos_z[i], p.pos_z[i - 1])


func test_points_lie_on_world_grid() -> void:
	var p: RoadProjector = _projector(&"basic", 123.4)[0]
	assert_almost_eq(p.s_m[0], 124.4, 1e-9)
	for i in range(1, p.count):
		assert_almost_eq(fposmod(p.s_m[i], 3.0), 0.0, 1e-6)
		assert_almost_eq(p.s_m[i] - p.s_m[i - 1], 3.0 if i > 1 else 1.0 + 0.6, 1e-6)


func test_right_curve_bends_right_on_screen() -> void:
	# The s_curve track's first curve (positive curvature) starts at 150 m.
	var p: RoadProjector = _projector(&"s_curve", 140.0)[0]
	var i := p.strip_at(250.0)
	assert_gt(p.pos_x[i], 0.0)
	assert_gt(p.project_point(i, 0.0).x, VIEW.x * 0.5)


func test_camera_offset_shifts_road_opposite() -> void:
	var p: RoadProjector = _projector(&"straight", 10.0, 2.0)[0]
	assert_lt(p.project_point(10, 0.0).x, VIEW.x * 0.5)


func test_no_seam_across_lap_wrap() -> void:
	# Open loop: the basic track's net heading and elevation are non-zero.
	var result := _projector(&"basic", 0.0)
	var track: Track = result[1]
	var p: RoadProjector = _projector(&"basic", track.lap_length_m - 100.0)[0]
	assert_true(p.s_m[0] < track.lap_length_m and p.s_m[p.count - 1] > track.lap_length_m)
	for i in range(1, p.count):
		var ds := p.s_m[i] - p.s_m[i - 1]
		assert_lt(absf(p.pos_y[i] - p.pos_y[i - 1]), ds * Track.MAX_ABS_GRADE * 1.5)
		assert_lt(absf(p.heading[i] - p.heading[i - 1]), ds * Track.MAX_ABS_CURVATURE + 1e-9)


func test_road_beyond_crest_projects_below_the_crest_line() -> void:
	# Hillcrest: up 18 m over 200..320, down over 320..440. Camera on the climb.
	var p: RoadProjector = _projector(&"hillcrest", 230.0)[0]
	var crest := p.strip_at(320.0)
	var beyond := p.strip_at(380.0)
	var crest_y := p.project_point(crest, 0.0).y
	var beyond_y := p.project_point(beyond, 0.0).y
	assert_gt(beyond_y, crest_y, "road past the crest is hidden behind it")


func test_strip_lookup() -> void:
	var p: RoadProjector = _projector(&"straight", 10.0)[0]
	assert_eq(p.strip_at(p.s_m[0] - 0.01), -1)
	assert_eq(p.strip_at(p.s_m[0]), 0)
	assert_eq(p.strip_at(p.s_m[1]), 1)
	assert_eq(p.strip_at(p.s_m[5] + 0.5), 5)
	assert_eq(p.strip_at(p.s_m[p.count - 1]), -1)
