extends Control
## Smudges on Nooni's glasses: a grimy fog plus fingerprint-like blobs that appear as the smudge level
## rises, and a bright swipe while she wipes them clean. Drawn under the HUD so the HUD stays readable.

var stress: Node
## The room turns this off while someone else is being played (Bruce and Semba don't wear glasses).
var active := true

var _blobs: Array = []
var _soft: GradientTexture2D


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false

	var gradient := Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 1))
	gradient.set_color(1, Color(1, 1, 1, 0))
	_soft = GradientTexture2D.new()
	_soft.gradient = gradient
	_soft.fill = GradientTexture2D.FILL_RADIAL
	_soft.fill_from = Vector2(0.5, 0.5)
	_soft.fill_to = Vector2(1.0, 0.5)
	_soft.width = 128
	_soft.height = 128

	var rng := RandomNumberGenerator.new()
	rng.seed = 7  # the same smudges every run
	for i in 32:
		_blobs.append({
			"pos": Vector2(rng.randf(), rng.randf()),
			"radius": rng.randf_range(70.0, 200.0),
			"threshold": rng.randf_range(0.0, 0.85),
		})


func _process(_delta: float) -> void:
	visible = active and stress != null and stress.smudge > 0.003
	if visible:
		queue_redraw()


func _draw() -> void:
	var area := get_viewport_rect().size
	var level: float = stress.smudge
	var grime := Color(0.9, 0.87, 0.82)

	draw_rect(Rect2(Vector2.ZERO, area), Color(grime.r, grime.g, grime.b, level * 0.3))
	for blob in _blobs:
		if level < blob.threshold:
			continue
		var alpha := clampf((level - blob.threshold) * 3.0, 0.0, 1.0) * 0.6
		var r: float = blob.radius
		var center: Vector2 = blob.pos * area
		draw_texture_rect(_soft, Rect2(center - Vector2(r, r), Vector2(r, r) * 2.0), false, Color(grime.r, grime.g, grime.b, alpha))

	if stress.wiping:
		# A bright slanted band sweeping across as she wipes.
		var x: float = lerpf(-0.25, 1.15, stress.wipe_t) * area.x
		var w := area.x * 0.18
		var slant := area.y * 0.25
		draw_colored_polygon(
			PackedVector2Array([Vector2(x, 0), Vector2(x + w, 0), Vector2(x + w - slant, area.y), Vector2(x - slant, area.y)]),
			Color(1, 1, 1, 0.35)
		)
