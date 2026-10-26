shader_type spatial;
render_mode cull_back;
#include "res://shaders/external_biome_common.gdshaderinc"
varying vec2 world_xz;

void vertex() {
	world_xz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
	float ripple = sin(world_xz.x * 0.65 + world_xz.y * 0.28) * 0.008;
	vec3 water = vec3(0.025, 0.14, 0.17) + vec3(ripple);
	ALBEDO = mix(COLOR.rgb, water, green_weight(world_xz));
	ROUGHNESS = mix(0.28, 0.42, green_weight(world_xz));
	SPECULAR = 0.45;
}
