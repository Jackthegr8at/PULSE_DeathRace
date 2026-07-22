extends Node
## Global match settings for 3D DeathRace (Kenney base).
## Autoload name: MatchConfig

enum Mode {
	HYBRID,
	RACE,
	LAST_STANDING,
}

enum TrackId {
	KENNEY_DEFAULT, ## Original starter-kit GridMap
	FIGURE_8, ## New figure-8 course
}

enum AIDifficulty {
	NOVICE,
	MEDIUM,
	HARD,
}

const TRACK_PATHS := {
	TrackId.KENNEY_DEFAULT: "res://scenes/tracks_3d/TrackDefault.tscn",
	TrackId.FIGURE_8: "res://scenes/tracks_3d/TrackFigure8.tscn",
}

const TRACK_DISPLAY := {
	TrackId.KENNEY_DEFAULT: "Starter Circuit",
	TrackId.FIGURE_8: "Figure-8 Chaos",
}

const AI_PROFILES: Dictionary = {
	AIDifficulty.NOVICE: {
		"throttle_base": 0.72,
		"throttle_step": 0.04,
		"corner_throttle": 0.46,
		"steer_gain": 2.10,
		"detect_range": 22.0,
		"aim_steer_weight": 0.72,
		"aim_time_max": 0.40,
		"fire_dot_min": 0.93,
	},
	AIDifficulty.MEDIUM: {
		"throttle_base": 0.84,
		"throttle_step": 0.04,
		"corner_throttle": 0.62,
		"steer_gain": 2.35,
		"detect_range": 25.0,
		"aim_steer_weight": 0.82,
		"aim_time_max": 0.55,
		"fire_dot_min": 0.94,
	},
	AIDifficulty.HARD: {
		"throttle_base": 0.94,
		"throttle_step": 0.03,
		"corner_throttle": 0.75,
		"steer_gain": 2.60,
		"detect_range": 28.0,
		"aim_steer_weight": 0.92,
		"aim_time_max": 0.75,
		"fire_dot_min": 0.96,
	},
}

var mode: Mode = Mode.HYBRID
var lap_count: int = 5
var ai_count: int = 3
var ai_difficulty: AIDifficulty = AIDifficulty.NOVICE
var track_id: TrackId = TrackId.KENNEY_DEFAULT

## Missile crate settings (Setup menu)
var crate_count: int = 5 ## How many crates spawn on the track
var missiles_per_crate: int = 2 ## Ammo granted when collecting one crate

## Strong references retained while moving through the loading screen. Keeping
## these resources alive means Race3D's existing load() calls reuse Godot's
## cache instead of loading the track and vehicle scenes a second time.
var loading_resources: Dictionary = {}
var loading_started_msec: int = 0


func uses_laps() -> bool:
	return mode != Mode.LAST_STANDING


func mode_display_name() -> String:
	match mode:
		Mode.HYBRID:
			return "Hybrid"
		Mode.RACE:
			return "Race"
		Mode.LAST_STANDING:
			return "Last Standing"
		_:
			return "Unknown"


func track_display_name() -> String:
	return TRACK_DISPLAY.get(track_id, "Track")


func track_scene_path() -> String:
	return TRACK_PATHS.get(track_id, TRACK_PATHS[TrackId.KENNEY_DEFAULT])


func ai_profile() -> Dictionary:
	return AI_PROFILES.get(ai_difficulty, AI_PROFILES[AIDifficulty.NOVICE]) as Dictionary


func ai_difficulty_display_name() -> String:
	match ai_difficulty:
		AIDifficulty.NOVICE:
			return "Novice"
		AIDifficulty.MEDIUM:
			return "Medium"
		AIDifficulty.HARD:
			return "Hard"
		_:
			return "Novice"


func begin_race_loading() -> void:
	loading_resources.clear()
	loading_started_msec = Time.get_ticks_msec()


func retain_loading_resource(path: String, resource: Resource) -> void:
	if resource != null:
		loading_resources[path] = resource


func get_loading_resource(path: String) -> Resource:
	return loading_resources.get(path) as Resource


func clear_loading_resources() -> void:
	loading_resources.clear()
	loading_started_msec = 0


func reset_to_defaults() -> void:
	mode = Mode.HYBRID
	lap_count = 5
	ai_count = 3
	ai_difficulty = AIDifficulty.NOVICE
	track_id = TrackId.KENNEY_DEFAULT
	crate_count = 5
	missiles_per_crate = 2
