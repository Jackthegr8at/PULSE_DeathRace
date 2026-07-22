extends SceneTree

var rematch_emitted := false
var setup_emitted := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var packed := load("res://scenes/ui/EndScreen.tscn") as PackedScene
	if not _check(packed != null, "EndScreen scene did not load"):
		return
	var screen := packed.instantiate()
	root.add_child(screen)
	screen.rematch_requested.connect(func() -> void: rematch_emitted = true)
	screen.setup_requested.connect(func() -> void: setup_emitted = true)
	screen.show_results({
		"title": "2ND PLACE",
		"player_won": false,
		"player_place": 2,
		"detail": "You finished 2nd.",
		"race_time": 200.06,
		"uses_laps": true,
		"laps_done": 5,
		"lap_total": 5,
		"difficulty": "MEDIUM",
		"survivors": 3,
		"results": [
			{"place": 1, "name": "AI-3", "status": "FINISHED", "finish_time": 198.42},
			{"place": 2, "name": "Player", "status": "FINISHED", "finish_time": 200.06, "is_player": true},
			{"place": 3, "name": "AI-1", "status": "ESTIMATED"},
			{"place": 0, "name": "AI-2", "status": "DNF"},
		],
	})
	if not _check(screen.visible, "EndScreen did not become visible"):
		return
	if not _check(screen.get_node("DesignRoot/Card/Content/VBox/TitleLabel").text == "2ND PLACE", "Result title mismatch"):
		return
	if not _check(screen.get_node("DesignRoot/Card/Content/VBox/Summary/TimeStat/TimeValue").text == "03:20.06", "Player time mismatch"):
		return
	var results := screen.get_node("DesignRoot/Card/Content/VBox/OrderScroll/ResultsList")
	if not _check(results.get_child_count() == 4, "Expected four result rows"):
		return
	if not _check(results.get_child(0).get_child(0).get_child(2).text == "03:18.42", "Finished AI time mismatch"):
		return
	if not _check(results.get_child(2).get_child(0).get_child(2).text == "EST.", "Estimated status mismatch"):
		return
	if not _check(results.get_child(3).get_child(0).get_child(2).text == "DNF", "DNF status mismatch"):
		return
	var design_root: Control = screen.get_node("DesignRoot")
	var displayed_size := design_root.size * design_root.scale
	if not _check(displayed_size.x <= 1280.0 and displayed_size.y <= 720.0, "Responsive card exceeds 1280x720"):
		return
	screen.get_node("DesignRoot/Card/Content/VBox/Buttons/RematchButton").pressed.emit()
	screen.get_node("DesignRoot/Card/Content/VBox/Buttons/SetupButton").pressed.emit()
	if not _check(rematch_emitted and setup_emitted, "Navigation signals were not emitted"):
		return
	print("[EndScreenSmoke] PASS size=%s scale=%.3f" % [displayed_size, design_root.scale.x])
	quit(0)


func _check(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error("[EndScreenSmoke] FAIL: %s" % message)
	quit(1)
	return false
