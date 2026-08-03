class_name CombatFx
extends RefCounted
## Shared one-shot combat / race VFX helpers (particles, rings, lights).

const SMOKE_TEX := preload("res://sprites/smoke.png")


static func host_for(node: Node) -> Node:
	if node == null:
		return null
	var tree := node.get_tree()
	if tree and tree.current_scene:
		return tree.current_scene
	return node.get_parent()


static func make_particles(
	color_start: Color,
	color_end: Color,
	amount: int,
	life: float,
	speed: float,
	scale_min: float,
	scale_max: float,
	quad_size: float,
	additive: bool = true,
	one_shot: bool = false
) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.emitting = false
	p.amount = maxi(amount, 1)
	p.lifetime = maxf(life, 0.05)
	p.one_shot = one_shot
	p.explosiveness = 0.95 if one_shot else 0.08
	p.randomness = 0.35
	p.fixed_fps = 30
	p.interpolate = true
	p.visibility_aabb = AABB(Vector3(-10, -6, -10), Vector3(20, 16, 20))
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 1, 0)
	mat.spread = 180.0
	mat.initial_velocity_min = speed * 0.4
	mat.initial_velocity_max = speed
	mat.gravity = Vector3(0, 0.6, 0)
	mat.damping_min = 1.4
	mat.damping_max = 3.6
	mat.scale_min = scale_min
	mat.scale_max = scale_max
	mat.color = color_start
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 0.08

	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.22, 0.65, 1.0])
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
	scale_curve.add_point(Vector2(0.0, 0.4))
	scale_curve.add_point(Vector2(0.18, 1.15))
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


static func spawn_world_root(from_node: Node, at: Vector3, name: String = "CombatFx") -> Node3D:
	var host := host_for(from_node)
	if host == null:
		return null
	var root := Node3D.new()
	root.name = name
	host.add_child(root)
	root.global_position = at
	return root


static func add_flash_light(
	parent: Node3D,
	color: Color,
	energy: float,
	range: float,
	duration: float
) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = energy
	light.omni_range = range
	light.shadow_enabled = false
	parent.add_child(light)
	var tw := parent.create_tween()
	tw.tween_property(light, "light_energy", 0.0, maxf(duration, 0.05))\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	return light


static func add_expanding_ring(
	parent: Node3D,
	color: Color,
	inner: float,
	outer: float,
	end_scale: float,
	duration: float,
	y_offset: float = 0.05
) -> void:
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = inner
	torus.outer_radius = outer
	torus.rings = 10
	torus.ring_segments = 22
	ring.mesh = torus
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(color.r, color.g, color.b, 0.9)
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 2.4
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	ring.material_override = mat
	ring.rotation_degrees = Vector3(90, 0, 0)
	ring.position.y = y_offset
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(ring)
	var tw := parent.create_tween()
	tw.set_parallel(true)
	tw.tween_property(ring, "scale", Vector3.ONE * end_scale, duration)\
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_property(mat, "albedo_color:a", 0.0, duration)
	tw.tween_property(mat, "emission_energy_multiplier", 0.0, duration * 0.9)


static func spawn_burst(
	from_node: Node,
	at: Vector3,
	primary: Color,
	hot: Color,
	accent: Color,
	scale: float = 1.0,
	lifetime: float = 0.55,
	name: String = "FxBurst"
) -> Node3D:
	var root := spawn_world_root(from_node, at, name)
	if root == null:
		return null
	var s := scale
	add_flash_light(root, primary, 7.0 * s, 5.5 * s, lifetime * 0.55)
	add_flash_light(root, accent, 3.5 * s, 3.8 * s, lifetime * 0.35)
	add_expanding_ring(root, primary, 0.14 * s, 0.28 * s, 7.5, lifetime * 0.5)
	add_expanding_ring(root, accent, 0.1 * s, 0.34 * s, 8.5, lifetime * 0.55, 0.03)

	var core := make_particles(
		Color(hot.r, hot.g, hot.b, 1.0),
		Color(primary.r, primary.g, primary.b, 0.0),
		int(14 * s),
		lifetime * 0.35,
		5.0 * s,
		0.4 * s,
		0.9 * s,
		0.85,
		true,
		true
	)
	root.add_child(core)
	core.emitting = true

	var cloud := make_particles(
		Color(primary.r, primary.g, primary.b, 1.0),
		Color(primary.r * 0.4, primary.g * 0.2, primary.b * 0.5, 0.0),
		int(18 * s),
		lifetime * 0.75,
		4.2 * s,
		0.7 * s,
		1.5 * s,
		1.2,
		true,
		true
	)
	root.add_child(cloud)
	cloud.emitting = true

	var sparks := make_particles(
		Color(accent.r, accent.g, accent.b, 1.0),
		Color(hot.r, hot.g, hot.b, 0.0),
		int(14 * s),
		lifetime * 0.45,
		7.5 * s,
		0.1 * s,
		0.28 * s,
		0.35,
		true,
		true
	)
	var smat := sparks.process_material as ParticleProcessMaterial
	if smat:
		smat.spread = 140.0
		smat.gravity = Vector3(0, -5.0, 0)
	root.add_child(sparks)
	sparks.emitting = true

	var scrap := make_particles(
		Color(0.55, 0.55, 0.6, 0.9),
		Color(0.2, 0.2, 0.22, 0.0),
		int(10 * s),
		lifetime * 0.7,
		3.5 * s,
		0.15 * s,
		0.4 * s,
		0.45,
		false,
		true
	)
	var scrap_mat := scrap.process_material as ParticleProcessMaterial
	if scrap_mat:
		scrap_mat.gravity = Vector3(0, -8.0, 0)
		scrap_mat.spread = 160.0
	root.add_child(scrap)
	scrap.emitting = true

	var tw := root.create_tween()
	tw.tween_interval(lifetime + 0.05)
	tw.tween_callback(root.queue_free)
	return root


static func spawn_hit_sparks(from_node: Node, at: Vector3, color: Color = Color("ff6ef0")) -> void:
	var root := spawn_world_root(from_node, at, "HitSparks")
	if root == null:
		return
	add_flash_light(root, color, 3.2, 2.6, 0.18)
	var sparks := make_particles(
		Color(1, 1, 1, 1),
		Color(color.r, color.g, color.b, 0.0),
		12,
		0.22,
		6.5,
		0.08,
		0.2,
		0.28,
		true,
		true
	)
	var mat := sparks.process_material as ParticleProcessMaterial
	if mat:
		mat.spread = 150.0
		mat.gravity = Vector3(0, -3.0, 0)
	root.add_child(sparks)
	sparks.emitting = true
	var puff := make_particles(
		Color(color.r, color.g, color.b, 0.9),
		Color(color.r, color.g, color.b, 0.0),
		8,
		0.28,
		2.8,
		0.25,
		0.55,
		0.5,
		true,
		true
	)
	root.add_child(puff)
	puff.emitting = true
	var tw := root.create_tween()
	tw.tween_interval(0.35)
	tw.tween_callback(root.queue_free)


static func spawn_collect_burst(from_node: Node, at: Vector3) -> void:
	spawn_burst(
		from_node,
		at,
		Color("ff2ec8"),
		Color("ffb0f0"),
		Color("3de8ff"),
		0.55,
		0.4,
		"PickupCollect"
	)


static func spawn_lap_burst(from_node: Node, at: Vector3, is_finish: bool) -> void:
	if is_finish:
		spawn_burst(
			from_node,
			at + Vector3(0, 0.6, 0),
			Color("ff2ec8"),
			Color("fff0ff"),
			Color("3de8ff"),
			1.35,
			0.75,
			"FinishBurst"
		)
	else:
		spawn_burst(
			from_node,
			at + Vector3(0, 0.4, 0),
			Color("3de8ff"),
			Color("c8fffd"),
			Color("ff2ec8"),
			0.7,
			0.45,
			"LapBurst"
		)


static func spawn_ram_impact(from_node: Node, at: Vector3) -> void:
	spawn_burst(
		from_node,
		at,
		Color("f6b600"),
		Color("ffe566"),
		Color("ff7a2e"),
		0.85,
		0.45,
		"RamImpact"
	)
