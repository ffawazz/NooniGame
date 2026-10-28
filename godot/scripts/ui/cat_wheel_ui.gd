extends Control
## The radial Cat-ical Wheel. Purely presentational: it draws the slices and reports which one the pointer
## is over; CharacterSwitcher decides what to do. Slot dictionaries: {name, color, locked}.

const WheelMath := preload("res://scripts/ui/wheel_math.gd")

const OUTER_RADIUS := 220.0
const INNER_RADIUS := 85.0
const DEAD_ZONE := 60.0
const SEGMENTS := 24

var slots: Array = []
var current_index := 0
var hovered := -1


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


func show_wheel(new_slots: Array, current: int) -> void:
	slots = new_slots
	current_index = current
	hovered = -1
	visible = true
	queue_redraw()


func hide_wheel() -> void:
	visible = false


## Returns the hovered slice index (-1 inside the dead zone).
func update_hover(offset: Vector2) -> int:
	var index := WheelMath.select_slice(offset, slots.size(), DEAD_ZONE)
	if index != hovered:
		hovered = index
		queue_redraw()
	return hovered


func _draw() -> void:
	if slots.is_empty():
		return
	# A Control under a CanvasLayer has no parent to size it from, so use the viewport directly.
	var area := get_viewport_rect().size
	var center := area * 0.5
	var font := ThemeDB.fallback_font
	draw_rect(Rect2(Vector2.ZERO, area), Color(0.03, 0.02, 0.08, 0.5))

	var count := slots.size()
	var sector := TAU / count
	var gap := 0.04

	for i in count:
		var slot: Dictionary = slots[i]
		var locked: bool = slot.locked
		var is_hover := i == hovered and not locked
		var a0 := i * sector - sector * 0.5 + gap
		var a1 := i * sector + sector * 0.5 - gap
		var outer := OUTER_RADIUS + (16.0 if is_hover else 0.0)

		var points := PackedVector2Array()
		for s in range(SEGMENTS + 1):
			points.append(center + _dir(lerpf(a0, a1, float(s) / SEGMENTS)) * outer)
		for s in range(SEGMENTS, -1, -1):
			points.append(center + _dir(lerpf(a0, a1, float(s) / SEGMENTS)) * INNER_RADIUS)

		var color: Color = slot.color
		if locked:
			color = Color(0.25, 0.25, 0.3, 0.8)
		elif is_hover:
			color = color.lightened(0.35)
		draw_colored_polygon(points, color)

		if i == current_index:
			var outline := points.duplicate()
			outline.append(points[0])
			draw_polyline(outline, Color.WHITE, 4.0, true)

		var mid := center + _dir(i * sector) * (INNER_RADIUS + outer) * 0.5
		var label_color := Color(0.6, 0.6, 0.65) if locked else Color.WHITE
		_text(font, mid + Vector2(0, -4), slot.name, 30, label_color)
		if locked:
			_text(font, mid + Vector2(0, 28), "(locked)", 20, label_color)

	_text(font, center + Vector2(0, -OUTER_RADIUS - 40), "CAT-ICAL WHEEL", 34, Color(1.0, 0.9, 0.5))
	var hint := "Release Tab to cancel" if hovered < 0 else "Release Tab to switch"
	_text(font, center, hint, 16, Color(0.85, 0.85, 0.95))


## Unit vector at `angle` radians clockwise from 12 o'clock.
func _dir(angle: float) -> Vector2:
	return Vector2(sin(angle), -cos(angle))


## Draws `text` centred on `center_pos`, with a dark outline so it reads on any slice colour.
func _text(font: Font, center_pos: Vector2, text: String, font_size: int, color: Color) -> void:
	var pos := center_pos + Vector2(-200.0, font_size * 0.35)
	draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_CENTER, 400.0, font_size, 8, Color(0.05, 0.03, 0.1))
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_CENTER, 400.0, font_size, color)
