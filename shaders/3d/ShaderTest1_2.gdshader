shader_type canvas_item;

uniform vec4 outline_color : source_color = vec4(0.1, 0.08, 0.12, 1.0);
uniform float edge_threshold = 0.12;

float lum(vec3 c) {
	return dot(c, vec3(0.299, 0.587, 0.114));
}

void fragment() {
	vec2 px = TEXTURE_PIXEL_SIZE;
	vec3 c = texture(TEXTURE, UV).rgb;
	float l = lum(c);
	float diff = 0.0;
	diff = max(diff, lum(texture(TEXTURE, UV + vec2(px.x, 0.0)).rgb) - l);
	diff = max(diff, lum(texture(TEXTURE, UV - vec2(px.x, 0.0)).rgb) - l);
	diff = max(diff, lum(texture(TEXTURE, UV + vec2(0.0, px.y)).rgb) - l);
	diff = max(diff, lum(texture(TEXTURE, UV - vec2(0.0, px.y)).rgb) - l);
	float edge = step(edge_threshold, diff);
	COLOR = vec4(mix(c, outline_color.rgb, edge), 1.0);
}