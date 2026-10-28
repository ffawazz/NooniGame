extends Node3D
## Greybox stealth test room, built entirely in code: level, cover, Nooni, Yasser, exit, HUD.
## Layout (metres, +X east, +Z south):
##   Nooni starts by the south wall, west of the sofa; the exit pad is in the opposite (+X, +Z) corner.
##   Yasser walks a loop through the middle; the sofa and counter are cover.

const NooniScript := preload("res://scripts/characters/nooni.gd")
const BrotherScript := preload("res://scripts/ai/brother_ai.gd")
const CoverScript := preload("res://scripts/stealth/cover_volume.gd")

## Headless tests: no mouse capture, no auto-restart.
var test_mode := false

var nooni: CharacterBody3D
var yasser: CharacterBody3D
var exit_position := Vector3(5.0, 0.0, 4.0)
var goal_radius := 1.2
var restart_delay := 2.5

var _finished := false
var _status_label: Label
var _brother_label: Label
var _awareness_bar: ProgressBar
var _message_label: Label


func _ready() -> void:
	_build_environment()
	_build_level()
	_build_cover()
	_build_characters()
	_build_exit()
	_build_hud()


func _physics_process(_delta: float) -> void:
	if _finished:
		return
	var d := nooni.global_position - exit_position
	d.y = 0.0
	if d.length() <= goal_radius:
		_finish("MISSION COMPLETE\nSnack acquired. Nobody suspects a thing.")


func _process(_delta: float) -> void:
	_status_label.text = "Nooni: " + nooni.status_text()
	_brother_label.text = "Yasser: " + yasser.state_name()
	_awareness_bar.value = yasser.awareness


# ---- Building ------------------------------------------------------------------------

func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.08, 0.1, 0.16)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.75, 0.75, 0.8)
	env.ambient_light_energy = 0.8
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55.0, 30.0, 0.0)
	sun.shadow_enabled = true
	add_child(sun)


func _build_level() -> void:
	var region := NavigationRegion3D.new()
	region.name = "Level"
	add_child(region)

	_box(region, "Floor", Vector3(0, -0.05, 0), Vector3(12, 0.1, 10), Color(0.55, 0.55, 0.58))
	_box(region, "Wall_N", Vector3(0, 1.25, 5.05), Vector3(12.2, 2.5, 0.1), Color(0.8, 0.78, 0.72))
	_box(region, "Wall_S", Vector3(0, 1.25, -5.05), Vector3(12.2, 2.5, 0.1), Color(0.8, 0.78, 0.72))
	_box(region, "Wall_E", Vector3(6.05, 1.25, 0), Vector3(0.1, 2.5, 10), Color(0.8, 0.78, 0.72))
	_box(region, "Wall_W", Vector3(-6.05, 1.25, 0), Vector3(0.1, 2.5, 10), Color(0.8, 0.78, 0.72))
	_box(region, "Sofa", Vector3(-2, 0.4, -3), Vector3(3, 0.8, 1), Color(0.45, 0.3, 0.6))
	_box(region, "Counter", Vector3(4.5, 0.5, -1), Vector3(1, 1, 3), Color(0.6, 0.45, 0.3))
	_box(region, "CoffeeTable", Vector3(-0.5, 0.25, 0), Vector3(1.6, 0.5, 0.8), Color(0.35, 0.25, 0.2))

	var nav_mesh := NavigationMesh.new()
	nav_mesh.agent_radius = 0.5
	nav_mesh.agent_height = 2.0
	nav_mesh.agent_max_climb = 0.25
	nav_mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nav_mesh.geometry_collision_mask = 1
	region.navigation_mesh = nav_mesh
	region.bake_navigation_mesh(false)


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

	_status_label = Label.new()
	box.add_child(_status_label)
	_brother_label = Label.new()
	box.add_child(_brother_label)

	_awareness_bar = ProgressBar.new()
	_awareness_bar.min_value = 0.0
	_awareness_bar.max_value = 1.0
	_awareness_bar.step = 0.01
	_awareness_bar.show_percentage = false
	_awareness_bar.custom_minimum_size = Vector2(220, 12)
	box.add_child(_awareness_bar)

	var help := Label.new()
	help.text = "WASD/arrows move | Mouse look | Ctrl/C crouch | Shift sprint | Space jump | Esc free mouse"
	box.add_child(help)

	_message_label = Label.new()
	_message_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_message_label.add_theme_font_size_override("font_size", 36)
	layer.add_child(_message_label)


# ---- Helpers -------------------------------------------------------------------------

func _box(parent: Node, box_name: String, pos: Vector3, size: Vector3, color: Color) -> void:
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

	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mesh.material_override = mat
	body.add_child(mesh)

	parent.add_child(body)


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
	nooni.input_enabled = false
	if not test_mode:
		await get_tree().create_timer(restart_delay).timeout
		get_tree().reload_current_scene()
