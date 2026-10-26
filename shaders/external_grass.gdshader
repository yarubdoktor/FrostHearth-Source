shader_type spatial;
render_mode cull_back;
#include "res://shaders/external_biome_common.gdshaderinc"
varying vec3 world_point;
varying float slope;

void vertex() {
	world_point = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	slope = 1.0 - abs(normalize(MODEL_NORMAL_MATRIX * NORMAL).y);
}

void fragment() {
	float broad = ground_noise(world_point.xz * 0.025);
	float detail = ground_noise(world_point.xz * 0.27);
	vec3 grass = mix(vec3(0.065, 0.13, 0.03), vec3(0.18, 0.28, 0.075), broad);
	grass *= 0.82 + detail * 0.36;
	float earth = smoothstep(0.68, 0.87, ground_noise(world_point.xz * 0.085 + vec2(18.0)));
	grass = mix(grass, vec3(0.20, 0.17, 0.105), earth * 0.35);
	float rock = smoothstep(0.13, 0.46, slope);
	vec3 landscape = mix(grass, vec3(0.24, 0.26, 0.24), rock);
	float summit_snow = smoothstep(17.0, 26.0, world_point.y) * (1.0 - smoothstep(0.33, 0.65, slope));
	landscape = mix(landscape, vec3(0.69, 0.76, 0.79), summit_snow);
	ALBEDO = mix(COLOR.rgb, landscape, green_weight(world_point.xz));
	ROUGHNESS = 0.94;
	SPECULAR = 0.18;
}
