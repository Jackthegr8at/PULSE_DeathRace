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
	_expect(not DroneCatalog.is_tier_available("welder", 2), "Welder Tier 2 is coming soon")
	_expect(not DroneCatalog.is_tier_available("welder", 3), "Welder Tier 3 is coming soon")
	_expect(not DroneCatalog.is_tier_available("welder", 4), "Welder Tier 4 is coming soon")
	_expect(
		DroneCatalog.get_attack_type("welder") == "repair_beam",
		"Welder uses the repair-beam strategy",
	)

	var novice := GarageProfile.calculate_credit_reward({
		"player_place": 1,
		"player_eliminations": 2,
		"player_drone_eliminations": 1,
		"difficulty": MatchConfig.AIDifficulty.NOVICE,
	})
	_expect(int(novice.get("total", -1)) == 22, "Novice reward uses fixed payout table")
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

	var welder_path := DroneCatalog.get_scene_path("welder", 1)
	var welder_model_scene := load(welder_path) as PackedScene
	_expect(welder_model_scene != null, "Welder Tier 1 model loads")
	if welder_model_scene:
		var welder_model := welder_model_scene.instantiate()
		_expect(welder_model != null, "Welder Tier 1 model instantiates")
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
			welder_controller.configure(welder_owner, DroneCatalog.WELDER_ID, 1),
			"DroneController configures Welder Tier 1",
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
			is_equal_approx(welder_owner.health, 62.0),
			"Welder restores 12 percent maximum health over three seconds",
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
