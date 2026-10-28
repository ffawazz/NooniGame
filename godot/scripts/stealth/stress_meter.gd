extends Node
## Nooni's stress meter, instead of a health bar.
##
## Stress RISES while a brother is closing in on spotting her (his awareness) and a little when one is simply
## close by, and FALLS when she is left alone, faster when crouched in cover.
## Above `smudge_threshold` her glasses fog up: the smudge builds while she stays stressed and only goes away
## when she wipes them (a quick tap, see wipe()). Stress itself also makes her sloppier at hiding
## (see NooniController.get_visibility).
##
## It keeps simulating while another character is played, so Nooni may well be smudged when you switch back.

signal smudged
signal wiped

@export_group("Stress")
@export var awareness_gain := 1.2  ## Stress per second at full brother awareness.
@export var proximity_gain := 0.15  ## Stress per second with a brother right next to her.
@export var proximity_range := 4.0
@export var calm_rate := 0.12
@export var cover_calm_rate := 0.3

@export_group("Glasses")
@export var smudge_threshold := 0.5
@export var first_smudge := 0.3  ## Instant fog when stress first crosses the threshold.
@export var smudge_rate := 0.6  ## Smudge per second at full stress.
@export var wipe_seconds := 0.35
@export var wipe_relief := 0.1  ## A deep breath: stress drops a little after a wipe.
@export var wipe_grace_seconds := 1.5  ## Clean glasses stay clean this long even if she is still stressed.

## 0..1.
var value := 0.0
## 0 = clear, 1 = unreadable.
var smudge := 0.0
var wiping := false
## 0..1 progress of the current wipe.
var wipe_t := 0.0

## The Nooni this belongs to: needs global_position, crouching and is_in_cover().
var character: Node3D

var _over := false
var _grace := 0.0
var _wipe_from := 0.0


func _physics_process(delta: float) -> void:
	var strongest := 0.0
	var nearest := INF
	for brother in get_tree().get_nodes_in_group("brother"):
		if brother.is_petted():
			continue  # a brother lost in cuddles is no threat
		strongest = maxf(strongest, brother.awareness)
		var flat: Vector3 = brother.global_position - character.global_position
		flat.y = 0.0
		nearest = minf(nearest, flat.length())

	var closeness := clampf(1.0 - nearest / proximity_range, 0.0, 1.0)
	var rise := awareness_gain * strongest + proximity_gain * closeness
	if rise > 0.001:
		value = minf(1.0, value + rise * delta)
	else:
		var hidden: bool = character.crouching and character.is_in_cover()
		value = maxf(0.0, value - (cover_calm_rate if hidden else calm_rate) * delta)

	_update_smudge(delta)


func _update_smudge(delta: float) -> void:
	if wiping:
		wipe_t = minf(1.0, wipe_t + delta / wipe_seconds)
		smudge = _wipe_from * (1.0 - wipe_t)
		if wipe_t >= 1.0:
			wiping = false
			smudge = 0.0
			value = maxf(0.0, value - wipe_relief)
			_grace = wipe_grace_seconds
			wiped.emit()
		return

	_grace = maxf(0.0, _grace - delta)
	var over := value >= smudge_threshold
	if over and not _over and _grace <= 0.0:
		smudge = maxf(smudge, first_smudge)
		smudged.emit()
	_over = over

	if over and _grace <= 0.0:
		var t := (value - smudge_threshold) / (1.0 - smudge_threshold)
		smudge = minf(1.0, smudge + smudge_rate * (0.25 + 0.75 * t) * delta)


## Quick tap to clean the glasses. Returns false if there is nothing to wipe (or she is already wiping).
func wipe() -> bool:
	if wiping or smudge <= 0.01:
		return false
	wiping = true
	wipe_t = 0.0
	_wipe_from = smudge
	return true
