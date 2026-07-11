class_name CarVisuals
extends RefCounted
## Shared sprite paths for stylized cel-shaded cars.

const PLAYER := "res://assets/sprites/car_player_green_v2.png"
const AI_RED := "res://assets/sprites/car_ai_red.png"
const AI_BLUE := "res://assets/sprites/car_ai_blue.png"
const AI_PURPLE := "res://assets/sprites/car_ai_purple.png"
const AI_ORANGE := "res://assets/sprites/car_ai_orange.png"

const AI_LIST: Array[String] = [AI_RED, AI_BLUE, AI_PURPLE, AI_ORANGE]


static func load_texture(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null
