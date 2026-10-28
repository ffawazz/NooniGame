extends RefCounted

const Game := preload("res://scripts/core/game.gd")
## Styling helpers so every menu, panel and caption shares one look (dark ink, warm gold, big rounded buttons).

const INK := Color(0.07, 0.05, 0.11)
const GOLD := Color(1.0, 0.86, 0.4)
const PANEL := Color(0.09, 0.07, 0.16, 0.92)


static func label(text := "", size := 22, color := Color.WHITE) -> Label:
	var node := Label.new()
	node.text = text
	node.add_theme_font_size_override("font_size", size)
	node.add_theme_color_override("font_color", color)
	node.add_theme_color_override("font_outline_color", INK)
	node.add_theme_constant_override("outline_size", maxi(4, size / 4))
	return node


static func button(text: String, on_press: Callable, width := 340.0) -> Button:
	var node := Button.new()
	node.text = text
	node.custom_minimum_size = Vector2(width, 54)
	node.add_theme_font_size_override("font_size", 26)
	node.add_theme_color_override("font_color", Color.WHITE)
	node.add_theme_color_override("font_hover_color", INK)
	node.add_theme_color_override("font_pressed_color", INK)
	node.add_theme_color_override("font_disabled_color", Color(0.55, 0.52, 0.62))
	node.add_theme_stylebox_override("normal", _box(Color(0.2, 0.16, 0.34), Color(0.5, 0.42, 0.75)))
	node.add_theme_stylebox_override("hover", _box(GOLD, Color.WHITE))
	node.add_theme_stylebox_override("pressed", _box(Color(0.95, 0.7, 0.25), Color.WHITE))
	node.add_theme_stylebox_override("focus", _box(Color(0.3, 0.24, 0.5), GOLD))
	node.add_theme_stylebox_override("disabled", _box(Color(0.14, 0.12, 0.2), Color(0.25, 0.22, 0.34)))
	node.pressed.connect(func(): Game.sfx("ui_click"))
	node.pressed.connect(on_press)
	return node


static func panel() -> PanelContainer:
	var node := PanelContainer.new()
	var style := _box(PANEL, Color(0.5, 0.42, 0.75))
	style.set_content_margin_all(28)
	node.add_theme_stylebox_override("panel", style)
	return node


static func bar(color: Color) -> ProgressBar:
	var node := ProgressBar.new()
	node.min_value = 0.0
	node.max_value = 1.0
	node.step = 0.01
	node.show_percentage = false
	node.custom_minimum_size = Vector2(220, 12)
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	node.add_theme_stylebox_override("fill", fill)
	return node


static func format_time(seconds: float) -> String:
	return "%d:%02d" % [int(seconds) / 60, int(seconds) % 60]


static func controls_text() -> String:
	return "\n".join([
		"WASD / arrow keys ........ move",
		"Mouse ........................ look and aim",
		"Ctrl or C ..................... crouch (hide in cover boxes)",
		"Shift ......................... sprint",
		"Space ........................ jump",
		"R ............................... wipe your glasses",
		"Q ............................... character ability",
		"Hold Tab .................... Cat-ical Wheel (slows time)",
		"1 / 2 / 3 ................... Nooni / Bruce / Semba",
		"Right mouse (hold) ...... Detective Vision",
		"Left mouse .................. grapple",
		"E ............................... interact / hack",
		"Esc ............................ pause",
	])


static func _box(color: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(3)
	style.set_corner_radius_all(14)
	style.set_content_margin_all(8)
	return style
