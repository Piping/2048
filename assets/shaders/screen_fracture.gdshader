shader_type canvas_item;
render_mode blend_mix, unshaded;

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float intensity : hint_range(0.0, 2.0) = 1.0;
uniform vec4 tint_color : source_color = vec4(1.0, 0.62, 0.18, 1.0);
uniform vec2 center_uv = vec2(0.5, 0.5);
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(41.0, 289.0))) * 43758.5453123);
}

float crack(vec2 p) {
	vec2 cell = floor(p);
	vec2 local = fract(p) - 0.5;
	float closest = 1.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 offset = vec2(float(x), float(y));
			vec2 seed = cell + offset;
			vec2 point = offset + vec2(hash(seed), hash(seed + 7.13)) - 0.5;
			closest = min(closest, length(local - point));
		}
	}
	return closest;
}

void fragment() {
	vec2 centered = SCREEN_UV - center_uv;
	float radius = length(centered) * 2.0;
	float radial = 1.0 - smoothstep(0.0, 1.15, radius);
	float ring = smoothstep(0.08, 0.55, progress) * (1.0 - smoothstep(0.45, 1.1, radius + progress * 0.28));
	float crack_mask = 1.0 - smoothstep(0.03, 0.08, crack(UV * 10.0 + TIME * 0.15));
	float distortion = crack_mask * intensity * 0.03 * (1.0 - progress) + ring * 0.015 * intensity;
	vec2 dir = normalize(centered + vec2(0.0001));
	vec2 screen_uv = SCREEN_UV + dir * distortion;
	vec4 base = texture(screen_texture, clamp(screen_uv, vec2(0.0), vec2(1.0)));
	float flare = (crack_mask * 0.8 + ring * 0.6) * intensity * (1.0 - progress);
	vec3 color = base.rgb + tint_color.rgb * flare;
	float alpha = clamp(flare * radial + ring * 0.22, 0.0, 0.95);
	COLOR = vec4(color, alpha);
}
