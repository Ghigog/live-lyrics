shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float blur_amount : hint_range(0.0, 5.0) = 2.5;
uniform vec4 glass_tint : source_color = vec4(0.0, 0.5, 0.7, 0.15);
uniform float gloss_intensity : hint_range(0.0, 1.0) = 0.35;

void fragment() {
	// Screen texture read with MIPMAPs for blur
	vec4 color = textureLod(screen_texture, SCREEN_UV, blur_amount);
	
	// Glass tinting (cyan-blue tint)
	color.rgb = mix(color.rgb, glass_tint.rgb, glass_tint.a);
	
	// Y2K/Aero gloss reflection overlay (diagonal shiny band)
	float shiny_line = sin((UV.x + UV.y - TIME * 0.15) * 4.0);
	shiny_line = smoothstep(0.85, 0.98, shiny_line) * gloss_intensity;
	
	// Combine screen blur with tint and shiny highlights
	color.rgb += vec3(shiny_line);
	
	COLOR = vec4(color.rgb, 1.0);
}
