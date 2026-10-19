class_name CupDefinition
extends Resource
## A championship cup: three events raced in order (top 3 unlocks the
## next). Trophies come from the player's points over their best finishes.

@export var id: StringName
@export var display_name: String = ""
@export var events: Array[EventDefinition] = []
## Credits for first reaching bronze, silver, gold (each paid once).
@export var trophy_bonus: Array[int] = [300, 500, 800]
@export var silver_points: int = 18
@export var gold_points: int = 26
## First event of the next cup, unlocked by any trophy (empty = none).
@export var unlocks: StringName
