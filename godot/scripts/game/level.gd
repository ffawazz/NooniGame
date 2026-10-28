extends Node3D
## A stealth level, built entirely from a data dictionary (see scripts/levels/*.gd). Handles the world, the
## characters, the exit, win/lose, pausing, story cards and the HUD.
##
## Tests use `level_index` to pick a level directly and set `test_mode` to skip menus, cards and scene changes.

const Game := preload("res://scripts/core/game.gd")
const NooniScript := preload("res://scripts/characters/nooni.gd")
const BruceScript := preload("res://scripts/characters/bruce.gd")
const SembaScript := preload("res://scripts/characters/semba.gd")
const BrotherScript := preload("res://scripts/ai/brother_ai.gd")
const SwitcherScript := preload("res://scripts/characters/character_switcher.gd")
const CoverScript := preload("res://scripts/stealth/cover_volume.gd")
const ClimbableScript := preload("res://scripts/puzzle/climbable.gd")
const PlateScript := preload("res://scripts/puzzle/pressure_plate.gd")
const DoorScript := preload("res://scripts/puzzle/sliding_door.gd")
const HackableScript := preload("res://scripts/puzzle/hackable.gd")
const AnchorScript := preload("res://scripts/puzzle/grapple_anchor.gd")
const HudScript := preload("res://scripts/ui/hud.gd")
const CaptionsScript := preload("res://scripts/ui/captions.gd")
const StoryCardScript := preload("res://scripts/ui/story_card.gd")
const PauseMenuScript := preload("res://scripts/ui/pause_menu.gd")
const ResultPanelScript := preload("res://scripts/ui/result_panel.gd")
const Levels := preload("res://scripts/levels/levels.gd")
const Toon := preload("res://scripts/core/toon.gd")

## -1 = whatever GameState says. Tests set a number.
@export var level_index := -1
## Headless tests: no mouse capture, no cards or menus, no scene changes.
var test_mode := false

var data: Dictionary
var nooni: CharacterBody3D
var bruce: CharacterBody3D
var semba: CharacterBody3D
var yasser: CharacterBody3D  ## The first brother, kept as a shortcut.
var brothers: Array = []
var doors: Dictionary = {}
var plates: Array = []
var door: AnimatableBody3D  ## The first door.
var plate: Area3D  ## The first plate.
var switcher: Node
var exit_position := Vector3.ZERO
var goal_radius := 1.2
var restart_delay := 2.5

var hud: Node
var captions: Node
var pause_menu: Node
var _result: Node
var _glasses: Control
var _message_label: Label
var _finished := false
var _won := false
var _started_msec := 0
var _hints_shown := {}


func _ready() -> void:
	var index: int = level_index if level_index >= 0 else Game.state().current_level
	level_index = index
	data = Levels.data(index)

	_build_environment()
	_build_world()
	_build_decor()
	_build_covers()
	_build_climbables()
	_build_doors_and_plates()
	_build_hackables()
	_build_anchors()
	_build_characters()
	_build_exit()

	hud = HudScript.new()
	add_child(hud)
	hud.setup(self)
	_glasses = hud.glasses
	_message_label = hud.message_label

	switcher = SwitcherScript.new()
	switcher.name = "CharacterSwitcher"
	switcher.test_mode = test_mode
	add_child(switcher)
	switcher.setup([nooni, bruce, semba], hud.wheel_ui, 0)

	captions = CaptionsScript.new()
	add_child(captions)
	_connect_hint_events()

	_started_msec = Time.get_ticks_msec()
	if not test_mode:
		pause_menu = PauseMenuScript.new()
		add_child(pause_menu)
		pause_menu.setup(self)
		_play_intro()


func _unhandled_input(event: InputEvent) -> void:
	if test_mode or _finished or pause_menu == null:
		return
	if event.is_action_pressed("pause"):
		pause_menu.toggle()
		get_viewport().set_input_as_handled()


func _physics_process(_delta: float) -> void:
	if _finished:
		return
	if nooni.grapple_target != null:
		_hint("grapple")
	var d := nooni.global_position - exit_position
	d.y = 0.0
	if d.length() <= goal_radius:
		_win()


## Seconds since the level began (not counting time spent on the story card).
func elapsed_seconds() -> float:
	return (Time.get_ticks_msec() - _started_msec) / 1000.0


# ---- Building: world -----------------------------------------------------------------

func _build_environment() -> void:
	var env_data: Dictionary = data.get("environment", {})
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = env_data.get("sky_top", Color(0.36, 0.52, 0.86))
	sky_material.sky_horizon_color = env_data.get("sky_horizon", Color(0.98, 0.86, 0.74))
	sky_material.ground_horizon_color = sky_material.sky_horizon_color
	sky_material.ground_bottom_color = Color(0.45, 0.4, 0.5)
	var sky := Sky.new()
	sky.sky_material = sky_material

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = env_data.get("ambient", Color(0.68, 0.7, 0.9))
	env.ambient_light_energy = 0.26
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52.0, 35.0, 0.0)
	sun.light_color = env_data.get("sun", Color(1.0, 0.93, 0.82))
	sun.light_energy = env_data.get("sun_energy", 0.62)
	sun.shadow_enabled = true
	add_child(sun)


## Everything solid goes under one NavigationRegion3D, which is then baked for the brothers.
func _build_world() -> void:
	var region := NavigationRegion3D.new()
	region.name = "World"
	add_child(region)

	for solid in data.solids:
		_box(region, solid.name, solid.pos, solid.size, solid.color, solid.get("opts", {}))

	# Doors are solid while closed, so they belong in the baked region too.
	for spec in data.get("doors", []):
		var new_door := DoorScript.new()
		new_door.name = spec.name
		new_door.position = spec.pos
		new_door.display_name = spec.get("label", spec.name)
		if spec.has("size"):
			new_door.size = spec.size
		if spec.has("open_offset"):
			new_door.open_offset = spec.open_offset
		region.add_child(new_door)
		doors[spec.name] = new_door
		if door == null:
			door = new_door

	var nav_mesh := NavigationMesh.new()
	nav_mesh.agent_radius = 0.5
	nav_mesh.agent_height = 2.0
	nav_mesh.agent_max_climb = 0.25
	nav_mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nav_mesh.geometry_collision_mask = 1
	region.navigation_mesh = nav_mesh
	region.bake_navigation_mesh(false)


## Visual-only dressing (no collision, so it never changes sight lines or paths).
func _build_decor() -> void:
	var decor := Node3D.new()
	decor.name = "Decor"
	add_child(decor)
	for item in data.get("decor", []):
		match item.t:
			"box":
				var box := Toon.box(decor, item.size, item.pos, item.color, item.get("outline", 0.02))
				box.rotation_degrees = item.get("rot", Vector3.ZERO)
			"cyl":
				var cyl := Toon.cylinder(decor, item.r, item.h, item.pos, item.color, item.get("outline", 0.02), item.get("top_r", -1.0))
				cyl.rotation_degrees = item.get("rot", Vector3.ZERO)
			"sphere":
				Toon.sphere(decor, item.r, item.pos, item.color, item.get("outline", 0.02))
			"omni":
				var glow := OmniLight3D.new()
				glow.position = item.pos
				glow.light_color = item.color
				glow.light_energy = item.energy
				glow.omni_range = item.range
				decor.add_child(glow)


func _build_covers() -> void:
	for spec in data.get("covers", []):
		var zone := CoverScript.new()
		zone.name = spec.name
		zone.position = spec.pos
		zone.size = spec.size
		add_child(zone)


func _build_climbables() -> void:
	for spec in data.get("climbables", []):
		var zone := ClimbableScript.new()
		zone.name = spec.name
		zone.position = spec.pos
		zone.size = spec.size
		zone.wall_direction = spec.wall
		zone.top_y = spec.top_y
		zone.landing = spec.landing
		add_child(zone)


func _build_doors_and_plates() -> void:
	for spec in data.get("plates", []):
		var new_plate := PlateScript.new()
		new_plate.name = spec.name
		new_plate.position = spec.pos
		new_plate.required_weight = spec.required
		new_plate.target = doors[spec.door]
		add_child(new_plate)
		plates.append(new_plate)
		if plate == null:
			plate = new_plate


func _build_hackables() -> void:
	for spec in data.get("hackables", []):
		var device := HackableScript.new()
		device.name = spec.name
		device.kind = spec.kind
		device.display_name = spec.get("label", spec.name)
		device.position = spec.pos
		device.rotation.y = spec.get("yaw", 0.0)
		device.cooldown_seconds = spec.get("cooldown", 12.0)
		device.effect_seconds = spec.get("seconds", 7.0)
		if spec.has("door"):
			device.target = doors[spec.door]
		add_child(device)


func _build_anchors() -> void:
	for spec in data.get("anchors", []):
		var anchor := AnchorScript.new()
		anchor.name = spec.name
		anchor.position = spec.pos
		anchor.landing = spec.landing
		anchor.rotation.y = spec.get("yaw", 0.0)
		add_child(anchor)


func _build_characters() -> void:
	var spawns: Dictionary = data.spawns
	nooni = _spawn_cat(NooniScript, "Nooni", spawns.nooni)
	bruce = _spawn_cat(BruceScript, "Bruce", spawns.get("bruce", {}))
	semba = _spawn_cat(SembaScript, "Semba", spawns.get("semba", {}))

	for spec in data.get("brothers", []):
		var brother := BrotherScript.new()
		brother.name = spec.name
		brother.kind = spec.get("kind", "yasser")
		brother.position = spec.pos
		brother.rotation.y = spec.get("yaw", 0.0)
		var route: Array[Vector3] = []
		for point in spec.get("route", []):
			route.append(point)
		brother.patrol_points = route
		brother.caught.connect(_on_caught)
		add_child(brother)
		brothers.append(brother)
		if yasser == null:
			yasser = brother


func _spawn_cat(script: GDScript, cat_name: String, spawn: Dictionary) -> CharacterBody3D:
	if spawn.is_empty():
		return null
	var cat: CharacterBody3D = script.new()
	cat.name = cat_name
	cat.test_mode = test_mode
	cat.position = spawn.pos
	cat.rotation.y = spawn.get("yaw", 0.0)
	add_child(cat)
	return cat


func _build_exit() -> void:
	var spec: Dictionary = data.exit
	exit_position = spec.pos
	goal_radius = spec.get("radius", 1.2)

	var pad := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(goal_radius * 1.25, 0.1, goal_radius * 1.25)
	pad.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.9, 0.3, 0.8)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pad.material_override = mat
	pad.position = exit_position + Vector3(0, 0.05, 0)
	add_child(pad)

	var label := Label3D.new()
	label.text = spec.get("label", "EXIT")
	label.font_size = 64
	label.pixel_size = 0.008
	label.outline_size = 12
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = exit_position + Vector3(0, 1.0, 0)
	add_child(label)


func _box(parent: Node, box_name: String, pos: Vector3, size: Vector3, color: Color, options := {}) -> void:
	var body := StaticBody3D.new()
	body.name = box_name
	body.position = pos
	body.collision_layer = 1  # world
	body.collision_mask = 0

	var shape := BoxShape3D.new()
	shape.size = size
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)

	Toon.box(body, size, Vector3.ZERO, color, 0.035, options)
	parent.add_child(body)


# ---- Story, hints and the end of the level -------------------------------------------

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
	_started_msec = Time.get_ticks_msec()


func _connect_hint_events() -> void:
	nooni.stress.smudged.connect(func(): _hint("first_smudge"))
	nooni.vision.activated.connect(func(): _hint("vision"))
	for new_plate in plates:
		new_plate.changed.connect(func(active: bool): if active: _hint("door_open"))
	if semba:
		semba.roared.connect(func(_position: Vector3): _hint("roar"))


## Shows data.hints[key] once.
func _hint(key: String) -> void:
	if _hints_shown.has(key) or not data.get("hints", {}).has(key):
		return
	_hints_shown[key] = true
	captions.say(data.hints[key], 5.0)


func _on_caught(brother: Node) -> void:
	_finish(false, "SPOTTED BY %s" % brother.name.to_upper(), ["This changes everything."])


func _win() -> void:
	_finish(true, "MISSION COMPLETE", data.get("story_outro", []))


func _finish(won: bool, title: String, lines: Array) -> void:
	if _finished:
		return
	_finished = true
	_won = won
	hud.message_label.text = title
	switcher.close_wheel(false)
	switcher.locked = true
	for character in [nooni, bruce, semba]:
		if character:
			character.input_enabled = false
	if test_mode:
		return

	await get_tree().create_timer(1.2).timeout
	hud.message_label.text = ""
	_result = ResultPanelScript.new()
	add_child(_result)
	var has_next := false
	if won:
		has_next = Game.state().complete_level(elapsed_seconds(), Game.state().attempts)
	_result.show_result(won, title, lines, elapsed_seconds(), Game.state().attempts, has_next)
