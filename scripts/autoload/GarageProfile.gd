extends Node
## Persistent vehicle ownership, selection, and completed-race progression.

const SCHEMA_VERSION := 1
const DEFAULT_PROFILE_PATH := "user://garage_profile.json"
const MAX_COMMITTED_RACE_IDS := 128

var storage_path: String = DEFAULT_PROFILE_PATH
var profile: Dictionary = {}
var debug_unlock_all: bool = false


func _ready() -> void:
	load_profile()


func default_profile() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"selected_vehicle_id": VehicleCatalog.DEFAULT_VEHICLE_ID,
		"unlocked_vehicle_ids": {
			VehicleCatalog.DEFAULT_VEHICLE_ID: true,
		},
		"stats": {
			"first_place_finishes": 0,
			"total_player_destroys": 0,
			"player_destroys_by_vehicle_id": {},
		},
		"committed_race_ids": [],
	}


func load_profile() -> void:
	profile = default_profile()
	if not FileAccess.file_exists(storage_path):
		_save_profile()
		return

	var file := FileAccess.open(storage_path, FileAccess.READ)
	if file == null:
		push_warning("GarageProfile: could not read %s; using defaults" % storage_path)
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is not Dictionary:
		push_warning("GarageProfile: profile is corrupt; using defaults")
		return
	_merge_loaded_profile(parsed as Dictionary)
	_evaluate_unlocks()


func _merge_loaded_profile(loaded: Dictionary) -> void:
	var selected_id := str(loaded.get("selected_vehicle_id", VehicleCatalog.DEFAULT_VEHICLE_ID))
	if not VehicleCatalog.has_vehicle(selected_id):
		selected_id = VehicleCatalog.DEFAULT_VEHICLE_ID
	profile["selected_vehicle_id"] = selected_id

	var loaded_unlocks := loaded.get("unlocked_vehicle_ids", {}) as Dictionary
	var unlocks := profile["unlocked_vehicle_ids"] as Dictionary
	for vehicle_id in loaded_unlocks:
		if VehicleCatalog.has_vehicle(str(vehicle_id)) and bool(loaded_unlocks[vehicle_id]):
			unlocks[str(vehicle_id)] = true

	var loaded_stats := loaded.get("stats", {}) as Dictionary
	var stats := profile["stats"] as Dictionary
	stats["first_place_finishes"] = maxi(int(loaded_stats.get("first_place_finishes", 0)), 0)
	stats["total_player_destroys"] = maxi(int(loaded_stats.get("total_player_destroys", 0)), 0)
	var loaded_by_vehicle := loaded_stats.get("player_destroys_by_vehicle_id", {}) as Dictionary
	var by_vehicle: Dictionary = {}
	for vehicle_id in loaded_by_vehicle:
		if VehicleCatalog.has_vehicle(str(vehicle_id)):
			by_vehicle[str(vehicle_id)] = maxi(int(loaded_by_vehicle[vehicle_id]), 0)
	stats["player_destroys_by_vehicle_id"] = by_vehicle

	var committed := loaded.get("committed_race_ids", []) as Array
	var valid_committed: Array[String] = []
	for race_id in committed:
		var id_text := str(race_id)
		if not id_text.is_empty() and id_text not in valid_committed:
			valid_committed.append(id_text)
	if valid_committed.size() > MAX_COMMITTED_RACE_IDS:
		valid_committed = valid_committed.slice(valid_committed.size() - MAX_COMMITTED_RACE_IDS)
	profile["committed_race_ids"] = valid_committed


func selected_vehicle_id() -> String:
	var selected_id := str(profile.get("selected_vehicle_id", VehicleCatalog.DEFAULT_VEHICLE_ID))
	if not VehicleCatalog.has_vehicle(selected_id) or not is_vehicle_unlocked(selected_id):
		return VehicleCatalog.DEFAULT_VEHICLE_ID
	return selected_id


func is_vehicle_unlocked(vehicle_id: String) -> bool:
	if debug_unlock_all and OS.is_debug_build():
		return VehicleCatalog.has_vehicle(vehicle_id)
	var unlocks := profile.get("unlocked_vehicle_ids", {}) as Dictionary
	return bool(unlocks.get(vehicle_id, false))


func select_vehicle(vehicle_id: String) -> bool:
	if not VehicleCatalog.has_vehicle(vehicle_id) or not is_vehicle_unlocked(vehicle_id):
		return false
	profile["selected_vehicle_id"] = vehicle_id
	return _save_profile()


func stats() -> Dictionary:
	return (profile.get("stats", {}) as Dictionary).duplicate(true)


func unlock_progress(vehicle_id: String) -> int:
	return VehicleCatalog.get_unlock_progress(vehicle_id, profile.get("stats", {}) as Dictionary)


func unlock_target(vehicle_id: String) -> int:
	return int(VehicleCatalog.get_vehicle(vehicle_id).get("unlock_target", 0))


func commit_completed_race(summary: Dictionary) -> Array[String]:
	if not bool(summary.get("completed", false)):
		return []
	var race_id := str(summary.get("race_id", ""))
	if race_id.is_empty():
		push_warning("GarageProfile: rejected race summary without an ID")
		return []
	var committed := profile.get("committed_race_ids", []) as Array
	if race_id in committed:
		return []

	var profile_stats := profile.get("stats", {}) as Dictionary
	if bool(summary.get("player_first", false)):
		profile_stats["first_place_finishes"] = int(profile_stats.get("first_place_finishes", 0)) + 1

	var kills_by_vehicle := summary.get("player_kills_by_vehicle_id", {}) as Dictionary
	var stored_by_vehicle := profile_stats.get("player_destroys_by_vehicle_id", {}) as Dictionary
	var total_added := 0
	for vehicle_id in kills_by_vehicle:
		var resolved_id := str(vehicle_id)
		if not VehicleCatalog.has_vehicle(resolved_id):
			continue
		var added := maxi(int(kills_by_vehicle[vehicle_id]), 0)
		if added <= 0:
			continue
		stored_by_vehicle[resolved_id] = int(stored_by_vehicle.get(resolved_id, 0)) + added
		total_added += added
	profile_stats["total_player_destroys"] = int(profile_stats.get("total_player_destroys", 0)) + total_added
	profile_stats["player_destroys_by_vehicle_id"] = stored_by_vehicle
	profile["stats"] = profile_stats

	committed.append(race_id)
	if committed.size() > MAX_COMMITTED_RACE_IDS:
		committed.pop_front()
	profile["committed_race_ids"] = committed
	var newly_unlocked := _evaluate_unlocks()
	_save_profile()
	return newly_unlocked


func _evaluate_unlocks() -> Array[String]:
	var newly_unlocked: Array[String] = []
	var unlocks := profile.get("unlocked_vehicle_ids", {}) as Dictionary
	var profile_stats := profile.get("stats", {}) as Dictionary
	unlocks[VehicleCatalog.DEFAULT_VEHICLE_ID] = true
	for vehicle_id in VehicleCatalog.get_all_ids():
		if bool(unlocks.get(vehicle_id, false)):
			continue
		if VehicleCatalog.meets_unlock_requirement(vehicle_id, profile_stats):
			unlocks[vehicle_id] = true
			newly_unlocked.append(vehicle_id)
	profile["unlocked_vehicle_ids"] = unlocks
	return newly_unlocked


func set_debug_unlock_all(enabled: bool) -> void:
	debug_unlock_all = enabled and OS.is_debug_build()


func reset_profile_for_tests(path: String) -> void:
	storage_path = path
	profile = default_profile()


func _save_profile() -> bool:
	var file := FileAccess.open(storage_path, FileAccess.WRITE)
	if file == null:
		push_warning("GarageProfile: could not save %s" % storage_path)
		return false
	file.store_string(JSON.stringify(profile, "\t"))
	return true
