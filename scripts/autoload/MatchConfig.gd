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
var ai_count: int = 0 ## AI combat comes next; 0 = solo drive for now
var track_id: TrackId = TrackId.KENNEY_DEFAULT


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


func reset_to_defaults() -> void:
	mode = Mode.HYBRID
	lap_count = 5
	ai_count = 0
	track_id = TrackId.KENNEY_DEFAULT
