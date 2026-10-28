extends Control
## Credits roll, shown after the last level. Any key returns to the title screen.

const Game := preload("res://scripts/core/game.gd")
const MenuKit := preload("res://scripts/ui/menu_kit.gd")

const LINES := [
	["NOONI'S TACTICAL GUIDE TO EVERYDAY LIFE", 44],
	["", 20],
	["Nooni, who treats minor inconveniences like high-stakes espionage", 24],
	["Bruce, who is Batman", 24],
	["Semba, who is the King", 24],
	["Yasser and Ahmed, who only wanted to watch TV", 24],
	["", 20],
	["Designed, written and built with Claude Code", 22],
	["Engine: Godot 4", 22],
	["", 20],
	["No snacks were harmed. Several were acquired.", 22],
	["", 30],
	["Thanks for playing!", 36],
	["", 20],
	["(press any key)", 18],
]

var _box: VBoxContainer
var _scroll := 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Game.music("music_menu")
	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.03, 0.09)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 18)
	add_child(_box)
	for line in LINES:
		var label := MenuKit.label(line[0], line[1], MenuKit.GOLD if line[1] >= 36 else Color.WHITE)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.custom_minimum_size = Vector2(1200, 0)
		_box.add_child(label)
	_box.position = Vector2(40, get_viewport_rect().size.y)


func _process(delta: float) -> void:
	_scroll += delta * 55.0
	_box.position.y = maxf(get_viewport_rect().size.y * 0.15, get_viewport_rect().size.y - _scroll)


func _unhandled_input(event: InputEvent) -> void:
	if (event is InputEventKey or event is InputEventMouseButton) and event.pressed:
		Game.state().go_menu()
