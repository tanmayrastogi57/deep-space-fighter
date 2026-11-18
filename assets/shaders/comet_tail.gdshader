shader_type spatial;
render_mode unshaded, blend_add, cull_back, depth_draw_never;
varying float along;
void vertex() { along = VERTEX.y + 0.5; }
void fragment() {
	float streak = .78+.22*cos(UV.x*37.7+along*2.8);
	float column = pow(max(1.-along,0.),2.)*streak;
	ALBEDO = mix(vec3(.57,.81,.90),vec3(.24,.42,.69),along);
	ALPHA = .56*column*smoothstep(0.,.07,along)*smoothstep(.0,.68,abs(dot(normalize(NORMAL),normalize(VIEW))));
}
