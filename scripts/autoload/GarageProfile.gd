extends Node
## Persistent vehicle ownership, selection, and completed-race progression.

const SCHEMA_VERSION := 6
const DEFAULT_PROFILE_PATH := "user://garage_profile.json"
const MAX_COMMITTED_RACE_IDS := 128

var storage_path: String = DEFAULT_PROFILE_PATH
var profile: Dictionary = {}
var debug_unlock_all: bool = false
var _last_commit_result: Dictionary = {}


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
			"hard_first_place_finishes": 0,
			"last_standing_wins": 0,
			"hybrid_wins": 0,
			"total_player_destroys": 0,
			"direct_missile_hits": 0,
			"player_destroys_by_vehicle_id": {},
		},
		"credits": {
			"balance": 0,
			"lifetime_earned": 0,
			"lifetime_spent": 0,
		},
		"drones": {
			"owned_tiers": {},
			"equipped_id": DroneCatalog.NO_DRONE_ID,
			"equipped_tier": 0,
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
	stats["hard_first_place_finishes"] = maxi(int(loaded_stats.get("hard_first_place_finishes", 0)), 0)
	stats["last_standing_wins"] = maxi(int(loaded_stats.get("last_standing_wins", 0)), 0)
	stats["hybrid_wins"] = maxi(int(loaded_stats.get("hybrid_wins", 0)), 0)
	stats["total_player_destroys"] = maxi(int(loaded_stats.get("total_player_destroys", 0)), 0)
	stats["direct_missile_hits"] = maxi(int(loaded_stats.get("direct_missile_hits", 0)), 0)
	var loaded_by_vehicle := loaded_stats.get("player_destroys_by_vehicle_id", {}) as Dictionary
	var by_vehicle: Dictionary = {}
	for vehicle_id in loaded_by_vehicle:
		if VehicleCatalog.has_vehicle(str(vehicle_id)):
			by_vehicle[str(vehicle_id)] = maxi(int(loaded_by_vehicle[vehicle_id]), 0)
	stats["player_destroys_by_vehicle_id"] = by_vehicle

	var loaded_credits := loaded.get("credits", {}) as Dictionary
	var credits := profile["credits"] as Dictionary
	credits["balance"] = maxi(int(loaded_credits.get("balance", 0)), 0)
	credits["lifetime_earned"] = maxi(int(loaded_credits.get("lifetime_earned", 0)), 0)
	credits["lifetime_spent"] = maxi(int(loaded_credits.get("lifetime_spent", 0)), 0)

	var loaded_drones := loaded.get("drones", {}) as Dictionary
	var drones := profile["drones"] as Dictionary
	var owned: Dictionary = {}
	var loaded_owned := loaded_drones.get("owned_tiers", {}) as Dictionary
	for drone_id in loaded_owned:
		var resolved_id := str(drone_id)
		if not DroneCatalog.has_drone(resolved_id):
			continue
		var resolved_tier := clampi(int(loaded_owned[drone_id]), 0, DroneCatalog.MAX_TIER)
		if resolved_tier > 0:
			owned[resolved_id] = resolved_tier
	drones["owned_tiers"] = owned
	var equipped_id := str(loaded_drones.get("equipped_id", DroneCatalog.NO_DRONE_ID))
	var equipped_tier := clampi(int(loaded_drones.get("equipped_tier", 0)), 0, DroneCatalog.MAX_TIER)
	if (
		not DroneCatalog.has_drone(equipped_id)
		or equipped_tier <= 0
		or equipped_tier > int(owned.get(equipped_id, 0))
	):
		equipped_id = DroneCatalog.NO_DRONE_ID
		equipped_tier = 0
	drones["equipped_id"] = equipped_id
	drones["equipped_tier"] = equipped_tier

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


func credit_balance() -> int:
	return maxi(int((profile.get("credits", {}) as Dictionary).get("balance", 0)), 0)


func lifetime_credits_earned() -> int:
	return maxi(int((profile.get("credits", {}) as Dictionary).get("lifetime_earned", 0)), 0)


func owned_drone_tier(drone_id: String) -> int:
	var drones := profile.get("drones", {}) as Dictionary
	var owned := drones.get("owned_tiers", {}) as Dictionary
	return clampi(int(owned.get(drone_id, 0)), 0, DroneCatalog.MAX_TIER)


func owns_drone_tier(drone_id: String, tier: int) -> bool:
	return tier > 0 and owned_drone_tier(drone_id) >= tier


func equipped_drone() -> Dictionary:
	var drones := profile.get("drones", {}) as Dictionary
	var drone_id := str(drones.get("equipped_id", DroneCatalog.NO_DRONE_ID))
	var tier := int(drones.get("equipped_tier", 0))
	if (
		not owns_drone_tier(drone_id, tier)
		or not DroneCatalog.is_tier_available(drone_id, tier)
	):
		return {"id": DroneCatalog.NO_DRONE_ID, "tier": 0}
	return {"id": drone_id, "tier": tier}


func can_purchase_drone_tier(drone_id: String, tier: int) -> bool:
	if not DroneCatalog.has_drone(drone_id) or tier < DroneCatalog.MIN_TIER or tier > DroneCatalog.MAX_TIER:
		return false
	if not DroneCatalog.is_tier_available(drone_id, tier):
		return false
	if owns_drone_tier(drone_id, tier):
		return false
	if tier > 1 and not owns_drone_tier(drone_id, tier - 1):
		return false
	return credit_balance() >= DroneCatalog.get_price(drone_id, tier)


func purchase_drone_tier(drone_id: String, tier: int) -> bool:
	if not can_purchase_drone_tier(drone_id, tier):
		return false
	var price := DroneCatalog.get_price(drone_id, tier)
	var credits := profile.get("credits", {}) as Dictionary
	credits["balance"] = credit_balance() - price
	credits["lifetime_spent"] = int(credits.get("lifetime_spent", 0)) + price
	var drones := profile.get("drones", {}) as Dictionary
	var owned := drones.get("owned_tiers", {}) as Dictionary
	owned[drone_id] = maxi(int(owned.get(drone_id, 0)), tier)
	drones["owned_tiers"] = owned
	profile["credits"] = credits
	profile["drones"] = drones
	return _save_profile()


func equip_drone(drone_id: String, tier: int) -> bool:
	if not owns_drone_tier(drone_id, tier) or not DroneCatalog.is_tier_available(drone_id, tier):
		return false
	var drones := profile.get("drones", {}) as Dictionary
	drones["equipped_id"] = drone_id
	drones["equipped_tier"] = tier
	profile["drones"] = drones
	return _save_profile()


func unequip_drone() -> bool:
	var drones := profile.get("drones", {}) as Dictionary
	drones["equipped_id"] = DroneCatalog.NO_DRONE_ID
	drones["equipped_tier"] = 0
	profile["drones"] = drones
	return _save_profile()


func calculate_credit_reward(summary: Dictionary) -> Dictionary:
	var player_place := maxi(int(summary.get("player_place", 0)), 0)
	var placement_reward := 0
	if bool(summary.get("player_first", false)) or player_place == 1:
		placement_reward = 10
	elif player_place == 2:
		placement_reward = 5
	elif player_place == 3:
		placement_reward = 2
	var elimination_count := maxi(int(summary.get("player_eliminations", 0)), 0)
	var drone_eliminations := clampi(
		int(summary.get("player_drone_eliminations", 0)),
		0,
		elimination_count
	)
	var elimination_reward := elimination_count * 5
	var drone_bonus := drone_eliminations * 2
	var subtotal := placement_reward + elimination_reward + drone_bonus
	var multiplier := 1.0
	match int(summary.get("difficulty", MatchConfig.AIDifficulty.NOVICE)):
		MatchConfig.AIDifficulty.MEDIUM:
			multiplier = 1.25
		MatchConfig.AIDifficulty.HARD:
			multiplier = 1.5
	var total := maxi(int(round(float(subtotal) * multiplier)), 0)
	return {
		"placement_reward": placement_reward,
		"elimination_count": elimination_count,
		"elimination_reward": elimination_reward,
		"drone_eliminations": drone_eliminations,
		"drone_bonus": drone_bonus,
		"subtotal": subtotal,
		"multiplier": multiplier,
		"total": total,
		"wallet_before": credit_balance(),
		"wallet_after": credit_balance() + total,
	}


func last_commit_result() -> Dictionary:
	return _last_commit_result.duplicate(true)


func commit_completed_race(summary: Dictionary) -> Array[String]:
	_last_commit_result = {
		"committed": false,
		"duplicate": false,
		"newly_unlocked_vehicle_ids": [],
		"credit_reward": {},
	}
	if not bool(summary.get("completed", false)):
		return []
	var race_id := str(summary.get("race_id", ""))
	if race_id.is_empty():
		push_warning("GarageProfile: rejected race summary without an ID")
		return []
	var committed := profile.get("committed_race_ids", []) as Array
	if race_id in committed:
		_last_commit_result["duplicate"] = true
		return []

	var credit_reward := calculate_credit_reward(summary)

	var profile_stats := profile.get("stats", {}) as Dictionary
	if bool(summary.get("player_first", false)):
		profile_stats["first_place_finishes"] = int(profile_stats.get("first_place_finishes", 0)) + 1
		if int(summary.get("difficulty", -1)) == MatchConfig.AIDifficulty.HARD:
			profile_stats["hard_first_place_finishes"] = int(profile_stats.get("hard_first_place_finishes", 0)) + 1
		if int(summary.get("mode", -1)) == MatchConfig.Mode.LAST_STANDING:
			profile_stats["last_standing_wins"] = int(profile_stats.get("last_standing_wins", 0)) + 1
		if int(summary.get("mode", -1)) == MatchConfig.Mode.HYBRID:
			profile_stats["hybrid_wins"] = int(profile_stats.get("hybrid_wins", 0)) + 1

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
	profile_stats["direct_missile_hits"] = (
		int(profile_stats.get("direct_missile_hits", 0))
		+ maxi(int(summary.get("direct_missile_hits", 0)), 0)
	)
	profile_stats["player_destroys_by_vehicle_id"] = stored_by_vehicle
	profile["stats"] = profile_stats

	var credits := profile.get("credits", {}) as Dictionary
	var earned := int(credit_reward.get("total", 0))
	credits["balance"] = credit_balance() + earned
	credits["lifetime_earned"] = int(credits.get("lifetime_earned", 0)) + earned
	profile["credits"] = credits

	committed.append(race_id)
	if committed.size() > MAX_COMMITTED_RACE_IDS:
		committed.pop_front()
	profile["committed_race_ids"] = committed
	var newly_unlocked := _evaluate_unlocks()
	_save_profile()
	_last_commit_result = {
		"committed": true,
		"duplicate": false,
		"newly_unlocked_vehicle_ids": newly_unlocked.duplicate(),
		"credit_reward": credit_reward.duplicate(true),
	}
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
	_last_commit_result.clear()


func _save_profile() -> bool:
	var file := FileAccess.open(storage_path, FileAccess.WRITE)
	if file == null:
		push_warning("GarageProfile: could not save %s" % storage_path)
		return false
	file.store_string(JSON.stringify(profile, "\t"))
	return true
