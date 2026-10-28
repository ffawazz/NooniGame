extends Node3D
## The Mazda CX-5 driving segment. Arcade driving down King Fahd Road: W/S throttle and brake, A/D steer,
## Space handbrake, E hack the next red light. Dodge the traffic, beat the clock.
## Forward is -Z; the car's world Z is minus the distance driven.

const Game := preload("res://scripts/core/game.gd")
const Levels := preload("res://scripts/levels/levels.gd")
const Toon := preload("res://scripts/core/toon.gd")
const MenuKit := preload("res://scripts/ui/menu_kit.gd")
const InputActions := preload("res://scripts/core/input_actions.gd")
const CarModel := preload("res://scripts/driving/car_model.gd")
const TrafficCarScript := preload("res://scripts/driving/traffic_car.gd")
const StopLightScript := preload("res://scripts/driving/stop_light.gd")
const CaptionsScript := preload("res://scripts/ui/captions.gd")
const StoryCardScript := preload("res://scripts/ui/story_card.gd")
const PauseMenuScript := preload("res://scripts/ui/pause_menu.gd")
const ResultPanelScript := preload("res://scripts/ui/result_panel.gd")

const ACCEL := 15.0
const COAST := 3.0
const BRAKE := 30.0
const HANDBRAKE := 46.0
const ROAD_HALF := 5.4
const LANES := [-3.6, 0.0, 3.6]
const CHUNK := 60.0
const CAR_HALF := Vector2(0.95, 2.15)  # x, z

@export var level_index := -1
## Headless tests: no cards, menus or scene changes.
var test_mode := false

var data: Dictionary
var car: Node3D
var speed := 0.0
var lateral := 0.0
var distance := 0.0
var crashes := 0
var penalty := 0.0
var elapsed := 0.0
var max_speed := 42.0
var length := 1200.0
var lights: Array = []
var traffic: Array = []

var captions: Node
var pause_menu: Node
var _finished := false
var _won := false
var _camera: Camera3D
var _visual: Node3D
var _steer_smooth := 0.0
var _crash_cooldown := 0.0
var _shake := 0.0
var _spawned_until := 0.0
var _cross_timer := 0.0
var _chunks: Dictionary = {}
var _hints_shown := {}
var _hack_cooldown := 0.0
var _hud: Dictionary = {}
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	InputActions.register()
	var index: int = level_index if level_index >= 0 else Game.state().current_level
	level_index = index
	data = Levels.data(index)
	length = data.get("length", 1200.0)
	max_speed = data.get("max_speed", 42.0)
	_rng.seed = 20251

	_build_environment()
	_build_car()
	for d in data.get("lights", []):
		var light := StopLightScript.new()
		light.position = Vector3(0, 0, -d)
		light.junction_z = -d
		add_child(light)
		lights.append(light)
	_ensure_chunks()
	_build_hud()

	captions = CaptionsScript.new()
	add_child(captions)

	elapsed = 0.0
	Game.music("music_drive")
	if not test_mode:
		pause_menu = PauseMenuScript.new()
		add_child(pause_menu)
		pause_menu.setup(self)
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_play_intro()


func _unhandled_input(event: InputEvent) -> void:
	if test_mode or _finished or pause_menu == null:
		return
	if event.is_action_pressed("pause"):
		pause_menu.toggle()
		get_viewport().set_input_as_handled()


# ---- Per-frame driving ---------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if _finished:
		return
	elapsed += delta
	_crash_cooldown = maxf(0.0, _crash_cooldown - delta)
	_hack_cooldown = maxf(0.0, _hack_cooldown - delta)

	var throttle := Input.is_action_pressed("move_forward")
	var braking := Input.is_action_pressed("move_back")
	var handbrake := Input.is_action_pressed("jump")
	var steer := Input.get_axis("move_left", "move_right")

	if throttle:
		speed += ACCEL * delta * (1.0 - speed / (max_speed * 1.15))
	else:
		speed -= COAST * delta
	if braking:
		speed -= BRAKE * delta
	if handbrake:
		speed -= HANDBRAKE * delta
	speed = clampf(speed, 0.0, max_speed)

	# Steering needs some speed, and a handbrake makes the tail slide wider.
	var grip := clampf(speed / 9.0, 0.0, 1.0)
	var lateral_speed := 6.2 * grip * (1.4 if handbrake else 1.0)
	lateral += steer * lateral_speed * delta
	var limit := ROAD_HALF - CAR_HALF.x + 0.2
	if absf(lateral) > limit:
		lateral = clampf(lateral, -limit, limit)
		speed *= 1.0 - 0.8 * delta  # scraping the barrier
		_shake = maxf(_shake, 0.15)

	distance += speed * delta
	car.position = Vector3(lateral, 0.0, -distance)
	_steer_smooth = lerpf(_steer_smooth, steer, minf(1.0, 8.0 * delta))
	_visual.rotation.y = -_steer_smooth * 0.22 * grip
	_visual.rotation.z = -_steer_smooth * 0.04 * grip

	for light in lights:
		light.tick(delta)
	if Input.is_action_just_pressed("interact"):
		try_hack_light()
	if Input.is_action_just_pressed("horn"):
		Game.sfx("horn", -3.0, _rng.randf_range(0.95, 1.05))

	_update_traffic(delta)
	_check_collisions()
	_ensure_chunks()
	_update_camera(delta)
	_update_hud()
	_update_engine()
	_check_end()


func _process(_delta: float) -> void:
	if _camera:
		_camera.fov = 68.0 + speed * 0.5


# ---- Traffic and lights --------------------------------------------------------------

func _update_traffic(delta: float) -> void:
	# Keep the road ahead populated with slower cars in random lanes.
	while _spawned_until < distance + 240.0:
		_spawned_until += _rng.randf_range(data.get("gap_min", 26.0), data.get("gap_max", 55.0))
		if _spawned_until > length + 40.0:
			break
		if _near_junction(_spawned_until):
			continue
		var lane: float = LANES[_rng.randi() % LANES.size()]
		_spawn_traffic(Vector3(lane, 0.0, -_spawned_until), Vector3(0, 0, -_rng.randf_range(9.0, 19.0)), false)

	# Cross traffic through every red junction the player is approaching.
	_cross_timer -= delta
	if _cross_timer <= 0.0:
		_cross_timer = data.get("cross_interval", 1.3)
		for light in lights:
			var ahead: float = (-light.junction_z) - distance
			if not light.green and ahead > -5.0 and ahead < 160.0:
				var from_left := _rng.randf() < 0.5
				var x := -45.0 if from_left else 45.0
				var z: float = light.junction_z + _rng.randf_range(-3.5, 3.5)
				_spawn_traffic(Vector3(x, 0.0, z), Vector3(16.0 if from_left else -16.0, 0, 0), true)

	for i in range(traffic.size() - 1, -1, -1):
		var other: Node3D = traffic[i]
		var gone: bool = other.global_position.z > car.position.z + 35.0 or absf(other.global_position.x) > 60.0
		if gone:
			other.queue_free()
			traffic.remove_at(i)


func _spawn_traffic(pos: Vector3, velocity: Vector3, cross: bool) -> void:
	var other := TrafficCarScript.new()
	other.cross = cross
	other.velocity = velocity
	var palette := [Color(0.9, 0.9, 0.92), Color(0.2, 0.2, 0.25), Color(0.85, 0.75, 0.3), Color(0.7, 0.2, 0.2), Color(0.3, 0.55, 0.35)]
	other.color = palette[_rng.randi() % palette.size()]
	other.position = pos
	add_child(other)
	traffic.append(other)


func _near_junction(d: float) -> bool:
	for light in lights:
		if absf((-light.junction_z) - d) < 22.0:
			return true
	return false


func _check_collisions() -> void:
	if _crash_cooldown > 0.0:
		return
	for other in traffic:
		if other.hit:
			continue
		var dx := absf(other.global_position.x - car.position.x)
		var dz := absf(other.global_position.z - car.position.z)
		if dx < other.half_size.x + CAR_HALF.x and dz < other.half_size.y + CAR_HALF.y:
			_crash(other)
			return


func _crash(other: Node3D) -> void:
	other.hit = true
	crashes += 1
	penalty += data.get("crash_penalty", 4.0)
	speed *= 0.35
	_crash_cooldown = 0.9
	_shake = 0.6
	# Knock the other car aside.
	var push := 1.0 if other.global_position.x >= car.position.x else -1.0
	other.velocity += Vector3(push * 7.0, 0, 0)
	Game.sfx("crash")
	_hint("crash")


## Hack the next red light ahead (within 90 m). Returns the light, or null.
func try_hack_light() -> Node:
	if _hack_cooldown > 0.0:
		return null
	var best: Node = null
	var best_gap := INF
	for light in lights:
		var gap: float = (-light.junction_z) - distance
		if gap > -2.0 and gap < 90.0 and not light.green and gap < best_gap and light.cooldown_left <= 0.0:
			best = light
			best_gap = gap
	if best and best.hack():
		_hack_cooldown = 0.6
		Game.sfx("chirp")
		_hint("hack")
		return best
	return null


func next_light() -> Node:
	var best: Node = null
	var best_gap := INF
	for light in lights:
		var gap: float = (-light.junction_z) - distance
		if gap > -6.0 and gap < best_gap:
			best = light
			best_gap = gap
	return best


# ---- World ---------------------------------------------------------------------------

func _build_environment() -> void:
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.25, 0.2, 0.5)
	sky_material.sky_horizon_color = Color(1.0, 0.62, 0.38)
	sky_material.ground_horizon_color = Color(1.0, 0.62, 0.38)
	sky_material.ground_bottom_color = Color(0.3, 0.2, 0.3)
	var sky := Sky.new()
	sky.sky_material = sky_material
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.85, 0.7, 0.9)
	env.ambient_light_energy = 0.3
	env.fog_enabled = true
	env.fog_light_color = Color(1.0, 0.7, 0.5)
	env.fog_density = 0.004
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-18.0, 50.0, 0.0)  # low sunset sun
	sun.light_color = Color(1.0, 0.75, 0.55)
	sun.light_energy = 0.8
	sun.shadow_enabled = true
	add_child(sun)


func _build_car() -> void:
	car = Node3D.new()
	car.name = "Mazda"
	add_child(car)
	_visual = Node3D.new()
	car.add_child(_visual)
	CarModel.build(_visual, Color(0.2, 0.4, 0.85), true)

	_camera = Camera3D.new()
	_camera.current = true
	add_child(_camera)
	_update_camera(1.0)


func _update_camera(delta: float) -> void:
	var target := car.position + Vector3(lateral * -0.25, 3.6, 8.5)
	_camera.global_position = _camera.global_position.lerp(target, minf(1.0, 10.0 * delta))
	if _shake > 0.0:
		_shake = maxf(0.0, _shake - delta)
		_camera.global_position += Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1), 0) * _shake * 0.25
	_camera.look_at(car.position + Vector3(0, 1.2, -9.0), Vector3.UP)


## Road, buildings, palms and lamp posts are built in 60 m chunks around the car and freed behind it.
func _ensure_chunks() -> void:
	var current := int(floor(distance / CHUNK))
	for i in range(current - 1, current + 7):
		if i < 0 or _chunks.has(i):
			continue
		_chunks[i] = _build_chunk(i)
	for key in _chunks.keys():
		if key < current - 2:
			_chunks[key].queue_free()
			_chunks.erase(key)


func _build_chunk(index: int) -> Node3D:
	var chunk := Node3D.new()
	chunk.position = Vector3(0, 0, -index * CHUNK - CHUNK * 0.5)
	add_child(chunk)
	var rng := RandomNumberGenerator.new()
	rng.seed = index * 7919 + 13

	Toon.box(chunk, Vector3(11.0, 0.1, CHUNK), Vector3(0, -0.05, 0), Color(0.3, 0.3, 0.34), 0.0)
	for side in [-1.0, 1.0]:
		Toon.box(chunk, Vector3(5.0, 0.25, CHUNK), Vector3(side * 8.1, 0.0, 0), Color(0.85, 0.75, 0.6), 0.0)
		Toon.box(chunk, Vector3(0.3, 0.5, CHUNK), Vector3(side * 5.65, 0.1, 0), Color(0.9, 0.85, 0.7), 0.02)
	for z in range(-27, 30, 6):
		for x in [-1.8, 1.8]:
			Toon.box(chunk, Vector3(0.18, 0.02, 2.6), Vector3(x, 0.01, float(z)), Color(0.95, 0.95, 0.9), 0.0)

	# Junctions get a cross road and crosswalk stripes.
	for light in lights:
		var local_z: float = light.junction_z - chunk.position.z
		if absf(local_z) < CHUNK * 0.5 + 6.0:
			Toon.box(chunk, Vector3(120.0, 0.1, 12.0), Vector3(0, -0.04, local_z), Color(0.3, 0.3, 0.34), 0.0)
			for x in range(-5, 6, 2):
				Toon.box(chunk, Vector3(0.7, 0.02, 3.0), Vector3(float(x), 0.02, local_z + 8.0), Color(0.95, 0.95, 0.95), 0.0)

	for side in [-1.0, 1.0]:
		for slot in 2:
			var width := rng.randf_range(6.0, 12.0)
			var depth := rng.randf_range(8.0, 14.0)
			var height := rng.randf_range(8.0, 32.0)
			var z := (slot - 0.5) * 30.0 + rng.randf_range(-4.0, 4.0)
			var tint := rng.randf_range(0.0, 1.0)
			var color := Color(0.85, 0.72, 0.55).lerp(Color(0.6, 0.65, 0.78), tint)
			Toon.box(chunk, Vector3(depth, height, width), Vector3(side * (13.0 + depth * 0.5), height * 0.5, z), color, 0.06)
		if index % 5 == 2:  # a tall landmark tower now and then, a nod to the Riyadh skyline
			Toon.box(chunk, Vector3(8.0, 80.0, 8.0), Vector3(side * 34.0, 40.0, -10.0), Color(0.5, 0.6, 0.75), 0.15)
		for z in range(-24, 30, 12):
			var palm := Node3D.new()
			palm.position = Vector3(side * 6.9, 0.0, float(z) + rng.randf_range(-2.0, 2.0))
			chunk.add_child(palm)
			Toon.cylinder(palm, 0.15, 3.6, Vector3(0, 1.8, 0), Color(0.55, 0.4, 0.3), 0.03)
			for leaf in 5:
				var frond := Toon.box(palm, Vector3(0.25, 0.06, 2.0), Vector3(0, 3.7, 0), Color(0.3, 0.65, 0.35), 0.02)
				frond.rotation_degrees = Vector3(-18, leaf * 72.0, 0)
				frond.position += Vector3(sin(deg_to_rad(leaf * 72.0)), 0, cos(deg_to_rad(leaf * 72.0))) * 0.9
		Toon.cylinder(chunk, 0.08, 5.0, Vector3(side * 5.9, 2.5, -12.0), Color(0.25, 0.25, 0.3), 0.02)
	return chunk


# ---- HUD, intro and the end ----------------------------------------------------------

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var box := VBoxContainer.new()
	box.position = Vector2(16, 12)
	layer.add_child(box)

	_hud.objective = MenuKit.label(data.get("objective", ""), 17, MenuKit.GOLD)
	box.add_child(_hud.objective)
	_hud.light = MenuKit.label("", 20)
	box.add_child(_hud.light)
	_hud.crashes = MenuKit.label("", 18)
	box.add_child(_hud.crashes)
	box.add_child(MenuKit.label("Distance to PNU", 18))
	_hud.progress = MenuKit.bar(Color(0.4, 0.8, 1.0))
	_hud.progress.custom_minimum_size = Vector2(320, 14)
	box.add_child(_hud.progress)
	box.add_child(MenuKit.label("W/S throttle, brake | A/D steer | Space handbrake | E hack the next red light", 16))

	_hud.timer = MenuKit.label("", 40, MenuKit.GOLD)
	_hud.timer.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_hud.timer.position.y = 10.0
	_hud.timer.grow_horizontal = Control.GROW_DIRECTION_BOTH
	layer.add_child(_hud.timer)

	_hud.speed = MenuKit.label("", 54, Color.WHITE)
	_hud.speed.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_hud.speed.position = Vector2(-300, -110)
	layer.add_child(_hud.speed)

	_hud.message = MenuKit.label("", 44)
	_hud.message.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hud.message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hud.message.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	layer.add_child(_hud.message)


func total_seconds() -> float:
	return elapsed + penalty


func time_limit() -> float:
	return data.get("time_limit", 0.0)


func _update_hud() -> void:
	_hud.speed.text = "%d km/h" % roundi(speed * 3.6)
	_hud.progress.value = clampf(distance / length, 0.0, 1.0)
	_hud.crashes.text = "Crashes: %d  (+%ds each)" % [crashes, int(data.get("crash_penalty", 4.0))]
	if time_limit() > 0.0:
		var left := maxf(0.0, time_limit() - total_seconds())
		_hud.timer.text = MenuKit.format_time(left)
		_hud.timer.modulate = Color(1.0, 0.4, 0.4) if left < 20.0 else Color.WHITE
	var light := next_light()
	if light == null:
		_hud.light.text = "No more junctions. Floor it!"
	else:
		var gap: float = maxf(0.0, (-light.junction_z) - distance)
		var status := "GREEN" if light.green else "RED"
		var extra := ""
		if not light.green:
			extra = "  [E] hack" if light.cooldown_left <= 0.0 and gap < 90.0 else ""
		_hud.light.text = "Next light %dm: %s%s" % [roundi(gap), status, extra]
		_hud.light.modulate = Color(0.5, 1.0, 0.6) if light.green else Color(1.0, 0.5, 0.5)


func _update_engine() -> void:
	var audio := Game.audio()
	if audio:
		audio.engine(true, speed / max_speed)


func _exit_tree() -> void:
	var audio := Game.audio()
	if audio:
		audio.engine(false)


func _check_end() -> void:
	if distance >= length:
		_finish(true, "ARRIVED AT PNU", data.get("story_outro", []))
	elif time_limit() > 0.0 and total_seconds() >= time_limit():
		_finish(false, "TOO LATE", [data.get("time_up_text", "The exam started without her.")])


func _finish(won: bool, title: String, lines: Array) -> void:
	if _finished:
		return
	_finished = true
	_won = won
	_hud.message.text = title
	var audio := Game.audio()
	if audio:
		audio.engine(false)
	Game.sfx("win" if won else "caught")
	if test_mode:
		return
	await get_tree().create_timer(1.2).timeout
	_hud.message.text = ""
	var panel := ResultPanelScript.new()
	add_child(panel)
	var has_next := false
	if won:
		has_next = Game.state().complete_level(total_seconds(), crashes)
	panel.show_result(won, title, lines, total_seconds(), crashes, has_next)


func _play_intro() -> void:
	var intro: Array = data.get("story_intro", [])
	if intro.is_empty() or Game.state().intro_seen_for == level_index:
		return
	Game.state().intro_seen_for = level_index
	var card := StoryCardScript.new()
	add_child(card)
	get_tree().paused = true
	card.play(data.title, intro)
	await card.finished
	get_tree().paused = false
	card.queue_free()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elapsed = 0.0


func _hint(key: String) -> void:
	if _hints_shown.has(key) or not data.get("hints", {}).has(key):
		return
	_hints_shown[key] = true
	captions.say(data.hints[key], 4.5)
