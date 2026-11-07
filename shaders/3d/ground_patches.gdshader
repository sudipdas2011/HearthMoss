shader_type spatial;
// Patchy, painterly ground like the marsh reference: blotches of earthy colors + tiny flecks.
// Patterns are in WORLD space, so they stay put while the camera moves.
// Lit normally (receives light and shadows), no shiny highlights.
render_mode diffuse_lambert, specular_disabled;

// Defaults are taken from palette_autumn.png. Lowest to highest noise value.
uniform vec3 col_a : source_color = vec3(0.329, 0.384, 0.275); // olive green
uniform vec3 col_b : source_color = vec3(0.443, 0.400, 0.322); // muddy brown
uniform vec3 col_c : source_color = vec3(0.471, 0.388, 0.255); // dark ochre
uniform vec3 col_d : source_color = vec3(0.678, 0.561, 0.325); // dry grass
uniform vec3 col_e : source_color = vec3(0.757, 0.671, 0.408); // pale straw

// Patch size: bigger number = smaller blotches.
uniform float patch_scale : hint_range(0.05, 3.0) = 0.35;
// Thresholds where one color turns into the next.
uniform float t1 : hint_range(0.0, 1.0) = 0.32;
uniform float t2 : hint_range(0.0, 1.0) = 0.46;
uniform float t3 : hint_range(0.0, 1.0) = 0.60;
uniform float t4 : hint_range(0.0, 1.0) = 0.74;

// Tiny 1-pixel flecks (flowers, grass tips). Tune density to your pixel size.
uniform vec3 fleck_color : source_color = vec3(0.831, 0.694, 0.188);
uniform float fleck_density : hint_range(0.5, 12.0) = 3.0;
uniform float fleck_amount : hint_range(0.0, 0.5) = 0.08;

varying vec3 wpos;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = wpos.xz;

	float n = vnoise(p * patch_scale) * 0.60
			+ vnoise(p * patch_scale * 2.3) * 0.30
			+ vnoise(p * patch_scale * 5.1) * 0.10;

	vec3 col = col_a;
	col = mix(col, col_b, step(t1, n));
	col = mix(col, col_c, step(t2, n));
	col = mix(col, col_d, step(t3, n));
	col = mix(col, col_e, step(t4, n));

	vec2 cell = floor(p * fleck_density);
	vec2 local = fract(p * fleck_density) - 0.5;
	float h = hash(cell);
	float square = step(max(abs(local.x), abs(local.y)), 0.2);
	float fleck = step(1.0 - fleck_amount, h) * square;
	col = mix(col, fleck_color, fleck);

	ALBEDO = col;
	ROUGHNESS = 1.0;
}
