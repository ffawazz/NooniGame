extends CanvasLayer
## Esc pauses the level. Runs while the tree is paused.

const Game := preload("res://scripts/core/game.gd")
const MenuKit := preload("res://scripts/ui/menu_kit.gd")

var _root: Control
var _main_box: VBoxContainer
var _controls_box: VBoxContainer


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false


func setup(_level: Node) -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.01, 0.05, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)
	var panel := MenuKit.panel()
	center.add_child(panel)

	_main_box = VBoxContainer.new()
	_main_box.add_theme_constant_override("separation", 14)
	panel.add_child(_main_box)
	_main_box.add_child(MenuKit.label("PAUSED", 44, MenuKit.GOLD))
	_main_box.add_child(MenuKit.button("Resume", toggle))
	_main_box.add_child(MenuKit.button("Restart level", func(): Game.state().restart_level()))
	_main_box.add_child(MenuKit.button("Controls", func(): _show_controls(true)))
	_main_box.add_child(MenuKit.button("Main menu", func(): Game.state().go_menu()))

	_controls_box = VBoxContainer.new()
	_controls_box.add_theme_constant_override("separation", 14)
	_controls_box.visible = false
	panel.add_child(_controls_box)
	_controls_box.add_child(MenuKit.label("CONTROLS", 36, MenuKit.GOLD))
	_controls_box.add_child(MenuKit.label(MenuKit.controls_text(), 20))
	_controls_box.add_child(MenuKit.button("Back", func(): _show_controls(false)))


func toggle() -> void:
	var opening := not visible
	visible = opening
	get_tree().paused = opening
	_show_controls(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if opening else Input.MOUSE_MODE_CAPTURED


func _show_controls(show: bool) -> void:
	_main_box.visible = not show
	_controls_box.visible = show
