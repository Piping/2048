shader_type canvas_item;
render_mode blend_mix, unshaded;

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform vec4 core_color : source_color = vec4(1.0, 0.92, 0.45, 1.0);
uniform vec4 outer_color : source_color = vec4(1.0, 0.28, 0.06, 1.0);
uniform vec2 center_uv = vec2(0.5, 0.5);
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;

void fragment() {
	vec2 centered = SCREEN_UV - center_uv;
	float radius = length(centered) * 2.0;
	float ring_center = mix(0.05, 1.2, progress);
	float ring = 1.0 - smoothstep(ring_center - 0.16, ring_center + 0.08, radius);
	float hot_core = (1.0 - smoothstep(0.0, 0.45 + progress * 0.25, radius)) * (1.0 - progress);
	float rays = sin(atan(centered.y, centered.x) * 10.0 + radius * 22.0 - TIME * 6.0) * 0.5 + 0.5;
	float distortion = ring * (0.08 + rays * 0.05);
	vec2 screen_uv = SCREEN_UV + normalize(centered + vec2(0.0001)) * distortion * 0.035;
	vec4 sampled = texture(screen_texture, clamp(screen_uv, vec2(0.0), vec2(1.0)));
	vec3 burst = sampled.rgb;
	burst += core_color.rgb * hot_core * 1.8;
	burst += mix(core_color.rgb, outer_color.rgb, radius) * ring * (0.9 + rays * 0.6);
	float alpha = max(ring * 0.8, hot_core) * (1.0 - progress);
	COLOR = vec4(burst, alpha);
}
