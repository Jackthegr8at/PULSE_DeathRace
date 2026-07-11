class_name MissilePickup
extends Area3D
## Road pickup: wooden ammo crate with mini-missile icon. Grants ammo on contact.

@export var ammo_amount: int = 1
@export var respawn_time: float = 14.0
@export var bob_height: float = 0.12
@export var bob_speed: float = 2.2
@export var spin_speed: float = 1.4

var _active: bool = true
var _time: float = 0.0

@onready var visual: Node3D = $Visual
@onready var missile_icon: Node3D = get_node_or_null("Visual/MissileIcon")


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	collision_layer = 0
	collision_mask = 8 # vehicle spheres
	monitoring = true
	_time = randf() * TAU


func _process(delta: float) -> void:
	if not _active or visual == null:
		return
	_time += delta
	visual.position.y = bob_height * sin(_time * bob_speed)
	# Crate stays upright; only the missile icon spins so it reads clearly
	if missile_icon:
		missile_icon.rotate_y(spin_speed * delta)


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
	await get_tree().create_timer(respawn_time).timeout
	if is_instance_valid(self):
		_active = true
		monitoring = true
		if visual:
			visual.visible = true
