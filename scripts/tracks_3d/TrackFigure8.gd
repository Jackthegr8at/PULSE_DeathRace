extends Track3DBase
## Hand-painted track scene (name is historical — does NOT rebuild the GridMap).
## Edit GridMap + SpawnPoint in TrackFigure8.tscn; this script only runs shared
## path / crate / finish logic from Track3DBase.


func _ready() -> void:
	track_display_name = "Figure-8 Chaos"
	# Do NOT clear or repaint GridMap — your editor layout is the source of truth.
	super._ready()
