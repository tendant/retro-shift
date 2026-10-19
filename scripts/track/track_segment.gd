class_name TrackSegment
extends Resource

@export var length_m: float = 20.0
# Signed heading change per meter (radians / meter). Positive = curves right.
@export var curvature_rad_per_m: float = 0.0
# Height difference from segment start to end (meters).
@export var elevation_delta_m: float = 0.0
@export var road_half_width_m: float = 5.0
@export var scenery_id: StringName
