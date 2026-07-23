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
}

const ORDERED_IDS: Array[String] = [
	"ravage",
	"bulldoze",
	"venom",
	"wraith",
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


func get_ai_roster(selected_vehicle_id: String, count: int = 3) -> Array[String]:
	var selected_id := selected_vehicle_id if has_vehicle(selected_vehicle_id) else DEFAULT_VEHICLE_ID
	var candidates: Array[String] = []
	for vehicle_id in ORDERED_IDS:
		if vehicle_id != selected_id:
			candidates.append(vehicle_id)
	if candidates.is_empty() or count <= 0:
		return []

	var roster: Array[String] = []
	for index in mini(count, candidates.size()):
		roster.append(candidates[index])
	return roster


func get_unlock_progress(vehicle_id: String, stats: Dictionary) -> int:
	var entry := get_vehicle(vehicle_id)
	match str(entry.get("unlock_rule", "default")):
		"default":
			return int(entry.get("unlock_target", 0))
		"first_place":
			return int(stats.get("first_place_finishes", 0))
		"total_kills":
			return int(stats.get("total_player_destroys", 0))
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
	if rule not in ["first_place", "total_kills", "kill_vehicle"]:
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
		"total_kills":
			return "DESTROY %d CARS" % target
		"kill_vehicle":
			var victim := get_vehicle(str(entry.get("unlock_vehicle_id", DEFAULT_VEHICLE_ID)))
			return "DESTROY %s %d TIMES" % [str(victim.get("display_name", "CAR")), target]
		_:
			return "UNAVAILABLE"
