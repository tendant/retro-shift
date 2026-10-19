class_name SaveService
extends RefCounted
## Versioned profile saves (§8): validate on load, back up before migrating,
## fall back to defaults on corruption.

const SCHEMA_VERSION := 2
const PROFILE_FILE := "profile.json"

## Current schema version. A variable so tests can exercise migrations.
var schema_version: int = SCHEMA_VERSION
## {from_version: Callable(Dictionary) -> Dictionary}, upgrading one version.
var migrations: Dictionary = {}

var _storage: SaveStorage


func _init(storage: SaveStorage) -> void:
	_storage = storage
	migrations[1] = _migrate_1_to_2


func load_profile() -> PlayerProfile:
	var text := _storage.read_text(PROFILE_FILE)
	if text.is_empty():
		return PlayerProfile.new()
	var json := JSON.new()
	if json.parse(text) != OK or not json.data is Dictionary:
		return _recover(text, "unreadable")
	var data: Dictionary = json.data
	var version: Variant = data.get("schema_version")
	if not (version is float or version is int) or int(version) < 1:
		return _recover(text, "no schema version")
	var from := int(version)
	if from > schema_version:
		return _recover(text, "from newer schema %d" % from)
	if from < schema_version:
		_storage.write_text(_backup_name("v%d" % from), text)
		for v in range(from, schema_version):
			if not migrations.has(v):
				return _recover(text, "no migration from schema %d" % v)
			data = migrations[v].call(data)
	return PlayerProfile.from_dict(data)


func save_profile(profile: PlayerProfile) -> bool:
	var data := profile.to_dict()
	data["schema_version"] = schema_version
	return _storage.write_text(PROFILE_FILE, JSON.stringify(data, "\t"))


## v2 replaced the two placeholder events with the Sunrise Coast Cup. Keep
## credits, upgrades and settings; event progress restarts at the new cup.
static func _migrate_1_to_2(data: Dictionary) -> Dictionary:
	data.erase("unlocked_events")
	data.erase("best_results")
	return data


## Keeps the bad file for inspection and starts from defaults.
func _recover(text: String, reason: String) -> PlayerProfile:
	push_warning("Save %s is %s; backed up and reset to defaults." % [PROFILE_FILE, reason])
	_storage.write_text(_backup_name("corrupt"), text)
	return PlayerProfile.new()


static func _backup_name(tag: String) -> String:
	return "%s.%s.bak" % [PROFILE_FILE.get_basename(), tag]
