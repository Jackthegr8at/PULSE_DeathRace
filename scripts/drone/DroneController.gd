class_name DroneController
extends Node3D
## Autonomous world-space drone that follows an owning vehicle and attacks rivals.

enum State {
	FOLLOW,
	LUNGE,
	RETURN,
}

const TARGET_RANGE := 12.0
const HOVER_HEIGHT := 2.15
const HOVER_REAR_OFFSET := 0.65
const FOLLOW_SMOOTHNESS := 8.0
const LUNGE_SPEED := 15.0
const RETURN_SPEED := 10.0
const HIT_DISTANCE := 1.15
const TARGET_HEIGHT := 0.65
const MODEL_TARGET_SIZE := 1.35
const SMOKE_TEX := preload("res://sprites/smoke.png")
const BombletBombdropScript := preload("res://scripts/drone/abilities/BombletBombdrop.gd")
const WelderRepairBeamScript := preload("res://scripts/drone/abilities/WelderRepairBeam.gd")

var owner_vehicle: Vehicle = null
var drone_id: String = DroneCatalog.SCRAPJAW_ID
var tier: int = 1
var cooldown_duration: float = 12.0
var damage_ratio: float = 0.60
var accent_color: Color = Color("e83f87")

var _state: State = State.FOLLOW
var _cooldown_remaining: float = 0.8
var _target: Vehicle = null
var _visual: Node3D = null
var _model: Node3D = null
var _bob_time: float = 0.0
var _last_owner_position := Vector3.ZERO
var _ability = null
var _hover_thruster: GPUParticles3D = null
var _hover_sparks: GPUParticles3D = null
var _accent_light: OmniLight3D = null
var _lunge_trail: GPUParticles3D = null
var _fx_power: float = 0.35


func configure(vehicle: Vehicle, configured_drone_id: String, configured_tier: int) -> bool:
	owner_vehicle = vehicle
	drone_id = configured_drone_id
	tier = clampi(configured_tier, DroneCatalog.MIN_TIER, DroneCatalog.MAX_TIER)
	var tier_data := DroneCatalog.get_tier(drone_id, tier)
	if owner_vehicle == null or tier_data.is_empty():
		return false
	cooldown_duration = float(tier_data.get("cooldown", 12.0))
	damage_ratio = float(tier_data.get("damage_ratio", 0.60))
	var drone_meta := DroneCatalog.get_drone(drone_id)
	accent_color = drone_meta.get("accent", Color("e83f87")) as Color
	_build_visual(str(tier_data.get("scene_path", "")))
	_build_ambient_fx()
	match DroneCatalog.get_attack_type(drone_id):
		"bombdrop":
			_ability = BombletBombdropScript.new()
			_ability.name = "BombdropAbility"
		"repair_beam":
			_ability = WelderRepairBeamScript.new()
			_ability.name = "RepairBeamAbility"
	if _ability != null:
		add_child(_ability)
		_ability.configure(self, owner_vehicle, tier_data)
	_last_owner_position = owner_vehicle.get_vehicle_position()
	global_position = _hover_target_position()
	add_to_group("combat_drones")
	return _model != null


func _process(delta: float) -> void:
	if not is_instance_valid(owner_vehicle) or not owner_vehicle.is_alive:
		queue_free()
		return
	_bob_time += delta
	if is_instance_valid(_ability):
		_ability.tick(delta)
	else:
		match _state:
			State.FOLLOW:
				_update_follow(delta)
			State.LUNGE:
				_update_lunge(delta)
			State.RETURN:
				_update_return(delta)
	_update_visual_attitude(delta)
	_update_ambient_fx(delta)
	_last_owner_position = owner_vehicle.get_vehicle_position()


func _update_follow(delta: float) -> void:
	var destination := _hover_target_position()
	global_position = global_position.lerp(
		destination,
		1.0 - exp(-FOLLOW_SMOOTHNESS * delta)
	)
	_face_direction(owner_vehicle.get_forward(), delta)
	if not _combat_is_active():
		return
	_cooldown_remaining = maxf(_cooldown_remaining - delta, 0.0)
	if _cooldown_remaining > 0.0:
		return
	_target = _find_target()
	if is_instance_valid(_target):
		_state = State.LUNGE


func _update_lunge(delta: float) -> void:
	if not _target_is_valid(_target) or not _combat_is_active():
		_cancel_attack()
		return
	var target_position := _target.get_vehicle_position() + Vector3.UP * TARGET_HEIGHT
	var to_target := target_position - global_position
	if to_target.length() <= HIT_DISTANCE:
		var hit_position := _target.get_vehicle_position() + Vector3.UP * TARGET_HEIGHT
		var damage := maxf(owner_vehicle.missile_damage * damage_ratio, 1.0)
		_target.take_damage(damage, owner_vehicle, &"drone")
		_spawn_chomp_impact(hit_position)
		_cooldown_remaining = cooldown_duration
		_target = null
		_state = State.RETURN
		return
	var direction := to_target.normalized()
	global_position += direction * minf(LUNGE_SPEED * delta, to_target.length())
	_face_direction(direction, delta)


func _update_return(delta: float) -> void:
	var destination := _hover_target_position()
	var to_home := destination - global_position
	if to_home.length() <= 0.18:
		global_position = destination
		_state = State.FOLLOW
		return
	var direction := to_home.normalized()
	global_position += direction * minf(RETURN_SPEED * delta, to_home.length())
	_face_direction(direction, delta)


func _cancel_attack() -> void:
	_target = null
	# A cancelled approach did not hit, so it does not consume the full cooldown.
	_cooldown_remaining = 0.0
	_state = State.RETURN


func _combat_is_active() -> bool:
	return (
		owner_vehicle.race_started
		and not owner_vehicle.match_over
		and not owner_vehicle.has_finished_race
		and owner_vehicle.is_alive
	)


func _find_target() -> Vehicle:
	var nearest: Vehicle = null
	var nearest_distance := TARGET_RANGE
	for candidate_node in get_tree().get_nodes_in_group("vehicles"):
		var candidate := candidate_node as Vehicle
		if not _target_is_valid(candidate):
			continue
		var distance := global_position.distance_to(candidate.get_vehicle_position())
		if distance >= nearest_distance or not _has_visibility(candidate):
			continue
		nearest = candidate
		nearest_distance = distance
	return nearest


func _target_is_valid(candidate: Vehicle) -> bool:
	return (
		is_instance_valid(candidate)
		and candidate != owner_vehicle
		and candidate.is_alive
		and not candidate.match_over
		and not candidate.has_finished_race
		and not candidate.is_cloaked
		and owner_vehicle.get_vehicle_position().distance_to(candidate.get_vehicle_position()) <= TARGET_RANGE
	)


func _has_visibility(candidate: Vehicle) -> bool:
	var from := global_position
	var to := candidate.get_vehicle_position() + Vector3.UP * TARGET_HEIGHT
	var query := PhysicsRayQueryParameters3D.create(from, to, 1 | 8)
	var owner_body := owner_vehicle.get_node_or_null("Sphere") as CollisionObject3D
	if owner_body:
		query.exclude = [owner_body.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return true
	var collider := hit.get("collider") as Node
	if collider == candidate:
		return true
	return collider != null and candidate.is_ancestor_of(collider)


func _hover_target_position() -> Vector3:
	var bob := sin(_bob_time * 2.25 + float(tier) * 0.4) * 0.09
	return (
		owner_vehicle.get_vehicle_position()
		+ Vector3.UP * (HOVER_HEIGHT + bob)
		- owner_vehicle.get_forward() * HOVER_REAR_OFFSET
	)


func ability_follow_owner(delta: float) -> void:
	var destination := _hover_target_position()
	global_position = global_position.lerp(
		destination,
		1.0 - exp(-FOLLOW_SMOOTHNESS * delta)
	)
	_face_direction(owner_vehicle.get_forward(), delta)


func ability_hover_target_position() -> Vector3:
	return _hover_target_position()


func ability_face_direction(direction: Vector3, delta: float) -> void:
	_face_direction(direction, delta)


func ability_combat_is_active() -> bool:
	return _combat_is_active()


func ability_find_target() -> Vehicle:
	return _find_target()


func _face_direction(direction: Vector3, delta: float) -> void:
	var flat := Vector3(direction.x, 0.0, direction.z)
	if flat.length_squared() < 0.0001:
		return
	var desired := Basis.looking_at(flat.normalized(), Vector3.UP)
	global_basis = global_basis.slerp(desired, 1.0 - exp(-10.0 * delta)).orthonormalized()


func _update_visual_attitude(delta: float) -> void:
	if _visual == null:
		return
	var owner_delta := owner_vehicle.get_vehicle_position() - _last_owner_position
	var lateral := owner_delta.dot(owner_vehicle.global_basis.x)
	var target_roll := clampf(-lateral * 0.12, -0.16, 0.16)
	_visual.rotation.z = lerpf(_visual.rotation.z, target_roll, 1.0 - exp(-6.0 * delta))


func _build_visual(scene_path: String) -> void:
	if scene_path.is_empty():
		return
	# Race LODs disabled: clustered meshes lost materials/UVs and looked broken.
	var load_path := scene_path
	var packed := load(load_path) as PackedScene
	if packed == null:
		push_error("DroneController: failed to load %s" % load_path)
		return
	_visual = Node3D.new()
	_visual.name = "Visual"
	add_child(_visual)
	_model = packed.instantiate() as Node3D
	if _model == null:
		return
	_model.name = "Model"
	_visual.add_child(_model)
	_model.rotation.y = deg_to_rad(DroneCatalog.get_model_yaw_degrees(drone_id))
	_normalize_model()
	for descendant in _model.find_children("*", "GeometryInstance3D", true, false):
		var geo := descendant as GeometryInstance3D
		if geo:
			geo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _normalize_model() -> void:
	if _model == null:
		return
	var bounds := AABB()
	var has_bounds := false
	for descendant in _model.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := descendant as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null:
			continue
		var relative := _model.global_transform.affine_inverse() * mesh_instance.global_transform
		var transformed := relative * mesh_instance.get_aabb()
		bounds = transformed if not has_bounds else bounds.merge(transformed)
		has_bounds = true
	if not has_bounds:
		return
	var largest := maxf(bounds.size.x, maxf(bounds.size.y, bounds.size.z))
	if largest <= 0.001:
		return
	var uniform_scale := MODEL_TARGET_SIZE / largest
	_model.scale = Vector3.ONE * uniform_scale
	var center := bounds.get_center() * uniform_scale
	_model.position = -center


func _build_ambient_fx() -> void:
	## Shared hover wash + accent glow for all drones (identity color from catalog).
	var c := accent_color
	var hot := c.lerp(Color.WHITE, 0.45)
	var fade := Color(c.r, c.g, c.b, 0.0)
	var fade_hot := Color(hot.r, hot.g, hot.b, 0.0)

	var owner_is_player := is_instance_valid(owner_vehicle) and owner_vehicle.is_player
	_hover_thruster = _make_drone_particles(
		Color(c.r, c.g, c.b, 0.9),
		fade,
		14 if owner_is_player else 10,
		0.18,
		2.4,
		0.14,
		0.34,
		0.32,
		true
	)
	_hover_thruster.name = "HoverThruster"
	_hover_thruster.position = Vector3(0, -0.28, 0.05)
	_hover_thruster.emitting = true
	_hover_thruster.fixed_fps = 24 if owner_is_player else 18
	var thruster_mat := _hover_thruster.process_material as ParticleProcessMaterial
	if thruster_mat:
		thruster_mat.direction = Vector3(0, -1, 0)
		thruster_mat.spread = 18.0
		thruster_mat.gravity = Vector3(0, -0.8, 0)
		thruster_mat.emission_sphere_radius = 0.06
	add_child(_hover_thruster)

	_hover_sparks = _make_drone_particles(
		Color(hot.r, hot.g, hot.b, 1.0),
		fade_hot,
		10 if owner_is_player else 6,
		0.12,
		3.2,
		0.05,
		0.12,
		0.16,
		true
	)
	_hover_sparks.name = "HoverSparks"
	_hover_sparks.position = Vector3(0, -0.26, 0.05)
	_hover_sparks.emitting = true
	_hover_sparks.fixed_fps = 24 if owner_is_player else 18
	var spark_mat := _hover_sparks.process_material as ParticleProcessMaterial
	if spark_mat:
		spark_mat.direction = Vector3(0, -1, 0)
		spark_mat.spread = 28.0
		spark_mat.gravity = Vector3(0, -1.2, 0)
		spark_mat.emission_sphere_radius = 0.04
	add_child(_hover_sparks)

	_lunge_trail = _make_drone_particles(
		Color(hot.r, hot.g, hot.b, 0.95),
		fade,
		16 if owner_is_player else 10,
		0.28,
		5.5,
		0.12,
		0.3,
		0.28,
		true
	)
	_lunge_trail.name = "LungeTrail"
	_lunge_trail.position = Vector3(0, 0.0, 0.2)
	_lunge_trail.emitting = false
	var trail_mat := _lunge_trail.process_material as ParticleProcessMaterial
	if trail_mat:
		# Local +Z is behind after looking_at forward travel.
		trail_mat.direction = Vector3(0, 0, 1)
		trail_mat.spread = 14.0
		trail_mat.gravity = Vector3(0, 0.4, 0)
		trail_mat.emission_sphere_radius = 0.05
	add_child(_lunge_trail)

	# Accent light on all drones (cheap omni, no shadows).
	_accent_light = OmniLight3D.new()
	_accent_light.name = "AccentLight"
	_accent_light.light_color = c
	_accent_light.light_energy = 0.9 if owner_is_player else 0.55
	_accent_light.omni_range = 2.4 if owner_is_player else 1.8
	_accent_light.shadow_enabled = false
	_accent_light.position = Vector3(0, -0.1, 0)
	add_child(_accent_light)


func _update_ambient_fx(delta: float) -> void:
	var combat := _combat_is_active()
	var ability_busy := false
	if is_instance_valid(_ability) and _ability.has_method("is_busy"):
		ability_busy = bool(_ability.is_busy())
	var lunging := (not is_instance_valid(_ability) and _state == State.LUNGE) or ability_busy
	var target_power := 0.0
	if combat:
		target_power = 1.15 if lunging else 0.4
		# Soft idle pulse so the drone reads as "alive" while hovering.
		target_power += 0.08 * sin(_bob_time * 4.5)
	_fx_power = lerpf(_fx_power, target_power, 1.0 - exp(-10.0 * delta))

	if _hover_thruster and is_instance_valid(_hover_thruster):
		_hover_thruster.emitting = _fx_power > 0.05
		var mat := _hover_thruster.process_material as ParticleProcessMaterial
		if mat:
			var spd := 1.4 + _fx_power * 3.2
			mat.initial_velocity_min = spd * 0.5
			mat.initial_velocity_max = spd
			mat.scale_min = 0.1 + _fx_power * 0.12
			mat.scale_max = 0.24 + _fx_power * 0.22
	if _hover_sparks and is_instance_valid(_hover_sparks):
		_hover_sparks.emitting = _fx_power > 0.2
		var smat := _hover_sparks.process_material as ParticleProcessMaterial
		if smat:
			var sspd := 2.0 + _fx_power * 4.0
			smat.initial_velocity_min = sspd * 0.55
			smat.initial_velocity_max = sspd
	if _lunge_trail and is_instance_valid(_lunge_trail):
		_lunge_trail.emitting = lunging and combat
		var tmat := _lunge_trail.process_material as ParticleProcessMaterial
		if tmat and lunging:
			tmat.initial_velocity_min = 3.5
			tmat.initial_velocity_max = 7.0
	if _accent_light and is_instance_valid(_accent_light):
		var flicker := 0.88 + 0.12 * sin(_bob_time * 11.0)
		_accent_light.light_energy = (0.55 + _fx_power * 1.8) * flicker
		_accent_light.omni_range = 1.8 + _fx_power * 1.6
		_accent_light.light_color = accent_color.lerp(Color.WHITE, clampf(_fx_power - 0.5, 0.0, 0.35))


func _spawn_chomp_impact(at: Vector3) -> void:
	## Scrapjaw bite flash — short magenta/accent energy burst at the hit.
	var host := get_tree().current_scene
	if host == null:
		host = get_parent()
	if host == null:
		return
	var root := Node3D.new()
	root.name = "ScrapjawImpact"
	host.add_child(root)
	root.global_position = at

	var hot := accent_color.lerp(Color.WHITE, 0.5)
	var core := _make_drone_particles(
		Color(hot.r, hot.g, hot.b, 1.0),
		Color(accent_color.r, accent_color.g, accent_color.b, 0.0),
		16,
		0.28,
		5.5,
		0.35,
		0.8,
		0.7,
		true
	)
	core.one_shot = true
	core.explosiveness = 0.95
	core.emitting = true
	var core_mat := core.process_material as ParticleProcessMaterial
	if core_mat:
		core_mat.direction = Vector3(0, 1, 0)
		core_mat.spread = 180.0
		core_mat.gravity = Vector3(0, 1.5, 0)
	root.add_child(core)

	var sparks := _make_drone_particles(
		Color(1.0, 0.9, 0.95, 1.0),
		Color(accent_color.r, accent_color.g, accent_color.b, 0.0),
		14,
		0.22,
		8.0,
		0.08,
		0.2,
		0.28,
		true
	)
	sparks.one_shot = true
	sparks.explosiveness = 0.98
	sparks.emitting = true
	var smat := sparks.process_material as ParticleProcessMaterial
	if smat:
		smat.direction = Vector3(0, 1, 0)
		smat.spread = 160.0
		smat.gravity = Vector3(0, -4.0, 0)
	root.add_child(sparks)

	var flash := OmniLight3D.new()
	flash.light_color = accent_color
	flash.light_energy = 5.5
	flash.omni_range = 4.0
	flash.shadow_enabled = false
	root.add_child(flash)
	var tw := root.create_tween()
	tw.tween_property(flash, "light_energy", 0.0, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_callback(root.queue_free)


func _make_drone_particles(
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
	p.randomness = 0.35
	p.fixed_fps = 30
	p.interpolate = true
	p.visibility_aabb = AABB(Vector3(-4, -4, -4), Vector3(8, 8, 8))
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, -1, 0)
	mat.spread = 15.0
	mat.initial_velocity_min = speed * 0.5
	mat.initial_velocity_max = speed
	mat.gravity = Vector3(0, -0.5, 0)
	mat.damping_min = 1.5
	mat.damping_max = 3.5
	mat.scale_min = scale_min
	mat.scale_max = scale_max
	mat.color = color_start
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 0.04

	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.25, 0.7, 1.0])
	grad.colors = PackedColorArray([
		color_start,
		color_start,
		color_start.lerp(color_end, 0.55),
		color_end,
	])
	var grad_tex := GradientTexture1D.new()
	grad_tex.gradient = grad
	mat.color_ramp = grad_tex

	var scale_curve := Curve.new()
	scale_curve.add_point(Vector2(0.0, 0.65))
	scale_curve.add_point(Vector2(0.2, 1.0))
	scale_curve.add_point(Vector2(1.0, 0.05))
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


func ability_notify_busy(busy: bool) -> void:
	## Optional hook for ability scripts; ambient FX reads ability.is_busy() when present.
	if busy:
		_fx_power = maxf(_fx_power, 0.95)
