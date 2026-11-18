shader_type spatial;
render_mode unshaded;
uniform vec4 glow : source_color = vec4(.48,.76,.88,1.);
varying vec2 face;
void vertex() { face = VERTEX.xz / .34; }
void fragment() {
	float r = length(face);
	float vanes = .72+.28*cos(16.*atan(face.y,face.x)+3.*r);
	float hot_ring = exp(-38.*abs(r-.72));
	ALBEDO = mix(vec3(.09,.12,.15),glow.rgb,.46*(1.-smoothstep(.25,.90,r))*vanes+.53*hot_ring);
}
