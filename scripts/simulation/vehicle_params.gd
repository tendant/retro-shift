class_name VehicleParams
extends Resource
## Per-car tuning (§6). Upgrades scale these at race start, never live state.

@export_group("Longitudinal")
@export var max_speed_mps: float = 75.0
@export var engine_accel_mps2: float = 14.0
@export var brake_decel_mps2: float = 28.0
@export var rolling_drag_mps2: float = 0.6
## Aero drag deceleration = aero_drag_per_m * speed².
@export var aero_drag_per_m: float = 0.0012
## How fast speed decays back to the cap after a boost ends.
@export var overcap_decel_mps2: float = 6.0

@export_group("Lateral")
## Cornering grip budget (m/s²): full steer holds a curve while
## |k|·v² <= steer_max_accel * grip, which defines v_max(k) (§6).
@export var steer_max_accel_mps2: float = 20.0
## Sideways speed at full steer. With steer_response_s this sets how snappy
## steering feels, independently of the cornering limit.
@export var steer_lateral_speed_mps: float = 8.0
## Time constant for sideways speed to reach its target.
@export var steer_response_s: float = 0.07
## Below this speed steering authority ramps down, so a parked car can't slide.
@export var steer_full_authority_speed_mps: float = 8.0
@export var grip: float = 1.0
@export var lateral_speed_cap_mps: float = 18.0

@export_group("Off-road")
@export var off_road_drag_mps2: float = 14.0
@export var off_road_grip_mult: float = 0.55
## How far past the road edge a car can go before hitting the soft wall.
@export var off_road_limit_m: float = 7.0

@export_group("Nitro")
@export var nitro_count: int = 3
@export var nitro_duration_s: float = 3.0
@export var nitro_accel_mult: float = 2.0
@export var nitro_speed_mult: float = 1.2

@export_group("Body")
@export var car_half_width_m: float = 0.9
