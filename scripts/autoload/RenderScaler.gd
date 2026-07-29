extends Node
## Keeps the 3D race affordable when the game window is maximized.
## Canvas/HUD rendering stays at the full window resolution.
## Prefers cheap spatial upscale over FSR2 (temporal) for steadier frame times.

const HD_PIXEL_LIMIT := 1280 * 800
const FULL_HD_PIXEL_LIMIT := 1920 * 1080
const QHD_PIXEL_LIMIT := 2560 * 1440
const EMBEDDED_MAXIMIZED_MIN_WIDTH := 1340.0
const EMBEDDED_MAXIMIZED_MAX_HEIGHT := 800.0
const SCALE_QUALITY := 0.75
const SCALE_BALANCED := 0.62
const SCALE_PERFORMANCE := 0.50
const NATIVE_LOD_THRESHOLD := 4.0
const QUALITY_LOD_THRESHOLD := 6.0
const BALANCED_LOD_THRESHOLD := 8.0
const PERFORMANCE_LOD_THRESHOLD := 10.0
const RESIZE_DEBOUNCE_SECONDS := 0.15

var _resize_timer: Timer
var _applied_scale := -1.0


func _ready() -> void:
	_resize_timer = Timer.new()
	_resize_timer.one_shot = true
	_resize_timer.wait_time = RESIZE_DEBOUNCE_SECONDS
	_resize_timer.timeout.connect(_apply_for_current_size)
	add_child(_resize_timer)

	get_viewport().size_changed.connect(_queue_update)
	call_deferred("_apply_for_current_size")


func _queue_update() -> void:
	_resize_timer.start()


func _apply_for_current_size() -> void:
	var viewport := get_viewport()
	var viewport_size := viewport.get_visible_rect().size
	var pixel_count := int(viewport_size.x * viewport_size.y)
	var target_scale := _scale_for_viewport_size(viewport_size, pixel_count)
	var target_lod_threshold := _lod_threshold_for_scale(target_scale)
	if is_equal_approx(target_scale, _applied_scale) \
			and is_equal_approx(viewport.mesh_lod_threshold, target_lod_threshold):
		return

	_applied_scale = target_scale
	viewport.scaling_3d_scale = target_scale
	# Environment meshes can be dense; use LODs earlier for the top-down race camera.
	viewport.mesh_lod_threshold = target_lod_threshold
	if target_scale < 1.0:
		# FSR2 is temporal and can hitch; FSR1 (spatial) is cheaper/steadier for arcade racing.
		viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR
		viewport.fsr_sharpness = 0.35
		viewport.msaa_3d = Viewport.MSAA_DISABLED
	else:
		viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
		# Light AA only when rendering native 3D resolution.
		viewport.msaa_3d = Viewport.MSAA_2X

	print("[RenderScaler] viewport=%dx%d 3D scale=%.2f mode=%s lod=%.1f" % [
		int(viewport_size.x),
		int(viewport_size.y),
		target_scale,
		"FSR" if target_scale < 1.0 else "native",
		target_lod_threshold,
	])


func _scale_for_viewport_size(viewport_size: Vector2, pixel_count: int) -> float:
	# Embedded Game view maximized often reports a wide ~720p logical size.
	if viewport_size.x >= EMBEDDED_MAXIMIZED_MIN_WIDTH and viewport_size.y <= EMBEDDED_MAXIMIZED_MAX_HEIGHT:
		return SCALE_PERFORMANCE
	if pixel_count <= HD_PIXEL_LIMIT:
		return 1.0
	if pixel_count <= FULL_HD_PIXEL_LIMIT:
		return SCALE_QUALITY
	if pixel_count <= QHD_PIXEL_LIMIT:
		return SCALE_BALANCED
	return SCALE_PERFORMANCE


func _lod_threshold_for_scale(render_scale: float) -> float:
	if render_scale <= SCALE_PERFORMANCE:
		return PERFORMANCE_LOD_THRESHOLD
	if render_scale <= SCALE_BALANCED:
		return BALANCED_LOD_THRESHOLD
	if render_scale <= SCALE_QUALITY:
		return QUALITY_LOD_THRESHOLD
	return NATIVE_LOD_THRESHOLD
