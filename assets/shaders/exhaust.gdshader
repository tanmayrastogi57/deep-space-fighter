shader_type spatial;
render_mode unshaded, blend_add, cull_back, depth_draw_never;
uniform vec4 tint : source_color = vec4(0.26, 0.68, 1.0, 1.0);
varying float aft;
void vertex() { aft = clamp(VERTEX.y + 0.5, 0.0, 1.0); }
void fragment() {
	float core = pow(1.0 - aft, 2.2);
	float cells = 0.85 + 0.15 * cos(aft * 21.0);
	ALBEDO = mix(tint.rgb, vec3(0.9, 0.93, 1.0), core);
	ALPHA = cells * (1.0 - smoothstep(0.0, 1.0, aft)) * 0.72;
}
