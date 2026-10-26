shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back;
// المرحلة 32 — سطح ثلجي سينمائي: تفاوت تفصيلي، لمعة بلورية متلألئة، برد زرقاء في الانخفاضات.
// يعمل في كل العارضات (Mobile/Forward+/Compatibility) لأنه spatial قياسي بلا مميزات خاصة.

varying vec3 v_world;
varying vec3 v_col;

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_col = COLOR.rgb;
}

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash12(i), hash12(i + vec2(1.0, 0.0)), u.x),
		mix(hash12(i + vec2(0.0, 1.0)), hash12(i + vec2(1.0, 1.0)), u.x), u.y);
}

void fragment() {
	vec3 base = v_col;
	// تفاوت تفصيلي دقيق يكسر رتابة اللون الواحد
	float n1 = vnoise(v_world.xz * 0.35);
	float n2 = vnoise(v_world.xz * 1.7);
	base *= 0.76 + 0.10 * mix(n1, n2, 0.5);
	// مسحات صخرية باردة زرقاء في المنخفضات — تبرّد الثلج كي لا يُحرق بالتعريض
	base = mix(base, base * vec3(0.84, 0.90, 1.04), 0.4 + 0.3 * smoothstep(0.35, 0.75, n1));
	ALBEDO = base;
	METALLIC = 0.0;
	ROUGHNESS = 0.62 + 0.10 * n2;
	SPECULAR = 0.35;
	// تلألؤ بلوري: خلايا عشوائية تلمع حسب زاوية الرؤية والزمن
	vec3 view_dir = normalize(CAMERA_POSITION_WORLD - v_world);
	vec2 cell = floor(v_world.xz * 9.0);
	float glint_seed = hash12(cell + floor(vec2(TIME * 1.7)));
	float glint = pow(glint_seed, 28.0);
	float grazing = pow(1.0 - clamp(abs(view_dir.y), 0.0, 1.0), 1.5);
	float sparkle = glint * (0.25 + 0.75 * grazing);
	ROUGHNESS = mix(ROUGHNESS, 0.25, sparkle);
	EMISSION = vec3(0.75, 0.85, 1.0) * sparkle * 0.18;
}
