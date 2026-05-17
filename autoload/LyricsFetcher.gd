extends Node

## LyricsFetcher communicates with online databases like LRCLIB to retrieve
## synchronized lyrics and parse them into timeline data.

var http_client: HTTPRequest

# Mock data mapping "Title" to raw LRC format for testing
var _mock_lrc_database: Dictionary = {
	"Everyday": """[00:00.00] (Instrumental Intro)
[00:06.00] I've been checking for you lately
[00:09.00] You're hard to find
[00:11.00] And I am in the mood for love
[00:15.00] But you are not around
[00:18.00] Everyday is a challenge now
[00:23.00] Without you near me
""",
	"Bizarre Love Triangle": """[00:00.00] (Synth Beats Playing)
[00:08.00] Every time I think of you
[00:10.00] I get a shot right through into a bolt of blue
[00:15.00] It's no problem of mine, but it's a problem I find
[00:20.00] Living a life that I can't leave behind
""",
	"Blue": """[00:00.00] (Yo listen up, here's the story)
[00:03.00] About a little guy that lives in a blue world
[00:06.00] And all day and all night and everything he sees is just blue
[00:10.00] Like him, inside and outside
[00:13.00] Blue his house with a blue little window
[00:16.00] And a blue corvette and everything is blue for him
""",
	"Digital Love": """[00:00.00] (Upbeat Electronic Beats)
[00:06.00] Last night I had a dream about you
[00:11.00] In this dream I'm dancing right beside you
[00:16.00] And it looked like everyone was having fun
[00:21.00] The kind of feeling I've waited so long
"""
}

func _ready() -> void:
	http_client = HTTPRequest.new()
	add_child(http_client)
	http_client.request_completed.connect(_on_request_completed)
	
	GlobalSignals.track_changed.connect(_on_track_changed)

func _on_track_changed(title: String, artist: String, album: String) -> void:
	print("[LyricsFetcher] Triggering fetch for: %s by %s (Album: %s)" % [title, artist, album])
	
	# Check mock database first if playing mock tracks
	if title in _mock_lrc_database:
		var parsed = parse_lrc(_mock_lrc_database[title])
		GlobalSignals.lyrics_fetched.emit({
			"synced": true,
			"lines": parsed
		})
		print("[LyricsFetcher] Found mock lyrics for: %s" % title)
		return
	
	# Trigger real online query
	fetch_lyrics_online(title, artist)

func fetch_lyrics_online(title: String, artist: String) -> void:
	var url = "https://lrclib.net/api/get?artist_name=%s&track_name=%s" % [
		artist.uri_encode(),
		title.uri_encode()
	]
	var headers = [
		"User-Agent: LiveLyricsOverlay/1.0 (github.com/Ghigog/live-lyrics)"
	]
	var err = http_client.request(url, headers)
	if err != OK:
		print("[LyricsFetcher] HTTP request failed to initialize.")

func _on_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		print("[LyricsFetcher] Failed to retrieve lyrics, Response code: %d" % response_code)
		GlobalSignals.lyrics_fetched.emit({
			"synced": false,
			"plain": "Lyrics not found online."
		})
		return
		
	var json = JSON.new()
	var err = json.parse(body.get_string_from_utf8())
	if err != OK:
		print("[LyricsFetcher] Failed to parse JSON response.")
		GlobalSignals.lyrics_fetched.emit({
			"synced": false,
			"plain": "Failed to parse retrieved lyrics data."
		})
		return
		
	var data = json.get_data()
	if typeof(data) == TYPE_DICTIONARY:
		var synced_text = data.get("syncedLyrics", "")
		if synced_text != null and typeof(synced_text) == TYPE_STRING and not synced_text.is_empty():
			var parsed = parse_lrc(synced_text)
			GlobalSignals.lyrics_fetched.emit({
				"synced": true,
				"lines": parsed
			})
		else:
			# Fallback to plain lyrics if synced not available
			var plain_text = data.get("plainLyrics", "")
			if plain_text == null or typeof(plain_text) != TYPE_STRING or plain_text.is_empty():
				plain_text = "No lyrics text found in database."
			GlobalSignals.lyrics_fetched.emit({
				"synced": false,
				"plain": plain_text
			})

## Parses LRC string format: [MM:SS.CC] Lyrics into structured dictionaries
func parse_lrc(lrc_text: String) -> Array[Dictionary]:
	var lines: Array[Dictionary] = []
	var regex = RegEx.new()
	regex.compile("\\[(\\d+):(\\d+)\\.(\\d+)\\](.*)")
	
	var raw_lines = lrc_text.split("\n")
	for line in raw_lines:
		line = line.strip_edges()
		var match = regex.search(line)
		if match:
			var minutes = match.get_string(1).to_float()
			var seconds = match.get_string(2).to_float()
			var centiseconds = match.get_string(3).to_float()
			var text = match.get_string(4).strip_edges()
			
			var total_seconds = (minutes * 60.0) + seconds + (centiseconds / 100.0)
			lines.append({
				"time": total_seconds,
				"text": text
			})
	return lines
