extends Node
## Focused checks for drone progression, rewards, resources, and Drone Bay startup.

const TEST_PATH := "res://.godot/drone_credit_profile_test.json"
var failures := 0


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	if FileAccess.file_exists(TEST_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))
	GarageProfile.reset_profile_for_tests(TEST_PATH)

	_expect(GarageProfile.credit_balance() == 0, "fresh wallet starts at zero")
	_expect(
		str(GarageProfile.equipped_drone().get("id", "")).is_empty(),
		"fresh profile has no equipped drone",
	)
	_expect(not GarageProfile.owns_drone_tier("scrapjaw", 1), "Scrapjaw starts unowned")
	_expect(not GarageProfile.can_purchase_drone_tier("scrapjaw", 2), "tiers purchase sequentially")
	_expect(
		is_equal_approx(DroneCatalog.get_model_yaw_degrees("scrapjaw"), 90.0),
		"Scrapjaw visual uses its authored +X forward-axis correction",
	)
	_expect(DroneCatalog.has_drone("bomblet"), "Bomblet is registered")
	_expect(DroneCatalog.is_tier_available("bomblet", 1), "Bomblet Tier 1 is available")
	_expect(DroneCatalog.is_tier_available("bomblet", 2), "Bomblet Tier 2 is available")
	_expect(DroneCatalog.is_tier_available("bomblet", 3), "Bomblet Tier 3 is available")
	_expect(DroneCatalog.is_tier_available("bomblet", 4), "Bomblet Tier 4 is available")
	_expect(DroneCatalog.has_drone("welder"), "Welder is registered")
	_expect(DroneCatalog.get_all_ids().has("welder"), "Welder participates in AI drone rotation")
	_expect(DroneCatalog.is_tier_available("welder", 1), "Welder Tier 1 is available")
	_expect(DroneCatalog.is_tier_available("welder", 2), "Welder Tier 2 is available")
	_expect(DroneCatalog.is_tier_available("welder", 3), "Welder Tier 3 is available")
	_expect(DroneCatalog.is_tier_available("welder", 4), "Welder Tier 4 is available")
	_expect(
		DroneCatalog.get_attack_type("welder") == "repair_beam",
		"Welder uses the repair-beam strategy",
	)
	var expected_welder_healing := [0.12, 0.13, 0.14, 0.15]
	var expected_welder_cooldowns := [12.0, 10.0, 8.0, 6.0]
	for tier in range(DroneCatalog.MIN_TIER, DroneCatalog.MAX_TIER + 1):
		var tier_data := DroneCatalog.get_tier("welder", tier)
		_expect(
			is_equal_approx(float(tier_data.get("heal_ratio", 0.0)), expected_welder_healing[tier - 1]),
			"Welder Tier %d uses the approved healing ratio" % tier,
		)
		_expect(
			is_equal_approx(float(tier_data.get("cooldown", 0.0)), expected_welder_cooldowns[tier - 1]),
			"Welder Tier %d uses the approved cooldown" % tier,
		)
		_expect(
			is_equal_approx(float(tier_data.get("beam_duration", 0.0)), 3.0),
			"Welder Tier %d keeps the three-second repair duration" % tier,
		)

	var novice := GarageProfile.calculate_credit_reward({
		"player_place": 1,
		"player_eliminations": 2,
		"player_drone_eliminations": 1,
		"difficulty": MatchConfig.AIDifficulty.NOVICE,
	})
	_expect(int(novice.get("total", -1)) == 22, "Novice reward uses fixed payout table")
	var last_standing_winner := GarageProfile.calculate_credit_reward({
		"player_first": true,
		"player_place": 0,
		"player_eliminations": 0,
		"player_drone_eliminations": 0,
		"difficulty": MatchConfig.AIDifficulty.NOVICE,
	})
	_expect(
		int(last_standing_winner.get("placement_reward", -1)) == 10
			and int(last_standing_winner.get("total", -1)) == 10,
		"Last Standing winner receives the first-place credit reward without a lap place",
	)
	var medium := GarageProfile.calculate_credit_reward({
		"player_place": 2,
		"player_eliminations": 1,
		"player_drone_eliminations": 1,
		"difficulty": MatchConfig.AIDifficulty.MEDIUM,
	})
	_expect(int(medium.get("total", -1)) == 15, "Medium reward rounds after x1.25")
	var hard := GarageProfile.calculate_credit_reward({
		"player_place": 3,
		"player_eliminations": 1,
		"player_drone_eliminations": 0,
		"difficulty": MatchConfig.AIDifficulty.HARD,
	})
	_expect(int(hard.get("total", -1)) == 11, "Hard reward rounds after x1.5")

	var credits := GarageProfile.profile.get("credits", {}) as Dictionary
	credits["balance"] = 100
	GarageProfile.profile["credits"] = credits
	_expect(GarageProfile.purchase_drone_tier("scrapjaw", 1), "Tier 1 can be purchased")
	_expect(GarageProfile.credit_balance() == 0, "purchase deducts the tier price")
	_expect(GarageProfile.equip_drone("scrapjaw", 1), "owned tier can be equipped")
	_expect(
		int(GarageProfile.equipped_drone().get("tier", 0)) == 1,
		"equipped tier persists in profile state",
	)

	var before_commit := GarageProfile.credit_balance()
	GarageProfile.commit_completed_race({
		"race_id": "drone-credit-race",
		"completed": true,
		"player_first": true,
		"player_place": 1,
		"player_eliminations": 1,
		"player_drone_eliminations": 1,
		"difficulty": MatchConfig.AIDifficulty.NOVICE,
		"player_kills_by_vehicle_id": {},
	})
	_expect(
		GarageProfile.credit_balance() == before_commit + 17,
		"confirmed race atomically awards credits",
	)
	var after_commit := GarageProfile.credit_balance()
	GarageProfile.commit_completed_race({
		"race_id": "drone-credit-race",
		"completed": true,
		"player_first": true,
		"player_place": 1,
		"player_eliminations": 99,
		"player_drone_eliminations": 99,
		"difficulty": MatchConfig.AIDifficulty.HARD,
		"player_kills_by_vehicle_id": {},
	})
	_expect(GarageProfile.credit_balance() == after_commit, "duplicate race does not pay twice")

	var stats_before_practice := GarageProfile.stats()
	GarageProfile.commit_completed_race({
		"race_id": "one-lap-practice-race",
		"completed": true,
		"player_first": true,
		"player_place": 1,
		"player_eliminations": 4,
		"player_drone_eliminations": 2,
		"direct_missile_hits": 50,
		"difficulty": MatchConfig.AIDifficulty.HARD,
		"mode": MatchConfig.Mode.HYBRID,
		"rewards_enabled": false,
		"player_kills_by_vehicle_id": {"bulldoze": 4},
	})
	_expect(
		GarageProfile.credit_balance() == after_commit,
		"one-lap practice race awards no credits",
	)
	_expect(
		GarageProfile.stats() == stats_before_practice,
		"one-lap practice race advances no persistent unlock statistics",
	)
	var practice_commit := GarageProfile.last_commit_result()
	var practice_reward := practice_commit.get("credit_reward", {}) as Dictionary
	_expect(
		bool(practice_commit.get("committed", false))
			and not bool(practice_reward.get("rewards_enabled", true))
			and int(practice_reward.get("total", -1)) == 0,
		"one-lap practice result is recorded and identified as reward-disabled",
	)

	for tier in range(DroneCatalog.MIN_TIER, DroneCatalog.MAX_TIER + 1):
		var path := DroneCatalog.get_scene_path("scrapjaw", tier)
		var packed := load(path) as PackedScene
		_expect(packed != null, "Scrapjaw Tier %d model loads" % tier)
		if packed:
			var model := packed.instantiate()
			_expect(model != null, "Scrapjaw Tier %d model instantiates" % tier)
			if model:
				model.free()

	for tier in range(DroneCatalog.MIN_TIER, DroneCatalog.MAX_TIER + 1):
		var path := DroneCatalog.get_scene_path("bomblet", tier)
		var packed := load(path) as PackedScene
		_expect(packed != null, "Bomblet Tier %d model loads" % tier)
		if packed:
			var model := packed.instantiate()
			_expect(model != null, "Bomblet Tier %d model instantiates" % tier)
			if model:
				model.free()

	for tier in range(DroneCatalog.MIN_TIER, DroneCatalog.MAX_TIER + 1):
		var welder_path := DroneCatalog.get_scene_path("welder", tier)
		var welder_model_scene := load(welder_path) as PackedScene
		_expect(welder_model_scene != null, "Welder Tier %d model loads" % tier)
		if welder_model_scene:
			var welder_model := welder_model_scene.instantiate()
			_expect(welder_model != null, "Welder Tier %d model instantiates" % tier)
			if welder_model:
				welder_model.free()

	var repair_vehicle := Vehicle.new()
	repair_vehicle.max_health = 100.0
	repair_vehicle.health = 50.0
	_expect(repair_vehicle.restore_health(12.0), "Vehicle accepts Welder repair health")
	_expect(is_equal_approx(repair_vehicle.health, 62.0), "Welder repair amount is applied")
	_expect(repair_vehicle.restore_health(100.0), "Vehicle accepts a repair that reaches full health")
	_expect(is_equal_approx(repair_vehicle.health, 100.0), "Welder repair clamps at maximum health")
	repair_vehicle.free()

	var mine_scene := load("res://scenes/drones/BombletMine.tscn") as PackedScene
	_expect(mine_scene != null, "Bomblet mine scene loads")
	if mine_scene:
		var mine := mine_scene.instantiate()
		_expect(mine is BombletMine, "Bomblet mine scene has the expected script")
		mine.free()

	var controller_scene := load("res://scenes/drones/DroneController.tscn") as PackedScene
	_expect(controller_scene != null, "DroneController scene loads")
	if controller_scene:
		var controller := controller_scene.instantiate()
		_expect(controller is DroneController, "DroneController scene has the expected script")
		controller.free()
		var vehicle_scene := load("res://scenes/vehicle.tscn") as PackedScene
		_expect(vehicle_scene != null, "Vehicle scene loads for Welder behavior test")
		var welder_owner := vehicle_scene.instantiate() as Vehicle
		var welder_controller := controller_scene.instantiate() as DroneController
		add_child(welder_owner)
		add_child(welder_controller)
		await get_tree().process_frame
		welder_owner.max_health = 100.0
		welder_owner.health = 50.0
		welder_owner.race_started = true
		welder_owner.match_over = false
		welder_owner.has_finished_race = false
		_expect(
			welder_controller.configure(welder_owner, DroneCatalog.WELDER_ID, 4),
			"DroneController configures Welder Tier 4",
		)
		_expect(
			welder_controller.get_node_or_null("RepairBeamAbility") is WelderRepairBeam,
			"DroneController creates the Welder repair strategy",
		)
		welder_controller.set_process(false)
		var repair_ability := welder_controller.get_node_or_null("RepairBeamAbility") as WelderRepairBeam
		if repair_ability:
			repair_ability.tick(1.0)
			for repair_step in range(12):
				repair_ability.tick(0.25)
		_expect(
			is_equal_approx(welder_owner.health, 65.0),
			"Welder Tier 4 restores 15 percent maximum health over three seconds",
		)
		var world_hp_fill := welder_owner.get_node_or_null("HealthBar3D/Fill") as MeshInstance3D
		_expect(world_hp_fill != null, "Vehicle exposes its world-space health fill")
		if world_hp_fill:
			_expect(
				is_equal_approx(world_hp_fill.scale.x, 0.65),
				"Welder healing synchronizes the world-space health bar",
			)
		welder_controller.queue_free()
		welder_owner.queue_free()
		await get_tree().process_frame

	var bay_scene := load("res://scenes/DroneBay.tscn") as PackedScene
	_expect(bay_scene != null, "Drone Bay scene loads")
	if bay_scene:
		var bay := bay_scene.instantiate()
		_expect(bay.get_script() != null, "Drone Bay script loads")
		add_child(bay)
		await get_tree().process_frame
		await get_tree().process_frame
		_expect(is_instance_valid(bay), "Drone Bay initializes")
		bay.queue_free()
		await get_tree().process_frame

	var previous_mode := MatchConfig.mode
	var previous_lap_count := MatchConfig.lap_count
	MatchConfig.mode = MatchConfig.Mode.HYBRID
	MatchConfig.lap_count = 1
	var setup_scene := load("res://scenes/Setup.tscn") as PackedScene
	_expect(setup_scene != null, "Setup scene loads for practice warning test")
	if setup_scene:
		var setup := setup_scene.instantiate()
		add_child(setup)
		await get_tree().process_frame
		await get_tree().process_frame
		var practice_warning := setup.find_child("PracticeWarning", true, false) as Label
		_expect(
			practice_warning != null and practice_warning.visible,
			"one-lap Hybrid setup visibly warns that rewards are disabled",
		)
		_expect(setup.find_child("AiCountMinus", true, false) is Button, "Setup exposes the AI count decrement control")
		_expect(setup.find_child("AiCountPlus", true, false) is Button, "Setup exposes the AI count increment control")
		_expect(setup.find_child("CratesToggle", true, false) is Button, "Setup exposes the crate live toggle")
		_expect(setup.find_child("AiDifficultyHeading", true, false) is Label, "AI difficulty occupies the first lower panel")
		_expect(setup.find_child("DroneBay", true, false) is Button, "Drone Bay occupies the second lower panel")
		_expect(setup.find_child("Garage", true, false) is Button, "Garage occupies the third lower panel")
		_expect(setup.find_child("RaceTypeValue", true, false) == null, "legacy race-type lower-panel value is removed")
		_expect(setup.find_child("OpponentsValue", true, false) == null, "legacy opponents lower-panel value is removed")
		setup.queue_free()
		await get_tree().process_frame
	MatchConfig.mode = previous_mode
	MatchConfig.lap_count = previous_lap_count

	if FileAccess.file_exists(TEST_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))
	if failures == 0:
		print("[DroneCreditTest] PASS")
		get_tree().quit(0)
	else:
		push_error("[DroneCreditTest] %d checks failed" % failures)
		get_tree().quit(1)


func _expect(condition: bool, label: String) -> void:
	if condition:
		print("[DroneCreditTest] OK: %s" % label)
		return
	failures += 1
	push_error("[DroneCreditTest] FAIL: %s" % label)
