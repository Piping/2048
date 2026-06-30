shader_type canvas_item;
render_mode blend_mix, unshaded;

uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform float tier : hint_range(0.0, 3.0) = 1.0;
uniform vec4 glow_color : source_color = vec4(1.0, 0.45, 0.08, 1.0);
uniform vec4 core_color : source_color = vec4(1.0, 0.84, 0.24, 1.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
}

float fbm(vec2 p) {
	float value = 0.0;
	float amplitude = 0.5;
	for (int i = 0; i < 4; i++) {
		value += noise(p) * amplitude;
		p *= 2.02;
		amplitude *= 0.5;
	}
	return value;
}

void fragment() {
	float active = step(0.01, intensity);
	vec2 centered = UV * 2.0 - 1.0;
	float edge = 1.0 - max(abs(centered.x), abs(centered.y));
	float tier01 = clamp((tier - 1.0) / 2.0, 0.0, 1.0);
	float edge_band = mix(0.10, 0.28, tier01);
	float inner_mask = smoothstep(0.0, mix(0.08, 0.22, tier01), edge);
	float flame_band = smoothstep(0.01, edge_band, edge) * (1.0 - inner_mask);
	float flow = fbm(vec2(UV.x * (4.0 + tier * 1.8), UV.y * (5.0 + tier * 2.6) - TIME * (1.2 + tier * 0.8)));
	float tongues = fbm(vec2(UV.x * (8.0 + tier * 3.1) + TIME * 0.7, UV.y * (9.0 + tier * 3.4) - TIME * (2.4 + tier * 1.5)));
	float vortex = fbm(vec2(UV.yx * vec2(9.0, 5.0) + vec2(TIME * 0.4, -TIME * 1.2)));
	float ember_noise = fbm(vec2(UV * vec2(12.0, 20.0) + vec2(0.0, -TIME * 4.5)));

	float heat_haze = smoothstep(0.0, 0.22, edge) * (0.05 + intensity * 0.28) * (1.0 - tier01);
	float heat_core = smoothstep(0.26, 0.92, flow * 0.55 + tongues * 0.35 + vortex * 0.12) * flame_band;
	float flame_core = smoothstep(0.22, 0.88, flow * 0.45 + tongues * 0.55 + vortex * 0.22) * flame_band * tier01;
	float inferno = smoothstep(0.34, 0.94, tongues * 0.6 + vortex * 0.25 + ember_noise * 0.18) * flame_band * clamp(tier - 2.0, 0.0, 1.0);
	float halo = smoothstep(0.0, 0.30 + 0.06 * tier, edge) * intensity * mix(0.18, 0.48, tier01);
	float ember_sparks = smoothstep(0.78, 0.96, ember_noise) * inferno * 1.6;

	float alpha = clamp(
		heat_haze
		+ heat_core * (0.18 + intensity * 0.24)
		+ flame_core * (0.30 + intensity * 0.50)
		+ inferno * (0.24 + intensity * 0.42)
		+ halo,
		0.0,
		0.98
	) * active;
	vec3 flame = mix(core_color.rgb, glow_color.rgb, clamp(flow + tongues * 0.42, 0.0, 1.0));
	vec3 color =
		core_color.rgb * heat_haze * 0.7 +
		mix(core_color.rgb, glow_color.rgb, 0.35) * heat_core * 0.8 +
		flame * flame_core * (0.9 + tier * 0.18) +
		mix(core_color.rgb, glow_color.rgb, 0.8) * inferno * 1.2 +
		vec3(1.0, 0.88, 0.55) * ember_sparks +
		glow_color.rgb * halo * (0.35 + tier * 0.15);
	COLOR = vec4(color, alpha);
}
