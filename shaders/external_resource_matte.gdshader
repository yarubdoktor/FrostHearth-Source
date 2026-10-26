shader_type spatial;
render_mode cull_back;
#include "res://shaders/external_biome_common.gdshaderinc"
varying vec2 world_xz;

void vertex() {
	world_xz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
	float green = green_weight(world_xz);
	float snow_color = smoothstep(0.55, 0.72, min(COLOR.r, min(COLOR.g, COLOR.b)));
	ALBEDO = mix(COLOR.rgb, vec3(0.28, 0.30, 0.27), green * snow_color);
	ROUGHNESS = 0.85;
	SPECULAR = 0.25;
}
