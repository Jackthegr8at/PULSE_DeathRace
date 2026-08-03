class_name MissilePickup
extends Area3D
## Road pickup: wooden ammo crate with mini-missile icon. Grants ammo on contact.

@export var ammo_amount: int = 1
@export var respawn_time: float = 14.0
@export var bob_height: float = 0.12
@export var bob_speed: float = 2.2
@export var spin_speed: float = 1.4

## Crate mesh is ~1.0 wide; rings sit outside that footprint.
const RING_INNER := 0.95
const RING_OUTER := 1.18
const RING_INNER_B := 1.22
const RING_OUTER_B := 1.38

var _active: bool = true
var _time: float = 0.0
var _idle_motes: GPUParticles3D = null
var _idle_ring: MeshInstance3D = null
var _idle_ring_outer: MeshInstance3D = null
var _ring_material: StandardMaterial3D = null
var _ring_outer_material: StandardMaterial3D = null

@onready var visual: Node3D = $Visual
@onready var missile_icon: Node3D = get_node_or_null("Visual/MissileIcon")
@onready var glow: OmniLight3D = get_node_or_null("Visual/Glow")


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	collision_layer = 0
	collision_mask = 8 # vehicle spheres
	monitoring = true
	_time = randf() * TAU
	_build_idle_fx()
	_set_idle_fx_active(true)


func _process(delta: float) -> void:
	if not _active or visual == null:
		return
	_time += delta
	visual.position.y = bob_height * sin(_time * bob_speed)
	# Crate stays upright; only the missile icon spins so it reads clearly
	if missile_icon:
		missile_icon.rotate_y(spin_speed * delta)
	# Orbit rings around the crate (not on its top face).
	if is_instance_valid(_idle_ring):
		_idle_ring.rotate_y(delta * 1.25)
		var pulse := 1.0 + sin(_time * 3.2) * 0.04
		_idle_ring.scale = Vector3(pulse, 1.0, pulse)
	if is_instance_valid(_idle_ring_outer):
		_idle_ring_outer.rotate_y(-delta * 0.85)
		var pulse_b := 1.0 + sin(_time * 2.4 + 1.2) * 0.05
		_idle_ring_outer.scale = Vector3(pulse_b, 1.0, pulse_b)
	if is_instance_valid(glow):
		glow.light_energy = 1.35 + 0.4 * sin(_time * 4.0)
		glow.omni_range = 3.4
	if is_instance_valid(_ring_material):
		_ring_material.emission_energy_multiplier = 2.0 + 0.7 * sin(_time * 5.0)
	if is_instance_valid(_ring_outer_material):
		_ring_outer_material.emission_energy_multiplier = 1.4 + 0.5 * sin(_time * 3.6)


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


func _build_idle_fx() -> void:
	if visual == null:
		return
	# Orbiting Pulse motes on a ring outside the crate sides.
	_idle_motes = CombatFx.make_particles(
		Color(1.0, 0.18, 0.78, 0.95),
		Color(0.24, 0.9, 1.0, 0.0),
		28,
		0.85,
		0.55,
		0.1,
		0.24,
		0.26,
		true,
		false
	)
	_idle_motes.name = "PickupMotes"
	_idle_motes.position = Vector3(0, 0.28, 0)
	_idle_motes.emitting = false
	var mat := _idle_motes.process_material as ParticleProcessMaterial
	if mat:
		mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
		mat.emission_ring_axis = Vector3(0, 1, 0)
		mat.emission_ring_height = 0.35
		mat.emission_ring_radius = 1.12
		mat.emission_ring_inner_radius = 1.0
		mat.direction = Vector3(0, 1, 0)
		mat.spread = 25.0
		mat.gravity = Vector3(0, 0.15, 0)
		mat.initial_velocity_min = 0.15
		mat.initial_velocity_max = 0.55
		mat.orbit_velocity_min = 0.35
		mat.orbit_velocity_max = 0.65
		mat.radial_velocity_min = -0.05
		mat.radial_velocity_max = 0.08
	visual.add_child(_idle_motes)

	# Magenta energy ring on the ground plane, around the crate footprint.
	_idle_ring = _make_ground_ring(
		"PickupRing",
		RING_INNER,
		RING_OUTER,
		Color("ff2ec8"),
		0.02,
		2.2
	)
	_ring_material = _idle_ring.material_override as StandardMaterial3D
	visual.add_child(_idle_ring)

	# Cyan outer accent ring (concept Pulse palette).
	_idle_ring_outer = _make_ground_ring(
		"PickupRingOuter",
		RING_INNER_B,
		RING_OUTER_B,
		Color("3de8ff"),
		0.0,
		1.4
	)
	_ring_outer_material = _idle_ring_outer.material_override as StandardMaterial3D
	if _ring_outer_material:
		_ring_outer_material.albedo_color.a = 0.4
	visual.add_child(_idle_ring_outer)

	if glow:
		glow.light_color = Color("ff2ec8")
		glow.light_energy = 1.4
		glow.omni_range = 3.4


func _make_ground_ring(
	node_name: String,
	inner: float,
	outer: float,
	color: Color,
	y: float,
	emission: float
) -> MeshInstance3D:
	var ring := MeshInstance3D.new()
	ring.name = node_name
	var torus := TorusMesh.new()
	torus.inner_radius = inner
	torus.outer_radius = outer
	torus.rings = 12
	torus.ring_segments = 36
	ring.mesh = torus
	# Flat on the road around the crate base (not stacked on the lid).
	ring.position = Vector3(0, y, 0)
	ring.rotation_degrees.x = 90.0
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var ring_mat := StandardMaterial3D.new()
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring_mat.albedo_color = Color(color.r, color.g, color.b, 0.72)
	ring_mat.emission_enabled = true
	ring_mat.emission = color
	ring_mat.emission_energy_multiplier = emission
	ring_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	ring.material_override = ring_mat
	return ring


func _set_idle_fx_active(active: bool) -> void:
	if _idle_motes and is_instance_valid(_idle_motes):
		_idle_motes.emitting = active
	if _idle_ring and is_instance_valid(_idle_ring):
		_idle_ring.visible = active
	if _idle_ring_outer and is_instance_valid(_idle_ring_outer):
		_idle_ring_outer.visible = active
	if glow and is_instance_valid(glow):
		glow.visible = active


func _collect() -> void:
	_active = false
	set_deferred("monitoring", false)
	var collect_at := global_position + Vector3(0, 0.4, 0)
	CombatFx.spawn_collect_burst(self, collect_at)
	_set_idle_fx_active(false)
	if visual:
		visual.visible = false
	await get_tree().create_timer(respawn_time).timeout
	if is_instance_valid(self):
		_respawn()


func _respawn() -> void:
	_active = true
	set_deferred("monitoring", true)
	if visual:
		visual.visible = true
		visual.scale = Vector3.ZERO
		var tw := create_tween()
		tw.tween_property(visual, "scale", Vector3.ONE, 0.28)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_set_idle_fx_active(true)
	CombatFx.spawn_burst(
		self,
		global_position + Vector3(0, 0.35, 0),
		Color("3de8ff"),
		Color("c8fffd"),
		Color("ff2ec8"),
		0.45,
		0.35,
		"PickupRespawn"
	)
