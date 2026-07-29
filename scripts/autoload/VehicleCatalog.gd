extends Node
## Authoritative metadata for every playable/opponent vehicle.

const DEFAULT_VEHICLE_ID := "ravage"

const VEHICLES: Dictionary = {
	"ravage": {
		"id": "ravage",
		"display_name": "RAVAGE",
		"role": "ARMORED SURVIVOR",
		"ability_title": "REINFORCED HULL",
		"ability_description": "15% additional maximum health.",
		"scene_path": "res://scenes/vehicles/RavageModular.tscn",
		"vehicle_type": Vehicle.VehicleType.RAVAGE,
		"minimap_color": Color("21e6e6"),
		"unlock_rule": "default",
		"unlock_target": 0,
		"unlock_vehicle_id": "",
		"garage_y_offset": 0.0,
	},
	"bulldoze": {
		"id": "bulldoze",
		"display_name": "BULLDOZE",
		"role": "HEAVY RAMMER",
		"ability_title": "IMPACT DAMAGE",
		"ability_description": "Ramming an enemy deals half a missile's damage.",
		"scene_path": "res://scenes/vehicles/BullDozeModular.tscn",
		"vehicle_type": Vehicle.VehicleType.BULLDOZE,
		"minimap_color": Color("ffc928"),
		"unlock_rule": "kill_vehicle",
		"unlock_target": 20,
		"unlock_vehicle_id": "bulldoze",
		"garage_y_offset": 0.0,
	},
	"venom": {
		"id": "venom",
		"display_name": "VENOM",
		"role": "SPEED SPECIALIST",
		"ability_title": "OVERDRIVE",
		"ability_description": "Higher forward speed than the other vehicles.",
		"scene_path": "res://scenes/vehicles/VenomModular.tscn",
		"vehicle_type": Vehicle.VehicleType.VENOM,
		"minimap_color": Color("b52cff"),
		"unlock_rule": "first_place",
		"unlock_target": 20,
		"unlock_vehicle_id": "",
		"garage_y_offset": 0.0,
	},
	"wraith": {
		"id": "wraith",
		"display_name": "WRAITH",
		"role": "WEAPONS SPECIALIST",
		"ability_title": "WARHEAD EXPERT",
		"ability_description": "Missiles deal 1.5x damage.",
		"scene_path": "res://scenes/vehicles/WraithModular.tscn",
		"vehicle_type": Vehicle.VehicleType.WRAITH,
		"minimap_color": Color("ff4b4b"),
		"unlock_rule": "total_kills",
		"unlock_target": 50,
		"unlock_vehicle_id": "",
		"garage_y_offset": 0.0,
	},
	"specter": {
		"id": "specter",
		"display_name": "SPECTER",
		"role": "STEALTH ASSASSIN",
		"ability_title": "SHADOW CLOAK",
		"ability_description": "Firing cloaks the vehicle for 2.5 seconds. 8-second cooldown.",
		"scene_path": "res://scenes/vehicles/SpecterModular.tscn",
		"vehicle_type": Vehicle.VehicleType.SPECTER,
		"minimap_color": Color("8f52c7"),
		"unlock_rule": "hard_first_place",
		"unlock_target": 10,
		"unlock_vehicle_id": "",
		"garage_y_offset": 0.0,
	},
	"molten": {
		"id": "molten",
		"display_name": "MOLTEN",
		"role": "FLAME BRUISER",
		"ability_title": "FIRESTORM",
		"ability_description": "One ammo unleashes a 4-second short-range flamethrower.",
		"scene_path": "res://scenes/vehicles/MoltenModular.tscn",
		"vehicle_type": Vehicle.VehicleType.MOLTEN,
		"minimap_color": Color("ff7a18"),
		"unlock_rule": "last_standing_wins",
		"unlock_target": 10,
		"unlock_vehicle_id": "",
		"garage_y_offset": 0.0,
	},
	"thunderclaw": {
		"id": "thunderclaw",
		"display_name": "THUNDERCLAW",
		"role": "STORM CHASER",
		"ability_title": "CHAIN SURGE",
		"ability_description": "Firing boosts acceleration; missile hits arc to one nearby rival.",
		"scene_path": "res://scenes/vehicles/ThunderclawModular.tscn",
		"vehicle_type": Vehicle.VehicleType.THUNDERCLAW,
		"minimap_color": Color("28bfff"),
		"unlock_rule": "hybrid_wins",
		"unlock_target": 15,
		"unlock_vehicle_id": "",
		"garage_y_offset": 0.0,
	},
	"torrent": {
		"id": "torrent",
		"display_name": "TORRENT",
		"role": "PRECISION STRIKER",
		"ability_title": "SEEKER WARHEAD",
		"ability_description": "Missiles lock onto a visible rival and home for up to 18 meters.",
		"scene_path": "res://scenes/vehicles/TorrentModular.tscn",
		"vehicle_type": Vehicle.VehicleType.TORRENT,
		"minimap_color": Color("15d5d1"),
		"unlock_rule": "direct_missile_hits",
		"unlock_target": 100,
		"unlock_vehicle_id": "",
		"garage_y_offset": 0.0,
	},
}

const ORDERED_IDS: Array[String] = [
	"ravage",
	"bulldoze",
	"venom",
	"wraith",
	"specter",
	"molten",
	"thunderclaw",
	"torrent",
]


func has_vehicle(vehicle_id: String) -> bool:
	return VEHICLES.has(vehicle_id)


func get_vehicle(vehicle_id: String) -> Dictionary:
	var resolved_id := vehicle_id if has_vehicle(vehicle_id) else DEFAULT_VEHICLE_ID
	return (VEHICLES[resolved_id] as Dictionary).duplicate(true)


func get_all_ids() -> Array[String]:
	return ORDERED_IDS.duplicate()


func get_scene_path(vehicle_id: String) -> String:
	return str(get_vehicle(vehicle_id).get("scene_path", ""))


func get_id_for_scene_path(scene_path: String) -> String:
	for vehicle_id in ORDERED_IDS:
		if get_scene_path(vehicle_id) == scene_path:
			return vehicle_id
	return DEFAULT_VEHICLE_ID


func get_ai_candidate_ids(selected_vehicle_id: String) -> Array[String]:
	var selected_id := selected_vehicle_id if has_vehicle(selected_vehicle_id) else DEFAULT_VEHICLE_ID
	var candidates: Array[String] = []
	for vehicle_id in ORDERED_IDS:
		if vehicle_id != selected_id:
			candidates.append(vehicle_id)
	return candidates


func get_ai_roster(selected_vehicle_id: String, count: int = 3) -> Array[String]:
	if ORDERED_IDS.size() <= 1 or count <= 0:
		return []

	var candidates := get_ai_candidate_ids(selected_vehicle_id)
	candidates.shuffle()
	return candidates.slice(0, mini(count, candidates.size()))


func get_unlock_progress(vehicle_id: String, stats: Dictionary) -> int:
	var entry := get_vehicle(vehicle_id)
	match str(entry.get("unlock_rule", "default")):
		"default":
			return int(entry.get("unlock_target", 0))
		"first_place":
			return int(stats.get("first_place_finishes", 0))
		"hard_first_place":
			return int(stats.get("hard_first_place_finishes", 0))
		"last_standing_wins":
			return int(stats.get("last_standing_wins", 0))
		"hybrid_wins":
			return int(stats.get("hybrid_wins", 0))
		"total_kills":
			return int(stats.get("total_player_destroys", 0))
		"direct_missile_hits":
			return int(stats.get("direct_missile_hits", 0))
		"kill_vehicle":
			var kills_by_vehicle := stats.get("player_destroys_by_vehicle_id", {}) as Dictionary
			return int(kills_by_vehicle.get(str(entry.get("unlock_vehicle_id", "")), 0))
		_:
			return 0


func meets_unlock_requirement(vehicle_id: String, stats: Dictionary) -> bool:
	var entry := get_vehicle(vehicle_id)
	var rule := str(entry.get("unlock_rule", "default"))
	if rule == "default":
		return true
	if rule not in [
		"first_place",
		"hard_first_place",
		"last_standing_wins",
		"hybrid_wins",
		"total_kills",
		"kill_vehicle",
		"direct_missile_hits",
	]:
		push_warning("VehicleCatalog: unknown unlock rule '%s' for %s" % [rule, vehicle_id])
		return false
	return get_unlock_progress(vehicle_id, stats) >= int(entry.get("unlock_target", 0))


func unlock_requirement_text(vehicle_id: String) -> String:
	var entry := get_vehicle(vehicle_id)
	var target := int(entry.get("unlock_target", 0))
	match str(entry.get("unlock_rule", "default")):
		"default":
			return "AVAILABLE"
		"first_place":
			return "FINISH 1ST IN %d RACES" % target
		"hard_first_place":
			return "WIN %d RACES ON HARD" % target
		"last_standing_wins":
			return "WIN %d LAST STANDING RACES" % target
		"hybrid_wins":
			return "WIN %d HYBRID RACES" % target
		"total_kills":
			return "DESTROY %d CARS" % target
		"kill_vehicle":
			var victim := get_vehicle(str(entry.get("unlock_vehicle_id", DEFAULT_VEHICLE_ID)))
			return "DESTROY %s %d TIMES" % [str(victim.get("display_name", "CAR")), target]
		"direct_missile_hits":
			return "LAND %d DIRECT MISSILE HITS" % target
		_:
			return "UNAVAILABLE"
