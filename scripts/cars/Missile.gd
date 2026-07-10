class_name Missile
extends Area2D
## Straight-line projectile. Damages cars other than the owner.

@export var speed: float = 700.0
@export var damage: float = 15.0
@export var lifetime: float = 2.2

var owner_car: Car = null
var _velocity: Vector2 = Vector2.ZERO
var _age: float = 0.0


func setup(shooter: Car, dmg: float, spd: float) -> void:
	owner_car = shooter
	damage = dmg
	speed = spd
	_velocity = Vector2.RIGHT.rotated(rotation) * speed
	# Missiles on layer 3; detect cars (2) and world (1)
	collision_layer = 4
	collision_mask = 1 | 2


func _ready() -> void:
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	monitoring = true
	if _velocity == Vector2.ZERO:
		_velocity = Vector2.RIGHT.rotated(rotation) * speed


func _physics_process(delta: float) -> void:
	global_position += _velocity * delta
	_age += delta
	if _age >= lifetime:
		queue_free()


func _on_body_entered(body: Node) -> void:
	if body == owner_car:
		return
	if body is Car:
		var car := body as Car
		if car.is_alive:
			car.take_damage(damage, owner_car)
		queue_free()
		return
	# Walls / static world
	if body is StaticBody2D or body is TileMap or body is TileMapLayer:
		queue_free()
