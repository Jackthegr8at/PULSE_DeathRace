class_name Missile3D
extends Area3D
## Straight-flying 3D missile. Damages Vehicle bodies (via sphere RigidBody3D).

@export var speed: float = 28.0
@export var damage: float = 15.0
@export var lifetime: float = 2.5

var owner_vehicle: Vehicle = null
var _velocity: Vector3 = Vector3.ZERO
var _age: float = 0.0


func setup(shooter: Vehicle, dmg: float, spd: float, dir: Vector3) -> void:
	owner_vehicle = shooter
	damage = dmg
	speed = spd
	_velocity = dir.normalized() * speed
	# Point mesh along velocity
	if _velocity.length_squared() > 0.001:
		look_at(global_position + _velocity, Vector3.UP)


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	monitoring = true
	collision_layer = 16
	collision_mask = 1 | 8 # world + vehicle spheres


func _physics_process(delta: float) -> void:
	global_position += _velocity * delta
	_age += delta
	if _age >= lifetime:
		queue_free()


func _on_body_entered(body: Node) -> void:
	if owner_vehicle and (body == owner_vehicle.sphere or body.get_parent() == owner_vehicle):
		return
	# Sphere is child of Vehicle
	var veh: Vehicle = null
	if body is RigidBody3D and body.get_parent() is Vehicle:
		veh = body.get_parent() as Vehicle
	elif body is Vehicle:
		veh = body as Vehicle
	if veh and veh != owner_vehicle and veh.is_alive:
		veh.take_damage(damage, owner_vehicle)
		queue_free()
		return
	# Hit static world
	if body is StaticBody3D or body is GridMap:
		queue_free()
