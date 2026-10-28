extends Node
## Autoload "GameState": which level we are on, what is unlocked, best results and settings, saved to disk.
## Scene changes and saving are skipped when `test_mode` is on (headless tests).

signal progress_changed
signal settings_changed

const Levels := preload("res://scripts/levels/levels.gd")

var save_path := "user://nooni_save.cfg"
var test_mode := false

var current_level := 0
## How many levels are playable (index < unlocked).
var unlocked := 1
## level index -> {"seconds": float, "spotted": int}
var results: Dictionary = {}
var settings := {"master": 0.8, "music": 0.6, "sfx": 0.9, "assist_cones": 1.0}
## Set when the story card for a level has been shown, so a Retry does not replay the intro.
var intro_seen_for := -1
## Tries on the current level (a try ends when she is spotted).
var attempts := 0


func _ready() -> void:
	load_save()


# ---- Flow ----------------------------------------------------------------------------

func new_game() -> void:
	attempts = 0
	current_level = -1
	unlocked = 1
	results = {}
	intro_seen_for = -1
	save()
	start_level(0)


func has_save() -> bool:
	return unlocked > 1 or not results.is_empty()


func continue_game() -> void:
	start_level(clampi(unlocked - 1, 0, Levels.count() - 1))


func start_level(index: int) -> void:
	if index != current_level:
		attempts = 0
	current_level = clampi(index, 0, Levels.count() - 1)
	if test_mode:
		return
	get_tree().paused = false
	get_tree().change_scene_to_file(Levels.scene_for(current_level))


func restart_level() -> void:
	intro_seen_for = current_level
	attempts += 1
	start_level(current_level)


## Called when the exit is reached. Records the result, unlocks the next level and returns true if there is one.
func complete_level(seconds: float, spotted: int) -> bool:
	var best: Dictionary = results.get(current_level, {})
	if best.is_empty() or seconds < best.seconds:
		results[current_level] = {"seconds": seconds, "spotted": spotted}
	unlocked = maxi(unlocked, mini(current_level + 2, Levels.count()))
	save()
	progress_changed.emit()
	return current_level + 1 < Levels.count()


func go_next() -> void:
	if current_level + 1 < Levels.count():
		intro_seen_for = -1
		attempts = 0
		start_level(current_level + 1)
	else:
		go_credits()


func go_menu() -> void:
	if test_mode:
		return
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func go_credits() -> void:
	if test_mode:
		return
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/credits.tscn")


# ---- Saving --------------------------------------------------------------------------

func save() -> void:
	if test_mode and save_path.begins_with("user://nooni_save"):
		return  # never touch the real save from tests
	var cfg := ConfigFile.new()
	cfg.set_value("progress", "unlocked", unlocked)
	cfg.set_value("progress", "results", results)
	for key in settings:
		cfg.set_value("settings", key, settings[key])
	cfg.save(save_path)


func load_save() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(save_path) != OK:
		return
	unlocked = clampi(int(cfg.get_value("progress", "unlocked", 1)), 1, Levels.count())
	results = cfg.get_value("progress", "results", {})
	for key in settings:
		settings[key] = float(cfg.get_value("settings", key, settings[key]))
