shader_type spatial;
#include "res://assets/shaders/surface_noise.gdshaderinc"
uniform vec4 stone : source_color;
uniform vec4 seam : source_color;
uniform float ice = 0.0;
varying vec3 rock_pos;
void vertex() { rock_pos = VERTEX; }
void fragment() {
	vec3 q = normalize(rock_pos);
	float faults = terrain(q*3.8+vec3(9.,3.,17.));
	float vein = 1.-smoothstep(.008,.038,abs(faults-.49));
	float grain = field(q*15.);
	ALBEDO = mix(stone.rgb*(.74+.34*faults+.14*grain),seam.rgb,vein*.66);
	ROUGHNESS = mix(.92,.34+.28*grain,ice);
	SPECULAR = .17+.33*ice;
}
