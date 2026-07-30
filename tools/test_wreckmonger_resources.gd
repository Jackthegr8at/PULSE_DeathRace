extends Node
## Local-only smoke test for Wreckmonger resources and Scrap Harvest.

const WRECKMONGER_SCENE_PATH := "res://scenes/vehicles/WreckmongerModular.tscn"
const VEHICLE_SCENE_PATH := "res://scenes/vehicle.tscn"


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var wreckmonger_scene := load(WRECKMONGER_SCENE_PATH) as PackedScene
	var vehicle_scene := load(VEHICLE_SCENE_PATH) as PackedScene
	if wreckmonger_scene == null or vehicle_scene == null:
		push_error("[WreckmongerResourceTest] required scene failed to load")
		get_tree().quit(1)
		return

	var visual := wreckmonger_scene.instantiate()
	var near_wreckmonger := vehicle_scene.instantiate() as Vehicle
	var distant_wreckmonger := vehicle_scene.instantiate() as Vehicle
	near_wreckmonger.vehicle_type = Vehicle.VehicleType.WRECKMONGER
	distant_wreckmonger.vehicle_type = Vehicle.VehicleType.WRECKMONGER
	add_child(visual)
	add_child(near_wreckmonger)
	add_child(distant_wreckmonger)

	var entry := VehicleCatalog.get_vehicle("wreckmonger")
	var valid := (
		str(entry.get("scene_path", "")) == WRECKMONGER_SCENE_PATH
		and int(entry.get("vehicle_type", -1)) == Vehicle.VehicleType.WRECKMONGER
		and visual.get_node_or_null("WeaponAnchor") != null
		and visual.get_node_or_null("ExhaustAnchor") != null
		and visual.get_node_or_null("WheelFrontLeft/Wheel") != null
		and visual.get_node_or_null("WheelFrontRight/Wheel") != null
		and visual.get_node_or_null("WheelBackLeft/Wheel") != null
		and visual.get_node_or_null("WheelBackRight/Wheel") != null
	)

	near_wreckmonger.position = Vector3.ZERO
	distant_wreckmonger.position = Vector3(20.01, 0.0, 0.0)
	valid = valid and near_wreckmonger.can_scrap_harvest(Vector3(20.0, 0.0, 0.0))
	valid = valid and not distant_wreckmonger.can_scrap_harvest(Vector3.ZERO)

	near_wreckmonger.health = near_wreckmonger.max_health * 0.50
	near_wreckmonger.missile_ammo = 0
	valid = valid and near_wreckmonger.apply_scrap_harvest()
	valid = valid and is_equal_approx(
		near_wreckmonger.health,
		near_wreckmonger.max_health * 0.75,
	)
	valid = valid and near_wreckmonger.missile_ammo == 2

	near_wreckmonger.health = near_wreckmonger.max_health - 1.0
	near_wreckmonger.missile_ammo = near_wreckmonger.max_missile_ammo - 1
	valid = valid and near_wreckmonger.apply_scrap_harvest()
	valid = valid and is_equal_approx(near_wreckmonger.health, near_wreckmonger.max_health)
	valid = valid and near_wreckmonger.missile_ammo == near_wreckmonger.max_missile_ammo

	if not valid:
		push_error("[WreckmongerResourceTest] catalog, scene, range, or harvest contract failed")
		get_tree().quit(1)
		return

	print("[WreckmongerResourceTest] PASS")
	get_tree().quit(0)
