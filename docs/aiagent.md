# Gemini CLI Project Instructions: Live Lyrics (Godot 4.x)

This file provides context and best practices for Gemini CLI agents working on the "Live Lyrics" desktop overlay project.

## Project Context
- **Engine:** Godot 4.6 (Forward Plus renderer).
- **Language:** GDScript 2.0.
- **Aesthetic:** Frutiger Aero / Y2K (glossy, bubble elements, transparent glassmorphic UI, fluid movements).
- **Key Systems:**
  - `GlobalSignals`: Event-driven central communications autoload.
  - `MediaListener`: Background poller / hook for Windows and macOS playing tracks.
  - `LyricsFetcher`: Rest API client interfacing with LRCLIB.

## Coding Standards & Best Practices

### 1. Style & Formatting
- **Indentation:** Always use **Tabs** (standard Godot convention).
- **Naming:** 
  - **Files:** `snake_case.gd`, `snake_case.tscn`.
  - **Functions/Variables:** `snake_case` (e.g., `update_lyrics()`, `is_hovered`).
  - **Signals:** `snake_case` (e.g., `track_changed`).
  - **Constants:** `SCREAMING_SNAKE_CASE`.
  - **Classes:** `PascalCase`.
- **Static Typing:** Use static typing where possible (e.g., `var current_time: float = 0.0`, `func set_track(title: String) -> void`).

### 2. Architecture & Communication
- **GlobalSignals Autoload:** Avoid tight coupling between UI and OS hooks. Communicate via `GlobalSignals.emit_signal()` or `GlobalSignals.track_changed.emit(...)`.
- **Threading:** Background operations (like polling OS-media or calling APIs) should run asynchronously or in separate threads to avoid freezing the transparent overlay UI.
- **Resources:** Use `.tres` StyleBoxFlat and Theme resource configurations to keep UI consistent and modular.

### 3. File Organization
- `autoload/`: Core global systems (Autoloads).
- `ui/`: UI layouts and custom UI elements.
- `assets/`: Fonts, custom shaders, icons, and textures.
- `docs/`: Markdown documents explaining individual systems.

---

## Feature Development Workflow

### 1. Task Tracking (`tickets.md`)
- Update `tickets.md` in the project root to reflect progress.
- Mark completed tasks with `[x]` and update tickets accordingly.

### 2. Implementation Planning (`implementation_plan.md`)
- For complex changes (e.g., implementing the macOS AppleScript hooks or writing the custom glassmorphism shader), create an `implementation_plan.md` in `docs/` or the root first.
- Wait for user feedback or approval before beginning coding.

### 3. Feature Walkthrough (`walkthrough.md`)
- Document your changes upon completion to verify functionality.
