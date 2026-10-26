// Fixed WORLD-space review region, never derived from Game.home/player state.
uniform bool green_enabled = true;
uniform bool whole_exterior = true;
uniform vec2 preview_center = vec2(790.0, 842.0);
uniform float preview_radius = 185.0;
uniform float preview_blend = 25.0;

float green_weight(vec2 point) {
	if (!green_enabled) { return 0.0; }
	if (whole_exterior) { return 1.0; }
	return 1.0 - smoothstep(preview_radius - preview_blend, preview_radius, distance(point, preview_center));
}

float hash_ground(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float ground_noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash_ground(cell), hash_ground(cell + vec2(1.0, 0.0)), u.x),
		mix(hash_ground(cell + vec2(0.0, 1.0)), hash_ground(cell + vec2(1.0)), u.x), u.y);
}
