class_name Progression
extends RefCounted
## Economy, upgrades and event unlocks (§8). Every change is saved.

signal changed

## Credits for 1st, 2nd and 3rd; any other finish earns FINISH_REWARD.
const PODIUM_REWARDS := [400, 250, 150]
const FINISH_REWARD := 75
## Finishing at or above this place unlocks the next event.
const UNLOCK_PLACE := 3

var profile: PlayerProfile
var base_params: VehicleParams = VehicleParams.new()

var _save: SaveService


func _init(save_service: SaveService) -> void:
	_save = save_service
	profile = _save.load_profile()


func can_buy(line: StringName) -> bool:
	var price := Upgrades.next_price(line, profile.level(line))
	return price >= 0 and profile.credits >= price


## Buys the next level of `line`. Atomic: either credits and level both
## change and are saved, or nothing changes.
func buy(line: StringName) -> bool:
	if not can_buy(line):
		return false
	profile.credits -= Upgrades.next_price(line, profile.level(line))
	profile.upgrades[line] = profile.level(line) + 1
	_commit()
	return true


static func reward_for(event: EventDefinition, place: int) -> int:
	var base: int = PODIUM_REWARDS[place - 1] if place >= 1 and place <= PODIUM_REWARDS.size() else FINISH_REWARD
	return roundi(base * event.reward_mult)


## Records a finish. Returns {"credits": int, "unlocked": StringName or &"",
## "new_best": bool}.
func award(event: EventDefinition, place: int, time_s: float) -> Dictionary:
	var credits := reward_for(event, place)
	profile.credits += credits
	var unlocked := &""
	if place <= UNLOCK_PLACE and event.unlocks != &"" and not profile.is_unlocked(event.unlocks):
		profile.unlocked_events.append(event.unlocks)
		unlocked = event.unlocks
	var best: Dictionary = profile.best_results.get(event.id, {})
	var new_best: bool = best.is_empty() or place < best["place"] or (place == best["place"] and time_s < best["time_s"])
	if new_best:
		profile.best_results[event.id] = {"place": place, "time_s": time_s}
	_commit()
	return {"credits": credits, "unlocked": unlocked, "new_best": new_best}


func player_params() -> VehicleParams:
	return Upgrades.apply(base_params, profile.upgrades)


func _commit() -> void:
	_save.save_profile(profile)
	changed.emit()
