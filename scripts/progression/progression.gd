class_name Progression
extends RefCounted
## Economy, upgrades and event unlocks (§8). Every change is saved.

signal changed

## Credits for 1st, 2nd and 3rd; any other finish earns FINISH_REWARD.
const PODIUM_REWARDS := [400, 250, 150]
const FINISH_REWARD := 75
## Finishing at or above this place unlocks the next event.
const UNLOCK_PLACE := 3
## Cup points by finishing place (best finish per event counts).
const CUP_POINTS := [10, 6, 4, 3, 2, 1]
const BRONZE := 1
const SILVER := 2
const GOLD := 3
const TROPHY_NAMES := ["", "Bronze", "Silver", "Gold"]

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


static func points_for(place: int) -> int:
	return CUP_POINTS[place - 1] if place >= 1 and place <= CUP_POINTS.size() else 0


## Points from the best finish in each of the cup's events.
func cup_points(cup: CupDefinition) -> int:
	var total := 0
	for event in cup.events:
		var best: Dictionary = profile.best_results.get(event.id, {})
		if not best.is_empty():
			total += points_for(best["place"])
	return total


## Trophy earned so far: bronze for a top 3 in every event, silver and gold
## by points on top of that. 0 = none yet.
func trophy_for(cup: CupDefinition) -> int:
	for event in cup.events:
		var best: Dictionary = profile.best_results.get(event.id, {})
		if best.is_empty() or best["place"] > UNLOCK_PLACE:
			return 0
	var points := cup_points(cup)
	if points >= cup.gold_points:
		return GOLD
	if points >= cup.silver_points:
		return SILVER
	return BRONZE


## Records a finish. Returns {"credits": int, "unlocked": StringName or &"",
## "new_best": bool, "trophy": int (new tier, or 0), "trophy_bonus": int}.
func award(event: EventDefinition, place: int, time_s: float, cup: CupDefinition = null) -> Dictionary:
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
	var trophy := 0
	var bonus := 0
	if cup != null:
		var earned := trophy_for(cup)
		var had: int = profile.trophies.get(cup.id, 0)
		if earned > had:
			for tier in range(had, earned):
				bonus += cup.trophy_bonus[tier]
			profile.trophies[cup.id] = earned
			profile.credits += bonus
			trophy = earned
			if had == 0 and cup.unlocks != &"" and not profile.is_unlocked(cup.unlocks):
				profile.unlocked_events.append(cup.unlocks)
				unlocked = cup.unlocks
	_commit()
	return {"credits": credits, "unlocked": unlocked, "new_best": new_best,
			"trophy": trophy, "trophy_bonus": bonus}


## Saves profile changes made directly (e.g. settings).
func save() -> void:
	_commit()


func player_params() -> VehicleParams:
	return Upgrades.apply(base_params, profile.upgrades)


func _commit() -> void:
	_save.save_profile(profile)
	changed.emit()
