shader_type spatial;
render_mode cull_back;
#include "res://shaders/external_biome_common.gdshaderinc"

// Only the foliage/rock surface of terrain chunks uses this material.
// Snow terrain, landmarks, cities and resource models remain untouched.
uniform sampler2D city_mask : filter_nearest, repeat_disable;
uniform vec2 home_xz = vec2(0.0);
uniform float clear_radius = 5.8;
varying vec2 map_xz;

void vertex() {
	map_xz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
	if (texture(city_mask, map_xz / 1200.0).r > 0.5
			|| distance(map_xz, home_xz) < clear_radius) {
		discard;
	}
	bool green_branch = COLOR.g > COLOR.r * 1.25 && COLOR.g > COLOR.b * 1.05;
	float snow_top = smoothstep(0.055, 0.16, min(COLOR.r, min(COLOR.g, COLOR.b)));
	vec3 leaves = mix(vec3(0.025, 0.075, 0.025), vec3(0.075, 0.16, 0.045), snow_top);
	float foliage = max(green_branch ? 1.0 : 0.0, snow_top);
	ALBEDO = mix(COLOR.rgb, leaves, foliage * green_weight(map_xz));
	ROUGHNESS = 0.85;
	SPECULAR = 0.25;
}
