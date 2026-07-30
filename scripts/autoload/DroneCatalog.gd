extends Node
## Authoritative drone metadata shared by progression, race spawning, and UI.

const SCRAPJAW_ID := "scrapjaw"
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
