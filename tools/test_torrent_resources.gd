extends Node
## Local-only smoke test for Torrent and the reusable homing projectile.

const TORRENT_SCENE_PATH := "res://scenes/vehicles/TorrentModular.tscn"
const HOMING_SCENE_PATH := "res://scenes/combat/HomingMissile3D.tscn"
const RACE_SCRIPT_PATH := "res://scripts/race/Race3D.gd"


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var torrent_scene := load(TORRENT_SCENE_PATH) as PackedScene
	var homing_scene := load(HOMING_SCENE_PATH) as PackedScene
	var race_script := load(RACE_SCRIPT_PATH) as Script
	if torrent_scene == null or homing_scene == null or race_script == null:
		push_error("[TorrentResourceTest] required scene failed to load")
		get_tree().quit(1)
		return

	var torrent := torrent_scene.instantiate()
	var missile := homing_scene.instantiate()
	if torrent == null or missile == null:
		push_error("[TorrentResourceTest] required scene failed to instantiate")
		get_tree().quit(1)
		return

	add_child(torrent)
	add_child(missile)
	var entry := VehicleCatalog.get_vehicle("torrent")
	var valid := (
		str(entry.get("scene_path", "")) == TORRENT_SCENE_PATH
		and int(entry.get("vehicle_type", -1)) == Vehicle.VehicleType.TORRENT
		and missile.has_method("setup_homing")
		and torrent.get_node_or_null("WeaponAnchor") != null
		and torrent.get_node_or_null("ExhaustAnchor") != null
	)
	torrent.queue_free()
	missile.queue_free()
	if not valid:
		push_error("[TorrentResourceTest] catalog or scene contract failed")
		get_tree().quit(1)
		return

	print("[TorrentResourceTest] PASS")
	get_tree().quit(0)
