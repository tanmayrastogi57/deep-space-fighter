shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never;
void vertex() {
	vec3 normal = normalize(INV_VIEW_MATRIX[3].xyz - MODEL_MATRIX[3].xyz);
	vec3 right = normalize(cross(INV_VIEW_MATRIX[1].xyz,normal));
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(vec4(right,0.),vec4(cross(normal,right),0.),vec4(normal,0.),MODEL_MATRIX[3]);
}
void fragment() {
	vec2 q = (UV-.5)*2.;
	float d = length(q);
	float rays = .92+.08*cos(8.*atan(q.y,q.x)+2.*d);
	ALBEDO = vec3(.93,.49,.18);
	ALPHA = .28*rays*exp(-12.*max(d-.70,0.))*smoothstep(.66,.71,d)*(1.-smoothstep(.91,1.,d));
}
