class_name Upgrades
extends RefCounted
## The four permanent upgrade lines (§8). Values are initial tuning.

const MAX_LEVEL := 3
const LINES: Array[StringName] = [&"engine", &"gearbox", &"tires", &"nitro"]

const DISPLAY_NAMES := {
	&"engine": "Engine",
	&"gearbox": "Gearbox",
	&"tires": "Tires",
	&"nitro": "Nitro",
}
## Price of levels 1..3.
const PRICES := {
	&"engine": [200, 450, 800],
	&"gearbox": [200, 450, 800],
	&"tires": [150, 350, 650],
	&"nitro": [150, 350, 650],
}
## Bonus at levels 0..3.
const ENGINE_ACCEL_BONUS := [0.0, 0.10, 0.20, 0.35]
const GEARBOX_SPEED_BONUS := [0.0, 0.05, 0.12, 0.20]
const TIRES_GRIP_BONUS := [0.0, 0.08, 0.16, 0.25]
const NITRO_COUNT := [3, 4, 5, 6]
## Nitro level 3 also makes each boost 10% stronger.
const NITRO_L3_STRENGTH := 1.10


## Price of the next level, or -1 when the line is maxed.
static func next_price(line: StringName, level: int) -> int:
	if level >= MAX_LEVEL:
		return -1
	return PRICES[line][level]


## Short description of what `level` gives, e.g. "+20% accel".
static func describe(line: StringName, level: int) -> String:
	match line:
		&"engine":
			return "+%d%% accel" % roundi(ENGINE_ACCEL_BONUS[level] * 100.0)
		&"gearbox":
			return "+%d%% top speed" % roundi(GEARBOX_SPEED_BONUS[level] * 100.0)
		&"tires":
			return "+%d%% grip" % roundi(TIRES_GRIP_BONUS[level] * 100.0)
		&"nitro":
			return "%d boosts%s" % [NITRO_COUNT[level], ", +10% power" if level >= MAX_LEVEL else ""]
	return ""


## Returns a copy of `base` with `levels` ({line: level}) applied. Applied at
## race start only; never touches live VehicleState (§8).
static func apply(base: VehicleParams, levels: Dictionary) -> VehicleParams:
	var params: VehicleParams = base.duplicate()
	var engine: int = levels.get(&"engine", 0)
	var gearbox: int = levels.get(&"gearbox", 0)
	var tires: int = levels.get(&"tires", 0)
	var nitro: int = levels.get(&"nitro", 0)
	params.engine_accel_mps2 *= 1.0 + ENGINE_ACCEL_BONUS[engine]
	params.max_speed_mps *= 1.0 + GEARBOX_SPEED_BONUS[gearbox]
	# Grip raises v_max on every curve and helps recover from off-road.
	params.grip *= 1.0 + TIRES_GRIP_BONUS[tires]
	params.off_road_grip_mult *= 1.0 + TIRES_GRIP_BONUS[tires]
	params.nitro_count = NITRO_COUNT[nitro]
	if nitro >= MAX_LEVEL:
		params.nitro_accel_mult *= NITRO_L3_STRENGTH
		params.nitro_speed_mult = 1.0 + (params.nitro_speed_mult - 1.0) * NITRO_L3_STRENGTH
	return params
