extends Node
## Global match settings written by Setup and read by Main / HUD / cars.
## Autoload name: MatchConfig

enum Mode {
	HYBRID, ## Win by finishing laps first OR being last car standing
	RACE, ## Win only by finishing required laps first
	LAST_STANDING, ## Win only by eliminating all other cars (no laps)
}

## Active ruleset for the next / current race.
var mode: Mode = Mode.HYBRID

## Laps required to win by race finish. Ignored when mode == LAST_STANDING.
var lap_count: int = 5

## Number of AI opponents to spawn (fixed at 4 for phase 1).
var ai_count: int = 4

## Path to the track scene to instance in Main.
var track_scene_path: String = "res://scenes/tracks/Figure8.tscn"


func uses_laps() -> bool:
	## True when lap counter and race-finish win are active.
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


func reset_to_defaults() -> void:
	mode = Mode.HYBRID
	lap_count = 5
	ai_count = 4
	track_scene_path = "res://scenes/tracks/Figure8.tscn"
