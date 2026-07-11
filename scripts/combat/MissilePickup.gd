class_name MissilePickup
extends Area3D
## Road pickup: grants missile ammo when a vehicle drives over it.

@export var ammo_amount: int = 1
@export var respawn_time: float = 14.0
@export var bob_height: float = 0.15
@export var bob_speed: float = 2.5
@export var spin_speed: float = 1.8

var _active: bool = true
var _base_y: float = 0.0
var _time: float = 0.0

@onready var visual: Node3D = $Visual
@onready var mesh: MeshInstance3D = $Visual/Mesh


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	collision_layer = 0
	collision_mask = 8 # vehicle spheres
	monitoring = true
	_base_y = position.y
	_time = randf() * TAU


func _process(delta: float) -> void:
	if not _active or visual == null:
		return
	_time += delta
	visual.position.y = bob_height * sin(_time * bob_speed)
	visual.rotate_y(spin_speed * delta)


func _on_body_entered(body: Node) -> void:
	if not _active:
		return
	var veh: Vehicle = null
	if body is RigidBody3D and body.get_parent() is Vehicle:
		veh = body.get_parent() as Vehicle
	elif body is Vehicle:
		veh = body as Vehicle
	if veh == null or not veh.is_alive:
		return
	if veh.add_missiles(ammo_amount):
		_collect()


func _collect() -> void:
	_active = false
	monitoring = false
	if visual:
		visual.visible = false
	# Soft chime via pitch on impact (optional short delay respawn)
	await get_tree().create_timer(respawn_time).timeout
	if is_instance_valid(self):
		_active = true
		monitoring = true
		if visual:
			visual.visible = true
