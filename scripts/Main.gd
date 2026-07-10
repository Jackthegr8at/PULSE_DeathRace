extends Node2D
## Race root: load track, spawn cars, evaluate win conditions, drive HUD / end screen.

const PlayerScene: PackedScene = preload("res://scenes/cars/PlayerCar.tscn")
const AIScene: PackedScene = preload("res://scenes/cars/AICar.tscn")
const HUDScene: PackedScene = preload("res://scenes/ui/HUD.tscn")
const EndScene: PackedScene = preload("res://scenes/ui/EndScreen.tscn")

var track: Track
var player: Car
var cars: Array[Car] = []
var hud: CanvasLayer
var end_screen: CanvasLayer
var match_over: bool = false

var _ai_colors: Array[Color] = [
	Color(1.0, 0.28, 0.32), ## Crimson
	Color(0.24, 0.72, 1.0), ## Electric blue
	Color(0.75, 0.35, 1.0), ## Violet
	Color(1.0, 0.55, 0.18), ## Orange rocket
]


func _ready() -> void:
	# Dark arena clear color
	RenderingServer.set_default_clear_color(Color(0.4, 0.58, 0.32))
	_spawn_track()
	# Let track finish building geometry this frame
	await get_tree().process_frame
	_spawn_cars()
	_spawn_ui()
	_update_alive_hud()


func _spawn_track() -> void:
	var path := MatchConfig.track_scene_path
	var packed := load(path) as PackedScene
	if packed == null:
		push_error("Failed to load track: %s" % path)
		return
	track = packed.instantiate() as Track
	add_child(track)


func _spawn_cars() -> void:
	if track == null:
		return
	var spawns := track.get_spawn_transforms()
	var path := track.get_race_path()

	# Player at first spawn
	player = PlayerScene.instantiate() as Car
	_place_car(player, spawns, 0)
	add_child(player)
	player.setup_lap_tracking(path)
	player.died.connect(_on_car_died)
	player.race_finished.connect(_on_car_race_finished)
	cars.append(player)

	var ai_n := MatchConfig.ai_count
	for i in ai_n:
		var ai := AIScene.instantiate() as Car
		var spawn_i := mini(i + 1, maxi(spawns.size() - 1, 0))
		_place_car(ai, spawns, spawn_i)
		add_child(ai)
		ai.setup_lap_tracking(path)
		if ai.has_method("setup_ai"):
			var color := _ai_colors[i % _ai_colors.size()]
			var sprite_path: String = CarVisuals.AI_LIST[i % CarVisuals.AI_LIST.size()]
			ai.setup_ai(path, color, "AI-%d" % (i + 1), sprite_path)
		ai.died.connect(_on_car_died)
		ai.race_finished.connect(_on_car_race_finished)
		cars.append(ai)


func _place_car(car: Car, spawns: Array[Transform2D], index: int) -> void:
	if spawns.is_empty():
		car.global_position = Vector2(700, 250) + Vector2(0, index * 40)
		car.rotation = 0.0
		return
	var xf: Transform2D = spawns[clampi(index, 0, spawns.size() - 1)]
	car.global_position = xf.origin
	car.rotation = xf.get_rotation()


func _spawn_ui() -> void:
	hud = HUDScene.instantiate()
	add_child(hud)
	if hud.has_method("setup"):
		hud.setup(track, player)
	elif hud.has_method("set_player"):
		hud.set_player(player)

	end_screen = EndScene.instantiate()
	add_child(end_screen)
	if end_screen.has_signal("rematch_requested"):
		end_screen.rematch_requested.connect(_on_rematch)
	if end_screen.has_signal("setup_requested"):
		end_screen.setup_requested.connect(_on_setup)


func _on_car_died(car: Car) -> void:
	if match_over:
		return
	cars.erase(car)
	_update_alive_hud()

	if car == player:
		# Player death: lose in all modes
		_end_match(false, "You were destroyed.")
		return

	# AI died — check last standing / hybrid wipeout
	var living := _living_cars()
	if living.size() == 1 and living[0] == player:
		if MatchConfig.mode == MatchConfig.Mode.LAST_STANDING \
				or MatchConfig.mode == MatchConfig.Mode.HYBRID:
			_end_match(true, "Last car standing!")
			return
	# Race-only: continue until someone finishes or player dies


func _on_car_race_finished(car: Car) -> void:
	if match_over or not MatchConfig.uses_laps():
		return
	if car == player:
		_end_match(true, "You finished %d laps first!" % MatchConfig.lap_count)
	else:
		_end_match(false, "%s finished the race first." % car.display_name)


func _living_cars() -> Array[Car]:
	var living: Array[Car] = []
	for c in cars:
		if is_instance_valid(c) and c.is_alive:
			living.append(c)
	return living


func _update_alive_hud() -> void:
	if hud and hud.has_method("update_alive"):
		hud.update_alive(_living_cars().size())


func _end_match(player_won: bool, detail: String) -> void:
	if match_over:
		return
	match_over = true
	if hud and hud.has_method("stop"):
		hud.stop()
	for c in cars:
		if is_instance_valid(c):
			c.set_match_over(true)
	if end_screen and end_screen.has_method("show_result"):
		end_screen.show_result(player_won, detail)


func _on_rematch() -> void:
	get_tree().change_scene_to_file("res://scenes/Main.tscn")


func _on_setup() -> void:
	get_tree().change_scene_to_file("res://scenes/Setup.tscn")
