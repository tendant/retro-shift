class_name EventDefinition
extends Resource
## One race event (§8): track, field, difficulty and rewards.

@export var id: StringName
@export var display_name: String = ""
@export var track: Track
@export var laps: int = 3
@export_range(0, 5) var opponents: int = 5
## Opponent skill spread (§7); the first opponent is the weakest.
@export var skill_min: float = 0.86
@export var skill_max: float = 1.0
@export var rubber_band_strength: float = 1.0
## Reward multiplier for the event tier.
@export var reward_mult: float = 1.0
## Event unlocked by finishing this one in the top 3 (empty = none).
@export var unlocks: StringName
