shader_type spatial;
render_mode cull_disabled, unshaded, depth_draw_never;
void fragment() {
	float r = UV.y;
	float grain = .5+.5*sin(119.*r + .55*sin(45.*r));
	float cassini = smoothstep(.012,.041,abs(r-.69));
	float encke = smoothstep(.004,.017,abs(r-.87));
	float edge = smoothstep(0.,.12,r)*(1.-smoothstep(.91,1.,r));
	vec3 dust = mix(vec3(.37,.33,.30),vec3(.83,.75,.60),.36+.32*grain+.23*sin(17.*r));
	ALBEDO = dust;
	ALPHA = edge*cassini*encke*(.4+.45*grain);
}
