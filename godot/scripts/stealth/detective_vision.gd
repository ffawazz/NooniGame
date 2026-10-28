extends Node

const Game := preload("res://scripts/core/game.gd")
## Nooni's AR glasses. Hold right mouse while she is the one being played: the glasses glint and
## Scout-Detective Vision switches on. Everything in the "vision_aware" group (brothers, gadgets) reacts:
## brothers show their sightlines, suspicion and a silhouette through walls; gadgets show hack prompts.

signal activated
signal deactivated

var active := false
## The Nooni this belongs to.
var character: Node


func _physics_process(_delta: float) -> void:
	var want: bool = character.input_enabled and Input.is_action_pressed("vision")
	if want != active:
		set_active(want)


func set_active(on: bool) -> void:
	active = on
	get_tree().call_group("vision_aware", "set_vision", on)
	if on:
		Game.sfx("vision_on")
		activated.emit()
	else:
		deactivated.emit()
