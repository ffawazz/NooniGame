extends Node3D
## Title screen: a little diorama of the three heroes under a slowly orbiting camera, with the menu on top.

const Game := preload("res://scripts/core/game.gd")
const NooniScript := preload("res://scripts/characters/nooni.gd")
const BruceScript := preload("res://scripts/characters/bruce.gd")
const SembaScript := preload("res://scripts/characters/semba.gd")
const MenuKit := preload("res://scripts/ui/menu_kit.gd")
const Levels := preload("res://scripts/levels/levels.gd")
const Toon := preload("res://scripts/core/toon.gd")

var _pages: Dictionary = {}
var _camera: Camera3D
var _angle := 0.4
var _continue_button: Button
var _level_box: VBoxContainer


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Game.music("music_menu")
	_build_backdrop()
	_build_ui()


func _process(delta: float) -> void:
	_angle += delta * 0.12
	_camera.global_position = Vector3(sin(_angle) * 4.6, 1.5, cos(_angle) * 4.6)
	_camera.look_at(Vector3(0, 0.9, 0), Vector3.UP)
	_camera.global_position -= _camera.global_transform.basis.x * 1.4  # heroes sit right of centre, menu on the left


func _build_backdrop() -> void:
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.2, 0.15, 0.4)
	sky_material.sky_horizon_color = Color(0.95, 0.6, 0.45)
	sky_material.ground_horizon_color = Color(0.95, 0.6, 0.45)
	sky_material.ground_bottom_color = Color(0.25, 0.15, 0.3)
	var sky := Sky.new()
	sky.sky_material = sky_material
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.7, 0.65, 0.95)
	env.ambient_light_energy = 0.3
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, 40, 0)
	sun.light_color = Color(1.0, 0.85, 0.7)
	sun.light_energy = 0.7
	sun.shadow_enabled = true
	add_child(sun)

	var ground := StaticBody3D.new()
	ground.collision_layer = 1
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(12, 0.2, 12)
	shape.shape = box
	shape.position.y = -0.1
	ground.add_child(shape)
	Toon.box(ground, Vector3(12, 0.2, 12), Vector3(0, -0.1, 0), Color(0.85, 0.7, 0.55), 0.035, {"checker_size": 1.0, "pattern_color": Color(0.7, 0.55, 0.42)})
	add_child(ground)

	for spec in [[NooniScript, Vector3(0, 0, 0)], [BruceScript, Vector3(-1.3, 0, 0.7)], [SembaScript, Vector3(1.3, 0, 0.7)]]:
		var hero: CharacterBody3D = spec[0].new()
		hero.test_mode = true  # no mouse capture
		hero.position = spec[1]
		hero.rotation.y = 0.0
		add_child(hero)

	_camera = Camera3D.new()
	add_child(_camera)
	_camera.current = true


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(root)

	var title := MenuKit.label("NOONI'S TACTICAL GUIDE\nTO EVERYDAY LIFE", 54, MenuKit.GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	title.position.y = 24.0
	title.grow_horizontal = Control.GROW_DIRECTION_BOTH
	title.add_theme_font_size_override("font_size", 50)
	root.add_child(title)

	var tagline := MenuKit.label("A cozy stealth-comedy of unbearable seriousness", 22, Color(1.0, 0.92, 0.85))
	tagline.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	tagline.position.y = 170.0
	tagline.grow_horizontal = Control.GROW_DIRECTION_BOTH
	root.add_child(tagline)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.offset_top = 150.0
	center.anchor_right = 0.5
	root.add_child(center)
	var stack := Control.new()
	center.add_child(stack)

	_pages["main"] = _make_page(stack, _main_page)
	_pages["levels"] = _make_page(stack, _levels_page)
	_pages["controls"] = _make_page(stack, _controls_page)
	_pages["settings"] = _make_page(stack, _settings_page)
	_show("main")


func _make_page(parent: Control, builder: Callable) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.position = Vector2(-190, -215)
	parent.add_child(box)
	builder.call(box)
	return box


func _show(page: String) -> void:
	for key in _pages:
		_pages[key].visible = key == page
	if page == "main":
		_continue_button.disabled = not Game.state().has_save()
	if page == "levels":
		_refresh_levels()


func _main_page(box: VBoxContainer) -> void:
	box.add_child(MenuKit.button("New game", func(): Game.state().new_game()))
	_continue_button = MenuKit.button("Continue", func(): Game.state().continue_game())
	box.add_child(_continue_button)
	box.add_child(MenuKit.button("Level select", func(): _show("levels")))
	box.add_child(MenuKit.button("Controls", func(): _show("controls")))
	box.add_child(MenuKit.button("Settings", func(): _show("settings")))
	box.add_child(MenuKit.button("Quit", func(): get_tree().quit()))


func _levels_page(box: VBoxContainer) -> void:
	box.add_child(MenuKit.label("LEVEL SELECT", 34, MenuKit.GOLD))
	_level_box = VBoxContainer.new()
	_level_box.add_theme_constant_override("separation", 10)
	box.add_child(_level_box)
	box.add_child(MenuKit.button("Back", func(): _show("main")))


func _refresh_levels() -> void:
	for child in _level_box.get_children():
		child.queue_free()
	for i in Levels.count():
		var info := Levels.data(i)
		var text: String = info.title
		if Game.state().results.has(i):
			text += "   (best %s)" % MenuKit.format_time(Game.state().results[i].seconds)
		var button := MenuKit.button(text, func(): Game.state().start_level(i), 560.0)
		button.disabled = i >= Game.state().unlocked
		_level_box.add_child(button)


func _controls_page(box: VBoxContainer) -> void:
	box.add_child(MenuKit.label("CONTROLS", 34, MenuKit.GOLD))
	box.add_child(MenuKit.label(MenuKit.controls_text(), 20))
	box.add_child(MenuKit.button("Back", func(): _show("main")))


func _assist_on() -> bool:
	return Game.state().settings.get("assist_cones", 1.0) > 0.5


func _settings_page(box: VBoxContainer) -> void:
	box.add_child(MenuKit.label("SETTINGS", 34, MenuKit.GOLD))
	var assist := CheckButton.new()
	assist.text = "Show brothers' vision cones all the time"
	assist.button_pressed = _assist_on()
	assist.add_theme_font_size_override("font_size", 20)
	assist.toggled.connect(func(on: bool):
		Game.state().settings.assist_cones = 1.0 if on else 0.0
		Game.state().save())
	box.add_child(assist)
	for key in ["master", "music", "sfx"]:
		box.add_child(MenuKit.label(key.capitalize() + " volume", 20))
		var slider := HSlider.new()
		slider.min_value = 0.0
		slider.max_value = 1.0
		slider.step = 0.05
		slider.value = Game.state().settings[key]
		slider.custom_minimum_size = Vector2(380, 24)
		slider.value_changed.connect(func(value: float):
			Game.state().settings[key] = value
			Game.state().save()
			Game.state().settings_changed.emit())
		box.add_child(slider)
	box.add_child(MenuKit.button("Back", func(): _show("main")))
