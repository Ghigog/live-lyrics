# 🌊 Live Lyrics: Frutiger Aero Desktop Overlay

**Live Lyrics** is a lightweight, responsive desktop overlay that fetches lyrics in real-time based on the music currently playing on your system, rendering them with a beautiful, nostalgic **Frutiger Aero / Y2K early-internet aesthetic**. 

Designed to be unobtrusive and quick, it floats on your screen as a glassy, transparent, click-through overlay—bringing back glossy gradients, water bubbles, and smooth glassmorphism.

![Godot Engine](https://img.shields.io/badge/Godot_Engine-4.6-478CBF?style=for-the-badge&logo=godot-engine&logoColor=white)
![GDScript](https://img.shields.io/badge/GDScript-2.0-478CBF?style=for-the-badge&logo=godot-engine&logoColor=white)
![Style](https://img.shields.io/badge/Aesthetic-Frutiger_Aero_/_Y2K-00A4E4?style=for-the-badge)

---

## 🌟 Key Features

- **Universal Media Hook:** Listens to the OS System Media Transport Controls (Windows) and MediaRemote/AppleScript (macOS) to detect the active track.
- **Dynamic Time-Synced Lyrics:** Integrates with free, synchronized lyrics databases (like LRCLIB) to scroll and display lyrics perfectly in time.
- **Frutiger Aero / Y2K Aesthetic:** Glossy buttons, glassy transparent panels, fluid bubble particles, water ripple shaders, and premium early-2000s styling.
- **Lightweight Overlay:** Borderless, transparent, "always-on-top", and optional click-through capabilities to keep it out of the way while you work or game.
- **Customizable Layout:** Draggable interface with quick-access controls that appear when hovered.

---

## 🤖 AI Agent & Developer Guide

If you are an AI assistant or developer working on this codebase, **START HERE:**

1. **READ YOUR INSTRUCTIONS:** Check [**AI Agent Instructions**](docs/aiagent.md) in the `docs/` folder for workflow steps, Godot project conventions, and implementation guidelines.
2. **Architecture Philosophy:**
   - **GDScript + Lightweight Helper:** GDScript is used for the core UI, rendering, and API logic. Because pure GDScript cannot natively query OS-level media APIs, we utilize a modular system architecture where a small background subprocess or light OS-command integration handles the OS polling and sends it to our core engine.
   - **Autoloads (Singletons):** Communication between systems is handled through event-driven signals via `GlobalSignals`.
3. **Directory Structure:** Keep files organized into their proper folders. Refer to the directory structure map below.

---

## 📂 Directory Structure

The project follows a modular and clean layout:

```text
live-lyrics/
├── assets/             # Raw & imported assets
│   ├── fonts/          # Nostalgic Y2K typography (e.g., Outfit, Segoe UI, sans-serif)
│   ├── shaders/        # Water ripples, gloss, reflections, and glassmorphism shaders
│   └── styles/         # StyleBoxFlat and Theme resource configurations
├── docs/               # System architecture and technical documentation
│   ├── aiagent.md      # AI Agent integration rules and workflow patterns
│   └── architecture.md # Detailed breakdown of OS media listener & lyric sync
├── autoload/           # Autoload singletons (always loaded)
│   ├── GlobalSignals.gd # Core event bus for decoupling UI and listeners
│   └── MediaListener.gd # OS-level media detection service
├── ui/                 # Interface components and layouts
│   ├── main_overlay.tscn # Root overlay screen
│   ├── main_overlay.gd  # Controller for transparency, drag, and lyric display
│   └── glass_panel/     # Styled components representing the Aero glass aesthetic
├── project.godot       # Godot project configuration
└── tickets.md          # Active task backlog and roadmap (refer here for todos)
```

---

## 🚀 Getting Started

### Prerequisites
- **Godot Engine 4.6 (Forward Plus)**
- Windows or macOS (for native OS media hook support)

### Running the Project
1. Open the project in Godot Engine 4.6+.
2. Play the main scene (`ui/main_overlay.tscn`).
3. (Optional) Run the background media helper if required by your platform.

---

## 📝 Roadmap & Tasks

Active development is tracked in [**tickets.md**](tickets.md) in the project root. Refer to this file to see what tasks are open, in progress, or completed.

---

## ⚖️ License
This project is open-source and created for educational/nostalgia purposes. All lyrics fetched belong to their respective copyright holders.
