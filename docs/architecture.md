# 🏛️ Architecture: Live Lyrics

This document details the architectural decisions and system integrations of **Live Lyrics**.

---

## 🖥️ Transparent Desktop Overlay in Godot 4.6

To create a borderless, transparent click-through overlay that floats over the user's desktop, we must configure several windows and viewport parameters.

### ⚙️ Required Project Settings

We require the following keys inside `project.godot`:

```gdscript
[display]
window/size/borderless=true
window/size/always_on_top=true
window/size/transparent=true
window/per_pixel_transparency/allowed=true

[rendering]
viewport/transparent_background=true
```

- **Borderless:** Removes the standard OS title bars, margins, and close/resize widgets.
- **Always on Top:** Forces the window stack to position this window above active browsers, editors, and games.
- **Transparent & Per Pixel Transparency:** Permits the underlying desktop background to shine through the window.
- **Viewport Transparent Background:** Prevents the default solid gray/black viewport environment sky from rendering, enabling alpha channels.

### 🖱️ Mouse Click-Through Toggle

To make the overlay truly unobtrusive, it must offer a "click-through" mode where clicks pass through to whatever is behind it:

```gdscript
# Enable click-through
DisplayServer.window_set_mouse_passthrough(DisplayServer.window_get_active_mouse_pixel_opacity_threshold())

# Disable click-through (restore interaction)
DisplayServer.window_set_mouse_passthrough(PackedVector2Array())
```

---

## 🎵 OS-Level Media Hooking

GDScript does not provide built-in APIs to access system playback controls. We implement platform-specific integrations:

```
+------------------+                   +--------------------+
|  macOS AppleScript|                   | Windows WinRT / PS |
+--------+---------+                   +---------+----------+
         |                                       |
         +-----------------+---------------------+
                           | OS.execute()
                           v
               +-----------+-----------+
               |   systems/MediaListener|
               +-----------+-----------+
                           | GlobalSignals.track_changed
                           v
                +----------+----------+
                |    ui/MainOverlay   |
                +---------------------+
```

### 1. Windows (WinRT & PowerShell)
We query the System Media Transport Controls (SMTC) using an asynchronous PowerShell worker thread that loads Windows Runtime assemblies to pull metadata, playback state, and timeline properties:
```powershell
# Get session manager and current session
$manager = Await ([Windows.Media.Control.GlobalSystemMediaTransportControlsSessionManager]::RequestAsync())
$session = $manager.GetCurrentSession()

# 1. Pull current song properties
$props = Await ($session.TryGetMediaPropertiesAsync())

# 2. Pull timeline properties & calculate authoritative real-time position
$timeline = $session.GetTimelineProperties()
$snapshotPosition = $timeline.Position.TotalSeconds
$lastUpdated = $timeline.LastUpdatedTime
$elapsed = ([System.DateTimeOffset]::Now - $lastUpdated).TotalSeconds
$position = $snapshotPosition + ($elapsed * $playbackRate)
```
Because the OS SMTC timeline `Position` returns a static snapshot, we perform **Reconciliation Math** in PowerShell to calculate the exact dynamic position. We trigger this via `OS.execute` in a silent background thread inside `MediaListener.gd`, parsing results as `Artist::Title::Album::Position::Duration::IsPlaying`.

### 2. macOS (AppleScript)
We query active desktop players (e.g. Spotify) using AppleScript commands to pull track details and current playback position:
```bash
osascript -e 'tell application "Spotify" to get {artist, name, player position} of current track'
```

---

## 📖 Lyrics Syncing Mechanics

We utilize **LRCLIB** (`https://lrclib.net`), a high-quality free open-source database of time-synced lyrics.

### 1. LRCLIB Integration Flow
- Whenever `GlobalSignals.track_changed` is emitted, `LyricsFetcher.gd` sends an HTTP query using client-safe headers:
  `GET https://lrclib.net/api/get?artist_name={artist}&track_name={title}`
- **Response Structure:**
  - `plainLyrics`: Standard plain text block fallback.
  - `syncedLyrics`: Time-synced text containing standard `[MM:SS.CC]` LRC tags.

### 2. LRC Parser & Synchronization Engine
- We parse `syncedLyrics` line-by-line using a Regex matching `\[(\d+):(\d+)\.(\d+)\](.*)`:
  - Convert `[MM:SS.CC]` to total seconds: `total = (min * 60) + sec + (centisec / 100)`.
  - Store structured results as `{"time": total_seconds, "text": lyric_string}`.

### 3. Client-Side Prediction & Authoritative Reconciliation
To achieve lag-free, ultra-smooth scrolling:
*   **Client-Side Prediction:** The UI overlays its own `_process(delta)` frame-loop, incrementing the local timeline `song_time` on every render frame by `delta` (running at a fluid **60+ FPS**).
*   **Authoritative Reconciliation:** Every 1 second, when `MediaListener.gd` reports a fresh calculation from the OS SMTC, the UI *reconciles* and snaps `song_time` to match the true OS media player time, preventing any timer drift.
*   **Smooth Tween Scrolling:** Highlight changes trigger hardware-accelerated `Tween` transitions (`set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)`) over `0.3` seconds, centering the active lyric line vertically inside the scroll container.
