extends Control

## MainOverlay is the primary UI controller. It manages the transparent borderless
## window, handles drag-to-move window interaction, and handles scroll-sync of lyrics.

# UI Elements created dynamically
var panel: PanelContainer
var track_label: Label
var lyrics_container: VBoxContainer
var scroll_container: ScrollContainer

# Lyric display tracking
var lyrics_list: Array[Dictionary] = []
var active_line_index: int = -1
var song_time: float = 0.0
var song_duration: float = 0.0
var is_playing: bool = false

# Drag to move variables
var dragging: bool = false
var drag_position: Vector2i = Vector2i()

# Click-through toggle state
var click_through_enabled: bool = false

func _ready() -> void:
	# Ensure window background is transparent
	get_window().transparent_bg = true
	
	# Programmatic UI setup to ensure robustness and easy Y2K styling
	_build_ui_layout()
	
	# Connect to core signal bus
	GlobalSignals.track_changed.connect(_on_track_changed)
	GlobalSignals.lyrics_fetched.connect(_on_lyrics_fetched)
	GlobalSignals.playback_position_updated.connect(_on_playback_position_updated)

func _process(delta: float) -> void:
	# Local timeline interpolation (Client-side prediction for ultra-smoothness)
	if is_playing and lyrics_list.size() > 0:
		song_time = min(song_time + delta, song_duration)
		_update_lyrics_scroller()

func _build_ui_layout() -> void:
	# 1. Glass Panel Container (Frutiger Aero Aesthetic)
	panel = PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	# Y2K Glass StyleBox
	var glass_style = StyleBoxFlat.new()
	glass_style.bg_color = Color(0.0, 0.45, 0.65, 0.25) # Soft aqua blue semi-transparent
	glass_style.border_width_left = 2
	glass_style.border_width_top = 2
	glass_style.border_width_right = 2
	glass_style.border_width_bottom = 2
	glass_style.border_color = Color(0.3, 0.8, 1.0, 0.6) # Glossy glowing border
	glass_style.corner_radius_top_left = 12
	glass_style.corner_radius_top_right = 12
	glass_style.corner_radius_bottom_left = 12
	glass_style.corner_radius_bottom_right = 12
	glass_style.shadow_color = Color(0, 0, 0, 0.15)
	glass_style.shadow_size = 10
	panel.add_theme_stylebox_override("panel", glass_style)
	
	# Load and apply the custom pneumaturgy-godot Y2K Liquid-Glass Shader
	var shader_material = ShaderMaterial.new()
	shader_material.shader = load("res://assets/shaders/glass_panel.gdshader")
	shader_material.set_shader_parameter("brightness", 0.08)
	shader_material.set_shader_parameter("chromatic_shift_amount", 0.15)
	shader_material.set_shader_parameter("bend_amount", 0.25)
	shader_material.set_shader_parameter("blur_amount", 3.0) # Sleek blurred desktop background refraction
	shader_material.set_shader_parameter("grain_amount", 0.03) # Subtle organic grain texture
	shader_material.set_shader_parameter("curve_light_blend", 0.5)
	shader_material.set_shader_parameter("rim_light_blend", 0.7)
	shader_material.set_shader_parameter("shadow_color", Color(0, 0, 0, 0.15))
	panel.material = shader_material
	
	add_child(panel)
	
	# 2. Main Margin layout
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)
	
	# 3. Horizontal Splitter (Left: Track Info, Right: Lyrics Scroller)
	var h_box = HBoxContainer.new()
	h_box.add_theme_constant_override("separation", 20)
	margin.add_child(h_box)
	
	# Left Side: Track metadata
	var track_vbox = VBoxContainer.new()
	track_vbox.custom_minimum_size = Vector2(200, 0)
	track_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	h_box.add_child(track_vbox)
	
	# Y2K Bubble Icon (Visual effect)
	var bubble = Panel.new()
	bubble.custom_minimum_size = Vector2(32, 32)
	var bubble_style = StyleBoxFlat.new()
	bubble_style.bg_color = Color(0.0, 0.7, 1.0, 0.5)
	bubble_style.corner_radius_top_left = 16
	bubble_style.corner_radius_top_right = 16
	bubble_style.corner_radius_bottom_left = 16
	bubble_style.corner_radius_bottom_right = 16
	bubble.add_theme_stylebox_override("panel", bubble_style)
	track_vbox.add_child(bubble)
	
	# Track name & Artist Label
	track_label = Label.new()
	track_label.text = "Waiting for Media..."
	track_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	track_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# Aesthetic Glow
	track_label.add_theme_color_override("font_shadow_color", Color(0, 0.5, 0.8, 0.5))
	track_label.add_theme_constant_override("shadow_offset_x", 1)
	track_label.add_theme_constant_override("shadow_offset_y", 1)
	track_vbox.add_child(track_label)
	
	# Instruction tooltip Label
	var instructions = Label.new()
	instructions.text = "[L-Drag to Move] [R-Click to Exit] [T to Click-Thru]"
	instructions.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	instructions.add_theme_font_size_override("font_size", 9)
	instructions.add_theme_color_override("font_color", Color(0.8, 0.95, 1.0, 0.7))
	track_vbox.add_child(instructions)
	
	# Right Side: Lyrics Scroller
	scroll_container = ScrollContainer.new()
	scroll_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll_container.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	h_box.add_child(scroll_container)
	
	lyrics_container = VBoxContainer.new()
	lyrics_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lyrics_container.add_theme_constant_override("separation", 8)
	scroll_container.add_child(lyrics_container)

## Handles window movement dragging
func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			dragging = event.pressed
			drag_position = DisplayServer.mouse_get_position() - DisplayServer.window_get_position()
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			# Exit overlay on Right Click
			get_tree().quit()
			
	elif event is InputEventMouseMotion and dragging:
		DisplayServer.window_set_position(DisplayServer.mouse_get_position() - drag_position)
		
	elif event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			get_tree().quit()
		elif event.keycode == KEY_T:
			toggle_click_through()

## Toggle click-through mode
func toggle_click_through() -> void:
	click_through_enabled = !click_through_enabled
	if click_through_enabled:
		DisplayServer.window_set_mouse_passthrough(PackedVector2Array([Vector2(-1, -1)]))
		panel.self_modulate.a = 0.4 # Fade overlay visually when click-through is enabled
		print("[MainOverlay] Mouse click-through ENABLED")
	else:
		DisplayServer.window_set_mouse_passthrough(PackedVector2Array())
		panel.self_modulate.a = 1.0
		print("[MainOverlay] Mouse click-through DISABLED")

func _on_track_changed(title: String, artist: String, album: String) -> void:
	var display_text = "%s\nby %s" % [title, artist]
	if album != null and not album.is_empty():
		display_text += "\n[%s]" % album
	track_label.text = display_text
	
	# Clear previous lyrics instantly and show a temporary searching placeholder
	lyrics_list = []
	for child in lyrics_container.get_children():
		child.queue_free()
	
	var loading_label = Label.new()
	loading_label.text = "Searching online for lyrics..."
	loading_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
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
				# Highlight active line in bright aqua with glow
				label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.8, 1.0))
				label.add_theme_font_size_override("font_size", 16)
				
				# Smoothly center scroller to this active line
				var target_y = label.position.y - (scroll_container.size.y / 2.0) + (label.size.y / 2.0)
				var tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
				tween.tween_property(scroll_container, "scroll_vertical", int(max(0, target_y)), 0.3)
			else:
				# Dim inactive lines
				label.add_theme_color_override("font_color", Color(0.7, 0.9, 1.0, 0.4))
				label.add_theme_font_size_override("font_size", 13)
