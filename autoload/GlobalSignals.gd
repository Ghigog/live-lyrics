extends Node

# Signal emitted when a new track is detected by the MediaListener
signal track_changed(title: String, artist: String, album: String)

# Signal emitted when lyrics are successfully fetched and parsed
# lyrics_data contains: { "synced": bool, "lines": Array[Dictionary] }
signal lyrics_fetched(lyrics_data: Dictionary)

# Signal emitted when the current song's playback position updates
signal playback_position_updated(seconds: float, duration: float, is_playing: bool)

# Signal emitted when the overlay visibility is toggled
signal overlay_toggled(is_visible: bool)
