class_name AutopilotInput
extends RefCounted
## Drives a car along the centerline at a safe fraction of v_max (§7 target
## speed). Used for `--autodrive` visual checks and as the AI starting point.

const LOOK_AHEAD_M := 150.0
const SAMPLE_STEP_M := 10.0
const SPEED_MARGIN := 0.9
const STEER_GAIN_PER_M := 0.35
const STEER_DAMPING_S := 0.25

var sim: RaceSimulation
var car: int
var target_lane_m: float = 0.0


func _init(p_sim: RaceSimulation, p_car: int = RaceSimulation.PLAYER) -> void:
	sim = p_sim
	car = p_car


func read(into: DrivingInput, _dt: float) -> void:
	var state := sim.cars[car]
	var track := sim.track
	var params := sim.params

	var target_speed := params.max_speed_mps
	var d := 0.0
	while d <= LOOK_AHEAD_M:
		target_speed = minf(target_speed,
				VehiclePhysics.v_max(track.curvature_at(state.s_m + d), params) * SPEED_MARGIN)
		d += SAMPLE_STEP_M
	into.throttle = 1.0 if state.speed_mps < target_speed else 0.0
	into.brake = 1.0 if state.speed_mps > target_speed + 3.0 else 0.0

	# Feed-forward against the curve push, plus PD toward the target lane.
	var k := track.curvature_at(state.s_m)
	var feed_forward := k * state.speed_mps * state.speed_mps / params.steer_max_accel_mps2
	var error := target_lane_m - state.x_m
	into.steer = clampf(feed_forward + STEER_GAIN_PER_M * error
			- STEER_DAMPING_S * state.lateral_speed_mps, -1.0, 1.0)
	into.nitro_pressed = false
