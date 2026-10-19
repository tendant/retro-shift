class_name VehiclePhysics
extends RefCounted
## Track-relative arcade vehicle model (§6). Pure functions over state.


## Highest speed at which a car can hold curvature `curvature` (§6):
## steer_max_accel * grip >= |k| * v².
static func v_max(curvature: float, params: VehicleParams, grip_mult: float = 1.0) -> float:
	var k := absf(curvature)
	if k < 1e-6:
		return INF
	return sqrt(params.steer_max_accel_mps2 * params.grip * grip_mult / k)


static func is_off_road(state: VehicleState, track: Track) -> bool:
	return absf(state.x_m) > track.half_width_at(state.s_m)


## Advances one car by `dt`. `top_speed_mult` scales the speed cap (AI
## rubber-banding). Returns true when a nitro boost fired this step.
static func step(state: VehicleState, input: DrivingInput, params: VehicleParams,
		track: Track, dt: float, top_speed_mult: float = 1.0) -> bool:
	var half_width := track.half_width_at(state.s_m)
	var off_road := absf(state.x_m) > half_width

	var fired := false
	if input.nitro_pressed and state.nitro_timer_s <= 0.0 and state.nitro_remaining > 0:
		state.nitro_remaining -= 1
		state.nitro_timer_s = params.nitro_duration_s
		fired = true
	var boost := state.nitro_timer_s > 0.0
	state.nitro_timer_s = maxf(0.0, state.nitro_timer_s - dt)

	# Longitudinal.
	var throttle := clampf(input.throttle, 0.0, 1.0)
	var brake := clampf(input.brake, 0.0, 1.0)
	var speed := state.speed_mps
	var forward_accel := throttle * params.engine_accel_mps2 * (params.nitro_accel_mult if boost else 1.0)
	forward_accel -= brake * params.brake_decel_mps2
	if speed > 0.0:
		forward_accel -= params.rolling_drag_mps2 + params.aero_drag_per_m * speed * speed
		if off_road:
			forward_accel -= params.off_road_drag_mps2
	var cap := params.max_speed_mps * top_speed_mult * (params.nitro_speed_mult if boost else 1.0)
	var new_speed := speed + forward_accel * dt
	if speed <= cap:
		new_speed = minf(new_speed, cap)
	else:
		new_speed = maxf(minf(new_speed, speed - params.overcap_decel_mps2 * dt), cap)
	speed = maxf(new_speed, 0.0)

	# Lateral: the road bends under a forward-moving car, pushing it outward.
	var grip := params.grip * (params.off_road_grip_mult if off_road else 1.0)
	var authority := clampf(speed / params.steer_full_authority_speed_mps, 0.0, 1.0)
	var steer_accel := clampf(input.steer, -1.0, 1.0) * params.steer_max_accel_mps2 * authority * grip
	var curve_accel := -track.curvature_at(state.s_m) * speed * speed
	var lateral_accel := steer_accel + curve_accel - params.lateral_damping_per_s * state.lateral_speed_mps
	var lat_cap := params.lateral_speed_cap_mps
	state.lateral_speed_mps = clampf(state.lateral_speed_mps + lateral_accel * dt, -lat_cap, lat_cap)

	state.x_m += state.lateral_speed_mps * dt
	var x_limit := half_width + params.off_road_limit_m
	if absf(state.x_m) > x_limit:
		state.x_m = signf(state.x_m) * x_limit
		state.lateral_speed_mps = 0.0
	state.speed_mps = speed
	state.s_m += speed * dt
	return fired
