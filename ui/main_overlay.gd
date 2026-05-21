extends Control

## MainOverlay is the primary UI controller. It manages the transparent borderless
## window, handles drag-to-move window interaction, and handles scroll-sync of lyrics.

# UI Elements created dynamically
#var panel: Panel
@onready var panel: Panel = $Panel
#var title_label: Label
@onready var title_label: Label = $margin/h_box/track_vbox/title_hbox/title_label
#var subtitle_label: Label
@onready var subtitle_label: Label = $margin/h_box/track_vbox/title_hbox/sub_margin/subtitle_label
#var lyrics_container: VBoxContainer
@onready var lyrics_container: VBoxContainer = $margin/h_box/scroll_container/lyrics_container
#var scroll_container: ScrollContainer
@onready var scroll_container: ScrollContainer = $margin/h_box/scroll_container

# Lyric display tracking
var lyrics_list: Array[Dictionary] = []
var active_line_index: int = -1
var song_time: float = 0.0
var song_duration: float = 0.0
var is_playing: bool = false

# Drag to move variables
var dragging: bool = false
var drag_position: Vector2i = Vector2i()

# Resizing cursor-hover tracking (actual resize is delegated to the OS)
const RESIZE_BORDER: float = 12.0 # Detect range in pixels

func _ready() -> void:
	# Ensure window background is transparent (GL Compatibility renderer supports this)
	#get_window().transparent_bg = true
	
	# Force the rendering clear color to fully transparent so no dark backdrop leaks through
	#RenderingServer.set_default_clear_color(Color(0, 0, 0, 0))
	
	# Programmatic UI setup
	#_build_ui_layout()
	
	# Connect to core signal bus
	GlobalSignals.track_changed.connect(_on_track_changed)
	GlobalSignals.lyrics_fetched.connect(_on_lyrics_fetched)
	GlobalSignals.playback_position_updated.connect(_on_playback_position_updated)

func _notification(what: int) -> void:
	# Re-anchor the panel whenever the OS reports a window size change.
	# This ensures the glass background always fills the window after the user resizes it.
	if what == NOTIFICATION_WM_SIZE_CHANGED and panel != null:
		panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _process(delta: float) -> void:
	# Local timeline interpolation (Client-side prediction for ultra-smoothness)
	if is_playing and lyrics_list.size() > 0:
		song_time = min(song_time + delta, song_duration)
		_update_lyrics_scroller()

#func _build_ui_layout() -> void:
	## 1. Glass Background Panel
	## Prefer the scene-defined child Panel so the user can edit it directly in the editor.
	## If no Panel child exists (e.g. first run without the tscn), create one as a fallback.
	#if has_node("Panel"):
		#panel = get_node("Panel") as Panel
		## Ensure it covers the full window (already set in tscn, belt-and-suspenders here)
		#panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		## NOTE: Shader params are intentionally NOT overridden here — respect whatever
		## the user has set on the ShaderMaterial in the Godot editor.
	#else:
		## Fallback: programmatically create the glass panel if scene child is missing
		#panel = Panel.new()
		#panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		#
		#var glass_style = load("res://assets/shaders/base_stylebox.tres") as StyleBox
		#panel.add_theme_stylebox_override("panel", glass_style)
		#
		#var shader_material = ShaderMaterial.new()
		#shader_material.shader = load("res://assets/shaders/glass_panel.gdshader")
		#shader_material.set_shader_parameter("brightness", 0.1)
		#shader_material.set_shader_parameter("chromatic_shift_amount", 0.2)
		#shader_material.set_shader_parameter("bend_amount", 0.4)
		#shader_material.set_shader_parameter("blur_amount", 2.5)
		#shader_material.set_shader_parameter("grain_amount", 0.05)
		#shader_material.set_shader_parameter("curve_light_blend", 0.5)
		#shader_material.set_shader_parameter("rim_light_blend", 0.8)
		#shader_material.set_shader_parameter("shadow_color", Color(0, 0, 0, 1))
		#panel.material = shader_material
		#
		#add_child(panel)
	#
	## 2. Main Content Margin layout (Sibling to glass panel, free from border constraints)
	#var margin = MarginContainer.new()
	#margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	#margin.add_theme_constant_override("margin_left", 32)
	#margin.add_theme_constant_override("margin_top", 8)
	#margin.add_theme_constant_override("margin_right", 32)
	#margin.add_theme_constant_override("margin_bottom", 8)
	#add_child(margin)
	#
	## 3. Horizontal Splitter (Left: Track Info, Right: Lyrics Scroller)
	#var h_box = HBoxContainer.new()
	#h_box.add_theme_constant_override("separation", 20)
	#margin.add_child(h_box)
	#
	## Left Side: Track metadata
	#var track_vbox = VBoxContainer.new()
	#track_vbox.custom_minimum_size = Vector2(200, 0)
	#track_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	#track_vbox.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	#h_box.add_child(track_vbox)
	#
	## Create a crisp Segoe UI SystemFont stack (Phase 4 requirement)
	#var sys_font = SystemFont.new()
	#sys_font.font_names = PackedStringArray(["Segoe UI", "Trebuchet MS", "Arial"])
	#
	#var title_hbox = HBoxContainer.new()
	#title_hbox.alignment = BoxContainer.ALIGNMENT_BEGIN
	#title_hbox.add_theme_constant_override("separation", 12)
	#track_vbox.add_child(title_hbox)
	#
	## Title Label
	#title_label = Label.new()
	#title_label.text = "Waiting for Media..."
	#title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	#title_label.add_theme_font_override("font", sys_font)
	#title_label.add_theme_font_size_override("font_size", 24)
	#title_label.add_theme_color_override("font_shadow_color", Color(0, 0.5, 0.8, 0.5))
	#title_label.add_theme_constant_override("shadow_offset_x", 1)
	#title_label.add_theme_constant_override("shadow_offset_y", 1)
	#title_hbox.add_child(title_label)
	#
	## Subtitle Label
	#subtitle_label = Label.new()
	#subtitle_label.text = ""
	#subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	#subtitle_label.size_flags_vertical = Control.SIZE_SHRINK_END # Align with bottom of title
	#subtitle_label.add_theme_font_override("font", sys_font)
	#subtitle_label.add_theme_font_size_override("font_size", 12)
	#subtitle_label.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0, 0.8))
	#
	## Subtitle Margin trick for better baseline alignment with the 24px title font
	#var sub_margin = MarginContainer.new()
	#sub_margin.add_theme_constant_override("margin_bottom", 6)
	#sub_margin.add_child(subtitle_label)
	#title_hbox.add_child(sub_margin)
	#
	## Right Side: Lyrics Scroller
	#scroll_container = ScrollContainer.new()
	#scroll_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	#scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	#scroll_container.custom_minimum_size = Vector2(250, 0)
	#scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	#scroll_container.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	#h_box.add_child(scroll_container)
	#
	#lyrics_container = VBoxContainer.new()
	#lyrics_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	#lyrics_container.add_theme_constant_override("separation", 8)
	#scroll_container.add_child(lyrics_container)

## Handles window movement dragging and OS-native borderless resizing.
## Resize is delegated to the OS via start_resize_move_mode() for smooth, hardware-accelerated
## resize without any GDScript polling overhead.
func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				var mouse_pos = get_local_mouse_position()
				var size_rect = size
				var on_right = mouse_pos.x >= size_rect.x - RESIZE_BORDER
				var on_bottom = mouse_pos.y >= size_rect.y - RESIZE_BORDER
				
				# Delegate resize to the OS window manager for smooth, responsive resizing.
				# This is the Godot best-practice for borderless window resizing.
				if on_right and on_bottom:
					DisplayServer.window_start_resize(DisplayServer.WINDOW_EDGE_BOTTOM_RIGHT, get_window().get_window_id())
					get_viewport().set_input_as_handled()
				elif on_right:
					DisplayServer.window_start_resize(DisplayServer.WINDOW_EDGE_RIGHT, get_window().get_window_id())
					get_viewport().set_input_as_handled()
				elif on_bottom:
					DisplayServer.window_start_resize(DisplayServer.WINDOW_EDGE_BOTTOM, get_window().get_window_id())
					get_viewport().set_input_as_handled()
				else:
					# Regular drag-to-move
					dragging = true
					drag_position = DisplayServer.mouse_get_position() - DisplayServer.window_get_position()
			else:
				dragging = false
				

	elif event is InputEventMouseMotion:
		if dragging:
			DisplayServer.window_set_position(DisplayServer.mouse_get_position() - drag_position)
		else:
			# Update mouse cursor shape based on hover position over resize edges
			var mouse_pos = get_local_mouse_position()
			var size_rect = size
			var on_right = mouse_pos.x >= size_rect.x - RESIZE_BORDER
			var on_bottom = mouse_pos.y >= size_rect.y - RESIZE_BORDER
			
			if on_right and on_bottom:
				mouse_default_cursor_shape = Control.CURSOR_FDIAGSIZE
			elif on_right:
				mouse_default_cursor_shape = Control.CURSOR_HSIZE
			elif on_bottom:
				mouse_default_cursor_shape = Control.CURSOR_VSIZE
			else:
				mouse_default_cursor_shape = Control.CURSOR_ARROW
		
	elif event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			get_tree().quit()


func _on_track_changed(title: String, artist: String, album: String) -> void:
	title_label.text = title
	var sub_text = artist
	if album != null and not album.is_empty():
		sub_text += " - " + album
	subtitle_label.text = sub_text
	
	# Clear previous lyrics instantly and show a temporary searching placeholder
	lyrics_list = []
	for child in lyrics_container.get_children():
		child.queue_free()
	
	var loading_label = Label.new()
	loading_label.text = "Searching online for lyrics..."
	loading_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	loading_label.add_theme_font_override("font", _get_sys_font())
	loading_label.add_theme_font_size_override("font_size", 14)
	loading_label.add_theme_color_override("font_color", Color(0.7, 0.9, 1.0, 0.6))
	lyrics_container.add_child(loading_label)
	
	# Reset state on song change
	song_time = 0.0
	song_duration = 0.0
	is_playing = false
	active_line_index = -1

func _on_playback_position_updated(seconds: float, duration: float, playing: bool) -> void:
	# Reconcile local timeline with authoritative OS media timeline
	song_time = seconds
	song_duration = duration
	is_playing = playing
	print("[MainOverlay] Timeline sync: song_time=%.2f, duration=%.2f, is_playing=%s, lyrics_count=%d" % [song_time, song_duration, str(is_playing), lyrics_list.size()])
	
	if lyrics_list.size() > 0:
		_update_lyrics_scroller()

func _on_lyrics_fetched(lyrics_data: Dictionary) -> void:
	# Clear previous lyrics
	for child in lyrics_container.get_children():
		child.queue_free()
	
	if lyrics_data.get("synced", false):
		lyrics_list = lyrics_data.get("lines", [])
		
		# Instantiate labels for each lyric line
		for line in lyrics_list:
			var line_label = Label.new()
			line_label.text = line.get("text", "")
			line_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
			line_label.add_theme_font_override("font", _get_sys_font())
			line_label.add_theme_font_size_override("font_size", 14)
			line_label.add_theme_color_override("font_color", Color(0.7, 0.9, 1.0, 0.6)) # Dim inactive lines
			lyrics_container.add_child(line_label)
	else:
		# Display plain lyrics or error messages (e.g. Lyrics not found)
		lyrics_list = []
		var plain_text = lyrics_data.get("plain", "No lyrics available.")
		var plain_label = Label.new()
		plain_label.text = plain_text
		plain_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		plain_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		plain_label.add_theme_font_override("font", _get_sys_font())
		plain_label.add_theme_font_size_override("font_size", 14)
		plain_label.add_theme_color_override("font_color", Color(0.7, 0.9, 1.0, 0.8))
		lyrics_container.add_child(plain_label)

func _update_lyrics_scroller() -> void:
	if lyrics_list.size() == 0:
		return
		
	var target_index: int = -1
	
	# Find current active line based on playback time
	for i in range(lyrics_list.size()):
		if song_time >= lyrics_list[i]["time"]:
			target_index = i
		else:
			break
			
	if target_index != active_line_index and target_index != -1:
		active_line_index = target_index
		print("[MainOverlay] Lyric highlight change to index: %d ('%s')" % [active_line_index, lyrics_list[active_line_index]["text"]])
		
		# Update UI line highlighting
		var children = lyrics_container.get_children()
		for i in range(children.size()):
			var label = children[i] as Label
			if not label: continue
			
			if i == active_line_index:
				# Highlight active line in pure white with neutral blue outline
				label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
				label.add_theme_font_size_override("font_size", 16)
				
				# Neutral blue outline matching the title theme for perfect white-background legibility
				label.add_theme_color_override("font_outline_color", Color(0.0, 0.5, 0.8, 0.9))
				label.add_theme_constant_override("outline_size", 2)
				
				# Smoothly center scroller to this active line
				var target_y = label.position.y - (scroll_container.size.y / 2.0) + (label.size.y / 2.0)
				var tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
				tween.tween_property(scroll_container, "scroll_vertical", int(max(0, target_y)), 0.3)
			else:
				# Dim inactive lines
				label.add_theme_color_override("font_color", Color(0.7, 0.9, 1.0, 0.4))
				label.add_theme_font_size_override("font_size", 13)
				
				# Remove outline for inactive lyrics
				label.remove_theme_color_override("font_outline_color")
				label.remove_theme_constant_override("outline_size")

func _get_sys_font() -> SystemFont:
	var sys_font = SystemFont.new()
	sys_font.font_names = PackedStringArray(["Segoe UI", "Trebuchet MS", "Arial"])
	return sys_font
