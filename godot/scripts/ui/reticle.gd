extends Control
## Crosshair for aiming the grapple. Only shows while Nooni is the one being played; turns gold with a
## "GRAPPLE" prompt when a hook is under it, and shows a cooldown ring after a zip.

var level: Node


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	visible = level != null and level.switcher != null and level.switcher.current == level.nooni and level.switcher.mode == 0
	if visible:
		queue_redraw()


func _draw() -> void:
	var nooni = level.nooni
	var center := get_viewport_rect().size * 0.5
	var has_target: bool = nooni.grapple_target != null
	var color := Color(1.0, 0.9, 0.4) if has_target else Color(1, 1, 1, 0.55)
	var radius := 17.0 if has_target else 11.0

	draw_arc(center, radius, 0.0, TAU, 32, Color(0.05, 0.03, 0.1, 0.8), 6.0, true)
	draw_arc(center, radius, 0.0, TAU, 32, color, 3.0, true)
	draw_circle(center, 2.5, color)
	if has_target:
		for sign_x in [-1.0, 1.0]:
			for sign_y in [-1.0, 1.0]:
				var corner: Vector2 = center + Vector2(sign_x, sign_y) * 26.0
				draw_line(corner, corner + Vector2(-sign_x * 9.0, 0), color, 3.0)
				draw_line(corner, corner + Vector2(0, -sign_y * 9.0), color, 3.0)
		draw_string(ThemeDB.fallback_font, center + Vector2(-60, 56), "CLICK: GRAPPLE", HORIZONTAL_ALIGNMENT_CENTER, 120.0, 16, color)
	elif nooni.grapple_cooldown_left > 0.0:
		var fraction: float = 1.0 - nooni.grapple_cooldown_left / nooni.grapple_cooldown_seconds
		draw_arc(center, 24.0, -PI * 0.5, -PI * 0.5 + TAU * fraction, 32, Color(0.6, 0.8, 1.0, 0.8), 3.0, true)
