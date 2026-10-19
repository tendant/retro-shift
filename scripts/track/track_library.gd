class_name TrackLibrary
extends RefCounted
## Every raceable track: championship tracks (.tres resources, editable in
## the Godot editor) followed by the code-built dev/visual test tracks.

const EVENT_TRACKS := {
	&"harbor_mile": "res://resources/tracks/harbor_mile.tres",
	&"lighthouse_loop": "res://resources/tracks/lighthouse_loop.tres",
	&"cliffside_run": "res://resources/tracks/cliffside_run.tres",
}


static func names() -> Array[StringName]:
	var all: Array[StringName] = []
	for track_name: StringName in EVENT_TRACKS:
		all.append(track_name)
	for track_name: StringName in TestTracks.NAMES:
		all.append(track_name)
	return all


## A fresh copy, safe to build and change (e.g. laps) for one race.
static func make(track_name: StringName) -> Track:
	if EVENT_TRACKS.has(track_name):
		return load(EVENT_TRACKS[track_name]).duplicate()
	return TestTracks.make(track_name)
