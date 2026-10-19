class_name TrackPalette
extends Resource
## A track's look: sky, ground, road colors and background layers.

@export_group("Sky")
@export var sky_top: Color = Color8(48, 88, 192)
@export var sky_horizon: Color = Color8(168, 204, 244)
## Far background strip: &"mountains" or &"sea".
@export var far_layer: StringName = &"mountains"
@export var show_hills: bool = true

@export_group("Ground")
@export var grass_light: Color = Color8(64, 156, 64)
@export var grass_dark: Color = Color8(54, 140, 56)

@export_group("Road")
@export var road_light: Color = Color8(108, 108, 118)
@export var road_dark: Color = Color8(100, 100, 110)
@export var rumble_light: Color = Color8(236, 236, 236)
@export var rumble_dark: Color = Color8(206, 44, 44)
@export var lane: Color = Color8(240, 240, 240)
