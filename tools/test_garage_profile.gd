extends Node
## Local-only profile and unlock progression checks.

const TEST_PATH := "user://garage_profile_test.json"
var failures: int = 0


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	if FileAccess.file_exists(TEST_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))
	GarageProfile.reset_profile_for_tests(TEST_PATH)

	_expect(GarageProfile.selected_vehicle_id() == "ravage", "fresh profile selects Ravage")
	_expect(GarageProfile.is_vehicle_unlocked("ravage"), "Ravage starts unlocked")
	_expect(not GarageProfile.is_vehicle_unlocked("bulldoze"), "Bulldoze starts locked")
	_expect(not GarageProfile.select_vehicle("wraith"), "locked vehicle cannot be selected")

	var no_commit := GarageProfile.commit_completed_race({
		"race_id": "abandoned",
		"completed": false,
		"player_first": true,
		"player_kills_by_vehicle_id": {"bulldoze": 20},
	})
	_expect(no_commit.is_empty(), "abandoned race does not commit")

	var bulldoze_unlock := GarageProfile.commit_completed_race({
		"race_id": "race-bulldoze",
		"completed": true,
		"player_first": false,
		"player_kills_by_vehicle_id": {"bulldoze": 20},
	})
	_expect("bulldoze" in bulldoze_unlock, "Bulldoze unlocks at 20 Bulldoze kills")
	_expect(GarageProfile.select_vehicle("bulldoze"), "unlocked Bulldoze can be selected")
	_expect(GarageProfile.selected_vehicle_id() == "bulldoze", "Bulldoze selection persists in memory")
	GarageProfile.load_profile()
	_expect(GarageProfile.selected_vehicle_id() == "bulldoze", "Bulldoze selection persists after reload")
	var roster := VehicleCatalog.get_ai_roster(GarageProfile.selected_vehicle_id(), 3)
	_expect(roster.size() == 3, "three AI vehicles are resolved")
	_expect("bulldoze" not in roster, "selected player vehicle is excluded from AI roster")

	var duplicate := GarageProfile.commit_completed_race({
		"race_id": "race-bulldoze",
		"completed": true,
		"player_first": true,
		"player_kills_by_vehicle_id": {"wraith": 50},
	})
	_expect(duplicate.is_empty(), "duplicate race ID is rejected")
	_expect(int(GarageProfile.stats().get("first_place_finishes", 0)) == 0, "duplicate does not increment wins")

	for index in 20:
		GarageProfile.commit_completed_race({
			"race_id": "win-%d" % index,
			"completed": true,
			"player_first": true,
			"player_kills_by_vehicle_id": {},
		})
	_expect(GarageProfile.is_vehicle_unlocked("venom"), "Venom unlocks at 20 first-place finishes")

	GarageProfile.commit_completed_race({
		"race_id": "race-wraith",
		"completed": true,
		"player_first": false,
		"player_kills_by_vehicle_id": {"wraith": 30},
	})
	_expect(GarageProfile.is_vehicle_unlocked("wraith"), "Wraith unlocks at 50 total kills")

	GarageProfile.profile["selected_vehicle_id"] = "missing-car"
	_expect(GarageProfile.selected_vehicle_id() == "ravage", "invalid selected ID falls back to Ravage")

	if FileAccess.file_exists(TEST_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))
	if failures == 0:
		print("[GarageProfileTest] PASS")
		get_tree().quit(0)
	else:
		push_error("[GarageProfileTest] %d checks failed" % failures)
		get_tree().quit(1)


func _expect(condition: bool, label: String) -> void:
	if condition:
		print("[GarageProfileTest] OK: %s" % label)
		return
	failures += 1
	push_error("[GarageProfileTest] FAIL: %s" % label)
