shader_type spatial;
render_mode cull_back;
#include "res://shaders/external_biome_common.gdshaderinc"
varying vec2 world_xz;
varying float asset_height;

void vertex() {
	world_xz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
	asset_height = VERTEX.y;
}

void fragment() {
	float green = green_weight(world_xz);
	// Remove only the separate snow overlay, revealing the existing roof.
	if (green > 0.5 && asset_height > 0.28) { discard; }
	ALBEDO = mix(COLOR.rgb, vec3(0.15, 0.19, 0.075), green);
	ROUGHNESS = 0.92;
	SPECULAR = 0.18;
}
