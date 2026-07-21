extends Node
## Temporary editor profiler. Prints only periodic summaries and slow frames.

const SPIKE_THRESHOLD_MS := 40.0
const SPIKE_COOLDOWN_SECONDS := 0.75
const SUMMARY_INTERVAL_SECONDS := 5.0
const RACE_WARMUP_SECONDS := 3.0

var _race_elapsed := 0.0
var _summary_elapsed := 0.0
var _spike_cooldown := 0.0
var _was_in_race := false


func _process(delta: float) -> void:
	var in_race := _is_race_scene()
	if not in_race:
		_was_in_race = false
		_race_elapsed = 0.0
		_summary_elapsed = 0.0
		return

	if not _was_in_race:
		_was_in_race = true
		print("[FrameProfiler] active; reporting frames slower than %.0f ms after warmup" % SPIKE_THRESHOLD_MS)

	_race_elapsed += delta
	_summary_elapsed += delta
	_spike_cooldown = maxf(0.0, _spike_cooldown - delta)
	if _race_elapsed < RACE_WARMUP_SECONDS:
		return

	if _summary_elapsed >= SUMMARY_INTERVAL_SECONDS:
		_summary_elapsed = 0.0
		print(_format_sample("FrameStats", delta))

	var frame_ms := delta * 1000.0
	if frame_ms >= SPIKE_THRESHOLD_MS and _spike_cooldown <= 0.0:
		_spike_cooldown = SPIKE_COOLDOWN_SECONDS
		print(_format_sample("FrameSpike", delta))


func _is_race_scene() -> bool:
	var scene := get_tree().current_scene
	if scene == null:
		return false
	return scene.scene_file_path.ends_with("/Race3D.tscn") or scene.name == "Race3D"


func _format_sample(tag: String, delta: float) -> String:
	var process_ms := Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	var physics_ms := Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
	var static_memory_mb := Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0
	var video_memory_mb := Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0
	return ("[%s] frame=%.1fms process=%.1fms physics=%.1fms fps=%.0f "
		+ "draws=%d primitives=%d objects=%d nodes=%d active3d=%d pairs3d=%d "
		+ "ram=%.0fMB vram=%.0fMB pipelines(canvas=%d mesh=%d surface=%d draw=%d)") % [
		tag,
		delta * 1000.0,
		process_ms,
		physics_ms,
		Performance.get_monitor(Performance.TIME_FPS),
		int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)),
		int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)),
		int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		int(Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS)),
		int(Performance.get_monitor(Performance.PHYSICS_3D_COLLISION_PAIRS)),
		static_memory_mb,
		video_memory_mb,
		int(Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_CANVAS)),
		int(Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_MESH)),
		int(Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SURFACE)),
		int(Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_DRAW)),
	]
