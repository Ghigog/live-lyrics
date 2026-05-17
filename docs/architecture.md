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
We query the System Media Transport Controls (SMTC) using a PowerShell polling block executed asynchronously or periodically:
```powershell
[Windows.Media.Control.GlobalSystemMediaTransportControlsSessionManager, Windows.Media.Control.GlobalSystemMediaTransportControlsSessionManager, ContentType=WindowsRuntime] | Out-Null
$manager = [Windows.Media.Control.GlobalSystemMediaTransportControlsSessionManager]::RequestAsync().GetResults()
$session = $manager.GetCurrentSession()
if ($session) {
    $props = $session.TryGetMediaPropertiesAsync().GetResults()
    Write-Output "$($props.Artist) - $($props.Title)"
}
```
We trigger this via `OS.execute("powershell", ["-Command", $command])` inside `MediaListener.gd`, parsing the returned string.

### 2. macOS (AppleScript)
We query the target media players (Spotify or Music) via OSAScript commands:
```bash
osascript -e 'tell application "Spotify" to get artist of current track & " - " & name of current track'
```
We trigger this via `OS.execute("osascript", ["-e", $command])` or by checking if player processes are active.

---

## 📖 Lyrics Syncing Mechanics

We utilize **LRCLIB** (`https://lrclib.net`), a high-quality free open-source database of time-synced lyrics.

### 1. LRCLIB Integration Flow
- Whenever `GlobalSignals.track_changed` is emitted, `LyricsFetcher.gd` sends an HTTP query:
  `GET https://lrclib.net/api/get?artist={artist}&title={title}`
- **Response Structure:**
  - `plainLyrics`: Full block of text.
  - `syncedLyrics`: Text containing LRC tags (e.g., `[00:15.30] Hello World`).

### 2. LRC Parser & Synchronization Engine
- We split `syncedLyrics` by newlines.
- Parse each line using a Regex matching `\[(\d{2}):(\d{2})\.(\d{2})\](.*)`:
  - Convert `[MM:SS.CC]` to total seconds.
  - Store pairs of `(time_in_seconds, lyric_string)` in a sorted array.
- During playback, we monitor the song timeline:
  - Highlight the line where `current_time >= lyric_time` and `current_time < next_lyric_time`.
  - Smoothly scroll the UI Container up or down.
