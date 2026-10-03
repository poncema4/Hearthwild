shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;
// Lake water. Everything about the shore comes from `depth_map`: a small image of the real terrain under the
// lake (red = how far the ground is below the surface, 0 at the waterline, 1 at max_depth), baked by
// terrain.gd, so the shoreline, shallows and foam follow the actual ground in both renderers (no depth texture).

uniform sampler2D depth_map : filter_linear, repeat_disable;
uniform float map_half_extent = 22.0;
uniform float max_depth = 4.0;
uniform vec3 shallow_color : source_color = vec3(0.30, 0.66, 0.66);
uniform vec3 deep_color : source_color = vec3(0.04, 0.20, 0.40);
uniform vec3 foam_color : source_color = vec3(0.93, 0.97, 1.0);
uniform vec3 sky_tint : source_color = vec3(0.62, 0.78, 0.95);
uniform float daylight = 1.0;       // 1 by day, 0 in the dead of night (set by DayNight)
uniform float wave_strength = 0.05;
uniform float wave_speed = 0.6;

varying vec3 local_pos;
varying vec3 world_pos;

void vertex() {
	local_pos = VERTEX;
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float wave_height(vec2 p, float t) {
	float h = sin(dot(p, vec2(0.90, 0.40)) * 1.7 + t * 1.3);
	h += 0.7 * sin(dot(p, vec2(-0.50, 0.85)) * 2.9 + t * 1.9);
	h += 0.4 * sin(dot(p, vec2(0.20, -1.00)) * 4.7 + t * 2.6);
	return h;
}

void fragment() {
	vec2 uv = local_pos.xz / (2.0 * map_half_extent) + 0.5;
	float depth01 = texture(depth_map, uv).r;       // 0 at the waterline
	float t = TIME * wave_speed;
	vec2 p = world_pos.xz;
	float e = 0.15;
	float h0 = wave_height(p, t);
	float hx = wave_height(p + vec2(e, 0.0), t);
	float hz = wave_height(p + vec2(0.0, e), t);
	vec3 n_world = normalize(vec3(-(hx - h0) / e * wave_strength, 1.0, -(hz - h0) / e * wave_strength));
	NORMAL = normalize((VIEW_MATRIX * vec4(n_world, 0.0)).xyz);

	float deep_mix = smoothstep(0.0, 0.55, depth01);
	vec3 col = mix(shallow_color, deep_color, deep_mix);
	// Fresnel from the smooth surface, NOT the rippled normal (that made every ripple flip the colour, which read
	// as lava at dusk), and a dimmer sky tint in low light.
	vec3 flat_normal = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
	float fresnel = pow(1.0 - clamp(dot(flat_normal, VIEW), 0.0, 1.0), 3.0);
	col = mix(col, sky_tint * mix(0.4, 1.0, daylight), fresnel * 0.5);

	// Foam: a thin band right at the waterline that breathes in and out.
	float shore = 1.0 - smoothstep(0.0, 0.045, depth01);
	float breathe = 0.55 + 0.45 * sin(TIME * 0.9 + h0 * 0.8 + depth01 * 40.0);
	float foam = shore * breathe;
	col = mix(col, foam_color, foam * 0.85);

	ALBEDO = col * mix(0.16, 1.0, daylight);
	// Sharp mirror-like reflections by day; in low light a rougher, weaker surface (a sharp reflection of an orange
	// dusk sky through the ripples looked like lava).
	ROUGHNESS = mix(0.4, 0.06, smoothstep(0.1, 0.9, daylight));
	SPECULAR = mix(0.15, 0.7, daylight);
	METALLIC = 0.0;
	ALPHA = clamp(mix(0.38, 0.94, smoothstep(0.0, 0.4, depth01)) + foam * 0.5, 0.0, 1.0);
}
