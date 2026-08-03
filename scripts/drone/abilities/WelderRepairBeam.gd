class_name WelderRepairBeam
extends Node3D
## Welder support strategy: autonomously repairs only its owning vehicle.

enum State {
	IDLE,
	REPAIRING,
}

const BEAM_COLOR := Color("57ef72")
const BEAM_HOT := Color("c8ffd0")
const BEAM_CORE_RADIUS := 0.028
const BEAM_OUTER_RADIUS := 0.065
const OWNER_TARGET_HEIGHT := 0.62
const SMOKE_TEX := preload("res://sprites/smoke.png")

var _controller: DroneController = null
var _owner: Vehicle = null
var _state: State = State.IDLE
var _cooldown_duration: float = 12.0
var _cooldown_remaining: float = 1.0
var _beam_duration: float = 3.0
var _heal_ratio: float = 0.12
var _repair_remaining: float = 0.0
var _healing_remaining: float = 0.0
var _beam_core: MeshInstance3D = null
var _beam_outer: MeshInstance3D = null
var _beam_core_mesh: CylinderMesh = null
var _beam_outer_mesh: CylinderMesh = null
var _endpoint_glow: MeshInstance3D = null
var _source_glow: MeshInstance3D = null
var _weld_sparks: GPUParticles3D = null
var _beam_motes: GPUParticles3D = null
var _endpoint_light: OmniLight3D = null
var _source_light: OmniLight3D = null
var _core_material: StandardMaterial3D = null
var _outer_material: StandardMaterial3D = null
var _visual_time: float = 0.0


func configure(controller: DroneController, owner: Vehicle, tier_data: Dictionary) -> void:
	_controller = controller
	_owner = owner
	_cooldown_duration = maxf(float(tier_data.get("cooldown", 12.0)), 0.1)
	_beam_duration = maxf(float(tier_data.get("beam_duration", 3.0)), 0.1)
	_heal_ratio = maxf(float(tier_data.get("heal_ratio", 0.12)), 0.0)
	_build_visuals()
	_set_visuals_active(false)


func is_busy() -> bool:
	return _state == State.REPAIRING


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
	_core_material = _make_beam_material(BEAM_HOT, 0.95, 5.0)
	_outer_material = _make_beam_material(BEAM_COLOR, 0.35, 2.2)

	_beam_core_mesh = CylinderMesh.new()
	_beam_core_mesh.top_radius = BEAM_CORE_RADIUS
	_beam_core_mesh.bottom_radius = BEAM_CORE_RADIUS
	_beam_core_mesh.height = 1.0
	_beam_core_mesh.radial_segments = 8
	_beam_core_mesh.material = _core_material
	_beam_core = MeshInstance3D.new()
	_beam_core.name = "RepairBeamCore"
	_beam_core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_beam_core.mesh = _beam_core_mesh
	add_child(_beam_core)

	_beam_outer_mesh = CylinderMesh.new()
	_beam_outer_mesh.top_radius = BEAM_OUTER_RADIUS
	_beam_outer_mesh.bottom_radius = BEAM_OUTER_RADIUS
	_beam_outer_mesh.height = 1.0
	_beam_outer_mesh.radial_segments = 10
	_beam_outer_mesh.material = _outer_material
	_beam_outer = MeshInstance3D.new()
	_beam_outer.name = "RepairBeamOuter"
	_beam_outer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_beam_outer.mesh = _beam_outer_mesh
	add_child(_beam_outer)

	_endpoint_glow = _make_glow_sphere("RepairEndpointGlow", 0.16, _core_material)
	add_child(_endpoint_glow)
	_source_glow = _make_glow_sphere("RepairSourceGlow", 0.1, _outer_material)
	add_child(_source_glow)

	_weld_sparks = _make_particles(
		Color(BEAM_HOT.r, BEAM_HOT.g, BEAM_HOT.b, 1.0),
		Color(BEAM_COLOR.r, BEAM_COLOR.g, BEAM_COLOR.b, 0.0),
		18,
		0.2,
		2.8,
		0.05,
		0.14,
		0.18,
		true
	)
	_weld_sparks.name = "WeldSparks"
	_weld_sparks.emitting = false
	var spark_mat := _weld_sparks.process_material as ParticleProcessMaterial
	if spark_mat:
		spark_mat.direction = Vector3(0, 1, 0)
		spark_mat.spread = 120.0
		spark_mat.gravity = Vector3(0, -2.5, 0)
		spark_mat.emission_sphere_radius = 0.08
	add_child(_weld_sparks)

	_beam_motes = _make_particles(
		Color(BEAM_COLOR.r, BEAM_COLOR.g, BEAM_COLOR.b, 0.85),
		Color(BEAM_HOT.r, BEAM_HOT.g, BEAM_HOT.b, 0.0),
		14,
		0.35,
		1.6,
		0.08,
		0.2,
		0.22,
		true
	)
	_beam_motes.name = "BeamMotes"
	_beam_motes.emitting = false
	var mote_mat := _beam_motes.process_material as ParticleProcessMaterial
	if mote_mat:
		mote_mat.direction = Vector3(0, -1, 0)
		mote_mat.spread = 8.0
		mote_mat.gravity = Vector3.ZERO
		mote_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		mote_mat.emission_box_extents = Vector3(0.04, 0.5, 0.04)
	add_child(_beam_motes)

	_endpoint_light = OmniLight3D.new()
	_endpoint_light.name = "RepairEndpointLight"
	_endpoint_light.light_color = BEAM_COLOR
	_endpoint_light.light_energy = 0.0
	_endpoint_light.omni_range = 2.8
	_endpoint_light.shadow_enabled = false
	add_child(_endpoint_light)

	_source_light = OmniLight3D.new()
	_source_light.name = "RepairSourceLight"
	_source_light.light_color = BEAM_HOT
	_source_light.light_energy = 0.0
	_source_light.omni_range = 1.8
	_source_light.shadow_enabled = false
	add_child(_source_light)


func _make_beam_material(color: Color, alpha: float, emission: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var albedo := color
	albedo.a = alpha
	material.albedo_color = albedo
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = emission
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material


func _make_glow_sphere(node_name: String, radius: float, material: Material) -> MeshInstance3D:
	var glow_mesh := SphereMesh.new()
	glow_mesh.radius = radius
	glow_mesh.height = radius * 2.0
	glow_mesh.radial_segments = 12
	glow_mesh.rings = 6
	glow_mesh.material = material
	var node := MeshInstance3D.new()
	node.name = node_name
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.mesh = glow_mesh
	return node


func _update_visuals(delta: float) -> void:
	if _beam_core == null or _endpoint_glow == null:
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
	var mid := (from + to) * 0.5
	var basis := Basis(beam_right, beam_up, beam_forward)
	_beam_core.global_transform = Transform3D(basis, mid)
	_beam_outer.global_transform = Transform3D(basis, mid)
	_beam_core_mesh.height = distance
	_beam_outer_mesh.height = distance

	# Subtle wobble so the beam feels alive, not a static laser.
	var wobble := 1.0 + sin(_visual_time * 14.0) * 0.08
	_beam_core_mesh.top_radius = BEAM_CORE_RADIUS * wobble
	_beam_core_mesh.bottom_radius = BEAM_CORE_RADIUS * wobble
	_beam_outer_mesh.top_radius = BEAM_OUTER_RADIUS * (0.95 + sin(_visual_time * 9.0) * 0.12)
	_beam_outer_mesh.bottom_radius = _beam_outer_mesh.top_radius

	_endpoint_glow.global_position = to
	_source_glow.global_position = from
	var pulse := 1.0 + sin(_visual_time * 11.0) * 0.22
	_endpoint_glow.scale = Vector3.ONE * pulse
	_source_glow.scale = Vector3.ONE * (0.85 + sin(_visual_time * 13.0) * 0.15)

	if _weld_sparks:
		_weld_sparks.global_position = to
		_weld_sparks.emitting = true
	if _beam_motes:
		_beam_motes.global_transform = Transform3D(basis, mid)
		var mote_mat := _beam_motes.process_material as ParticleProcessMaterial
		if mote_mat:
			# Local +Y is beam_up (drone → chassis), so motes travel along the repair path.
			mote_mat.emission_box_extents = Vector3(0.04, distance * 0.48, 0.04)
			mote_mat.direction = Vector3(0, 1, 0)
			mote_mat.initial_velocity_min = distance * 0.25
			mote_mat.initial_velocity_max = distance * 0.7
		_beam_motes.emitting = true

	if _endpoint_light:
		_endpoint_light.global_position = to
		_endpoint_light.light_energy = 2.2 + 0.6 * sin(_visual_time * 16.0)
	if _source_light:
		_source_light.global_position = from
		_source_light.light_energy = 1.2 + 0.35 * sin(_visual_time * 12.0)

	if _core_material:
		_core_material.emission_energy_multiplier = 4.2 + 1.4 * sin(_visual_time * 18.0)
	if _outer_material:
		_outer_material.emission_energy_multiplier = 1.8 + 0.6 * sin(_visual_time * 10.0)


func _set_visuals_active(active: bool) -> void:
	if _beam_core:
		_beam_core.visible = active
	if _beam_outer:
		_beam_outer.visible = active
	if _endpoint_glow:
		_endpoint_glow.visible = active
	if _source_glow:
		_source_glow.visible = active
	if _weld_sparks:
		_weld_sparks.emitting = active
	if _beam_motes:
		_beam_motes.emitting = active
	if _endpoint_light:
		_endpoint_light.light_energy = 2.0 if active else 0.0
		_endpoint_light.visible = active
	if _source_light:
		_source_light.light_energy = 1.0 if active else 0.0
		_source_light.visible = active


func _make_particles(
	color_start: Color,
	color_end: Color,
	amount: int,
	life: float,
	speed: float,
	scale_min: float,
	scale_max: float,
	quad_size: float,
	additive: bool
) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.emitting = false
	p.amount = amount
	p.lifetime = life
	p.explosiveness = 0.05
	p.randomness = 0.4
	p.fixed_fps = 30
	p.interpolate = true
	p.visibility_aabb = AABB(Vector3(-4, -4, -4), Vector3(8, 8, 8))
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 1, 0)
	mat.spread = 30.0
	mat.initial_velocity_min = speed * 0.45
	mat.initial_velocity_max = speed
	mat.gravity = Vector3(0, -1.0, 0)
	mat.damping_min = 1.0
	mat.damping_max = 2.5
	mat.scale_min = scale_min
	mat.scale_max = scale_max
	mat.color = color_start
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 0.04

	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.3, 1.0])
	grad.colors = PackedColorArray([color_start, color_start, color_end])
	var grad_tex := GradientTexture1D.new()
	grad_tex.gradient = grad
	mat.color_ramp = grad_tex

	var scale_curve := Curve.new()
	scale_curve.add_point(Vector2(0.0, 0.7))
	scale_curve.add_point(Vector2(0.2, 1.0))
	scale_curve.add_point(Vector2(1.0, 0.0))
	var scale_tex := CurveTexture.new()
	scale_tex.curve = scale_curve
	mat.scale_curve = scale_tex
	p.process_material = mat

	var draw := QuadMesh.new()
	draw.size = Vector2(quad_size, quad_size)
	var draw_mat := StandardMaterial3D.new()
	draw_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	draw_mat.blend_mode = (
		BaseMaterial3D.BLEND_MODE_ADD if additive else BaseMaterial3D.BLEND_MODE_MIX
	)
	draw_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	draw_mat.vertex_color_use_as_albedo = true
	draw_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	draw_mat.billboard_keep_scale = true
	draw_mat.albedo_texture = SMOKE_TEX
	draw_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	p.draw_pass_1 = draw
	p.material_override = draw_mat
	return p
