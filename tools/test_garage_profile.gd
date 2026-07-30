extends Node
## Local-only profile and unlock progression checks.

const TEST_PATH := "res://.godot/garage_profile_test.json"
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
	_expect(not GarageProfile.is_vehicle_unlocked("specter"), "Specter starts locked")
	_expect(not GarageProfile.is_vehicle_unlocked("molten"), "Molten starts locked")
	_expect(not GarageProfile.is_vehicle_unlocked("thunderclaw"), "Thunderclaw starts locked")
	_expect(not GarageProfile.is_vehicle_unlocked("torrent"), "Torrent starts locked")
	_expect(not GarageProfile.is_vehicle_unlocked("wreckmonger"), "Wreckmonger starts locked")
	_expect(
		int(GarageProfile.stats().get("hybrid_wins", -1)) == 0,
		"profiles without Hybrid history migrate to zero Hybrid wins",
	)
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
	var ai_candidates := VehicleCatalog.get_ai_candidate_ids(GarageProfile.selected_vehicle_id())
	_expect("specter" in ai_candidates, "Specter is eligible for the AI rotation")
	_expect("molten" in ai_candidates, "Molten is eligible for the AI rotation")
	_expect("thunderclaw" in ai_candidates, "Thunderclaw is eligible for the AI rotation")
	_expect("torrent" in ai_candidates, "Torrent is eligible for the AI rotation")
	_expect("wreckmonger" in ai_candidates, "Wreckmonger is eligible for the AI rotation")
	_expect(ai_candidates.size() == 8, "all eight non-player vehicles are AI candidates")
	MatchConfig.ai_count = 3
	MatchConfig.begin_race_loading()
	var loading_roster := MatchConfig.ai_vehicle_ids()
	_expect(
		loading_roster == MatchConfig.ai_vehicle_ids(),
		"AI rotation stays stable throughout race loading",
	)
	MatchConfig.clear_loading_resources()

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
			"difficulty": MatchConfig.AIDifficulty.NOVICE,
			"player_kills_by_vehicle_id": {},
		})
	_expect(GarageProfile.is_vehicle_unlocked("venom"), "Venom unlocks at 20 first-place finishes")
	_expect(not GarageProfile.is_vehicle_unlocked("specter"), "non-Hard wins do not unlock Specter")

	for index in 9:
		GarageProfile.commit_completed_race({
			"race_id": "hard-win-%d" % index,
			"completed": true,
			"player_first": true,
			"difficulty": MatchConfig.AIDifficulty.HARD,
			"player_kills_by_vehicle_id": {},
		})
	_expect(not GarageProfile.is_vehicle_unlocked("specter"), "Specter remains locked after 9 Hard wins")
	var specter_unlock := GarageProfile.commit_completed_race({
		"race_id": "hard-win-9",
		"completed": true,
		"player_first": true,
		"difficulty": MatchConfig.AIDifficulty.HARD,
		"player_kills_by_vehicle_id": {},
	})
	_expect("specter" in specter_unlock, "Specter unlocks at 10 Hard first-place finishes")

	for index in 9:
		GarageProfile.commit_completed_race({
			"race_id": "last-standing-win-%d" % index,
			"completed": true,
			"player_first": true,
			"mode": MatchConfig.Mode.LAST_STANDING,
			"player_kills_by_vehicle_id": {},
		})
	_expect(not GarageProfile.is_vehicle_unlocked("molten"), "Molten remains locked after 9 Last Standing wins")
	var molten_unlock := GarageProfile.commit_completed_race({
		"race_id": "last-standing-win-9",
		"completed": true,
		"player_first": true,
		"mode": MatchConfig.Mode.LAST_STANDING,
		"player_kills_by_vehicle_id": {},
	})
	_expect("molten" in molten_unlock, "Molten unlocks at 10 Last Standing wins")

	for index in 14:
		GarageProfile.commit_completed_race({
			"race_id": "hybrid-win-%d" % index,
			"completed": true,
			"player_first": true,
			"mode": MatchConfig.Mode.HYBRID,
			"player_kills_by_vehicle_id": {},
		})
	_expect(
		not GarageProfile.is_vehicle_unlocked("thunderclaw"),
		"Thunderclaw remains locked after 14 Hybrid wins",
	)
	var thunderclaw_unlock := GarageProfile.commit_completed_race({
		"race_id": "hybrid-win-14",
		"completed": true,
		"player_first": true,
		"mode": MatchConfig.Mode.HYBRID,
		"player_kills_by_vehicle_id": {},
	})
	_expect(
		"thunderclaw" in thunderclaw_unlock,
		"Thunderclaw unlocks at 15 Hybrid wins",
	)

	GarageProfile.commit_completed_race({
		"race_id": "torrent-hits-99",
		"completed": true,
		"player_first": false,
		"direct_missile_hits": 99,
		"player_kills_by_vehicle_id": {},
	})
	_expect(not GarageProfile.is_vehicle_unlocked("torrent"), "Torrent remains locked after 99 direct hits")
	var torrent_unlock := GarageProfile.commit_completed_race({
		"race_id": "torrent-hit-100",
		"completed": true,
		"player_first": false,
		"direct_missile_hits": 1,
		"player_kills_by_vehicle_id": {},
	})
	_expect("torrent" in torrent_unlock, "Torrent unlocks at 100 direct missile hits")

	GarageProfile.commit_completed_race({
		"race_id": "race-wraith",
		"completed": true,
		"player_first": false,
		"player_kills_by_vehicle_id": {"wraith": 30},
	})
	_expect(GarageProfile.is_vehicle_unlocked("wraith"), "Wraith unlocks at 50 total kills")

	GarageProfile.commit_completed_race({
		"race_id": "wreckmonger-kills-74",
		"completed": true,
		"player_first": false,
		"player_kills_by_vehicle_id": {"ravage": 24},
	})
	_expect(
		not GarageProfile.is_vehicle_unlocked("wreckmonger"),
		"Wreckmonger remains locked after 74 total kills",
	)
	var wreckmonger_unlock := GarageProfile.commit_completed_race({
		"race_id": "wreckmonger-kill-75",
		"completed": true,
		"player_first": false,
		"player_kills_by_vehicle_id": {"ravage": 1},
	})
	_expect(
		"wreckmonger" in wreckmonger_unlock,
		"Wreckmonger unlocks at 75 total kills",
	)

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
