class_name Missile3D
extends Area3D
## Straight-flying 3D missile using scenes/combat/missile.glb.

@export var speed: float = 28.0
@export var damage: float = 15.0
@export var lifetime: float = 2.5
## Scale the imported GLB (tweak if too big/small in game).
@export var model_scale: float = 1.0
## Local rotation (degrees) so the GLB nose matches Area3D -Z (look_at forward).
## Common: (90,0,0) if the model points +Y; (0,180,0) if it points +Z.
@export var model_rotation_degrees: Vector3 = Vector3(0, 0, 0)

var owner_vehicle: Vehicle = null
var _velocity: Vector3 = Vector3.ZERO
var _age: float = 0.0

@onready var model: Node3D = get_node_or_null("Model")


func setup(shooter: Vehicle, dmg: float, spd: float, dir: Vector3) -> void:
	owner_vehicle = shooter
	damage = dmg
	speed = spd
	var d := dir
	d.y = 0.0
	if d.length_squared() < 0.0001:
		d = Vector3(0, 0, 1)
	_velocity = d.normalized() * speed
	# Point this Area3D so -Z faces travel (Godot look_at convention)
	if _velocity.length_squared() > 0.001:
		look_at(global_position + _velocity, Vector3.UP)
	_apply_model_transform()


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	monitoring = true
	collision_layer = 16
	collision_mask = 1 | 8 # world + vehicle spheres
	_apply_model_transform()


func _apply_model_transform() -> void:
	if model == null:
		model = get_node_or_null("Model")
	if model == null:
		return
	model.scale = Vector3.ONE * model_scale
	model.rotation_degrees = model_rotation_degrees


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
