extends Node

## MediaListener handles OS-level media transport monitoring
## It polls media sources at standard intervals and emits signals when track metadata changes.

@export var poll_interval: float = 2.0
@export var mock_mode: bool = true # Fallback mock mode to test UI easily without active media player

var current_title: String = ""
var current_artist: String = ""

var _poll_timer: Timer

func _ready() -> void:
	_poll_timer = Timer.new()
	_poll_timer.wait_time = poll_interval
	_poll_timer.autostart = true
	_poll_timer.timeout.connect(_on_poll_timer_timeout)
	add_child(_poll_timer)
	
	if mock_mode:
		_simulate_mock_playback()

func _on_poll_timer_timeout() -> void:
	if mock_mode:
		return
	
	# Future implementation: OS-specific polling logic
	# See docs/architecture.md for Windows PowerShell & macOS AppleScript execution
	pass

var _mock_tracks: Array[Dictionary] = [
	{ "title": "Everyday", "artist": "Weyes Blood" },
	{ "title": "Bizarre Love Triangle", "artist": "New Order" },
	{ "title": "Blue", "artist": "Eiffel 65" },
	{ "title": "Digital Love", "artist": "Daft Punk" }
]
var _mock_index: int = 0

func _simulate_mock_playback() -> void:
	if not mock_mode:
		return
	_change_track(_mock_tracks[_mock_index]["title"], _mock_tracks[_mock_index]["artist"])
	
	# Cycle tracks every 20 seconds in mock mode
	var cycle_timer = get_tree().create_timer(20.0)
	cycle_timer.timeout.connect(func():
		_mock_index = (_mock_index + 1) % _mock_tracks.size()
		_simulate_mock_playback()
	)

func _change_track(new_title: String, new_artist: String) -> void:
	if new_title != current_title or new_artist != current_artist:
		current_title = new_title
		current_artist = new_artist
		GlobalSignals.track_changed.emit(current_title, current_artist)
		print("[MediaListener] Track changed: %s - %s" % [current_artist, current_title])
