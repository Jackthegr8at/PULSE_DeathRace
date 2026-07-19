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

const TRACK_PATHS := {
	TrackId.KENNEY_DEFAULT: "res://scenes/tracks_3d/TrackDefault.tscn",
	TrackId.FIGURE_8: "res://scenes/tracks_3d/TrackFigure8.tscn",
}

const TRACK_DISPLAY := {
	TrackId.KENNEY_DEFAULT: "Starter Circuit",
	TrackId.FIGURE_8: "Figure-8 Chaos",
}

var mode: Mode = Mode.HYBRID
var lap_count: int = 5
var ai_count: int = 3
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
	track_id = TrackId.KENNEY_DEFAULT
	crate_count = 5
	missiles_per_crate = 2
