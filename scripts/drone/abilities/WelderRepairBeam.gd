class_name WelderRepairBeam
extends Node3D
## Welder support strategy: autonomously repairs only its owning vehicle.

enum State {
	IDLE,
	REPAIRING,
}

const BEAM_COLOR := Color("57ef72")
const BEAM_RADIUS := 0.035
const OWNER_TARGET_HEIGHT := 0.62

var _controller: DroneController = null
var _owner: Vehicle = null
var _state: State = State.IDLE
var _cooldown_duration: float = 12.0
var _cooldown_remaining: float = 1.0
var _beam_duration: float = 3.0
var _heal_ratio: float = 0.12
var _repair_remaining: float = 0.0
var _healing_remaining: float = 0.0
var _beam: MeshInstance3D = null
var _beam_mesh: CylinderMesh = null
var _endpoint_glow: MeshInstance3D = null
var _visual_time: float = 0.0


func configure(controller: DroneController, owner: Vehicle, tier_data: Dictionary) -> void:
	_controller = controller
	_owner = owner
	_cooldown_duration = maxf(float(tier_data.get("cooldown", 12.0)), 0.1)
	_beam_duration = maxf(float(tier_data.get("beam_duration", 3.0)), 0.1)
	_heal_ratio = maxf(float(tier_data.get("heal_ratio", 0.12)), 0.0)
	_build_visuals()
	_set_visuals_active(false)


func tick(delta: float) -> void:
	if not is_instance_valid(_controller) or not is_instance_valid(_owner):
		_set_visuals_active(false)
		return
	_controller.ability_follow_owner(delta)
	match _state:
		State.IDLE:
			_update_idle(delta)
		State.REPAIRING:
			_update_repairing(delta)


func _update_idle(delta: float) -> void:
	_set_visuals_active(false)
	if not _controller.ability_combat_is_active():
		return
	_cooldown_remaining = maxf(_cooldown_remaining - delta, 0.0)
	if _cooldown_remaining > 0.0 or _owner.health >= _owner.max_health:
		return
	_state = State.REPAIRING
	_repair_remaining = _beam_duration
	_healing_remaining = _owner.max_health * _heal_ratio
	_set_visuals_active(true)


func _update_repairing(delta: float) -> void:
	if not _controller.ability_combat_is_active() or not _owner.is_alive:
		_finish_repair()
		return
	var step := minf(delta, _repair_remaining)
	var heal_per_second := (_owner.max_health * _heal_ratio) / _beam_duration
	var requested_heal := minf(heal_per_second * step, _healing_remaining)
	if requested_heal > 0.0:
		var health_before := _owner.health
		_owner.restore_health(requested_heal)
		_healing_remaining = maxf(
			_healing_remaining - maxf(_owner.health - health_before, 0.0),
			0.0
		)
	_repair_remaining = maxf(_repair_remaining - step, 0.0)
	_update_visuals(delta)
	if _repair_remaining <= 0.0 or _healing_remaining <= 0.001 or _owner.health >= _owner.max_health:
		_finish_repair()
func _finish_repair() -> void:
	_state = State.IDLE
	_cooldown_remaining = _cooldown_duration
	_repair_remaining = 0.0
	_healing_remaining = 0.0
	_set_visuals_active(false)


func _build_visuals() -> void:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var beam_albedo := BEAM_COLOR
	beam_albedo.a = 0.78
	material.albedo_color = beam_albedo
	material.emission_enabled = true
	material.emission = BEAM_COLOR
	material.emission_energy_multiplier = 3.5

	_beam_mesh = CylinderMesh.new()
	_beam_mesh.top_radius = BEAM_RADIUS
	_beam_mesh.bottom_radius = BEAM_RADIUS
	_beam_mesh.height = 1.0
	_beam_mesh.radial_segments = 8
	_beam_mesh.material = material
	_beam = MeshInstance3D.new()
	_beam.name = "RepairBeam"
	_beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_beam.mesh = _beam_mesh
	add_child(_beam)

	var glow_mesh := SphereMesh.new()
	glow_mesh.radius = 0.15
	glow_mesh.height = 0.30
	glow_mesh.radial_segments = 12
	glow_mesh.rings = 6
	glow_mesh.material = material
	_endpoint_glow = MeshInstance3D.new()
	_endpoint_glow.name = "RepairEndpointGlow"
	_endpoint_glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_endpoint_glow.mesh = glow_mesh
	add_child(_endpoint_glow)


func _update_visuals(delta: float) -> void:
	if _beam == null or _endpoint_glow == null:
		return
	_visual_time += delta
	var from := _controller.global_position + Vector3.DOWN * 0.18
	var to := _owner.get_vehicle_position() + Vector3.UP * OWNER_TARGET_HEIGHT
	var offset := to - from
	var distance := maxf(offset.length(), 0.001)
	var beam_up := offset / distance
	var beam_right := beam_up.cross(Vector3.FORWARD)
	if beam_right.length_squared() < 0.001:
		beam_right = beam_up.cross(Vector3.RIGHT)
	beam_right = beam_right.normalized()
	var beam_forward := beam_right.cross(beam_up).normalized()
	_beam.global_transform = Transform3D(
		Basis(beam_right, beam_up, beam_forward),
		(from + to) * 0.5
	)
	_beam_mesh.height = distance
	_endpoint_glow.global_position = to
	var pulse := 1.0 + sin(_visual_time * 9.0) * 0.18
	_endpoint_glow.scale = Vector3.ONE * pulse


func _set_visuals_active(active: bool) -> void:
	if _beam:
		_beam.visible = active
	if _endpoint_glow:
		_endpoint_glow.visible = active
