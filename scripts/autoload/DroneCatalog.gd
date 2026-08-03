extends Node
## Authoritative drone metadata shared by progression, race spawning, and UI.

const SCRAPJAW_ID := "scrapjaw"
const BOMBLET_ID := "bomblet"
const WELDER_ID := "welder"
const NO_DRONE_ID := ""
const MIN_TIER := 1
const MAX_TIER := 4

const DRONES: Dictionary = {
	SCRAPJAW_ID: {
		"id": SCRAPJAW_ID,
		"display_name": "Scrapjaw",
		"role": "Assault Drone",
		"ability": "Chomp",
		"description": "Hunts the nearest visible rival, lunges in, and tears through armor.",
		"accent": Color("e83f87"),
		# Scrapjaw was authored with +X as forward; Godot gameplay uses -Z.
		"model_yaw_degrees": 90.0,
		"tiers": {
			1: {
				"label": "COMMON",
				"scene_path": "res://models/Drones/scrapjaw_T1.glb",
				"price": 100,
				"cooldown": 12.0,
				"damage_ratio": 0.60,
			},
			2: {
				"label": "RARE",
				"scene_path": "res://models/Drones/scrapjaw_T2.glb",
				"price": 250,
				"cooldown": 10.0,
				"damage_ratio": 0.70,
			},
			3: {
				"label": "EPIC",
				"scene_path": "res://models/Drones/scrapjaw_T3.glb",
				"price": 500,
				"cooldown": 8.0,
				"damage_ratio": 0.85,
			},
			4: {
				"label": "LEGENDARY",
				"scene_path": "res://models/Drones/scrapjaw_T4.glb",
				"price": 900,
				"cooldown": 6.0,
				"damage_ratio": 1.00,
			},
		},
	},
	BOMBLET_ID: {
		"id": BOMBLET_ID,
		"display_name": "Bomblet",
		"role": "Scout / Bomber Drone",
		"ability": "Bombdrop",
		"description": "Dashes ahead, seeds the racing line with proximity mines, then returns.",
		"accent": Color("ef8611"),
		"attack_type": "bombdrop",
		# Bomblet uses the same authored +X forward convention as Scrapjaw.
		"model_yaw_degrees": 90.0,
		"tiers": {
			1: {
				"label": "COMMON",
				"scene_path": "res://models/Drones/bomblet_t1.glb",
				"price": 100,
				"cooldown": 12.0,
				"damage_ratio": 0.30,
				"bomb_count": 3,
				"mine_lifetime": 3.0,
				"bombdrop_distance": 8.0,
			},
			2: {
				"label": "RARE",
				"scene_path": "res://models/Drones/bomblet_t2.glb",
				"price": 250,
				"cooldown": 10.0,
				"damage_ratio": 0.35,
				"bomb_count": 4,
				"mine_lifetime": 3.25,
				"bombdrop_distance": 8.5,
			},
			3: {
				"label": "EPIC",
				"scene_path": "res://models/Drones/bomblet_t3.glb",
				"price": 500,
				"cooldown": 8.0,
				"damage_ratio": 0.40,
				"bomb_count": 5,
				"mine_lifetime": 3.5,
				"bombdrop_distance": 9.0,
			},
			4: {
				"label": "LEGENDARY",
				"scene_path": "res://models/Drones/bomblet_t4.glb",
				"price": 900,
				"cooldown": 6.0,
				"damage_ratio": 0.50,
				"bomb_count": 6,
				"mine_lifetime": 4.0,
				"bombdrop_distance": 10.0,
			},
		},
	},
	WELDER_ID: {
		"id": WELDER_ID,
		"display_name": "Welder",
		"role": "Support Drone",
		"ability": "Repair Beam",
		"description": "Projects a repair beam that steadily restores its owner's damaged armor.",
		"accent": Color("43c95c"),
		"attack_type": "repair_beam",
		# Welder uses the same authored +X forward convention as the other drones.
		"model_yaw_degrees": 90.0,
		"tiers": {
			1: {
				"label": "COMMON",
				"scene_path": "res://models/Drones/welder_t1.glb",
				"price": 100,
				"cooldown": 12.0,
				"beam_duration": 3.0,
				"heal_ratio": 0.12,
			},
			2: {
				"label": "RARE",
				"scene_path": "",
				"price": 250,
			},
			3: {
				"label": "EPIC",
				"scene_path": "",
				"price": 500,
			},
			4: {
				"label": "LEGENDARY",
				"scene_path": "",
				"price": 900,
			},
		},
	},
}


func get_all_ids() -> Array[String]:
	var ids: Array[String] = []
	for drone_id in DRONES:
		ids.append(str(drone_id))
	return ids


func has_drone(drone_id: String) -> bool:
	return DRONES.has(drone_id)


func get_drone(drone_id: String) -> Dictionary:
	return (DRONES.get(drone_id, {}) as Dictionary).duplicate(true)


func get_tier(drone_id: String, tier: int) -> Dictionary:
	var drone := DRONES.get(drone_id, {}) as Dictionary
	var tiers := drone.get("tiers", {}) as Dictionary
	return (tiers.get(clampi(tier, MIN_TIER, MAX_TIER), {}) as Dictionary).duplicate(true)


func get_scene_path(drone_id: String, tier: int) -> String:
	return str(get_tier(drone_id, tier).get("scene_path", ""))


func get_model_yaw_degrees(drone_id: String) -> float:
	return float(get_drone(drone_id).get("model_yaw_degrees", 0.0))


func get_attack_type(drone_id: String) -> String:
	return str(get_drone(drone_id).get("attack_type", "chomp"))


func is_tier_available(drone_id: String, tier: int) -> bool:
	var tier_data := get_tier(drone_id, tier)
	if tier_data.is_empty():
		return false
	var scene_path := str(tier_data.get("scene_path", ""))
	return not scene_path.is_empty() and ResourceLoader.exists(scene_path)


func get_max_available_tier(drone_id: String) -> int:
	for tier in range(MAX_TIER, MIN_TIER - 1, -1):
		if is_tier_available(drone_id, tier):
			return tier
	return 0


func resolve_available_tier(drone_id: String, requested_tier: int) -> int:
	var maximum := mini(clampi(requested_tier, MIN_TIER, MAX_TIER), get_max_available_tier(drone_id))
	for tier in range(maximum, MIN_TIER - 1, -1):
		if is_tier_available(drone_id, tier):
			return tier
	return 0


func ai_drone_for_index(ai_index: int) -> String:
	var ids := get_all_ids()
	if ids.is_empty():
		return NO_DRONE_ID
	return ids[posmod(ai_index, ids.size())]


func get_price(drone_id: String, tier: int) -> int:
	return maxi(int(get_tier(drone_id, tier).get("price", 0)), 0)


func ai_tier_for_difficulty(difficulty: int, _ai_index: int = 0) -> int:
	match difficulty:
		MatchConfig.AIDifficulty.MEDIUM:
			return 2
		MatchConfig.AIDifficulty.HARD:
			# Hard entrants independently roll Epic or Legendary when spawned.
			return randi_range(3, 4)
		_:
			return 1
