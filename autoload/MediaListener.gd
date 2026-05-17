extends Node

## MediaListener handles OS-level media transport monitoring
## It polls media sources at standard intervals in a background thread and emits track changed and timeline events.

@export var poll_interval: float = 1.0 # Polling every 1.0 second is ideal for keeping timeline synced!
@export var mock_mode: bool = false

var current_title: String = ""
var current_artist: String = ""
var current_album: String = ""
var current_position: float = 0.0
var current_duration: float = 0.0
var is_active_playing: bool = false

var _thread: Thread
var _exit_thread: bool = false
var _script_path: String

func _ready() -> void:
	_script_path = ProjectSettings.globalize_path("res://get_media.ps1")
	
	if mock_mode:
		_simulate_mock_playback()
	else:
		_thread = Thread.new()
		_thread.start(_thread_poll)

func _thread_poll() -> void:
	while not _exit_thread:
		var result = _poll_os_media()
		if result.size() == 6:
			# Call deferred because we are on a background thread
			call_deferred("_update_media_state", result[1], result[0], result[2], result[3], result[4], result[5])
		
		# Delay between polls (in milliseconds)
		OS.delay_msec(int(poll_interval * 1000.0))

func _poll_os_media() -> Array:
	if OS.get_name() != "Windows":
		return []
		
	var output = []
	var exit_code = OS.execute(
		"powershell.exe", 
		["-NoProfile", "-ExecutionPolicy", "Bypass", "-File", _script_path], 
		output, 
		true,
		false
	)
	
	if exit_code == 0 and output.size() > 0:
		var raw_out = output[0].strip_edges()
		if raw_out.begins_with("ERROR::") or raw_out == "NONE":
			return []
		
		var parts = raw_out.split("::")
		if parts.size() == 6:
			return [
				parts[0].strip_edges(), # Artist
				parts[1].strip_edges(), # Title
				parts[2].strip_edges(), # Album
				parts[3].strip_edges().to_float(), # Position
				parts[4].strip_edges().to_float(), # Duration
				parts[5].strip_edges() == "true" # IsPlaying
			]
			
	return []

func _update_media_state(title: String, artist: String, album: String, position: float, duration: float, is_playing: bool) -> void:
	# 1. Update metadata if changed
	if title != current_title or artist != current_artist or album != current_album:
		current_title = title
		current_artist = artist
		current_album = album
		GlobalSignals.track_changed.emit(current_title, current_artist, current_album)
		print("[MediaListener] Track changed: %s - %s (Album: %s)" % [current_artist, current_title, current_album])
	
	# 2. Emit timeline and play state update
	current_position = position
	current_duration = duration
	is_active_playing = is_playing
	GlobalSignals.playback_position_updated.emit(current_position, current_duration, is_active_playing)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_PREDELETE:
		_exit_thread = true
		if _thread and _thread.is_started():
			_thread.wait_to_finish()

# --- Mock simulation fallbacks below ---
var _mock_tracks: Array[Dictionary] = [
	{ "title": "Everyday", "artist": "Weyes Blood", "album": "Titanic Rising", "duration": 23.0 },
	{ "title": "Bizarre Love Triangle", "artist": "New Order", "album": "Brotherhood", "duration": 22.0 },
	{ "title": "Blue", "artist": "Eiffel 65", "album": "Europop", "duration": 20.0 },
	{ "title": "Digital Love", "artist": "Daft Punk", "album": "Discovery", "duration": 26.0 }
]
var _mock_index: int = 0
var _mock_time: float = 0.0

func _simulate_mock_playback() -> void:
	if not mock_mode:
		return
		
	var track = _mock_tracks[_mock_index]
	_change_track(track["title"], track["artist"], track["album"])
	
	# Start a recurring timer to simulate tick updates
	_mock_time = 0.0
	_run_mock_ticks(track["duration"])

func _run_mock_ticks(duration: float) -> void:
	if not mock_mode or _exit_thread:
		return
		
	# Emit mock update
	GlobalSignals.playback_position_updated.emit(_mock_time, duration, true)
	
	# Tick step
	await get_tree().create_timer(1.0).timeout
	_mock_time += 1.0
	
	if _mock_time >= duration:
		# Next track
		_mock_index = (_mock_index + 1) % _mock_tracks.size()
		_simulate_mock_playback()
	else:
		_run_mock_ticks(duration)

func _change_track(new_title: String, new_artist: String, new_album: String) -> void:
	current_title = new_title
	current_artist = new_artist
	current_album = new_album
	GlobalSignals.track_changed.emit(current_title, current_artist, current_album)
	print("[MediaListener Mock] Track changed: %s - %s (Album: %s)" % [current_artist, current_title, current_album])
