shader_type canvas_item;

// ─── Base Glass ───────────────────────────────────────────────────────────────
uniform vec4  glass_color      : source_color = vec4(0.06, 0.12, 0.22, 0.78);
uniform vec4  highlight_color  : source_color = vec4(0.55, 0.90, 1.00, 0.22);

// ─── Border ───────────────────────────────────────────────────────────────────
uniform vec4  border_color     : source_color = vec4(0.45, 0.88, 1.00, 0.80);
uniform float border_thickness : hint_range(0.001, 0.05, 0.001) = 0.008;

// ─── Specular highlight (bright patch, top-left, like macOS glass) ────────────
uniform float specular_intensity : hint_range(0.0, 1.0,  0.05) = 0.35;
uniform float specular_sharpness : hint_range(1.0, 12.0, 0.5)  = 4.0;
uniform vec2  specular_origin                                   = vec2(0.22, 0.0);

// ─── Top-edge inner gloss band ────────────────────────────────────────────────
uniform float gloss_intensity  : hint_range(0.0, 1.0,  0.05) = 0.18;
uniform float gloss_thickness  : hint_range(0.01, 0.3, 0.01) = 0.10;

// ─── Diagonal shine sweep ─────────────────────────────────────────────────────
uniform float shine_speed      : hint_range(0.0, 2.0,  0.05) = 0.28;
uniform float shine_intensity  : hint_range(0.0, 1.0,  0.05) = 0.13;
uniform float shine_width      : hint_range(0.0, 0.6,  0.01) = 0.20;

// ─── Frosted texture (multi-octave noise) ─────────────────────────────────────
uniform float frost_scale      : hint_range(2.0, 40.0, 0.5)  = 18.0;
uniform float frost_intensity  : hint_range(0.0, 0.15, 0.005) = 0.045;

// ─── Caustics (animated light pooling, realistic glass refraction sim) ────────
uniform float caustic_scale    : hint_range(1.0, 10.0, 0.5)  = 3.5;
uniform float caustic_speed    : hint_range(0.0, 2.0,  0.05) = 0.18;
uniform float caustic_intensity : hint_range(0.0, 0.3, 0.01) = 0.055;

// ─── Chromatic aberration at edges (lens fringe) ─────────────────────────────
uniform float chroma_intensity : hint_range(0.0, 0.05, 0.002) = 0.018;

// ─── Vignette (edges slightly darker) ────────────────────────────────────────
uniform float vignette_intensity : hint_range(0.0, 1.0, 0.05) = 0.25;

// ─────────────────────────────────────────────────────────────────────────────

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(hash(i),              hash(i + vec2(1.0, 0.0)), f.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x),
		f.y
	);
}

// Multi-octave fractal noise — gives the "frosted" micro-texture
float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	vec2  shift = vec2(100.0);
	for (int i = 0; i < 5; i++) {
		v += a * vnoise(p);
		p  = p * 2.1 + shift;
		a *= 0.5;
	}
	return v;
}

// Voronoi-like caustic cell noise
float caustic(vec2 p) {
	vec2  cell = floor(p);
	float c = 1.0;
	for (int x = -1; x <= 1; x++) {
		for (int y = -1; y <= 1; y++) {
			vec2 neighbor = cell + vec2(float(x), float(y));
			vec2 pt = neighbor + vec2(
				sin(neighbor.y * 7.3 + TIME * caustic_speed),
				cos(neighbor.x * 5.1 + TIME * caustic_speed * 0.7)
			) * 0.45;
			c = min(c, length(p - pt));
		}
	}
	return c;
}

void fragment() {
	// The StyleBox is set to bg_color=white, no shadow.
	// Godot's rasterizer sets COLOR.a=0 for pixels outside the rounded corners,
	// and COLOR.a=1 inside. We just discard anything outside the shape.
	if (COLOR.a < 0.5) { discard; }

	// shape is the anti-aliased edge mask from the StyleBox rasterizer.
	// Pixels right on the edge will have 0 < COLOR.a < 1 for smooth AA.
	float shape = COLOR.a;

	// Correct UV for aspect ratio so all effects are square in pixel space
	float aspect = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	vec2  uva    = vec2(UV.x * aspect, UV.y);

	// ── Border (UV edge distance, works correctly for any shape) ──────────────
	// min distance from any edge in UV space, normalised by border_thickness.
	float bx = min(UV.x, 1.0 - UV.x) / max(border_thickness, 0.001);
	float by = min(UV.y, 1.0 - UV.y) / max(border_thickness, 0.001);
	// Clamp to shape so the border ring never bleeds outside the rounded corners.
	float border = (1.0 - smoothstep(0.0, 1.0, min(bx, by))) * shape;

	// ── Frost (5-octave FBM, slow drift) ──────────────────────────────────────
	vec2  frost_uv = UV * frost_scale;
	float frost    = (fbm(frost_uv + vec2(TIME * 0.03, TIME * 0.017)) - 0.5)
	               * frost_intensity;

	// ── Caustics ──────────────────────────────────────────────────────────────
	vec2  cst_uv = UV * caustic_scale;
	float cst    = pow(caustic(cst_uv), 2.5) * caustic_intensity;

	// ── Chromatic aberration ───────────────────────────────────────────────────
	float edge_factor = border;
	float chroma_r = vnoise(UV * 12.0 + vec2( chroma_intensity, 0.0) * edge_factor) * edge_factor;
	float chroma_b = vnoise(UV * 12.0 + vec2(-chroma_intensity, 0.0) * edge_factor) * edge_factor;

	// ── Specular highlight ─────────────────────────────────────────────────────
	vec2  spec_uv  = uva - vec2(specular_origin.x * aspect, specular_origin.y);
	float spec_r2  = dot(spec_uv, spec_uv);
	float specular = exp(-spec_r2 * specular_sharpness) * specular_intensity;

	// ── Top-edge gloss band ───────────────────────────────────────────────────
	float gloss = smoothstep(0.0, gloss_thickness * 0.5, gloss_thickness - UV.y)
	            * smoothstep(0.0, 0.01, UV.y)
	            * gloss_intensity;

	// ── Diagonal shine sweep ──────────────────────────────────────────────────
	float sp    = mod(TIME * shine_speed, 3.5) - 0.4;
	float sd    = UV.x + UV.y;
	float shine = smoothstep(sp - shine_width, sp, sd)
	            * (1.0 - smoothstep(sp, sp + shine_width, sd))
	            * shine_intensity;

	// ── Vignette ──────────────────────────────────────────────────────────────
	float vig = clamp(
		(1.0 - pow(length(UV - 0.5) * 1.6, 2.0)) * (1.0 - vignette_intensity) + (1.0 - vignette_intensity),
		0.0, 1.0);

	// ── Composite ─────────────────────────────────────────────────────────────
	vec3 col = glass_color.rgb
	         + highlight_color.rgb * highlight_color.a
	         + frost + cst + specular + gloss + shine;

	col.r += chroma_r * chroma_intensity * 0.5;
	col.b += chroma_b * chroma_intensity * 0.5;
	col   *= vig;
	col    = mix(col, border_color.rgb, border * border_color.a);

	// Alpha: glass body + border ring boost, all clipped to shape AA
	float alpha = clamp(
		mix(glass_color.a, max(glass_color.a, border_color.a), border * border_color.a),
		0.0, 1.0
	) * shape;

	COLOR = vec4(clamp(col, 0.0, 1.0), alpha);
}
