class_name PlayerProfile
extends RefCounted
## Persistent player progress (§8). Plain data; SaveService owns the format.

const FIRST_EVENT := &"harbor_mile"

var credits: int = 0
## {line: level}
var upgrades: Dictionary = {}
var unlocked_events: Array[StringName] = [FIRST_EVENT]
## {event_id: {"place": int, "time_s": float}}
var best_results: Dictionary = {}
## {cup_id: trophy tier}, 1 = bronze, 2 = silver, 3 = gold.
var trophies: Dictionary = {}
var settings: Dictionary = {}


func _init() -> void:
	for line in Upgrades.LINES:
		upgrades[line] = 0


func level(line: StringName) -> int:
	return upgrades.get(line, 0)


func is_unlocked(event_id: StringName) -> bool:
	return unlocked_events.has(event_id)


func to_dict() -> Dictionary:
	var ups := {}
	for line in Upgrades.LINES:
		ups[String(line)] = level(line)
	var unlocked: Array[String] = []
	for event_id in unlocked_events:
		unlocked.append(String(event_id))
	var best := {}
	for event_id: StringName in best_results:
		best[String(event_id)] = best_results[event_id].duplicate()
	var cup_trophies := {}
	for cup_id: StringName in trophies:
		cup_trophies[String(cup_id)] = trophies[cup_id]
	return {
		"credits": credits,
		"upgrades": ups,
		"unlocked_events": unlocked,
		"best_results": best,
		"trophies": cup_trophies,
		"settings": settings.duplicate(true),
	}


## Builds a profile from untrusted data: unknown keys are ignored and every
## value is type-checked and clamped, falling back to defaults.
static func from_dict(data: Dictionary) -> PlayerProfile:
	var profile := PlayerProfile.new()
	profile.credits = maxi(0, _to_int(data.get("credits"), 0))

	var ups: Variant = data.get("upgrades")
	if ups is Dictionary:
		for line in Upgrades.LINES:
			profile.upgrades[line] = clampi(_to_int(ups.get(String(line)), 0), 0, Upgrades.MAX_LEVEL)

	var unlocked: Variant = data.get("unlocked_events")
	if unlocked is Array:
		for event_id: Variant in unlocked:
			if event_id is String and not profile.unlocked_events.has(StringName(event_id)):
				profile.unlocked_events.append(StringName(event_id))

	var best: Variant = data.get("best_results")
	if best is Dictionary:
		for event_id: Variant in best:
			var entry: Variant = best[event_id]
			if event_id is String and entry is Dictionary:
				var place := _to_int(entry.get("place"), 0)
				var time_s: Variant = entry.get("time_s")
				if place >= 1 and (time_s is float or time_s is int) and is_finite(time_s) and time_s > 0.0:
					profile.best_results[StringName(event_id)] = {"place": place, "time_s": float(time_s)}

	var cup_trophies: Variant = data.get("trophies")
	if cup_trophies is Dictionary:
		for cup_id: Variant in cup_trophies:
			var tier := clampi(_to_int(cup_trophies[cup_id], 0), 0, Progression.GOLD)
			if cup_id is String and tier > 0:
				profile.trophies[StringName(cup_id)] = tier

	var settings: Variant = data.get("settings")
	if settings is Dictionary:
		profile.settings = settings.duplicate(true)
	return profile


## JSON numbers arrive as floats; accept whole numbers only.
static func _to_int(value: Variant, fallback: int) -> int:
	if value is int:
		return value
	if value is float and is_finite(value) and value == floorf(value):
		return int(value)
	return fallback
