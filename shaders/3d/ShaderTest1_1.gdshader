shader_type spatial;
// Pixel post-process v2: soft tinted outlines -> optional dither -> perceptual palette snap.
// The palette match is done in OKLab, so a pink object stays pink (it picks the closest
// berry shade) instead of collapsing into brown. Works on Mobile and Forward+.
// Needs an ORTHOGONAL Camera3D. Put this on a QuadMesh (Size 2x2, Flip Faces ON,
// Extra Cull Margin = max), child of the camera, inside the low-res SubViewport.
// Set Environment -> Tonemap -> Linear.
render_mode unshaded, depth_test_disabled, cull_disabled;

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
// N x 1 palette image (import: Mipmaps off, Compress Mode Lossless).
uniform sampler2D palette_tex : source_color, filter_nearest;

// --- Outlines ---
uniform float outline_strength : hint_range(0.0, 1.0) = 0.7;
uniform float outline_darken : hint_range(0.0, 1.0) = 0.55;
uniform vec4 outline_color : source_color = vec4(0.13, 0.11, 0.16, 1.0);
uniform float outline_tint : hint_range(0.0, 1.0) = 0.8;
uniform bool use_depth_outline = true;
uniform bool use_color_outline = false;
uniform float depth_threshold : hint_range(0.0, 2.0) = 0.12;
uniform float color_threshold : hint_range(0.0, 1.0) = 0.12;

// --- Palette ---
uniform bool use_palette = true;
// 0 = original colors, 1 = fully snapped to the palette.
uniform float palette_strength : hint_range(0.0, 1.0) = 1.0;
// Below 1 favors matching brightness over hue (keeps light/shadow bands cleaner).
uniform float chroma_weight : hint_range(0.0, 2.0) = 1.0;
uniform float dither_strength : hint_range(0.0, 0.2) = 0.0;

const float BAYER[16] = float[](
	0.0, 8.0, 2.0, 10.0,
	12.0, 4.0, 14.0, 6.0,
	3.0, 11.0, 1.0, 9.0,
	15.0, 7.0, 13.0, 5.0
);

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

float get_depth(vec2 uv, mat4 inv_proj) {
	float raw = texture(depth_tex, uv).x;
	vec3 ndc = vec3(uv * 2.0 - 1.0, raw);
	vec4 view = inv_proj * vec4(ndc, 1.0);
	view.xyz /= view.w;
	return -view.z;
}

float lum(vec3 c) {
	return dot(c, vec3(0.299, 0.587, 0.114));
}

// Linear sRGB -> OKLab
vec3 to_oklab(vec3 c) {
	float l = 0.4122214708 * c.r + 0.5363325363 * c.g + 0.0514459929 * c.b;
	float m = 0.2119034982 * c.r + 0.6806995451 * c.g + 0.1073969566 * c.b;
	float s = 0.0883024619 * c.r + 0.2817188376 * c.g + 0.6299787005 * c.b;
	l = pow(max(l, 0.0), 1.0 / 3.0);
	m = pow(max(m, 0.0), 1.0 / 3.0);
	s = pow(max(s, 0.0), 1.0 / 3.0);
	return vec3(
		0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
		1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
		0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s);
}

vec3 snap_to_palette(vec3 c) {
	int n = textureSize(palette_tex, 0).x;
	vec3 lab = to_oklab(c);
	vec3 best = c;
	float best_d = 1e9;
	for (int i = 0; i < n; i++) {
		vec3 p = texture(palette_tex, vec2((float(i) + 0.5) / float(n), 0.5)).rgb;
		vec3 d = to_oklab(p) - lab;
		float dist = d.x * d.x + chroma_weight * (d.y * d.y + d.z * d.z);
		if (dist < best_d) {
			best_d = dist;
			best = p;
		}
	}
	return best;
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 px = 1.0 / VIEWPORT_SIZE;
	vec2 ox = vec2(px.x, 0.0);
	vec2 oy = vec2(0.0, px.y);

	vec3 c = texture(screen_tex, uv).rgb;
	float edge = 0.0;

	if (use_depth_outline) {
		float d  = get_depth(uv, INV_PROJECTION_MATRIX);
		float dl = get_depth(uv - ox, INV_PROJECTION_MATRIX);
		float dr = get_depth(uv + ox, INV_PROJECTION_MATRIX);
		float du = get_depth(uv - oy, INV_PROJECTION_MATRIX);
		float dd = get_depth(uv + oy, INV_PROJECTION_MATRIX);
		float sx = dl + dr - 2.0 * d;
		float sy = du + dd - 2.0 * d;
		edge = max(edge, step(depth_threshold, max(-sx, -sy)));
	}

	if (use_color_outline) {
		float l = lum(c);
		float diff = 0.0;
		diff = max(diff, lum(texture(screen_tex, uv + ox).rgb) - l);
		diff = max(diff, lum(texture(screen_tex, uv - ox).rgb) - l);
		diff = max(diff, lum(texture(screen_tex, uv + oy).rgb) - l);
		diff = max(diff, lum(texture(screen_tex, uv - oy).rgb) - l);
		edge = max(edge, step(color_threshold, diff));
	}

	vec3 line = mix(outline_color.rgb, c * outline_darken, outline_tint);
	vec3 col = mix(c, line, edge * outline_strength);

	if (use_palette) {
		int bx = int(mod(FRAGCOORD.x, 4.0));
		int by = int(mod(FRAGCOORD.y, 4.0));
		float b = BAYER[by * 4 + bx] / 16.0 - 0.5;
		vec3 snapped = snap_to_palette(max(col + b * dither_strength, vec3(0.0)));
		col = mix(col, snapped, palette_strength);
	}

	ALBEDO = col;
}
