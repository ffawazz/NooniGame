extends Node
## The "Audio" autoload: sound effects from a small pool of players, looping music, and the car engine.
## Volumes come from GameState.settings (master / music / sfx) through three buses.
## Scripts call it through Game.sfx(...), Game.music(...) so they still work when it isn't installed.

const SFX_NAMES := [
	"ui_click", "ui_confirm", "alert", "caught", "win", "roar", "purr", "meow", "hack", "vision_on", "wipe",
	"grapple_fire", "grapple_land", "door", "plate", "wheel_open", "switch", "heartbeat", "crash", "chirp", "horn",
]
const MUSIC_NAMES := ["music_menu", "music_stealth", "music_drive"]
const POOL_SIZE := 12

var _cache := {}
var _pool: Array = []
var _next := 0
var _music: AudioStreamPlayer
var _music_name := ""
var _engine: AudioStreamPlayer
## The most recent effects requested, oldest first (handy for tests and debugging).
var played: Array = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # menus and pause still make sound
	_ensure_bus("Music")
	_ensure_bus("SFX")
	for i in POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.bus = "SFX"
		add_child(player)
		_pool.append(player)
	_music = AudioStreamPlayer.new()
	_music.bus = "Music"
	add_child(_music)
	_engine = AudioStreamPlayer.new()
	_engine.bus = "SFX"
	_engine.stream = _loop("engine")
	_engine.volume_db = -80.0
	add_child(_engine)

	var state := get_node_or_null("/root/GameState")
	if state:
		state.settings_changed.connect(apply_volumes)
	apply_volumes()


func _ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) != -1:
		return
	AudioServer.add_bus()
	var index := AudioServer.bus_count - 1
	AudioServer.set_bus_name(index, bus_name)
	AudioServer.set_bus_send(index, "Master")


## Pushes the saved volume settings onto the buses.
func apply_volumes() -> void:
	var state := get_node_or_null("/root/GameState")
	var settings: Dictionary = state.settings if state else {"master": 0.8, "music": 0.6, "sfx": 0.9}
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), linear_to_db(maxf(0.0001, settings.master)))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), linear_to_db(maxf(0.0001, settings.music)))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), linear_to_db(maxf(0.0001, settings.sfx)))


func stream(sound: String) -> AudioStream:
	if not _cache.has(sound):
		_cache[sound] = load("res://audio/%s.wav" % sound)
	return _cache[sound]


## A looping copy of a WAV (the imported resource is shared, so loop flags are set on a duplicate).
func _loop(sound: String) -> AudioStream:
	var wav: AudioStreamWAV = stream(sound).duplicate()
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = wav.data.size() / 2  # 16-bit mono
	return wav


func sfx(sound: String, volume_db := 0.0, pitch := 1.0) -> void:
	played.append(sound)
	if played.size() > 64:
		played.pop_front()
	var player: AudioStreamPlayer = _pool[_next]
	_next = (_next + 1) % _pool.size()
	player.stream = stream(sound)
	player.volume_db = volume_db
	player.pitch_scale = pitch
	player.play()


func play_music(track: String) -> void:
	if track == _music_name and _music.playing:
		return
	_music_name = track
	_music.stream = _loop(track)
	_music.volume_db = -60.0
	_music.play()
	create_tween().tween_property(_music, "volume_db", -2.0, 1.5)


func stop_music() -> void:
	_music_name = ""
	_music.stop()


func current_music() -> String:
	return _music_name


## Car engine: pass active = false to silence it.
func engine(active: bool, speed_fraction := 0.0) -> void:
	if not active:
		_engine.stop()
		return
	if not _engine.playing:
		_engine.play()
	_engine.pitch_scale = 0.55 + clampf(speed_fraction, 0.0, 1.0) * 1.7
	_engine.volume_db = -14.0 + clampf(speed_fraction, 0.0, 1.0) * 6.0
