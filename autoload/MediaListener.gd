extends Node

## MediaListener handles OS-level media transport monitoring
## It polls media sources at standard intervals in a background thread and emits track changed events.

@export var poll_interval: float = 2.0
@export var mock_mode: bool = false # Default to FALSE since OS integration is fully functional!

var current_title: String = ""
var current_artist: String = ""
var current_album: String = ""

var _thread: Thread
var _exit_thread: bool = false
var _script_path: String

func _ready() -> void:
	# Globalize the powershell script path so OS.execute can find it
	_script_path = ProjectSettings.globalize_path("res://get_media.ps1")
	
	if mock_mode:
		_simulate_mock_playback()
	else:
		_thread = Thread.new()
		_thread.start(_thread_poll)

func _thread_poll() -> void:
	while not _exit_thread:
		var result = _poll_os_media()
		if result.size() == 3:
			# Call deferred because we are on a background thread and need to emit safe UI signals
			call_deferred("_change_track", result[1], result[0], result[2])
		
		# Delay between polls (in milliseconds)
		OS.delay_msec(int(poll_interval * 1000.0))

func _poll_os_media() -> Array:
	if OS.get_name() != "Windows":
		# Fallback/stub for macOS
		return []
		
	var output = []
	# Run powershell silently to fetch media
	var exit_code = OS.execute(
		"powershell.exe", 
		["-NoProfile", "-ExecutionPolicy", "Bypass", "-File", _script_path], 
		output, 
		true, # read_stderr = true
		false # open_console = false (keeps it completely silent and invisible to the user!)
	)
	
	if exit_code == 0 and output.size() > 0:
		var raw_out = output[0].strip_edges()
		if raw_out.begins_with("ERROR::") or raw_out == "NONE":
			return []
		
		var parts = raw_out.split("::")
		if parts.size() == 3:
			return [parts[0], parts[1], parts[2]] # [Artist, Title, Album]
			
	return []

func _notification(what: int) -> void:
	# Clean exit of background thread to avoid crash on close
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_PREDELETE:
		_exit_thread = true
		if _thread and _thread.is_started():
			_thread.wait_to_finish()

# --- Mock simulation fallbacks below ---
var _mock_tracks: Array[Dictionary] = [
	{ "title": "Everyday", "artist": "Weyes Blood", "album": "Titanic Rising" },
	{ "title": "Bizarre Love Triangle", "artist": "New Order", "album": "Brotherhood" },
	{ "title": "Blue", "artist": "Eiffel 65", "album": "Europop" },
	{ "title": "Digital Love", "artist": "Daft Punk", "album": "Discovery" }
]
var _mock_index: int = 0

func _simulate_mock_playback() -> void:
	if not mock_mode:
		return
	_change_track(_mock_tracks[_mock_index]["title"], _mock_tracks[_mock_index]["artist"], _mock_tracks[_mock_index]["album"])
	
	var cycle_timer = get_tree().create_timer(20.0)
	cycle_timer.timeout.connect(func():
		_mock_index = (_mock_index + 1) % _mock_tracks.size()
		_simulate_mock_playback()
	)

func _change_track(new_title: String, new_artist: String, new_album: String) -> void:
	if new_title != current_title or new_artist != current_artist or new_album != current_album:
		current_title = new_title
		current_artist = new_artist
		current_album = new_album
		GlobalSignals.track_changed.emit(current_title, current_artist, current_album)
		print("[MediaListener] Track changed: %s - %s (Album: %s)" % [current_artist, current_title, current_album])
