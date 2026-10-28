extends Node3D
## Greybox stealth test room, built entirely in code: level, cover, Nooni, Bruce, Yasser, the pantry puzzle, HUD.
## Layout (metres, +X east, +Z south):
##   Nooni starts by the south wall, west of the sofa; the exit pad is in the opposite (+X, +Z) corner.
##   Yasser walks a loop through the middle; the sofa and counter are cover.
##   The exit pad is locked in a pantry. Its door opens only while Bruce (weight 3) sits on the pressure plate;
##   Nooni weighs too little. Bruce's Bat-Nap can freeze Yasser while Nooni sneaks past.
##   Semba can climb the curtain or bookshelf on the west wall and roar to draw Yasser over there.

const NooniScript := preload("res://scripts/characters/nooni.gd")
const BrotherScript := preload("res://scripts/ai/brother_ai.gd")
const CoverScript := preload("res://scripts/stealth/cover_volume.gd")
const Toon := preload("res://scripts/core/toon.gd")
const BruceScript := preload("res://scripts/characters/bruce.gd")
const SembaScript := preload("res://scripts/characters/semba.gd")
const ClimbableScript := preload("res://scripts/puzzle/climbable.gd")
const SwitcherScript := preload("res://scripts/characters/character_switcher.gd")
const WheelUIScript := preload("res://scripts/ui/cat_wheel_ui.gd")
const PlateScript := preload("res://scripts/puzzle/pressure_plate.gd")
const DoorScript := preload("res://scripts/puzzle/sliding_door.gd")

## Headless tests: no mouse capture, no auto-restart.
var test_mode := false

var nooni: CharacterBody3D
var bruce: CharacterBody3D
var semba: CharacterBody3D
var yasser: CharacterBody3D
var switcher: Node
var door: AnimatableBody3D
var plate: Area3D
var exit_position := Vector3(5.0, 0.0, 4.0)
var goal_radius := 1.2
var restart_delay := 2.5

var _finished := false
var _status_label: Label
var _door_label: Label
var _wheel_ui: Control
var _brother_label: Label
var _awareness_bar: ProgressBar
var _message_label: Label


func _ready() -> void:
	_build_environment()
	_build_level()
	_build_cover()
	_build_decor()
	_build_climbables()
	_build_characters()
	_build_plate()
	_build_exit()
	_build_hud()
	_build_switcher()


func _physics_process(_delta: float) -> void:
	if _finished:
		return
	var d := nooni.global_position - exit_position
	d.y = 0.0
	if d.length() <= goal_radius:
		_finish("MISSION COMPLETE\nSnack acquired. Nobody suspects a thing.")


func _process(_delta: float) -> void:
	_status_label.text = "%s: %s" % [switcher.current.display_name, switcher.current.status_text()]
	_door_label.text = "Pantry door: %s" % ("OPEN" if door.is_open else "LOCKED (a heavy cat on the plate opens it)")
	_brother_label.text = "Yasser: " + yasser.state_name()
	_awareness_bar.value = yasser.awareness


# ---- Building ------------------------------------------------------------------------

func _build_environment() -> void:
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.36, 0.52, 0.86)
	sky_material.sky_horizon_color = Color(0.98, 0.86, 0.74)
	sky_material.ground_horizon_color = Color(0.98, 0.86, 0.74)
	sky_material.ground_bottom_color = Color(0.45, 0.4, 0.5)
	var sky := Sky.new()
	sky.sky_material = sky_material

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.68, 0.7, 0.9)
	env.ambient_light_energy = 0.26
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52.0, 35.0, 0.0)
	sun.light_color = Color(1.0, 0.93, 0.82)
	sun.light_energy = 0.62
	sun.shadow_enabled = true
	add_child(sun)


func _build_level() -> void:
	var region := NavigationRegion3D.new()
	region.name = "Level"
	add_child(region)

	var floor_tiles := {"checker_size": 1.0, "pattern_color": Color(0.7, 0.55, 0.42)}
	var wall_panel := {"wainscot_height": 0.9, "pattern_color": Color(0.5, 0.66, 0.66)}
	_box(region, "Floor", Vector3(0, -0.05, 0), Vector3(12, 0.1, 10), Color(0.84, 0.72, 0.56), floor_tiles)
	_box(region, "Wall_N", Vector3(0, 1.25, 5.05), Vector3(12.2, 2.5, 0.1), Color(0.93, 0.8, 0.62), wall_panel)
	_box(region, "Wall_S", Vector3(0, 1.25, -5.05), Vector3(12.2, 2.5, 0.1), Color(0.93, 0.8, 0.62), wall_panel)
	_box(region, "Wall_E", Vector3(6.05, 1.25, 0), Vector3(0.1, 2.5, 10), Color(0.93, 0.8, 0.62), wall_panel)
	_box(region, "Wall_W", Vector3(-6.05, 1.25, 0), Vector3(0.1, 2.5, 10), Color(0.93, 0.8, 0.62), wall_panel)
	_box(region, "Sofa", Vector3(-2, 0.4, -3), Vector3(3, 0.8, 1), Color(0.55, 0.38, 0.78))
	_box(region, "Counter", Vector3(4.5, 0.5, -1), Vector3(1, 1, 3), Color(0.85, 0.55, 0.35))
	_box(region, "CoffeeTable", Vector3(-0.5, 0.25, 0), Vector3(1.6, 0.5, 0.8), Color(0.5, 0.33, 0.24))

	_box(region, "Bookshelf", Vector3(-5.75, 1.0, 3.2), Vector3(0.5, 2.0, 2.0), Color(0.62, 0.42, 0.28))

	# Pantry in the north-east corner. The exit pad is inside, behind a door that Bruce can open.
	var panel_color := Color(0.93, 0.8, 0.62)
	_box(region, "Pantry_West", Vector3(3.2, 1.25, 3.75), Vector3(0.15, 2.5, 2.5), panel_color, wall_panel)
	_box(region, "Pantry_South_A", Vector3(3.7, 1.25, 2.5), Vector3(1.0, 2.5, 0.15), panel_color, wall_panel)
	_box(region, "Pantry_South_B", Vector3(5.6, 1.25, 2.5), Vector3(0.8, 2.5, 0.15), panel_color, wall_panel)
	_box(region, "Pantry_Lintel", Vector3(4.7, 2.4, 2.5), Vector3(1.0, 0.2, 0.15), panel_color, wall_panel)
	door = DoorScript.new()
	door.name = "PantryDoor"
	door.position = Vector3(4.7, 1.1, 2.5)
	region.add_child(door)

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

	Toon.box(decor, Vector3(3.2, 0.02, 2.2), Vector3(-0.5, 0.011, 0), Color(0.78, 0.36, 0.34), 0.0)  # rug
	Toon.box(decor, Vector3(0.55, 0.22, 0.5), Vector3(-2.9, 0.91, -3.0), Color(0.98, 0.78, 0.3), 0.02)  # cushions
	Toon.box(decor, Vector3(0.55, 0.22, 0.5), Vector3(-1.1, 0.91, -3.0), Color(0.35, 0.75, 0.7), 0.02)

	# Framed picture on the north wall.
	Toon.box(decor, Vector3(2.0, 1.0, 0.05), Vector3(-2.0, 1.55, 4.97), Color(0.3, 0.2, 0.15), 0.0)
	Toon.box(decor, Vector3(1.8, 0.8, 0.02), Vector3(-2.0, 1.55, 4.945), Color(0.55, 0.78, 0.95), 0.0)

	# Books and shelves on the bookshelf's front face (x = -5.5).
	var spines := [Color(0.85, 0.3, 0.35), Color(0.3, 0.55, 0.85), Color(0.95, 0.75, 0.25), Color(0.4, 0.75, 0.5), Color(0.7, 0.4, 0.8)]
	for row in 3:
		var shelf_y := 0.3 + row * 0.55
		Toon.box(decor, Vector3(0.08, 0.04, 1.9), Vector3(-5.46, shelf_y, 3.2), Color(0.42, 0.27, 0.18), 0.0)
		for i in 7:
			var book := Toon.box(decor, Vector3(0.12, 0.34, 0.2), Vector3(-5.44, shelf_y + 0.2, 2.35 + i * 0.27), spines[(i + row) % spines.size()], 0.01)
			book.rotation_degrees.z = 4.0 * ((i + row) % 3 - 1)

	# Curtain on the west wall with its rod, just south of the bookshelf.
	Toon.box(decor, Vector3(0.05, 2.1, 1.1), Vector3(-5.95, 1.2, 1.6), Color(0.78, 0.3, 0.48), 0.02)
	var rod := Toon.cylinder(decor, 0.03, 1.4, Vector3(-5.9, 2.3, 1.6), Color(0.3, 0.22, 0.18), 0.01)
	rod.rotation_degrees = Vector3(90, 0, 0)

	# Floor lamp with a warm light, tucked in the north-west corner.
	Toon.cylinder(decor, 0.04, 1.6, Vector3(-5.4, 0.8, 4.4), Color(0.2, 0.18, 0.25), 0.015)
	Toon.cylinder(decor, 0.32, 0.4, Vector3(-5.4, 1.8, 4.4), Color(1.0, 0.92, 0.6), 0.02, 0.18)
	var glow := OmniLight3D.new()
	glow.position = Vector3(-5.4, 1.7, 4.4)
	glow.light_color = Color(1.0, 0.85, 0.55)
	glow.light_energy = 0.45
	glow.omni_range = 6.0
	decor.add_child(glow)


## Grab zones for Semba. Wall direction points into the surface; the landing is a spot on top of the bookshelf.
func _build_climbables() -> void:
	_climbable("Climb_Bookshelf", Vector3(-5.0, 1.1, 3.2), Vector3(0.9, 2.2, 1.6), 2.0, Vector3(-5.72, 2.05, 3.2))
	_climbable("Climb_Curtain", Vector3(-5.4, 1.2, 1.6), Vector3(1.0, 2.4, 1.1), 2.3, Vector3(-5.72, 2.05, 2.6))


func _build_cover() -> void:
	_cover("CoverZone_Sofa", Vector3(-2, 0.9, -3), Vector3(3.6, 1.8, 2.4))
	_cover("CoverZone_Counter", Vector3(4.5, 0.9, -1), Vector3(2.2, 1.8, 3.6))


func _build_characters() -> void:
	nooni = NooniScript.new()
	nooni.name = "Nooni"
	nooni.test_mode = test_mode
	nooni.position = Vector3(-3.2, 0, -4.3)  # south wall, with open floor behind her for the camera
	nooni.rotation.y = -PI * 0.5  # facing +X
	add_child(nooni)

	bruce = BruceScript.new()
	bruce.name = "Bruce"
	bruce.test_mode = test_mode
	bruce.position = Vector3(-4.4, 0, -4.2)
	bruce.rotation.y = -PI * 0.5
	add_child(bruce)

	semba = SembaScript.new()
	semba.name = "Semba"
	semba.test_mode = test_mode
	semba.position = Vector3(-5.2, 0, -3.5)
	semba.rotation.y = -PI * 0.5
	add_child(semba)

	yasser = BrotherScript.new()
	yasser.name = "Yasser"
	yasser.position = Vector3(-3, 0, 1.5)
	yasser.rotation.y = -PI * 0.5  # facing +X
	var route: Array[Vector3] = [
		Vector3(-3, 0, 1.5), Vector3(2, 0, 1.5),
		Vector3(2, 0, -1.5), Vector3(-3, 0, -1.5),
	]
	yasser.patrol_points = route
	yasser.caught.connect(_on_caught)
	add_child(yasser)


func _build_plate() -> void:
	plate = PlateScript.new()
	plate.name = "PressurePlate"
	plate.position = Vector3(0.5, 0, 3.8)
	plate.target = door
	add_child(plate)


func _build_switcher() -> void:
	switcher = SwitcherScript.new()
	switcher.name = "CharacterSwitcher"
	switcher.test_mode = test_mode
	add_child(switcher)
	switcher.setup([nooni, bruce, semba], _wheel_ui, 0)


func _build_exit() -> void:
	var pad := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(1.5, 0.1, 1.5)
	pad.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.9, 0.3, 0.8)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pad.material_override = mat
	pad.position = exit_position + Vector3(0, 0.05, 0)
	add_child(pad)


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	var box := VBoxContainer.new()
	box.position = Vector2(16, 12)
	layer.add_child(box)

	_status_label = _hud_label()
	box.add_child(_status_label)
	_brother_label = _hud_label()
	box.add_child(_brother_label)
	_door_label = _hud_label()
	box.add_child(_door_label)

	_awareness_bar = ProgressBar.new()
	_awareness_bar.min_value = 0.0
	_awareness_bar.max_value = 1.0
	_awareness_bar.step = 0.01
	_awareness_bar.show_percentage = false
	_awareness_bar.custom_minimum_size = Vector2(220, 12)
	box.add_child(_awareness_bar)

	var help := _hud_label()
	help.text = "WASD/arrows move | Mouse look | Ctrl/C crouch | Shift sprint | Space jump | Q ability | Hold Tab: cat wheel | 1/2/3 switch | Esc free mouse"
	box.add_child(help)

	_wheel_ui = WheelUIScript.new()
	layer.add_child(_wheel_ui)

	_message_label = _hud_label()
	_message_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_message_label.add_theme_font_size_override("font_size", 36)
	layer.add_child(_message_label)


# ---- Helpers -------------------------------------------------------------------------

func _hud_label() -> Label:
	var label := Label.new()
	label.add_theme_color_override("font_outline_color", Color(0.07, 0.05, 0.11))
	label.add_theme_constant_override("outline_size", 6)
	return label


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


func _climbable(climb_name: String, pos: Vector3, size: Vector3, top_y: float, landing: Vector3) -> void:
	var zone := ClimbableScript.new()
	zone.name = climb_name
	zone.position = pos
	zone.size = size
	zone.wall_direction = Vector3(-1, 0, 0)
	zone.top_y = top_y
	zone.landing = landing
	add_child(zone)


func _cover(cover_name: String, pos: Vector3, size: Vector3) -> void:
	var zone := CoverScript.new()
	zone.name = cover_name
	zone.position = pos
	zone.size = size
	add_child(zone)


func _on_caught(brother: Node) -> void:
	_finish("SPOTTED BY %s\nThis changes everything." % brother.name.to_upper())


func _finish(message: String) -> void:
	if _finished:
		return
	_finished = true
	_message_label.text = message
	switcher.close_wheel(false)
	switcher.locked = true
	for character in [nooni, bruce, semba]:
		character.input_enabled = false
	if not test_mode:
		await get_tree().create_timer(restart_delay).timeout
		get_tree().reload_current_scene()
