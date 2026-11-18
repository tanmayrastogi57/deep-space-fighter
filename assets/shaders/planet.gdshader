shader_type spatial;
render_mode unshaded;
#include "res://assets/shaders/surface_noise.gdshaderinc"
// 0: ocean world; 1: airless moon; 2: gas giant; 3: photosphere.
uniform int kind;
uniform vec3 sunward = vec3(-0.8,0.25,0.35);
varying vec3 sphere_pos;
void vertex() { sphere_pos = normalize(VERTEX); }
void fragment() {
	vec3 p = normalize(sphere_pos);
	float n = terrain(p*3.5 + vec3(13.,4.,9.));
	float facing = clamp(dot(normalize(NORMAL),normalize(VIEW)),0.,1.);
	float limb = pow(1.-facing,3.);
	ROUGHNESS = 0.93;
	SPECULAR = 0.15;
	if (kind == 0) {
		float land = smoothstep(.43,.50,n);
		vec3 crust = mix(vec3(.055,.18,.23),vec3(.38,.41,.26),smoothstep(.51,.68,n));
		vec3 base = mix(vec3(.075,.22,.36),crust,land);
		float clouds = terrain(p*7.4 + vec3(n*2.,sin(6.*p.y)*1.1,4.));
		base = mix(base,vec3(.73,.80,.80),smoothstep(.50,.70,clouds)*.84);
		ALBEDO = base;
	} else if (kind == 1) {
		float crater = 0.;
		for (int i=0; i<26; i++) {
			float id = float(i)+.5, y = 1.-2.*id/26.;
			float r = sqrt(max(0.,1.-y*y));
			vec3 center = vec3(r*cos(id*2.4),y,r*sin(id*2.4));
			float d = length(center-p)/(.10+.19*hash3(vec3(id,3.,5.)));
			crater += .21*(1.-smoothstep(.09,.28,abs(d-1.))) - .27*(1.-smoothstep(.52,.96,d));
		}
		ALBEDO = vec3(.64,.62,.60)*clamp(.55+.52*n+crater,.16,1.2);
	} else if (kind == 2) {
		float bands = sin(28.*p.y+4.*n+.65*sin(9.*p.x));
		vec3 base = mix(vec3(.50,.38,.31),vec3(.83,.75,.62),smoothstep(-.95,1.,bands)*(.6+.34*n));
		ALBEDO = base*(.85+.18*n+.03*sin(86.*p.y+9.*n));
	} else {
		float grain = terrain(35.*p);
		vec3 sun = mix(vec3(.91,.44,.17),vec3(.99,.86,.59),.40+.56*facing);
		ALBEDO = sun*(.74+.21*grain+.05*n);
		SPECULAR = 0.;
	}
	if (kind != 3) {
		float daylight = smoothstep(-.18,.92,dot(p,normalize(sunward)));
		vec3 night = kind == 0 ? vec3(.33,.41,.49) : vec3(.19,.21,.26);
		ALBEDO *= mix(night,vec3(1.0,.98,.94),daylight);
		if (kind == 0) ALBEDO += vec3(.055,.14,.20)*limb*(.25+.75*daylight);
	}
}
