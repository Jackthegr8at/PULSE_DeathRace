extends Node3D
## 3D race host: instances selected track + player vehicle + follow camera.

const VehicleScene: PackedScene = preload("res://scenes/vehicle.tscn")

@onready var track_root: Node3D = $TrackRoot
@onready var vehicles_root: Node3D = $Vehicles
@onready var view: Node3D = $View

var track: Node3D = null
var player: Vehicle = null


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color(0.68, 0.76, 0.97))
	_load_track()
	# Let GridMap / figure-8 builder finish
	await get_tree().process_frame
	await get_tree().process_frame
	_spawn_player()
	_bind_camera()


func _load_track() -> void:
	var path := MatchConfig.track_scene_path()
	var packed := load(path) as PackedScene
	if packed == null:
		push_error("Race3D: failed to load track %s" % path)
		return
	track = packed.instantiate() as Node3D
	track_root.add_child(track)


func _spawn_player() -> void:
	player = VehicleScene.instantiate() as Vehicle
	vehicles_root.add_child(player)

	var spawn := _get_spawn_transform()
	# Kenney vehicle: physics sphere drives position; place it at spawn
	var sphere := player.get_node_or_null("Sphere") as RigidBody3D
	if sphere:
		sphere.global_position = spawn.origin + Vector3(0, 0.6, 0)
		sphere.linear_velocity = Vector3.ZERO
		sphere.angular_velocity = Vector3.ZERO
	var container := player.get_node_or_null("Container") as Node3D
	if container:
		container.global_transform = Transform3D(spawn.basis, spawn.origin)
	player.global_position = spawn.origin


func _get_spawn_transform() -> Transform3D:
	if track and track.has_method("get_spawn_transform"):
		return track.call("get_spawn_transform") as Transform3D
	return Transform3D(Basis(), Vector3(3.5, 0.2, 5))


func _bind_camera() -> void:
	if view == null or player == null:
		return
	# view.gd exports target: Vehicle
	view.set("target", player)
	view.global_position = player.get_vehicle_position()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().change_scene_to_file("res://scenes/Setup.tscn")
